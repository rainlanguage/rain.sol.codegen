// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.16.1/src/Vm.sol";
import {LibCodeGen} from "./LibCodeGen.sol";

/// @dev The directory that generated contract files are written to, relative to
/// the project root. Consumers commit this directory and import from it by
/// path, so it is a cross repo contract rather than an internal detail.
string constant GENERATED_DIR = "src/generated";

/// Thrown when a tag is not a single path segment drawn from the tag alphabet.
/// Such a tag cannot be interpolated into a directory path.
/// @param tag The rejected tag.
error InvalidTag(string tag);

/// @title LibFs
/// @notice A library for file system operations related to code generation.
/// @dev Uses foundry's Vm cheat codes for file operations. Notably standardizes
/// the placement and idempotent creation of generated files.
library LibFs {
    /// Reverts unless `tag` is drawn from the tag alphabet: at least one
    /// character, each of them an ASCII letter, a digit, `_` or `$`. That is
    /// the Solidity identifier alphabet without the rule against a leading
    /// digit, because a tag names a directory rather than a declaration and the
    /// release tags this org freezes are `<major>_<minor>_<patch>`, which opens
    /// with one. Restricting a tag to that alphabet is what makes it safe to
    /// interpolate into a path: no character in the set is a path separator,
    /// none of them is `.`, so no tag is `.` or `..` and none of them reaches
    /// past the single directory it names.
    /// @param tag The tag to check.
    function requireTag(string memory tag) internal pure {
        bytes memory tagBytes = bytes(tag);
        if (tagBytes.length == 0) {
            revert InvalidTag(tag);
        }
        for (uint256 i = 0; i < tagBytes.length; i++) {
            bytes1 char = tagBytes[i];
            bool isLetter = (char >= 0x41 && char <= 0x5A) || (char >= 0x61 && char <= 0x7A);
            bool isDigit = char >= 0x30 && char <= 0x39;
            bool isUnderscoreOrDollar = char == 0x5F || char == 0x24;
            if (!(isLetter || isDigit || isUnderscoreOrDollar)) {
                revert InvalidTag(tag);
            }
        }
    }

    /// @notice Constructs the directory that a tag's generated files live in.
    ///
    /// Reverts unless `tag` is drawn from the tag alphabet, so every directory
    /// this function returns is a direct child of `GENERATED_DIR`. The check is
    /// here rather than at the write because the directory is what carries the
    /// tag out of this library: a caller that takes the returned directory and
    /// does its own IO with it gets the same confinement
    /// `buildFileForTaggedContract` does, and there is no tag for which this
    /// library produces a directory at all without producing a safe one.
    ///
    /// An accepted tag is interpolated verbatim, so it reaches the directory
    /// byte for byte and is never quoted, escaped, trimmed, case folded or
    /// truncated.
    /// @param tag The tag, interpolated verbatim.
    /// @return The directory as a string.
    function dirForTag(string memory tag) internal pure returns (string memory) {
        requireTag(tag);
        return string.concat(GENERATED_DIR, "/", tag);
    }

    /// @notice Constructs the file path for a contract's generated file.
    ///
    /// Reverts unless `contractName` is a Solidity identifier, so every path
    /// this function returns is a direct child of `GENERATED_DIR`. The check is
    /// here rather than at the write because the path is what carries the name
    /// out of this library: a caller that takes the returned path and does its
    /// own IO with it gets the same confinement `buildFileForContract` does,
    /// and there is no name for which this library produces a path at all
    /// without producing a safe one.
    ///
    /// An accepted name is interpolated verbatim, so it reaches the path byte
    /// for byte and is never quoted, escaped, trimmed, case folded or
    /// truncated. Names that differ only in case therefore give different
    /// paths, which a case insensitive filesystem resolves to the same file.
    /// @param contractName The name of the contract, interpolated verbatim.
    /// @return The file path as a string.
    function pathForContract(string memory contractName) internal pure returns (string memory) {
        return pathForContractIn(GENERATED_DIR, contractName);
    }

    /// @notice Constructs the file path for a contract's generated file inside
    /// `dir`.
    /// @dev `pathForContract` is this function applied to `GENERATED_DIR`, so
    /// everything stated there about the name holds here too: the path is a
    /// direct child of `dir` for every name that is accepted at all, and an
    /// accepted name is interpolated verbatim.
    ///
    /// `dir` is interpolated verbatim and is not checked, so where `dir` itself
    /// sits is entirely the caller's, and only `fs_permissions` confines it.
    /// That is why this is private rather than internal: the only directory a
    /// consumer of this library writes to is `GENERATED_DIR`.
    /// @param dir The directory to put the file in, without a trailing
    /// separator, interpolated verbatim.
    /// @param contractName The name of the contract, interpolated verbatim.
    /// @return The file path as a string.
    function pathForContractIn(string memory dir, string memory contractName) private pure returns (string memory) {
        LibCodeGen.requireContractName(contractName);
        return string.concat(dir, "/", contractName, ".sol");
    }

    /// @notice Constructs the file path for a contract's generated file inside a
    /// tag's directory, which is the layout per release deploy pin snapshots
    /// use.
    ///
    /// Reverts unless `tag` is drawn from the tag alphabet and `contractName`
    /// is a Solidity identifier, so every path this function returns is exactly
    /// two segments inside `GENERATED_DIR`: neither argument can express a path
    /// separator, `.` or `..`, so neither of them can add a segment, remove
    /// one, or leave the directory. The tag is checked first, so a call that
    /// gets both wrong names the tag.
    ///
    /// Both accepted arguments are interpolated verbatim, so they reach the
    /// path byte for byte and are never quoted, escaped, trimmed, case folded
    /// or truncated.
    /// @dev This is `pathForContractIn` applied to `dirForTag(tag)`, so the name
    /// rule and the verbatim interpolation of the name are exactly
    /// `pathForContract`'s, one directory deeper.
    /// @param tag The tag whose directory the file lives in, interpolated
    /// verbatim.
    /// @param contractName The name of the contract, interpolated verbatim.
    /// @return The file path as a string.
    function pathForTaggedContract(string memory tag, string memory contractName)
        internal
        pure
        returns (string memory)
    {
        return pathForContractIn(dirForTag(tag), contractName);
    }

    /// @notice True if anything occupies `path`, including a symlink whose
    /// target does not exist.
    /// @dev `vm.exists` answers for whatever the path resolves to, so it reports
    /// a symlink with no target as absent. `vm.readLink` answers for the path
    /// itself and reverts unless the path is a symlink, so it sees the link that
    /// `vm.exists` does not.
    /// @param vm The Vm instance for file operations.
    /// @param path The path to check, which must be readable under
    /// `fs_permissions`.
    /// @return True if the path holds a file, a directory or a symlink.
    function isPresent(Vm vm, string memory path) internal view returns (bool) {
        if (vm.exists(path)) {
            return true;
        }
        // What the target is does not matter here, only that the path has one.
        //slither-disable-next-line unused-return
        try vm.readLink(path) returns (string memory) {
            return true;
        } catch {
            return false;
        }
    }

    /// @notice Builds a file for a generated contract at
    /// `pathForContract(contractName)`.
    ///
    /// `contractName` must be a Solidity identifier, which `pathForContract`
    /// requires of every path it returns, so the file is always a direct child
    /// of `GENERATED_DIR` and a rejected name reverts before any cheatcode is
    /// reached.
    ///
    /// `GENERATED_DIR` is created if it does not exist, along with any missing
    /// parent of it, so the first generation in a repo does not need it
    /// committed already.
    ///
    /// Anything already at the path is unlinked before the write, so a symlink
    /// there is replaced by a regular file rather than written through to its
    /// target, including a symlink whose target does not exist, and the path
    /// does not exist between the unlink and the write.
    /// Any manual changes to the generated file, or any other existing file at
    /// that path, are lost.
    ///
    /// The whole file is written on every call, so the same arguments always
    /// produce the same bytes. The prefix and bytecode hash constant are always
    /// included, further content is provided in the body parameter, which is
    /// expected to be generated by `LibCodeGen` by the caller.
    /// @param vm The Vm instance for file operations.
    /// @param instance The contract instance whose bytecode hash is to be
    /// included.
    /// @param contractName The name of the contract.
    /// @param body The body of the contract file to be written.
    function buildFileForContract(Vm vm, address instance, string memory contractName, string memory body) internal {
        buildFileForContract(vm, instance, GENERATED_DIR, contractName, body);
    }

    /// @notice Builds a file for a generated contract inside `dir` rather than
    /// inside `GENERATED_DIR`.
    /// @dev Identical to `buildFileForContract` in every other respect, and
    /// that function is this one applied to `GENERATED_DIR`: `dir` is what gets
    /// created when it is missing, and what the file is written a direct child
    /// of. `dir` is interpolated verbatim and is not checked, so a caller
    /// passing something other than a directory it means to own gets whatever
    /// `fs_permissions` allows; `contractName` is still required to be a
    /// Solidity identifier, so the name can never carry the file out of `dir`.
    ///
    /// This overload exists so that the directory creation is reachable from a
    /// test without deleting `GENERATED_DIR`. Every test that generates a file
    /// writes under `GENERATED_DIR`, and `forge` runs them in parallel, so
    /// removing it to make it missing races all of them.
    /// @param vm The Vm instance for file operations.
    /// @param instance The contract instance whose bytecode hash is to be
    /// included.
    /// @param dir The directory to put the file in, without a trailing
    /// separator, interpolated verbatim.
    /// @param contractName The name of the contract.
    /// @param body The body of the contract file to be written.
    function buildFileForContract(
        Vm vm,
        address instance,
        string memory dir,
        string memory contractName,
        string memory body
    ) internal {
        string memory path = pathForContractIn(dir, contractName);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.createDir(dir, true);
        if (isPresent(vm, path)) {
            //forge-lint: disable-next-line(unsafe-cheatcode)
            vm.removeFile(path);
        }
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(
            path, string.concat(LibCodeGen.filePrefix(), LibCodeGen.bytecodeHashConstantString(vm, instance), body)
        );
    }

    /// @notice Builds a file for a generated contract at
    /// `pathForTaggedContract(tag, contractName)`.
    ///
    /// `tag` must be drawn from the tag alphabet and `contractName` must be a
    /// Solidity identifier, which `pathForTaggedContract` requires of every
    /// path it returns, so the file is always two segments inside
    /// `GENERATED_DIR` and a rejected tag or name reverts before any cheatcode
    /// is reached.
    ///
    /// The tag's directory is created if it does not exist, along with
    /// `GENERATED_DIR` itself, so the first generation for a tag does not need
    /// it committed already.
    ///
    /// Anything already at the path is unlinked before the write, so a symlink
    /// there is replaced by a regular file rather than written through to its
    /// target, including a symlink whose target does not exist, and the path
    /// does not exist between the unlink and the write.
    /// Any manual changes to the generated file, or any other existing file at
    /// that path, are lost.
    ///
    /// The whole file is written on every call, so the same arguments always
    /// produce the same bytes. The prefix and bytecode hash constant are always
    /// included, further content is provided in the body parameter, which is
    /// expected to be generated by `LibCodeGen` by the caller.
    /// @dev This is the `dir` overload of `buildFileForContract` applied to
    /// `dirForTag(tag)`, so everything that overload states holds here, and the
    /// only thing this function adds is that the directory is not the caller's
    /// to choose: it is derived from a tag that `dirForTag` refuses unless it
    /// names exactly one directory inside `GENERATED_DIR`.
    /// @param vm The Vm instance for file operations.
    /// @param instance The contract instance whose bytecode hash is to be
    /// included.
    /// @param tag The tag whose directory the file lives in.
    /// @param contractName The name of the contract.
    /// @param body The body of the contract file to be written.
    function buildFileForTaggedContract(
        Vm vm,
        address instance,
        string memory tag,
        string memory contractName,
        string memory body
    ) internal {
        buildFileForContract(vm, instance, dirForTag(tag), contractName, body);
    }
}

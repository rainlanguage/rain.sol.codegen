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
    /// truncated.
    /// @param contractName The name of the contract, interpolated verbatim.
    /// @return The file path as a string.
    function pathForContract(string memory contractName) internal pure returns (string memory) {
        LibCodeGen.requireContractName(contractName);
        return string.concat(GENERATED_DIR, "/", contractName, ".sol");
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
    /// @param tag The tag whose directory the file lives in, interpolated
    /// verbatim.
    /// @param contractName The name of the contract, interpolated verbatim.
    /// @return The file path as a string.
    function pathForTaggedContract(string memory tag, string memory contractName)
        internal
        pure
        returns (string memory)
    {
        string memory dir = dirForTag(tag);
        LibCodeGen.requireContractName(contractName);
        return string.concat(dir, "/", contractName, ".sol");
    }

    /// @notice Builds a file for a generated contract at
    /// `pathForContract(contractName)`.
    ///
    /// `contractName` must be a Solidity identifier, which `pathForContract`
    /// requires of every path it returns, so the file is always a direct child
    /// of `GENERATED_DIR` and a rejected name reverts before any cheatcode is
    /// reached.
    ///
    /// `GENERATED_DIR` is created if it does not exist, so the first generation
    /// in a repo does not need it committed already.
    ///
    /// Anything already at the path is unlinked before the write, so a symlink
    /// there is replaced by a regular file rather than written through to its
    /// target, and the path does not exist between the unlink and the write.
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
        string memory path = pathForContract(contractName);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.createDir(GENERATED_DIR, true);
        if (vm.exists(path)) {
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
    /// target, and the path does not exist between the unlink and the write.
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
        string memory path = pathForTaggedContract(tag, contractName);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.createDir(dirForTag(tag), true);
        if (vm.exists(path)) {
            //forge-lint: disable-next-line(unsafe-cheatcode)
            vm.removeFile(path);
        }
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(
            path, string.concat(LibCodeGen.filePrefix(), LibCodeGen.bytecodeHashConstantString(vm, instance), body)
        );
    }
}

// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm, VmSafe} from "forge-std-1.16.2/src/Vm.sol";
import {LibCodeGen} from "./LibCodeGen.sol";

/// @dev The directory that generated contract files are written to, relative to
/// the project root. Consumers commit this directory and import from it by
/// path, so it is a cross repo contract rather than an internal detail.
string constant GENERATED_DIR = "src/generated";

/// Thrown when the symlink found at a generated path could not be removed.
///
/// The write that would have followed does not happen. A link still at the path
/// is a write that lands on whatever the link resolves to instead, which is the
/// one outcome that has to be impossible here, so a removal that did not happen
/// ends the call rather than being assumed.
///
/// `ffi = true` is what the removal needs and what a consumer that has not
/// enabled it is missing; that case reverts before this, out of the cheatcode.
/// @param path The path the symlink is at.
/// @param exitCode The exit code the removal reported.
/// @param stderr What the removal wrote to stderr.
error SymlinkRemovalFailed(string path, int32 exitCode, bytes stderr);

/// Thrown when the generated directory holds an artifact for a contract other
/// than the one `pathForContract` names for it. Consumers commit these files
/// and import them by path, so an artifact this library does not write is one
/// nothing regenerates: its imports keep resolving to a frozen codehash while
/// the build reports success.
/// @param path The artifact nothing regenerates, relative to the project root.
error OrphanedGeneratedArtifact(string path);

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
        LibCodeGen.requireIdentifier(contractName);
        return string.concat(dir, "/", contractName, ".sol");
    }

    /// The final segment of `path`: the bytes after its last `/`, or all of
    /// `path` when it has none. `vm.readDir` reports absolute paths, so this is
    /// what carries an entry's own name.
    /// @param path The path to take the final segment of.
    /// @return The final segment.
    function lastPathSegment(string memory path) internal pure returns (string memory) {
        bytes memory pathBytes = bytes(path);
        uint256 start = 0;
        for (uint256 i = 0; i < pathBytes.length; i++) {
            if (pathBytes[i] == "/") {
                start = i + 1;
            }
        }
        bytes memory segment = new bytes(pathBytes.length - start);
        for (uint256 i = 0; i < segment.length; i++) {
            segment[i] = pathBytes[start + i];
        }
        return string(segment);
    }

    /// @notice Reverts if `GENERATED_DIR` holds an artifact for `contractName`
    /// other than the one at `pathForContract(contractName)`.
    ///
    /// An artifact for a contract is a direct child of `GENERATED_DIR` named
    /// for that contract: the name in full, then a `.`, then anything. The full
    /// name up to the `.` is what separates one contract's artifact from
    /// another's, so a repo generating both `Foo` and `FooBar` keeps both.
    ///
    /// `pathForContract` names exactly one such child, and that one is asked
    /// for here rather than spelled out again, so whichever file that function
    /// names is the current artifact and every other one is a file this library
    /// does not write. Nothing regenerates those, while the consumer's `src/**`
    /// keeps importing them, so they are refused rather than left frozen beside
    /// a fresh generation.
    ///
    /// Only direct children are read. `pathForContract` never names anything
    /// deeper, so a per release snapshot directory holds nothing this library
    /// wrote and is left alone.
    ///
    /// Inherits `pathForContract`'s refusal to produce a path for a name that
    /// is not a Solidity identifier.
    /// @param vm The Vm instance for file operations.
    /// @param contractName The name of the contract.
    function requireNoOrphanedArtifact(Vm vm, string memory contractName) internal view {
        requireNoOrphanedArtifactIn(vm, GENERATED_DIR, contractName);
    }

    /// @notice Reverts if `dir` holds an artifact for `contractName` other than
    /// the one at `pathForContractIn(dir, contractName)`.
    /// @dev `requireNoOrphanedArtifact` is this function applied to
    /// `GENERATED_DIR`, so everything stated there holds here too, of `dir`
    /// rather than of `GENERATED_DIR`. It is private for the same reason
    /// `pathForContractIn` is: the only directory a consumer of this library
    /// writes to is `GENERATED_DIR`, and `dir` is interpolated verbatim and is
    /// not checked.
    ///
    /// The whole check is one read of `dir`, and `vm.readDir` does not revert
    /// when that read fails: it returns a single entry naming `dir` itself and
    /// carrying an `errorMessage`. No artifact name matches that entry, so a
    /// directory that cannot be read is accepted rather than refused. That is
    /// the answer wanted for a repo with no generated directory yet, and it is
    /// why `buildFileForContract` creates `dir` before calling this: after a
    /// `vm.createDir` that did not itself revert, the read is of a directory
    /// that is there.
    /// @param vm The Vm instance for file operations.
    /// @param dir The directory to read, without a trailing separator,
    /// interpolated verbatim.
    /// @param contractName The name of the contract.
    function requireNoOrphanedArtifactIn(Vm vm, string memory dir, string memory contractName) private view {
        bytes32 currentArtifact = keccak256(bytes(lastPathSegment(pathForContractIn(dir, contractName))));
        bytes memory prefix = bytes(string.concat(contractName, "."));
        //forge-lint: disable-next-line(unsafe-cheatcode)
        Vm.DirEntry[] memory entries = vm.readDir(dir);
        for (uint256 i = 0; i < entries.length; i++) {
            bytes memory name = bytes(lastPathSegment(entries[i].path));
            if (name.length < prefix.length || keccak256(name) == currentArtifact) {
                continue;
            }
            bool isArtifact = true;
            for (uint256 j = 0; j < prefix.length; j++) {
                if (name[j] != prefix[j]) {
                    isArtifact = false;
                    break;
                }
            }
            if (isArtifact) {
                revert OrphanedGeneratedArtifact(string.concat(dir, "/", string(name)));
            }
        }
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
    /// a symlink with no target as absent. `vm.readLink` is what covers that
    /// one: foundry resolves a path before it reads the link at it, so the
    /// cheatcode succeeds only where there is nothing to resolve to, and reverts
    /// on a symlink that does resolve — which is the case `vm.exists` has
    /// already answered. Between them every symlink is present.
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

    /// @notice True if `path`, which must be a direct child of `dir`, is itself
    /// a symlink, whether or not it resolves to anything.
    /// @dev Every cheatcode that takes a path resolves it before it acts, so
    /// none of them can tell a live symlink from the file at the other end of
    /// it: `vm.exists`, `vm.isFile` and `vm.fsMetadata(...).isSymlink` all
    /// answer for the target, and `vm.readLink` reverts because the path it is
    /// handed has already stopped being a link. `vm.readDir` is the one that
    /// does not, because what it reports comes from walking the directory rather
    /// than from resolving a path, so each entry's `isSymlink` is about the
    /// entry itself. That holds whether or not the walk is told to follow
    /// links, and `dir` is resolved before the walk starts either way, so a
    /// `dir` that is itself a symlink lists its target's children.
    ///
    /// Depth 1 is what confines the listing to the direct children of `dir`,
    /// and only a direct child is `path`. A deeper listing reports entries from
    /// subdirectories under the same name, which is not hypothetical here:
    /// `src/generated/<tag>/<Name>.sol` is a frozen snapshot sitting one level
    /// under `src/generated/<Name>.sol` and sharing its name exactly. The
    /// listing comes back sorted by path, so whichever of the two sorts first
    /// would be the one that answered, and a snapshot answering for a live
    /// symlink at the path is the removal reaching the link's target again.
    ///
    /// The entry is found by the name it has in the directory, compared exactly:
    /// `vm.readDir` reports absolute paths, so that is the only part of an entry
    /// that can be held against a path built from `dir`. A filesystem that
    /// resolves two spellings of a name to one file therefore reports the
    /// spelling it stored, and a `path` spelled the other way does not match it,
    /// which is the same case insensitivity `pathForContract` already states.
    /// @param vm The Vm instance for file operations.
    /// @param dir The directory holding `path`, which must exist and be readable
    /// under `fs_permissions`.
    /// @param path The path to check.
    /// @return True if the path itself is a symlink.
    function isSymlinkIn(Vm vm, string memory dir, string memory path) private view returns (bool) {
        bytes32 name = keccak256(bytes(lastPathSegment(path)));
        VmSafe.DirEntry[] memory entries = vm.readDir(dir, 1, false);
        for (uint256 i = 0; i < entries.length; i++) {
            if (keccak256(bytes(lastPathSegment(entries[i].path))) == name) {
                return entries[i].isSymlink;
            }
        }
        return false;
    }

    /// @notice Removes the symlink at `path`, leaving whatever it resolves to
    /// exactly as it was.
    /// @dev Every cheatcode that removes something resolves the path before it
    /// acts, so `vm.removeFile` on a live symlink deletes the file at the other
    /// end of the link and leaves the link behind, now dangling. What the caller
    /// asked to replace is the path; the file the link points at is a second
    /// file at a second path that nothing about generating here names, and it is
    /// bounded only by `fs_permissions`. forge-std 1.16.2 has no cheatcode that
    /// acts on the link, so this shells out instead: `rm` acts on the name it is
    /// given and never follows a symlink operand, whatever is at the other end.
    ///
    /// Only reached once `isSymlinkIn` has answered true, so `rm` is never asked
    /// to remove a directory, and the `-r` that would let it is not passed. A
    /// symlink that resolves to a directory is still a symlink, so it is the
    /// link that goes and the directory it pointed at is left alone. `-f` is
    /// passed so that a link is removed rather than prompted about on a terminal
    /// that nothing is reading.
    ///
    /// The command is an argv array rather than a command line, so no shell
    /// interprets anything in `path`, and `--` ends the options so that a caller
    /// supplied `dir` beginning with `-` cannot be read as one.
    ///
    /// `fs_permissions` does not confine `rm` the way it confines a cheatcode.
    /// What confines this is the `vm.createDir(dir, true)` that runs ahead of it
    /// and is permission checked: `path` is always a direct child of `dir`, so a
    /// `dir` the grant refuses reverts before anything is unlinked.
    ///
    /// This is the only thing in this library that needs `ffi = true`, and it
    /// runs only when a symlink is actually at the path, so a consumer that has
    /// not enabled ffi generates normally and gets a revert in the one case that
    /// cannot be handled without destroying something. Nothing is lost either
    /// way.
    /// @param vm The Vm instance for file operations.
    /// @param path The path of the symlink to remove.
    function removeSymlink(Vm vm, string memory path) private {
        string[] memory command = new string[](4);
        command[0] = "rm";
        command[1] = "-f";
        command[2] = "--";
        command[3] = path;
        VmSafe.FfiResult memory result = vm.tryFfi(command);
        if (result.exitCode != 0) {
            revert SymlinkRemovalFailed(path, result.exitCode, result.stderr);
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
    /// The whole file content is built before anything on disk is touched, and
    /// building it reverts for an `instance` that holds no code and for a
    /// licence or copyright `filePrefix` refuses. A revert does not roll back
    /// cheatcode filesystem effects, so ordering the build first is what keeps
    /// a failed generation from leaving the directory worse than it found it:
    /// nothing is created, unlinked or written unless there is content to
    /// write.
    ///
    /// Another artifact for the same contract already in `GENERATED_DIR`
    /// refuses the whole call, before anything at the path is unlinked or
    /// written, so a generation never lands beside a file that nothing
    /// regenerates. The directory is created first, because the check is a read
    /// of it and a consumer generating for the first time has neither the
    /// directory nor an orphan in it.
    ///
    /// Whatever is at the path comes off it before the write, so a symlink
    /// there is replaced by a regular file rather than written through to its
    /// target, whether or not that target exists, and the path holds nothing
    /// between the removal and the write.
    ///
    /// A symlink comes off by removing the link and nothing else. What it
    /// resolves to is left byte for byte as it was, wherever it is, however far
    /// the calling project's `fs_permissions` reach: the caller asked to
    /// generate at the path, and the file at the other end of a link is a
    /// second file at a second path that nothing here named. Removing a link
    /// needs `ffi = true` and reverts without it, so a consumer that has not
    /// enabled ffi refuses that case rather than generating through it.
    ///
    /// Any manual changes to the generated file, and any other existing file at
    /// that path, are lost.
    ///
    /// A directory at the path is the one thing that cannot come off it, and
    /// reverts rather than being cleared or written into. A symlink that
    /// resolves to a directory is a link like any other: the link goes and the
    /// directory stays.
    ///
    /// The whole file is written on every call, so the same arguments always
    /// produce the same bytes. The prefix and bytecode hash constant are always
    /// included, further content is provided in the body parameter, which is
    /// expected to be generated by `LibCodeGen` by the caller.
    ///
    /// The file lands in the calling project's repo, so the licence it is under
    /// and the copyright holder it names come from the caller and are subject to
    /// `LibCodeGen.filePrefix`'s rule for them.
    /// @param vm The Vm instance for file operations.
    /// @param instance The contract instance whose bytecode hash is to be
    /// included.
    /// @param contractName The name of the contract.
    /// @param spdxLicenseIdentifier The SPDX licence identifier the written file
    /// declares.
    /// @param copyrightText The copyright text the written file declares.
    /// @param body The body of the contract file to be written.
    function buildFileForContract(
        Vm vm,
        address instance,
        string memory contractName,
        string memory spdxLicenseIdentifier,
        string memory copyrightText,
        string memory body
    ) internal {
        buildFileForContract(vm, instance, GENERATED_DIR, contractName, spdxLicenseIdentifier, copyrightText, body);
    }

    /// @notice Builds a file for a generated contract inside `dir` rather than
    /// inside `GENERATED_DIR`.
    /// @dev Identical to `buildFileForContract` in every other respect, and
    /// that function is this one applied to `GENERATED_DIR`: `dir` is what gets
    /// created when it is missing, what is read for another artifact of the
    /// same contract, and what the file is written a direct child of. `dir` is
    /// interpolated verbatim and is not checked, so a caller
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
    /// @param spdxLicenseIdentifier The SPDX licence identifier the written file
    /// declares.
    /// @param copyrightText The copyright text the written file declares.
    /// @param body The body of the contract file to be written.
    function buildFileForContract(
        Vm vm,
        address instance,
        string memory dir,
        string memory contractName,
        string memory spdxLicenseIdentifier,
        string memory copyrightText,
        string memory body
    ) internal {
        string memory path = pathForContractIn(dir, contractName);
        string memory content = string.concat(
            LibCodeGen.filePrefix(spdxLicenseIdentifier, copyrightText),
            LibCodeGen.bytecodeHashConstantString(vm, instance),
            body
        );
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.createDir(dir, true);
        requireNoOrphanedArtifactIn(vm, dir, contractName);
        // Whatever is at the path has to come off it before the write, or the
        // write lands on what a link there resolves to rather than on the path.
        //
        // `vm.removeFile` resolves the path before it acts, so it removes the
        // path itself except where the path is a symlink that resolves to
        // something, and there it removes that something instead and leaves the
        // link. That is the one case it cannot be used for, so it is the one
        // case that takes the link off directly. A path that resolves to
        // nothing, whether it is a link with no target or a cycle of them, has
        // nothing else for the cheatcode to reach, and a path that is not a link
        // resolves to itself.
        //
        // Either way the path holds nothing afterwards or the call has reverted,
        // so one pass is the whole job. A directory is what reverts: it is the
        // one thing that cannot come off the path at all.
        if (isPresent(vm, path)) {
            if (vm.exists(path) && isSymlinkIn(vm, dir, path)) {
                removeSymlink(vm, path);
            } else {
                //forge-lint: disable-next-line(unsafe-cheatcode)
                vm.removeFile(path);
            }
        }
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(path, content);
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
    /// Whatever is at the path comes off it before the write, so a symlink
    /// there is replaced by a regular file rather than written through to its
    /// target, whether or not that target exists, and the path holds nothing
    /// between the removal and the write.
    ///
    /// A symlink comes off by removing the link and nothing else. What it
    /// resolves to is left byte for byte as it was, wherever it is, however far
    /// the calling project's `fs_permissions` reach. Removing a link needs
    /// `ffi = true` and reverts without it, so a consumer that has not enabled
    /// ffi refuses that case rather than generating through it.
    ///
    /// Any manual changes to the generated file, and any other existing file at
    /// that path, are lost.
    ///
    /// A directory at the path is the one thing that cannot come off it, and
    /// reverts rather than being cleared or written into. A symlink that
    /// resolves to a directory is a link like any other: the link goes and the
    /// directory stays.
    ///
    /// The whole file is written on every call, so the same arguments always
    /// produce the same bytes. The prefix and bytecode hash constant are always
    /// included, further content is provided in the body parameter, which is
    /// expected to be generated by `LibCodeGen` by the caller.
    ///
    /// The file lands in the calling project's repo, so the licence it is under
    /// and the copyright holder it names come from the caller and are subject to
    /// `LibCodeGen.filePrefix`'s rule for them.
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
    /// @param spdxLicenseIdentifier The SPDX licence identifier the written file
    /// declares.
    /// @param copyrightText The copyright text the written file declares.
    /// @param body The body of the contract file to be written.
    function buildFileForTaggedContract(
        Vm vm,
        address instance,
        string memory tag,
        string memory contractName,
        string memory spdxLicenseIdentifier,
        string memory copyrightText,
        string memory body
    ) internal {
        buildFileForContract(vm, instance, dirForTag(tag), contractName, spdxLicenseIdentifier, copyrightText, body);
    }
}

// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.16.2/src/Vm.sol";
import {LibCodeGen} from "./LibCodeGen.sol";

/// @dev The directory that generated contract files are written to, relative to
/// the project root. Consumers commit this directory and import from it by
/// path, so it is a cross repo contract rather than an internal detail.
string constant GENERATED_DIR = "src/generated";

/// Thrown when the generated directory holds an artifact for a contract other
/// than the one `pathForContract` names for it. Consumers commit these files
/// and import them by path, so an artifact this library does not write is one
/// nothing regenerates: its imports keep resolving to a frozen codehash while
/// the build reports success.
/// @param path The artifact nothing regenerates, relative to the project root.
error OrphanedGeneratedArtifact(string path);

/// @title LibFs
/// @notice A library for file system operations related to code generation.
/// @dev Uses foundry's Vm cheat codes for file operations. Notably standardizes
/// the placement and idempotent creation of generated files.
library LibFs {
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
    /// The path is unlinked until it holds nothing, then written, so a symlink
    /// there is replaced by a regular file rather than written through to its
    /// target, whether or not that target exists, and the path does not exist
    /// between the last unlink and the write. Taking a live symlink off the
    /// path takes what it resolves to with it, because that is what the unlink
    /// acts on first.
    /// Any manual changes to the generated file, any other existing file at
    /// that path, and whatever a symlink at that path resolves to, are lost.
    ///
    /// A directory at the path, and a symlink at the path that resolves to a
    /// directory, are the cases this cannot unlink, and both revert rather than
    /// being written into or through.
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
        // `vm.removeFile` resolves the path before it acts, so on a live symlink
        // it takes what the link points at and leaves the link, now dangling.
        // Every pass removes something the next one no longer finds, so this
        // ends with the path holding nothing.
        while (isPresent(vm, path)) {
            //forge-lint: disable-next-line(unsafe-cheatcode)
            vm.removeFile(path);
        }
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(path, content);
    }
}

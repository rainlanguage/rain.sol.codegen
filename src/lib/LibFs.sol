// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.16.1/src/Vm.sol";
import {LibCodeGen} from "./LibCodeGen.sol";

/// @dev The directory that generated contract files are written to, relative to
/// the project root. Consumers commit this directory and import from it by
/// path, so it is a cross repo contract rather than an internal detail.
string constant GENERATED_DIR = "src/generated";

/// Thrown when `GENERATED_DIR` holds an artifact for a contract other than the
/// one `pathForContract` names for it. Consumers commit these files and import
/// them by path, so an artifact this library does not write is one nothing
/// regenerates: its imports keep resolving to a frozen codehash while the build
/// reports success.
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
    /// truncated.
    /// @param contractName The name of the contract, interpolated verbatim.
    /// @return The file path as a string.
    function pathForContract(string memory contractName) internal pure returns (string memory) {
        LibCodeGen.requireContractName(contractName);
        return string.concat(GENERATED_DIR, "/", contractName, ".sol");
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
        bytes32 currentArtifact = keccak256(bytes(lastPathSegment(pathForContract(contractName))));
        bytes memory prefix = bytes(string.concat(contractName, "."));
        //forge-lint: disable-next-line(unsafe-cheatcode)
        Vm.DirEntry[] memory entries = vm.readDir(GENERATED_DIR);
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
                revert OrphanedGeneratedArtifact(string.concat(GENERATED_DIR, "/", string(name)));
            }
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
    /// `GENERATED_DIR` is created if it does not exist, so the first generation
    /// in a repo does not need it committed already.
    ///
    /// Another artifact for the same contract already in `GENERATED_DIR`
    /// refuses the whole call, before anything is created or removed, so a
    /// generation never lands beside a file that nothing regenerates.
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
        requireNoOrphanedArtifact(vm, contractName);
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

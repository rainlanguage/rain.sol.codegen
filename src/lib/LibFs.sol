// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.16.2/src/Vm.sol";
import {LibCodeGen} from "./LibCodeGen.sol";

/// @dev The directory that generated contract files are written to, relative to
/// the project root. Consumers commit this directory and import from it by
/// path, so it is a cross repo contract rather than an internal detail.
string constant GENERATED_DIR = "src/generated";

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
        LibCodeGen.requireContractName(contractName);
        return string.concat(dir, "/", contractName, ".sol");
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
}

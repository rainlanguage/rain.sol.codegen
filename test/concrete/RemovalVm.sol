// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {VmSafe} from "forge-std-1.16.2/src/Vm.sol";

/// Thrown by `RemovalVm.writeFile`.
/// @param path The path the write was for.
error WriteReached(string path);

/// Thrown by `RemovalVm.removeFile`.
/// @param path The path the removal was for.
error RemoveFileReached(string path);

/// @title RemovalVm
/// A contract with the shape of the `Vm` functions `buildFileForContract`
/// reaches, whose answers about the path are whatever it was constructed with.
///
/// `buildFileForContract` decides how to take what is at the generated path off
/// it from whether the path resolves and from what the directory listing says
/// the entry is, and then decides whether to go on to the write from what the
/// removal reported. None of those three is something a real filesystem
/// produces on demand: a listing that disagrees with the path does not happen,
/// and a removal that reports failure would have to be arranged by revoking
/// permissions, which then answers differently depending on which user the run
/// happens to have.
///
/// Nothing here touches disk. Both removals and the write revert instead of
/// happening, so which one the library reached is what a test observes, and no
/// file lands anywhere for any of them.
contract RemovalVm {
    /// What `readDir` reports.
    VmSafe.DirEntry[] internal sEntries;

    /// What `exists` reports.
    bool internal immutable iPathExists;

    /// The exit code `tryFfi` reports.
    int32 internal immutable iExitCode;

    /// What `tryFfi` reports on stderr.
    bytes internal sStderr;

    constructor(VmSafe.DirEntry[] memory entries, bool pathExists, int32 exitCode, bytes memory stderrOutput) {
        // Solidity 0.8.25 cannot copy an array of structs holding dynamic
        // members from memory to storage in one assignment.
        for (uint256 i = 0; i < entries.length; i++) {
            VmSafe.DirEntry storage entry = sEntries.push();
            entry.errorMessage = entries[i].errorMessage;
            entry.path = entries[i].path;
            entry.depth = entries[i].depth;
            entry.isDir = entries[i].isDir;
            entry.isSymlink = entries[i].isSymlink;
        }
        iPathExists = pathExists;
        iExitCode = exitCode;
        sStderr = stderrOutput;
    }

    /// The generated content is built before anything else happens, and the
    /// bytecode hash constant is formatted through this. What it returns reaches
    /// only a string that is never written.
    function toString(bytes32) external pure returns (string memory) {
        return "0x00";
    }

    /// The directory is created before the path is inspected. Nothing on disk
    /// backs this Vm, so there is nothing to create.
    function createDir(string calldata, bool) external {}

    /// Whether the path resolves to anything, as constructed.
    function exists(string calldata) external view returns (bool) {
        return iPathExists;
    }

    /// Reached only when the path resolves to nothing, and answering rather than
    /// reverting is what makes the path present anyway: a link with no target.
    function readLink(string calldata) external pure returns (string memory) {
        return "target";
    }

    /// The listing, as constructed.
    function readDir(string calldata, uint64, bool) external view returns (VmSafe.DirEntry[] memory entries) {
        entries = sEntries;
    }

    /// The removal that acts on a link, reporting whatever the constructor was
    /// given.
    function tryFfi(string[] calldata) external view returns (VmSafe.FfiResult memory result) {
        result = VmSafe.FfiResult({exitCode: iExitCode, stdout: "", stderr: sStderr});
    }

    /// The removal that acts on what the path resolves to.
    function removeFile(string calldata path) external pure {
        revert RemoveFileReached(path);
    }

    /// The write, which is the last thing `buildFileForContract` does, so
    /// reaching it is what says the removal ahead of it was accepted.
    function writeFile(string calldata path, string calldata) external pure {
        revert WriteReached(path);
    }
}

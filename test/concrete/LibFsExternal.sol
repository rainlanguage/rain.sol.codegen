// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std-1.16.2/src/Vm.sol";
import {LibFs} from "src/lib/LibFs.sol";

/// @title LibFsExternal
/// Puts `LibFs` behind a call frame. `vm.expectRevert` needs one, and the
/// library functions are internal so they are inlined into whatever calls them.
contract LibFsExternal {
    function buildFileForContract(
        Vm vm,
        address instance,
        string memory contractName,
        string memory spdxLicenseIdentifier,
        string memory copyrightText,
        string memory body
    ) external {
        LibFs.buildFileForContract(vm, instance, contractName, spdxLicenseIdentifier, copyrightText, body);
    }

    function buildFileForContract(
        Vm vm,
        address instance,
        string memory dir,
        string memory contractName,
        string memory spdxLicenseIdentifier,
        string memory copyrightText,
        string memory body
    ) external {
        LibFs.buildFileForContract(vm, instance, dir, contractName, spdxLicenseIdentifier, copyrightText, body);
    }

    function pathForContract(string memory contractName) external pure returns (string memory) {
        return LibFs.pathForContract(contractName);
    }

    function requireNoOrphanedArtifact(Vm vm, string memory contractName) external view {
        LibFs.requireNoOrphanedArtifact(vm, contractName);
    }
}

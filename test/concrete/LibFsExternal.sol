// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std-1.16.1/src/Vm.sol";
import {LibFs} from "src/lib/LibFs.sol";

/// @title LibFsExternal
/// Puts `LibFs.buildFileForContract` behind a call frame. `vm.expectRevert`
/// needs one, and the library function is internal so it is inlined into
/// whatever calls it.
contract LibFsExternal {
    function buildFileForContract(Vm vm, address instance, string memory contractName, string memory body) external {
        LibFs.buildFileForContract(vm, instance, contractName, body);
    }
}

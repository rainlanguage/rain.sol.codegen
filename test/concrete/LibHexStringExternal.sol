// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std-1.16.2/src/Vm.sol";
import {LibHexString} from "src/lib/LibHexString.sol";

/// @title LibHexStringExternal
/// Forces the result of `LibHexString.bytesToHex` across an ABI boundary. The
/// library returns a string whose pointer is deliberately not word aligned, so
/// encoding it as return data is the case most likely to expose a bad pointer.
contract LibHexStringExternal {
    function bytesToHex(Vm vm, bytes memory data) external pure returns (string memory) {
        return LibHexString.bytesToHex(vm, data);
    }
}

// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std/Vm.sol";

library LibHexString {
    function bytesToHex(Vm vm, bytes memory data) internal pure returns (string memory) {
        string memory hexString = vm.toString(data);
        assembly ("memory-safe") {
            // Remove the leading 0x
            let newHexString := add(hexString, 2)
            mstore(newHexString, sub(mload(hexString), 2))
            hexString := newHexString
        }
        return hexString;
    }
}

// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std/Vm.sol";

/// @title LibHexString
/// @notice A library for converting bytes to hexadecimal strings. Uses the
/// standard foundry Vm to perform the conversion.
library LibHexString {
    /// Converts a bytes array to its hexadecimal string representation but
    /// without the leading "0x". This is useful because solidity does not always
    /// accept the prefix, such as in `hex"..."` literals.
    /// @param vm The Vm instance used for conversion.
    /// @param data The bytes array to convert.
    /// @return The hexadecimal string representation of the bytes array.
    function bytesToHex(Vm vm, bytes memory data) internal pure returns (string memory) {
        string memory hexString = vm.toString(data);
        assembly ("memory-safe") {
            // Remove the leading 0x which is unconditionally added by
            /// vm.toString.
            let newHexString := add(hexString, 2)
            mstore(newHexString, sub(mload(hexString), 2))
            hexString := newHexString
        }
        return hexString;
    }
}

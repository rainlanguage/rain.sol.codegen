// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.16.1/src/Vm.sol";

/// Thrown when the `Vm` handed to `bytesToHex` does not return the string that
/// `toString(bytes)` is defined to return, which is "0x" followed by exactly two
/// hexadecimal characters per input byte.
/// @param hexString The string the `Vm` returned.
/// @param expectedLength The length the returned string was required to have.
error UnexpectedHexString(string hexString, uint256 expectedLength);

/// @title LibHexString
/// @notice A library for converting bytes to hexadecimal strings. Uses the
/// standard foundry Vm to perform the conversion.
library LibHexString {
    /// Converts a bytes array to its hexadecimal string representation but
    /// without the leading "0x". This is useful because solidity does not always
    /// accept the prefix, such as in `hex"..."` literals.
    ///
    /// Reverts with `UnexpectedHexString` if the `Vm` does not return "0x"
    /// followed by two hexadecimal characters per input byte. That is what
    /// foundry's own `Vm` always returns, but `vm` is a parameter, so the string
    /// the prefix is stripped from is whatever the caller's `Vm` hands back.
    /// Stripping two characters from a shorter string underflows the length
    /// word, and stripping them from an unprefixed one silently discards two
    /// characters of real data into generated source that still compiles.
    /// @param vm The Vm instance used for conversion.
    /// @param data The bytes array to convert.
    /// @return The hexadecimal string representation of the bytes array.
    function bytesToHex(Vm vm, bytes memory data) internal pure returns (string memory) {
        string memory hexString = vm.toString(data);

        uint256 expectedLength = data.length * 2 + 2;
        bytes memory hexBytes = bytes(hexString);
        if (hexBytes.length != expectedLength || hexBytes[0] != bytes1("0") || hexBytes[1] != bytes1("x")) {
            revert UnexpectedHexString(hexString, expectedLength);
        }

        assembly ("memory-safe") {
            // Remove the leading 0x which is unconditionally added by
            // vm.toString.
            let newHexString := add(hexString, 2)
            mstore(newHexString, sub(mload(hexString), 2))
            hexString := newHexString
        }
        return hexString;
    }
}

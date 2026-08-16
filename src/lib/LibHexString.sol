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

        bool stripped;
        assembly ("memory-safe") {
            let len := mload(hexString)
            // The length is checked first and the prefix is only read inside
            // it, because `and` in Yul evaluates both arms. `expectedLength` is
            // at least 2, so a length that matches it guarantees the word read
            // below is within the string's own allocation.
            if eq(len, expectedLength) {
                // The first two bytes of the data word against "0x". One word
                // load rather than two indexed byte reads, and it reuses the
                // pointer the strip already needs.
                if eq(shr(240, mload(add(hexString, 0x20))), 0x3078) {
                    // Remove the leading 0x, which solidity does not always
                    // accept — such as in `hex"..."` literals.
                    let newHexString := add(hexString, 2)
                    mstore(newHexString, sub(len, 2))
                    hexString := newHexString
                    stripped := 1
                }
            }
        }

        // The revert stays in solidity: the error carries a dynamic string, and
        // hand-encoding one in assembly is a dozen lines of pointer arithmetic
        // for a build-time function where gas is not a consideration.
        if (!stripped) {
            revert UnexpectedHexString(hexString, expectedLength);
        }
        return hexString;
    }
}

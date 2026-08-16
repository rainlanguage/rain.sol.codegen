// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std-1.16.1/src/Vm.sol";

/// @dev `forge fmt`'s own `line_length` default. Written out here rather than
/// imported from `LibCodeGen` so that this reference does not move when the
/// library's constant does.
uint256 constant SLOW_LINE_LENGTH = 120;

/// @dev `forge fmt` breaks a too long constant declaration after the `=` and
/// indents the value by one `tab_width`, which also defaults to 4.
string constant SLOW_WRAP = "\n    ";

/// @title LibCodeGenSlow
/// @notice A deliberately naive reference for the constant declarations
/// `LibCodeGen` emits.
///
/// `LibCodeGen` decides whether to wrap by adding up magic numbers that stand in
/// for the literals it is about to concatenate. This reference instead builds
/// the unwrapped line and measures it, so the two agree only when every one of
/// those magic numbers is right. Every string here is spelled out again rather
/// than imported, so a change to a literal in `LibCodeGen` shows up as a
/// disagreement instead of moving both sides at once.
///
/// The empty comment case is the one place the two sides state the same rule
/// rather than deriving it independently: a declaration is preceded by one
/// blank line, and by a comment line only when there is a comment. The exact
/// text of both cases is pinned separately by literal assertions, so this
/// reference is not the only thing holding it.
library LibCodeGenSlow {
    /// `vm.toString` on a `bytes` always prefixes `0x`, which a `hex"..."`
    /// literal must not carry. Dropped by copying the tail one byte at a time so
    /// the expectation owes nothing to `LibHexString`.
    function hexOfSlow(Vm vm, bytes memory data) internal pure returns (string memory) {
        bytes memory prefixed = bytes(vm.toString(data));
        bytes memory stripped = new bytes(prefixed.length - 2);
        for (uint256 i = 2; i < prefixed.length; i++) {
            stripped[i - 2] = prefixed[i];
        }
        return string(stripped);
    }

    /// Joins the declaration onto one line when it fits, and onto two when it
    /// does not. `declaration` is everything up to and including the `=`, and
    /// `value` is everything after it.
    function joinSlow(string memory declaration, string memory value) internal pure returns (string memory) {
        string memory oneLine = string.concat(declaration, " ", value);
        if (bytes(oneLine).length > SLOW_LINE_LENGTH) {
            return string.concat(declaration, SLOW_WRAP, value);
        }
        return oneLine;
    }

    function bytesConstantStringSlow(Vm vm, string memory comment, string memory name, bytes memory data)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            bytes(comment).length == 0 ? "\n" : string.concat("\n", comment, "\n"),
            joinSlow(string.concat("bytes constant ", name, " ="), string.concat("hex\"", hexOfSlow(vm, data), "\";")),
            "\n"
        );
    }

    function uint8ConstantStringSlow(Vm vm, string memory comment, string memory name, uint8 data)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            bytes(comment).length == 0 ? "\n" : string.concat("\n", comment, "\n"),
            joinSlow(string.concat("uint8 constant ", name, " ="), string.concat(vm.toString(uint256(data)), ";")),
            "\n"
        );
    }

    function bytes32ConstantStringSlow(Vm vm, string memory comment, string memory name, bytes32 data)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            bytes(comment).length == 0 ? "\n" : string.concat("\n", comment, "\n"),
            joinSlow(
                string.concat("bytes32 constant ", name, " ="), string.concat("bytes32(", vm.toString(data), ");")
            ),
            "\n"
        );
    }

    function addressConstantStringSlow(Vm vm, string memory comment, string memory name, address data)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            bytes(comment).length == 0 ? "\n" : string.concat("\n", comment, "\n"),
            joinSlow(
                string.concat("address constant ", name, " ="), string.concat("address(", vm.toString(data), ");")
            ),
            "\n"
        );
    }

    /// The length of the longest line in `text`, so a test can assert what
    /// `forge fmt` would measure rather than what the library predicted.
    function longestLineSlow(string memory text) internal pure returns (uint256) {
        bytes memory data = bytes(text);
        uint256 longest = 0;
        uint256 current = 0;
        for (uint256 i = 0; i < data.length; i++) {
            if (data[i] == 0x0a) {
                if (current > longest) {
                    longest = current;
                }
                current = 0;
            } else {
                current++;
            }
        }
        if (current > longest) {
            longest = current;
        }
        return longest;
    }

    /// A name of `length` repeated `A` characters, for pinning the wrap decision
    /// either side of the maximum line length without spelling out a name that
    /// nobody can count by eye.
    function nameOfLengthSlow(uint256 length) internal pure returns (string memory) {
        bytes memory name = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            name[i] = "A";
        }
        return string(name);
    }
}

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

/// @dev Every character a Solidity identifier may begin with, spelled out one by
/// one rather than as byte ranges. `LibCodeGen.requireContractName` decides with
/// range comparisons, so an off by one at either end of a range shows up here as
/// a disagreement instead of moving both sides at once.
string constant SLOW_HEAD_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_$";

/// @dev Every character a Solidity identifier may continue with: the head
/// alphabet and the decimal digits.
string constant SLOW_TAIL_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_$0123456789";

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
/// The lines that precede a declaration are assembled here from the rule they
/// follow: one blank line always, and a comment line only when there is a
/// comment. The exact text of both cases is pinned separately by literal
/// assertions, so this reference is not the only thing holding it.
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

    /// The lines that precede a declaration, listed out and then joined one
    /// newline terminated line at a time: a blank line always, and a comment
    /// line only when there is a comment. `LibCodeGen.commentPrefix` instead
    /// chooses between two whole prefix literals, so the two agree only when
    /// both the number of lines and the text of each one is right.
    function commentPrefixSlow(string memory comment) internal pure returns (string memory) {
        string[] memory lines = new string[](bytes(comment).length == 0 ? 1 : 2);
        lines[0] = "";
        if (lines.length == 2) {
            lines[1] = comment;
        }
        string memory prefix = "";
        for (uint256 i = 0; i < lines.length; i++) {
            prefix = string.concat(prefix, lines[i], "\n");
        }
        return prefix;
    }

    function bytesConstantStringSlow(Vm vm, string memory comment, string memory name, bytes memory data)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            commentPrefixSlow(comment),
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
            commentPrefixSlow(comment),
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
            commentPrefixSlow(comment),
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
            commentPrefixSlow(comment),
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

    /// True if `char` appears anywhere in `alphabet`.
    function containsSlow(string memory alphabet, bytes1 char) internal pure returns (bool) {
        bytes memory alphabetBytes = bytes(alphabet);
        for (uint256 i = 0; i < alphabetBytes.length; i++) {
            if (alphabetBytes[i] == char) {
                return true;
            }
        }
        return false;
    }

    /// True if `name` is a Solidity identifier, decided by membership of the
    /// written out alphabets rather than by arithmetic.
    function isContractNameSlow(string memory name) internal pure returns (bool) {
        bytes memory nameBytes = bytes(name);
        if (nameBytes.length == 0) {
            return false;
        }
        if (!containsSlow(SLOW_HEAD_ALPHABET, nameBytes[0])) {
            return false;
        }
        for (uint256 i = 1; i < nameBytes.length; i++) {
            if (!containsSlow(SLOW_TAIL_ALPHABET, nameBytes[i])) {
                return false;
            }
        }
        return true;
    }

    /// Folds arbitrary bytes into a name that is a Solidity identifier, so that
    /// the accepted half of the domain can be fuzzed at all. Random bytes are
    /// essentially never an identifier, so fuzzing names directly only ever
    /// exercises rejection, and a property stated over accepted names has to
    /// build them rather than wait for them.
    function nameFromSeedSlow(bytes memory seed) internal pure returns (string memory) {
        bytes memory head = bytes(SLOW_HEAD_ALPHABET);
        bytes memory tail = bytes(SLOW_TAIL_ALPHABET);
        uint256 length = seed.length == 0 ? 1 : seed.length;
        bytes memory name = new bytes(length);
        name[0] = head[(seed.length == 0 ? 0 : uint256(uint8(seed[0]))) % head.length];
        for (uint256 i = 1; i < length; i++) {
            name[i] = tail[uint256(uint8(seed[i])) % tail.length];
        }
        return string(name);
    }
}

// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

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

/// @dev The lowercase hex digits, indexed by the nibble each one spells.
string constant SLOW_HEX_ALPHABET = "0123456789abcdef";

/// Thrown when a slice is asked for between delimiters that the text does not
/// carry in that order.
/// @param text The text that was searched.
/// @param open The delimiter the slice starts after.
/// @param close The delimiter the slice ends before.
error NoSlice(string text, string open, string close);

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

    /// The EIP-55 checksummed hex string for `data`: `0x`, then the forty
    /// lowercase hex digits of the address, each letter uppercased when the
    /// nibble at the same position of the keccak256 hash of those forty digits
    /// is 8 or more. The digits come from the address's own bits rather than
    /// from `vm.toString`, so this disagrees with the cheatcode instead of
    /// restating it.
    function checksumAddressSlow(address data) internal pure returns (string memory) {
        bytes memory alphabet = bytes(SLOW_HEX_ALPHABET);
        bytes memory lower = new bytes(40);
        for (uint256 i = 0; i < 40; i++) {
            lower[39 - i] = alphabet[(uint256(uint160(data)) >> (4 * i)) & 0x0F];
        }

        bytes32 hash = keccak256(lower);
        bytes memory checksummed = new bytes(42);
        checksummed[0] = "0";
        checksummed[1] = "x";
        for (uint256 i = 0; i < 40; i++) {
            bytes1 digit = lower[i];
            uint8 nibble = i % 2 == 0 ? uint8(hash[i / 2]) >> 4 : uint8(hash[i / 2]) & 0x0F;
            checksummed[i + 2] = digit > "9" && nibble > 7 ? bytes1(uint8(digit) - 32) : digit;
        }
        return string(checksummed);
    }

    /// The index of the first `needle` in `haystack` at or after `from`, or
    /// `haystack.length` when there is none.
    function indexOfSlow(bytes memory haystack, bytes memory needle, uint256 from) internal pure returns (uint256) {
        for (uint256 i = from; i + needle.length <= haystack.length; i++) {
            bool matched = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (haystack[i + j] != needle[j]) {
                    matched = false;
                    break;
                }
            }
            if (matched) {
                return i;
            }
        }
        return haystack.length;
    }

    /// The text between the first `open` in `text` and the first `close` after
    /// it, so a test can state a property of the literal a declaration carries
    /// rather than of a value the test formatted for itself. Reverts when
    /// either delimiter is missing, so text that does not carry the literal at
    /// all fails rather than yielding an empty slice.
    function betweenSlow(string memory text, string memory open, string memory close)
        internal
        pure
        returns (string memory)
    {
        bytes memory textBytes = bytes(text);
        bytes memory openBytes = bytes(open);
        bytes memory closeBytes = bytes(close);

        uint256 openIndex = indexOfSlow(textBytes, openBytes, 0);
        if (openIndex == textBytes.length) {
            revert NoSlice(text, open, close);
        }

        uint256 start = openIndex + openBytes.length;
        uint256 end = indexOfSlow(textBytes, closeBytes, start);
        if (end == textBytes.length) {
            revert NoSlice(text, open, close);
        }

        bytes memory slice = new bytes(end - start);
        for (uint256 i = 0; i < slice.length; i++) {
            slice[i] = textBytes[start + i];
        }
        return string(slice);
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

    /// True if `tag` is drawn from the tag alphabet, decided by membership of
    /// the written out alphabet rather than by arithmetic. The tag alphabet is
    /// the identifier alphabet with no rule about the first character, which is
    /// exactly `SLOW_TAIL_ALPHABET`: a tail character is any character an
    /// identifier admits at all.
    function isTagSlow(string memory tag) internal pure returns (bool) {
        bytes memory tagBytes = bytes(tag);
        if (tagBytes.length == 0) {
            return false;
        }
        for (uint256 i = 0; i < tagBytes.length; i++) {
            if (!containsSlow(SLOW_TAIL_ALPHABET, tagBytes[i])) {
                return false;
            }
        }
        return true;
    }

    /// Folds arbitrary bytes into a tag, so that the accepted half of the tag
    /// domain can be fuzzed at all. Unlike `nameFromSeedSlow` the first
    /// character is drawn from the same alphabet as the rest, because a tag has
    /// no rule about its first character, so the digit opening tags such as
    /// `0_1_1` is reachable here.
    function tagFromSeedSlow(bytes memory seed) internal pure returns (string memory) {
        bytes memory alphabet = bytes(SLOW_TAIL_ALPHABET);
        uint256 length = seed.length == 0 ? 1 : seed.length;
        bytes memory tag = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            tag[i] = alphabet[(seed.length == 0 ? 0 : uint256(uint8(seed[i]))) % alphabet.length];
        }
        return string(tag);
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

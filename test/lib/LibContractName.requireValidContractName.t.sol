// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {InvalidContractName} from "src/lib/LibContractName.sol";
import {LibContractNameExternal} from "test/concrete/LibContractNameExternal.sol";
import {LibContractNameSlow, SLOW_HEAD_ALPHABET, SLOW_TAIL_ALPHABET} from "test/lib/LibContractNameSlow.sol";

/// @title LibContractNameRequireValidContractNameTest
/// @notice The accepted set is what confines a generated file to one path
/// segment inside the generated directory, so it is asserted as a set rather
/// than by example: every single byte is checked in both the leading and the
/// trailing position, and the rejected names that motivate the check are pinned
/// by name as well.
contract LibContractNameRequireValidContractNameTest is Test {
    LibContractNameExternal internal immutable iExternal;

    constructor() {
        iExternal = new LibContractNameExternal();
    }

    /// The name is rejected, and the error carries the name that was rejected
    /// so a build failure names the offending input.
    function assertRejected(string memory contractName) internal {
        vm.expectRevert(abi.encodeWithSelector(InvalidContractName.selector, contractName));
        iExternal.requireValidContractName(contractName);
    }

    /// The name is accepted, i.e. the call does not revert.
    function assertAccepted(string memory contractName) internal view {
        iExternal.requireValidContractName(contractName);
    }

    /// An empty name is `src/generated/.sol`: a hidden file that no compiler
    /// picks up as a contract, written by a build that reports success.
    function testRequireValidContractNameRejectsEmpty() external {
        assertRejected("");
    }

    /// A separator puts the file in a subdirectory of the generated directory
    /// rather than in it.
    function testRequireValidContractNameRejectsSeparator() external {
        assertRejected("/");
        assertRejected("/Foo");
        assertRejected("Foo/");
        assertRejected("sub/Foo");
    }

    /// A relative directory reference leaves the generated directory entirely,
    /// and whether that write lands is then decided by the consumer's
    /// `fs_permissions` rather than by this library.
    function testRequireValidContractNameRejectsTraversal() external {
        assertRejected("..");
        assertRejected("../Foo");
        assertRejected("../../ESCAPED");
    }

    /// A dot anywhere makes the name something other than a bare contract name:
    /// a hidden file, a current directory reference, or a second extension in
    /// front of the `.sol` this library appends.
    function testRequireValidContractNameRejectsDots() external {
        assertRejected(".");
        assertRejected(".hidden");
        assertRejected("Foo.sol");
        assertRejected("Foo.Bar");
    }

    /// A Solidity identifier cannot start with a digit, so neither can a
    /// contract name.
    function testRequireValidContractNameRejectsLeadingDigit() external {
        assertRejected("0");
        assertRejected("1Foo");
        assertRejected("9_");
    }

    /// Whitespace, control characters and a trailing NUL are all names a shell
    /// or a filesystem treats as something other than what was written.
    function testRequireValidContractNameRejectsWhitespaceAndControl() external {
        assertRejected(" ");
        assertRejected("Foo Bar");
        assertRejected("Foo\t");
        assertRejected("Foo\n");
        assertRejected(string(bytes.concat(bytes("Foo"), bytes1(0x00))));
    }

    /// Bytes outside ASCII are not identifier characters, including the
    /// continuation bytes of a well formed UTF-8 sequence.
    function testRequireValidContractNameRejectsNonAscii() external {
        // "Fooé" as UTF-8.
        assertRejected(string(bytes.concat(bytes("Foo"), hex"c3a9")));
        assertRejected(string(bytes.concat(bytes("Foo"), bytes1(0x80))));
        assertRejected(string(bytes.concat(bytes("Foo"), bytes1(0xff))));
    }

    /// Shell metacharacters and Solidity syntax characters are both outside the
    /// identifier alphabet, so neither a glob nor a quote can reach a path or a
    /// declaration.
    function testRequireValidContractNameRejectsPunctuation() external {
        assertRejected("*");
        assertRejected("Foo*");
        assertRejected("Foo-Bar");
        assertRejected("Foo;Bar");
        assertRejected("Foo\"Bar");
        assertRejected("Foo\\Bar");
        assertRejected("~");
    }

    /// The whole identifier alphabet is accepted, in both the leading position
    /// and after it, including the two characters that are not letters.
    function testRequireValidContractNameAcceptsIdentifiers() external view {
        assertAccepted("Foo");
        assertAccepted("F");
        assertAccepted("_");
        assertAccepted("$");
        assertAccepted("_Foo");
        assertAccepted("$Foo");
        assertAccepted("Foo1");
        assertAccepted("Foo_Bar$0");
        assertAccepted("ABCDEFGHIJKLMNOPQRSTUVWXYZ");
        assertAccepted("abcdefghijklmnopqrstuvwxyz");
        assertAccepted("A0123456789");
    }

    /// Exhaustive over the leading byte: all 256 of them, accepted exactly when
    /// the byte is in the head alphabet. Nothing about the boundaries of the
    /// accepted ranges is left to a chosen example.
    function testRequireValidContractNameEveryLeadingByte() external {
        for (uint256 i = 0; i < 256; i++) {
            string memory name = string(bytes.concat(bytes1(uint8(i))));
            if (LibContractNameSlow.containsSlow(SLOW_HEAD_ALPHABET, bytes1(uint8(i)))) {
                assertAccepted(name);
            } else {
                assertRejected(name);
            }
        }
    }

    /// Exhaustive over the trailing byte, behind a leading byte that is itself
    /// accepted. The digits separate this from the leading case: they are
    /// accepted here and rejected there.
    function testRequireValidContractNameEveryTrailingByte() external {
        for (uint256 i = 0; i < 256; i++) {
            string memory name = string(bytes.concat(bytes("A"), bytes1(uint8(i))));
            if (LibContractNameSlow.containsSlow(SLOW_TAIL_ALPHABET, bytes1(uint8(i)))) {
                assertAccepted(name);
            } else {
                assertRejected(name);
            }
        }
    }

    /// Over arbitrary names of arbitrary length, acceptance agrees with the
    /// reference alphabet exactly. The reference is written out character by
    /// character, so this fails if either end of either range moves.
    function testRequireValidContractNameMatchesAlphabet(bytes memory nameBytes) external {
        string memory contractName = string(nameBytes);
        if (LibContractNameSlow.isValidContractNameSlow(contractName)) {
            assertAccepted(contractName);
        } else {
            assertRejected(contractName);
        }
    }

    /// Names built to be identifiers are accepted at any length, so the check is
    /// not passing everything through a length that happens to be short or
    /// rejecting everything of a length it has not seen.
    function testRequireValidContractNameAcceptsGeneratedIdentifiers(bytes memory seed) external view {
        string memory contractName = LibContractNameSlow.nameFromSeedSlow(seed);
        assertTrue(bytes(contractName).length > 0, "generated an empty name");
        assertAccepted(contractName);
    }

    /// A single byte outside the alphabet is enough to reject a name that is
    /// otherwise an identifier, wherever in the name it sits. A check that only
    /// looked at the first or the last character would pass this.
    function testRequireValidContractNameRejectsOneBadByte(bytes memory seed, uint256 position, uint8 badByte)
        external
    {
        string memory valid = LibContractNameSlow.nameFromSeedSlow(seed);
        bytes memory nameBytes = bytes(valid);
        vm.assume(!LibContractNameSlow.containsSlow(SLOW_TAIL_ALPHABET, bytes1(badByte)));
        nameBytes[position % nameBytes.length] = bytes1(badByte);
        assertRejected(string(nameBytes));
    }
}

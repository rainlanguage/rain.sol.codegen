// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibCodeGen, InvalidIdentifier} from "src/lib/LibCodeGen.sol";
import {LibCodeGenSlow, SLOW_HEAD_ALPHABET, SLOW_TAIL_ALPHABET} from "test/lib/LibCodeGenSlow.sol";

/// @title LibCodeGenRequireIdentifierTest
/// @notice `requireIdentifier` is what stands between a caller supplied name and
/// the filesystem path or the generated declaration built out of it. The rule it
/// enforces is the Solidity identifier: that is what a contract name and a
/// constant name both are, and it is also a character set that cannot express a
/// path separator, a parent directory, an empty basename, or a character that
/// ends one declaration and starts another.
contract LibCodeGenRequireIdentifierTest is Test {
    /// Reachable only through an external call so that the revert can be caught
    /// rather than aborting the test.
    function callRequireIdentifier(string memory name) external pure {
        LibCodeGen.requireIdentifier(name);
    }

    function assertAccepted(string memory name) internal view {
        this.callRequireIdentifier(name);
    }

    function assertRejected(string memory name) internal {
        vm.expectRevert(abi.encodeWithSelector(InvalidIdentifier.selector, name));
        this.callRequireIdentifier(name);
    }

    /// The names real consumers pass. Every `script/Build.sol` in the Rain org
    /// passes the concrete contract's own name, so these are the shape that must
    /// keep working.
    function testRequireIdentifierAcceptsContractNames() external view {
        assertAccepted("CodeGennable");
        assertAccepted("PythWords");
        assertAccepted("RaindexV6SubParser");
        assertAccepted("RainlangExpressionDeployer");
    }

    /// Every character class Solidity allows in an identifier, at both the first
    /// position and a later one, so the rule is Solidity's rather than a
    /// narrower guess at it.
    function testRequireIdentifierAcceptsIdentifierCharacters() external view {
        assertAccepted("A");
        assertAccepted("z");
        assertAccepted("_");
        assertAccepted("$");
        assertAccepted("_Foo");
        assertAccepted("$Foo");
        assertAccepted("Foo_Bar");
        assertAccepted("Foo$Bar");
        assertAccepted("Foo0");
        assertAccepted("F0o_$9");
    }

    /// Each of the three character ranges is closed at exactly its ends. Pinned
    /// from both sides: the first and last character of every range is
    /// accepted, and the character immediately outside each end is refused.
    /// A range that runs one past either of its ends admits one of the six
    /// characters sitting against them: at sign, `[`, backtick, `{`, `/` or
    /// `:` — none of which belongs in an identifier, and one of which is a
    /// path separator. Nothing else in this suite distinguishes those six from
    /// the ranges they sit against, because a name has to be an identifier
    /// apart from the one character under test for the boundary to be what
    /// decides it.
    function testRequireIdentifierRangeBoundaries() external {
        assertAccepted("A");
        assertAccepted("Z");
        assertAccepted("a");
        assertAccepted("z");
        assertAccepted("A0");
        assertAccepted("A9");
        assertRejected("@");
        assertRejected("[");
        assertRejected("`");
        assertRejected("{");
        assertRejected("A/");
        assertRejected("A:");
    }

    /// An empty name would build `src/generated/.sol` and `meta/.rain.meta`:
    /// hidden dotfiles that no compiler picks up and `ls` does not show, written
    /// with a success report.
    function testRequireIdentifierRejectsEmpty() external {
        assertRejected("");
    }

    /// A digit cannot open a Solidity identifier, so it cannot open a contract
    /// name either.
    function testRequireIdentifierRejectsLeadingDigit() external {
        assertRejected("0Foo");
        assertRejected("9");
    }

    /// A separator would target a subdirectory, and `..` would escape the
    /// generated directory entirely. Both are refused by the character rule
    /// rather than by a special case for them.
    function testRequireIdentifierRejectsPathCharacters() external {
        assertRejected("sub/Foo");
        assertRejected("..");
        assertRejected(".");
        assertRejected("../../ESCAPED");
        assertRejected("../src/generated/X");
        assertRejected("/Foo");
        assertRejected("Foo/");
        assertRejected("Foo\\Bar");
    }

    /// A name that is otherwise fine but carries anything outside the identifier
    /// set is refused. A dot in particular would collide with the extension the
    /// caller appends.
    function testRequireIdentifierRejectsOtherCharacters() external {
        assertRejected("Foo.sol");
        assertRejected("Foo Bar");
        assertRejected("Foo-Bar");
        assertRejected("Foo\n");
        assertRejected(unicode"Foo€");
        assertRejected(string(hex"466f6f00"));
    }

    /// The rejection carries the name that was rejected, so a build script that
    /// generates many files says which one it choked on.
    function testRequireIdentifierErrorCarriesTheName() external {
        vm.expectRevert(abi.encodeWithSelector(InvalidIdentifier.selector, "sub/Foo"));
        this.callRequireIdentifier("sub/Foo");
    }

    /// Accepting a name is exactly accepting every one of its bytes, so an
    /// accepted name can be rebuilt from the identifier alphabet and nothing
    /// else. Fuzzed so that the check is not merely rejecting the handful of
    /// bad names spelled out above.
    function testRequireIdentifierAcceptedNamesAreIdentifiers(string memory name) external {
        bytes memory nameBytes = bytes(name);
        bool expectedValid = nameBytes.length > 0;
        for (uint256 i = 0; i < nameBytes.length; i++) {
            bytes1 char = nameBytes[i];
            bool isLetter = (char >= "A" && char <= "Z") || (char >= "a" && char <= "z");
            bool isDigit = char >= "0" && char <= "9";
            bool isUnderscoreOrDollar = char == "_" || char == "$";
            if (!(isLetter || isUnderscoreOrDollar || (isDigit && i > 0))) {
                expectedValid = false;
                break;
            }
        }

        if (expectedValid) {
            this.callRequireIdentifier(name);
        } else {
            vm.expectRevert(abi.encodeWithSelector(InvalidIdentifier.selector, name));
            this.callRequireIdentifier(name);
        }
    }

    /// No accepted name contains a byte that means anything to a filesystem, so
    /// no accepted name can leave the directory it is interpolated into. Stated
    /// as a property of the accepted set rather than as a list of the sequences
    /// that would escape.
    function testRequireIdentifierAcceptedNamesCannotTraverse(string memory name) external {
        try this.callRequireIdentifier(name) {
            bytes memory nameBytes = bytes(name);
            assertGt(nameBytes.length, 0, "empty name accepted");
            for (uint256 i = 0; i < nameBytes.length; i++) {
                assertNotEq(uint8(nameBytes[i]), uint8(bytes1("/")), "separator accepted");
                assertNotEq(uint8(nameBytes[i]), uint8(bytes1("\\")), "backslash accepted");
                assertNotEq(uint8(nameBytes[i]), uint8(bytes1(".")), "dot accepted");
                assertNotEq(uint8(nameBytes[i]), uint8(bytes1(hex"00")), "nul accepted");
            }
        } catch {}
    }

    /// Exhaustive over the leading byte: all 256 of them, accepted exactly when
    /// the byte is in the head alphabet. Nothing about the boundaries of the
    /// accepted ranges is left to a chosen example, and the oracle is the
    /// alphabet written out character by character rather than the same range
    /// arithmetic the library uses.
    function testRequireIdentifierEveryLeadingByte() external {
        for (uint256 i = 0; i < 256; i++) {
            string memory name = string(bytes.concat(bytes1(uint8(i))));
            if (LibCodeGenSlow.containsSlow(SLOW_HEAD_ALPHABET, bytes1(uint8(i)))) {
                assertAccepted(name);
            } else {
                assertRejected(name);
            }
        }
    }

    /// Exhaustive over the trailing byte, behind a leading byte that is itself
    /// accepted. The digits separate this from the leading case: they are
    /// accepted here and rejected there.
    function testRequireIdentifierEveryTrailingByte() external {
        for (uint256 i = 0; i < 256; i++) {
            string memory name = string(bytes.concat(bytes("A"), bytes1(uint8(i))));
            if (LibCodeGenSlow.containsSlow(SLOW_TAIL_ALPHABET, bytes1(uint8(i)))) {
                assertAccepted(name);
            } else {
                assertRejected(name);
            }
        }
    }

    /// Over arbitrary names of arbitrary length, acceptance agrees with the
    /// reference alphabet exactly. The reference is spelled out character by
    /// character, so this fails if either end of any range moves, rather than
    /// following the library the way an inlined copy of its own arithmetic
    /// would.
    function testRequireIdentifierMatchesAlphabet(bytes memory nameBytes) external {
        string memory name = string(nameBytes);
        if (LibCodeGenSlow.isIdentifierSlow(name)) {
            assertAccepted(name);
        } else {
            assertRejected(name);
        }
    }

    /// Names built to be identifiers are accepted at any length and across the
    /// whole alphabet. Fuzzing a name directly essentially never produces an
    /// identifier, so without constructing them the accepted half of the domain
    /// is never exercised at all and a check that rejected everything would
    /// still pass.
    function testRequireIdentifierAcceptsGeneratedIdentifiers(bytes memory seed) external view {
        string memory name = LibCodeGenSlow.nameFromSeedSlow(seed);
        assertTrue(bytes(name).length > 0, "generated an empty name");
        assertAccepted(name);
    }

    /// A single byte outside the alphabet is enough to reject a name that is
    /// otherwise an identifier, wherever in the name it sits. A check that only
    /// looked at the first or the last character would pass this.
    function testRequireIdentifierRejectsOneBadByte(bytes memory seed, uint256 position, uint8 badByte) external {
        bytes memory nameBytes = bytes(LibCodeGenSlow.nameFromSeedSlow(seed));
        vm.assume(!LibCodeGenSlow.containsSlow(SLOW_TAIL_ALPHABET, bytes1(badByte)));
        nameBytes[position % nameBytes.length] = bytes1(badByte);
        assertRejected(string(nameBytes));
    }
}

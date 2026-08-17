// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {LibFs, InvalidTag} from "src/lib/LibFs.sol";
import {LibCodeGen, InvalidContractName} from "src/lib/LibCodeGen.sol";
import {LibCodeGenSlow, SLOW_TAIL_ALPHABET} from "test/lib/LibCodeGenSlow.sol";

/// @title LibFsRequireTagTest
/// @notice `requireTag` is what stands between a caller supplied tag and a
/// directory path built out of it. The rule it enforces is the Solidity
/// identifier alphabet with no rule about the first character: that admits the
/// `<major>_<minor>_<patch>` release tags whose whole point is to open with a
/// digit, and it is still a character set that cannot express a path separator,
/// a parent directory or an empty segment.
contract LibFsRequireTagTest is Test {
    /// Reachable only through an external call so that the revert can be caught
    /// rather than aborting the test.
    function callRequireTag(string memory tag) external pure {
        LibFs.requireTag(tag);
    }

    /// `requireContractName` behind a call frame too, so the two rules can be
    /// asserted to disagree on the same string.
    function callRequireContractName(string memory name) external pure {
        LibCodeGen.requireContractName(name);
    }

    function assertAccepted(string memory tag) internal view {
        this.callRequireTag(tag);
    }

    function assertRejected(string memory tag) internal {
        vm.expectRevert(abi.encodeWithSelector(InvalidTag.selector, tag));
        this.callRequireTag(tag);
    }

    /// The tags real consumers write. `frozen-snapshots-append-only` in the
    /// shared CI recognises a frozen snapshot directory by exactly the
    /// `<digits>_<digits>_<digits>` shape, and a deploy repo carries a rolling
    /// `candidate` directory beside the frozen ones, so these are the shapes
    /// that have to be accepted for the layout to be reachable at all.
    function testRequireTagAcceptsReleaseTags() external view {
        assertAccepted("0_1_1");
        assertAccepted("0_1_4");
        assertAccepted("0_1_10");
        assertAccepted("12_0_255");
        assertAccepted("candidate");
    }

    /// A tag opening with a digit is the case that separates this rule from
    /// `requireContractName`, which refuses one because a Solidity identifier
    /// cannot open with a digit. Both verdicts on the same string are asserted
    /// here, so collapsing the two rules into one fails.
    function testRequireTagAcceptsLeadingDigitContractNameDoesNot() external {
        assertAccepted("0_1_1");
        vm.expectRevert(abi.encodeWithSelector(InvalidContractName.selector, "0_1_1"));
        this.callRequireContractName("0_1_1");
    }

    /// Every character class the tag alphabet allows, at both the first
    /// position and a later one.
    function testRequireTagAcceptsAlphabetCharacters() external view {
        assertAccepted("A");
        assertAccepted("z");
        assertAccepted("_");
        assertAccepted("$");
        assertAccepted("0");
        assertAccepted("9");
        assertAccepted("_0_1_1");
        assertAccepted("$tag");
        assertAccepted("v0_1_1");
        assertAccepted("0");
    }

    /// Each of the three character ranges is closed at exactly its ends. Pinned
    /// from both sides: the first and last character of every range is
    /// accepted, and the character immediately outside each end is refused.
    /// A range that runs one past either of its ends admits one of the six
    /// characters sitting against them: at sign, `[`, backtick, `{`, `/` or
    /// `:` — one of which is a path separator.
    function testRequireTagRangeBoundaries() external {
        assertAccepted("A");
        assertAccepted("Z");
        assertAccepted("a");
        assertAccepted("z");
        assertAccepted("0");
        assertAccepted("9");
        assertRejected("@");
        assertRejected("[");
        assertRejected("`");
        assertRejected("{");
        assertRejected("/");
        assertRejected(":");
    }

    /// An empty tag would build `src/generated//Foo.sol`, which resolves to the
    /// untagged path and so silently overwrites a file that belongs to no
    /// snapshot.
    function testRequireTagRejectsEmpty() external {
        assertRejected("");
    }

    /// A separator would reach a deeper directory, and `..` would escape the
    /// generated directory entirely. Both are refused by the character rule
    /// rather than by a special case for them.
    function testRequireTagRejectsPathCharacters() external {
        assertRejected("..");
        assertRejected(".");
        assertRejected("0_1_1/sub");
        assertRejected("../../ESCAPED");
        assertRejected("/0_1_1");
        assertRejected("0_1_1/");
        assertRejected("/");
        assertRejected("0_1_1\\sub");
        assertRejected(".hidden");
    }

    /// A tag that is otherwise fine but carries anything outside the alphabet
    /// is refused. The version separators consumers might reach for first are
    /// the ones that matter: `0.1.1` carries dots and `0-1-1` a dash.
    function testRequireTagRejectsOtherCharacters() external {
        assertRejected("0.1.1");
        assertRejected("0-1-1");
        assertRejected("0 1 1");
        assertRejected("0_1_1\n");
        assertRejected(unicode"tag€");
        assertRejected(string(hex"7461670a"));
        assertRejected(string(hex"74616700"));
    }

    /// The rejection carries the tag that was rejected, so a build script that
    /// generates many files says which one it choked on.
    function testRequireTagErrorCarriesTheTag() external {
        vm.expectRevert(abi.encodeWithSelector(InvalidTag.selector, "0.1.1"));
        this.callRequireTag("0.1.1");
    }

    /// Exhaustive over the single byte of a one character tag: all 256 of them,
    /// accepted exactly when the byte is in the alphabet. Nothing about the
    /// boundaries of the accepted ranges is left to a chosen example, and the
    /// oracle is the alphabet written out character by character rather than
    /// the same range arithmetic the library uses.
    function testRequireTagEveryLeadingByte() external {
        for (uint256 i = 0; i < 256; i++) {
            string memory tag = string(bytes.concat(bytes1(uint8(i))));
            if (LibCodeGenSlow.containsSlow(SLOW_TAIL_ALPHABET, bytes1(uint8(i)))) {
                assertAccepted(tag);
            } else {
                assertRejected(tag);
            }
        }
    }

    /// Exhaustive over the trailing byte, behind a leading byte that is itself
    /// accepted. The same alphabet decides both positions, which is what makes
    /// a tag differ from a contract name.
    function testRequireTagEveryTrailingByte() external {
        for (uint256 i = 0; i < 256; i++) {
            string memory tag = string(bytes.concat(bytes("0"), bytes1(uint8(i))));
            if (LibCodeGenSlow.containsSlow(SLOW_TAIL_ALPHABET, bytes1(uint8(i)))) {
                assertAccepted(tag);
            } else {
                assertRejected(tag);
            }
        }
    }

    /// Over arbitrary tags of arbitrary length, acceptance agrees with the
    /// reference alphabet exactly. The reference is spelled out character by
    /// character, so this fails if either end of any range moves, rather than
    /// following the library the way an inlined copy of its own arithmetic
    /// would.
    function testRequireTagMatchesAlphabet(bytes memory tagBytes) external {
        string memory tag = string(tagBytes);
        if (LibCodeGenSlow.isTagSlow(tag)) {
            assertAccepted(tag);
        } else {
            assertRejected(tag);
        }
    }

    /// Tags built from the alphabet are accepted at any length. Fuzzing a tag
    /// directly essentially never produces one, so without constructing them the
    /// accepted half of the domain is never exercised at all and a check that
    /// rejected everything would still pass.
    function testRequireTagAcceptsGeneratedTags(bytes memory seed) external view {
        string memory tag = LibCodeGenSlow.tagFromSeedSlow(seed);
        assertTrue(bytes(tag).length > 0, "generated an empty tag");
        assertAccepted(tag);
    }

    /// Every `<digits>_<digits>_<digits>` tag is accepted, which is the exact
    /// shape the shared CI's frozen snapshot check recognises as a release. Built
    /// from three arbitrary numbers rather than from the alphabet, so this states
    /// the cross repo contract rather than restating the character rule.
    function testRequireTagAcceptsEveryNumericReleaseTag(uint64 major, uint64 minor, uint64 patch) external view {
        assertAccepted(
            string.concat(
                vm.toString(uint256(major)), "_", vm.toString(uint256(minor)), "_", vm.toString(uint256(patch))
            )
        );
    }

    /// A single byte outside the alphabet is enough to reject a tag that is
    /// otherwise fine, wherever in the tag it sits. A check that only looked at
    /// the first or the last character would pass this.
    function testRequireTagRejectsOneBadByte(bytes memory seed, uint256 position, uint8 badByte) external {
        bytes memory tagBytes = bytes(LibCodeGenSlow.tagFromSeedSlow(seed));
        vm.assume(!LibCodeGenSlow.containsSlow(SLOW_TAIL_ALPHABET, bytes1(badByte)));
        tagBytes[position % tagBytes.length] = bytes1(badByte);
        assertRejected(string(tagBytes));
    }

    /// No accepted tag contains a byte that means anything to a filesystem, so
    /// no accepted tag can leave the directory it is interpolated into. Stated
    /// as a property of the accepted set rather than as a list of the sequences
    /// that would escape.
    function testRequireTagAcceptedTagsCannotTraverse(string memory tag) external {
        try this.callRequireTag(tag) {
            bytes memory tagBytes = bytes(tag);
            assertGt(tagBytes.length, 0, "empty tag accepted");
            for (uint256 i = 0; i < tagBytes.length; i++) {
                assertNotEq(uint8(tagBytes[i]), uint8(bytes1("/")), "separator accepted");
                assertNotEq(uint8(tagBytes[i]), uint8(bytes1("\\")), "backslash accepted");
                assertNotEq(uint8(tagBytes[i]), uint8(bytes1(".")), "dot accepted");
                assertNotEq(uint8(tagBytes[i]), uint8(bytes1(hex"00")), "nul accepted");
            }
        } catch {}
    }
}

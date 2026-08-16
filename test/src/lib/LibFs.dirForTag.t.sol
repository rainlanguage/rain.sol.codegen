// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibFs, GENERATED_DIR, InvalidTag} from "src/lib/LibFs.sol";
import {LibFsExternal} from "test/concrete/LibFsExternal.sol";
import {LibCodeGenSlow} from "test/lib/LibCodeGenSlow.sol";

/// @title LibFsDirForTagTest
/// @notice `dirForTag` is the only thing that puts a caller supplied tag into a
/// directory path, so it owns that half of the confinement: it reverts unless
/// the tag is drawn from the tag alphabet, and the directory it does return
/// carries that tag verbatim.
///
/// The properties below are split by domain rather than asserted over arbitrary
/// strings. Over the accepted domain, tags are CONSTRUCTED from the alphabet,
/// because an arbitrary string is essentially never a tag and filtering for one
/// would leave the property proven over nothing. Over the rejected domain,
/// arbitrary bytes are exactly the right generator, because that is what the
/// rejected domain is.
contract LibFsDirForTagTest is Test {
    /// `vm.expectRevert` needs a call frame, and `dirForTag` is an internal
    /// library function that is inlined into its caller.
    LibFsExternal internal immutable iExternal;

    constructor() {
        iExternal = new LibFsExternal();
    }

    /// A tag's files live in a directory named for the tag directly inside the
    /// generated directory. Pinned exactly because consumers commit this
    /// directory and import from it by path: the location is a cross repo
    /// contract, not an internal detail.
    function testDirForTag() external pure {
        assertEq(LibFs.dirForTag("0_1_1"), "src/generated/0_1_1");
        assertEq(LibFs.dirForTag("candidate"), "src/generated/candidate");
    }

    /// Copies `len` bytes out of `data` starting at `start`, so the structural
    /// assertions below can name each region of the directory independently
    /// rather than rebuilding it with the same `string.concat` the library uses
    /// and asserting it equals itself.
    function slice(bytes memory data, uint256 start, uint256 len) internal pure returns (bytes memory out) {
        out = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            out[i] = data[start + i];
        }
    }

    /// The directory is two regions and nothing else: the generated directory
    /// and the tag byte for byte. Asserted positionally over tags built from
    /// the alphabet, at every length, so that a tag is never quoted, escaped,
    /// trimmed, case folded or truncated on its way into the directory. The
    /// length equality is what makes it exhaustive: it forbids any extra byte
    /// anywhere.
    function testDirForTagStructure(bytes memory seed) external pure {
        string memory tag = LibCodeGenSlow.tagFromSeedSlow(seed);
        bytes memory dir = bytes(LibFs.dirForTag(tag));
        bytes memory tagBytes = bytes(tag);

        assertEq(dir.length, 14 + tagBytes.length, "directory has bytes beyond generated dir + tag");
        assertEq(slice(dir, 0, 14), bytes("src/generated/"), "generated directory");
        assertEq(slice(dir, 14, tagBytes.length), tagBytes, "tag is not verbatim");
    }

    /// Two tags must never be handed the same directory: a frozen snapshot
    /// would be overwritten by another release's generation. Distinct tags give
    /// distinct directories.
    function testDirForTagDistinctTagsDistinctDirs(bytes memory seedA, bytes memory seedB) external pure {
        string memory a = LibCodeGenSlow.tagFromSeedSlow(seedA);
        string memory b = LibCodeGenSlow.tagFromSeedSlow(seedB);
        vm.assume(keccak256(bytes(a)) != keccak256(bytes(b)));
        assertNotEq(LibFs.dirForTag(a), LibFs.dirForTag(b));
    }

    /// The directory is relative to the project root. An absolute path would
    /// resolve outside the consumer's repo entirely, so the first byte is never
    /// a separator.
    function testDirForTagIsRelative(bytes memory seed) external pure {
        bytes memory dir = bytes(LibFs.dirForTag(LibCodeGenSlow.tagFromSeedSlow(seed)));
        assertTrue(dir.length > 0, "empty directory");
        assertNotEq(uint8(dir[0]), uint8(bytes1("/")), "directory is absolute");
    }

    /// What the check buys: the directory built for a tag the library accepts is
    /// one segment directly inside the generated directory, with no dot in it at
    /// all. Asserted by counting, over generated tags, so no accepted tag can
    /// reach a deeper directory, a parent directory, or a hidden one.
    function testDirForTagAcceptedTagsStayInGeneratedDir(bytes memory seed) external pure {
        bytes memory dir = bytes(LibFs.dirForTag(LibCodeGenSlow.tagFromSeedSlow(seed)));
        bytes memory generated = bytes(GENERATED_DIR);

        uint256 separators = 0;
        for (uint256 i = 0; i < dir.length; i++) {
            if (dir[i] == "/") {
                separators++;
            }
            assertNotEq(uint8(dir[i]), uint8(bytes1(".")), "a dot in the directory");
        }
        uint256 generatedSeparators = 0;
        for (uint256 i = 0; i < generated.length; i++) {
            if (generated[i] == "/") {
                generatedSeparators++;
            }
        }
        assertEq(separators, generatedSeparators + 1, "the directory is not a direct child of the generated directory");
    }

    /// No directory is produced for the tag at all, and the error carries the
    /// tag that was rejected so a build failure says which one it was.
    function assertTagRejected(string memory tag) internal {
        vm.expectRevert(abi.encodeWithSelector(InvalidTag.selector, tag));
        iExternal.dirForTag(tag);
    }

    /// The tags that motivate the check get no directory, so a consumer that
    /// calls `dirForTag` and then does its own IO with the result cannot be
    /// handed one that escapes the generated directory or hides inside it.
    function testDirForTagRejectsNamedEscapes() external {
        // `src/generated/`: the generated directory itself, so a tagged write
        // would land on an untagged file.
        assertTagRejected("");
        // Leaves the generated directory.
        assertTagRejected("..");
        assertTagRejected("../../ESCAPED");
        assertTagRejected("../0_1_1");
        // Reaches a deeper directory of, or out of, the generated directory.
        assertTagRejected("0_1_1/sub");
        assertTagRejected("/0_1_1");
        assertTagRejected("0_1_1/");
        assertTagRejected("/");
        // Hidden.
        assertTagRejected(".");
        assertTagRejected(".hidden");
        // The version separators a consumer reaches for before the org's.
        assertTagRejected("0.1.1");
        assertTagRejected("0-1-1");
    }

    /// The whole rejected domain, not only the tags above: no string outside the
    /// alphabet produces a directory. Fuzzed over arbitrary bytes, which is the
    /// right generator here precisely because an arbitrary byte string is
    /// essentially never a tag.
    function testDirForTagRejectsEveryNonTag(bytes memory tagBytes) external {
        string memory tag = string(tagBytes);
        vm.assume(!LibCodeGenSlow.isTagSlow(tag));
        assertTagRejected(tag);
    }
}

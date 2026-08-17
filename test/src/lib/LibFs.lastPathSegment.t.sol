// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {LibFs} from "src/lib/LibFs.sol";

/// @title LibFsLastPathSegmentTest
/// @notice `lastPathSegment` is what turns a directory entry into the name to
/// compare against, so its result is the whole basis of that comparison: a
/// segment that keeps any of the directories above it, or drops any of the name
/// itself, compares against something that is not the file's name.
///
/// The property is asserted over arbitrary bytes rather than over paths,
/// because the function takes whatever `vm.readDir` reports and nothing
/// upstream of it constrains that to a shape. The cases below are the shapes
/// that carry a boundary: a name with no directory above it, an empty result, a
/// separator with nothing after it.
contract LibFsLastPathSegmentTest is Test {
    /// The absolute path a directory read reports, which is the input the
    /// library actually receives.
    function testLastPathSegmentAbsolutePath() external pure {
        assertEq(LibFs.lastPathSegment("/home/user/repo/src/generated/Foo.sol"), "Foo.sol");
    }

    /// The relative path `pathForContract` returns, which is the input the
    /// current artifact's name is taken from.
    function testLastPathSegmentRelativePath() external pure {
        assertEq(LibFs.lastPathSegment("src/generated/Foo.sol"), "Foo.sol");
    }

    /// A path with no separator at all is entirely its own final segment.
    function testLastPathSegmentNoSeparator() external pure {
        assertEq(LibFs.lastPathSegment("Foo.sol"), "Foo.sol");
        assertEq(LibFs.lastPathSegment(""), "");
    }

    /// Only the last separator counts, so repeated and empty intermediate
    /// segments are all above the name and none of them reach it.
    function testLastPathSegmentRepeatedSeparators() external pure {
        assertEq(LibFs.lastPathSegment("a//b///Foo.sol"), "Foo.sol");
    }

    /// A path ending in a separator has nothing after it, and an empty segment
    /// is the honest answer rather than the segment before it.
    function testLastPathSegmentTrailingSeparator() external pure {
        assertEq(LibFs.lastPathSegment("src/generated/"), "");
        assertEq(LibFs.lastPathSegment("/"), "");
    }

    /// The three halves of the definition, over arbitrary bytes: the result
    /// carries no separator, it is a suffix of the input, and it is the LONGEST
    /// such suffix, which is what pins it to the last separator rather than to
    /// any earlier one.
    function testLastPathSegmentIsTheSuffixAfterTheLastSeparator(bytes memory pathBytes) external pure {
        bytes memory segment = bytes(LibFs.lastPathSegment(string(pathBytes)));

        assertLe(segment.length, pathBytes.length, "segment is longer than the path");
        uint256 start = pathBytes.length - segment.length;
        for (uint256 i = 0; i < segment.length; i++) {
            assertTrue(segment[i] != "/", "segment carries a separator");
            assertTrue(segment[i] == pathBytes[start + i], "segment is not a suffix of the path");
        }
        if (start > 0) {
            assertTrue(pathBytes[start - 1] == "/", "segment does not start after a separator");
        }
    }
}

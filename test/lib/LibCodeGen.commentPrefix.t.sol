// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibCodeGen} from "src/lib/LibCodeGen.sol";
import {LibCodeGenSlow} from "./LibCodeGenSlow.sol";

/// @title LibCodeGenCommentPrefixTest
/// @notice `commentPrefix` is the one rule every constant declaration shares:
/// a blank line always, and a comment line only when there is a comment. The
/// library states it as a choice between two whole prefix literals, so these
/// assert it against a reference that assembles the prefix a line at a time,
/// and pin that reference's own two cases to literals so agreement between the
/// two is not the only thing holding either.
contract LibCodeGenCommentPrefixTest is Test {
    /// No comment is one blank line and nothing else. Two consecutive newlines
    /// here would be a blank line `forge fmt` collapses, which makes a
    /// regenerated file fail the consumer's `forge fmt --check`.
    function testCommentPrefixSlowEmptyComment() external pure {
        assertEq(LibCodeGenSlow.commentPrefixSlow(""), "\n");
    }

    /// A comment is a blank line, then the comment on a line of its own. The
    /// comment is emitted as given, so the caller owns whether it carries
    /// `///` and where it breaks.
    function testCommentPrefixSlowWithComment() external pure {
        assertEq(LibCodeGenSlow.commentPrefixSlow("/// @dev Some comment."), "\n/// @dev Some comment.\n");
    }

    /// Whatever the comment, the library emits the lines the reference
    /// assembles. Fuzzed over the comment because emptiness is the only thing
    /// the rule branches on and every other comment has to come back untouched.
    function testCommentPrefixMatchesSlow(string memory comment) external pure {
        assertEq(LibCodeGen.commentPrefix(comment), LibCodeGenSlow.commentPrefixSlow(comment));
    }
}

// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {MAX_LINE_LENGTH, NEWLINE_DUE_TO_MAX_LENGTH} from "src/lib/LibCodeGen.sol";

/// @title LibCodeGenMaxLineLengthTest
/// @notice `MAX_LINE_LENGTH` and `NEWLINE_DUE_TO_MAX_LENGTH` are the whole wrap
/// contract: the library emits lines it believes `forge fmt` leaves alone, and
/// an indent it believes `forge fmt` would itself have chosen. Both are
/// properties of the formatter, stated in `[fmt]` of `foundry.toml`, so these
/// read that file and assert the constants against what it states.
///
/// Nothing else in the repo compares the two. `rainix-copy-artifacts`
/// regenerates, runs `forge fmt`, then `git diff --exit-code`, so a formatter
/// that disagrees with these constants reflows the emitted text into the
/// committed baseline rather than reporting the disagreement.
contract LibCodeGenMaxLineLengthTest is Test {
    /// The line length the wrap arithmetic is computed against is the line
    /// length this repo's formatter is configured with.
    function testMaxLineLengthMatchesFormatterConfig() external view {
        string memory config = vm.readFile("foundry.toml");
        assertTrue(vm.keyExistsToml(config, ".fmt.line_length"), "foundry.toml states no [fmt] line_length");
        assertEq(vm.parseTomlUint(config, ".fmt.line_length"), MAX_LINE_LENGTH);
    }

    /// The wrap is a newline followed by exactly one of this repo's configured
    /// tab widths of spaces, which is what `forge fmt` emits when it breaks a
    /// constant declaration after the `=` itself.
    function testNewlineDueToMaxLengthMatchesFormatterConfig() external view {
        string memory config = vm.readFile("foundry.toml");
        assertTrue(vm.keyExistsToml(config, ".fmt.tab_width"), "foundry.toml states no [fmt] tab_width");

        bytes memory expected = new bytes(vm.parseTomlUint(config, ".fmt.tab_width") + 1);
        expected[0] = "\n";
        for (uint256 i = 1; i < expected.length; i++) {
            expected[i] = " ";
        }
        assertEq(NEWLINE_DUE_TO_MAX_LENGTH, string(expected));
    }
}

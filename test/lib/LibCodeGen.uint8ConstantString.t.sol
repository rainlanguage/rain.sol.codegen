// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibCodeGen, MAX_LINE_LENGTH} from "src/lib/LibCodeGen.sol";
import {LibCodeGenSlow} from "./LibCodeGenSlow.sol";

/// @title LibCodeGenUint8ConstantStringTest
/// @notice `uint8ConstantString` emits a Solidity `uint8 constant` declaration
/// and decides for itself whether that declaration fits on one line. The
/// decision is made by adding up magic numbers standing in for the literals it
/// is about to concatenate, so these assert the emitted text against a reference
/// that measures the line instead, and pin the decision either side of the
/// maximum.
contract LibCodeGenUint8ConstantStringTest is Test {
    /// The short case: blank line, comment, then the whole declaration on one
    /// line, decimal rather than hex.
    function testUint8ConstantString() external pure {
        assertEq(
            LibCodeGen.uint8ConstantString(vm, "/// @dev Some count.", "SOME_COUNT", 42),
            "\n/// @dev Some count.\nuint8 constant SOME_COUNT = 42;\n"
        );
    }

    /// Zero is a real value, not a sentinel to special-case.
    function testUint8ConstantStringZero() external pure {
        assertEq(
            LibCodeGen.uint8ConstantString(vm, "/// @dev Zero.", "ZERO", 0),
            "\n/// @dev Zero.\nuint8 constant ZERO = 0;\n"
        );
    }

    /// The maximum a `uint8` holds still emits as a plain decimal that fits the
    /// declared type, so the generated constant compiles.
    function testUint8ConstantStringMax() external pure {
        assertEq(
            LibCodeGen.uint8ConstantString(vm, "/// @dev Max.", "MAX", type(uint8).max),
            "\n/// @dev Max.\nuint8 constant MAX = 255;\n"
        );
    }

    /// A declaration of exactly the maximum length stays on one line. `forge fmt`
    /// leaves a line of exactly `line_length` alone, so wrapping here would be a
    /// reflow the formatter immediately undoes.
    function testUint8ConstantStringAtMaxLength() external pure {
        string memory name = LibCodeGenSlow.nameOfLengthSlow(98);
        string memory emitted = LibCodeGen.uint8ConstantString(vm, "/// @dev At max.", name, 255);
        assertEq(emitted, string.concat("\n/// @dev At max.\nuint8 constant ", name, " = 255;\n"));
        assertEq(LibCodeGenSlow.longestLineSlow(emitted), MAX_LINE_LENGTH);
    }

    /// One character past the maximum wraps after the `=`, with the value
    /// indented by one tab width on the next line.
    function testUint8ConstantStringOverMaxLengthByName() external pure {
        string memory name = LibCodeGenSlow.nameOfLengthSlow(99);
        assertEq(
            LibCodeGen.uint8ConstantString(vm, "/// @dev Over max.", name, 255),
            string.concat("\n/// @dev Over max.\nuint8 constant ", name, " =\n    255;\n")
        );
    }

    /// The decimal's own width counts toward the decision, not just the name's.
    /// Same name either side, one digit apart.
    function testUint8ConstantStringOverMaxLengthByDigits() external pure {
        string memory name = LibCodeGenSlow.nameOfLengthSlow(100);

        string memory under = LibCodeGen.uint8ConstantString(vm, "/// @dev Under.", name, 9);
        assertEq(under, string.concat("\n/// @dev Under.\nuint8 constant ", name, " = 9;\n"));
        assertEq(LibCodeGenSlow.longestLineSlow(under), MAX_LINE_LENGTH);

        assertEq(
            LibCodeGen.uint8ConstantString(vm, "/// @dev Over.", name, 10),
            string.concat("\n/// @dev Over.\nuint8 constant ", name, " =\n    10;\n")
        );
    }

    /// Whatever the comment, name and value, the emitted text is the declaration
    /// built from those literals, wrapped exactly when measuring the one line
    /// form says it does not fit.
    function testUint8ConstantStringMatchesMeasuredLine(string memory comment, string memory name, uint8 data)
        external
        pure
    {
        assertEq(
            LibCodeGen.uint8ConstantString(vm, comment, name, data),
            LibCodeGenSlow.uint8ConstantStringSlow(vm, comment, name, data)
        );
    }

    /// The literal the declaration carries parses back to the value it was
    /// generated from, so the constant is not silently truncated or
    /// reformatted. The literal is sliced out of the emitted text, so the round
    /// trip is a property of what the library wrote.
    function testUint8ConstantStringRoundTrips(uint8 data) external pure {
        string memory emitted = LibCodeGen.uint8ConstantString(vm, "/// @dev Fuzz.", "FUZZ", data);
        assertEq(emitted, string.concat("\n/// @dev Fuzz.\nuint8 constant FUZZ = ", vm.toString(uint256(data)), ";\n"));
        assertEq(vm.parseUint(LibCodeGenSlow.betweenSlow(emitted, "FUZZ = ", ";")), uint256(data));
    }

    /// An empty comment emits no comment line rather than an empty one. Two
    /// consecutive newlines are a blank line that `forge fmt` collapses, so a
    /// generated file carrying one is not stable under the formatter and a
    /// consumer's `forge fmt --check` reds when it regenerates.
    function testUint8ConstantStringEmptyComment() external pure {
        assertEq(LibCodeGen.uint8ConstantString(vm, "", "NO_COMMENT", 7), "\nuint8 constant NO_COMMENT = 7;\n");
    }

    /// The comment is the only thing an empty comment removes: the declaration
    /// that follows it is byte for byte the same either way, including the
    /// blank line that separates it from whatever precedes it.
    function testUint8ConstantStringEmptyCommentKeepsDeclaration() external pure {
        assertEq(
            LibCodeGen.uint8ConstantString(vm, "/// @dev Seven.", "NO_COMMENT", 7),
            string.concat("\n/// @dev Seven.", LibCodeGen.uint8ConstantString(vm, "", "NO_COMMENT", 7))
        );
    }
}

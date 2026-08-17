// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibCodeGen, MAX_LINE_LENGTH} from "src/lib/LibCodeGen.sol";
import {LibCodeGenSlow} from "test/lib/LibCodeGenSlow.sol";

/// @dev A `bytes32` literal is 66 characters whatever the value, so the
/// declaration is `96 + name.length` characters long on one line.
bytes32 constant SOME_HASH = 0x2573004ac3a9ee7fc8d73654d76386f1b6b99e34cdf86a689c4691e47143420f;
string constant SOME_HASH_STRING = "0x2573004ac3a9ee7fc8d73654d76386f1b6b99e34cdf86a689c4691e47143420f";

/// @title LibCodeGenBytes32ConstantStringTest
/// @notice `bytes32ConstantString` emits a Solidity `bytes32 constant`
/// declaration. The output is source code that must COMPILE, so these assert the
/// exact emitted text rather than that it merely contains the value.
contract LibCodeGenBytes32ConstantStringTest is Test {
    function testBytes32ConstantString() external view {
        assertEq(
            LibCodeGen.bytes32ConstantString(
                vm,
                "/// @dev Some hash.",
                "SOME_HASH",
                0x2573004ac3a9ee7fc8d73654d76386f1b6b99e34cdf86a689c4691e47143420f
            ),
            "\n/// @dev Some hash.\nbytes32 constant SOME_HASH ="
            " bytes32(0x2573004ac3a9ee7fc8d73654d76386f1b6b99e34cdf86a689c4691e47143420f);\n"
        );
    }

    /// Zero is a real value, not a sentinel to special-case. Whether a caller
    /// should be emitting it is the caller's problem — `bytecodeHashConstantString`
    /// refuses a codeless address for exactly that reason — and this function
    /// emits it as plainly as any other value.
    function testBytes32ConstantStringZero() external view {
        assertEq(
            LibCodeGen.bytes32ConstantString(vm, "/// @dev Zero.", "ZERO", bytes32(0)),
            "\n/// @dev Zero.\nbytes32 constant ZERO ="
            " bytes32(0x0000000000000000000000000000000000000000000000000000000000000000);\n"
        );
    }

    /// The literal the declaration carries parses back to the value it was
    /// generated from, rather than being truncated or reformatted. The literal
    /// is sliced out of the emitted text, so the round trip is a property of
    /// what the library wrote.
    function testBytes32ConstantStringRoundTrips(bytes32 data) external view {
        string memory emitted = LibCodeGen.bytes32ConstantString(vm, "/// @dev Fuzz.", "FUZZ", data);
        assertEq(
            emitted, string.concat("\n/// @dev Fuzz.\nbytes32 constant FUZZ = bytes32(", vm.toString(data), ");\n")
        );
        assertEq(vm.parseBytes32(LibCodeGenSlow.betweenSlow(emitted, "bytes32(", ")")), data);
    }

    /// A declaration of exactly the maximum length stays on one line. `forge fmt`
    /// leaves a line of exactly `line_length` alone, so wrapping here would be a
    /// reflow the formatter immediately undoes.
    function testBytes32ConstantStringAtMaxLength() external view {
        string memory name = LibCodeGenSlow.nameOfLengthSlow(24);
        string memory emitted = LibCodeGen.bytes32ConstantString(vm, "/// @dev At max.", name, SOME_HASH);
        assertEq(
            emitted,
            string.concat("\n/// @dev At max.\nbytes32 constant ", name, " = bytes32(", SOME_HASH_STRING, ");\n")
        );
        assertEq(LibCodeGenSlow.longestLineSlow(emitted), MAX_LINE_LENGTH);
    }

    /// One character past the maximum wraps after the `=`, with the value
    /// indented by one tab width on the next line.
    function testBytes32ConstantStringOverMaxLength() external view {
        string memory name = LibCodeGenSlow.nameOfLengthSlow(25);
        assertEq(
            LibCodeGen.bytes32ConstantString(vm, "/// @dev Over max.", name, SOME_HASH),
            string.concat("\n/// @dev Over max.\nbytes32 constant ", name, " =\n    bytes32(", SOME_HASH_STRING, ");\n")
        );
    }

    /// Whatever the comment, name and value, the emitted text is the declaration
    /// built from those literals, wrapped exactly when measuring the one line
    /// form says it does not fit. Fuzzed over every input because each term of
    /// the library's hand computed sum has to be right for this to hold.
    function testBytes32ConstantStringMatchesMeasuredLine(string memory comment, string memory name, bytes32 data)
        external
        view
    {
        assertEq(
            LibCodeGen.bytes32ConstantString(vm, comment, name, data),
            LibCodeGenSlow.bytes32ConstantStringSlow(vm, comment, name, data)
        );
    }

    /// An empty comment emits no comment line rather than an empty one. Two
    /// consecutive newlines are a blank line that `forge fmt` collapses, so a
    /// generated file carrying one is not stable under the formatter and a
    /// consumer's `forge fmt --check` reds when it regenerates.
    function testBytes32ConstantStringEmptyComment() external view {
        assertEq(
            LibCodeGen.bytes32ConstantString(vm, "", "NO_COMMENT", SOME_HASH),
            string.concat("\nbytes32 constant NO_COMMENT = bytes32(", SOME_HASH_STRING, ");\n")
        );
    }

    /// The comment is the only thing an empty comment removes: the declaration
    /// that follows it is byte for byte the same either way, including the
    /// blank line that separates it from whatever precedes it.
    function testBytes32ConstantStringEmptyCommentKeepsDeclaration() external view {
        assertEq(
            LibCodeGen.bytes32ConstantString(vm, "/// @dev Some hash.", "NO_COMMENT", SOME_HASH),
            string.concat("\n/// @dev Some hash.", LibCodeGen.bytes32ConstantString(vm, "", "NO_COMMENT", SOME_HASH))
        );
    }
}

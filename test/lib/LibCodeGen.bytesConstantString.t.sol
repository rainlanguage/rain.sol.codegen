// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {LibCodeGen, MAX_LINE_LENGTH} from "src/lib/LibCodeGen.sol";
import {LibCodeGenSlow} from "./LibCodeGenSlow.sol";

/// @dev 32 bytes, so the hex literal is 64 characters and the whole declaration
/// is `24 + name.length + 64` characters on one line.
bytes constant DATA_32 = hex"2573004ac3a9ee7fc8d73654d76386f1b6b99e34cdf86a689c4691e47143420f";
string constant HEX_32 = "2573004ac3a9ee7fc8d73654d76386f1b6b99e34cdf86a689c4691e47143420f";

/// @dev One byte more than `DATA_32`, so two characters more of hex.
bytes constant DATA_33 = hex"2573004ac3a9ee7fc8d73654d76386f1b6b99e34cdf86a689c4691e47143420faa";
string constant HEX_33 = "2573004ac3a9ee7fc8d73654d76386f1b6b99e34cdf86a689c4691e47143420faa";

/// @dev Two bytes more than `DATA_32`, so four characters more of hex.
bytes constant DATA_34 = hex"2573004ac3a9ee7fc8d73654d76386f1b6b99e34cdf86a689c4691e47143420faabb";
string constant HEX_34 = "2573004ac3a9ee7fc8d73654d76386f1b6b99e34cdf86a689c4691e47143420faabb";

/// @title LibCodeGenBytesConstantStringTest
/// @notice `bytesConstantString` emits a Solidity `bytes constant` declaration
/// and decides for itself whether that declaration fits on one line. The
/// decision is made by adding up magic numbers standing in for the literals it
/// is about to concatenate, so these assert the emitted text against a reference
/// that measures the line instead, and pin the decision either side of the
/// maximum.
contract LibCodeGenBytesConstantStringTest is Test {
    /// The short case: blank line, comment, then the whole declaration on one
    /// line. The blank line is what separates this constant from whatever the
    /// caller concatenated before it.
    function testBytesConstantString() external pure {
        assertEq(
            LibCodeGen.bytesConstantString(vm, "/// @dev Some bytes comment.", "SOME_BYTES_CONSTANT", hex"12345678"),
            "\n/// @dev Some bytes comment.\nbytes constant SOME_BYTES_CONSTANT = hex\"12345678\";\n"
        );
    }

    /// Empty data is a real value, not a reason to skip the constant. `hex""` is
    /// valid Solidity for empty bytes, so the declaration is still emitted whole
    /// rather than collapsing to a bare `hex` or an unterminated literal.
    function testBytesConstantStringEmptyData() external pure {
        assertEq(
            LibCodeGen.bytesConstantString(vm, "/// @dev Nothing.", "NOTHING", ""),
            "\n/// @dev Nothing.\nbytes constant NOTHING = hex\"\";\n"
        );
    }

    /// A declaration of exactly the maximum length stays on one line. `forge fmt`
    /// leaves a line of exactly `line_length` alone, so wrapping here would be a
    /// reflow the formatter immediately undoes.
    function testBytesConstantStringAtMaxLength() external pure {
        string memory name = LibCodeGenSlow.nameOfLengthSlow(32);
        string memory emitted = LibCodeGen.bytesConstantString(vm, "/// @dev At max.", name, DATA_32);
        assertEq(emitted, string.concat("\n/// @dev At max.\nbytes constant ", name, " = hex\"", HEX_32, "\";\n"));
        assertEq(LibCodeGenSlow.longestLineSlow(emitted), MAX_LINE_LENGTH);
    }

    /// One character past the maximum wraps after the `=`, with the value
    /// indented by one tab width on the next line.
    function testBytesConstantStringOverMaxLengthByName() external pure {
        string memory name = LibCodeGenSlow.nameOfLengthSlow(33);
        assertEq(
            LibCodeGen.bytesConstantString(vm, "/// @dev Over max.", name, DATA_32),
            string.concat("\n/// @dev Over max.\nbytes constant ", name, " =\n    hex\"", HEX_32, "\";\n")
        );
    }

    /// The data's own length counts toward the decision, not just the name's.
    /// Same name either side, one byte of data apart.
    function testBytesConstantStringOverMaxLengthByData() external pure {
        string memory name = LibCodeGenSlow.nameOfLengthSlow(30);

        string memory under = LibCodeGen.bytesConstantString(vm, "/// @dev Under.", name, DATA_33);
        assertEq(under, string.concat("\n/// @dev Under.\nbytes constant ", name, " = hex\"", HEX_33, "\";\n"));
        assertEq(LibCodeGenSlow.longestLineSlow(under), MAX_LINE_LENGTH);

        assertEq(
            LibCodeGen.bytesConstantString(vm, "/// @dev Over.", name, DATA_34),
            string.concat("\n/// @dev Over.\nbytes constant ", name, " =\n    hex\"", HEX_34, "\";\n")
        );
    }

    /// Whatever the comment, name and data, the emitted text is the declaration
    /// built from those literals, wrapped exactly when measuring the one line
    /// form says it does not fit. Fuzzed over every input because each term of
    /// the library's hand computed sum has to be right for this to hold.
    function testBytesConstantStringMatchesMeasuredLine(string memory comment, string memory name, bytes memory data)
        external
        pure
    {
        assertEq(
            LibCodeGen.bytesConstantString(vm, comment, name, data),
            LibCodeGenSlow.bytesConstantStringSlow(vm, comment, name, data)
        );
    }

    /// The hex the declaration carries is the data, unchanged and unprefixed, so
    /// the constant compiles back to the bytes it was generated from. A `0x`
    /// inside a `hex"..."` literal does not compile at all.
    function testBytesConstantStringCarriesData(bytes memory data) external pure {
        string memory emitted = LibCodeGen.bytesConstantString(vm, "/// @dev Fuzz.", "FUZZ", data);
        assertTrue(vm.contains(emitted, string.concat("hex\"", LibCodeGenSlow.hexOfSlow(vm, data), "\";\n")));
        assertFalse(vm.contains(emitted, "hex\"0x"), "hex literal carries a 0x prefix");
    }

    /// An empty comment emits no comment line rather than an empty one. Two
    /// consecutive newlines are a blank line that `forge fmt` collapses, so a
    /// generated file carrying one is not stable under the formatter and a
    /// consumer's `forge fmt --check` reds when it regenerates.
    function testBytesConstantStringEmptyComment() external pure {
        assertEq(
            LibCodeGen.bytesConstantString(vm, "", "NO_COMMENT", DATA_32),
            string.concat("\nbytes constant NO_COMMENT = hex\"", HEX_32, "\";\n")
        );
    }

    /// The comment is the only thing an empty comment removes: the declaration
    /// that follows it is byte for byte the same either way, including the
    /// blank line that separates it from whatever precedes it.
    function testBytesConstantStringEmptyCommentKeepsDeclaration() external pure {
        assertEq(
            LibCodeGen.bytesConstantString(vm, "/// @dev Some data.", "NO_COMMENT", DATA_32),
            string.concat("\n/// @dev Some data.", LibCodeGen.bytesConstantString(vm, "", "NO_COMMENT", DATA_32))
        );
    }
}

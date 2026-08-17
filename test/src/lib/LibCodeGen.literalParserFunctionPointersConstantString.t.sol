// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibCodeGen} from "src/lib/LibCodeGen.sol";
import {IParserToolingV1} from "src/interface/IParserToolingV1.sol";
import {LibCodeGenSlow} from "test/lib/LibCodeGenSlow.sol";
import {ToolingMock} from "test/concrete/ToolingMock.sol";

/// @dev The comment the library puts above this constant, spelled out here so
/// that a change to it fails rather than moving both sides at once.
string constant LITERAL_PARSER_COMMENT = "/// @dev Every two bytes is a function pointer for a literal parser.\n"
    "/// Literal dispatches are determined by the first byte(s) of the literal\n"
    "/// rather than a full word lookup, and are done with simple conditional\n"
    "/// jumps as the possibilities are limited compared to the number of words we\n" "/// have.";

/// @title LibCodeGenLiteralParserFunctionPointersConstantStringTest
/// @notice `literalParserFunctionPointersConstantString` names the constant,
/// writes the comment and picks which of the tooling instance's builders to ask.
/// All three are the library's own choice rather than the caller's, so all three
/// are pinned here.
contract LibCodeGenLiteralParserFunctionPointersConstantStringTest is Test {
    ToolingMock internal sMock;

    function setUp() external {
        sMock = new ToolingMock();
    }

    /// The whole emitted declaration for a short pointer string.
    function testLiteralParserFunctionPointersConstantString() external {
        sMock.setAll(hex"aaaa", hex"1234", hex"bbbb", hex"cccc", hex"dddd");
        assertEq(
            LibCodeGen.literalParserFunctionPointersConstantString(vm, IParserToolingV1(address(sMock))),
            "\n/// @dev Every two bytes is a function pointer for a literal parser.\n"
            "/// Literal dispatches are determined by the first byte(s) of the literal\n"
            "/// rather than a full word lookup, and are done with simple conditional\n"
            "/// jumps as the possibilities are limited compared to the number of words we\n" "/// have.\n"
            "bytes constant LITERAL_PARSER_FUNCTION_POINTERS = hex\"1234\";\n"
        );
    }

    /// The pointers come from `buildLiteralParserFunctionPointers` and from no
    /// other builder on the same instance. `IParserToolingV1` carries two
    /// builders, so the sibling on the same interface is the one most easily
    /// asked by mistake.
    function testLiteralParserFunctionPointersConstantStringUsesItsOwnBuilder(bytes memory pointers, bytes memory other)
        external
    {
        vm.assume(keccak256(pointers) != keccak256(other));
        sMock.setAll(other, pointers, other, other, other);
        assertEq(
            LibCodeGen.literalParserFunctionPointersConstantString(vm, IParserToolingV1(address(sMock))),
            LibCodeGenSlow.bytesConstantStringSlow(
                vm, LITERAL_PARSER_COMMENT, "LITERAL_PARSER_FUNCTION_POINTERS", pointers
            )
        );
    }
}

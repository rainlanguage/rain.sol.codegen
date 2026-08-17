// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {LibCodeGen} from "src/lib/LibCodeGen.sol";
import {IParserToolingV1} from "src/interface/IParserToolingV1.sol";
import {LibCodeGenSlow} from "test/lib/LibCodeGenSlow.sol";
import {ToolingMock} from "test/concrete/ToolingMock.sol";

/// @dev The comment the library puts above this constant, spelled out here so
/// that a change to it fails rather than moving both sides at once.
string constant OPERAND_HANDLER_COMMENT = "/// @dev Every two bytes is a function pointer for an operand handler.\n"
    "/// These positional indexes all map to the same indexes looked up in the parse\n" "/// meta.";

/// @title LibCodeGenOperandHandlerFunctionPointersConstantStringTest
/// @notice `operandHandlerFunctionPointersConstantString` names the constant,
/// writes the comment and picks which of the tooling instance's builders to ask.
/// All three are the library's own choice rather than the caller's, so all three
/// are pinned here.
contract LibCodeGenOperandHandlerFunctionPointersConstantStringTest is Test {
    ToolingMock internal sMock;

    function setUp() external {
        sMock = new ToolingMock();
    }

    /// The whole emitted declaration for a short pointer string.
    function testOperandHandlerFunctionPointersConstantString() external {
        sMock.setAll(hex"aaaa", hex"bbbb", hex"1234", hex"cccc", hex"dddd");
        assertEq(
            LibCodeGen.operandHandlerFunctionPointersConstantString(vm, IParserToolingV1(address(sMock))),
            "\n/// @dev Every two bytes is a function pointer for an operand handler.\n"
            "/// These positional indexes all map to the same indexes looked up in the parse\n" "/// meta.\n"
            "bytes constant OPERAND_HANDLER_FUNCTION_POINTERS = hex\"1234\";\n"
        );
    }

    /// The pointers come from `buildOperandHandlerFunctionPointers` and from no
    /// other builder on the same instance. `IParserToolingV1` carries two
    /// builders, so the sibling on the same interface is the one most easily
    /// asked by mistake.
    function testOperandHandlerFunctionPointersConstantStringUsesItsOwnBuilder(
        bytes memory pointers,
        bytes memory other
    ) external {
        vm.assume(keccak256(pointers) != keccak256(other));
        sMock.setAll(other, other, pointers, other, other);
        assertEq(
            LibCodeGen.operandHandlerFunctionPointersConstantString(vm, IParserToolingV1(address(sMock))),
            LibCodeGenSlow.bytesConstantStringSlow(
                vm, OPERAND_HANDLER_COMMENT, "OPERAND_HANDLER_FUNCTION_POINTERS", pointers
            )
        );
    }
}

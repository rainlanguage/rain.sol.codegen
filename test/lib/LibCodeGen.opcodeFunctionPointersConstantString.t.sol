// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {LibCodeGen} from "src/lib/LibCodeGen.sol";
import {IOpcodeToolingV1} from "src/interface/IOpcodeToolingV1.sol";
import {LibCodeGenSlow} from "./LibCodeGenSlow.sol";
import {ToolingMock} from "../concrete/ToolingMock.sol";

/// @dev The comment the library puts above this constant, spelled out here so
/// that a change to it fails rather than moving both sides at once.
string constant OPCODE_COMMENT = "/// @dev The function pointers known to the interpreter for dynamic dispatch.\n"
    "/// By setting these as a constant they can be inlined into the interpreter\n"
    "/// and loaded at eval time for very low gas (~100) due to the compiler\n"
    "/// optimising it to a single `codecopy` to build the in memory bytes array.";

/// @title LibCodeGenOpcodeFunctionPointersConstantStringTest
/// @notice `opcodeFunctionPointersConstantString` names the constant, writes the
/// comment and picks which of the tooling instance's builders to ask. All three
/// are the library's own choice rather than the caller's, so all three are
/// pinned here.
contract LibCodeGenOpcodeFunctionPointersConstantStringTest is Test {
    ToolingMock internal sMock;

    function setUp() external {
        sMock = new ToolingMock();
    }

    /// The whole emitted declaration for a short pointer string.
    function testOpcodeFunctionPointersConstantString() external {
        sMock.setAll(hex"1234", hex"aaaa", hex"bbbb", hex"cccc", hex"dddd");
        assertEq(
            LibCodeGen.opcodeFunctionPointersConstantString(vm, IOpcodeToolingV1(address(sMock))),
            "\n/// @dev The function pointers known to the interpreter for dynamic dispatch.\n"
            "/// By setting these as a constant they can be inlined into the interpreter\n"
            "/// and loaded at eval time for very low gas (~100) due to the compiler\n"
            "/// optimising it to a single `codecopy` to build the in memory bytes array.\n"
            "bytes constant OPCODE_FUNCTION_POINTERS = hex\"1234\";\n"
        );
    }

    /// The pointers come from `buildOpcodeFunctionPointers` and from no other
    /// builder on the same instance. The mock answers each builder differently,
    /// so asking the wrong one emits the wrong hex.
    function testOpcodeFunctionPointersConstantStringUsesItsOwnBuilder(bytes memory pointers, bytes memory other)
        external
    {
        vm.assume(keccak256(pointers) != keccak256(other));
        sMock.setAll(pointers, other, other, other, other);
        assertEq(
            LibCodeGen.opcodeFunctionPointersConstantString(vm, IOpcodeToolingV1(address(sMock))),
            LibCodeGenSlow.bytesConstantStringSlow(vm, OPCODE_COMMENT, "OPCODE_FUNCTION_POINTERS", pointers)
        );
    }
}

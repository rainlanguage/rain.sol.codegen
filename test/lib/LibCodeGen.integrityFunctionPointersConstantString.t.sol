// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {LibCodeGen} from "src/lib/LibCodeGen.sol";
import {IIntegrityToolingV1} from "src/interface/IIntegrityToolingV1.sol";
import {LibCodeGenSlow} from "./LibCodeGenSlow.sol";
import {ToolingMock} from "../concrete/ToolingMock.sol";

/// @dev The comment the library puts above this constant, spelled out here so
/// that a change to it fails rather than moving both sides at once. This is the
/// only one of the five that is a single line, so it is also the only one whose
/// comment is passed as a plain literal rather than a concatenation.
string constant INTEGRITY_COMMENT = "/// @dev The function pointers for the integrity check fns.";

/// @title LibCodeGenIntegrityFunctionPointersConstantStringTest
/// @notice `integrityFunctionPointersConstantString` names the constant, writes
/// the comment and picks which of the tooling instance's builders to ask. All
/// three are the library's own choice rather than the caller's, so all three are
/// pinned here.
contract LibCodeGenIntegrityFunctionPointersConstantStringTest is Test {
    ToolingMock internal sMock;

    function setUp() external {
        sMock = new ToolingMock();
    }

    /// The whole emitted declaration for a short pointer string.
    function testIntegrityFunctionPointersConstantString() external {
        sMock.setAll(hex"aaaa", hex"bbbb", hex"cccc", hex"dddd", hex"1234");
        assertEq(
            LibCodeGen.integrityFunctionPointersConstantString(vm, IIntegrityToolingV1(address(sMock))),
            "\n/// @dev The function pointers for the integrity check fns.\n"
            "bytes constant INTEGRITY_FUNCTION_POINTERS = hex\"1234\";\n"
        );
    }

    /// The pointers come from `buildIntegrityFunctionPointers` and from no other
    /// builder on the same instance.
    function testIntegrityFunctionPointersConstantStringUsesItsOwnBuilder(bytes memory pointers, bytes memory other)
        external
    {
        vm.assume(keccak256(pointers) != keccak256(other));
        sMock.setAll(other, other, other, other, pointers);
        assertEq(
            LibCodeGen.integrityFunctionPointersConstantString(vm, IIntegrityToolingV1(address(sMock))),
            LibCodeGenSlow.bytesConstantStringSlow(vm, INTEGRITY_COMMENT, "INTEGRITY_FUNCTION_POINTERS", pointers)
        );
    }
}

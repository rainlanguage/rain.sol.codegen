// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibCodeGen} from "src/lib/LibCodeGen.sol";
import {ISubParserToolingV1} from "src/interface/ISubParserToolingV1.sol";
import {LibCodeGenSlow} from "test/lib/LibCodeGenSlow.sol";
import {ToolingMock} from "test/concrete/ToolingMock.sol";

/// @dev The comment the library puts above this constant, spelled out here so
/// that a change to it fails rather than moving both sides at once.
string constant SUB_PARSER_WORD_PARSERS_COMMENT = "/// @dev The function pointers for the sub parser functions that produce the\n"
    "/// bytecode that this contract knows about. This is both constructing the subParser\n"
    "/// bytecode that dials back into this contract at eval time, and mapping\n"
    "/// to things that happen entirely on the interpreter such as well known\n"
    "/// constants and references to the context grid.";

/// @title LibCodeGenSubParserWordParsersConstantStringTest
/// @notice `subParserWordParsersConstantString` names the constant, writes the
/// comment and picks which of the tooling instance's builders to ask. All three
/// are the library's own choice rather than the caller's, so all three are
/// pinned here.
contract LibCodeGenSubParserWordParsersConstantStringTest is Test {
    ToolingMock internal sMock;

    function setUp() external {
        sMock = new ToolingMock();
    }

    /// The whole emitted declaration for a short parser string.
    function testSubParserWordParsersConstantString() external {
        sMock.setAll(hex"aaaa", hex"bbbb", hex"cccc", hex"1234", hex"dddd");
        assertEq(
            LibCodeGen.subParserWordParsersConstantString(vm, ISubParserToolingV1(address(sMock))),
            "\n/// @dev The function pointers for the sub parser functions that produce the\n"
            "/// bytecode that this contract knows about. This is both constructing the subParser\n"
            "/// bytecode that dials back into this contract at eval time, and mapping\n"
            "/// to things that happen entirely on the interpreter such as well known\n"
            "/// constants and references to the context grid.\n"
            "bytes constant SUB_PARSER_WORD_PARSERS = hex\"1234\";\n"
        );
    }

    /// The parsers come from `buildSubParserWordParsers` and from no other
    /// builder on the same instance.
    function testSubParserWordParsersConstantStringUsesItsOwnBuilder(bytes memory parsers, bytes memory other)
        external
    {
        vm.assume(keccak256(parsers) != keccak256(other));
        sMock.setAll(other, other, other, parsers, other);
        assertEq(
            LibCodeGen.subParserWordParsersConstantString(vm, ISubParserToolingV1(address(sMock))),
            LibCodeGenSlow.bytesConstantStringSlow(
                vm, SUB_PARSER_WORD_PARSERS_COMMENT, "SUB_PARSER_WORD_PARSERS", parsers
            )
        );
    }
}

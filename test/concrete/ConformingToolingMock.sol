// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IOpcodeToolingV1} from "src/interface/IOpcodeToolingV1.sol";
import {IParserToolingV1} from "src/interface/IParserToolingV1.sol";
import {ISubParserToolingV1} from "src/interface/ISubParserToolingV1.sol";
import {IIntegrityToolingV1} from "src/interface/IIntegrityToolingV1.sol";

/// @dev What `ConformingToolingMock` answers for
/// `buildLiteralParserFunctionPointers`. `IParserToolingV1` declares that
/// builder `pure`, so its answer is a property of the code rather than of the
/// instance, and a test recognises it by reading it from here.
bytes constant CONFORMING_LITERAL_PARSER_FUNCTION_POINTERS = hex"a1";

/// @dev What `ConformingToolingMock` answers for
/// `buildOperandHandlerFunctionPointers`. Distinct from every other builder's
/// answer, so a test can tell which builder answered.
bytes constant CONFORMING_OPERAND_HANDLER_FUNCTION_POINTERS = hex"a2";

/// @dev What `ConformingToolingMock` answers for `buildSubParserWordParsers`.
/// `ISubParserToolingV1` declares that builder `pure`, so its answer is a
/// property of the code rather than of the instance, and a test recognises it by
/// reading it from here.
bytes constant CONFORMING_SUB_PARSER_WORD_PARSERS = hex"a3";

/// @title ConformingToolingMock
/// Inherits all four published tooling interfaces, so the name, arguments,
/// return type and state mutability of every builder is what the compiler checks
/// against the interface rather than what a cast at a call site assumes.
/// @dev The two builders their interfaces declare `view` answer with a value
/// chosen per instance at construction. The three their interfaces declare
/// `pure` answer with the constants above, which is the most an implementation
/// of a `pure` builder can do.
contract ConformingToolingMock is IOpcodeToolingV1, IParserToolingV1, ISubParserToolingV1, IIntegrityToolingV1 {
    bytes internal sOpcodeFunctionPointers;
    bytes internal sIntegrityFunctionPointers;

    constructor(bytes memory opcodeFunctionPointers, bytes memory integrityFunctionPointers) {
        sOpcodeFunctionPointers = opcodeFunctionPointers;
        sIntegrityFunctionPointers = integrityFunctionPointers;
    }

    /// @inheritdoc IOpcodeToolingV1
    function buildOpcodeFunctionPointers() external view override returns (bytes memory) {
        return sOpcodeFunctionPointers;
    }

    /// @inheritdoc IIntegrityToolingV1
    function buildIntegrityFunctionPointers() external view override returns (bytes memory) {
        return sIntegrityFunctionPointers;
    }

    /// @inheritdoc IParserToolingV1
    function buildLiteralParserFunctionPointers() external pure override returns (bytes memory) {
        return CONFORMING_LITERAL_PARSER_FUNCTION_POINTERS;
    }

    /// @inheritdoc IParserToolingV1
    function buildOperandHandlerFunctionPointers() external pure override returns (bytes memory) {
        return CONFORMING_OPERAND_HANDLER_FUNCTION_POINTERS;
    }

    /// @inheritdoc ISubParserToolingV1
    function buildSubParserWordParsers() external pure override returns (bytes memory) {
        return CONFORMING_SUB_PARSER_WORD_PARSERS;
    }
}

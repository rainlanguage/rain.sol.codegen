// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IOpcodeToolingV1} from "src/interface/IOpcodeToolingV1.sol";
import {IParserToolingV1} from "src/interface/IParserToolingV1.sol";
import {ISubParserToolingV1} from "src/interface/ISubParserToolingV1.sol";
import {IIntegrityToolingV1} from "src/interface/IIntegrityToolingV1.sol";

/// @title ToolingMock
/// Answers all five tooling builders that `LibCodeGen` dispatches to, each with
/// its own byte string, so a test can tell which builder a `LibCodeGen` wrapper
/// actually called rather than only that it called something.
/// @dev Inherits all four tooling interfaces, so the name, arguments, return
/// type and state mutability of every builder is checked by the compiler against
/// the interface that declares it. Every answer is set per instance and so is
/// read from storage, which is what each of the four interfaces has to allow for
/// this mock to compile.
contract ToolingMock is IOpcodeToolingV1, IParserToolingV1, ISubParserToolingV1, IIntegrityToolingV1 {
    bytes internal sOpcodeFunctionPointers;
    bytes internal sLiteralParserFunctionPointers;
    bytes internal sOperandHandlerFunctionPointers;
    bytes internal sSubParserWordParsers;
    bytes internal sIntegrityFunctionPointers;

    /// Sets every builder's answer at once. Tests pass five distinct values so
    /// that a wrapper calling the wrong builder emits the wrong hex.
    function setAll(
        bytes memory opcodeFunctionPointers,
        bytes memory literalParserFunctionPointers,
        bytes memory operandHandlerFunctionPointers,
        bytes memory subParserWordParsers,
        bytes memory integrityFunctionPointers
    ) external {
        sOpcodeFunctionPointers = opcodeFunctionPointers;
        sLiteralParserFunctionPointers = literalParserFunctionPointers;
        sOperandHandlerFunctionPointers = operandHandlerFunctionPointers;
        sSubParserWordParsers = subParserWordParsers;
        sIntegrityFunctionPointers = integrityFunctionPointers;
    }

    /// @inheritdoc IOpcodeToolingV1
    function buildOpcodeFunctionPointers() external view override returns (bytes memory) {
        return sOpcodeFunctionPointers;
    }

    /// @inheritdoc IParserToolingV1
    function buildLiteralParserFunctionPointers() external view override returns (bytes memory) {
        return sLiteralParserFunctionPointers;
    }

    /// @inheritdoc IParserToolingV1
    function buildOperandHandlerFunctionPointers() external view override returns (bytes memory) {
        return sOperandHandlerFunctionPointers;
    }

    /// @inheritdoc ISubParserToolingV1
    function buildSubParserWordParsers() external view override returns (bytes memory) {
        return sSubParserWordParsers;
    }

    /// @inheritdoc IIntegrityToolingV1
    function buildIntegrityFunctionPointers() external view override returns (bytes memory) {
        return sIntegrityFunctionPointers;
    }
}

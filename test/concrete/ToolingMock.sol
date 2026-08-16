// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

/// @title ToolingMock
/// Answers all five tooling builders that `LibCodeGen` dispatches to, each with
/// its own byte string, so a test can tell which builder a `LibCodeGen` wrapper
/// actually called rather than only that it called something.
/// @dev `IParserToolingV1` and `ISubParserToolingV1` declare their builders
/// `pure`, which no implementation can satisfy while returning data set per
/// instance, so this mock declares all five `view` and does not inherit the
/// interfaces. Tests cast its address to the interface at the call site, so the
/// selectors are still the interfaces' own.
contract ToolingMock {
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

    function buildOpcodeFunctionPointers() external view returns (bytes memory) {
        return sOpcodeFunctionPointers;
    }

    function buildLiteralParserFunctionPointers() external view returns (bytes memory) {
        return sLiteralParserFunctionPointers;
    }

    function buildOperandHandlerFunctionPointers() external view returns (bytes memory) {
        return sOperandHandlerFunctionPointers;
    }

    function buildSubParserWordParsers() external view returns (bytes memory) {
        return sSubParserWordParsers;
    }

    function buildIntegrityFunctionPointers() external view returns (bytes memory) {
        return sIntegrityFunctionPointers;
    }
}

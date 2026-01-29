// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @title IParserToolingV1
/// Implemented by any contract that exposes parser tooling functions for the
/// Rain interpreter. Ostensibly this is for the interpreter itself while sub
/// parsers have a separate interface.
interface IParserToolingV1 {
    /// Builds operand handler function pointers.
    /// This is intended for use by the Rain interpreter to run operand handling
    /// logic when parsing rainlang code. The expectation is that the pointers
    /// will be built ahead of time and cached in a constant for efficiency. As
    /// the process is deterministic for a given source and compiler
    /// configuration, the output can be tested against the used value in CI and
    /// the translation from source to pointers can also be tested in CI. See
    /// .github/workflows/git-clean.yaml for an example of such a test.
    function buildOperandHandlerFunctionPointers() external pure returns (bytes memory);

    /// Builds literal parser function pointers.
    /// This is intended for use by the Rain interpreter to run literal parsing
    /// logic when parsing rainlang code. The expectation is that the pointers
    /// will be built ahead of time and cached in a constant for efficiency. As
    /// the process is deterministic for a given source and compiler
    /// configuration, the output can be tested against the used value in CI and
    /// the translation from source to pointers can also be tested in CI. See
    /// .github/workflows/git-clean.yaml for an example of such a test.
    function buildLiteralParserFunctionPointers() external pure returns (bytes memory);
}

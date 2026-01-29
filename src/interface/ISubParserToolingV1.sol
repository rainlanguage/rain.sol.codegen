// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @title ISubParserToolingV1
/// Implemented by any contract that exposes sub parser tooling functions for the
/// Rain interpreter.
interface ISubParserToolingV1 {
    /// Builds sub parser word parsers.
    /// This is intended for use by the Rain interpreter to run sub parser word
    /// parsing logic when parsing rainlang code. The expectation is that the
    /// parsers will be built ahead of time and cached in a constant for
    /// efficiency. As the process is deterministic for a given source and
    /// compiler configuration, the output can be tested against the used value
    /// in CI and the translation from source to parsers can also be tested in
    /// CI. See .github/workflows/git-clean.yaml for an example of such a test.
    function buildSubParserWordParsers() external pure returns (bytes memory);
}

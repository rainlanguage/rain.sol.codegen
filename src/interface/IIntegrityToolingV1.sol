// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @title IIntegrityToolingV1
/// Implemented by any contract that exposes integrity check functions for the
/// Rain interpreter. Ostensibly this is for the interpreter itself and also
/// extension points such as externs. These integrity checks are for the opcodes
/// tooled by IOpcodeToolingV1 implementations.
interface IIntegrityToolingV1 {
    /// Builds integrity function pointers.
    /// This is intended for use by the Rain interpreter to run integrity checks
    /// over rainlang code before it is used/deployed/executed. The expectation
    /// is that the pointers will be built ahead of time and cached in a constant
    /// for efficiency. As the process is deterministic for a given source and
    /// compiler configuration, the output can be tested against the used value
    /// in CI and the translation from source to pointers can also be tested in
    /// CI. See .github/workflows/git-clean.yaml for an example of such a test.
    function buildIntegrityFunctionPointers() external view returns (bytes memory);
}

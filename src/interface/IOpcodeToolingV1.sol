// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @title IOpcodeToolingV1
/// Implemented by any contract that exposes opcode functions (new words) for the
/// Rain interpreter. Ostensibly this is for the interpreter itself and also
/// extension points such as externs.
interface IOpcodeToolingV1 {
    /// Builds opcode function pointers.
    /// This is intended for use by the Rain interpreter to run opcodes
    /// implementing rainlang execution logic. The expectation is that the
    /// pointers will be built ahead of time and cached in a constant for
    /// efficiency. As the process is deterministic for a given source and
    /// compiler configuration, the output can be tested against the used value
    /// in CI and the translation from source to pointers can also be tested in
    /// CI. See .github/workflows/git-clean.yaml for an example of such a test.
    function buildOpcodeFunctionPointers() external view returns (bytes memory);
}

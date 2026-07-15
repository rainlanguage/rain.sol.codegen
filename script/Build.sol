// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BuildScript} from "../src/abstract/BuildScript.sol";
import {LibFs} from "../src/lib/LibFs.sol";
import {LibCodeGen} from "../src/lib/LibCodeGen.sol";
import {CodeGennable} from "../test/concrete/CodeGennable.sol";

/// @title Build
/// @notice Builds the generated file for the CodeGennable contract, as an
/// example of both halves of this library: the constant generation utilities in
/// `LibCodeGen`, and the `BuildScript` entrypoint split that keeps regenerating
/// separate from cutting a release record.
/// @dev This repo pins no release record of its own, so it implements `build`
/// alone and inherits the default empty `snapshotContractNames` — `cut` freezes
/// nothing here.
contract Build is BuildScript {
    /// Emits the example's constants. Reached by both `run` (regenerate) and
    /// `cut` (regenerate, then freeze), so generation lives in one place.
    function build() internal override {
        CodeGennable codeGennable = new CodeGennable();

        LibFs.buildFileForContract(
            vm,
            address(codeGennable),
            "CodeGennable",
            string.concat(
                LibCodeGen.bytesConstantString(
                    vm, "/// @dev Some bytes comment.", "SOME_BYTES_CONSTANT", hex"12345678"
                ),
                LibCodeGen.bytesConstantString(
                        vm,
                        "/// @dev Longer constant.",
                        "LONGER_BYTES_CONSTANT",
                        hex"e2bafcba65b2c99d33f5096307bc57c2e7f195d2a178f56e45d720bb64344998e2bafcba65b2c99d33f5096307bc57c2e7f195d2a178f56e45d720bb64344998"
                    )
            )
        );
    }
}

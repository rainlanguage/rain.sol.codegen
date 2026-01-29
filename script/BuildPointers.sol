// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Script} from "forge-std/Script.sol";
import {LibFs} from "../src/lib/LibFs.sol";
import {LibCodeGen} from "../src/lib/LibCodeGen.sol";
import {CodeGennable} from "../test/concrete/CodeGennable.sol";

/// @title BuildPointers
/// @notice Script to build the pointers file for the CodeGennable contract.
/// @dev This shows an example of how to use the bytes constant generation
/// utility in LibCodeGen.
contract BuildPointers is Script {
    /// Builds the pointers file for the CodeGennable contract to show an example
    /// of how to use the bytes constant generation utility.
    function run() external {
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

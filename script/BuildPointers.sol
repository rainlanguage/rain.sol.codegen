// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {Script} from "forge-std/Script.sol";
import {LibFs} from "../src/lib/LibFs.sol";
import {LibCodeGen} from "../src/lib/LibCodeGen.sol";
import {CodeGennable} from "../test/concrete/CodeGennable.sol";

contract BuildPointers is Script {
    function run() external {
        CodeGennable codeGennable = new CodeGennable();

        LibFs.buildFileForContract(
            vm,
            address(codeGennable),
            "CodeGennable",
            string.concat(
                LibCodeGen.bytesConstantString(vm, "/// @dev Some bytes comment.", "SOME_BYTES_CONSTANT", hex"12345678"),
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

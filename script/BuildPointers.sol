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
                LibCodeGen.bytesConstantString(vm, "/// @dev Some bytes comment.", "SOME_BYTES_CONSTANT", hex"12345678")
            )
        );
    }
}

// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std/Vm.sol";
import {LibCodeGen} from "./LibCodeGen.sol";

library LibFs {
    function pathForContract(string memory contractName) internal pure returns (string memory) {
        return string.concat("src/generated/", contractName, ".pointers.sol");
    }

    function buildFileForContract(Vm vm, address instance, string memory contractName, string memory body) internal {
        string memory path = pathForContract(contractName);

        if (vm.exists(path)) {
            //forge-lint: disable-next-line(unsafe-cheatcode)
            vm.removeFile(path);
        }
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(
            path, string.concat(LibCodeGen.filePrefix(), LibCodeGen.bytecodeHashConstantString(vm, instance), body)
        );
    }
}

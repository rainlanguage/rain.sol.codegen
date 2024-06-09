// SPDX-License-Identifier: CAL
pragma solidity ^0.8.25;

library LibFs {
    function buildFileForContract(address instance, string memory contractName, string memory body) internal {
        string memory path = pathForContract(contractName);

        if (vm.exists(path)) {
            vm.removeFile(path);
        }
        vm.writeFile(path, string.concat(filePrefix(), bytecodeHashConstantString(instance), body));
    }
}
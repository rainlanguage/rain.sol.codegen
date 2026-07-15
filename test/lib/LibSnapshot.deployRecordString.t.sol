// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibSnapshot} from "src/lib/LibSnapshot.sol";

/// @title LibSnapshotDeployRecordStringTest
/// @notice `deployRecordString` defines the shape of a complete deployment
/// record. These assert the exact emitted source, because the output must
/// compile and because the whole point of centralising the shape is that a
/// constant cannot go missing.
contract LibSnapshotDeployRecordStringTest is Test {
    address internal constant DEPLOYED = address(0xc51a14251b0dcF0ae24A96b7153991378938f5F5);

    function testDeployRecordString() external {
        vm.etch(DEPLOYED, hex"600160025560");

        assertEq(
            LibSnapshot.deployRecordString(vm, hex"3d602d80600a3d3981f3", DEPLOYED),
            string.concat(
                "\n/// @dev Address of the contract deployed via the deterministic\n"
                "/// deployment proxy. Identical across all EVM-compatible networks.\n"
                "address constant DEPLOYED_ADDRESS = address(0xc51a14251b0dcF0ae24A96b7153991378938f5F5);\n",
                "\n/// @dev Hash of the runtime bytecode: the deployment's identity.\n"
                "/// Lets a consumer verify what is deployed at the address without\n"
                "/// loading and hashing the runtime bytecode itself.\n",
                "bytes32 constant RUNTIME_CODE_HASH = bytes32(",
                vm.toString(DEPLOYED.codehash),
                ");\n",
                "\n/// @dev Hash of the creation bytecode. This is what a CREATE2 address\n"
                "/// derives from, so a consumer can verify the address without loading\n"
                "/// and hashing the creation bytecode itself.\n",
                "bytes32 constant CREATION_CODE_HASH = bytes32(",
                vm.toString(keccak256(hex"3d602d80600a3d3981f3")),
                ");\n",
                "\n/// @dev The creation bytecode of the contract.\n"
                'bytes constant CREATION_CODE = hex"3d602d80600a3d3981f3";\n',
                "\n/// @dev The runtime bytecode of the contract.\n"
                'bytes constant RUNTIME_CODE = hex"600160025560";\n'
            )
        );
    }

    /// The hashes must be the hashes OF the bytecode in the same record, or the
    /// record is internally inconsistent and a consumer trusting the cheap
    /// constant gets a different answer than one hashing the bytes.
    function testDeployRecordHashesMatchTheirBytecode(bytes memory creationCode, bytes memory runtimeCode) external {
        vm.assume(runtimeCode.length > 0);
        vm.etch(DEPLOYED, runtimeCode);

        string memory record = LibSnapshot.deployRecordString(vm, creationCode, DEPLOYED);

        assertTrue(
            vm.contains(
                record,
                string.concat(
                    "bytes32 constant RUNTIME_CODE_HASH = bytes32(", vm.toString(keccak256(runtimeCode)), ");"
                )
            ),
            "runtime hash is not the hash of the runtime code"
        );
        assertTrue(
            vm.contains(
                record,
                string.concat(
                    "bytes32 constant CREATION_CODE_HASH = bytes32(", vm.toString(keccak256(creationCode)), ");"
                )
            ),
            "creation hash is not the hash of the creation code"
        );
    }

    /// The record is complete by construction: all three constants are always
    /// present, so a consumer cannot emit an address+codehash-only pin by
    /// omission. This is the property that centralising the shape buys.
    function testDeployRecordStringIsComplete(bytes memory creationCode, bytes memory runtimeCode) external {
        vm.assume(runtimeCode.length > 0);
        vm.etch(DEPLOYED, runtimeCode);

        string memory record = LibSnapshot.deployRecordString(vm, creationCode, DEPLOYED);

        assertTrue(vm.contains(record, "address constant DEPLOYED_ADDRESS = address("), "no address");
        assertTrue(vm.contains(record, "bytes constant CREATION_CODE ="), "no creation code");
        assertTrue(vm.contains(record, "bytes constant RUNTIME_CODE ="), "no runtime code");
        assertTrue(vm.contains(record, "bytes32 constant RUNTIME_CODE_HASH = bytes32("), "no runtime codehash");
        assertTrue(vm.contains(record, "bytes32 constant CREATION_CODE_HASH = bytes32("), "no creation codehash");
    }

    /// The runtime code is read from the live instance, not from an argument, so
    /// it always describes what is actually deployed at that address.
    function testDeployRecordStringReadsRuntimeFromTheInstance() external {
        vm.etch(DEPLOYED, hex"aabbcc");
        assertTrue(
            vm.contains(
                LibSnapshot.deployRecordString(vm, hex"00", DEPLOYED), 'bytes constant RUNTIME_CODE = hex"aabbcc";'
            ),
            "runtime not read from instance"
        );

        vm.etch(DEPLOYED, hex"ddeeff");
        assertTrue(
            vm.contains(
                LibSnapshot.deployRecordString(vm, hex"00", DEPLOYED), 'bytes constant RUNTIME_CODE = hex"ddeeff";'
            ),
            "runtime did not track the instance"
        );
    }
}

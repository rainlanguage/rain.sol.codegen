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
            "\n/// @dev Address of the contract deployed via the deterministic\n"
            "/// deployment proxy. Identical across all EVM-compatible networks.\n"
            "address constant DEPLOYED_ADDRESS = address(0xc51a14251b0dcF0ae24A96b7153991378938f5F5);\n"
            "\n/// @dev The creation bytecode of the contract.\n"
            'bytes constant CREATION_CODE = hex"3d602d80600a3d3981f3";\n'
            "\n/// @dev The runtime bytecode of the contract.\n" 'bytes constant RUNTIME_CODE = hex"600160025560";\n'
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

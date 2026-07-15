// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibCodeGen} from "src/lib/LibCodeGen.sol";

/// @title LibCodeGenAddressConstantStringTest
/// @notice `addressConstantString` emits a Solidity `address constant`
/// declaration. The output is source code that must COMPILE, so these assert the
/// exact emitted text rather than that it merely contains the address.
contract LibCodeGenAddressConstantStringTest is Test {
    function testAddressConstantString() external view {
        assertEq(
            LibCodeGen.addressConstantString(
                vm, "/// @dev Some address.", "SOME_ADDRESS", address(0xc51a14251b0dcF0ae24A96b7153991378938f5F5)
            ),
            "\n/// @dev Some address.\naddress constant SOME_ADDRESS = address(0xc51a14251b0dcF0ae24A96b7153991378938f5F5);\n"
        );
    }

    /// The zero address is a real value, not a sentinel to special-case.
    function testAddressConstantStringZero() external view {
        assertEq(
            LibCodeGen.addressConstantString(vm, "/// @dev Zero.", "ZERO", address(0)),
            "\n/// @dev Zero.\naddress constant ZERO = address(0x0000000000000000000000000000000000000000);\n"
        );
    }

    /// The emitted literal is checksummed, so it round-trips back to the same
    /// address rather than silently relying on an all-lowercase form.
    function testAddressConstantStringRoundTrips(address data) external view {
        string memory emitted = LibCodeGen.addressConstantString(vm, "/// @dev Fuzz.", "FUZZ", data);
        assertEq(
            emitted, string.concat("\n/// @dev Fuzz.\naddress constant FUZZ = address(", vm.toString(data), ");\n")
        );
        assertEq(vm.parseAddress(vm.toString(data)), data);
    }
}

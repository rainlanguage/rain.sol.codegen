// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibCodeGen} from "src/lib/LibCodeGen.sol";

/// @title LibCodeGenBytes32ConstantStringTest
/// @notice `bytes32ConstantString` emits a Solidity `bytes32 constant`
/// declaration. The output is source code that must COMPILE, so these assert the
/// exact emitted text rather than that it merely contains the value.
contract LibCodeGenBytes32ConstantStringTest is Test {
    function testBytes32ConstantString() external view {
        assertEq(
            LibCodeGen.bytes32ConstantString(
                vm,
                "/// @dev Some hash.",
                "SOME_HASH",
                0x2573004ac3a9ee7fc8d73654d76386f1b6b99e34cdf86a689c4691e47143420f
            ),
            "\n/// @dev Some hash.\nbytes32 constant SOME_HASH ="
            " bytes32(0x2573004ac3a9ee7fc8d73654d76386f1b6b99e34cdf86a689c4691e47143420f);\n"
        );
    }

    /// Zero is a real value, not a sentinel to special-case. It is also the value
    /// a codehash constant wrongly takes when an instance is not passed, so it
    /// must emit as plainly as any other.
    function testBytes32ConstantStringZero() external view {
        assertEq(
            LibCodeGen.bytes32ConstantString(vm, "/// @dev Zero.", "ZERO", bytes32(0)),
            "\n/// @dev Zero.\nbytes32 constant ZERO ="
            " bytes32(0x0000000000000000000000000000000000000000000000000000000000000000);\n"
        );
    }

    /// The emitted value round-trips: the literal parses back to the same bytes32
    /// rather than being truncated or reformatted.
    function testBytes32ConstantStringRoundTrips(bytes32 data) external view {
        assertEq(
            LibCodeGen.bytes32ConstantString(vm, "/// @dev Fuzz.", "FUZZ", data),
            string.concat("\n/// @dev Fuzz.\nbytes32 constant FUZZ = bytes32(", vm.toString(data), ");\n")
        );
        assertEq(vm.parseBytes32(vm.toString(data)), data);
    }
}

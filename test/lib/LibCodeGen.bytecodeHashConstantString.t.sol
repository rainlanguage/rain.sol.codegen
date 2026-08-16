// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibCodeGen, MAX_LINE_LENGTH} from "src/lib/LibCodeGen.sol";
import {LibCodeGenSlow} from "./LibCodeGenSlow.sol";
import {CodeGennable} from "../concrete/CodeGennable.sol";

/// @title LibCodeGenBytecodeHashConstantStringTest
/// @notice `bytecodeHashConstantString` emits the one constant that every
/// generated file carries, under a name and comment it chooses itself. What it
/// must emit is the hash of the runtime code actually at the instance address,
/// because a consumer compares it against `addr.codehash`, so these derive the
/// expectation by hashing that code rather than by reading it back off the same
/// account.
contract LibCodeGenBytecodeHashConstantStringTest is Test {
    address internal constant INSTANCE = address(uint160(uint256(keccak256("instance"))));

    /// The whole emitted declaration, for code put at the address by hand. The
    /// name and comment are the library's, not the caller's, so they are pinned
    /// exactly: every consumer's generated file and every consumer's assertion
    /// against it is written against this spelling.
    function testBytecodeHashConstantString() external {
        vm.etch(INSTANCE, hex"6001");
        assertEq(
            LibCodeGen.bytecodeHashConstantString(vm, INSTANCE),
            string.concat(
                "\n/// @dev Hash of the known bytecode.\nbytes32 constant BYTECODE_HASH = bytes32(",
                vm.toString(keccak256(hex"6001")),
                ");\n"
            )
        );
    }

    /// The hash is of the runtime code of a really deployed contract, which is
    /// what `addr.codehash` returns for it.
    function testBytecodeHashConstantStringDeployed() external {
        CodeGennable codeGennable = new CodeGennable();
        assertEq(
            LibCodeGen.bytecodeHashConstantString(vm, address(codeGennable)),
            string.concat(
                "\n/// @dev Hash of the known bytecode.\nbytes32 constant BYTECODE_HASH = bytes32(",
                vm.toString(keccak256(address(codeGennable).code)),
                ");\n"
            )
        );
    }

    /// The name is fixed and so is the length of a `bytes32` literal, so this
    /// declaration can never need wrapping. Asserted rather than assumed,
    /// because this function does its own concatenation instead of going through
    /// `bytes32ConstantString` and so has no wrap decision at all.
    function testBytecodeHashConstantStringFitsMaxLength() external {
        vm.etch(INSTANCE, hex"6001");
        assertLe(LibCodeGenSlow.longestLineSlow(LibCodeGen.bytecodeHashConstantString(vm, INSTANCE)), MAX_LINE_LENGTH);
    }

    /// Whatever the runtime code, the constant carries its keccak256 hash.
    function testBytecodeHashConstantStringHashesCode(bytes memory code) external {
        vm.assume(code.length > 0);
        vm.etch(INSTANCE, code);
        assertEq(
            LibCodeGen.bytecodeHashConstantString(vm, INSTANCE),
            string.concat(
                "\n/// @dev Hash of the known bytecode.\nbytes32 constant BYTECODE_HASH = bytes32(",
                vm.toString(keccak256(code)),
                ");\n"
            )
        );
    }

    /// Two instances with different code get different constants, so the
    /// constant is a fingerprint of the code rather than of the address or of
    /// anything else about the account.
    function testBytecodeHashConstantStringDiscriminatesCode(bytes memory codeA, bytes memory codeB) external {
        vm.assume(codeA.length > 0 && codeB.length > 0);
        vm.assume(keccak256(codeA) != keccak256(codeB));

        vm.etch(INSTANCE, codeA);
        string memory emittedA = LibCodeGen.bytecodeHashConstantString(vm, INSTANCE);
        vm.etch(INSTANCE, codeB);
        string memory emittedB = LibCodeGen.bytecodeHashConstantString(vm, INSTANCE);

        assertNotEq(emittedA, emittedB);
    }

    /// The same instance generates the same text every time it is asked, so
    /// regenerating a file twice does not produce a diff.
    function testBytecodeHashConstantStringIdempotent(bytes memory code) external {
        vm.assume(code.length > 0);
        vm.etch(INSTANCE, code);
        assertEq(
            LibCodeGen.bytecodeHashConstantString(vm, INSTANCE), LibCodeGen.bytecodeHashConstantString(vm, INSTANCE)
        );
    }
}

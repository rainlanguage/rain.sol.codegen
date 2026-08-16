// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibCodeGen, MAX_LINE_LENGTH} from "src/lib/LibCodeGen.sol";
import {LibCodeGenSlow} from "./LibCodeGenSlow.sol";

/// @dev `describedByMetaHashConstantString` reads `meta/<name>.rain.meta`, and
/// this repo's `fs_permissions` grants no read under `meta`. `src/generated` is
/// the one directory it grants read-write, so a fixture goes there and the name
/// walks back out of `meta` to reach it. That the name reaches the path at all
/// is itself asserted below.
string constant FIXTURE_NAME = "../src/generated/LibCodeGenDescribedByMetaHashFixture";
string constant FIXTURE_PATH = "src/generated/LibCodeGenDescribedByMetaHashFixture.rain.meta";

/// @dev The fixed part of the declaration. The name and comment are the
/// library's own choice rather than the caller's, so both are pinned exactly:
/// every consumer's generated file is written against this spelling.
string constant DESCRIBED_BY_META_HASH_PREFIX =
    "\n/// @dev The hash of the meta that describes the contract.\nbytes32 constant DESCRIBED_BY_META_HASH = bytes32(";

/// @title LibCodeGenDescribedByMetaHashConstantStringTest
/// @notice `describedByMetaHashConstantString` builds a path out of the name it
/// is given, reads that file, and puts the hash of its contents into a constant.
contract LibCodeGenDescribedByMetaHashConstantStringTest is Test {
    /// Reachable only through an external call so that a refused read can be
    /// caught and inspected rather than aborting the test.
    function callDescribedByMetaHash(string memory name) external view returns (string memory) {
        return LibCodeGen.describedByMetaHashConstantString(vm, name);
    }

    /// The path is `meta/<name>.rain.meta`. The name is not a file that exists
    /// here, so the path is observed through the access refusal, which quotes
    /// the path that was asked for. Two names, because a hard coded path would
    /// satisfy one of them.
    function testDescribedByMetaHashConstantStringPath() external {
        assertRequestsPath("CodeGennable", "meta/CodeGennable.rain.meta");
        assertRequestsPath("SomeOtherContract", "meta/SomeOtherContract.rain.meta");
    }

    function assertRequestsPath(string memory name, string memory expectedPath) internal {
        try this.callDescribedByMetaHash(name) returns (string memory) {
            fail();
        } catch (bytes memory err) {
            assertTrue(vm.contains(string(err), expectedPath), "did not ask for the expected path");
        }
    }

    /// The constant carries the keccak256 of the file's bytes, and nothing about
    /// the file's name or path.
    function testDescribedByMetaHashConstantString() external {
        bytes memory meta = hex"1234";
        vm.writeFileBinary(FIXTURE_PATH, meta);
        string memory emitted = LibCodeGen.describedByMetaHashConstantString(vm, FIXTURE_NAME);
        vm.removeFile(FIXTURE_PATH);

        assertEq(emitted, string.concat(DESCRIBED_BY_META_HASH_PREFIX, vm.toString(keccak256(meta)), ");\n"));
    }

    /// Different meta gives a different constant, so the hash is of the contents
    /// rather than of anything fixed.
    function testDescribedByMetaHashConstantStringHashesContents() external {
        bytes memory metaA = hex"1234";
        bytes memory metaB = hex"5678";

        vm.writeFileBinary(FIXTURE_PATH, metaA);
        string memory emittedA = LibCodeGen.describedByMetaHashConstantString(vm, FIXTURE_NAME);
        vm.writeFileBinary(FIXTURE_PATH, metaB);
        string memory emittedB = LibCodeGen.describedByMetaHashConstantString(vm, FIXTURE_NAME);
        vm.removeFile(FIXTURE_PATH);

        assertEq(emittedA, string.concat(DESCRIBED_BY_META_HASH_PREFIX, vm.toString(keccak256(metaA)), ");\n"));
        assertEq(emittedB, string.concat(DESCRIBED_BY_META_HASH_PREFIX, vm.toString(keccak256(metaB)), ");\n"));
        assertNotEq(emittedA, emittedB);
    }

    /// Reading the same file twice gives the same text, so regenerating a file
    /// does not produce a diff.
    function testDescribedByMetaHashConstantStringIdempotent() external {
        vm.writeFileBinary(FIXTURE_PATH, hex"1234");
        string memory first = LibCodeGen.describedByMetaHashConstantString(vm, FIXTURE_NAME);
        string memory second = LibCodeGen.describedByMetaHashConstantString(vm, FIXTURE_NAME);
        vm.removeFile(FIXTURE_PATH);

        assertEq(first, second);
    }

    /// The name is fixed and so is the length of a `bytes32` literal, so this
    /// declaration can never need wrapping. Asserted rather than assumed,
    /// because this function does its own concatenation instead of going through
    /// `bytes32ConstantString` and so has no wrap decision at all.
    function testDescribedByMetaHashConstantStringFitsMaxLength() external {
        vm.writeFileBinary(FIXTURE_PATH, hex"1234");
        string memory emitted = LibCodeGen.describedByMetaHashConstantString(vm, FIXTURE_NAME);
        vm.removeFile(FIXTURE_PATH);

        assertLe(LibCodeGenSlow.longestLineSlow(emitted), MAX_LINE_LENGTH);
    }
}

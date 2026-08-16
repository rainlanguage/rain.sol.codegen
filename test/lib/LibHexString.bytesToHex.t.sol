// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {Vm} from "forge-std-1.16.1/src/Vm.sol";
import {LibHexString} from "src/lib/LibHexString.sol";
import {LibCodeGen} from "src/lib/LibCodeGen.sol";

/// @title LibHexStringExternal
/// @notice Forces the result of `bytesToHex` across an ABI boundary. The library
/// returns a string whose pointer is deliberately not word aligned, so encoding
/// it as return data is the case most likely to expose a bad pointer.
contract LibHexStringExternal {
    function bytesToHex(Vm vm, bytes memory data) external pure returns (string memory) {
        return LibHexString.bytesToHex(vm, data);
    }
}

/// @title LibHexStringBytesToHexTest
/// @notice `bytesToHex` converts bytes to their hex representation with the
/// leading `0x` removed, because `hex"..."` literals in the generated source do
/// not accept the prefix. The output is spliced into Solidity source that must
/// COMPILE, so these pin the exact emitted characters, the exact length, and the
/// fact that the in place pointer surgery leaves surrounding memory alone.
contract LibHexStringBytesToHexTest is Test {
    /// The known vector. Upper case input nibbles emit as lower case, and every
    /// byte emits as exactly two characters including the leading zero.
    function testBytesToHexKnown() external pure {
        assertEq(LibHexString.bytesToHex(vm, hex"deadBEEF0123"), "deadbeef0123");
    }

    /// Empty bytes are the boundary of the prefix strip: `vm.toString` returns
    /// exactly `0x`, so the whole string is prefix and nothing is left. The
    /// length must be zero, NOT the underflowed `2 - 2` of a longer string, so
    /// this reads the raw length word rather than trusting string equality.
    function testBytesToHexEmpty() external pure {
        string memory hexString = LibHexString.bytesToHex(vm, "");
        uint256 rawLength;
        assembly ("memory-safe") {
            rawLength := mload(hexString)
        }
        assertEq(rawLength, 0);
        assertEq(hexString, "");
        assertEq(bytes(hexString).length, 0);
    }

    /// A zero byte is two characters, not zero characters and not one. Dropping
    /// the leading nibble would emit an odd number of hex nibbles, which does
    /// not compile.
    function testBytesToHexZeroByte() external pure {
        assertEq(LibHexString.bytesToHex(vm, hex"00"), "00");
    }

    /// A single high byte, the shortest non trivial input.
    function testBytesToHexSingleByte() external pure {
        assertEq(LibHexString.bytesToHex(vm, hex"ff"), "ff");
    }

    /// Leading zero bytes are significant in a `hex"..."` literal and must not be
    /// trimmed the way an integer representation would trim them.
    function testBytesToHexLeadingZeroBytes() external pure {
        assertEq(LibHexString.bytesToHex(vm, hex"0000000001"), "0000000001");
    }

    /// The first data word boundary. The string returned by `vm.toString` is
    /// mutated in place at a 2 byte offset, so the case where the payload
    /// straddles a word is the one where a bad copy shows up.
    function testBytesToHexWordBoundary() external pure {
        assertEq(
            LibHexString.bytesToHex(vm, hex"000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"),
            "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
        );
        assertEq(
            LibHexString.bytesToHex(vm, hex"000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20"),
            "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20"
        );
    }

    /// The prefix is removed, not merely expected to be absent. `0x` cannot
    /// appear in hex output, so any `x` in the result is a prefix that survived.
    function testBytesToHexHasNoPrefix(bytes memory data) external pure {
        bytes memory hexBytes = bytes(LibHexString.bytesToHex(vm, data));
        for (uint256 i = 0; i < hexBytes.length; i++) {
            assertTrue(hexBytes[i] != bytes1("x"), "prefix survived");
        }
    }

    /// Two characters per byte, exactly. An off by one here emits an odd number
    /// of hex nibbles and the generated source does not compile.
    function testBytesToHexLength(bytes memory data) external pure {
        assertEq(bytes(LibHexString.bytesToHex(vm, data)).length, data.length * 2);
    }

    /// Every character is a lower case hex nibble. Anything else in the string
    /// terminates or corrupts the `hex"..."` literal it is spliced into.
    function testBytesToHexCharset(bytes memory data) external pure {
        bytes memory hexBytes = bytes(LibHexString.bytesToHex(vm, data));
        for (uint256 i = 0; i < hexBytes.length; i++) {
            uint8 c = uint8(hexBytes[i]);
            assertTrue((c >= 0x30 && c <= 0x39) || (c >= 0x61 && c <= 0x66), "not a lower case hex nibble");
        }
    }

    /// The emitted characters round trip back to the input bytes once the
    /// stripped prefix is put back, so the strip removed the prefix and nothing
    /// else.
    function testBytesToHexRoundTrips(bytes memory data) external pure {
        string memory hexString = LibHexString.bytesToHex(vm, data);
        assertEq(vm.parseBytes(string.concat("0x", hexString)), data);
    }

    /// The result is `vm.toString` with the first two characters gone and the
    /// rest untouched, which is the whole contract of the function.
    function testBytesToHexIsVmToStringWithoutPrefix(bytes memory data) external pure {
        bytes memory full = bytes(vm.toString(data));
        assertEq(full.length, data.length * 2 + 2);
        assertEq(full[0], bytes1("0"));
        assertEq(full[1], bytes1("x"));

        bytes memory expected = new bytes(full.length - 2);
        for (uint256 i = 2; i < full.length; i++) {
            expected[i - 2] = full[i];
        }
        assertEq(LibHexString.bytesToHex(vm, data), string(expected));
    }

    /// Generation is idempotent: the same input produces the same characters
    /// every time, and an earlier result is not disturbed by a later call
    /// mutating the buffer of its own `vm.toString`.
    function testBytesToHexRepeatedCallsIndependent() external pure {
        string memory first = LibHexString.bytesToHex(vm, hex"1111111111");
        string memory second = LibHexString.bytesToHex(vm, hex"2222");
        string memory third = LibHexString.bytesToHex(vm, hex"1111111111");
        assertEq(first, "1111111111");
        assertEq(second, "2222");
        assertEq(third, "1111111111");
        assertEq(keccak256(bytes(first)), keccak256(bytes(third)));
    }

    /// The `memory-safe` annotation claims the assembly touches nothing outside
    /// the string it was handed. Memory allocated before the call must survive
    /// it, memory allocated after it must not be clobbered by it, and the free
    /// memory pointer must not move backwards.
    function testBytesToHexLeavesNeighbouringMemoryAlone() external pure {
        bytes memory before = hex"1122334455667788991122334455667788991122334455667788991122334455";
        uint256 freeMemoryPointerBefore;
        assembly ("memory-safe") {
            freeMemoryPointerBefore := mload(0x40)
        }

        string memory hexString = LibHexString.bytesToHex(vm, hex"aabbccddeeff");

        uint256 freeMemoryPointerAfter;
        assembly ("memory-safe") {
            freeMemoryPointerAfter := mload(0x40)
        }
        bytes memory afterwards = hex"99aabbccddeeff0099aabbccddeeff0099aabbccddeeff0099aabbccddeeff00";

        assertEq(hexString, "aabbccddeeff");
        assertEq(
            keccak256(before),
            keccak256(hex"1122334455667788991122334455667788991122334455667788991122334455"),
            "memory allocated before the call was corrupted"
        );
        assertEq(
            keccak256(afterwards),
            keccak256(hex"99aabbccddeeff0099aabbccddeeff0099aabbccddeeff0099aabbccddeeff00"),
            "memory allocated after the call was corrupted"
        );
        assertTrue(freeMemoryPointerAfter >= freeMemoryPointerBefore, "free memory pointer moved backwards");
    }

    /// The returned string lives entirely inside memory that was allocated
    /// during the call, so the pointer surgery never hands back a pointer into
    /// memory that belonged to the caller.
    function testBytesToHexResultIsWithinFreshlyAllocatedMemory() external pure {
        uint256 freeMemoryPointerBefore;
        assembly ("memory-safe") {
            freeMemoryPointerBefore := mload(0x40)
        }

        string memory hexString = LibHexString.bytesToHex(vm, hex"aabbccddeeff");

        uint256 freeMemoryPointerAfter;
        uint256 pointer;
        assembly ("memory-safe") {
            freeMemoryPointerAfter := mload(0x40)
            pointer := hexString
        }

        assertTrue(pointer >= freeMemoryPointerBefore, "result points below memory allocated by the call");
        assertTrue(
            pointer + 0x20 + bytes(hexString).length <= freeMemoryPointerAfter, "result runs past allocated memory"
        );
    }

    /// The result survives ABI encoding as return data. The pointer handed back
    /// is deliberately not word aligned, so a consumer that copies it must still
    /// see the same characters.
    function testBytesToHexSurvivesAbiBoundary(bytes memory data) external {
        LibHexStringExternal external_ = new LibHexStringExternal();
        assertEq(external_.bytesToHex(vm, data), LibHexString.bytesToHex(vm, data));
    }

    /// The caller splices the result straight into a `hex"..."` literal, so the
    /// concatenation the generator actually performs is pinned exactly.
    function testBytesToHexConcatenatesIntoHexLiteral() external pure {
        assertEq(string.concat("hex\"", LibHexString.bytesToHex(vm, hex"aabb"), "\";"), "hex\"aabb\";");
    }

    /// Empty data reaches the generated source as an empty `hex""` literal
    /// rather than a stray `0x`, an odd nibble count, or a truncated statement.
    function testBytesToHexEmptyReachesCallerAsEmptyHexLiteral() external pure {
        assertEq(
            LibCodeGen.bytesConstantString(vm, "/// @dev Nothing.", "NOTHING", ""),
            "\n/// @dev Nothing.\nbytes constant NOTHING = hex\"\";\n"
        );
    }

    /// Data long enough to push the declaration past the wrap threshold still
    /// yields a hex payload of exactly two characters per byte, so the length the
    /// caller measures to decide wrapping is the length it actually emits.
    function testBytesToHexLongData() external pure {
        bytes memory data = new bytes(300);
        for (uint256 i = 0; i < data.length; i++) {
            data[i] = bytes1(uint8(i));
        }
        string memory hexString = LibHexString.bytesToHex(vm, data);
        assertEq(bytes(hexString).length, 600);
        assertEq(vm.parseBytes(string.concat("0x", hexString)), data);
    }
}

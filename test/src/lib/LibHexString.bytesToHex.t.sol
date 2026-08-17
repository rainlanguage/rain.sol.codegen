// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {Vm} from "forge-std-1.16.2/src/Vm.sol";
import {LibHexString, UnexpectedHexString} from "src/lib/LibHexString.sol";
import {LibCodeGen} from "src/lib/LibCodeGen.sol";
import {LibHexStringExternal} from "test/concrete/LibHexStringExternal.sol";
import {NonConformingVm} from "test/concrete/NonConformingVm.sol";

/// @title LibHexStringBytesToHexTest
/// @notice `bytesToHex` converts bytes to their hex representation with the
/// leading `0x` removed, because `hex"..."` literals in the generated source do
/// not accept the prefix. The output is spliced into Solidity source that must
/// COMPILE, so these pin the exact emitted characters, the exact length, and the
/// fact that the in place pointer surgery leaves surrounding memory alone.
contract LibHexStringBytesToHexTest is Test {
    /// `bytesToHex` is an internal library function that is inlined into its
    /// caller, so crossing the ABI boundary and letting `vm.expectRevert` see a
    /// revert both need a deployed callee. It holds no state, so one instance
    /// serves the whole suite.
    LibHexStringExternal internal immutable iExternal;

    constructor() {
        iExternal = new LibHexStringExternal();
    }

    /// A `Vm` whose `toString(bytes)` answers `toStringReturn` for every input.
    /// Each case pins a different return string, so the stub carries it as
    /// construction data and is built per case.
    function vmReturning(string memory toStringReturn) internal returns (Vm) {
        return Vm(address(new NonConformingVm(toStringReturn)));
    }

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

    /// The input belongs to the caller. Converting it must not write through the
    /// pointer it was handed.
    function testBytesToHexDoesNotMutateInput(bytes memory data) external pure {
        uint256 lengthBefore = data.length;
        bytes32 contentBefore = keccak256(data);

        LibHexString.bytesToHex(vm, data);

        assertEq(data.length, lengthBefore, "input length was mutated");
        assertEq(keccak256(data), contentBefore, "input content was mutated");
    }

    /// The payload ends flush with the end of the buffer `vm.toString` allocated
    /// whenever `data.length % 16 == 15`, because the two stripped characters are
    /// exactly the slack in the word rounding. Concatenating forces a copy of the
    /// whole string, which is where a copier reading past the buffer would show
    /// up.
    function testBytesToHexAllocationBoundary() external pure {
        assertEq(
            string.concat("<", LibHexString.bytesToHex(vm, hex"000102030405060708090a0b0c0d0e"), ">"),
            "<000102030405060708090a0b0c0d0e>"
        );
        assertEq(
            string.concat(
                "<",
                LibHexString.bytesToHex(vm, hex"000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e"),
                ">"
            ),
            "<000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e>"
        );
    }

    /// The result survives ABI encoding as return data. The pointer handed back
    /// is deliberately not word aligned, so a consumer that copies it must still
    /// see the same characters.
    function testBytesToHexSurvivesAbiBoundary(bytes memory data) external view {
        assertEq(iExternal.bytesToHex(vm, data), LibHexString.bytesToHex(vm, data));
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

    /// The `Vm` is a parameter, so the string the prefix is stripped from is
    /// whatever the caller's `Vm` returns. The strip is only valid on a string
    /// of `2 * data.length + 2` characters beginning `0x`, and everything below
    /// pins that the library checks that rather than assuming it. The library
    /// call is forced across the ABI boundary because the revert has to happen
    /// in a subcall for `expectRevert` to see it.
    ///
    /// An empty return underflows the length word to `2**256 - 2` if it is not
    /// caught, which is the loudest case and the one that never reverts on its
    /// own.
    function testBytesToHexRevertsOnEmptyVmOutput() external {
        Vm badVm = vmReturning("");
        vm.expectRevert(abi.encodeWithSelector(UnexpectedHexString.selector, "", uint256(6)));
        iExternal.bytesToHex(badVm, hex"aabb");
    }

    /// One character underflows to `2**256 - 1`.
    function testBytesToHexRevertsOnOneCharacterVmOutput() external {
        Vm badVm = vmReturning("Z");
        vm.expectRevert(abi.encodeWithSelector(UnexpectedHexString.selector, "Z", uint256(6)));
        iExternal.bytesToHex(badVm, hex"aabb");
    }

    /// The quiet case. A return of the right length with no `0x` on it does not
    /// underflow anything; it discards two characters of real data and hands
    /// back `"bbcc"`, which reaches generated source as a `hex"..."` literal
    /// that compiles and holds the wrong value.
    function testBytesToHexRevertsOnUnprefixedVmOutput() external {
        Vm badVm = vmReturning("aabbcc");
        vm.expectRevert(abi.encodeWithSelector(UnexpectedHexString.selector, "aabbcc", uint256(6)));
        iExternal.bytesToHex(badVm, hex"aabb");
    }

    /// Both characters of the prefix are checked, not just the second. The
    /// second character here is a correct `x`, so only the check on the first
    /// character rejects this.
    function testBytesToHexRevertsOnWrongFirstPrefixCharacter() external {
        Vm badVm = vmReturning("Zxaabb");
        vm.expectRevert(abi.encodeWithSelector(UnexpectedHexString.selector, "Zxaabb", uint256(6)));
        iExternal.bytesToHex(badVm, hex"aabb");
    }

    /// Both characters of the prefix are checked, not just the first. The first
    /// character here is a correct `0`, so only the check on the second
    /// character rejects this.
    function testBytesToHexRevertsOnWrongSecondPrefixCharacter() external {
        Vm badVm = vmReturning("0Xaabb");
        vm.expectRevert(abi.encodeWithSelector(UnexpectedHexString.selector, "0Xaabb", uint256(6)));
        iExternal.bytesToHex(badVm, hex"aabb");
    }

    /// A correctly prefixed return that is too short for the data encodes fewer
    /// bytes than it claims to. Nothing about the prefix is wrong, so only the
    /// length check catches it.
    function testBytesToHexRevertsOnTruncatedVmOutput() external {
        Vm badVm = vmReturning("0xaa");
        vm.expectRevert(abi.encodeWithSelector(UnexpectedHexString.selector, "0xaa", uint256(6)));
        iExternal.bytesToHex(badVm, hex"aabb");
    }

    /// The length is an equality, not a lower bound, so a return that is too
    /// long is rejected as well.
    function testBytesToHexRevertsOnOverlongVmOutput() external {
        Vm badVm = vmReturning("0xaabbcc");
        vm.expectRevert(abi.encodeWithSelector(UnexpectedHexString.selector, "0xaabbcc", uint256(6)));
        iExternal.bytesToHex(badVm, hex"aabb");
    }

    /// Empty data still requires the two prefix characters, so the shortest
    /// return the library accepts is `0x` and the required length at the bottom
    /// of the range is 2, not 0. An empty return here is short by exactly the
    /// prefix and must be a revert rather than an out of bounds read.
    function testBytesToHexRevertsOnEmptyVmOutputForEmptyData() external {
        Vm badVm = vmReturning("");
        vm.expectRevert(abi.encodeWithSelector(UnexpectedHexString.selector, "", uint256(2)));
        iExternal.bytesToHex(badVm, "");
    }

    /// The payload is checked against the hexadecimal charset, not merely
    /// counted. A return of the right length behind the right prefix whose
    /// payload is not hexadecimal reaches generated source inside a `hex"..."`
    /// literal that does not compile, and the compiler names the generated file
    /// rather than the `Vm` that produced the characters.
    function testBytesToHexRevertsOnNonHexVmOutput() external {
        LibHexStringExternal external_ = new LibHexStringExternal();
        Vm badVm = Vm(address(new NonConformingVm("0xZZZZ")));
        vm.expectRevert(abi.encodeWithSelector(UnexpectedHexString.selector, "0xZZZZ", uint256(6)));
        external_.bytesToHex(badVm, hex"aabb");
    }

    /// `toString(bytes)` is defined to return lower case, so upper case nibbles
    /// are a non conforming return even though they name the same bytes.
    function testBytesToHexRevertsOnUpperCaseVmOutput() external {
        LibHexStringExternal external_ = new LibHexStringExternal();
        Vm badVm = Vm(address(new NonConformingVm("0xAABB")));
        vm.expectRevert(abi.encodeWithSelector(UnexpectedHexString.selector, "0xAABB", uint256(6)));
        external_.bytesToHex(badVm, hex"aabb");
    }

    /// The character immediately after the prefix is checked, so a scan that
    /// begins one character late does not accept this.
    function testBytesToHexRevertsOnNonHexFirstPayloadCharacter() external {
        LibHexStringExternal external_ = new LibHexStringExternal();
        Vm badVm = Vm(address(new NonConformingVm("0xZabb")));
        vm.expectRevert(abi.encodeWithSelector(UnexpectedHexString.selector, "0xZabb", uint256(6)));
        external_.bytesToHex(badVm, hex"aabb");
    }

    /// The final character of the payload is checked, so a scan that stops one
    /// character early does not accept this.
    function testBytesToHexRevertsOnNonHexLastPayloadCharacter() external {
        LibHexStringExternal external_ = new LibHexStringExternal();
        Vm badVm = Vm(address(new NonConformingVm("0xaabZ")));
        vm.expectRevert(abi.encodeWithSelector(UnexpectedHexString.selector, "0xaabZ", uint256(6)));
        external_.bytesToHex(badVm, hex"aabb");
    }

    /// `/` is the character immediately below `0`, the bottom of the digit
    /// range, so only the lower bound of that range rejects it.
    function testBytesToHexRevertsOnCharacterBelowDigitRange() external {
        LibHexStringExternal external_ = new LibHexStringExternal();
        Vm badVm = Vm(address(new NonConformingVm("0x/abb")));
        vm.expectRevert(abi.encodeWithSelector(UnexpectedHexString.selector, "0x/abb", uint256(6)));
        external_.bytesToHex(badVm, hex"aabb");
    }

    /// `:` is the character immediately above `9`, the top of the digit range,
    /// so only the upper bound of that range rejects it.
    function testBytesToHexRevertsOnCharacterAboveDigitRange() external {
        LibHexStringExternal external_ = new LibHexStringExternal();
        Vm badVm = Vm(address(new NonConformingVm("0x:abb")));
        vm.expectRevert(abi.encodeWithSelector(UnexpectedHexString.selector, "0x:abb", uint256(6)));
        external_.bytesToHex(badVm, hex"aabb");
    }

    /// A backtick is the character immediately below `a`, the bottom of the
    /// letter range, so only the lower bound of that range rejects it.
    function testBytesToHexRevertsOnCharacterBelowLetterRange() external {
        LibHexStringExternal external_ = new LibHexStringExternal();
        Vm badVm = Vm(address(new NonConformingVm("0x`abb")));
        vm.expectRevert(abi.encodeWithSelector(UnexpectedHexString.selector, "0x`abb", uint256(6)));
        external_.bytesToHex(badVm, hex"aabb");
    }

    /// `g` is the character immediately above `f`, the top of the letter range,
    /// so only the upper bound of that range rejects it.
    function testBytesToHexRevertsOnCharacterAboveLetterRange() external {
        LibHexStringExternal external_ = new LibHexStringExternal();
        Vm badVm = Vm(address(new NonConformingVm("0xgabb")));
        vm.expectRevert(abi.encodeWithSelector(UnexpectedHexString.selector, "0xgabb", uint256(6)));
        external_.bytesToHex(badVm, hex"aabb");
    }

    /// Every character of the hexadecimal charset is accepted, which includes
    /// the four that sit on the boundaries of the two accepted ranges: `0`, `9`,
    /// `a` and `f`. The charset check narrows what is accepted, so what it must
    /// not narrow is pinned alongside it.
    function testBytesToHexAcceptsEveryHexNibble() external {
        LibHexStringExternal external_ = new LibHexStringExternal();
        Vm conformingVm = Vm(address(new NonConformingVm("0x0123456789abcdef")));
        assertEq(external_.bytesToHex(conformingVm, hex"0011223344556677"), "0123456789abcdef");
    }

    /// The check gates on the shape of the returned string, not on the identity
    /// of the `Vm`. A conforming `Vm` that is not foundry's is still stripped
    /// and returned, so the guard does not quietly narrow the parameter to the
    /// cheatcode address.
    function testBytesToHexAcceptsConformingVm() external {
        Vm conformingVm = vmReturning("0xaabb");
        assertEq(iExternal.bytesToHex(conformingVm, hex"aabb"), "aabb");
    }

    /// The tightest accepted return: the whole string is prefix and nothing is
    /// left, which is what foundry's `Vm` returns for empty data.
    function testBytesToHexAcceptsConformingVmForEmptyData() external {
        Vm conformingVm = vmReturning("0x");
        string memory hexString = iExternal.bytesToHex(conformingVm, "");
        uint256 rawLength;
        assembly ("memory-safe") {
            rawLength := mload(hexString)
        }
        assertEq(rawLength, 0);
        assertEq(hexString, "");
    }

    /// The property behind every case above: for any data and any string a `Vm`
    /// might return, the library either reverts or returns exactly that string
    /// with its first two characters removed. Conformance is derived here from
    /// the definition of `toString(bytes)` rather than read back off the
    /// library, so nothing gets through that does not match the definition.
    ///
    /// A string that is `0x` followed by exactly two characters per input byte
    /// is a vanishing fraction of all strings, so the accepted half of the
    /// property is CONSTRUCTED against the fuzzed data rather than waited for:
    /// an unconstructed return conforms 0 times in 2048 runs. `conforming`
    /// picks which half of the property a run aims at, and the payload is
    /// filled from `filler` so that an accepted string is arbitrary in
    /// everything except the shape the library actually checks. That shape
    /// includes the hexadecimal charset, which an arbitrary `filler` almost
    /// never satisfies, so a constructed payload still lands in the rejected
    /// half most of the time: the accepted half is reached on the order of 55
    /// runs in 2048 rather than on the order of 1024.
    /// Whether a string conforms is still read off its own characters below, so
    /// a `filler` that happens to conform is checked against the accepted half
    /// rather than expected to revert.
    function testBytesToHexStripsOrRevertsForEveryVmOutput(bytes memory data, string memory filler, bool conforming)
        external
    {
        string memory toStringReturn = filler;
        if (conforming) {
            bytes memory fillerBytes = bytes(filler);
            bytes memory payload = new bytes(data.length * 2);
            for (uint256 i = 0; i < payload.length; i++) {
                payload[i] = fillerBytes.length == 0 ? bytes1("a") : fillerBytes[i % fillerBytes.length];
            }
            toStringReturn = string.concat("0x", string(payload));
        }

        Vm stubVm = vmReturning(toStringReturn);

        bytes memory returned = bytes(toStringReturn);
        uint256 expectedLength = data.length * 2 + 2;
        // The length equality implies at least 2 characters, so the prefix
        // reads only happen once indexing them is in bounds.
        bool conforms = returned.length == expectedLength && returned[0] == bytes1("0") && returned[1] == bytes1("x");
        // `toString(bytes)` is defined to emit two lower case hexadecimal
        // nibbles per input byte, so a payload character outside that charset is
        // as non conforming as a wrong length or a missing prefix.
        for (uint256 i = 2; conforms && i < returned.length; i++) {
            uint8 c = uint8(returned[i]);
            conforms = (c >= 0x30 && c <= 0x39) || (c >= 0x61 && c <= 0x66);
        }

        if (conforms) {
            bytes memory expected = new bytes(returned.length - 2);
            for (uint256 i = 2; i < returned.length; i++) {
                expected[i - 2] = returned[i];
            }
            assertEq(iExternal.bytesToHex(stubVm, data), string(expected));
        } else {
            vm.expectRevert(abi.encodeWithSelector(UnexpectedHexString.selector, toStringReturn, expectedLength));
            iExternal.bytesToHex(stubVm, data);
        }
    }
}

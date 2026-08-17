// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibCodeGen, MAX_LINE_LENGTH} from "src/lib/LibCodeGen.sol";
import {LibCodeGenSlow} from "test/lib/LibCodeGenSlow.sol";

/// @dev A checksummed address literal, 42 characters like every other, so the
/// declaration is `72 + name.length` characters long on one line.
address constant SOME_ADDRESS = address(0xc51a14251b0dcF0ae24A96b7153991378938f5F5);
string constant SOME_ADDRESS_STRING = "0xc51a14251b0dcF0ae24A96b7153991378938f5F5";

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

    /// The literal the declaration carries parses back to the address it was
    /// generated from. The literal is sliced out of the emitted text, so the
    /// round trip is a property of what the library wrote.
    function testAddressConstantStringRoundTrips(address data) external view {
        string memory emitted = LibCodeGen.addressConstantString(vm, "/// @dev Fuzz.", "FUZZ", data);
        assertEq(
            emitted, string.concat("\n/// @dev Fuzz.\naddress constant FUZZ = address(", vm.toString(data), ");\n")
        );
        assertEq(vm.parseAddress(LibCodeGenSlow.betweenSlow(emitted, "address(", ")")), data);
    }

    /// The emitted literal is EIP-55 checksummed. `solc` rejects a forty digit
    /// hex literal whose case does not carry the checksum, so a generated file
    /// holding an all-lowercase address does not compile. `vm.parseAddress`
    /// accepts either form, so the round trip cannot tell them apart and this
    /// is stated against a reference that derives the checksum from the
    /// address's own bits.
    function testAddressConstantStringChecksummed(address data) external view {
        string memory emitted = LibCodeGen.addressConstantString(vm, "/// @dev Fuzz.", "FUZZ", data);
        assertEq(LibCodeGenSlow.betweenSlow(emitted, "address(", ")"), LibCodeGenSlow.checksumAddressSlow(data));
    }

    /// A declaration of exactly the maximum length stays on one line. `forge fmt`
    /// leaves a line of exactly `line_length` alone, so wrapping here would be a
    /// reflow the formatter immediately undoes.
    function testAddressConstantStringAtMaxLength() external view {
        string memory name = LibCodeGenSlow.nameOfLengthSlow(48);
        string memory emitted = LibCodeGen.addressConstantString(vm, "/// @dev At max.", name, SOME_ADDRESS);
        assertEq(
            emitted,
            string.concat("\n/// @dev At max.\naddress constant ", name, " = address(", SOME_ADDRESS_STRING, ");\n")
        );
        assertEq(LibCodeGenSlow.longestLineSlow(emitted), MAX_LINE_LENGTH);
    }

    /// One character past the maximum wraps after the `=`, with the value
    /// indented by one tab width on the next line.
    function testAddressConstantStringOverMaxLength() external view {
        string memory name = LibCodeGenSlow.nameOfLengthSlow(49);
        assertEq(
            LibCodeGen.addressConstantString(vm, "/// @dev Over max.", name, SOME_ADDRESS),
            string.concat(
                "\n/// @dev Over max.\naddress constant ", name, " =\n    address(", SOME_ADDRESS_STRING, ");\n"
            )
        );
    }

    /// Whatever the comment, name and address, the emitted text is the
    /// declaration built from those literals, wrapped exactly when measuring the
    /// one line form says it does not fit. Fuzzed over every input because each
    /// term of the library's hand computed sum has to be right for this to hold.
    function testAddressConstantStringMatchesMeasuredLine(string memory comment, string memory name, address data)
        external
        view
    {
        assertEq(
            LibCodeGen.addressConstantString(vm, comment, name, data),
            LibCodeGenSlow.addressConstantStringSlow(vm, comment, name, data)
        );
    }

    /// An empty comment emits no comment line rather than an empty one. Two
    /// consecutive newlines are a blank line that `forge fmt` collapses, so a
    /// generated file carrying one is not stable under the formatter and a
    /// consumer's `forge fmt --check` reds when it regenerates.
    function testAddressConstantStringEmptyComment() external view {
        assertEq(
            LibCodeGen.addressConstantString(vm, "", "NO_COMMENT", SOME_ADDRESS),
            string.concat("\naddress constant NO_COMMENT = address(", SOME_ADDRESS_STRING, ");\n")
        );
    }

    /// The comment is the only thing an empty comment removes: the declaration
    /// that follows it is byte for byte the same either way, including the
    /// blank line that separates it from whatever precedes it.
    function testAddressConstantStringEmptyCommentKeepsDeclaration() external view {
        assertEq(
            LibCodeGen.addressConstantString(vm, "/// @dev Some address.", "NO_COMMENT", SOME_ADDRESS),
            string.concat(
                "\n/// @dev Some address.", LibCodeGen.addressConstantString(vm, "", "NO_COMMENT", SOME_ADDRESS)
            )
        );
    }
}

// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.16.2/src/Vm.sol";
import {IOpcodeToolingV1} from "../interface/IOpcodeToolingV1.sol";
import {IParserToolingV1} from "../interface/IParserToolingV1.sol";
import {ISubParserToolingV1} from "../interface/ISubParserToolingV1.sol";
import {IIntegrityToolingV1} from "../interface/IIntegrityToolingV1.sol";
import {LibHexString} from "./LibHexString.sol";

/// @dev Maximum length of a line in the generated code. Important limit for
/// compatibility with formatters such as `forge fmt`.
uint256 constant MAX_LINE_LENGTH = 120;

/// @dev Newline string used when a line exceeds the max length. Indentation
/// needs to match what formatters expect.
string constant NEWLINE_DUE_TO_MAX_LENGTH = "\n    ";

/// @dev The SPDX licence identifier every repo in this org declares for its own
/// source, and so the identifier that heads a file generated into one of them
/// when the caller names none. Exported rather than inlined into the defaulting
/// overload, so a consumer that threads the header through its own build can
/// name the value instead of restating the string.
string constant RAIN_SPDX_LICENSE_IDENTIFIER = "LicenseRef-DCL-1.0";

/// @dev The copyright text every repo in this org declares for its own source,
/// and so the text that heads a file generated into one of them when the caller
/// names none. Exported for the same reason.
string constant RAIN_COPYRIGHT_TEXT = "Copyright (c) 2020 Rain Open Source Software Ltd";

/// Thrown when a name is not a Solidity identifier. Such a name cannot be
/// interpolated into a file path or a constant declaration.
/// @param name The rejected name.
error InvalidIdentifier(string name);

/// Thrown when a bytecode hash is asked for at an address that holds no code.
/// @param instance The address that holds no code.
error CodelessInstance(address instance);

/// Thrown when an SPDX licence identifier is not a non-empty single line. An
/// empty identifier names no licence on a tag that a presence check accepts, and
/// solc refuses the file it heads with "Invalid SPDX license identifier". A line
/// break ends the tag's line so that everything after it lands as source.
/// @param spdxLicenseIdentifier The rejected identifier.
error InvalidSpdxLicenseIdentifier(string spdxLicenseIdentifier);

/// Thrown when a copyright text is not a non-empty single line, for the same
/// reasons the licence identifier has to be one.
/// @param copyrightText The rejected text.
error InvalidCopyrightText(string copyrightText);

/// @title LibCodeGen
/// @notice Library for generating Solidity code snippets for contract function
/// pointers, code hashes, associated comments, etc. All snippets are returned
/// as strings that can be concatenated into complete Solidity files and written
/// to disk by the caller.
library LibCodeGen {
    /// Reverts unless `name` is a Solidity identifier: at least one character,
    /// drawn from ASCII letters, digits, `_` and `$`, and not starting with a
    /// digit. Every name this library interpolates verbatim into generated
    /// source or into a path is one, and being an identifier is what makes that
    /// interpolation safe. A declaration named by an identifier is the
    /// declaration the caller asked for and no other, because no identifier
    /// carries a space, a `;` or any other character that ends a declaration or
    /// starts another. A path built from an identifier stays a direct child of
    /// the directory it is joined to, because no identifier contains a path
    /// separator and none of them is `.` or `..`.
    /// @param name The name to check.
    function requireIdentifier(string memory name) internal pure {
        bytes memory nameBytes = bytes(name);
        if (nameBytes.length == 0) {
            revert InvalidIdentifier(name);
        }
        for (uint256 i = 0; i < nameBytes.length; i++) {
            bytes1 char = nameBytes[i];
            bool isLetter = (char >= 0x41 && char <= 0x5A) || (char >= 0x61 && char <= 0x7A);
            bool isDigit = char >= 0x30 && char <= 0x39;
            bool isUnderscoreOrDollar = char == 0x5F || char == 0x24;
            if (!(isLetter || isUnderscoreOrDollar || (isDigit && i > 0))) {
                revert InvalidIdentifier(name);
            }
        }
    }

    /// The blank line and comment line that precede a constant declaration. The
    /// comment line is emitted only when `comment` is not empty, so a
    /// declaration is preceded by exactly one blank line either way and the
    /// output is stable under `forge fmt`, which collapses consecutive blank
    /// lines.
    /// @param comment The comment to place above the declaration, or the empty
    /// string for no comment.
    /// @return The text that precedes the declaration.
    function commentPrefix(string memory comment) internal pure returns (string memory) {
        return bytes(comment).length == 0 ? "\n" : string.concat("\n", comment, "\n");
    }

    /// True when `text` can be interpolated into a header line as itself: at
    /// least one byte, and no byte that ends a line. Solidity ends a `//`
    /// comment at either a line feed or a carriage return, so a value carrying
    /// one would close the tag's line and continue as source.
    /// @param text The text to check.
    /// @return Whether the text is a non-empty single line.
    function isSingleLine(string memory text) internal pure returns (bool) {
        bytes memory textBytes = bytes(text);
        if (textBytes.length == 0) {
            return false;
        }
        for (uint256 i = 0; i < textBytes.length; i++) {
            if (textBytes[i] == 0x0A || textBytes[i] == 0x0D) {
                return false;
            }
        }
        return true;
    }

    /// The file prefix for autogenerated files outlines the license, pragma,
    /// and a note about the file being autogenerated. The pragma is ^ as the
    /// generated code is expected to be imported into some concrete contract
    /// with pragma = version.
    ///
    /// The generated file lands in the calling project's repo, so the licence it
    /// is under and the copyright holder it names are the calling project's to
    /// state and are taken from the caller. Both are interpolated verbatim into
    /// their tags, and both have to be a non-empty single line for the tag they
    /// land on to say what it appears to.
    ///
    /// The overload taking no arguments makes that statement out of this org's
    /// own values, which is a statement only a repo this org owns can make. A
    /// consumer in another org calls this two argument overload and passes its
    /// own values.
    /// @param spdxLicenseIdentifier The SPDX licence identifier for the
    /// generated file, interpolated verbatim.
    /// @param copyrightText The copyright text for the generated file,
    /// interpolated verbatim.
    /// @return The text that heads the generated file.
    function filePrefix(string memory spdxLicenseIdentifier, string memory copyrightText)
        internal
        pure
        returns (string memory)
    {
        if (!isSingleLine(spdxLicenseIdentifier)) {
            revert InvalidSpdxLicenseIdentifier(spdxLicenseIdentifier);
        }
        if (!isSingleLine(copyrightText)) {
            revert InvalidCopyrightText(copyrightText);
        }
        //REUSE-IgnoreStart
        return string.concat(
            "// SPDX-License-Identifier: ",
            spdxLicenseIdentifier,
            "\n" "// SPDX-FileCopyrightText: ",
            copyrightText,
            "\n" "pragma solidity ^0.8.25;\n\n",
            "// THIS FILE IS AUTOGENERATED BY THE BUILD SCRIPT. DO NOT EDIT BY HAND.\n"
        );
        //REUSE-IgnoreEnd
    }

    /// The file prefix headed by the licence and the copyright text this org's
    /// repos declare for their own source.
    ///
    /// A generated file lands in the calling project's repo, so what it says
    /// about its own licensing is that project's statement to make. This
    /// overload makes it on the caller's behalf out of
    /// `RAIN_SPDX_LICENSE_IDENTIFIER` and `RAIN_COPYRIGHT_TEXT`, which is right
    /// for a repo this org owns and wrong for every other repo. A consumer
    /// elsewhere calls the overload that takes the two values, and passes its
    /// own.
    ///
    /// This is that overload applied to those two constants and nothing else,
    /// so a header written by defaulting is one the caller could have written
    /// out, and every rule that overload puts on either value holds here rather
    /// than being skipped because the values came from the library.
    /// @return The text that heads the generated file.
    function filePrefix() internal pure returns (string memory) {
        return filePrefix(RAIN_SPDX_LICENSE_IDENTIFIER, RAIN_COPYRIGHT_TEXT);
    }

    /// Puts the hash of the bytecode of some contract instance into a constant
    /// string. Often used to ensure that the deployed bytecode matches the
    /// expected bytecode.
    ///
    /// Reverts if `instance` holds no code. A codeless address hashes to
    /// `bytes32(0)` if the account does not exist and to `keccak256("")` if it
    /// does, and `address.codehash` returns those same two values, so a
    /// constant carrying either is satisfied by every codeless address rather
    /// than by the one deployment it names.
    /// @param vm The Vm instance used to format values as strings.
    /// @param instance The address of the contract instance whose bytecode
    /// hash is to be computed.
    /// @return A string containing the Solidity code for the bytecode hash
    /// constant.
    function bytecodeHashConstantString(Vm vm, address instance) internal view returns (string memory) {
        uint256 codeSize;
        bytes32 bytecodeHash;
        assembly {
            codeSize := extcodesize(instance)
            bytecodeHash := extcodehash(instance)
        }
        if (codeSize == 0) {
            revert CodelessInstance(instance);
        }
        return bytes32ConstantString(vm, "/// @dev Hash of the known bytecode.", "BYTECODE_HASH", bytecodeHash);
    }

    /// Puts the opcode function pointers used by the interpreter into a
    /// constant string.
    /// @param vm The Vm instance used to format values as strings.
    /// @param interpreter The interpreter tooling instance to get the
    /// function pointers from.
    /// @return A string containing the Solidity code for the opcode function
    /// pointers constant.
    function opcodeFunctionPointersConstantString(Vm vm, IOpcodeToolingV1 interpreter)
        internal
        view
        returns (string memory)
    {
        return bytesConstantString(
            vm,
            string.concat(
                "/// @dev The function pointers known to the interpreter for dynamic dispatch.\n",
                "/// By setting these as a constant they can be inlined into the interpreter\n",
                "/// and loaded at eval time for very low gas (~100) due to the compiler\n",
                "/// optimising it to a single `codecopy` to build the in memory bytes array."
            ),
            "OPCODE_FUNCTION_POINTERS",
            interpreter.buildOpcodeFunctionPointers()
        );
    }

    /// Puts the literal parser function pointers used by the parser into a
    /// constant string.
    /// @param vm The Vm instance used to format values as strings.
    /// @param instance The parser tooling instance to get the function pointers
    /// from.
    /// @return A string containing the Solidity code for the literal parser
    /// function pointers constant.
    function literalParserFunctionPointersConstantString(Vm vm, IParserToolingV1 instance)
        internal
        view
        returns (string memory)
    {
        return bytesConstantString(
            vm,
            string.concat(
                "/// @dev Every two bytes is a function pointer for a literal parser.\n",
                "/// Literal dispatches are determined by the first byte(s) of the literal\n",
                "/// rather than a full word lookup, and are done with simple conditional\n",
                "/// jumps as the possibilities are limited compared to the number of words we\n",
                "/// have."
            ),
            "LITERAL_PARSER_FUNCTION_POINTERS",
            instance.buildLiteralParserFunctionPointers()
        );
    }

    /// Puts the operand handler function pointers used by the parser into a
    /// constant string.
    /// @param vm The Vm instance used to format values as strings.
    /// @param instance The parser tooling instance to get the function pointers
    /// from.
    /// @return A string containing the Solidity code for the operand handler
    /// function pointers constant.
    function operandHandlerFunctionPointersConstantString(Vm vm, IParserToolingV1 instance)
        internal
        view
        returns (string memory)
    {
        return bytesConstantString(
            vm,
            string.concat(
                "/// @dev Every two bytes is a function pointer for an operand handler.\n",
                "/// These positional indexes all map to the same indexes looked up in the parse\n",
                "/// meta."
            ),
            "OPERAND_HANDLER_FUNCTION_POINTERS",
            instance.buildOperandHandlerFunctionPointers()
        );
    }

    /// Puts the sub parser word parser function pointers used by the sub parser
    /// into a constant string.
    /// @param vm The Vm instance used to format values as strings.
    /// @param subParser The sub parser tooling instance to get the function
    /// pointers from.
    /// @return A string containing the Solidity code for the sub parser word
    /// parsers constant.
    function subParserWordParsersConstantString(Vm vm, ISubParserToolingV1 subParser)
        internal
        view
        returns (string memory)
    {
        return bytesConstantString(
            vm,
            string.concat(
                "/// @dev The function pointers for the sub parser functions that produce the\n",
                "/// bytecode that this contract knows about. This is both constructing the subParser\n",
                "/// bytecode that dials back into this contract at eval time, and mapping\n",
                "/// to things that happen entirely on the interpreter such as well known\n",
                "/// constants and references to the context grid."
            ),
            "SUB_PARSER_WORD_PARSERS",
            subParser.buildSubParserWordParsers()
        );
    }

    /// Puts the integrity check function pointers used by the integrity tooling
    /// into a constant string.
    /// @param vm The Vm instance used to format values as strings.
    /// @param deployer The integrity tooling instance to get the function
    /// pointers from.
    /// @return A string containing the Solidity code for the integrity check
    /// function pointers constant.
    function integrityFunctionPointersConstantString(Vm vm, IIntegrityToolingV1 deployer)
        internal
        view
        returns (string memory)
    {
        return bytesConstantString(
            vm,
            "/// @dev The function pointers for the integrity check fns.",
            "INTEGRITY_FUNCTION_POINTERS",
            deployer.buildIntegrityFunctionPointers()
        );
    }

    /// Puts the hash of the meta that describes the contract into a constant
    /// string.
    ///
    /// This is the only function in this library that touches the filesystem.
    /// It reads `meta/<name>.rain.meta` relative to the project root, so the
    /// calling project's `foundry.toml` has to grant access to that directory:
    ///
    /// ```toml
    /// fs_permissions = [
    ///   { access = "read", path = "meta" },
    /// ]
    /// ```
    ///
    /// Without the grant the read is refused by foundry rather than by this
    /// library, and the error names the permission rather than the missing
    /// grant.
    /// @param vm The Vm instance used to read the meta file and to format
    /// values as strings.
    /// @param name The name of the contract whose meta hash is to be computed.
    /// Has to be a Solidity identifier, as it is interpolated into the path of
    /// the file that is read.
    /// @return A string containing the Solidity code for the described by meta
    /// hash constant.
    function describedByMetaHashConstantString(Vm vm, string memory name) internal view returns (string memory) {
        requireIdentifier(name);
        bytes memory describedByMeta = vm.readFileBinary(string.concat("meta/", name, ".rain.meta"));
        return bytes32ConstantString(
            vm,
            "/// @dev The hash of the meta that describes the contract.",
            "DESCRIBED_BY_META_HASH",
            keccak256(describedByMeta)
        );
    }

    /// Generates a Solidity bytes constant declaration string. Needs special
    /// handling to be formatted nicely due to potential length of hex data and
    /// constant name.
    /// @param vm The Vm instance used to format values as strings.
    /// @param comment The comment to include above the constant declaration.
    /// An empty comment emits no comment line.
    /// @param name The name of the constant, interpolated verbatim. Has to be a
    /// Solidity identifier.
    /// @param data The bytes data for the constant.
    /// @return A string containing the Solidity code for the bytes constant.
    function bytesConstantString(Vm vm, string memory comment, string memory name, bytes memory data)
        internal
        pure
        returns (string memory)
    {
        requireIdentifier(name);
        string memory hexData = LibHexString.bytesToHex(vm, data);
        return string.concat(
            commentPrefix(comment),
            "bytes constant ",
            name,
            " =",
            15 + bytes(name).length + 2 + 1 + 4 + bytes(hexData).length + 2 > MAX_LINE_LENGTH
                ? NEWLINE_DUE_TO_MAX_LENGTH
                : " ",
            "hex\"",
            hexData,
            "\";\n"
        );
    }

    /// Generates a Solidity uint8 constant declaration string. Needs special
    /// handling to be formatted nicely due to potential length of constant name.
    /// @param vm The Vm instance used to format values as strings.
    /// @param comment The comment to include above the constant declaration.
    /// An empty comment emits no comment line.
    /// @param name The name of the constant, interpolated verbatim. Has to be a
    /// Solidity identifier.
    /// @param data The uint8 data for the constant.
    /// @return A string containing the Solidity code for the uint8 constant.
    function uint8ConstantString(Vm vm, string memory comment, string memory name, uint8 data)
        internal
        pure
        returns (string memory)
    {
        requireIdentifier(name);
        string memory intString = vm.toString(data);
        return string.concat(
            commentPrefix(comment),
            "uint8 constant ",
            name,
            " =",
            15 + bytes(name).length + 2 + 1 + bytes(intString).length + 1 > MAX_LINE_LENGTH
                ? NEWLINE_DUE_TO_MAX_LENGTH
                : " ",
            intString,
            ";\n"
        );
    }

    /// Generates a Solidity bytes32 constant declaration string. Wraps the
    /// literal in `bytes32(...)` so the generated source is explicit about the
    /// type rather than relying on a bare hex literal being inferred.
    /// @param vm The Vm instance used to format values as strings.
    /// @param comment The comment to include above the constant declaration.
    /// An empty comment emits no comment line.
    /// @param name The name of the constant, interpolated verbatim. Has to be a
    /// Solidity identifier.
    /// @param data The bytes32 value for the constant.
    /// @return A string containing the Solidity code for the bytes32 constant.
    function bytes32ConstantString(Vm vm, string memory comment, string memory name, bytes32 data)
        internal
        pure
        returns (string memory)
    {
        requireIdentifier(name);
        string memory hexString = vm.toString(data);
        return string.concat(
            commentPrefix(comment),
            "bytes32 constant ",
            name,
            " =",
            17 + bytes(name).length + 2 + 1 + 8 + bytes(hexString).length + 2 > MAX_LINE_LENGTH
                ? NEWLINE_DUE_TO_MAX_LENGTH
                : " ",
            "bytes32(",
            hexString,
            ");\n"
        );
    }

    /// Generates a Solidity address constant declaration string. Wraps the
    /// literal in `address(...)` so the generated source is explicit about the
    /// type rather than relying on a bare hex literal being inferred.
    /// @param vm The Vm instance used to format values as strings.
    /// @param comment The comment to include above the constant declaration.
    /// An empty comment emits no comment line.
    /// @param name The name of the constant, interpolated verbatim. Has to be a
    /// Solidity identifier.
    /// @param data The address for the constant.
    /// @return A string containing the Solidity code for the address constant.
    function addressConstantString(Vm vm, string memory comment, string memory name, address data)
        internal
        pure
        returns (string memory)
    {
        requireIdentifier(name);
        string memory addressString = vm.toString(data);
        return string.concat(
            commentPrefix(comment),
            "address constant ",
            name,
            " =",
            17 + bytes(name).length + 2 + 1 + 8 + bytes(addressString).length + 2 > MAX_LINE_LENGTH
                ? NEWLINE_DUE_TO_MAX_LENGTH
                : " ",
            "address(",
            addressString,
            ");\n"
        );
    }
}

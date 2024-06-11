// SPDX-License-Identifier: CAL
pragma solidity ^0.8.25;

import {Vm} from "forge-std/Vm.sol";
import {IOpcodeToolingV1} from "../interface/IOpcodeToolingV1.sol";
import {IParserToolingV1} from "../interface/IParserToolingV1.sol";
import {ISubParserToolingV1} from "../interface/ISubParserToolingV1.sol";
import {IIntegrityToolingV1} from "../interface/IIntegrityToolingV1.sol";
import {AuthoringMetaV2} from "rain.interpreter.interface/interface/IParserV1.sol";
import {LibHexString} from "./LibHexString.sol";
import {LibGenParseMeta} from "./LibGenParseMeta.sol";

uint256 constant MAX_LINE_LENGTH = 120;
string constant NEWLINE_DUE_TO_MAX_LENGTH = "\n    ";

library LibCodeGen {
    function filePrefix() internal pure returns (string memory) {
        return string.concat(
            "// THIS FILE IS AUTOGENERATED BY ./script/BuildPointers.sol\n\n",
            "// This file is committed to the repository because there is a circular\n"
            "// dependency between the contract and its pointers file. The contract\n"
            "// needs the pointers file to exist so that it can compile, and the pointers\n"
            "// file needs the contract to exist so that it can be compiled.\n\n",
            "// SPDX-License-Identifier: CAL\n",
            "pragma solidity =0.8.25;\n"
        );
    }

    function bytecodeHashConstantString(Vm vm, address instance) internal view returns (string memory) {
        bytes32 bytecodeHash;
        assembly {
            bytecodeHash := extcodehash(instance)
        }
        return string.concat(
            "\n",
            "/// @dev Hash of the known bytecode.\n",
            "bytes32 constant BYTECODE_HASH = bytes32(",
            vm.toString(bytecodeHash),
            ");\n"
        );
    }

    function opcodeFunctionPointersConstantString(Vm vm, IOpcodeToolingV1 interpreter)
        internal
        view
        returns (string memory)
    {
        string memory functionPointers = LibHexString.bytesToHex(vm, interpreter.buildOpcodeFunctionPointers());
        return string.concat(
            "\n",
            "/// @dev The function pointers known to the interpreter for dynamic dispatch.\n",
            "/// By setting these as a constant they can be inlined into the interpreter\n",
            "/// and loaded at eval time for very low gas (~100) due to the compiler\n",
            "/// optimising it to a single `codecopy` to build the in memory bytes array.\n",
            "bytes constant OPCODE_FUNCTION_POINTERS =",
            bytes(functionPointers).length + 43 > MAX_LINE_LENGTH ? NEWLINE_DUE_TO_MAX_LENGTH : " ",
            "hex\"",
            functionPointers,
            "\";\n"
        );
    }

    function literalParserFunctionPointersConstantString(Vm vm, IParserToolingV1 instance)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            "\n",
            "/// @dev Every two bytes is a function pointer for a literal parser.\n",
            "/// Literal dispatches are determined by the first byte(s) of the literal\n",
            "/// rather than a full word lookup, and are done with simple conditional\n",
            "/// jumps as the possibilities are limited compared to the number of words we\n" "/// have.\n",
            "bytes constant LITERAL_PARSER_FUNCTION_POINTERS = hex\"",
            LibHexString.bytesToHex(vm, instance.buildLiteralParserFunctionPointers()),
            "\";\n"
        );
    }

    function operandHandlerFunctionPointersConstantString(Vm vm, IParserToolingV1 instance)
        internal
        pure
        returns (string memory)
    {
        string memory operandHandlerFunctionPointers =
            LibHexString.bytesToHex(vm, instance.buildOperandHandlerFunctionPointers());
        return string.concat(
            "\n",
            "/// @dev Every two bytes is a function pointer for an operand handler.\n",
            "/// These positional indexes all map to the same indexes looked up in the parse\n",
            "/// meta.\n",
            "bytes constant OPERAND_HANDLER_FUNCTION_POINTERS =",
            bytes(operandHandlerFunctionPointers).length + 52 > MAX_LINE_LENGTH ? NEWLINE_DUE_TO_MAX_LENGTH : " ",
            "hex\"",
            operandHandlerFunctionPointers,
            "\";\n"
        );
    }

    function parseMetaConstantString(Vm vm, bytes memory authoringMetaBytes, uint8 buildDepth)
        internal
        pure
        returns (string memory)
    {
        AuthoringMetaV2[] memory authoringMeta = abi.decode(authoringMetaBytes, (AuthoringMetaV2[]));
        string memory parseMeta = LibHexString.bytesToHex(LibGenParseMeta.buildParseMetaV2(authoringMeta, buildDepth));
        return string.concat(
            "\n",
            "/// @dev Encodes the parser meta that is used to lookup word definitions.\n",
            "/// The structure of the parser meta is:\n",
            "/// - 1 byte: The depth of the bloom filters\n",
            "/// - 1 byte: The hashing seed\n",
            "/// - The bloom filters, each is 32 bytes long, one for each build depth.\n",
            "/// - All the items for each word, each is 4 bytes long. Each item's first byte\n",
            "///   is its opcode index, the remaining 3 bytes are the word fingerprint.\n",
            "/// To do a lookup, the word is hashed with the seed, then the first byte of the\n",
            "/// hash is compared against the bloom filter. If there is a hit then we count\n",
            "/// the number of 1 bits in the bloom filter up to this item's 1 bit. We then\n",
            "/// treat this a the index of the item in the items array. We then compare the\n",
            "/// word fingerprint against the fingerprint of the item at this index. If the\n",
            "/// fingerprints equal then we have a match, else we increment the seed and try\n",
            "/// again with the next bloom filter, offsetting all the indexes by the total\n",
            "/// bit count of the previous bloom filter. If we reach the end of the bloom\n",
            "/// filters then we have a miss.\n",
            "bytes constant PARSE_META =",
            bytes(parseMeta).length + 34 > MAX_LINE_LENGTH ? NEWLINE_DUE_TO_MAX_LENGTH : " ",
            "hex\"",
            parseMeta,
            "\";\n\n",
            "/// @dev The build depth of the parser meta.\n",
            "uint8 constant PARSE_META_BUILD_DEPTH = ",
            vm.toString(buildDepth),
            ";\n"
        );
    }

    function subParserWordParsersConstantString(Vm vm, ISubParserToolingV1 subParser)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            "\n",
            "/// @dev Real function pointers to the sub parser functions that produce the\n",
            "/// bytecode that this contract knows about. This is both constructing the subParser\n",
            "/// bytecode that dials back into this contract at eval time, and mapping\n",
            "/// to things that happen entirely on the interpreter such as well known\n",
            "/// constants and references to the context grid.\n",
            "bytes constant SUB_PARSER_WORD_PARSERS = hex\"",
            LibHexString.bytesToHex(vm, subParser.buildSubParserWordParsers()),
            "\";\n"
        );
    }

    function integrityFunctionPointersConstantString(Vm vm, IIntegrityToolingV1 deployer)
        internal
        view
        returns (string memory)
    {
        string memory integrityFunctionPointers = LibHexString.bytesToHex(vm, deployer.buildIntegrityFunctionPointers());
        return string.concat(
            "\n",
            "/// @dev The function pointers for the integrity check fns.\n",
            "bytes constant INTEGRITY_FUNCTION_POINTERS =",
            bytes(integrityFunctionPointers).length + 46 > MAX_LINE_LENGTH ? NEWLINE_DUE_TO_MAX_LENGTH : " ",
            "hex\"",
            integrityFunctionPointers,
            "\";\n"
        );
    }

    function describedByMetaHashConstantString(Vm vm, string memory name) internal view returns (string memory) {
        bytes memory describedByMeta = vm.readFileBinary(string.concat("meta/", name, ".rain.meta"));
        return string.concat(
            "\n",
            "/// @dev The hash of the meta that describes the contract.\n",
            "bytes32 constant DESCRIBED_BY_META_HASH = bytes32(",
            vm.toString(keccak256(describedByMeta)),
            ");\n"
        );
    }
}

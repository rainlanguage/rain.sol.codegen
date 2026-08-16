// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

/// @dev The library whose emitting surface the README has to describe.
string constant LIB_CODE_GEN_PATH = "src/lib/LibCodeGen.sol";

/// @dev The file under test.
string constant README_PATH = "README.md";

/// @dev Every function in `LibCodeGen` that emits a generated declaration ends
/// its name with this. The functions that do not are the identifier check, the
/// comment prefix and the file prefix, none of which emit a constant.
string constant EMITTER_SUFFIX = "ConstantString";

/// @dev The README's opening description runs from the top of the file to the
/// first section heading. Everything below that line belongs to a section and
/// describes how to work on the repo rather than what it emits.
string constant FIRST_HEADING = "\n## ";

/// @dev The number of emitters `LibCodeGen` declares. Asserted so that a
/// scanner that silently stops matching declarations fails rather than passing
/// over an empty list, and so that adding or removing an emitter lands here as
/// well as in the phrase map below.
uint256 constant EXPECTED_EMITTER_COUNT = 11;

/// @dev Upper bound on emitters the scanner will collect before it gives up.
/// Only bounds the scratch array; exceeding it fails the test.
uint256 constant MAX_EMITTERS = 64;

/// @title LibCodeGenReadmeTest
/// @notice The README's opening tells a reader what this library produces, and
/// the set of things it produces is `LibCodeGen`'s emitting functions. This
/// reads both files off disk and asserts the opening names every category of
/// output the library can emit, so a description narrower than the surface reds
/// the suite.
///
/// The emitter list is scanned out of `src/lib/LibCodeGen.sol` rather than
/// written down here, so a new emitter is an unmapped name that fails rather
/// than a silent gap in the prose.
contract LibCodeGenReadmeTest is Test {
    /// The phrase the README's opening has to carry for `emitter` to count as
    /// described. The empty string means the emitter has no mapping, which the
    /// caller treats as a failure rather than as a pass.
    /// @param emitter The name of an emitting function in `LibCodeGen`.
    /// @return The phrase to look for, or the empty string for no mapping.
    function requiredPhrase(string memory emitter) internal pure returns (string memory) {
        bytes32 key = keccak256(bytes(emitter));

        if (key == keccak256("bytecodeHashConstantString")) {
            return "bytecode hash";
        }
        if (key == keccak256("describedByMetaHashConstantString")) {
            return "meta hash";
        }
        if (
            key == keccak256("opcodeFunctionPointersConstantString")
                || key == keccak256("literalParserFunctionPointersConstantString")
                || key == keccak256("operandHandlerFunctionPointersConstantString")
                || key == keccak256("subParserWordParsersConstantString")
                || key == keccak256("integrityFunctionPointersConstantString")
        ) {
            return "function-pointer";
        }
        if (key == keccak256("bytesConstantString")) {
            return "`bytes`";
        }
        if (key == keccak256("uint8ConstantString")) {
            return "`uint8`";
        }
        if (key == keccak256("bytes32ConstantString")) {
            return "`bytes32`";
        }
        if (key == keccak256("addressConstantString")) {
            return "`address`";
        }
        return "";
    }

    /// The first index at or after `from` where `needle` occurs in `haystack`.
    /// @param haystack The bytes to search.
    /// @param needle The bytes to search for. An empty needle is never found.
    /// @param from The index to start searching at.
    /// @return Whether `needle` was found, and the index it was found at.
    function indexOf(bytes memory haystack, bytes memory needle, uint256 from) internal pure returns (bool, uint256) {
        if (needle.length == 0 || needle.length > haystack.length) {
            return (false, 0);
        }
        for (uint256 i = from; i + needle.length <= haystack.length; i++) {
            bool match_ = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (haystack[i + j] != needle[j]) {
                    match_ = false;
                    break;
                }
            }
            if (match_) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    /// Whether `needle` occurs anywhere in `haystack`.
    /// @param haystack The bytes to search.
    /// @param needle The bytes to search for.
    /// @return Whether `needle` occurs in `haystack`.
    function contains(bytes memory haystack, bytes memory needle) internal pure returns (bool) {
        (bool found,) = indexOf(haystack, needle, 0);
        return found;
    }

    /// `data[start:end]` as a fresh array.
    /// @param data The bytes to copy from.
    /// @param start The inclusive start index.
    /// @param end The exclusive end index.
    /// @return The copied bytes.
    function slice(bytes memory data, uint256 start, uint256 end) internal pure returns (bytes memory) {
        bytes memory out = new bytes(end - start);
        for (uint256 i = 0; i < out.length; i++) {
            out[i] = data[start + i];
        }
        return out;
    }

    /// Whether `char` can appear in a Solidity identifier.
    /// @param char The character to classify.
    /// @return Whether `char` is an identifier character.
    function isIdentifierChar(bytes1 char) internal pure returns (bool) {
        return (char >= 0x41 && char <= 0x5A) || (char >= 0x61 && char <= 0x7A) || (char >= 0x30 && char <= 0x39)
            || char == 0x5F || char == 0x24;
    }

    /// Whether `data` ends with `suffix`.
    /// @param data The bytes to check.
    /// @param suffix The suffix to look for.
    /// @return Whether `data` ends with `suffix`.
    function endsWith(bytes memory data, bytes memory suffix) internal pure returns (bool) {
        if (suffix.length > data.length) {
            return false;
        }
        for (uint256 i = 0; i < suffix.length; i++) {
            if (data[data.length - suffix.length + i] != suffix[i]) {
                return false;
            }
        }
        return true;
    }

    /// The names of every emitting function declared in `source`. A declaration
    /// is `function `, an identifier, then `(`, and an emitter is a declaration
    /// whose name ends with `EMITTER_SUFFIX`. Calls to those same functions are
    /// not declarations and so are not collected twice.
    /// @param source The Solidity source to scan.
    /// @return The emitter names in declaration order.
    function emitterNames(bytes memory source) internal pure returns (string[] memory) {
        bytes memory keyword = bytes("function ");
        bytes memory suffix = bytes(EMITTER_SUFFIX);
        string[] memory found = new string[](MAX_EMITTERS);
        uint256 count = 0;
        uint256 cursor = 0;

        while (true) {
            (bool isFound, uint256 at) = indexOf(source, keyword, cursor);
            if (!isFound) {
                break;
            }
            cursor = at + keyword.length;

            uint256 end = cursor;
            while (end < source.length && isIdentifierChar(source[end])) {
                end++;
            }
            if (end == cursor || end >= source.length || source[end] != "(") {
                continue;
            }

            bytes memory name = slice(source, cursor, end);
            if (endsWith(name, suffix)) {
                assertLt(count, MAX_EMITTERS, "more emitters than the scanner can hold");
                found[count] = string(name);
                count++;
            }
        }

        string[] memory names = new string[](count);
        for (uint256 i = 0; i < count; i++) {
            names[i] = found[i];
        }
        return names;
    }

    /// The README's opening description: the top of the file down to the first
    /// section heading.
    /// @param readme The whole README.
    /// @return The opening description.
    function readmeOpening(bytes memory readme) internal pure returns (bytes memory) {
        (bool found, uint256 at) = indexOf(readme, bytes(FIRST_HEADING), 0);
        return slice(readme, 0, found ? at : readme.length);
    }

    /// The scanner picks the declarations out of `LibCodeGen` and nothing else.
    /// Without this a scanner that matched nothing would make the description
    /// test below pass over an empty list.
    function testReadmeEmitterScanFindsTheDeclarations() external view {
        string[] memory emitters = emitterNames(bytes(vm.readFile(LIB_CODE_GEN_PATH)));

        assertEq(emitters.length, EXPECTED_EMITTER_COUNT, "emitter count changed, so the README opening has to as well");
        assertEq(emitters[0], "bytecodeHashConstantString");
        assertEq(emitters[1], "opcodeFunctionPointersConstantString");
        assertEq(emitters[2], "literalParserFunctionPointersConstantString");
        assertEq(emitters[3], "operandHandlerFunctionPointersConstantString");
        assertEq(emitters[4], "subParserWordParsersConstantString");
        assertEq(emitters[5], "integrityFunctionPointersConstantString");
        assertEq(emitters[6], "describedByMetaHashConstantString");
        assertEq(emitters[7], "bytesConstantString");
        assertEq(emitters[8], "uint8ConstantString");
        assertEq(emitters[9], "bytes32ConstantString");
        assertEq(emitters[10], "addressConstantString");
    }

    /// The opening description names every category of output `LibCodeGen` can
    /// emit, so a reader is not told the library only does one of them.
    function testReadmeOpeningDescribesEveryEmitter() external view {
        bytes memory opening = readmeOpening(bytes(vm.readFile(README_PATH)));
        string[] memory emitters = emitterNames(bytes(vm.readFile(LIB_CODE_GEN_PATH)));

        for (uint256 i = 0; i < emitters.length; i++) {
            string memory phrase = requiredPhrase(emitters[i]);
            assertGt(bytes(phrase).length, 0, string.concat("no README phrase mapped for ", emitters[i]));
            assertTrue(
                contains(opening, bytes(phrase)),
                string.concat("README opening does not describe ", emitters[i], ", expected phrase: ", phrase)
            );
        }
    }

    /// The opening is what is under test, so it has to be bounded by the first
    /// section heading rather than being the whole file.
    function testReadmeOpeningStopsAtTheFirstHeading() external view {
        bytes memory readme = bytes(vm.readFile(README_PATH));
        bytes memory opening = readmeOpening(readme);

        assertGt(readme.length, opening.length, "README has no section heading to stop at");
        assertFalse(contains(opening, bytes(FIRST_HEADING)), "opening reaches past the first section heading");
        assertTrue(contains(readme, bytes(FIRST_HEADING)), "README has no section heading");
    }
}

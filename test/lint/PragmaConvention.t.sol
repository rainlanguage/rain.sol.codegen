// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {Vm} from "forge-std-1.16.1/src/Vm.sol";
import {GENERATED_DIR} from "src/lib/LibFs.sol";

/// @dev Deeper than any directory nesting the scanned roots hold, so the scan
/// reaches every file under them.
uint64 constant SCAN_MAX_DEPTH = 64;

/// @dev The line every Solidity file's version pragma begins with. The byte
/// that follows it is the operator the convention constrains.
string constant PRAGMA_PREFIX = "pragma solidity ";

/// @dev The line prefix a concrete contract declaration begins with. `abstract
/// contract`, `library` and `interface` declarations begin with a different
/// word, so none of them match.
string constant CONCRETE_PREFIX = "contract ";

/// @dev The operator required of a file that declares no concrete contract.
string constant CARET = "^";

/// @dev The operator required of a file that declares a concrete contract.
string constant PIN = "=";

/// @dev Returned for a search that matched no line.
uint256 constant NOT_FOUND = type(uint256).max;

/// @title PragmaConventionTest
/// @notice Library, abstract and interface files carry a caret range so that a
/// consumer importing them compiles them under its own solc. Concrete files
/// pin an exact version so that the bytecode a deployment produces is the
/// bytecode this repo compiled. The two rules are one property of a file: its
/// pragma operator follows from whether it declares a concrete contract.
contract PragmaConventionTest is Test {
    /// Every first party `.sol` file declares the pragma operator its
    /// declarations call for.
    ///
    /// `GENERATED_DIR` is not scanned. Other tests in this suite create and
    /// delete files there while this one runs, so listing it races with them.
    /// The prefix that heads every file written there, pragma included, is
    /// pinned byte for byte by `LibCodeGenFilePrefixTest.testFilePrefixExact`.
    function testPragmaConvention() external view {
        string[] memory roots = new string[](3);
        roots[0] = "src";
        roots[1] = "test";
        roots[2] = "script";

        for (uint256 i = 0; i < roots.length; i++) {
            uint256 checked = 0;
            Vm.DirEntry[] memory entries = vm.readDir(roots[i], SCAN_MAX_DEPTH);

            for (uint256 j = 0; j < entries.length; j++) {
                string memory path = entries[j].path;
                if (entries[j].isDir || !isSolidityFile(path) || vm.contains(path, GENERATED_DIR)) {
                    continue;
                }

                bytes memory source = bytes(vm.readFile(path));
                bool concrete = afterLinePrefix(source, bytes(CONCRETE_PREFIX)) != NOT_FOUND;
                assertEq(
                    pragmaOperator(source),
                    concrete ? PIN : CARET,
                    string.concat(path, concrete ? " declares a concrete contract" : " declares no concrete contract")
                );
                checked++;
            }

            assertGt(checked, 0, string.concat(roots[i], " holds no Solidity files to check"));
        }
    }

    /// The extension decides which entries the scan reads, so it must match
    /// `.sol` and nothing that merely resembles it.
    function testIsSolidityFileMatchesTheSolExtensionOnly() external pure {
        assertTrue(isSolidityFile("src/lib/LibCodeGen.sol"), "LibCodeGen.sol");
        assertTrue(isSolidityFile(".sol"), "bare extension");
        assertFalse(isSolidityFile("sol"), "no dot");
        assertFalse(isSolidityFile(""), "empty");
        assertFalse(isSolidityFile("src/lib/LibCodeGen.so"), "truncated extension");
        assertFalse(isSolidityFile("src/lib/LibCodeGen.solx"), "extended extension");
        assertFalse(isSolidityFile("src/lib/LibCodeGen.json"), "other extension");
    }

    /// Only a line that begins with the prefix is a declaration. The same bytes
    /// indented or mid line belong to a body, a comment or a string literal.
    function testAfterLinePrefixMatchesOnlyAtLineStart() external pure {
        assertEq(afterLinePrefix(bytes("contract Foo {"), bytes("contract ")), 9, "first line");
        assertEq(afterLinePrefix(bytes("library L {\ncontract Foo {"), bytes("contract ")), 21, "later line");
        assertEq(afterLinePrefix(bytes("  contract Foo {"), bytes("contract ")), NOT_FOUND, "indented");
        assertEq(afterLinePrefix(bytes("abstract contract Foo {"), bytes("contract ")), NOT_FOUND, "abstract");
    }

    /// `NOT_FOUND` whenever no line begins with the prefix, including when the
    /// prefix is longer than the whole input.
    function testAfterLinePrefixNotFound() external pure {
        assertEq(afterLinePrefix(bytes("library L {"), bytes("contract ")), NOT_FOUND, "other declaration");
        assertEq(afterLinePrefix(bytes(""), bytes("contract ")), NOT_FOUND, "empty source");
        assertEq(afterLinePrefix(bytes("con"), bytes("contract ")), NOT_FOUND, "source shorter than prefix");
    }

    /// The operator is the byte the pragma line puts after `PRAGMA_PREFIX`, and
    /// the empty string when the file ends there or declares no pragma at all.
    function testPragmaOperatorReadsTheByteAfterThePrefix() external pure {
        assertEq(pragmaOperator(bytes("pragma solidity ^0.8.25;")), "^", "caret");
        assertEq(pragmaOperator(bytes("// header\npragma solidity =0.8.25;")), "=", "pin after header");
        assertEq(pragmaOperator(bytes("// header only")), "", "no pragma");
        assertEq(pragmaOperator(bytes("pragma solidity ")), "", "nothing after prefix");
    }

    /// The operator that follows `PRAGMA_PREFIX`, as a one character string.
    /// The empty string when `source` declares no version pragma, which is
    /// neither operator and so fails the assertion that consumes this.
    function pragmaOperator(bytes memory source) internal pure returns (string memory) {
        uint256 at = afterLinePrefix(source, bytes(PRAGMA_PREFIX));
        if (at == NOT_FOUND || at == source.length) {
            return "";
        }
        return string(abi.encodePacked(source[at]));
    }

    /// The index of the first byte after the first line of `source` that begins
    /// with `prefix`, or `NOT_FOUND` when no line does.
    ///
    /// Matching a line prefix rather than a substring is what makes a
    /// declaration distinguishable from the same word inside a body, an import
    /// or a string literal: `forge fmt`, which CI enforces, puts every top
    /// level declaration at column zero and indents everything nested.
    function afterLinePrefix(bytes memory source, bytes memory prefix) internal pure returns (uint256) {
        for (uint256 i = 0; i + prefix.length <= source.length; i++) {
            if (i > 0 && source[i - 1] != 0x0a) {
                continue;
            }

            uint256 j = 0;
            while (j < prefix.length && source[i + j] == prefix[j]) {
                j++;
            }
            if (j == prefix.length) {
                return i + prefix.length;
            }
        }
        return NOT_FOUND;
    }

    /// True when `path` names a Solidity source file.
    function isSolidityFile(string memory path) internal pure returns (bool) {
        bytes memory pathBytes = bytes(path);
        bytes memory extension = bytes(".sol");
        if (pathBytes.length < extension.length) {
            return false;
        }

        uint256 offset = pathBytes.length - extension.length;
        for (uint256 i = 0; i < extension.length; i++) {
            if (pathBytes[offset + i] != extension[i]) {
                return false;
            }
        }
        return true;
    }
}

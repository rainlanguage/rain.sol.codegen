// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibCodeGen, InvalidContractName} from "src/lib/LibCodeGen.sol";

/// @title LibCodeGenRequireContractNameTest
/// @notice `requireContractName` is what stands between a caller supplied
/// contract name and a filesystem path built out of it. The rule it enforces is
/// the Solidity identifier: that is what a contract name is, and it is also a
/// character set that cannot express a path separator, a parent directory or an
/// empty basename.
contract LibCodeGenRequireContractNameTest is Test {
    /// Reachable only through an external call so that the revert can be caught
    /// rather than aborting the test.
    function callRequireContractName(string memory name) external pure {
        LibCodeGen.requireContractName(name);
    }

    function assertAccepted(string memory name) internal view {
        this.callRequireContractName(name);
    }

    function assertRejected(string memory name) internal {
        vm.expectRevert(abi.encodeWithSelector(InvalidContractName.selector, name));
        this.callRequireContractName(name);
    }

    /// The names real consumers pass. Every `script/Build.sol` in the Rain org
    /// passes the concrete contract's own name, so these are the shape that must
    /// keep working.
    function testRequireContractNameAcceptsContractNames() external view {
        assertAccepted("CodeGennable");
        assertAccepted("PythWords");
        assertAccepted("RaindexV6SubParser");
        assertAccepted("RainlangExpressionDeployer");
    }

    /// Every character class Solidity allows in an identifier, at both the first
    /// position and a later one, so the rule is Solidity's rather than a
    /// narrower guess at it.
    function testRequireContractNameAcceptsIdentifierCharacters() external view {
        assertAccepted("A");
        assertAccepted("z");
        assertAccepted("_");
        assertAccepted("$");
        assertAccepted("_Foo");
        assertAccepted("$Foo");
        assertAccepted("Foo_Bar");
        assertAccepted("Foo$Bar");
        assertAccepted("Foo0");
        assertAccepted("F0o_$9");
    }

    /// An empty name would build `src/generated/.sol` and `meta/.rain.meta`:
    /// hidden dotfiles that no compiler picks up and `ls` does not show, written
    /// with a success report.
    function testRequireContractNameRejectsEmpty() external {
        assertRejected("");
    }

    /// A digit cannot open a Solidity identifier, so it cannot open a contract
    /// name either.
    function testRequireContractNameRejectsLeadingDigit() external {
        assertRejected("0Foo");
        assertRejected("9");
    }

    /// A separator would target a subdirectory, and `..` would escape the
    /// generated directory entirely. Both are refused by the character rule
    /// rather than by a special case for them.
    function testRequireContractNameRejectsPathCharacters() external {
        assertRejected("sub/Foo");
        assertRejected("..");
        assertRejected(".");
        assertRejected("../../ESCAPED");
        assertRejected("../src/generated/X");
        assertRejected("/Foo");
        assertRejected("Foo/");
        assertRejected("Foo\\Bar");
    }

    /// A name that is otherwise fine but carries anything outside the identifier
    /// set is refused. A dot in particular would collide with the extension the
    /// caller appends.
    function testRequireContractNameRejectsOtherCharacters() external {
        assertRejected("Foo.sol");
        assertRejected("Foo Bar");
        assertRejected("Foo-Bar");
        assertRejected("Foo\n");
        assertRejected(unicode"Foo€");
        assertRejected(string(hex"466f6f00"));
    }

    /// The rejection carries the name that was rejected, so a build script that
    /// generates many files says which one it choked on.
    function testRequireContractNameErrorCarriesTheName() external {
        vm.expectRevert(abi.encodeWithSelector(InvalidContractName.selector, "sub/Foo"));
        this.callRequireContractName("sub/Foo");
    }

    /// Accepting a name is exactly accepting every one of its bytes, so an
    /// accepted name can be rebuilt from the identifier alphabet and nothing
    /// else. Fuzzed so that the check is not merely rejecting the handful of
    /// bad names spelled out above.
    function testRequireContractNameAcceptedNamesAreIdentifiers(string memory name) external {
        bytes memory nameBytes = bytes(name);
        bool expectedValid = nameBytes.length > 0;
        for (uint256 i = 0; i < nameBytes.length; i++) {
            bytes1 char = nameBytes[i];
            bool isLetter = (char >= "A" && char <= "Z") || (char >= "a" && char <= "z");
            bool isDigit = char >= "0" && char <= "9";
            bool isUnderscoreOrDollar = char == "_" || char == "$";
            if (!(isLetter || isUnderscoreOrDollar || (isDigit && i > 0))) {
                expectedValid = false;
                break;
            }
        }

        if (expectedValid) {
            this.callRequireContractName(name);
        } else {
            vm.expectRevert(abi.encodeWithSelector(InvalidContractName.selector, name));
            this.callRequireContractName(name);
        }
    }

    /// No accepted name contains a byte that means anything to a filesystem, so
    /// no accepted name can leave the directory it is interpolated into. Stated
    /// as a property of the accepted set rather than as a list of the sequences
    /// that would escape.
    function testRequireContractNameAcceptedNamesCannotTraverse(string memory name) external {
        try this.callRequireContractName(name) {
            bytes memory nameBytes = bytes(name);
            assertGt(nameBytes.length, 0, "empty name accepted");
            for (uint256 i = 0; i < nameBytes.length; i++) {
                assertNotEq(uint8(nameBytes[i]), uint8(bytes1("/")), "separator accepted");
                assertNotEq(uint8(nameBytes[i]), uint8(bytes1("\\")), "backslash accepted");
                assertNotEq(uint8(nameBytes[i]), uint8(bytes1(".")), "dot accepted");
                assertNotEq(uint8(nameBytes[i]), uint8(bytes1(hex"00")), "nul accepted");
            }
        } catch {}
    }
}

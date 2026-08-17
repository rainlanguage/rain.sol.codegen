// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {LibFs, GENERATED_DIR, InvalidTag} from "src/lib/LibFs.sol";
import {InvalidContractName} from "src/lib/LibCodeGen.sol";
import {LibFsExternal} from "test/concrete/LibFsExternal.sol";
import {LibCodeGenSlow} from "test/lib/LibCodeGenSlow.sol";

/// @title LibFsPathForTaggedContractTest
/// @notice `pathForTaggedContract` puts two caller supplied strings into one
/// path, so it owns the confinement for both of them: it reverts unless the tag
/// is drawn from the tag alphabet and the contract name is a Solidity
/// identifier, and the path it does return carries both of them verbatim.
///
/// The claim under test is that no pair of arguments produces a path outside
/// `GENERATED_DIR`. That is asserted two ways: positionally over constructed
/// arguments, where every byte of the path is accounted for, and as a property
/// over the whole input domain, where any pair the function accepts at all is
/// checked for confinement whatever it was.
contract LibFsPathForTaggedContractTest is Test {
    /// `vm.expectRevert` needs a call frame, and `pathForTaggedContract` is an
    /// internal library function that is inlined into its caller.
    LibFsExternal internal immutable iExternal;

    constructor() {
        iExternal = new LibFsExternal();
    }

    /// The layout the org's release convention puts a frozen deploy pin snapshot
    /// in, and the rolling directory a deploy repo keeps beside it. Pinned
    /// exactly because consumers commit these files and import them by path: the
    /// location is a cross repo contract, not an internal detail.
    function testPathForTaggedContractProducesTheOrgLayout() external pure {
        assertEq(LibFs.pathForTaggedContract("0_1_1", "StoxReceipt"), "src/generated/0_1_1/StoxReceipt.sol");
        assertEq(LibFs.pathForTaggedContract("candidate", "StoxReceipt"), "src/generated/candidate/StoxReceipt.sol");
    }

    /// The untagged path is unchanged by the tagged one existing: a name that
    /// carries its own separator is still refused, so a caller cannot reach the
    /// tagged layout by smuggling the tag through `pathForContract`.
    function testPathForContractStillRefusesASmuggledTag() external {
        vm.expectRevert(abi.encodeWithSelector(InvalidContractName.selector, "0_1_1/StoxReceipt"));
        iExternal.pathForContract("0_1_1/StoxReceipt");
    }

    /// The path is four regions and nothing else: the generated directory, the
    /// tag byte for byte, a separator then the contract name byte for byte, and
    /// the Solidity extension. Asserted positionally over arguments built from
    /// their alphabets, at every length, so that neither argument is quoted,
    /// escaped, trimmed, case folded or truncated on its way into the path. The
    /// length equality is what makes it exhaustive: it forbids any extra byte
    /// anywhere.
    function testPathForTaggedContractStructure(bytes memory tagSeed, bytes memory nameSeed) external pure {
        string memory tag = LibCodeGenSlow.tagFromSeedSlow(tagSeed);
        string memory contractName = LibCodeGenSlow.nameFromSeedSlow(nameSeed);
        bytes memory path = bytes(LibFs.pathForTaggedContract(tag, contractName));
        bytes memory tagBytes = bytes(tag);
        bytes memory nameBytes = bytes(contractName);

        assertEq(path.length, 14 + tagBytes.length + 1 + nameBytes.length + 4, "path has bytes beyond its four regions");
        assertEq(LibCodeGenSlow.sliceSlow(path, 0, 14), bytes("src/generated/"), "generated directory");
        assertEq(LibCodeGenSlow.sliceSlow(path, 14, tagBytes.length), tagBytes, "tag is not verbatim");
        assertEq(LibCodeGenSlow.sliceSlow(path, 14 + tagBytes.length, 1), bytes("/"), "tag separator");
        assertEq(
            LibCodeGenSlow.sliceSlow(path, 15 + tagBytes.length, nameBytes.length),
            nameBytes,
            "contract name is not verbatim"
        );
        assertEq(LibCodeGenSlow.sliceSlow(path, 15 + tagBytes.length + nameBytes.length, 4), bytes(".sol"), "extension");
    }

    /// The path is relative to the project root. An absolute path would resolve
    /// outside the consumer's repo entirely, so the first byte is never a
    /// separator.
    function testPathForTaggedContractIsRelative(bytes memory tagSeed, bytes memory nameSeed) external pure {
        bytes memory path = bytes(
            LibFs.pathForTaggedContract(
                LibCodeGenSlow.tagFromSeedSlow(tagSeed), LibCodeGenSlow.nameFromSeedSlow(nameSeed)
            )
        );
        assertTrue(path.length > 0, "empty path");
        assertNotEq(uint8(path[0]), uint8(bytes1("/")), "path is absolute");
    }

    /// Two tagged contracts must never be handed the same file: generation would
    /// silently overwrite one with the other, and across tags that would rewrite
    /// a frozen snapshot. A different tag or a different name gives a different
    /// path.
    function testPathForTaggedContractDistinctArgumentsDistinctPaths(
        bytes memory tagSeedA,
        bytes memory nameSeedA,
        bytes memory tagSeedB,
        bytes memory nameSeedB
    ) external pure {
        string memory tagA = LibCodeGenSlow.tagFromSeedSlow(tagSeedA);
        string memory nameA = LibCodeGenSlow.nameFromSeedSlow(nameSeedA);
        string memory tagB = LibCodeGenSlow.tagFromSeedSlow(tagSeedB);
        string memory nameB = LibCodeGenSlow.nameFromSeedSlow(nameSeedB);
        vm.assume(
            keccak256(bytes(tagA)) != keccak256(bytes(tagB)) || keccak256(bytes(nameA)) != keccak256(bytes(nameB))
        );
        assertNotEq(LibFs.pathForTaggedContract(tagA, nameA), LibFs.pathForTaggedContract(tagB, nameB));
    }

    /// The tagged path and the untagged path never collide, so generating into a
    /// tag cannot overwrite a file that belongs to no snapshot.
    function testPathForTaggedContractNeverCollidesWithUntagged(bytes memory tagSeed, bytes memory nameSeed)
        external
        pure
    {
        string memory tag = LibCodeGenSlow.tagFromSeedSlow(tagSeed);
        string memory contractName = LibCodeGenSlow.nameFromSeedSlow(nameSeed);
        assertNotEq(LibFs.pathForTaggedContract(tag, contractName), LibFs.pathForContract(contractName));
    }

    /// The number of `/` in `GENERATED_DIR`, counted rather than assumed, so the
    /// segment counting below states a relationship to the constant instead of
    /// to a hardcoded number that moves independently of it.
    function generatedDirSeparators() internal pure returns (uint256 separators) {
        bytes memory generated = bytes(GENERATED_DIR);
        for (uint256 i = 0; i < generated.length; i++) {
            if (generated[i] == "/") {
                separators++;
            }
        }
    }

    /// Every way a path can leave `GENERATED_DIR` or hide inside it, checked
    /// against one path: it begins with the generated directory and a separator,
    /// it adds exactly two segments to it, no segment is empty, and the only dot
    /// anywhere is the extension this library appends. `..` needs a dot, a deeper
    /// directory needs a third separator, and an absolute path or a doubled
    /// separator needs an empty segment, so all of them are excluded together.
    function assertConfined(string memory path) internal pure {
        bytes memory pathBytes = bytes(path);
        bytes memory generated = bytes(GENERATED_DIR);

        assertGt(pathBytes.length, generated.length, "path is no longer than the generated directory");
        for (uint256 i = 0; i < generated.length; i++) {
            assertEq(uint8(pathBytes[i]), uint8(generated[i]), "path does not begin with the generated directory");
        }
        assertEq(uint8(pathBytes[generated.length]), uint8(bytes1("/")), "generated directory is not a path prefix");

        uint256 separators = 0;
        uint256 sinceSeparator = 0;
        for (uint256 i = 0; i < pathBytes.length; i++) {
            if (pathBytes[i] == "/") {
                assertGt(sinceSeparator, 0, "empty path segment");
                separators++;
                sinceSeparator = 0;
            } else {
                if (pathBytes[i] == ".") {
                    assertEq(i, pathBytes.length - 4, "a dot outside the appended extension");
                }
                sinceSeparator++;
            }
        }
        assertGt(sinceSeparator, 0, "path ends in a separator");
        assertEq(separators, generatedDirSeparators() + 2, "the path is not exactly two segments inside the dir");
    }

    /// The confinement invariant over the whole input domain: whatever pair of
    /// strings `pathForTaggedContract` accepts, the path it hands back is inside
    /// `GENERATED_DIR`. Each argument is either arbitrary bytes or built from its
    /// alphabet, chosen by the fuzzer, so the rejected domain is reached by the
    /// raw branches and the accepted domain — which arbitrary bytes essentially
    /// never reach — by the constructed ones. Nothing is assumed away: a pair
    /// that reverts proves confinement by producing no path at all.
    function testPathForTaggedContractAcceptedArgumentsAreConfined(
        bytes memory tagSeed,
        bytes memory nameSeed,
        bool rawTag,
        bool rawName
    ) external {
        string memory tag = rawTag ? string(tagSeed) : LibCodeGenSlow.tagFromSeedSlow(tagSeed);
        string memory contractName = rawName ? string(nameSeed) : LibCodeGenSlow.nameFromSeedSlow(nameSeed);
        try iExternal.pathForTaggedContract(tag, contractName) returns (string memory path) {
            assertTrue(LibCodeGenSlow.isTagSlow(tag), "a tag outside the alphabet was accepted");
            assertTrue(LibCodeGenSlow.isContractNameSlow(contractName), "a name outside the alphabet was accepted");
            assertConfined(path);
        } catch {}
    }

    /// The same confinement, stated over a pair that is an accepted tag and an
    /// accepted name with one byte of one of them replaced by an arbitrary one.
    /// This is the neighbourhood of the accepted domain, which uniform fuzzing
    /// never reaches, and it is where an off by one in either check would show.
    function testPathForTaggedContractOneBadByteIsConfined(
        bytes memory tagSeed,
        bytes memory nameSeed,
        uint256 position,
        uint8 badByte,
        bool inTag
    ) external {
        bytes memory tagBytes = bytes(LibCodeGenSlow.tagFromSeedSlow(tagSeed));
        bytes memory nameBytes = bytes(LibCodeGenSlow.nameFromSeedSlow(nameSeed));
        if (inTag) {
            tagBytes[position % tagBytes.length] = bytes1(badByte);
        } else {
            nameBytes[position % nameBytes.length] = bytes1(badByte);
        }
        try iExternal.pathForTaggedContract(string(tagBytes), string(nameBytes)) returns (string memory path) {
            assertConfined(path);
        } catch {}
    }

    /// No path is produced for the tag at all, and the error names the tag
    /// rather than the contract name, so a build failure says which argument was
    /// wrong.
    function assertTagRejected(string memory tag, string memory contractName) internal {
        vm.expectRevert(abi.encodeWithSelector(InvalidTag.selector, tag));
        iExternal.pathForTaggedContract(tag, contractName);
    }

    /// No path is produced for the contract name at all, and the error names the
    /// contract name.
    function assertNameRejected(string memory tag, string memory contractName) internal {
        vm.expectRevert(abi.encodeWithSelector(InvalidContractName.selector, contractName));
        iExternal.pathForTaggedContract(tag, contractName);
    }

    /// The tags that would escape the generated directory or hide inside it get
    /// no path, behind a contract name that is fine, so the tag is what decides
    /// it.
    function testPathForTaggedContractRejectsTagEscapes() external {
        assertTagRejected("", "Foo");
        assertTagRejected("..", "Foo");
        assertTagRejected("../..", "Foo");
        assertTagRejected("../../ESCAPED", "Foo");
        assertTagRejected(".", "Foo");
        assertTagRejected(".hidden", "Foo");
        assertTagRejected("sub/0_1_1", "Foo");
        assertTagRejected("0_1_1/sub", "Foo");
        assertTagRejected("/0_1_1", "Foo");
        assertTagRejected("0_1_1/", "Foo");
        assertTagRejected("0.1.1", "Foo");
    }

    /// The contract names that would escape or hide get no path either, behind a
    /// tag that is fine. The tagged path is one segment deeper than the untagged
    /// one, so a name that traverses once lands back on an untagged file rather
    /// than outside the repo, which is why the name check has to hold here too.
    function testPathForTaggedContractRejectsNameEscapes() external {
        assertNameRejected("0_1_1", "");
        assertNameRejected("0_1_1", "..");
        assertNameRejected("0_1_1", "../Foo");
        assertNameRejected("0_1_1", "../../ESCAPED");
        assertNameRejected("0_1_1", ".");
        assertNameRejected("0_1_1", ".hidden");
        assertNameRejected("0_1_1", "sub/Foo");
        assertNameRejected("0_1_1", "/Foo");
        assertNameRejected("0_1_1", "Foo/");
        assertNameRejected("0_1_1", "Foo.sol");
    }

    /// A contract name that is a tag but not an identifier is still refused: the
    /// two rules are applied to the argument each belongs to, not to whichever
    /// one happens to pass.
    function testPathForTaggedContractDoesNotApplyTheTagRuleToTheName() external {
        assertNameRejected("0_1_1", "0_1_1");
    }

    /// A tag that is a Solidity identifier is accepted, so the tag rule is not
    /// merely the identifier rule under another name in the direction that
    /// matters either.
    function testPathForTaggedContractAcceptsAnIdentifierTag() external pure {
        assertEq(LibFs.pathForTaggedContract("candidate", "Foo"), "src/generated/candidate/Foo.sol");
    }

    /// Both arguments wrong names the tag, because the tag is checked first. A
    /// build script that gets both wrong is told about the outer one, which is
    /// the one that decides the directory.
    function testPathForTaggedContractRejectsTheTagFirst() external {
        assertTagRejected("../escape", "../escape");
    }

    /// The whole rejected tag domain, not only the tags above.
    function testPathForTaggedContractRejectsEveryNonTag(bytes memory tagBytes) external {
        string memory tag = string(tagBytes);
        vm.assume(!LibCodeGenSlow.isTagSlow(tag));
        assertTagRejected(tag, "Foo");
    }

    /// The whole rejected name domain, not only the names above.
    function testPathForTaggedContractRejectsEveryNonIdentifierName(bytes memory nameBytes) external {
        string memory contractName = string(nameBytes);
        vm.assume(!LibCodeGenSlow.isContractNameSlow(contractName));
        assertNameRejected("0_1_1", contractName);
    }
}

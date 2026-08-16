// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibCodeGen, MAX_LINE_LENGTH, InvalidIdentifier} from "src/lib/LibCodeGen.sol";
import {LibCodeGenSlow} from "./LibCodeGenSlow.sol";

/// @dev `describedByMetaHashConstantString` reads `meta/<name>.rain.meta`, and
/// this repo's `fs_permissions` grants read-write on `meta`, so a fixture goes
/// there under the name the library is given. That the name reaches the path at
/// all is itself asserted below.
///
/// The fixture file is real, shared, mutable state that outlives the EVM: every
/// test here writes it and then removes it. A single path shared across the
/// tests is therefore a race — one test's `removeFile` lands between another's
/// `writeFileBinary` and the library's read, and that test fails with
/// `vm.readFileBinary: ... No such file or directory` on a file it had just
/// written. It reproduced as an intermittent 2-of-5 failure in this suite at a
/// fixed `--fuzz-seed`, so the fuzzer was never involved. Each test owns a
/// distinct path instead, which is what makes them independent of each other.
string constant FIXTURE_STEM = "LibCodeGenDescribedByMetaHashFixture";

/// @dev The fixed part of the declaration. The name and comment are the
/// library's own choice rather than the caller's, so both are pinned exactly:
/// every consumer's generated file is written against this spelling.
string constant DESCRIBED_BY_META_HASH_PREFIX =
    "\n/// @dev The hash of the meta that describes the contract.\nbytes32 constant DESCRIBED_BY_META_HASH = bytes32(";

/// @title LibCodeGenDescribedByMetaHashConstantStringTest
/// @notice `describedByMetaHashConstantString` builds a path out of the name it
/// is given, reads that file, and puts the hash of its contents into a constant.
contract LibCodeGenDescribedByMetaHashConstantStringTest is Test {
    /// `meta/` holds no committed file, so nothing in a fresh clone creates it
    /// and `vm.writeFileBinary` does not create a parent directory. Every
    /// fixture below is removed again, which leaves the directory empty and so
    /// invisible to git.
    function setUp() external {
        vm.createDir("meta", true);
    }

    /// Reachable only through an external call so that a refused or failed read
    /// can be caught and inspected rather than aborting the test.
    function callDescribedByMetaHash(string memory name) external view returns (string memory) {
        return LibCodeGen.describedByMetaHashConstantString(vm, name);
    }

    /// The path this test's own fixture is written to, relative to the repo root.
    function fixturePath(string memory owner) internal pure returns (string memory) {
        return string.concat("meta/", FIXTURE_STEM, owner, ".rain.meta");
    }

    /// The name that makes the library build `fixturePath(owner)`. It stops
    /// short of the `.rain.meta` the library appends, and is a Solidity
    /// identifier because the library rejects a name that is not one.
    function fixtureName(string memory owner) internal pure returns (string memory) {
        return string.concat(FIXTURE_STEM, owner);
    }

    /// The path is `meta/<name>.rain.meta`. The name is not a file that exists
    /// here, so the path is observed through the failed open, which quotes the
    /// path that was asked for. Two names, because a hard coded path would
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
        vm.writeFileBinary(fixturePath("Basic"), meta);
        string memory emitted = LibCodeGen.describedByMetaHashConstantString(vm, fixtureName("Basic"));
        vm.removeFile(fixturePath("Basic"));

        assertEq(emitted, string.concat(DESCRIBED_BY_META_HASH_PREFIX, vm.toString(keccak256(meta)), ");\n"));
    }

    /// Different meta gives a different constant, so the hash is of the contents
    /// rather than of anything fixed.
    function testDescribedByMetaHashConstantStringHashesContents() external {
        bytes memory metaA = hex"1234";
        bytes memory metaB = hex"5678";

        vm.writeFileBinary(fixturePath("HashesContents"), metaA);
        string memory emittedA = LibCodeGen.describedByMetaHashConstantString(vm, fixtureName("HashesContents"));
        vm.writeFileBinary(fixturePath("HashesContents"), metaB);
        string memory emittedB = LibCodeGen.describedByMetaHashConstantString(vm, fixtureName("HashesContents"));
        vm.removeFile(fixturePath("HashesContents"));

        assertEq(emittedA, string.concat(DESCRIBED_BY_META_HASH_PREFIX, vm.toString(keccak256(metaA)), ");\n"));
        assertEq(emittedB, string.concat(DESCRIBED_BY_META_HASH_PREFIX, vm.toString(keccak256(metaB)), ");\n"));
        assertNotEq(emittedA, emittedB);
    }

    /// Reading the same file twice gives the same text, so regenerating a file
    /// does not produce a diff.
    function testDescribedByMetaHashConstantStringIdempotent() external {
        vm.writeFileBinary(fixturePath("Idempotent"), hex"1234");
        string memory first = LibCodeGen.describedByMetaHashConstantString(vm, fixtureName("Idempotent"));
        string memory second = LibCodeGen.describedByMetaHashConstantString(vm, fixtureName("Idempotent"));
        vm.removeFile(fixturePath("Idempotent"));

        assertEq(first, second);
    }

    /// The name is fixed and so is the length of a `bytes32` literal, so this
    /// declaration fits on one line. `DESCRIBED_BY_META_HASH` is the longest
    /// constant name this library chooses for itself, at 118 of the 120
    /// characters available, so it is the one measured.
    function testDescribedByMetaHashConstantStringFitsMaxLength() external {
        vm.writeFileBinary(fixturePath("FitsMaxLength"), hex"1234");
        string memory emitted = LibCodeGen.describedByMetaHashConstantString(vm, fixtureName("FitsMaxLength"));
        vm.removeFile(fixturePath("FitsMaxLength"));

        assertLe(LibCodeGenSlow.longestLineSlow(emitted), MAX_LINE_LENGTH);
    }

    /// The declaration is the one `bytes32ConstantString` builds, so it carries
    /// the same wrap decision as every other `bytes32` constant rather than an
    /// unconditional space of its own. Measured against the naive reference,
    /// which builds the one line form and measures it, so this holds only while
    /// the emitted line is what that measurement says it should be.
    ///
    /// Not fuzzed over the meta, unlike the `bytes32` suite this shares its
    /// reference with: the meta only reaches the declaration as its `keccak256`,
    /// and a `bytes32` is 66 characters whatever it is, so a second value could
    /// not reach a different wrap decision. Fuzzing it would only add fixture
    /// writes to a real directory.
    function testDescribedByMetaHashConstantStringMatchesMeasuredLine() external {
        bytes memory meta = hex"1234";
        vm.writeFileBinary(fixturePath("MatchesMeasuredLine"), meta);
        string memory emitted = LibCodeGen.describedByMetaHashConstantString(vm, fixtureName("MatchesMeasuredLine"));
        vm.removeFile(fixturePath("MatchesMeasuredLine"));

        assertEq(
            emitted,
            LibCodeGenSlow.bytes32ConstantStringSlow(
                vm,
                "/// @dev The hash of the meta that describes the contract.",
                "DESCRIBED_BY_META_HASH",
                keccak256(meta)
            )
        );
    }

    /// The name is interpolated into a path, so a name that is not a Solidity
    /// identifier is refused before any read happens. `..` and `/` would
    /// otherwise reach a file outside `meta/`, and an empty name would read
    /// `meta/.rain.meta`.
    function testDescribedByMetaHashConstantStringRejectsNonIdentifierName() external {
        assertRejectsName("");
        assertRejectsName("../src/generated/X");
        assertRejectsName("../../etc/passwd");
        assertRejectsName("sub/Foo");
        assertRejectsName("Foo.rain");
        assertRejectsName("Foo Bar");
        assertRejectsName("Foo-Bar");
        assertRejectsName("0Foo");
    }

    function assertRejectsName(string memory name) internal {
        vm.expectRevert(abi.encodeWithSelector(InvalidIdentifier.selector, name));
        this.callDescribedByMetaHash(name);
    }

    /// The identifier rule is Solidity's, not a narrower one: leading `_` and
    /// `$`, and digits after the first character, are all part of a contract
    /// name and are accepted. Proven by the read reaching the filesystem, which
    /// only happens once the name is accepted.
    function testDescribedByMetaHashConstantStringAcceptsIdentifierName() external {
        assertRequestsPath("_Foo", "meta/_Foo.rain.meta");
        assertRequestsPath("$Foo", "meta/$Foo.rain.meta");
        assertRequestsPath("Foo1", "meta/Foo1.rain.meta");
        assertRequestsPath("F0o_$1", "meta/F0o_$1.rain.meta");
    }
}

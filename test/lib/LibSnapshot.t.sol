// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibSnapshot} from "src/lib/LibSnapshot.sol";
import {LibFs} from "src/lib/LibFs.sol";

/// @title LibSnapshotTest
/// @notice Exercises the per-release snapshot freeze against this repo's own
/// committed codegen example (`src/generated/CodeGennable.pointers.sol`). Each
/// test removes the tag dir it creates so the working tree stays clean.
contract LibSnapshotTest is Test {
    string internal constant EXAMPLE = "CodeGennable";

    function exampleNames() internal pure returns (string[] memory names) {
        names = new string[](1);
        names[0] = EXAMPLE;
    }

    /// External wrapper so `vm.expectRevert` can catch a revert raised inside
    /// the internal library call.
    function freezeExternal(string[] memory names) external {
        LibSnapshot.freezeSnapshot(vm, names);
    }

    /// The tag is `[package].version` from foundry.toml with dots as
    /// underscores. This repo declares 0.1.0.
    function testDeployTagIsPackageVersionWithUnderscores() external view {
        assertEq(LibSnapshot.deployTag(vm), "0_1_0");
    }

    function testDirAndPathForTag() external pure {
        assertEq(LibSnapshot.dirForTag("0_1_7"), "src/generated/0_1_7");
        assertEq(LibSnapshot.frozenPathForContract("0_1_7", "Foo"), "src/generated/0_1_7/Foo.pointers.sol");
    }

    /// The whole freeze lifecycle, in one test on purpose: the snapshot dir is
    /// keyed off `[package].version`, so every test here would target the SAME
    /// real directory, and cheatcode filesystem writes are not reverted between
    /// tests. Splitting these would race on shared state rather than isolate.
    ///
    /// Covers: freezing copies the generated pointers file in byte for byte; an
    /// IDENTICAL re-freeze is a harmless no-op; and the guard — if the generated
    /// output would change without a `[package].version` bump, freezing REVERTS
    /// rather than silently rewriting the record that consumers of the published
    /// release pin against. That guard is the property the mechanism must never
    /// ship without.
    function testFreezeSnapshotLifecycle() external {
        string memory tag = LibSnapshot.deployTag(vm);
        string memory frozenPath = LibSnapshot.frozenPathForContract(tag, EXAMPLE);
        string memory generated = vm.readFile(LibFs.pathForContract(EXAMPLE));

        LibSnapshot.freezeSnapshot(vm, exampleNames());

        assertTrue(vm.exists(frozenPath), "snapshot not written");
        assertEq(vm.readFile(frozenPath), generated, "snapshot not byte-identical");

        // Identical re-freeze must not revert.
        LibSnapshot.freezeSnapshot(vm, exampleNames());
        assertEq(vm.readFile(frozenPath), generated, "idempotent re-freeze changed the snapshot");

        // Stand in for "the generated output changed but the version didn't":
        // the frozen record now differs from what would be written.
        string memory frozenRecord = "// a previously frozen release record\n";
        vm.writeFile(frozenPath, frozenRecord);

        vm.expectRevert("LibSnapshot: frozen snapshot would change; bump [package].version for a new release");
        this.freezeExternal(exampleNames());

        // The frozen record is left untouched by the reverted freeze.
        assertEq(vm.readFile(frozenPath), frozenRecord, "reverted freeze still wrote");

        vm.removeDir(LibSnapshot.dirForTag(tag), true);
    }
}

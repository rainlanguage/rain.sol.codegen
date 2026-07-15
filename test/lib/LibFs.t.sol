// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibFs} from "src/lib/LibFs.sol";
import {LibSnapshot} from "src/lib/LibSnapshot.sol";

/// @title LibFsTest
contract LibFsTest is Test {
    /// Generated files live under `src/generated/` and are named for the
    /// contract they were generated from. Pinned exactly because consumers
    /// commit this file and import it by path: the location is a cross repo
    /// contract, not an internal detail.
    function testPathForContract() external pure {
        assertEq(LibFs.pathForContract("Foo"), "src/generated/Foo.sol");
    }

    /// A frozen snapshot is a byte for byte copy of the generated file, so its
    /// filename has to track `pathForContract`. These are two separate string
    /// builders in two separate libraries, so nothing but this assertion stops
    /// one from being renamed without the other and silently producing
    /// snapshots whose names no longer match what was generated.
    function testFrozenPathTracksGeneratedFilename() external pure {
        assertEq(
            LibSnapshot.frozenPathForContract("0_1_7", "Foo"),
            vm.replace(LibFs.pathForContract("Foo"), "src/generated/", "src/generated/0_1_7/")
        );
    }
}

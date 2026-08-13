// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibFs} from "src/lib/LibFs.sol";

/// @title LibFsTest
contract LibFsTest is Test {
    /// Generated files live under `src/generated/` and are named for the
    /// contract they were generated from. Pinned exactly because consumers
    /// commit this file and import it by path: the location is a cross repo
    /// contract, not an internal detail.
    function testPathForContract() external pure {
        assertEq(LibFs.pathForContract("Foo"), "src/generated/Foo.sol");
    }
}

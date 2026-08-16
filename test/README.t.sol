// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

/// @title ReadmeTest
/// @notice The published package carries no `foundry.toml`, `soldeer.lock` or
/// `remappings.txt`, and soldeer writes remappings only for a project's own
/// direct dependencies. A consumer therefore learns which forge-std to install
/// from the README or from a failed compile, so the README's claim about
/// forge-std is checked against the pin it has to agree with.
contract ReadmeTest is Test {
    /// The version `foundry.toml` pins is the one the sources are built and
    /// tested against, so it is the one a consumer has to install. A README
    /// naming any other version sends the consumer to a forge-std the imports
    /// cannot resolve.
    function testReadmeNamesPinnedForgeStdVersion() external view {
        string memory version = vm.parseTomlString(vm.readFile("foundry.toml"), ".dependencies.forge-std");
        assertTrue(
            vm.contains(vm.readFile("README.md"), string.concat("forge-std~", version)),
            "README does not name the pinned forge-std version to install"
        );
    }

    /// Imports of forge-std carry the version in the prefix, so forge-std being
    /// present is not enough: it has to be reachable at that exact prefix. A
    /// consumer that only knows the version can still install it somewhere the
    /// imports cannot see, so the README states the prefix as well.
    function testReadmeNamesForgeStdImportPrefix() external view {
        string memory version = vm.parseTomlString(vm.readFile("foundry.toml"), ".dependencies.forge-std");
        assertTrue(
            vm.contains(vm.readFile("README.md"), string.concat("forge-std-", version, "/")),
            "README does not name the forge-std import prefix"
        );
    }
}

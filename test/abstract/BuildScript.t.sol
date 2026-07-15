// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {SpyBuildScript} from "./SpyBuildScript.sol";

/// @title BuildScriptTest
contract BuildScriptTest is Test {
    /// THE property the base exists to enforce. `run()` is the path CI takes on
    /// every build; the tag follows `[package].version`, which release
    /// automation bumps on every publish, so a `run()` that cut would open a
    /// `<tag>/` dir for a release nobody deployed and dirty the tree.
    function testRunBuildsAndCutsNothing() external {
        SpyBuildScript s = new SpyBuildScript();
        s.run();
        assertEq(s.builds(), 1, "run did not build");
        assertEq(s.freezes(), 0, "the CI path cut a snapshot");
    }

    /// Cutting regenerates first: freezing stale output would record a lie.
    function testCutBuildsThenFreezes() external {
        SpyBuildScript s = new SpyBuildScript();
        s.cut();
        assertEq(s.builds(), 1, "cut did not build");
        assertEq(s.freezes(), 1, "cut did not freeze");
    }

    /// Each entrypoint is one pass, so a repeated dispatch is the caller's
    /// choice rather than a hidden loop.
    function testEntrypointsDoNotCompound() external {
        SpyBuildScript s = new SpyBuildScript();
        s.run();
        s.run();
        s.cut();
        assertEq(s.builds(), 3, "builds per dispatch drifted");
        assertEq(s.freezes(), 1, "run freezes");
    }
}

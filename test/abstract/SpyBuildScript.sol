// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BuildScript} from "src/abstract/BuildScript.sol";

/// @notice Counts the hooks instead of running them, so the entrypoints are
/// asserted on dispatch alone. The real `freeze` writes the tag dir named by
/// `[package].version` — shared state that `LibSnapshot.t.sol` also drives, and
/// forge runs test contracts concurrently, so touching it here would race
/// rather than test.
contract SpyBuildScript is BuildScript {
    uint256 public builds;
    uint256 public freezes;

    function build() internal override {
        builds++;
    }

    function snapshotContractNames() internal pure override returns (string[] memory names) {
        names = new string[](0);
    }

    function freeze() internal override {
        freezes++;
    }
}

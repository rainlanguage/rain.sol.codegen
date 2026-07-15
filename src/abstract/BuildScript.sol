// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Script} from "forge-std-1.16.1/src/Script.sol";
import {LibSnapshot} from "../lib/LibSnapshot.sol";

/// @title BuildScript
/// @notice Base for a repo's codegen script. Splits "regenerate the committed
/// generated files" from "cut this release's immutable record" into two
/// entrypoints, and owns both so a consumer cannot merge them back together.
///
/// The split is the whole point. The snapshot tag derives from
/// `[package].version`, which release automation bumps on every publish. A
/// script that cut a snapshot as part of its ordinary build therefore opens a
/// `<tag>/` dir for a release nobody deployed, every time the version moves,
/// and the next regenerate-and-diff finds the tree dirty. `run()` and `cut()`
/// are concrete here precisely so a consumer implements the hooks and has
/// nowhere to cut from the path CI runs.
///
/// Cutting stays independent of deploying. The frozen record carries the
/// creation code, and a Zoltu address is a pure function of it, so a deploy
/// reads the record rather than needing this script to broadcast — the deploy
/// then puts on-chain exactly the bytes that were frozen, instead of
/// re-deriving them.
abstract contract BuildScript is Script {
    /// @notice Write this repo's generated files, e.g. via
    /// `LibFs.buildFileForContract`. Runs on both entrypoints: cutting a record
    /// of stale output would freeze a lie.
    function build() internal virtual;

    /// @notice The contracts whose generated files form this release's frozen
    /// record. Empty for a repo that generates files but freezes none.
    /// @return names The contract names.
    function snapshotContractNames() internal view virtual returns (string[] memory names);

    /// @notice Freeze this release's record. Virtual only so tests can observe
    /// the dispatch; consumers are not expected to override it.
    function freeze() internal virtual {
        LibSnapshot.freezeSnapshot(vm, snapshotContractNames());
    }

    /// @notice Regenerate the committed generated files, cutting nothing. This
    /// is what CI's regenerate-and-diff runs, so it is inert with respect to
    /// the frozen `<tag>/` dirs.
    function run() external {
        build();
    }

    /// @notice Regenerate, then cut this release's record into
    /// `src/generated/<tag>/`. A deliberate act, so it has its own entrypoint:
    /// `forge script <path> --sig 'cut()'`.
    function cut() external {
        build();
        freeze();
    }
}

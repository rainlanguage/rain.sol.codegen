// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.16.1/src/Vm.sol";
import {LibFs} from "./LibFs.sol";

/// @title LibSnapshot
/// @notice Freezes generated files into per-release snapshots under
/// `src/generated/<tag>/`, so every published release keeps an immutable record
/// of its own deployment that consumers of that release can pin against, even
/// after the current generated files advance to a newer release.
///
/// `LibFs` owns "write a generated file for a contract"; this owns "freeze that
/// generated file for this release", one step later.
///
/// The immutability guard ships WITH the mechanism deliberately: freezing
/// without it silently rewrites the record consumers pin against, so a repo
/// cannot adopt snapshots and accidentally omit the safety property.
///
/// @dev The consuming repo's `foundry.toml` must grant read access to itself so
/// `deployTag` can read the release version from it:
/// `fs_permissions = [{ access = "read", path = "foundry.toml" }, ...]`
/// alongside the usual read-write access to `src/generated`.
library LibSnapshot {
    /// @notice The canonical release tag: `foundry.toml` `[package].version`
    /// with dots converted to underscores (`0.1.7` -> `0_1_7`) for the Solidity
    /// directory form. The single definition of the tag form — the version in
    /// `foundry.toml` is the one source of truth for which release is being
    /// built, so the snapshot dir is derived from it rather than restated.
    /// @param vm The Vm instance for file operations.
    /// @return The tag.
    function deployTag(Vm vm) internal view returns (string memory) {
        string memory version = vm.parseTomlString(vm.readFile("foundry.toml"), ".package.version");
        bytes memory versionBytes = bytes(version);
        bytes memory tagBytes = new bytes(versionBytes.length);
        for (uint256 i = 0; i < versionBytes.length; i++) {
            tagBytes[i] = versionBytes[i] == "." ? bytes1("_") : versionBytes[i];
        }
        return string(tagBytes);
    }

    /// @notice The directory holding a release's frozen snapshot.
    /// @param tag The release tag, as returned by `deployTag`.
    /// @return The directory path as a string.
    function dirForTag(string memory tag) internal pure returns (string memory) {
        return string.concat("src/generated/", tag);
    }

    /// @notice The path of a contract's frozen generated file within a release's
    /// snapshot. Mirrors `LibFs.pathForContract` one directory deeper.
    /// @param tag The release tag, as returned by `deployTag`.
    /// @param contractName The name of the contract.
    /// @return The file path as a string.
    function frozenPathForContract(string memory tag, string memory contractName)
        internal
        pure
        returns (string memory)
    {
        return string.concat(dirForTag(tag), "/", contractName, ".sol");
    }

    /// @notice Freeze the current generated files into this release's
    /// snapshot dir. Only the CURRENT `deployTag` dir is ever written — older
    /// releases' snapshots are never touched.
    ///
    /// An existing snapshot is treated as immutable: rewriting it with IDENTICAL
    /// content is a harmless no-op, but a DIFFERENT payload reverts. That only
    /// happens when the generated output changed without a `[package].version`
    /// bump — the change must bump the version so a NEW `<tag>/` dir is written
    /// beside the frozen ones, rather than corrupting the record that consumers
    /// of the already-published release pin against.
    ///
    /// @param vm The Vm instance for file operations.
    /// @param contractNames The contracts whose generated files (as
    /// placed by `LibFs.buildFileForContract`) form this release's record.
    function freezeSnapshot(Vm vm, string[] memory contractNames) internal {
        string memory tag = deployTag(vm);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.createDir(dirForTag(tag), true);
        for (uint256 i = 0; i < contractNames.length; i++) {
            string memory frozenPath = frozenPathForContract(tag, contractNames[i]);
            string memory content = vm.readFile(LibFs.pathForContract(contractNames[i]));
            if (vm.exists(frozenPath)) {
                require(
                    keccak256(bytes(vm.readFile(frozenPath))) == keccak256(bytes(content)),
                    "LibSnapshot: frozen snapshot would change; bump [package].version for a new release"
                );
            }
            //forge-lint: disable-next-line(unsafe-cheatcode)
            vm.writeFile(frozenPath, content);
        }
    }
}

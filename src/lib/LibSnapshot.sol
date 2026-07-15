// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.16.1/src/Vm.sol";
import {LibCodeGen} from "./LibCodeGen.sol";
import {LibFs} from "./LibFs.sol";

/// @title LibSnapshot
/// @notice Freezes generated pointers files into per-release snapshots under
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
    /// @notice The complete deployment record for one deployable, as generated
    /// Solidity source: the deterministic address it lands at, the creation
    /// bytecode it is deployed FROM, and the runtime bytecode it is verified
    /// AGAINST on-chain.
    ///
    /// Pair with `LibFs.buildFileForContract(vm, deployed, name, ...)`, which
    /// prepends `BYTECODE_HASH` derived from the SAME instance. Together that is
    /// the complete pin — address + codehash + creation + runtime — and it is
    /// what makes a past release reproducible and independently verifiable after
    /// the current build diverges:
    ///
    /// - `keccak256(RUNTIME_CODE) == BYTECODE_HASH` — the record self-agrees.
    /// - deploying `CREATION_CODE` reproduces `DEPLOYED_ADDRESS` with that
    ///   runtime on-chain — address and bytecode cannot drift apart.
    ///
    /// A record carrying only address + codehash can do neither. The shape lives
    /// here, rather than being re-assembled in each repo, so a consumer cannot
    /// emit an incomplete record by omission.
    ///
    /// Returns ONLY the constants, so a caller needing extra generated content
    /// (parse meta, function pointers) concatenates rather than forking the
    /// shape.
    ///
    /// @param vm The Vm instance.
    /// @param creationCode The creation bytecode the contract is deployed from.
    /// @param deployed The address it deterministically deploys to, already
    /// deployed so its runtime code can be read.
    /// @return The Solidity source for the record's constants.
    function deployRecordString(Vm vm, bytes memory creationCode, address deployed)
        internal
        view
        returns (string memory)
    {
        return string.concat(
            LibCodeGen.addressConstantString(
                vm,
                "/// @dev Address of the contract deployed via the deterministic\n"
                "/// deployment proxy. Identical across all EVM-compatible networks.",
                "DEPLOYED_ADDRESS",
                deployed
            ),
            LibCodeGen.bytes32ConstantString(
                vm,
                "/// @dev Hash of the runtime bytecode: the deployment's identity.\n"
                "/// Lets a consumer verify what is deployed at the address without\n"
                "/// loading and hashing the runtime bytecode itself.",
                "RUNTIME_CODE_HASH",
                deployed.codehash
            ),
            LibCodeGen.bytes32ConstantString(
                vm,
                "/// @dev Hash of the creation bytecode. This is what a CREATE2 address\n"
                "/// derives from, so a consumer can verify the address without loading\n"
                "/// and hashing the creation bytecode itself.",
                "CREATION_CODE_HASH",
                keccak256(creationCode)
            ),
            LibCodeGen.bytesConstantString(
                vm, "/// @dev The creation bytecode of the contract.", "CREATION_CODE", creationCode
            ),
            LibCodeGen.bytesConstantString(
                vm, "/// @dev The runtime bytecode of the contract.", "RUNTIME_CODE", deployed.code
            )
        );
    }

    /// @notice Build the complete deployment-record file for one deployable.
    ///
    /// Prefer this over calling `LibFs.buildFileForContract` with
    /// `deployRecordString` by hand: it passes `deployed` to `LibFs` ITSELF, so
    /// the prepended `BYTECODE_HASH` is always the real runtime codehash. A
    /// caller wiring those two together manually can pass `address(0)` and emit
    /// `BYTECODE_HASH = 0` — which is worse than omitting it, since a consumer
    /// importing that constant silently compares against nothing.
    ///
    /// @param vm The Vm instance.
    /// @param contractName The contract the record describes.
    /// @param creationCode The creation bytecode it is deployed from.
    /// @param deployed The address it deterministically deploys to, already
    /// deployed so its runtime code can be read.
    /// @param extraBody Additional generated content appended after the record
    /// (parse meta, function pointers). Empty for a plain deployable.
    function buildDeployRecordForContract(
        Vm vm,
        string memory contractName,
        bytes memory creationCode,
        address deployed,
        string memory extraBody
    ) internal {
        LibFs.buildFileForContract(
            vm, deployed, contractName, string.concat(deployRecordString(vm, creationCode, deployed), extraBody)
        );
    }

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

    /// @notice The path of a contract's frozen pointers file within a release's
    /// snapshot. Mirrors `LibFs.pathForContract` one directory deeper.
    /// @param tag The release tag, as returned by `deployTag`.
    /// @param contractName The name of the contract.
    /// @return The file path as a string.
    function frozenPathForContract(string memory tag, string memory contractName)
        internal
        pure
        returns (string memory)
    {
        return string.concat(dirForTag(tag), "/", contractName, ".pointers.sol");
    }

    /// @notice Freeze the current generated pointers files into this release's
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
    /// @param contractNames The contracts whose generated pointers files (as
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

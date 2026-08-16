// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.16.1/src/Vm.sol";

/// @title LibNatSpec
/// @notice Reads back the contract level NatSpec that solc emitted for a
/// compiled contract, so a test can assert what a consumer of the published
/// package actually receives rather than what the source appears to say.
///
/// The tags solc emits are not the tags written in the source. Untagged `///`
/// lines are appended to whichever tag precedes them, so a paragraph written
/// under a title tag is emitted as part of the title and never as a notice.
/// Only the compiler output distinguishes the two, which is why it is what
/// these read.
///
/// The artifact carries the compiler's metadata twice: `metadata`, which is
/// forge's own deserialization of it and holds no `title` key at all, and
/// `rawMetadata`, the string solc produced. The string is the copy that answers
/// for the title, so it is the copy read here, and the notice is read from the
/// same place so that both come from one source.
library LibNatSpec {
    /// The solc metadata for `contractName`, as the JSON string the build
    /// artifact for `sourceFileName` carries it in.
    /// @param vm The Vm instance used to locate and read the artifact.
    /// @param sourceFileName The base name of the source file, with extension,
    /// which is the directory forge writes the artifact under.
    /// @param contractName The name of the contract within that file.
    function metadataJson(Vm vm, string memory sourceFileName, string memory contractName)
        internal
        view
        returns (string memory)
    {
        string memory outDir = vm.parseTomlString(vm.readFile("foundry.toml"), ".profile.default.out");
        string memory artifact = vm.readFile(string.concat(outDir, "/", sourceFileName, "/", contractName, ".json"));
        return vm.parseJsonString(artifact, ".rawMetadata");
    }

    /// The contract level title solc emitted, and whether it emitted one.
    /// @param vm The Vm instance used to locate and read the artifact.
    /// @param sourceFileName The base name of the source file, with extension.
    /// @param contractName The name of the contract within that file.
    function title(Vm vm, string memory sourceFileName, string memory contractName)
        internal
        view
        returns (bool, string memory)
    {
        string memory json = metadataJson(vm, sourceFileName, contractName);
        if (!vm.keyExistsJson(json, ".output.devdoc.title")) {
            return (false, "");
        }
        return (true, vm.parseJsonString(json, ".output.devdoc.title"));
    }

    /// The contract level notice solc emitted, and whether it emitted one.
    /// @param vm The Vm instance used to locate and read the artifact.
    /// @param sourceFileName The base name of the source file, with extension.
    /// @param contractName The name of the contract within that file.
    function notice(Vm vm, string memory sourceFileName, string memory contractName)
        internal
        view
        returns (bool, string memory)
    {
        string memory json = metadataJson(vm, sourceFileName, contractName);
        if (!vm.keyExistsJson(json, ".output.userdoc.notice")) {
            return (false, "");
        }
        return (true, vm.parseJsonString(json, ".output.userdoc.notice"));
    }
}

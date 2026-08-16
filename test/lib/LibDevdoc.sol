// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.16.1/src/Vm.sol";

/// @dev The key solc gives the sole unnamed return value of a function in the
/// `returns` object of its devdoc entry. Unnamed returns are numbered from zero
/// in declaration order, and these functions each declare exactly one.
string constant DEVDOC_SOLE_RETURN_KEY = "_0";

/// @title LibDevdoc
/// @notice Reads the developer documentation solc emits for a contract out of
/// that contract's compiled artifact.
///
/// The artifact is what a consumer of this package receives alongside the ABI,
/// so documentation read through here is documentation that reached the
/// consumer, rather than a source comment that may or may not have survived
/// being tagged. An untagged `///` line is prose that lands in `userdoc` as part
/// of the preceding notice and never appears in `devdoc` at all, which is
/// indistinguishable from a well documented function when the source is read by
/// eye.
library LibDevdoc {
    /// The return documentation of a function's sole return value, exactly as
    /// it appears in the compiled artifact, with solc's own collapsing of the
    /// source line breaks to single spaces already applied.
    ///
    /// A function with no return tag has no `returns` entry rather than an
    /// empty one, so that case is answered with the empty string and the
    /// difference between "documented as nothing" and "not documented" is not
    /// one the caller has to make a cheatcode revert mean.
    /// @param vm The Vm instance used to read and parse the artifact.
    /// @param contractName The name of the contract. Also the name of its source
    /// file and of its artifact, which is how the artifact is located.
    /// @param signature The function's signature as solc keys the devdoc methods
    /// object: the name and the parameter types, with no spaces.
    /// @return The documented return text, or the empty string when the function
    /// carries no return tag.
    function soleReturnDoc(Vm vm, string memory contractName, string memory signature)
        internal
        view
        returns (string memory)
    {
        // The output directory is read from the config rather than written out,
        // so that the artifact is looked for wherever this project's forge
        // actually puts it.
        string memory outDir = vm.parseTomlString(vm.readFile("foundry.toml"), ".profile.default.out");
        string memory artifact = vm.readFile(string.concat(outDir, "/", contractName, ".sol/", contractName, ".json"));
        string memory key =
            string.concat(".metadata.output.devdoc.methods['", signature, "'].returns.", DEVDOC_SOLE_RETURN_KEY);
        return vm.keyExistsJson(artifact, key) ? vm.parseJsonString(artifact, key) : "";
    }
}

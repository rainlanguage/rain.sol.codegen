// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

/// @title NonConformingVm
/// A contract with the shape of `Vm.toString(bytes)` that returns a string
/// chosen at construction rather than the hexadecimal encoding of its input.
/// `LibHexString.bytesToHex` takes its `Vm` as a parameter, so this stands in
/// for a caller that supplies something other than foundry's own `Vm`.
contract NonConformingVm {
    string internal sReturn;

    constructor(string memory toStringReturn) {
        sReturn = toStringReturn;
    }

    function toString(bytes memory) external view returns (string memory) {
        return sReturn;
    }
}

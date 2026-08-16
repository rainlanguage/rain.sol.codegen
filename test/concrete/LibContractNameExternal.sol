// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibContractName} from "src/lib/LibContractName.sol";

/// @title LibContractNameExternal
/// Puts `LibContractName.requireValidContractName` behind a call frame.
/// `vm.expectRevert` needs one, and the library function is internal so it is
/// inlined into whatever calls it.
contract LibContractNameExternal {
    function requireValidContractName(string memory contractName) external pure {
        LibContractName.requireValidContractName(contractName);
    }
}

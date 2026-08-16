// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std-1.16.1/src/Vm.sol";
import {LibAuditLedger} from "test/lib/LibAuditLedger.sol";

/// @title AuditLedgerExternal
/// Puts `LibAuditLedger.requireAppendOrder` behind an ABI boundary so its
/// reverts land in a frame `vm.expectRevert` can observe.
contract AuditLedgerExternal {
    function requireAppendOrder(Vm vm, string memory json) external view {
        LibAuditLedger.requireAppendOrder(vm, json);
    }
}

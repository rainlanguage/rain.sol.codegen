// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.16.1/src/Vm.sol";

/// Thrown when a scan ledger holds no records at all, so it has no newest
/// record for a reader to treat as authoritative.
error EmptyScanLedger();

/// Thrown when a scan record carries no `timestamp`, which leaves its position
/// in the ledger's order unprovable.
/// @param index The index of the record in the ledger array.
error MissingScanTimestamp(uint256 index);

/// Thrown when a scan record's `timestamp` is not `YYYY-MM-DDTHH:MM:SSZ`.
/// @param index The index of the record in the ledger array.
/// @param timestamp The timestamp the record carries.
error MalformedScanTimestamp(uint256 index, string timestamp);

/// Thrown when a scan record is not strictly newer than the record before it,
/// so the ledger's last element is not its newest scan.
/// @param index The index of the record that is not strictly newer.
/// @param earlier The timestamp of the record at `index - 1`.
/// @param later The timestamp of the record at `index`.
error ScanLedgerOutOfOrder(uint256 index, string earlier, string later);

/// @title LibAuditLedger
/// @notice Enforces the ordering invariant that `audit/mutation-test-scans.json`
/// is read under: records are appended in run order, so the last element is the
/// most recent scan.
library LibAuditLedger {
    /// The shape every scan `timestamp` has. A `0` marks a position that must
    /// hold a digit; every other position must hold exactly this character.
    /// Fixing the shape is what makes a lexicographic comparison of two
    /// timestamps a chronological one.
    bytes constant TIMESTAMP_SHAPE = "0000-00-00T00:00:00Z";

    /// Requires that a scan ledger's records are ordered oldest to newest, so
    /// that its last element is its most recent scan.
    ///
    /// Reverts with `EmptyScanLedger` if there are no records,
    /// `MissingScanTimestamp` or `MalformedScanTimestamp` if a record's
    /// timestamp cannot be compared, and `ScanLedgerOutOfOrder` if a record is
    /// not strictly newer than the one before it.
    /// @param vm The Vm instance used to parse the ledger.
    /// @param json The scan ledger, a JSON array of scan records.
    function requireAppendOrder(Vm vm, string memory json) internal view {
        uint256 length = 0;
        while (vm.keyExistsJson(json, string.concat("$[", vm.toString(length), "]"))) {
            length++;
        }
        if (length == 0) {
            revert EmptyScanLedger();
        }

        string memory earlier;
        for (uint256 index = 0; index < length; index++) {
            string memory key = string.concat("$[", vm.toString(index), "].timestamp");
            if (!vm.keyExistsJson(json, key)) {
                revert MissingScanTimestamp(index);
            }
            string memory later = vm.parseJsonString(json, key);
            requireTimestampShape(index, later);
            if (index > 0) {
                requireStrictlyAfter(index, earlier, later);
            }
            earlier = later;
        }
    }

    /// Requires that a timestamp reads `YYYY-MM-DDTHH:MM:SSZ`, the only shape
    /// under which comparing two timestamps as bytes compares them as times.
    ///
    /// Reverts with `MalformedScanTimestamp` if it does not.
    /// @param index The index of the record in the ledger array.
    /// @param timestamp The timestamp the record carries.
    function requireTimestampShape(uint256 index, string memory timestamp) internal pure {
        bytes memory shape = TIMESTAMP_SHAPE;
        bytes memory value = bytes(timestamp);
        if (value.length != shape.length) {
            revert MalformedScanTimestamp(index, timestamp);
        }
        for (uint256 i = 0; i < shape.length; i++) {
            if (shape[i] == "0") {
                if (value[i] < "0" || value[i] > "9") {
                    revert MalformedScanTimestamp(index, timestamp);
                }
            } else if (value[i] != shape[i]) {
                revert MalformedScanTimestamp(index, timestamp);
            }
        }
    }

    /// Requires that `later` is strictly after `earlier`. Two records sharing a
    /// timestamp leave which of them is newest undecidable, so equality is a
    /// violation.
    ///
    /// Reverts with `ScanLedgerOutOfOrder` if it is not.
    /// @param index The index of the record carrying `later`.
    /// @param earlier The timestamp of the record at `index - 1`.
    /// @param later The timestamp of the record at `index`.
    function requireStrictlyAfter(uint256 index, string memory earlier, string memory later) internal pure {
        bytes memory earlierBytes = bytes(earlier);
        bytes memory laterBytes = bytes(later);
        for (uint256 i = 0; i < earlierBytes.length; i++) {
            if (laterBytes[i] > earlierBytes[i]) {
                return;
            }
            if (laterBytes[i] < earlierBytes[i]) {
                revert ScanLedgerOutOfOrder(index, earlier, later);
            }
        }
        revert ScanLedgerOutOfOrder(index, earlier, later);
    }
}

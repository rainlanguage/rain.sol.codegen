// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {
    LibAuditLedger,
    EmptyScanLedger,
    MissingScanTimestamp,
    MalformedScanTimestamp,
    ScanLedgerOutOfOrder
} from "test/lib/LibAuditLedger.sol";
import {AuditLedgerExternal} from "test/concrete/AuditLedgerExternal.sol";

/// @title MutationTestScansTest
/// Binds `audit/mutation-test-scans.json` to the ordering rule `audit/README.md`
/// states it is read under, and proves that rule is enforced rather than merely
/// written down.
contract MutationTestScansTest is Test {
    /// The committed scan ledger this repo's readers treat as authoritative.
    string constant LEDGER_PATH = "audit/mutation-test-scans.json";

    /// A well formed timestamp the fixtures vary one character of at a time.
    string constant BASE_TIMESTAMP = "2026-08-16T14:55:16Z";

    AuditLedgerExternal internal ledger;

    function setUp() external {
        ledger = new AuditLedgerExternal();
    }

    /// The positions of `YYYY-MM-DDTHH:MM:SSZ` that hold a digit.
    function digitPositions() internal pure returns (uint8[14] memory) {
        return [uint8(0), 1, 2, 3, 5, 6, 8, 9, 11, 12, 14, 15, 17, 18];
    }

    /// A scan ledger holding one record per supplied timestamp, in the order
    /// supplied.
    function ledgerJson(string[] memory timestamps) internal pure returns (string memory) {
        string memory json = "[";
        for (uint256 i = 0; i < timestamps.length; i++) {
            if (i > 0) {
                json = string.concat(json, ",");
            }
            json = string.concat(json, "{\"timestamp\":\"", timestamps[i], "\"}");
        }
        return string.concat(json, "]");
    }

    /// A scan ledger holding exactly two records, in the order supplied.
    function ledgerJson(string memory first, string memory second) internal pure returns (string memory) {
        string[] memory timestamps = new string[](2);
        timestamps[0] = first;
        timestamps[1] = second;
        return ledgerJson(timestamps);
    }

    /// `BASE_TIMESTAMP` with the digit at `position` replaced by `digit`.
    function timestampWithDigit(uint256 position, uint8 digit) internal pure returns (string memory) {
        bytes memory timestamp = abi.encodePacked(BASE_TIMESTAMP);
        timestamp[position] = bytes1(uint8(0x30) + digit);
        return string(timestamp);
    }

    /// The committed ledger satisfies the ordering rule, so its last element is
    /// its most recent scan.
    function testCommittedLedgerIsAppendOrdered() external view {
        LibAuditLedger.requireAppendOrder(vm, vm.readFile(LEDGER_PATH));
    }

    /// A ledger with no records has no newest scan.
    function testEmptyLedgerRejected() external {
        vm.expectRevert(abi.encodeWithSelector(EmptyScanLedger.selector));
        ledger.requireAppendOrder(vm, "[]");
    }

    /// A record with no timestamp cannot be placed in the order.
    function testMissingTimestampRejected() external {
        vm.expectRevert(abi.encodeWithSelector(MissingScanTimestamp.selector, 1));
        ledger.requireAppendOrder(
            vm, string.concat("[{\"timestamp\":\"", BASE_TIMESTAMP, "\"},{\"commit\":\"c72eb89\"}]")
        );
    }

    /// A timestamp shorter than the shape is not comparable.
    function testShortTimestampRejected() external {
        string memory short = "2026-08-16T14:55:16";
        vm.expectRevert(abi.encodeWithSelector(MalformedScanTimestamp.selector, 0, short));
        ledger.requireAppendOrder(vm, ledgerJson(short, BASE_TIMESTAMP));
    }

    /// A timestamp longer than the shape is not comparable.
    function testLongTimestampRejected() external {
        string memory long = "2026-08-16T14:55:16.5Z";
        vm.expectRevert(abi.encodeWithSelector(MalformedScanTimestamp.selector, 0, long));
        ledger.requireAppendOrder(vm, ledgerJson(long, BASE_TIMESTAMP));
    }

    /// Every literal position of the shape is required, so a swapped separator
    /// is refused wherever it appears. Position 19 is the `Z`, so this also
    /// covers a timestamp that is not UTC.
    function testWrongSeparatorRejectedAtEveryLiteralPosition() external {
        uint8[6] memory literals = [4, 7, 10, 13, 16, 19];
        for (uint256 i = 0; i < literals.length; i++) {
            bytes memory timestamp = abi.encodePacked(BASE_TIMESTAMP);
            timestamp[literals[i]] = "_";
            vm.expectRevert(abi.encodeWithSelector(MalformedScanTimestamp.selector, 0, string(timestamp)));
            ledger.requireAppendOrder(vm, ledgerJson(string(timestamp), BASE_TIMESTAMP));
        }
    }

    /// Every digit position of the shape is required, so a non-digit is refused
    /// wherever it appears.
    function testNonDigitRejectedAtEveryDigitPosition() external {
        uint8[14] memory positions = digitPositions();
        for (uint256 i = 0; i < positions.length; i++) {
            bytes memory timestamp = abi.encodePacked(BASE_TIMESTAMP);
            timestamp[positions[i]] = "x";
            vm.expectRevert(abi.encodeWithSelector(MalformedScanTimestamp.selector, 0, string(timestamp)));
            ledger.requireAppendOrder(vm, ledgerJson(string(timestamp), BASE_TIMESTAMP));
        }
    }

    /// The index the malformed timestamp is reported at is the record's own.
    function testMalformedTimestampReportsItsOwnIndex() external {
        string memory malformed = "2026-08-16T14:55:1xZ";
        vm.expectRevert(abi.encodeWithSelector(MalformedScanTimestamp.selector, 1, malformed));
        ledger.requireAppendOrder(vm, ledgerJson(BASE_TIMESTAMP, malformed));
    }

    /// Records appended oldest to newest satisfy the rule.
    function testAscendingLedgerAccepted() external view {
        string[] memory timestamps = new string[](3);
        timestamps[0] = "2026-08-16T14:55:16Z";
        timestamps[1] = "2026-08-17T09:00:00Z";
        timestamps[2] = "2027-01-01T00:00:00Z";
        LibAuditLedger.requireAppendOrder(vm, ledgerJson(timestamps));
    }

    /// A record older than the one before it puts the newest scan somewhere
    /// other than the last element.
    function testDescendingLedgerRejected() external {
        string memory newer = "2026-08-17T09:00:00Z";
        vm.expectRevert(abi.encodeWithSelector(ScanLedgerOutOfOrder.selector, 1, newer, BASE_TIMESTAMP));
        ledger.requireAppendOrder(vm, ledgerJson(newer, BASE_TIMESTAMP));
    }

    /// Two records sharing a timestamp leave which of them is newest
    /// undecidable.
    function testEqualTimestampsRejected() external {
        vm.expectRevert(abi.encodeWithSelector(ScanLedgerOutOfOrder.selector, 1, BASE_TIMESTAMP, BASE_TIMESTAMP));
        ledger.requireAppendOrder(vm, ledgerJson(BASE_TIMESTAMP, BASE_TIMESTAMP));
    }

    /// The violation is reported at the first record that breaks the order, not
    /// at the end of the ledger.
    function testOutOfOrderReportsTheFirstOffendingIndex() external {
        string[] memory timestamps = new string[](4);
        timestamps[0] = "2026-08-16T14:55:16Z";
        timestamps[1] = "2026-08-17T09:00:00Z";
        timestamps[2] = "2026-08-16T23:59:59Z";
        timestamps[3] = "2027-01-01T00:00:00Z";
        vm.expectRevert(abi.encodeWithSelector(ScanLedgerOutOfOrder.selector, 2, timestamps[1], timestamps[2]));
        ledger.requireAppendOrder(vm, ledgerJson(timestamps));
    }

    /// The order is decided by every digit of the timestamp, so a difference at
    /// any one of them orders the pair, in exactly one direction.
    function testOrderIsDecidedByEveryDigit(uint256 slot, uint8 lowDigit, uint8 highDigit) external {
        uint8[14] memory positions = digitPositions();
        uint256 position = positions[slot % positions.length];
        lowDigit = uint8(bound(lowDigit, 0, 8));
        highDigit = uint8(bound(highDigit, uint256(lowDigit) + 1, 9));

        string memory low = timestampWithDigit(position, lowDigit);
        string memory high = timestampWithDigit(position, highDigit);

        LibAuditLedger.requireAppendOrder(vm, ledgerJson(low, high));

        vm.expectRevert(abi.encodeWithSelector(ScanLedgerOutOfOrder.selector, 1, high, low));
        ledger.requireAppendOrder(vm, ledgerJson(high, low));
    }
}

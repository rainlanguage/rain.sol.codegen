// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibNatSpec} from "test/lib/LibNatSpec.sol";

/// @title ISubParserToolingV1NoticeTest
/// @notice `ISubParserToolingV1` is published and consumed as an ABI artifact,
/// so its contract level documentation is only as good as the `userdoc` a
/// consumer's tooling reads out of that artifact. What the source file looks
/// like says nothing about that: an untagged `///` paragraph is appended to the
/// tag above it, so a description written under a title tag is emitted as a
/// title that recites the whole paragraph and as no notice at all.
///
/// The two halves of that failure are asserted separately because a fix can
/// produce either one alone. A title that is exactly the interface name is the
/// evidence no description leaked into it, and a non-empty notice is the
/// evidence the description reached the tag consumers read.
contract ISubParserToolingV1NoticeTest is Test {
    /// The interface whose emitted NatSpec is asserted here.
    string internal constant CONTRACT_NAME = "ISubParserToolingV1";

    /// The source file the compiler wrote that interface's artifact for.
    string internal constant SOURCE_FILE_NAME = "ISubParserToolingV1.sol";

    /// The emitted title names the interface and nothing else.
    function testTitleIsTheInterfaceName() external view {
        (bool exists, string memory value) = LibNatSpec.title(vm, SOURCE_FILE_NAME, CONTRACT_NAME);
        assertTrue(exists, "solc emitted no contract level title");
        assertEq(value, CONTRACT_NAME, "the contract level title is not just the interface name");
    }

    /// The description reaches `userdoc` as a contract level notice.
    function testNoticeIsEmitted() external view {
        (bool exists, string memory value) = LibNatSpec.notice(vm, SOURCE_FILE_NAME, CONTRACT_NAME);
        assertTrue(exists, "solc emitted no contract level notice");
        assertTrue(bytes(value).length > 0, "the contract level notice is empty");
    }
}

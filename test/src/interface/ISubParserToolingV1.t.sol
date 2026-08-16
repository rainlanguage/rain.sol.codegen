// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {ISubParserToolingV1} from "src/interface/ISubParserToolingV1.sol";
import {ConformingToolingMock, CONFORMING_SUB_PARSER_WORD_PARSERS} from "test/concrete/ConformingToolingMock.sol";

/// @dev The ERC-165 id of `ISubParserToolingV1` as published. Deployed contracts
/// advertise this value and answer `supportsInterface` for it alone, so an
/// interface whose id is not this one is a different interface and takes a `V2`
/// name rather than this one.
bytes4 constant I_SUB_PARSER_TOOLING_V1_INTERFACE_ID = 0x336284d4;

/// @title ISubParserToolingV1Test
/// @notice `ISubParserToolingV1` is published for other repositories to
/// implement and to probe over ERC-165, so its id and its implementability are
/// both fixed here.
contract ISubParserToolingV1Test is Test {
    /// The id is held against a literal rather than against a recomputation of
    /// itself, so a change to the interface's function set moves the id off the
    /// literal instead of carrying the literal along with it.
    function testISubParserToolingV1InterfaceId() external pure {
        assertEq(bytes32(type(ISubParserToolingV1).interfaceId), bytes32(I_SUB_PARSER_TOOLING_V1_INTERFACE_ID));
    }

    /// A contract that inherits the interface answers the builder at the
    /// interface's own selector, with its own answer rather than with another
    /// builder's, and with the same answer whatever the instance was constructed
    /// with, which is all a `pure` builder is able to do.
    function testISubParserToolingV1ConformingImplementation(
        bytes memory opcodePointers,
        bytes memory integrityPointers
    ) external {
        ConformingToolingMock mock = new ConformingToolingMock(opcodePointers, integrityPointers);
        assertEq(ISubParserToolingV1(address(mock)).buildSubParserWordParsers(), CONFORMING_SUB_PARSER_WORD_PARSERS);
    }
}

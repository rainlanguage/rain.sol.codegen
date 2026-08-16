// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {IParserToolingV1} from "src/interface/IParserToolingV1.sol";
import {
    ConformingToolingMock,
    CONFORMING_LITERAL_PARSER_FUNCTION_POINTERS,
    CONFORMING_OPERAND_HANDLER_FUNCTION_POINTERS
} from "test/concrete/ConformingToolingMock.sol";

/// @dev The ERC-165 id of `IParserToolingV1` as published. Deployed contracts
/// advertise this value and answer `supportsInterface` for it alone, so an
/// interface whose id is not this one is a different interface and takes a `V2`
/// name rather than this one.
bytes4 constant I_PARSER_TOOLING_V1_INTERFACE_ID = 0x1a2c8edd;

/// @title IParserToolingV1Test
/// @notice `IParserToolingV1` is published for other repositories to implement
/// and to probe over ERC-165, so its id and its implementability are both fixed
/// here.
contract IParserToolingV1Test is Test {
    /// The id is held against a literal rather than against a recomputation of
    /// itself, so a change to the interface's function set moves the id off the
    /// literal instead of carrying the literal along with it. This is the only
    /// one of the four ids that is an exclusive or of two selectors rather than
    /// a single selector, so it also moves when the two builders swap names.
    function testIParserToolingV1InterfaceId() external pure {
        assertEq(bytes32(type(IParserToolingV1).interfaceId), bytes32(I_PARSER_TOOLING_V1_INTERFACE_ID));
    }

    /// A contract that inherits the interface answers both builders at the
    /// interface's own selectors, each with its own answer rather than with the
    /// other's, and with the same answer whatever the instance was constructed
    /// with, which is all a `pure` builder is able to do.
    function testIParserToolingV1ConformingImplementation(bytes memory opcodePointers, bytes memory integrityPointers)
        external
    {
        ConformingToolingMock mock = new ConformingToolingMock(opcodePointers, integrityPointers);
        assertEq(
            IParserToolingV1(address(mock)).buildLiteralParserFunctionPointers(),
            CONFORMING_LITERAL_PARSER_FUNCTION_POINTERS
        );
        assertEq(
            IParserToolingV1(address(mock)).buildOperandHandlerFunctionPointers(),
            CONFORMING_OPERAND_HANDLER_FUNCTION_POINTERS
        );
    }
}

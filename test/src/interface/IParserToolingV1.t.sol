// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {IParserToolingV1} from "src/interface/IParserToolingV1.sol";
import {ToolingMock} from "test/concrete/ToolingMock.sol";

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
    /// literal instead of carrying the literal along with it. This is the one id
    /// of the four that is an exclusive or of two selectors rather than a single
    /// selector, so it moves when either builder's name or arguments change, and
    /// it says nothing about which of the two selectors carries which meaning.
    function testIParserToolingV1InterfaceId() external pure {
        assertEq(bytes32(type(IParserToolingV1).interfaceId), bytes32(I_PARSER_TOOLING_V1_INTERFACE_ID));
    }

    /// `ToolingMock` reaches the interface type by assignment rather than by a
    /// cast through `address`, so this compiles only while the mock inherits the
    /// interface, and the mock compiles only while it implements both builders
    /// with the names, arguments, return types and state mutabilities the
    /// interface declares. Each answer then travels its own builder's selector
    /// and return decoding, so the two selectors the id exclusive-ors together
    /// are held apart here even though the id itself cannot tell them apart.
    function testIParserToolingV1ImplementedByToolingMock(
        bytes memory literalParserFunctionPointers,
        bytes memory operandHandlerFunctionPointers,
        bytes memory other
    ) external {
        vm.assume(keccak256(literalParserFunctionPointers) != keccak256(operandHandlerFunctionPointers));
        vm.assume(keccak256(literalParserFunctionPointers) != keccak256(other));
        vm.assume(keccak256(operandHandlerFunctionPointers) != keccak256(other));
        ToolingMock mock = new ToolingMock();
        mock.setAll(other, literalParserFunctionPointers, operandHandlerFunctionPointers, other, other);
        IParserToolingV1 tooling = mock;
        assertEq(tooling.buildLiteralParserFunctionPointers(), literalParserFunctionPointers);
        assertEq(tooling.buildOperandHandlerFunctionPointers(), operandHandlerFunctionPointers);
    }
}

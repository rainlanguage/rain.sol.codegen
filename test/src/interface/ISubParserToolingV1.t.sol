// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {ISubParserToolingV1} from "src/interface/ISubParserToolingV1.sol";
import {ToolingMock} from "test/concrete/ToolingMock.sol";

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

    /// `ToolingMock` reaches the interface type by assignment rather than by a
    /// cast through `address`, so this compiles only while the mock inherits the
    /// interface, and the mock compiles only while it implements the builder
    /// with the name, arguments, return type and state mutability the interface
    /// declares. The answer then travels the interface's own selector and return
    /// decoding, and is this builder's rather than any other builder's on the
    /// same instance.
    function testISubParserToolingV1ImplementedByToolingMock(bytes memory wordParsers, bytes memory other) external {
        vm.assume(keccak256(wordParsers) != keccak256(other));
        ToolingMock mock = new ToolingMock();
        mock.setAll(other, other, other, wordParsers, other);
        ISubParserToolingV1 tooling = mock;
        assertEq(tooling.buildSubParserWordParsers(), wordParsers);
    }
}

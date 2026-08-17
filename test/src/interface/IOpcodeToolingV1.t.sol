// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {IOpcodeToolingV1} from "src/interface/IOpcodeToolingV1.sol";
import {ToolingMock} from "test/concrete/ToolingMock.sol";

/// @dev The ERC-165 id of `IOpcodeToolingV1` as published. Deployed contracts
/// advertise this value and answer `supportsInterface` for it alone, so an
/// interface whose id is not this one is a different interface and takes a `V2`
/// name rather than this one.
bytes4 constant I_OPCODE_TOOLING_V1_INTERFACE_ID = 0x514b5d4f;

/// @title IOpcodeToolingV1Test
/// @notice `IOpcodeToolingV1` is published for other repositories to implement
/// and to probe over ERC-165, so its id and its implementability are both fixed
/// here.
contract IOpcodeToolingV1Test is Test {
    /// The id is held against a literal rather than against a recomputation of
    /// itself, so a change to the interface's function set moves the id off the
    /// literal instead of carrying the literal along with it.
    function testIOpcodeToolingV1InterfaceId() external pure {
        assertEq(bytes32(type(IOpcodeToolingV1).interfaceId), bytes32(I_OPCODE_TOOLING_V1_INTERFACE_ID));
    }

    /// `ToolingMock` reaches the interface type by assignment rather than by a
    /// cast through `address`, so this compiles only while the mock inherits the
    /// interface, and the mock compiles only while it implements the builder
    /// with the name, arguments, return type and state mutability the interface
    /// declares. The answer then travels the interface's own selector and return
    /// decoding, and is this builder's rather than any other builder's on the
    /// same instance.
    function testIOpcodeToolingV1ImplementedByToolingMock(bytes memory pointers, bytes memory other) external {
        vm.assume(keccak256(pointers) != keccak256(other));
        ToolingMock mock = new ToolingMock();
        mock.setAll(pointers, other, other, other, other);
        IOpcodeToolingV1 tooling = mock;
        assertEq(tooling.buildOpcodeFunctionPointers(), pointers);
    }
}

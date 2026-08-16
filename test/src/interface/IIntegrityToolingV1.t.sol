// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {IIntegrityToolingV1} from "src/interface/IIntegrityToolingV1.sol";
import {ConformingToolingMock} from "test/concrete/ConformingToolingMock.sol";

/// @dev The ERC-165 id of `IIntegrityToolingV1` as published. Deployed contracts
/// advertise this value and answer `supportsInterface` for it alone, so an
/// interface whose id is not this one is a different interface and takes a `V2`
/// name rather than this one.
bytes4 constant I_INTEGRITY_TOOLING_V1_INTERFACE_ID = 0xb92d7553;

/// @title IIntegrityToolingV1Test
/// @notice `IIntegrityToolingV1` is published for other repositories to
/// implement and to probe over ERC-165, so its id and its implementability are
/// both fixed here.
contract IIntegrityToolingV1Test is Test {
    /// The id is held against a literal rather than against a recomputation of
    /// itself, so a change to the interface's function set moves the id off the
    /// literal instead of carrying the literal along with it.
    function testIIntegrityToolingV1InterfaceId() external pure {
        assertEq(bytes32(type(IIntegrityToolingV1).interfaceId), bytes32(I_INTEGRITY_TOOLING_V1_INTERFACE_ID));
    }

    /// A contract that inherits the interface answers the builder at the
    /// interface's own selector, with the value that instance was given rather
    /// than with any other builder's answer.
    function testIIntegrityToolingV1ConformingImplementation(bytes memory pointers, bytes memory other) external {
        vm.assume(keccak256(pointers) != keccak256(other));
        ConformingToolingMock mock = new ConformingToolingMock(other, pointers);
        assertEq(IIntegrityToolingV1(address(mock)).buildIntegrityFunctionPointers(), pointers);
    }
}

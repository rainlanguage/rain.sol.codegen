// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

/// @title CodeGennable
/// An empty contract the suite deploys whenever it needs an address that holds
/// code. It carries no behaviour of its own: what the tests want from it is a
/// stable, non-zero `codehash` to feed to `bytecodeHashConstantString` and
/// `buildFileForContract`. The name is asserted on in
/// `LibCodeGen.requireIdentifier.t.sol` and used as a contract name in
/// `LibCodeGen.describedByMetaHashConstantString.t.sol`, so it is not free to
/// change.
contract CodeGennable {}

// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity ^0.8.25;

interface IParserToolingV1 {
    function buildOperandHandlerFunctionPointers() external pure returns (bytes memory);

    function buildLiteralParserFunctionPointers() external pure returns (bytes memory);
}

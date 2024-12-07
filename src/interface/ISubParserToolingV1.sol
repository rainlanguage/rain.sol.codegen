// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

interface ISubParserToolingV1 {
    function buildSubParserWordParsers() external pure returns (bytes memory);
}

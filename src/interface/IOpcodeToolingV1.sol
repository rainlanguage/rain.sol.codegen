// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity ^0.8.25;

interface IOpcodeToolingV1 {
    function buildOpcodeFunctionPointers() external view returns (bytes memory);
}

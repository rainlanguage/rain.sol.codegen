// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity ^0.8.25;

interface IIntegrityToolingV1 {
    function buildIntegrityFunctionPointers() external view returns (bytes memory);
}

// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// Thrown when a name that is interpolated into a file path or into generated
/// source is not a Solidity identifier.
/// @param contractName The rejected name.
error InvalidContractName(string contractName);

/// @title LibContractName
/// @notice The single definition of what code generation accepts as the name of
/// a contract. Names reach both the filesystem, as the stem of a path, and the
/// generated source, as an identifier, so only a Solidity identifier is
/// accepted.
library LibContractName {
    /// @notice Reverts unless `contractName` is a Solidity identifier: at least
    /// one character, the first of `A-Z`, `a-z`, `_` or `$`, and each of the
    /// rest of those or `0-9`. No `.` and no `/` are in that set, so an
    /// accepted name is a single path segment that is neither empty, nor a
    /// relative directory reference, nor hidden by a leading dot.
    /// @param contractName The name to check.
    function requireValidContractName(string memory contractName) internal pure {
        bytes memory nameBytes = bytes(contractName);
        if (nameBytes.length == 0) {
            revert InvalidContractName(contractName);
        }
        for (uint256 i = 0; i < nameBytes.length; i++) {
            bytes1 char = nameBytes[i];
            bool head = (char >= "A" && char <= "Z") || (char >= "a" && char <= "z") || char == "_" || char == "$";
            bool digit = char >= "0" && char <= "9";
            if (!(head || (digit && i > 0))) {
                revert InvalidContractName(contractName);
            }
        }
    }
}

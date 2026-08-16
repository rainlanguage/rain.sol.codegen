// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

/// @dev Every character a Solidity identifier may begin with, spelled out one by
/// one rather than as byte ranges. `LibContractName` decides with range
/// comparisons, so an off by one at either end of a range shows up here as a
/// disagreement instead of moving both sides at once.
string constant SLOW_HEAD_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_$";

/// @dev Every character a Solidity identifier may continue with: the head
/// alphabet and the decimal digits.
string constant SLOW_TAIL_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_$0123456789";

/// @title LibContractNameSlow
/// @notice A deliberately naive reference for what `LibContractName` accepts,
/// by membership of a written out alphabet rather than by arithmetic.
library LibContractNameSlow {
    /// True if `char` appears anywhere in `alphabet`.
    function containsSlow(string memory alphabet, bytes1 char) internal pure returns (bool) {
        bytes memory alphabetBytes = bytes(alphabet);
        for (uint256 i = 0; i < alphabetBytes.length; i++) {
            if (alphabetBytes[i] == char) {
                return true;
            }
        }
        return false;
    }

    /// True if `contractName` is a Solidity identifier.
    function isValidContractNameSlow(string memory contractName) internal pure returns (bool) {
        bytes memory nameBytes = bytes(contractName);
        if (nameBytes.length == 0) {
            return false;
        }
        if (!containsSlow(SLOW_HEAD_ALPHABET, nameBytes[0])) {
            return false;
        }
        for (uint256 i = 1; i < nameBytes.length; i++) {
            if (!containsSlow(SLOW_TAIL_ALPHABET, nameBytes[i])) {
                return false;
            }
        }
        return true;
    }

    /// Folds arbitrary bytes into a name that is a Solidity identifier, so that
    /// the accepted half of the domain can be fuzzed at all. Random bytes are
    /// essentially never an identifier, so fuzzing names directly only ever
    /// exercises rejection.
    function nameFromSeedSlow(bytes memory seed) internal pure returns (string memory) {
        bytes memory head = bytes(SLOW_HEAD_ALPHABET);
        bytes memory tail = bytes(SLOW_TAIL_ALPHABET);
        uint256 length = seed.length == 0 ? 1 : seed.length;
        bytes memory name = new bytes(length);
        name[0] = head[(seed.length == 0 ? 0 : uint256(uint8(seed[0]))) % head.length];
        for (uint256 i = 1; i < length; i++) {
            name[i] = tail[uint256(uint8(seed[i])) % tail.length];
        }
        return string(name);
    }
}

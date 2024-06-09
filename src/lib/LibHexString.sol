// SPDX-License-Identifier: CAL
pragma solidity ^0.8.25;

library LibHexString {
    function bytesToHex(bytes memory data) internal pure returns (string memory) {
        string memory hexString = vm.toString(data);
        assembly ("memory-safe") {
            // Remove the leading 0x
            let newHexString := add(hexString, 2)
            mstore(newHexString, sub(mload(hexString), 2))
            hexString := newHexString
        }
        return hexString;
    }
}
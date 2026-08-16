// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibFs} from "src/lib/LibFs.sol";

/// @title LibFsTest
contract LibFsTest is Test {
    /// Generated files live under `src/generated/` and are named for the
    /// contract they were generated from. Pinned exactly because consumers
    /// commit this file and import it by path: the location is a cross repo
    /// contract, not an internal detail.
    function testPathForContract() external pure {
        assertEq(LibFs.pathForContract("Foo"), "src/generated/Foo.sol");
    }

    /// Copies `len` bytes out of `data` starting at `start`. Used so the
    /// structural assertions below can name each of the three regions of the
    /// path independently, rather than rebuilding the path with the same
    /// `string.concat` the library uses and asserting it equals itself.
    function slice(bytes memory data, uint256 start, uint256 len) internal pure returns (bytes memory out) {
        out = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            out[i] = data[start + i];
        }
    }

    /// The path is three regions and nothing else: the generated directory, the
    /// contract name byte for byte, and the Solidity extension. Asserted
    /// positionally over arbitrary names so that a name is never quoted,
    /// escaped, trimmed, case folded or truncated on its way into the path.
    /// The length equality is what makes it exhaustive: it forbids any extra
    /// byte anywhere.
    function testPathForContractStructure(string memory contractName) external pure {
        bytes memory path = bytes(LibFs.pathForContract(contractName));
        bytes memory name = bytes(contractName);

        assertEq(path.length, 14 + name.length + 4, "path has bytes beyond dir + name + extension");
        assertEq(slice(path, 0, 14), bytes("src/generated/"), "directory");
        assertEq(slice(path, 14, name.length), name, "contract name is not verbatim");
        assertEq(slice(path, 14 + name.length, 4), bytes(".sol"), "extension");
    }

    /// Two contracts must never be handed the same file: generation would
    /// silently overwrite one with the other. Distinct names give distinct
    /// paths.
    function testPathForContractDistinctNamesDistinctPaths(string memory a, string memory b) external pure {
        vm.assume(keccak256(bytes(a)) != keccak256(bytes(b)));
        assertNotEq(LibFs.pathForContract(a), LibFs.pathForContract(b));
    }

    /// The path is relative to the project root. An absolute path would resolve
    /// outside the consumer's repo entirely, so the first byte is never a
    /// separator.
    function testPathForContractIsRelative(string memory contractName) external pure {
        bytes memory path = bytes(LibFs.pathForContract(contractName));
        assertTrue(path.length > 0, "empty path");
        assertNotEq(uint8(path[0]), uint8(bytes1("/")), "path is absolute");
    }
}

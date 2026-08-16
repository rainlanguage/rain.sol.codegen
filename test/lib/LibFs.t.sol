// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibFs, GENERATED_DIR} from "src/lib/LibFs.sol";
import {InvalidContractName} from "src/lib/LibCodeGen.sol";
import {LibFsExternal} from "test/concrete/LibFsExternal.sol";
import {LibCodeGenSlow} from "test/lib/LibCodeGenSlow.sol";

/// @title LibFsTest
/// @notice `pathForContract` is the only thing that puts a caller supplied name
/// into a path, so it owns the confinement: it reverts unless the name is a
/// Solidity identifier, and the path it does return carries that name verbatim.
///
/// The properties below are split by domain rather than asserted over arbitrary
/// strings. Over the accepted domain, names are CONSTRUCTED from the identifier
/// alphabet, because an arbitrary string is essentially never an identifier and
/// filtering for one would leave the property proven over nothing. Over the
/// rejected domain, arbitrary bytes are exactly the right generator, because
/// that is what the rejected domain is.
contract LibFsTest is Test {
    /// `vm.expectRevert` needs a call frame, and `pathForContract` is an
    /// internal library function that is inlined into its caller.
    LibFsExternal internal immutable iExternal;

    constructor() {
        iExternal = new LibFsExternal();
    }

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
    /// positionally over names built from the identifier alphabet, at every
    /// length and across the whole alphabet, so that a name is never quoted,
    /// escaped, trimmed, case folded or truncated on its way into the path. The
    /// length equality is what makes it exhaustive: it forbids any extra byte
    /// anywhere.
    function testPathForContractStructure(bytes memory seed) external pure {
        string memory contractName = LibCodeGenSlow.nameFromSeedSlow(seed);
        bytes memory path = bytes(LibFs.pathForContract(contractName));
        bytes memory name = bytes(contractName);

        assertEq(path.length, 14 + name.length + 4, "path has bytes beyond dir + name + extension");
        assertEq(slice(path, 0, 14), bytes("src/generated/"), "directory");
        assertEq(slice(path, 14, name.length), name, "contract name is not verbatim");
        assertEq(slice(path, 14 + name.length, 4), bytes(".sol"), "extension");
    }

    /// Two contracts must never be handed the same file: generation would
    /// silently overwrite one with the other. Distinct names give distinct
    /// paths. Both names are built from the alphabet, so the pair is drawn from
    /// the domain the function accepts rather than from strings it refuses to
    /// produce a path for at all.
    function testPathForContractDistinctNamesDistinctPaths(bytes memory seedA, bytes memory seedB) external pure {
        string memory a = LibCodeGenSlow.nameFromSeedSlow(seedA);
        string memory b = LibCodeGenSlow.nameFromSeedSlow(seedB);
        vm.assume(keccak256(bytes(a)) != keccak256(bytes(b)));
        assertNotEq(LibFs.pathForContract(a), LibFs.pathForContract(b));
    }

    /// The path is relative to the project root. An absolute path would resolve
    /// outside the consumer's repo entirely, so the first byte is never a
    /// separator.
    function testPathForContractIsRelative(bytes memory seed) external pure {
        bytes memory path = bytes(LibFs.pathForContract(LibCodeGenSlow.nameFromSeedSlow(seed)));
        assertTrue(path.length > 0, "empty path");
        assertNotEq(uint8(path[0]), uint8(bytes1("/")), "path is absolute");
    }

    /// What the check buys: the path built for a name the library accepts is
    /// one segment directly inside the generated directory, and the only dot in
    /// it is the extension the library appends. Asserted by counting, over
    /// generated identifiers, so no accepted name can reach a subdirectory, a
    /// parent directory, or a hidden file.
    function testPathForContractAcceptedNamesStayInGeneratedDir(bytes memory seed) external pure {
        string memory contractName = LibCodeGenSlow.nameFromSeedSlow(seed);
        bytes memory path = bytes(LibFs.pathForContract(contractName));
        bytes memory dir = bytes(GENERATED_DIR);

        uint256 separators = 0;
        for (uint256 i = 0; i < path.length; i++) {
            if (path[i] == "/") {
                separators++;
            }
            if (path[i] == ".") {
                assertEq(i, path.length - 4, "a dot outside the appended extension");
            }
        }
        uint256 dirSeparators = 0;
        for (uint256 i = 0; i < dir.length; i++) {
            if (dir[i] == "/") {
                dirSeparators++;
            }
        }
        assertEq(separators, dirSeparators + 1, "the path is not a direct child of the generated directory");
    }

    /// No path is produced for the name at all, and the error carries the name
    /// that was rejected so a build failure says which one it was.
    function assertNameRejected(string memory contractName) internal {
        vm.expectRevert(abi.encodeWithSelector(InvalidContractName.selector, contractName));
        iExternal.pathForContract(contractName);
    }

    /// The names that motivate the check get no path, so a consumer that calls
    /// `pathForContract` and then does its own IO with the result cannot be
    /// handed one that escapes the generated directory or hides inside it.
    /// These are the exact strings from the issue plus the other shapes that
    /// stop the path being a single segment.
    function testPathForContractRejectsNamedEscapes() external {
        // `src/generated/.sol`: valid generated Solidity at a path that no
        // compiler picks up as a contract file and that `ls` hides.
        assertNameRejected("");
        // Leaves the generated directory.
        assertNameRejected("..");
        assertNameRejected("../../ESCAPED");
        assertNameRejected("../Foo");
        // Reaches a subdirectory of, or out of, the generated directory.
        assertNameRejected("sub/Foo");
        assertNameRejected("/Foo");
        assertNameRejected("Foo/");
        assertNameRejected("/");
        // Hidden, or a second extension in front of the appended one.
        assertNameRejected(".");
        assertNameRejected(".hidden");
        assertNameRejected("Foo.sol");
    }

    /// The whole rejected domain, not only the names above: no string that is
    /// not a Solidity identifier produces a path. Fuzzed over arbitrary bytes,
    /// which is the right generator here precisely because an arbitrary byte
    /// string is essentially never an identifier.
    function testPathForContractRejectsEveryNonIdentifierName(bytes memory nameBytes) external {
        string memory contractName = string(nameBytes);
        vm.assume(!LibCodeGenSlow.isContractNameSlow(contractName));
        assertNameRejected(contractName);
    }
}

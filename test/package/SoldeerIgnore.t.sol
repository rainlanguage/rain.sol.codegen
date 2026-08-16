// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {VmSafe} from "forge-std-1.16.1/src/Vm.sol";

/// @title SoldeerIgnoreTest
/// @notice `.soldeerignore` is the entire definition of what the published
/// package contains: soldeer zips the working tree at publish time and drops
/// what this file names. So the list is a claim about the repo root, and it is
/// held against the repo root rather than read as documentation of it.
///
/// Three sets meet at the root, and the two containments below are what make
/// the file honest in both directions:
///
/// - every root entry is either excluded here or named in `shipped()`, so a new
///   top level path cannot start shipping without someone saying it should;
/// - every entry here either names a root entry or names something `.gitignore`
///   keeps out of the repo, so an entry that excludes nothing cannot sit in the
///   list looking like it was derived from the package contents.
///
/// The `.gitignore` half of that is what admits the defensive entries. A path
/// git is told never to hold is a path a working tree can still hold when the
/// package is built, so excluding it is live even though it is absent from a
/// fresh checkout.
contract SoldeerIgnoreTest is Test {
    /// The top level paths the package is for. Everything else at the root is
    /// tooling, and `.soldeerignore` has to name it.
    function shipped() internal pure returns (string[] memory) {
        string[] memory paths = new string[](6);
        paths[0] = "LICENSE";
        paths[1] = "LICENSES";
        paths[2] = "README.md";
        paths[3] = "REUSE.toml";
        paths[4] = "script";
        paths[5] = "src";
        return paths;
    }

    /// `.DS_Store` is the one exclusion that answers to neither the repo nor
    /// `.gitignore`: nothing in this repo produces it and git is not told about
    /// it, but macOS writes it into any directory it browses, including one
    /// about to be published.
    function ephemeral() internal view returns (string[] memory) {
        string[] memory gitignored = entriesOf(".gitignore");
        string[] memory paths = new string[](gitignored.length + 1);
        for (uint256 i = 0; i < gitignored.length; i++) {
            paths[i] = gitignored[i];
        }
        paths[gitignored.length] = ".DS_Store";
        return paths;
    }

    /// The paths named by an ignore file, one per line, with the leading `/`
    /// that anchors an entry to the root stripped so that anchored and
    /// unanchored spellings of the same root path compare equal. Blank lines
    /// and `#` comments name nothing and are dropped.
    function entriesOf(string memory path) internal view returns (string[] memory) {
        string[] memory lines = vm.split(vm.readFile(path), "\n");
        string[] memory paths = new string[](lines.length);
        uint256 count = 0;
        for (uint256 i = 0; i < lines.length; i++) {
            string memory line = vm.trim(lines[i]);
            bytes memory data = bytes(line);
            if (data.length == 0 || data[0] == "#") {
                continue;
            }
            paths[count++] = data[0] == "/" ? drop(data, 1) : line;
        }
        assembly ("memory-safe") {
            mstore(paths, count)
        }
        return paths;
    }

    /// The names directly under the repo root. `readDir` resolves what it is
    /// asked to walk, so it reports each entry as an absolute path and the name
    /// is the last segment of it.
    function rootEntries() internal view returns (string[] memory) {
        VmSafe.DirEntry[] memory dir = vm.readDir("./");
        string[] memory paths = new string[](dir.length);
        for (uint256 i = 0; i < dir.length; i++) {
            bytes memory data = bytes(dir[i].path);
            uint256 start = 0;
            for (uint256 j = 0; j < data.length; j++) {
                if (data[j] == "/") {
                    start = j + 1;
                }
            }
            paths[i] = drop(data, start);
        }
        return paths;
    }

    /// `data` without its first `prefixLength` bytes.
    function drop(bytes memory data, uint256 prefixLength) internal pure returns (string memory) {
        bytes memory out = new bytes(data.length - prefixLength);
        for (uint256 i = 0; i < out.length; i++) {
            out[i] = data[i + prefixLength];
        }
        return string(out);
    }

    /// Whether `paths` holds `path`.
    function has(string[] memory paths, string memory path) internal pure returns (bool) {
        bytes32 wanted = keccak256(bytes(path));
        for (uint256 i = 0; i < paths.length; i++) {
            if (keccak256(bytes(paths[i])) == wanted) {
                return true;
            }
        }
        return false;
    }

    /// Every exclusion excludes something. An entry that matches neither a path
    /// in the repo nor a path git is told to keep out of it is inherited from
    /// somewhere else and makes the list read as derived from the package when
    /// it was copied.
    function testEveryIgnoreEntryExcludesSomething() external view {
        string[] memory root = rootEntries();
        string[] memory defensive = ephemeral();
        string[] memory ignored = entriesOf(".soldeerignore");
        for (uint256 i = 0; i < ignored.length; i++) {
            assertTrue(
                has(root, ignored[i]) || has(defensive, ignored[i]),
                string.concat(
                    "`.soldeerignore` excludes `",
                    ignored[i],
                    "`, which is neither in the repo nor in `.gitignore`, so it excludes nothing"
                )
            );
        }
    }

    /// Nothing reaches the package by omission. A root path that is not shipped
    /// on purpose has to be excluded on purpose.
    function testEveryRootEntryIsShippedOrIgnored() external view {
        string[] memory ignored = entriesOf(".soldeerignore");
        string[] memory published = shipped();
        string[] memory root = rootEntries();
        for (uint256 i = 0; i < root.length; i++) {
            assertTrue(
                has(ignored, root[i]) || has(published, root[i]),
                string.concat(
                    "`", root[i], "` is at the repo root and `.soldeerignore` does not exclude it, so it ships"
                )
            );
        }
    }

    /// The shipped set is a statement about this repo, so each of its paths is
    /// one this repo has.
    function testEveryShippedPathIsInTheRepo() external view {
        string[] memory root = rootEntries();
        string[] memory published = shipped();
        for (uint256 i = 0; i < published.length; i++) {
            assertTrue(has(root, published[i]), string.concat("`", published[i], "` is not at the repo root"));
        }
    }

    /// The package is these paths, so excluding one empties the package of the
    /// thing it is for.
    function testNoShippedPathIsIgnored() external view {
        string[] memory ignored = entriesOf(".soldeerignore");
        string[] memory published = shipped();
        for (uint256 i = 0; i < published.length; i++) {
            assertFalse(
                has(ignored, published[i]),
                string.concat("`.soldeerignore` excludes `", published[i], "`, which the package is for")
            );
        }
    }
}

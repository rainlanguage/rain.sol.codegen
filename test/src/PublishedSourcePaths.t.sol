// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {VmSafe} from "forge-std-1.16.1/src/Vm.sol";

/// @dev The path the tooling interface docstrings point consumers at, which the
/// package therefore has to carry.
string constant BUILD_SCRIPT = "script/Build.sol";

/// @title PublishedSourcePathsTest
/// @notice Everything under `src` ships in the soldeer package, and consumers
/// read it from `dependencies/rain-sol-codegen-<version>/src`, where the only
/// paths that resolve are the ones the package carries. `.soldeerignore` states
/// what is stripped, so a repo path named under a stripped directory is a path
/// no consumer can follow, and the paths that are named have to be ones that
/// survive publishing.
///
/// `.soldeerignore` is read here rather than restated, so an entry added to it
/// is enforced against the shipped sources without this test being touched.
contract PublishedSourcePathsTest is Test {
    /// The directory prefixes `.soldeerignore` strips from the package, each
    /// carrying a trailing `/` so that a match is a path into that directory
    /// rather than a word that happens to start with the same characters.
    /// A leading `/`, which anchors an entry to the package root, is dropped
    /// because a path written inside a source file does not carry one.
    function strippedPrefixes() internal view returns (string[] memory) {
        string[] memory lines = vm.split(vm.readFile(".soldeerignore"), "\n");
        uint256 count = 0;
        for (uint256 i = 0; i < lines.length; i++) {
            if (bytes(vm.trim(lines[i])).length > 0) {
                count++;
            }
        }

        string[] memory prefixes = new string[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < lines.length; i++) {
            string memory entry = vm.trim(lines[i]);
            if (bytes(entry).length == 0) {
                continue;
            }
            prefixes[j++] = string.concat(stripLeadingSlash(entry), "/");
        }
        return prefixes;
    }

    /// `entry` without its first byte if that byte is `/`, otherwise `entry`.
    function stripLeadingSlash(string memory entry) internal pure returns (string memory) {
        bytes memory data = bytes(entry);
        if (data.length == 0 || data[0] != "/") {
            return entry;
        }
        bytes memory stripped = new bytes(data.length - 1);
        for (uint256 i = 1; i < data.length; i++) {
            stripped[i - 1] = data[i];
        }
        return string(stripped);
    }

    /// True if `subject` ends with `suffix`.
    function endsWith(string memory subject, string memory suffix) internal pure returns (bool) {
        bytes memory subjectData = bytes(subject);
        bytes memory suffixData = bytes(suffix);
        if (subjectData.length < suffixData.length) {
            return false;
        }
        uint256 offset = subjectData.length - suffixData.length;
        for (uint256 i = 0; i < suffixData.length; i++) {
            if (subjectData[offset + i] != suffixData[i]) {
                return false;
            }
        }
        return true;
    }

    /// Every `.sol` file under `src`, at any depth.
    function sourceFiles() internal view returns (string[] memory) {
        VmSafe.DirEntry[] memory entries = vm.readDir("src", 8);
        uint256 count = 0;
        for (uint256 i = 0; i < entries.length; i++) {
            if (!entries[i].isDir && endsWith(entries[i].path, ".sol")) {
                count++;
            }
        }

        string[] memory files = new string[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < entries.length; i++) {
            if (!entries[i].isDir && endsWith(entries[i].path, ".sol")) {
                files[j++] = entries[i].path;
            }
        }
        return files;
    }

    /// No source file the package ships names a path under a directory that
    /// `.soldeerignore` strips, because such a path resolves to nothing in the
    /// package a consumer installs.
    function testPublishedSourcesNameNoStrippedPath() external view {
        string[] memory prefixes = strippedPrefixes();
        assertGt(prefixes.length, 0, ".soldeerignore yielded no entries");

        string[] memory files = sourceFiles();
        assertGt(files.length, 0, "src yielded no sol files");

        for (uint256 i = 0; i < files.length; i++) {
            string memory content = vm.readFile(files[i]);
            for (uint256 j = 0; j < prefixes.length; j++) {
                assertFalse(
                    vm.contains(content, prefixes[j]), string.concat(files[i], " names the stripped path ", prefixes[j])
                );
            }
        }
    }

    /// The path the docstrings send consumers to is a file in this repo, and
    /// `.soldeerignore` strips no directory that contains it, so it reaches the
    /// package the docstrings are read from.
    function testBuildScriptSurvivesPublishing() external view {
        assertTrue(vm.isFile(BUILD_SCRIPT), string.concat(BUILD_SCRIPT, " is not a file"));

        string[] memory prefixes = strippedPrefixes();
        assertGt(prefixes.length, 0, ".soldeerignore yielded no entries");

        for (uint256 i = 0; i < prefixes.length; i++) {
            assertFalse(
                vm.contains(BUILD_SCRIPT, prefixes[i]),
                string.concat(BUILD_SCRIPT, " is under the stripped path ", prefixes[i])
            );
        }
    }
}

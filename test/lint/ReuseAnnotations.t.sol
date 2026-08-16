// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {Vm} from "forge-std-1.16.1/src/Vm.sol";

/// @dev The REUSE annotation file, at the project root.
string constant REUSE_TOML = "REUSE.toml";

/// @dev The comment markers that bound a region of a file carrying no
/// licensing information. A region left open runs to the end of the file.
string constant IGNORE_START = "REUSE-IgnoreStart";
string constant IGNORE_END = "REUSE-IgnoreEnd";

// REUSE-IgnoreStart
/// @dev The tag a file declares its own license with. `reuse` reads it from
/// anywhere outside an ignored region, so the tag standing there is the file
/// licensing itself. The trailing colon is part of the tag, and is what
/// separates it from the same name used as a TOML key.
string constant SPDX_LICENSE_TAG = "SPDX-License-Identifier:";
// REUSE-IgnoreEnd

/// @dev The byte that makes an annotated path a glob rather than one file.
string constant GLOB_MARKER = "*";

/// @dev The suffix of a path covering every file under a directory. It is the
/// only glob form `annotatedFiles` resolves.
string constant RECURSIVE_GLOB_SUFFIX = "/**/";

/// @dev Deeper than any directory tree an annotation covers, so a scan reaches
/// every file under the annotated directory.
uint64 constant SCAN_MAX_DEPTH = 64;

/// @dev A directory this repo keeps files in at more than one depth.
string constant NESTED_DIR = "audit";

/// Thrown when REUSE.toml annotates a glob that cannot be resolved to the files
/// it covers, so that an unresolvable annotation fails this lint rather than
/// passing it unchecked.
error UnresolvableGlob(string path);

/// @title ReuseAnnotationsTest
/// @notice A header in the file and an entry in REUSE.toml are two ways to
/// license a file, and `reuse lint` is satisfied by either one. A file that
/// carries a header therefore has no reason to also be annotated: the
/// annotation is a second copy of the same fact, held in a different file from
/// the one it describes and free to drift from it. The header is the copy that
/// travels with the file into a published package, so it is the one that is
/// kept, and REUSE.toml annotates only the paths that cannot carry one.
///
/// The other half of the property — every file without a header is annotated —
/// is `reuse lint` itself, which the `legal` CI job runs over the whole tree.
contract ReuseAnnotationsTest is Test {
    /// No path REUSE.toml annotates resolves to a file that licenses itself.
    function testAnnotatedFilesDeclareNoLicenseOfTheirOwn() external view {
        string memory toml = vm.readFile(REUSE_TOML);
        uint256 checked = 0;

        for (uint256 i = 0; vm.keyExistsToml(toml, annotationKey(i)); i++) {
            string[] memory annotated = vm.parseTomlStringArray(toml, string.concat(annotationKey(i), ".path"));

            for (uint256 j = 0; j < annotated.length; j++) {
                string[] memory files = annotatedFiles(annotated[j]);

                for (uint256 k = 0; k < files.length; k++) {
                    assertFalse(
                        declaresItsOwnLicense(files[k]),
                        string.concat(files[k], " licenses itself and is also annotated by ", annotated[j])
                    );
                    checked++;
                }
            }
        }

        assertGt(checked, 0, "REUSE.toml annotates no files");
    }

    /// The tag is read from the bytes of the file at the path, so a file that
    /// heads itself with one is distinguished from a file that does not.
    ///
    /// REUSE.toml names the tag as a TOML key, which licenses the files it
    /// annotates rather than itself, so it is not a file that licenses itself.
    function testDeclaresItsOwnLicenseReadsTheFile() external view {
        assertTrue(declaresItsOwnLicense("src/lib/LibCodeGen.sol"), "headed source file");
        assertFalse(declaresItsOwnLicense(".gitignore"), "file with no header");
        assertFalse(declaresItsOwnLicense(REUSE_TOML), "TOML key is not a header");
    }

    /// The tag is licensing information where it stands outside every ignored
    /// region, and is not where it stands inside one.
    function testDeclaresLicenseHonoursIgnoredRegions() external view {
        assertTrue(declaresLicense(string.concat("// ", SPDX_LICENSE_TAG, " LicenseRef-DCL-1.0")), "plain header");
        assertFalse(declaresLicense("a file with no tag"), "no tag");
        assertFalse(declaresLicense(string.concat(IGNORE_START, SPDX_LICENSE_TAG, IGNORE_END)), "inside a region");
        assertTrue(declaresLicense(string.concat(IGNORE_START, IGNORE_END, SPDX_LICENSE_TAG)), "after a region");
        assertTrue(declaresLicense(string.concat(SPDX_LICENSE_TAG, IGNORE_START, IGNORE_END)), "before a region");
        assertFalse(declaresLicense(string.concat(IGNORE_START, SPDX_LICENSE_TAG)), "region left open");
        assertTrue(
            declaresLicense(string.concat(IGNORE_START, IGNORE_END, SPDX_LICENSE_TAG, IGNORE_START, IGNORE_END)),
            "between two regions"
        );
    }

    /// A path with no glob in it is the one file it names.
    function testAnnotatedFilesResolvesAPlainPathToItself() external view {
        string[] memory files = annotatedFiles(REUSE_TOML);
        assertEq(files.length, 1, "count");
        assertEq(files[0], REUSE_TOML, "path");
    }

    /// A path naming nothing on disk resolves to no files, so it carries no
    /// header to be a second copy of.
    function testAnnotatedFilesResolvesAMissingPathToNothing() external view {
        assertEq(annotatedFiles("no/such/file").length, 0, "missing plain path");
        assertEq(annotatedFiles(string.concat("no/such/dir", RECURSIVE_GLOB_SUFFIX)).length, 0, "missing glob root");
    }

    /// A recursive glob is every file below its directory at any depth, and no
    /// directory, because a directory has no bytes to read a tag out of.
    function testAnnotatedFilesResolvesARecursiveGlobToEveryFileBelowIt() external view {
        string[] memory files = annotatedFiles(string.concat(NESTED_DIR, RECURSIVE_GLOB_SUFFIX));
        assertGt(files.length, 0, "count");

        string memory root = string.concat(vm.projectRoot(), "/", NESTED_DIR, "/");
        bool belowFirstLevel = false;
        for (uint256 i = 0; i < files.length; i++) {
            assertTrue(vm.isFile(files[i]), files[i]);
            belowFirstLevel = belowFirstLevel || vm.contains(vm.replace(files[i], root, ""), "/");
        }
        assertTrue(belowFirstLevel, "scan stopped at the first level");
    }

    /// Any other glob form is refused, so a path this lint cannot expand is
    /// never mistaken for a path that holds no headers.
    function testAnnotatedFilesRefusesAnUnresolvableGlob() external {
        vm.expectRevert(abi.encodeWithSelector(UnresolvableGlob.selector, "src/*.sol"));
        this.externalAnnotatedFiles("src/*.sol");
    }

    /// The suffix must match at the end of the subject and nowhere else, and a
    /// subject shorter than the suffix ends with nothing.
    function testHasSuffix() external pure {
        assertTrue(hasSuffix("audit/**/", RECURSIVE_GLOB_SUFFIX), "recursive glob");
        assertTrue(hasSuffix(RECURSIVE_GLOB_SUFFIX, RECURSIVE_GLOB_SUFFIX), "whole subject");
        assertFalse(hasSuffix("audit/**/x", RECURSIVE_GLOB_SUFFIX), "suffix mid subject");
        assertFalse(hasSuffix("audit/**", RECURSIVE_GLOB_SUFFIX), "truncated");
        assertFalse(hasSuffix("audit/*/", RECURSIVE_GLOB_SUFFIX), "wrong bytes");
        assertFalse(hasSuffix("/", RECURSIVE_GLOB_SUFFIX), "subject shorter than suffix");
        assertFalse(hasSuffix("", RECURSIVE_GLOB_SUFFIX), "empty subject");
        assertTrue(hasSuffix("", ""), "empty suffix");
    }

    /// The subject with exactly the trailing suffix removed.
    function testWithoutSuffix() external pure {
        assertEq(withoutSuffix("audit/**/", RECURSIVE_GLOB_SUFFIX), "audit", "one directory");
        assertEq(withoutSuffix(".github/workflows/**/", RECURSIVE_GLOB_SUFFIX), ".github/workflows", "nested");
        assertEq(withoutSuffix(RECURSIVE_GLOB_SUFFIX, RECURSIVE_GLOB_SUFFIX), "", "whole subject");
        assertEq(withoutSuffix("audit/**/", ""), "audit/**/", "empty suffix");
    }

    /// `annotatedFiles` reached through a call, so that the revert it throws
    /// can be expected.
    function externalAnnotatedFiles(string memory annotated) external view returns (string[] memory) {
        return annotatedFiles(annotated);
    }

    /// The key of the `i`th `[[annotations]]` block of REUSE.toml.
    function annotationKey(uint256 i) internal pure returns (string memory) {
        return string.concat(".annotations[", vm.toString(i), "]");
    }

    /// The files an annotated path covers, which is one file for a plain path,
    /// every file below a directory for a recursive glob, and none for a path
    /// that names nothing on disk.
    function annotatedFiles(string memory annotated) internal view returns (string[] memory) {
        if (!vm.contains(annotated, GLOB_MARKER)) {
            if (!vm.exists(annotated)) {
                return new string[](0);
            }
            string[] memory plain = new string[](1);
            plain[0] = annotated;
            return plain;
        }

        if (!hasSuffix(annotated, RECURSIVE_GLOB_SUFFIX)) {
            revert UnresolvableGlob(annotated);
        }

        string memory root = withoutSuffix(annotated, RECURSIVE_GLOB_SUFFIX);
        if (!vm.exists(root)) {
            return new string[](0);
        }

        Vm.DirEntry[] memory entries = vm.readDir(root, SCAN_MAX_DEPTH);
        uint256 count = 0;
        for (uint256 i = 0; i < entries.length; i++) {
            if (!entries[i].isDir) {
                count++;
            }
        }

        string[] memory files = new string[](count);
        uint256 at = 0;
        for (uint256 i = 0; i < entries.length; i++) {
            if (!entries[i].isDir) {
                files[at] = entries[i].path;
                at++;
            }
        }
        return files;
    }

    /// True when the file at `path` licenses itself.
    function declaresItsOwnLicense(string memory path) internal view returns (bool) {
        return declaresLicense(string(vm.readFileBinary(path)));
    }

    /// True when `content` carries the SPDX license tag outside every ignored
    /// region.
    function declaresLicense(string memory content) internal view returns (bool) {
        string[] memory regions = vm.split(content, IGNORE_START);
        if (vm.contains(regions[0], SPDX_LICENSE_TAG)) {
            return true;
        }

        for (uint256 i = 1; i < regions.length; i++) {
            string[] memory resumed = vm.split(regions[i], IGNORE_END);
            for (uint256 j = 1; j < resumed.length; j++) {
                if (vm.contains(resumed[j], SPDX_LICENSE_TAG)) {
                    return true;
                }
            }
        }
        return false;
    }

    /// True when `subject` ends with `suffix`.
    function hasSuffix(string memory subject, string memory suffix) internal pure returns (bool) {
        bytes memory subjectBytes = bytes(subject);
        bytes memory suffixBytes = bytes(suffix);
        if (subjectBytes.length < suffixBytes.length) {
            return false;
        }

        uint256 offset = subjectBytes.length - suffixBytes.length;
        for (uint256 i = 0; i < suffixBytes.length; i++) {
            if (subjectBytes[offset + i] != suffixBytes[i]) {
                return false;
            }
        }
        return true;
    }

    /// `subject` without its trailing `suffix`.
    function withoutSuffix(string memory subject, string memory suffix) internal pure returns (string memory) {
        bytes memory subjectBytes = bytes(subject);
        bytes memory kept = new bytes(subjectBytes.length - bytes(suffix).length);
        for (uint256 i = 0; i < kept.length; i++) {
            kept[i] = subjectBytes[i];
        }
        return string(kept);
    }
}

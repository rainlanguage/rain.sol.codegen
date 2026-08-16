// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {VmSafe} from "forge-std-1.16.1/src/Vm.sol";
import {LibFs, GENERATED_DIR} from "src/lib/LibFs.sol";

/// @title LibFsIsPresentTest
/// @notice `isPresent` is what stands between `buildFileForContract` and a write
/// that lands somewhere other than the path it was given, so what it answers for
/// a symlink is asserted here together with the write that depends on it.
///
/// Symlinks are built with `ln` because forge-std 1.16.1 has no cheatcode that
/// creates one, and they are read back with `readlink`, which reports the path
/// itself and fails on anything that is not a symlink. `vm.readLink` is what the
/// library uses, so it is deliberately not what asserts here.
contract LibFsIsPresentTest is Test {
    /// Every path this contract hands to the shell is built here from a bare
    /// name, so no test in it can name a path outside the generated directory.
    function pathFor(string memory name) internal pure returns (string memory) {
        return string.concat(GENERATED_DIR, "/", name);
    }

    /// Creates a symlink at `name` pointing at `target`, which is resolved
    /// relative to the generated directory because that is where the link
    /// itself is. The exit code is asserted so that a link that was never
    /// created cannot read as the library behaving.
    function symlink(string memory name, string memory target) internal {
        string[] memory command = new string[](4);
        command[0] = "ln";
        command[1] = "-s";
        command[2] = target;
        command[3] = pathFor(name);
        VmSafe.FfiResult memory result = vm.tryFfi(command);
        assertEq(result.exitCode, 0, string(result.stderr));
    }

    /// The target of the symlink at `name`, and a non-zero exit code if `name`
    /// is not a symlink at all.
    function readlink(string memory name) internal returns (VmSafe.FfiResult memory) {
        string[] memory command = new string[](2);
        command[0] = "readlink";
        command[1] = pathFor(name);
        return vm.tryFfi(command);
    }

    /// `rm -rf` removes a dangling symlink and succeeds on a path that holds
    /// nothing, neither of which is true of the cheatcodes. Setup and cleanup
    /// that leaned on the behaviour under test would leave the tree dirty
    /// exactly when the test fails.
    function remove(string memory name) internal {
        string[] memory command = new string[](3);
        command[0] = "rm";
        command[1] = "-rf";
        command[2] = pathFor(name);
        VmSafe.FfiResult memory result = vm.tryFfi(command);
        assertEq(result.exitCode, 0, string(result.stderr));
    }

    /// A path that holds nothing is absent. The write removes what it finds
    /// before writing, and removing a path that holds nothing reverts, so
    /// answering true here would break every first generation.
    function testIsPresentNothing() external {
        string memory name = "LibFsIsPresentNothing.txt";
        remove(name);

        assertFalse(LibFs.isPresent(vm, pathFor(name)), "a path holding nothing is present");
    }

    /// A regular file at the path is present.
    function testIsPresentFile() external {
        string memory name = "LibFsIsPresentFile.txt";
        remove(name);
        vm.writeFile(pathFor(name), "content");

        assertTrue(LibFs.isPresent(vm, pathFor(name)), "a file is not present");

        remove(name);
    }

    /// A directory at the path is present. Nothing generates a directory there,
    /// so the write has to find one rather than land inside it.
    function testIsPresentDirectory() external {
        string memory name = "LibFsIsPresentDir";
        remove(name);
        vm.createDir(pathFor(name), false);

        assertTrue(LibFs.isPresent(vm, pathFor(name)), "a directory is not present");

        remove(name);
    }

    /// A symlink whose target exists is present, and is the case that already
    /// resolves, so it is what the dangling case is measured against.
    function testIsPresentSymlink() external {
        string memory name = "LibFsIsPresentLink.txt";
        string memory targetName = "LibFsIsPresentLinkTarget.txt";
        remove(name);
        remove(targetName);
        vm.writeFile(pathFor(targetName), "content");
        symlink(name, targetName);
        assertEq(readlink(name).exitCode, 0, "the path under test is not a symlink");
        assertTrue(vm.exists(pathFor(name)), "the link does not resolve");

        assertTrue(LibFs.isPresent(vm, pathFor(name)), "a symlink is not present");

        remove(name);
        remove(targetName);
    }

    /// A symlink whose target does not exist is present. The path resolves to
    /// nothing, which is why `vm.exists` alone is not what answers this.
    function testIsPresentDanglingSymlink() external {
        string memory name = "LibFsIsPresentDanglingLink.txt";
        string memory targetName = "LibFsIsPresentDanglingLinkTarget.txt";
        remove(name);
        remove(targetName);
        symlink(name, targetName);
        assertEq(readlink(name).exitCode, 0, "the path under test is not a symlink");
        assertEq(string(readlink(name).stdout), targetName, "the link points elsewhere");
        assertFalse(vm.exists(pathFor(name)), "the link is not dangling");

        assertTrue(LibFs.isPresent(vm, pathFor(name)), "a dangling symlink is not present");

        remove(name);
    }

    /// A symlink at the generated path whose target does not exist is replaced
    /// by a regular file holding the generated content, and the target is not
    /// created: the write goes to the path, not through it.
    ///
    /// The content is compared against a second contract generated at a path
    /// that held nothing, so the claim is that the two cases produce the same
    /// file rather than that some particular bytes appear.
    function testBuildFileForContractReplacesDanglingSymlink() external {
        string memory name = "LibFsIsPresentDangling";
        string memory linkName = "LibFsIsPresentDangling.sol";
        string memory targetName = "LibFsIsPresentDanglingTarget.txt";
        string memory controlName = "LibFsIsPresentControl";
        string memory controlFileName = "LibFsIsPresentControl.sol";
        remove(linkName);
        remove(targetName);
        remove(controlFileName);

        symlink(linkName, targetName);
        assertEq(readlink(linkName).exitCode, 0, "the path under test is not a symlink");
        assertFalse(vm.exists(pathFor(targetName)), "the link target is already there");
        assertFalse(vm.exists(pathFor(linkName)), "the link is not dangling");

        string memory body = "\n// dangling\n";
        LibFs.buildFileForContract(vm, address(this), name, body);
        LibFs.buildFileForContract(vm, address(this), controlName, body);

        assertFalse(vm.exists(pathFor(targetName)), "the write followed the link to its target");
        assertTrue(readlink(linkName).exitCode != 0, "the path is still a symlink");
        assertEq(
            vm.readFile(pathFor(linkName)),
            vm.readFile(pathFor(controlFileName)),
            "the file at the path is not what a write to a path holding nothing produces"
        );

        remove(linkName);
        remove(targetName);
        remove(controlFileName);
    }
}

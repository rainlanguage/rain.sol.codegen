// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {VmSafe} from "forge-std-1.16.2/src/Vm.sol";
import {LibFs, GENERATED_DIR} from "src/lib/LibFs.sol";
import {LibFsExternal} from "test/concrete/LibFsExternal.sol";

/// @title LibFsIsPresentTest
/// @notice `isPresent` is what stands between `buildFileForContract` and a write
/// that lands somewhere other than the path it was given, so what it answers for
/// a symlink is asserted here together with the write that depends on it.
///
/// Symlinks are built with `ln` because forge-std 1.16.2 has no cheatcode that
/// creates one, and they are read back with `readlink`, which reports the path
/// itself and fails on anything that is not a symlink. `vm.readLink` is what the
/// library uses, so it is deliberately not what asserts here.
///
/// What a symlink at the generated path resolves to is the other half of this.
/// A link points wherever it was made to point, so what is at the far end of one
/// is a second file at a second path that the caller never named, and the only
/// thing bounding where that path is is `fs_permissions`. This repo grants
/// `read-write` on `meta/` as well as on the generated directory, and `meta/`
/// holds committed input that ships in the published package, so a target there
/// is asserted here alongside targets inside the generated directory.
contract LibFsIsPresentTest is Test {
    /// A write that is supposed to revert needs a call frame to revert out of,
    /// and `buildFileForContract` is an internal library function that is
    /// inlined into its caller.
    LibFsExternal internal immutable iExternal;

    constructor() {
        iExternal = new LibFsExternal();
    }

    /// `src/generated/` holds no committed file, so nothing in a fresh clone
    /// creates it, and none of `ln`, `vm.writeFile` or `vm.createDir` for a
    /// child of it creates the parent. `buildFileForContract` creates it for
    /// itself, but suites run in any order and a filtered run may be only this
    /// one, so this contract creates it rather than inheriting it from whatever
    /// ran first.
    function setUp() external {
        vm.createDir(GENERATED_DIR, true);
    }

    /// A path inside the generated directory, built here from a bare name.
    function pathFor(string memory name) internal pure returns (string memory) {
        return string.concat(GENERATED_DIR, "/", name);
    }

    /// A path inside `meta/`, built here from a bare name. The directory is one
    /// of the two this repo's `fs_permissions` grant `read-write`, and the only
    /// one that is not the generated directory, so it is where a target that a
    /// generation run has no business touching is put.
    function metaPathFor(string memory name) internal pure returns (string memory) {
        return string.concat("meta/", name);
    }

    /// Creates a symlink at `linkPath` pointing at `target`, which the
    /// filesystem resolves relative to the directory the link itself is in. The
    /// exit code is asserted so that a link that was never created cannot read
    /// as the library behaving.
    function symlinkAt(string memory linkPath, string memory target) internal {
        string[] memory command = new string[](4);
        command[0] = "ln";
        command[1] = "-s";
        command[2] = target;
        command[3] = linkPath;
        VmSafe.FfiResult memory result = vm.tryFfi(command);
        assertEq(result.exitCode, 0, string(result.stderr));
    }

    /// `symlinkAt` for a link inside the generated directory.
    function symlink(string memory name, string memory target) internal {
        symlinkAt(pathFor(name), target);
    }

    /// The target of the symlink at `linkPath`, and a non-zero exit code if
    /// `linkPath` is not a symlink at all.
    function readlinkAt(string memory linkPath) internal returns (VmSafe.FfiResult memory) {
        string[] memory command = new string[](2);
        command[0] = "readlink";
        command[1] = linkPath;
        return vm.tryFfi(command);
    }

    /// `readlinkAt` for a link inside the generated directory.
    function readlink(string memory name) internal returns (VmSafe.FfiResult memory) {
        return readlinkAt(pathFor(name));
    }

    /// `rm -rf` removes a dangling symlink and succeeds on a path that holds
    /// nothing, neither of which is true of the cheatcodes. Setup and cleanup
    /// that leaned on the behaviour under test would leave the tree dirty
    /// exactly when the test fails.
    function removeAt(string memory path) internal {
        string[] memory command = new string[](3);
        command[0] = "rm";
        command[1] = "-rf";
        command[2] = path;
        VmSafe.FfiResult memory result = vm.tryFfi(command);
        assertEq(result.exitCode, 0, string(result.stderr));
    }

    /// `removeAt` for a path inside the generated directory.
    function remove(string memory name) internal {
        removeAt(pathFor(name));
    }

    /// Generates `name` into the generated directory. The licence and copyright
    /// reach the header and nothing in this contract reads the header, so this
    /// repo's own values stand in for a caller's.
    function generate(string memory name, string memory body) internal {
        LibFs.buildFileForContract(
            vm, address(this), name, "LicenseRef-DCL-1.0", "Copyright (c) 2020 Rain Open Source Software Ltd", body
        );
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
        assertEq(LibFs.pathForContract(name), pathFor(linkName), "the link is not where the write goes");
        assertEq(readlink(linkName).exitCode, 0, "the path under test is not a symlink");
        assertFalse(vm.exists(pathFor(targetName)), "the link target is already there");
        assertFalse(vm.exists(pathFor(linkName)), "the link is not dangling");

        string memory body = "\n// dangling\n";
        generate(name, body);
        generate(controlName, body);

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

    /// A symlink at the generated path whose target exists is replaced by a
    /// regular file holding the generated content, and the target does not
    /// receive it: the write goes to the path, not through it.
    ///
    /// The target is also left exactly as it was. Removing the link is what
    /// frees the path, and the link is all that has to go; the file at the far
    /// end of it is a second file at a second path, and the caller asked to
    /// generate at the path, not to delete that. Its bytes are asserted rather
    /// than its existence, because a target removed and recreated, truncated,
    /// or written through to all leave a file at that path.
    ///
    /// The content is compared against a second contract generated at a path
    /// that held nothing, so the claim is that the two cases produce the same
    /// file rather than that some particular bytes appear.
    function testBuildFileForContractReplacesLiveSymlink() external {
        string memory name = "LibFsIsPresentLive";
        string memory linkName = "LibFsIsPresentLive.sol";
        string memory targetName = "LibFsIsPresentLiveTarget.txt";
        string memory controlName = "LibFsIsPresentLiveControl";
        string memory controlFileName = "LibFsIsPresentLiveControl.sol";
        remove(linkName);
        remove(targetName);
        remove(controlFileName);

        vm.writeFile(pathFor(targetName), "SENTINEL");
        symlink(linkName, targetName);
        assertEq(LibFs.pathForContract(name), pathFor(linkName), "the link is not where the write goes");
        assertEq(readlink(linkName).exitCode, 0, "the path under test is not a symlink");
        assertTrue(vm.exists(pathFor(linkName)), "the link does not resolve");
        assertEq(vm.readFile(pathFor(targetName)), "SENTINEL", "the link target is not the seeded file");

        string memory body = "\n// live\n";
        generate(name, body);
        generate(controlName, body);

        bool linkIsStillASymlink = readlink(linkName).exitCode == 0;
        bool targetExists = vm.exists(pathFor(targetName));
        string memory target = targetExists ? vm.readFile(pathFor(targetName)) : "";
        string memory written = vm.readFile(pathFor(linkName));
        string memory control = vm.readFile(pathFor(controlFileName));

        remove(linkName);
        remove(targetName);
        remove(controlFileName);

        assertFalse(linkIsStillASymlink, "the path is still a symlink");
        assertTrue(targetExists, "the link target was destroyed by the write");
        assertEq(target, "SENTINEL", "the link target's own content did not survive the write");
        assertEq(written, control, "the file at the path is not what a write to a path holding nothing produces");
    }

    /// The file a live symlink resolves to does not have to be inside the
    /// generated directory, and the one that motivates this is not. `meta/` is
    /// granted `read-write` because `describedByMetaHashConstantString` reads
    /// from it, and what it holds is committed input that ships in the published
    /// package. A generation run that took a `meta/` file with it would be
    /// destroying that, silently, while reporting success.
    ///
    /// The link target is spelled relative to the link's own directory, which is
    /// where the filesystem resolves it from, so this reaches `meta/` from
    /// `src/generated/` the way a link someone actually made would.
    function testBuildFileForContractLeavesATargetOutsideTheGeneratedDirectoryAlone() external {
        string memory name = "LibFsIsPresentMeta";
        string memory linkName = "LibFsIsPresentMeta.sol";
        string memory targetName = "LibFsIsPresentMetaTarget.rain.meta";
        remove(linkName);
        removeAt(metaPathFor(targetName));

        vm.createDir("meta", true);
        vm.writeFile(metaPathFor(targetName), "COMMITTED");
        symlinkAt(pathFor(linkName), string.concat("../../", metaPathFor(targetName)));
        assertEq(LibFs.pathForContract(name), pathFor(linkName), "the link is not where the write goes");
        assertEq(readlink(linkName).exitCode, 0, "the path under test is not a symlink");
        assertTrue(vm.exists(pathFor(linkName)), "the link does not resolve");
        assertEq(vm.readFile(metaPathFor(targetName)), "COMMITTED", "the link target is not the seeded file");

        string memory body = "\n// meta\n";
        generate(name, body);

        bool linkIsStillASymlink = readlink(linkName).exitCode == 0;
        bool targetExists = vm.exists(metaPathFor(targetName));
        string memory target = targetExists ? vm.readFile(metaPathFor(targetName)) : "";
        string memory written = vm.readFile(pathFor(linkName));

        remove(linkName);
        removeAt(metaPathFor(targetName));

        assertTrue(targetExists, "a committed file outside the generated directory was destroyed by the write");
        assertEq(target, "COMMITTED", "the file outside the generated directory was rewritten by the write");
        assertFalse(linkIsStillASymlink, "the path is still a symlink");
        assertTrue(vm.contains(written, body), "the generated file did not land at the path");
    }

    /// A symlink that resolves to a directory is a symlink like any other: the
    /// link comes off the path and the directory it pointed at, along with
    /// everything under it, is left alone. A directory is the one thing that
    /// cannot be taken off the path, but a link to one is not a directory, and
    /// the distinction is exactly the one `rm` makes and `vm.removeFile` does
    /// not.
    function testBuildFileForContractReplacesASymlinkToADirectory() external {
        string memory name = "LibFsIsPresentLinkedDir";
        string memory linkName = "LibFsIsPresentLinkedDir.sol";
        string memory dirName = "LibFsIsPresentLinkedDirTarget";
        string memory insideName = string.concat(dirName, "/inside.txt");
        remove(linkName);
        remove(dirName);

        vm.createDir(pathFor(dirName), true);
        vm.writeFile(pathFor(insideName), "INSIDE");
        symlink(linkName, dirName);
        assertEq(LibFs.pathForContract(name), pathFor(linkName), "the link is not where the write goes");
        assertEq(readlink(linkName).exitCode, 0, "the path under test is not a symlink");
        assertTrue(vm.isDir(pathFor(linkName)), "the link does not resolve to a directory");

        string memory body = "\n// linked dir\n";
        generate(name, body);

        bool linkIsStillASymlink = readlink(linkName).exitCode == 0;
        bool pathIsFile = vm.isFile(pathFor(linkName));
        bool dirSurvives = vm.isDir(pathFor(dirName));
        string memory inside = vm.exists(pathFor(insideName)) ? vm.readFile(pathFor(insideName)) : "";
        string memory written = vm.readFile(pathFor(linkName));

        remove(linkName);
        remove(dirName);

        assertTrue(dirSurvives, "the directory the link resolved to was removed");
        assertEq(inside, "INSIDE", "the contents of the directory the link resolved to did not survive");
        assertFalse(linkIsStillASymlink, "the path is still a symlink");
        assertTrue(pathIsFile, "the path does not hold a regular file");
        assertTrue(vm.contains(written, body), "the generated file did not land at the path");
    }

    /// A chain of symlinks ends the same way one link does, and takes only its
    /// first link with it. The path is the first link, so that is what comes
    /// off; the second link and the file at the end of it are two more paths
    /// nobody named.
    ///
    /// This is also where a removal that resolved before acting reaches
    /// furthest: it lands on the far end of the whole chain, however long the
    /// chain is.
    function testBuildFileForContractReplacesASymlinkChain() external {
        string memory name = "LibFsIsPresentChain";
        string memory linkName = "LibFsIsPresentChain.sol";
        string memory middleName = "LibFsIsPresentChainMiddle.txt";
        string memory targetName = "LibFsIsPresentChainTarget.txt";
        remove(linkName);
        remove(middleName);
        remove(targetName);

        vm.writeFile(pathFor(targetName), "SENTINEL");
        symlink(middleName, targetName);
        symlink(linkName, middleName);
        assertEq(LibFs.pathForContract(name), pathFor(linkName), "the link is not where the write goes");
        assertEq(readlink(linkName).exitCode, 0, "the path under test is not a symlink");
        assertTrue(vm.exists(pathFor(linkName)), "the chain does not resolve");

        string memory body = "\n// chain\n";
        generate(name, body);

        bool linkIsStillASymlink = readlink(linkName).exitCode == 0;
        VmSafe.FfiResult memory middle = readlink(middleName);
        bool targetExists = vm.exists(pathFor(targetName));
        string memory target = targetExists ? vm.readFile(pathFor(targetName)) : "";
        string memory written = vm.readFile(pathFor(linkName));

        remove(linkName);
        remove(middleName);
        remove(targetName);

        assertFalse(linkIsStillASymlink, "the path is still a symlink");
        assertEq(middle.exitCode, 0, "the second link in the chain was removed");
        assertEq(string(middle.stdout), targetName, "the second link in the chain was repointed");
        assertTrue(targetExists, "the far end of the chain was destroyed by the write");
        assertEq(target, "SENTINEL", "the far end of the chain's own content did not survive the write");
        assertTrue(vm.contains(written, body), "the generated file did not land at the path");
    }

    /// A cycle of symlinks resolves to nothing, so the path is occupied by
    /// something that is not there. The write still ends, and still ends with a
    /// regular file at the path: the removal acts on the link rather than on
    /// what it resolves to, and a link is always something that can be removed.
    ///
    /// Termination is the point. Every removal here has to take something off
    /// the path, or the call has to end anyway; a cycle is the shape that never
    /// bottoms out, so it is what a removal that kept looking for one would spin
    /// on.
    function testBuildFileForContractReplacesASymlinkCycle() external {
        string memory name = "LibFsIsPresentCycle";
        string memory linkName = "LibFsIsPresentCycle.sol";
        string memory otherName = "LibFsIsPresentCycleOther.txt";
        remove(linkName);
        remove(otherName);

        symlink(linkName, otherName);
        symlink(otherName, linkName);
        assertEq(LibFs.pathForContract(name), pathFor(linkName), "the link is not where the write goes");
        assertEq(readlink(linkName).exitCode, 0, "the path under test is not a symlink");
        assertFalse(vm.exists(pathFor(linkName)), "the cycle resolves to something");

        string memory body = "\n// cycle\n";
        generate(name, body);

        bool linkIsStillASymlink = readlink(linkName).exitCode == 0;
        bool pathIsFile = vm.isFile(pathFor(linkName));
        VmSafe.FfiResult memory other = readlink(otherName);
        string memory written = vm.readFile(pathFor(linkName));

        remove(linkName);
        remove(otherName);

        assertFalse(linkIsStillASymlink, "the path is still a symlink");
        assertTrue(pathIsFile, "the path does not hold a regular file");
        assertEq(other.exitCode, 0, "the other half of the cycle was removed");
        assertEq(string(other.stdout), linkName, "the other half of the cycle was repointed");
        assertTrue(vm.contains(written, body), "the generated file did not land at the path");
    }

    /// A directory at the generated path is the one thing the write cannot take
    /// off it. It reverts rather than clearing the directory, and rather than
    /// writing the generated source into it: a directory holds whatever a
    /// consumer put there, and neither emptying it nor generating a file inside
    /// it is what was asked for.
    ///
    /// Caught rather than expected, so the assertions run after the directory is
    /// removed. A failing assertion ends the test where it stands and would
    /// leave the directory in `src/generated/` for whatever compiles next.
    function testBuildFileForContractRefusesADirectoryAtThePath() external {
        string memory name = "LibFsIsPresentDirAtPath";
        string memory dirName = "LibFsIsPresentDirAtPath.sol";
        string memory insideName = string.concat(dirName, "/inside.txt");
        remove(dirName);

        vm.createDir(pathFor(dirName), true);
        vm.writeFile(pathFor(insideName), "INSIDE");
        assertEq(LibFs.pathForContract(name), pathFor(dirName), "the directory is not where the write goes");

        bool reverted;
        try iExternal.buildFileForContract(
            vm, address(this), name, "LicenseRef-DCL-1.0", "Copyright (c) 2020 Rain Open Source Software Ltd", "\n\n"
        ) {
            reverted = false;
        } catch {
            reverted = true;
        }

        bool dirSurvives = vm.isDir(pathFor(dirName));
        string memory inside = vm.exists(pathFor(insideName)) ? vm.readFile(pathFor(insideName)) : "";

        remove(dirName);

        assertTrue(reverted, "a directory at the generated path was not refused");
        assertTrue(dirSurvives, "the directory at the generated path was removed");
        assertEq(inside, "INSIDE", "the contents of the directory at the generated path did not survive");
    }
}

// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {LibFs, GENERATED_DIR, OrphanedGeneratedArtifact} from "src/lib/LibFs.sol";
import {InvalidIdentifier} from "src/lib/LibCodeGen.sol";
import {LibFsExternal} from "test/concrete/LibFsExternal.sol";
import {LibCodeGenSlow} from "test/lib/LibCodeGenSlow.sol";

/// @dev A parseable Solidity source unit, so that a file one of these tests
/// leaves under `src/generated` on failure does not also break the compile.
//REUSE-IgnoreStart
string constant PLACEHOLDER_SOURCE = "// SPDX-License-Identifier: LicenseRef-DCL-1.0\npragma solidity ^0.8.25;\n";

//REUSE-IgnoreEnd

/// @title LibFsRequireNoOrphanedArtifactTest
/// @notice Consumers commit what this library generates and import it by path,
/// so a second artifact for the same contract sitting beside the one being
/// generated is a file nothing regenerates while `src/**` keeps importing it.
/// These assert that such a file is refused, that the refusal is keyed on the
/// contract name rather than on any one extension, and that the file the
/// library does write is the one thing it is not refused for.
///
/// Every test owns a contract name no other test uses, because the check reads
/// the whole generated directory and suites run in parallel.
contract LibFsRequireNoOrphanedArtifactTest is Test {
    /// `vm.expectRevert` needs a call frame, and `requireNoOrphanedArtifact` is
    /// an internal library function that is inlined into its caller.
    LibFsExternal internal immutable iExternal;

    constructor() {
        iExternal = new LibFsExternal();
    }

    /// The check is one read of `GENERATED_DIR`, and `src/generated/` holds no
    /// committed file, so nothing in a fresh clone creates it. Every test here
    /// also writes its fixture there directly, and a filtered run may be only
    /// one of them, so the directory is not something this contract can inherit
    /// from a test that happened to run earlier.
    function setUp() external {
        vm.createDir(GENERATED_DIR, true);
    }

    /// Removes whatever is at `path`, so a test establishes its own
    /// precondition rather than assuming one.
    function cleanupPath(string memory path) internal {
        if (vm.exists(path)) {
            if (vm.isDir(path)) {
                vm.removeDir(path, true);
            } else {
                vm.removeFile(path);
            }
        }
    }

    /// The path an artifact for `contractName` occupies when its name carries
    /// `suffix` in place of the `sol` the library appends.
    function artifactPath(string memory contractName, string memory suffix) internal pure returns (string memory) {
        return string.concat(GENERATED_DIR, "/", contractName, ".", suffix);
    }

    /// Runs the check and hands back what it reverted with, or empty bytes when
    /// it did not revert. Nothing here asserts, so a caller removes its
    /// fixtures before it asserts anything about them.
    ///
    /// A revert and a failed assertion both abort the test body at the point
    /// they happen, so a fixture removed after either one is removed only on
    /// the runs that pass. Every fixture these tests write is a file this check
    /// refuses on, and they all share the one generated directory, so a fixture
    /// left behind by a failing run is a precondition the next run does not get
    /// to choose.
    function checkOutcome(string memory contractName) internal returns (bytes memory) {
        try iExternal.requireNoOrphanedArtifact(vm, contractName) {
            return "";
        } catch (bytes memory reason) {
            return reason;
        }
    }

    /// Asserts `outcome` is the check accepting the contract.
    function assertAccepted(bytes memory outcome) internal pure {
        assertEq(outcome.length, 0, "the check refused a contract it must accept");
    }

    /// Asserts `outcome` is the check refusing `orphan`, by the exact error and
    /// path a consumer is shown. The comparison is over the raw revert bytes,
    /// so the message says in words what those bytes are meant to be.
    function assertRefused(bytes memory outcome, string memory orphan) internal pure {
        assertEq(
            outcome,
            abi.encodeWithSelector(OrphanedGeneratedArtifact.selector, orphan),
            string.concat("not refused as OrphanedGeneratedArtifact(", orphan, ")")
        );
    }

    /// No artifact at all for the contract is the first generation in a repo,
    /// which must not be refused.
    function testRequireNoOrphanedArtifactAcceptsNothingForTheContract() external {
        string memory name = "LibFsOrphanNothing";
        cleanupPath(LibFs.pathForContract(name));
        cleanupPath(artifactPath(name, "pointers.sol"));

        LibFs.requireNoOrphanedArtifact(vm, name);
    }

    /// The file the library writes is the one artifact for the contract that is
    /// never an orphan, so regenerating over it is not refused.
    function testRequireNoOrphanedArtifactAcceptsTheFileItWrites() external {
        string memory name = "LibFsOrphanCurrent";
        vm.writeFile(LibFs.pathForContract(name), PLACEHOLDER_SOURCE);

        bytes memory outcome = checkOutcome(name);

        cleanupPath(LibFs.pathForContract(name));
        assertAccepted(outcome);
    }

    /// The artifact name this library wrote before `src/generated/<Name>.sol`.
    /// Consumers still hold these committed and imported, so this is the case
    /// that reaches the check in the field.
    function testRequireNoOrphanedArtifactRejectsTheLegacyName() external {
        string memory name = "LibFsOrphanLegacy";
        string memory legacy = artifactPath(name, "pointers.sol");
        cleanupPath(legacy);
        vm.writeFile(legacy, PLACEHOLDER_SOURCE);

        bytes memory outcome = checkOutcome(name);

        cleanupPath(legacy);
        assertRefused(outcome, legacy);
    }

    /// Having generated the current file does not excuse the orphan: adding the
    /// new artifact without deleting the old one leaves `src/**` importing the
    /// old one, which is the state the refusal exists to reject.
    function testRequireNoOrphanedArtifactRejectsAlongsideTheCurrentFile() external {
        string memory name = "LibFsOrphanBoth";
        string memory legacy = artifactPath(name, "pointers.sol");
        cleanupPath(legacy);
        vm.writeFile(LibFs.pathForContract(name), PLACEHOLDER_SOURCE);
        vm.writeFile(legacy, PLACEHOLDER_SOURCE);

        bytes memory outcome = checkOutcome(name);

        cleanupPath(legacy);
        cleanupPath(LibFs.pathForContract(name));
        assertRefused(outcome, legacy);
    }

    /// Writes an artifact for `contractName` carrying `suffix`, asserts it is
    /// refused by the path it occupies, and removes it again. The contract name
    /// is the caller's so that each case owns a file no other case names.
    function assertSuffixRejected(string memory contractName, string memory suffix) internal {
        string memory orphan = artifactPath(contractName, suffix);
        cleanupPath(orphan);
        vm.writeFile(orphan, PLACEHOLDER_SOURCE);

        bytes memory outcome = checkOutcome(contractName);

        cleanupPath(orphan);
        assertRefused(outcome, orphan);
    }

    /// The refusal is keyed on the contract name, not on the one extension that
    /// happens to be stale today, so the next time `pathForContract` moves
    /// there is nothing here to update. Spelled out one suffix at a time rather
    /// than fuzzed: fuzz cases run concurrently against the one generated
    /// directory, two cases whose file names collide race on it, and random
    /// identifiers essentially never land near `sol` anyway. These do — every
    /// one of them differs from the appended `sol` by a single edit, which is
    /// what a comparison that is nearly right survives.
    function testRequireNoOrphanedArtifactRejectsEveryOtherSuffix() external {
        assertSuffixRejected("LibFsOrphanSuffixLegacy", "pointers.sol");
        assertSuffixRejected("LibFsOrphanSuffixShort", "so");
        assertSuffixRejected("LibFsOrphanSuffixLong", "soll");
        assertSuffixRejected("LibFsOrphanSuffixUpper", "SOL");
        assertSuffixRejected("LibFsOrphanSuffixLead", "asol");
        assertSuffixRejected("LibFsOrphanSuffixDigit", "sol0");
        assertSuffixRejected("LibFsOrphanSuffixDouble", "sol.sol");
        assertSuffixRejected("LibFsOrphanSuffixOther", "json");
        assertSuffixRejected("LibFsOrphanSuffixBare", "pointers");
        assertSuffixRejected("LibFsOrphanSuffixEmpty", "");
    }

    /// An artifact is the contract name followed by a `.`, so the name on its
    /// own is not one. Nothing this library writes is extensionless, and a file
    /// that is holds no imports for `src/**` to resolve to.
    function testRequireNoOrphanedArtifactIgnoresTheBareName() external {
        string memory name = "LibFsOrphanBare";
        string memory bare = string.concat(GENERATED_DIR, "/", name);
        cleanupPath(bare);
        vm.writeFile(bare, PLACEHOLDER_SOURCE);

        bytes memory outcome = checkOutcome(name);

        cleanupPath(bare);
        assertAccepted(outcome);
    }

    /// An artifact belongs to the contract whose name it carries in full, up to
    /// the `.`. A longer name that merely starts with this one is a different
    /// contract's artifact and must not be refused, or a repo could not
    /// generate both `Foo` and `FooBar`.
    function testRequireNoOrphanedArtifactIgnoresOtherContracts() external {
        string memory name = "LibFsOrphanPrefix";
        string memory sibling = artifactPath(string.concat(name, "Extra"), "pointers.sol");
        string memory unrelated = artifactPath("LibFsOrphanUnrelated", "pointers.sol");
        cleanupPath(sibling);
        cleanupPath(unrelated);
        vm.writeFile(sibling, PLACEHOLDER_SOURCE);
        vm.writeFile(unrelated, PLACEHOLDER_SOURCE);

        bytes memory outcome = checkOutcome(name);

        cleanupPath(sibling);
        cleanupPath(unrelated);
        assertAccepted(outcome);
    }

    /// A name that is a prefix of this one, and so a shorter contract's
    /// artifact, is likewise not this contract's.
    function testRequireNoOrphanedArtifactIgnoresShorterContracts() external {
        string memory name = "LibFsOrphanLongerName";
        string memory shorter = artifactPath("LibFsOrphanLonger", "pointers.sol");
        cleanupPath(shorter);
        vm.writeFile(shorter, PLACEHOLDER_SOURCE);

        bytes memory outcome = checkOutcome(name);

        cleanupPath(shorter);
        assertAccepted(outcome);
    }

    /// Consumers freeze per release snapshots into subdirectories of the
    /// generated directory. `pathForContract` never names anything below a
    /// direct child, so nothing down there is an artifact this library wrote
    /// and none of it is refused.
    function testRequireNoOrphanedArtifactIgnoresSubdirectories() external {
        string memory name = "LibFsOrphanNested";
        string memory dir = string.concat(GENERATED_DIR, "/LibFsOrphanTag");
        cleanupPath(dir);
        vm.createDir(dir, true);
        vm.writeFile(string.concat(dir, "/", name, ".pointers.sol"), PLACEHOLDER_SOURCE);
        vm.writeFile(string.concat(dir, "/", name, ".sol"), PLACEHOLDER_SOURCE);

        bytes memory outcome = checkOutcome(name);

        cleanupPath(dir);
        assertAccepted(outcome);
    }

    /// A directory occupying an artifact's name is not something this library
    /// wrote either, and leaving it there means the name is taken by something
    /// no regeneration touches.
    function testRequireNoOrphanedArtifactRejectsADirectory() external {
        string memory name = "LibFsOrphanDir";
        string memory orphan = artifactPath(name, "pointers.sol");
        cleanupPath(orphan);
        vm.createDir(orphan, true);

        bytes memory outcome = checkOutcome(name);

        cleanupPath(orphan);
        assertRefused(outcome, orphan);
    }

    /// The check asks `pathForContract` which file is the current one, so it
    /// inherits that function's refusal to produce a path for a name that is
    /// not a Solidity identifier.
    function testRequireNoOrphanedArtifactRejectsEveryNonIdentifierName(bytes memory nameBytes) external {
        string memory contractName = string(nameBytes);
        vm.assume(!LibCodeGenSlow.isIdentifierSlow(contractName));

        vm.expectRevert(abi.encodeWithSelector(InvalidIdentifier.selector, contractName));
        iExternal.requireNoOrphanedArtifact(vm, contractName);
    }
}

// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {LibParseMeta} from "rain.interpreter.interface/lib/parse/LibParseMeta.sol";
import {LibAuthoringMeta, AuthoringMetaV2} from "test/lib/meta/LibAuthoringMeta.sol";
import {LibGenParseMeta} from "src/lib/LibGenParseMeta.sol";
import {LibBloom} from "test/lib/bloom/LibBloom.sol";

// import {AuthoringMetaV2} from "rain.interpreter.interface/interface/IParserV1.sol";
// import {LibParseMeta} from "src/lib/parse/LibParseMeta.sol";
// import {LibParseState, ParseState} from "src/lib/parse/LibParseState.sol";
// import {LibBloom} from "test/lib/bloom/LibBloom.sol";
// import {LibParseOperand, Operand} from "src/lib/parse/LibParseOperand.sol";

contract LibGenParseMetaBuildMetaTest is Test {
    // using LibParseState for ParseState;
    // using LibParseMeta for ParseState;

    /// This is super loose from limited empirical testing.
    function expanderDepth(uint256 n) internal pure returns (uint8) {
        // Number of fully saturated expanders
        // + 1 for solidity flooring everything
        // + 1 for a non-fully saturated but still quite full expander
        // + 1 for a potentially nearly empty expander
        return uint8(n / type(uint8).max + 3);
    }

    function testBuildMeta(AuthoringMetaV2[] memory authoringMeta) external pure {
        vm.assume(!LibBloom.bloomFindsDupes(LibAuthoringMeta.copyWordsFromAuthoringMeta(authoringMeta)));
        bytes memory meta = LibGenParseMeta.buildParseMetaV2(authoringMeta, expanderDepth(authoringMeta.length));
        (meta);
    }

    function testRoundMetaExpanderShallow(AuthoringMetaV2[] memory authoringMeta, uint8 j, bytes32 notFound)
        external
        pure
    {
        vm.assume(authoringMeta.length > 0);
        vm.assume(!LibBloom.bloomFindsDupes(LibAuthoringMeta.copyWordsFromAuthoringMeta(authoringMeta)));
        for (uint256 i = 0; i < authoringMeta.length; i++) {
            vm.assume(authoringMeta[i].word != notFound);
        }
        j = uint8(bound(j, uint8(0), uint8(authoringMeta.length) - 1));

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(authoringMeta, expanderDepth(authoringMeta.length));
        (bool exists, uint256 k) = LibParseMeta.lookupWord(meta, authoringMeta[j].word);
        assertTrue(exists, "exists");
        assertEq(j, k, "k");

        (bool notExists, uint256 l) = LibParseMeta.lookupWord(meta, notFound);
        assertTrue(!notExists, "notExists");
        assertEq(0, l, "l");
    }

    function testRoundMetaExpanderDeeper(AuthoringMetaV2[] memory authoringMeta, uint8 j, bytes32 notFound)
        external
        pure
    {
        vm.assume(authoringMeta.length > 50);
        vm.assume(!LibBloom.bloomFindsDupes(LibAuthoringMeta.copyWordsFromAuthoringMeta(authoringMeta)));
        for (uint256 i = 0; i < authoringMeta.length; i++) {
            vm.assume(authoringMeta[i].word != notFound);
        }
        j = uint8(bound(j, uint8(0), uint8(authoringMeta.length) - 1));

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(authoringMeta, expanderDepth(authoringMeta.length));

        (bool exists, uint256 k) = LibParseMeta.lookupWord(meta, authoringMeta[j].word);
        assertTrue(exists, "exists");
        assertEq(j, k, "k");

        (bool notExists, uint256 l) = LibParseMeta.lookupWord(meta, notFound);
        assertTrue(!notExists, "notExists");
        assertEq(0, l, "l");
    }
}

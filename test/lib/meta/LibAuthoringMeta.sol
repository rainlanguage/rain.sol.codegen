// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {AuthoringMetaV2} from "rain.interpreter.interface/interface/IParserV1.sol";

library LibAuthoringMeta {
    function copyWordsFromAuthoringMeta(AuthoringMetaV2[] memory authoringMeta)
        internal
        pure
        returns (bytes32[] memory)
    {
        bytes32[] memory words = new bytes32[](authoringMeta.length);
        for (uint256 i = 0; i < authoringMeta.length; i++) {
            words[i] = authoringMeta[i].word;
        }
        return words;
    }
}

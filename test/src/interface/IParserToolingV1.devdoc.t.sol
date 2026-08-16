// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibDevdoc} from "test/lib/LibDevdoc.sol";

/// @dev The documented encoding of `buildOperandHandlerFunctionPointers`' return
/// value, as published. Held as a literal here rather than read back out of the
/// source it documents, so that dropping or rewording the tag moves the devdoc
/// off this string instead of carrying this string along with it.
string constant BUILD_OPERAND_HANDLER_FUNCTION_POINTERS_RETURN_DOC =
    "Every two bytes is a function pointer for an operand handler, positionally indexed to match the parse meta.";

/// @dev The documented encoding of `buildLiteralParserFunctionPointers`' return
/// value, as published. Distinct from the operand handler text because literal
/// parsers are not indexed the same way, and asserted separately so that the two
/// builders on this interface cannot share one docstring.
string constant BUILD_LITERAL_PARSER_FUNCTION_POINTERS_RETURN_DOC =
    "Every two bytes is a function pointer for a literal parser, dispatched on the first byte(s) of the literal.";

/// @title IParserToolingV1DevdocTest
/// @notice The width and the indexing of the returned bytes are the whole
/// contract of a builder: the caller gets an undifferentiated `bytes memory` and
/// has to know how to cut it up. That fact is only carried to a consumer if it
/// is tagged as a return, because solc puts tagged text in `devdoc` and folds
/// untagged `///` prose into the preceding `userdoc` notice, so a builder whose
/// encoding is described in untagged prose ships an artifact that documents the
/// return value nowhere.
contract IParserToolingV1DevdocTest is Test {
    /// The encoding reaches the compiled artifact as this function's return tag.
    function testBuildOperandHandlerFunctionPointersReturnDoc() external view {
        assertEq(
            LibDevdoc.soleReturnDoc(vm, "IParserToolingV1", "buildOperandHandlerFunctionPointers()"),
            BUILD_OPERAND_HANDLER_FUNCTION_POINTERS_RETURN_DOC
        );
    }

    /// The encoding reaches the compiled artifact as this function's return tag.
    function testBuildLiteralParserFunctionPointersReturnDoc() external view {
        assertEq(
            LibDevdoc.soleReturnDoc(vm, "IParserToolingV1", "buildLiteralParserFunctionPointers()"),
            BUILD_LITERAL_PARSER_FUNCTION_POINTERS_RETURN_DOC
        );
    }
}

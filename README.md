# rain.sol.codegen

Solidity native tooling to generate Solidity code.

Notably builds a valid Solidity file (pragma, etc.) that passes foundry
formatting cleanly, that can build the constant caches needed for prebuilt
function pointer tables to ensure runtime gas efficiency.

Includes interfaces for the interpreter and sub parsers/externs for Rain
contracts to implement and be compatible with the code generation functions here.

`script/BuildPointers.sol` includes an example implementation and
`.github/workflows/git-clean.yaml` an example CI action to show how to build
pointers cleanly and ensure that the source code does not become out of sync with
the built artifacts when merging new code.

Generated code is intended to be imported downstream into contracts that may
themselves expose pointers to be included in the generated code. This circular
dependency means the pointers may need to be built several times until they
produce a stable output where the pointers do not move, and therefore do not
break the codehash over the contract that includes the pointers.
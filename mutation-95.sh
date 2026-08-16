#!/usr/bin/env bash
# Mutation driver for issue 95. Each mutant breaks exactly one line, runs the
# new test file, records the result, and restores the tree from git.
set -uo pipefail
cd "$(dirname "$0")" || exit 1

TEST_PATH=test/src/PublishedSourcePaths.t.sol
OUT=mutation-95.log
: >"$OUT"

run_case() {
  local name="$1"
  rm -rf cache/fuzz/failures
  {
    echo "===== $name ====="
    forge test --match-path "$TEST_PATH" 2>&1 | grep -E "^\[(PASS|FAIL)|^Suite result|^Ran |^Error|^No tests"
  } >>"$OUT"
  git checkout -- src script test foundry.toml
}

# Baseline: unmutated, both tests must pass.
run_case "M0 baseline (no mutation)"

# M1..M5: reintroduce the stripped path in each of the five docstrings.
for f in \
  src/interface/IIntegrityToolingV1.sol \
  src/interface/IOpcodeToolingV1.sol \
  src/interface/ISubParserToolingV1.sol
do
  sed -i 's|/// `script/Build.sol` in this package is a worked example of such a|/// See .github/workflows/build-pointers.yaml for an example of such a|' "$f"
  run_case "MUTANT $f"
done

# IParserToolingV1 carries two, mutated one at a time.
sed -i '0,|/// `script/Build.sol` in this package is a worked example of such a|s||/// See .github/workflows/build-pointers.yaml for an example of such a|' src/interface/IParserToolingV1.sol
run_case "MUTANT src/interface/IParserToolingV1.sol first docstring"

sed -i '20,$s|/// `script/Build.sol` in this package is a worked example of such a|/// See .github/workflows/build-pointers.yaml for an example of such a|' src/interface/IParserToolingV1.sol
run_case "MUTANT src/interface/IParserToolingV1.sol second docstring"

# M6: shallow the src walk so no .sol file is reached.
sed -i 's|vm.readDir("src", 8)|vm.readDir("src", 1)|' "$TEST_PATH"
run_case "MUTANT sourceFiles depth 8 -> 1"

# M7: point the docstring target at a path .soldeerignore strips.
sed -i 's|string constant BUILD_SCRIPT = "script/Build.sol";|string constant BUILD_SCRIPT = "test/concrete/CodeGennable.sol";|' "$TEST_PATH"
run_case "MUTANT BUILD_SCRIPT -> stripped path"

cat "$OUT"

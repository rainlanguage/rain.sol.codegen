# rain.sol.codegen

Solidity-native tooling to generate Solidity source. Builds a valid `.sol` file
(pragma + foundry-clean formatting) hosting build-time constants that a contract
imports and the compiler inlines: prebuilt function-pointer tables (the case
that motivates it — runtime gas efficiency in the Rain interpreter), a
deployed-bytecode hash, a described-by meta hash, and plain
`address`/`uint8`/`bytes32`/`bytes` constants.

Also exposes the tooling interfaces (`IIntegrityToolingV1`, `IOpcodeToolingV1`,
`IParserToolingV1`, `ISubParserToolingV1`) that Rain contracts implement to
build the pointers this library caches.

A consumer drives this library from a build script, and the path of that script
is not a free choice: it must be `script/Build.sol`, the path org CI regenerates
and currency-checks committed generated sources from — see
[`rainix-copy-artifacts.yaml`](https://github.com/rainlanguage/rainix/blob/main/.github/workflows/rainix-copy-artifacts.yaml).
Any other path is an unsupported layout.

The org's worked example is
[`rainlanguage/rain.deploy`](https://github.com/rainlanguage/rain.deploy):
[`script/Build.sol`](https://github.com/rainlanguage/rain.deploy/blob/main/script/Build.sol)
generates into its committed `src/generated/`. This repo carries no example of
its own — it is the library, and nothing here is generated.

Generated code is imported downstream by contracts that themselves expose
pointers, which pointers feed back into the generation. This cycle means
pointers may need to be regenerated several times until they reach a fixed point
where neither pointer values nor the codehash of any consuming contract shift.

Reaching that fixed point is the consumer's job: nothing bounds or iterates the
loop. A tree that has not settled fails the currency check exactly as a tree
nobody regenerated does — see
[`rainix-copy-artifacts.yaml`](https://github.com/rainlanguage/rainix/blob/main/.github/workflows/rainix-copy-artifacts.yaml)
— so regenerate until the working tree stops changing before committing, and
read a tree that never stops changing as a cycle that does not converge rather
than one more pass to run. Committing part-way records a deployed-bytecode hash
for a contract compiled against a different pass of the same file.

## Formatter requirements

`LibCodeGen` wraps the declarations it emits itself, deciding against
`MAX_LINE_LENGTH` and `NEWLINE_DUE_TO_MAX_LENGTH`. Those two encode
`forge fmt`'s `line_length` and `tab_width`, which this repo states in `[fmt]`
of `foundry.toml` rather than inheriting.

A consuming repo whose `[fmt]` disagrees gets generated sources its own
`forge fmt` reflows away from what this library emits. Consumers therefore need
`line_length = 120` and `tab_width = 4`.

## Install

Via [soldeer](https://soldeer.xyz):

```sh
forge soldeer install rain-sol-codegen~<version>
```

## Develop

This repo uses [nix](https://nixos.org/download.html). The default shell is the
slim `sol-shell` from [rainix](https://github.com/rainlanguage/rainix).

```sh
nix develop           # enter the shell
forge soldeer install # install deps declared in foundry.toml
forge build
```

Checks, each of which CI also runs:

- `forge test`
- `forge fmt --check`
- `slither .`
- `reuse lint`

`forge test` writes scratch files under `src/generated/`, creating the directory
if it is absent. Nothing there is committed, and every test removes its own
file, so a completed run leaves the directory empty and invisible to git. Same
arrangement as `meta/`, which the meta-hash tests use the same way. Anything
left there after an interrupted run is scratch, and `git status` will say so.

[`.github/workflows/rainix.yaml`](https://github.com/rainlanguage/rain.sol.codegen/blob/main/.github/workflows/rainix.yaml)
is what runs all four in CI, via rainix's `rainix-sol.yaml`. CI also applies
org-wide gates that none of the four covers — see
[`rainix-sol-static.yaml`](https://github.com/rainlanguage/rainix/blob/main/.github/workflows/rainix-sol-static.yaml)
— so a green local run is necessary but not sufficient.

Use the nix-pinned `forge` for all development.

## Publish

Publishing is merge-driven, not tag-driven.
[`Package Release`](https://github.com/rainlanguage/rain.sol.codegen/blob/main/.github/workflows/package-release.yaml)
calls rainix's
[`rainix-autopublish.yaml`](https://github.com/rainlanguage/rainix/blob/main/.github/workflows/rainix-autopublish.yaml)
reusable on every push to `main`, passing the package name explicitly as
`soldeer-package: rain-sol-codegen`.

That workflow owns both the version and the release tag, so neither is set by
hand. `[package].version` in `foundry.toml` is therefore the next, unpublished
version rather than the last published one.

## License

DecentraLicense 1.0 (DCL-1.0) — full text in
[`LICENSES/`](LICENSES/LicenseRef-DCL-1.0.txt). Roughly `CAL-1.0`
([opensource.org](https://opensource.org/license/cal-1-0)) plus user-data
disclosure obligations consistent with permissionless-blockchain assumptions.

This repo is [REUSE 3.3](https://reuse.software/spec-3.3/) compliant. Verify
locally:

```sh
nix develop -c reuse lint
```

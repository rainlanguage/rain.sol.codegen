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
is not a free choice: rainix's `rainix-copy-artifacts.yaml` reusable regenerates
from `script/Build.sol` exactly, and hard-fails any repo that commits
`src/generated/` without one. A consumer that names its script anything else
gets no regeneration and no currency check.

The org's worked example is
[`rainlanguage/rain.deploy`](https://github.com/rainlanguage/rain.deploy):
[`script/Build.sol`](https://github.com/rainlanguage/rain.deploy/blob/main/script/Build.sol)
generates into its committed `src/generated/`. This repo carries no example of
its own — it is the library, and nothing here is generated.

Generated code is imported downstream by contracts that themselves expose
pointers, which pointers feed back into the generation. This cycle means
pointers may need to be regenerated several times until they reach a fixed point
where neither pointer values nor the codehash of any consuming contract shift.

## Formatter requirements

`LibCodeGen` wraps the declarations it emits itself, deciding against
`MAX_LINE_LENGTH` and `NEWLINE_DUE_TO_MAX_LENGTH`. Those two encode
`forge fmt`'s `line_length` and `tab_width`, which this repo states in `[fmt]`
of `foundry.toml` rather than inheriting.

A consuming repo whose `[fmt]` disagrees gets generated sources its own
`forge fmt` reflows. `rainix-copy-artifacts` regenerates, runs `forge fmt`, then
`git diff --exit-code`, so that reflow is committed as the new baseline instead
of being reported. Consumers therefore need `line_length = 120` and
`tab_width = 4`.

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

On top of the above, CI applies rainix's org-wide static checks via
[`.github/workflows/rainix.yaml`](.github/workflows/rainix.yaml).

Use the nix-pinned `forge` for all development.

## Publish

Publishing is merge-driven, not tag-driven.
[`Package Release`](.github/workflows/package-release.yaml) calls rainix's
`rainix-autopublish.yaml` reusable on every push to `main`, passing the package
name explicitly as `soldeer-package: rain-sol-codegen`. When the source content
differs from the latest published revision, that workflow pushes
`[package].version` to Soldeer, tags `sol-v<x.y.z>`, and bumps
`[package].version` to the next version. `[package].version` in `foundry.toml`
is therefore the next, unpublished version rather than the last published one.
Neither the version nor the tag is set by hand.

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

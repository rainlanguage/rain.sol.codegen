# rain.sol.codegen

Solidity-native tooling to generate Solidity source. Builds a valid `.sol` file
(pragma + foundry-clean formatting) that hosts the constant caches for prebuilt
function-pointer tables — needed for runtime gas efficiency in the Rain
interpreter.

Also exposes the tooling interfaces (`IIntegrityToolingV1`, `IOpcodeToolingV1`,
`IParserToolingV1`, `ISubParserToolingV1`) that Rain contracts implement to
build the pointers this library caches.

`script/Build.sol` is an example implementation. The name is not a free choice:
rainix's `rainix-copy-artifacts.yaml` reusable regenerates from that exact path,
and hard-fails any repo that commits `src/generated/` without it.
`.github/workflows/build-pointers.yaml` wires that reusable up here, so CI fails
when the committed generated sources drift from a fresh regeneration.

Generated code is imported downstream by contracts that themselves expose
pointers, which pointers feed back into the generation. This cycle means
pointers may need to be regenerated several times until they reach a fixed point
where neither pointer values nor the codehash of any consuming contract shift.

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

Regenerate the committed example artifact under `src/generated/`:

```sh
forge script script/Build.sol
```

## Generated paths

`LibFs.pathForContract` names `src/generated/<Contract>.sol`, and
`buildFileForContract` writes that file and only that file. Consumers commit it
and import it by path from `src/**`, so the path is a cross repo contract:
moving it, or moving `GENERATED_DIR`, breaks every repo holding the artifact at
the old path.

`buildFileForContract` therefore refuses to generate while `src/generated/`
holds another artifact for the same contract — any direct child named for that
contract, in full, followed by a `.` and anything other than `sol`. Nothing
regenerates such a file, while the consumer's imports keep resolving to it, so
the build fails with `OrphanedGeneratedArtifact` naming the file rather than
generating beside it. Delete it and repoint the imports at
`src/generated/<Contract>.sol` in the same commit. Only direct children are
read, so per release snapshot directories under `src/generated/` are untouched.

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

The tag is never set by hand. The version is set by hand for exactly one reason:
the bump that workflow applies is always a patch step, so a change that breaks
consumers — the generated path contract above, or anything else a consumer
compiles against — carries the minor step in the PR that makes it. The gate
requires only that `[package].version` is ahead of the published revision, so it
publishes whatever version the merged tree names and resumes patch bumping from
there.

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

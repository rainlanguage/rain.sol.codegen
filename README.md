# rain.sol.codegen

Solidity-native tooling to generate Solidity source. Builds a valid `.sol` file
(pragma + foundry-clean formatting) that hosts the constant caches for prebuilt
function-pointer tables — needed for runtime gas efficiency in the Rain
interpreter.

Also exposes interfaces (interpreter, sub-parsers, externs) for Rain contracts
to implement against the generated code.

`script/BuildPointers.sol` is an example implementation;
`.github/workflows/git-clean.yaml` is an example CI guard that fails when the
committed pointer artifacts drift from a fresh regeneration.

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
nix develop          # enter the shell
forge soldeer install # install deps declared in foundry.toml
forge build
```

Tasks:

- `rainix-sol-static` — slither
- `rainix-sol-legal` — `reuse lint`

This repo has no `forge test` suite — the code is tooling exercised by
downstream consumers' generated artifacts.

Use the nix-pinned `forge` for all development.

## Publish

Tag `v<x.y.z>` on `main`. The
[`Publish to Soldeer`](.github/workflows/publish-soldeer.yaml) wrapper delegates
to rainix's reusable workflow, which derives the package name from the repo name
(`rain.sol.codegen` → `rain-sol-codegen`).

## License

DecentraLicense 1.0 (DCL-1.0) — full text in
[`LICENSES/`](LICENSES/LicenseRef-DCL-1.0.txt). Roughly `CAL-1.0`
([opensource.org](https://opensource.org/license/cal-1-0)) plus user-data
disclosure obligations consistent with permissionless-blockchain assumptions.

This repo is [REUSE 3.2](https://reuse.software/spec-3.2/) compliant. Verify
locally:

```sh
nix develop -c rainix-sol-legal
```

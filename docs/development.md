# Development setup

Per-tier setup and workflow. The repo is a monorepo; each tier builds
independently and has its own CI job.

## Prerequisites by tier

| Tier | Needs | Notes |
| --- | --- | --- |
| `apps/ios/FungibleCore` | Swift 5.9+ | Builds on Linux or macOS; no device |
| `apps/ios/FungibleApp` | macOS + Xcode 15+, LiDAR device, XcodeGen | `sceneDepth` needs real hardware (no simulator) |
| `services/worker` | Python 3.12+; PDAL/GDAL via conda for execution | Tests need only `pytest` |
| `web/viewer` | Node 20+ | — |

## iOS core (`FungibleCore`)

```sh
cd apps/ios/FungibleCore
swift build
swift test
```

Add a module: create `Sources/<Module>/`, declare the target (and a test target)
in `Package.swift`, depend inward on `FungibleDomain`. Never import ARKit/Metal
here — that breaks Linux CI and the device-independence rule (see CLAUDE.md).

## iOS app (`FungibleApp`)

```sh
brew install xcodegen
cd apps/ios/FungibleApp
xcodegen generate          # regenerates FungibleApp.xcodeproj (not committed)
open FungibleApp.xcodeproj
```

Select a LiDAR-equipped device and run. The app depends on the local
`FungibleCore` package by relative path. The capture pipeline reuses the core's
tested math; the Metal shader mirrors `FungibleCapture.Unprojection`.

## Cloud worker (`services/worker`)

```sh
cd services/worker
pip install -r requirements-dev.txt
pytest -q                  # tests the pure pipeline builders (no native deps)

# To actually run pipelines, install PDAL via conda-forge:
conda install -c conda-forge pdal python-pdal gdal
python -m fungible_worker --dry-run to-copc scan.laz scan.copc.laz
```

Keep pipeline builders pure (return PDAL pipelines as data). Only `runner.py`
imports `pdal`, lazily.

## Web viewer (`web/viewer`)

```sh
cd web/viewer
npm install
npm run dev                # local dev server
npm run typecheck          # tsc --noEmit
npm test                   # vitest
```

Pure logic (`format.ts`, `copc.ts`) is unit-tested; three.js/DOM live at the
edges (`pointCloudViewer.ts`, `main.ts`).

## CI

`.github/workflows/ci.yml` runs three jobs on every push: **core** (swift:5.9
container, build+test), **worker** (python:3.12-slim, pytest), **web** (node:20,
typecheck+test). All three must be green. Keep changes scoped so a failure points
at one tier.

## Commit & branch conventions

- Develop on the feature branch; keep CI green per commit.
- Commit messages explain the *why* and reference ADRs when structural.
- Structural decisions get a new ADR in `docs/decisions/` (don't edit accepted ones).

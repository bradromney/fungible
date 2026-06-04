# CLAUDE.md

Orientation for AI/dev sessions working in this repo. Read this first.

## What this is

Fungible (codename) — an iOS-native LiDAR **capture + processing + interop
platform**. Capture spaces as point clouds / 3D models, then measure, annotate,
**convert between formats**, and hand off to CAD/BIM/3D tools. It serves **AEC
(building/remodel/construction), general 3D modeling, and site/landscaping** —
the core is market-agnostic; vertical features (earthwork, IFC/BIM, meshing) are
modules on top. Landscaping is the **launch vertical, not the boundary**
(ADR-0007). Differentiators: **no scan-count ceiling**, **universal interop**,
guided capture, and (for site work) mobile cut/fill. See
`docs/decisions/0007-multi-market-positioning.md`.

## Read these to understand *why*

- `docs/decisions/` — ADRs 0001–0006 (the load-bearing choices). Start here.
- `docs/architecture/overview.md` — system shape + module map + data model.
- `docs/research/` — OSS landscape, competitive analysis, buy/build/reuse matrix.
- `docs/roadmap.md` — milestones M0→M6 and current status.
- `docs/third-party-licenses.md` — what may/may not be linked (commercial app).

## Repo layout

```
apps/ios/FungibleCore/   Swift Package — device-independent core (CI-tested)
apps/ios/FungibleApp/    ARKit/Metal/SwiftUI app (Xcode-only, NOT in CI)
services/worker/         Python PDAL cloud worker
web/viewer/              Vite/TS/three.js web viewer
docs/                    decisions, architecture, research, roadmap
.github/workflows/ci.yml core (swift) + worker (pytest) + web (tsc/vitest)
```

## Golden rule: the core stays device-independent

`FungibleCore` modules must **not** import ARKit/Metal/RealityKit, so they build
and test on Linux CI with no Apple device. ARKit/Metal implementations live in
`apps/ios/FungibleApp` and conform to protocols defined in the core. The CPU
math (e.g. `FungibleCapture.Unprojection`) is the spec/oracle; the Metal shader
mirrors it.

Modules: `FungibleDomain` (math, model), `FungibleCapture` (unprojection, voxel
accumulator), `FungibleStorage` (file/in-memory stores, codec), `FungibleRegistration`
(incremental no-ceiling pipeline), `FungibleMeasure` (DEM, cut/fill, contours),
`FungibleExport` (PLY/XYZ/DXF), `FungibleGuidance`, `FungibleEntitlements`.

## Build & test

```sh
# iOS core (no device needed; CI uses the swift:5.9 container)
cd apps/ios/FungibleCore && swift build && swift test

# Cloud worker (pure pipeline builders; PDAL imported lazily)
cd services/worker && pip install -r requirements-dev.txt && pytest -q

# Web viewer
cd web/viewer && npm install && npm run typecheck && npm test

# iOS app (macOS + Xcode + LiDAR device only)
cd apps/ios/FungibleApp && xcodegen generate && open FungibleApp.xcodeproj
```

## Conventions

- **Every change to the core must keep CI green.** Add tests with new logic.
- Swift: strict-concurrency-aware (`Sendable`); no `assumeIsolated` (iOS 16 target).
- Worker: keep pipeline builders **pure** (return PDAL pipelines as data); import
  PDAL only inside `runner`.
- Web: pure logic in testable modules (e.g. `format.ts`, `copc.ts`); keep three/
  DOM at the edges.
- Decisions that change structure get a new ADR (don't edit accepted ones).
- Commit messages: explain the *why*; reference ADRs where relevant.

## What needs a human / a Mac (not doable in a Linux CI session)

- Building/running `FungibleApp` on a LiDAR device (the M1 capture loop).
- Wiring the bridged native libs (LASzip/las-rs, libE57Format, copc-lib,
  small_gicp/TEASER++/GTSAM) — needs the C/C++/Rust toolchain + device validation.
- Choosing the first `SyncProvider` driver (iCloud / hosted S3-R2 / BYO Drive).
- The product name (still "Fungible").

## Status (current)

M0 foundation complete and CI-green. The full on-device pipeline composes in
tests: capture → accumulate → store → incremental registration → DEM →
cut/fill + contours → export. Next highest-leverage step is building M1 on a
device. See `docs/roadmap.md`.

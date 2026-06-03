# Delivery Roadmap

Foundation-first ([ADR-0002](./decisions/0002-foundation-first-delivery.md)),
targeting an early-July v1. Each milestone ends in something demoable; we cut
scope, not robustness. Sequence is dependency-ordered, not date-padded.

## M0 — Foundation ✅ (in progress)

- [x] Repo scaffold, monorepo layout, `.gitignore`
- [x] Decision records (ADR 0001–0006)
- [x] Open-source + competitive research dossier + buy/build/reuse matrix
- [x] Architecture overview + system diagram
- [x] `FungibleCore` Swift package: domain model, protocol seams, and tested
      logic (math, sync `LocalOnly`, guidance rules, cut/fill, entitlements)
- [x] CI building/testing the core on every push
- [ ] Xcode app target wired to `FungibleCore` (created on macOS)

## M1 — Capture loop (single scan, on device)

The first thing a user sees work. Depends on M0. **App-layer scaffolding is
committed** (`apps/ios/FungibleApp`: ARKit session, Metal unprojection shader,
CPU unprojector on the tested core, guidance overlay, auto-save, XcodeGen spec);
remaining work is building/validating it in Xcode on a LiDAR device and adding
the live Metal point-cloud preview.

- ARKit session: `smoothedSceneDepth` + `confidenceMap` + `ARMeshAnchor`
- Metal unproject → confidence/range-filtered points → bounded accumulation
  buffer (voxel dedup); copy depth/confidence out of `ARFrame` immediately
- Live SceneKit/Metal preview of the growing cloud
- `RuleBasedGuidanceEngine` wired to live `CaptureSignals` (motion/lighting/
  confidence prompts on screen)
- Auto-save one finalized scan to the local store (chunked binary)
- **Demo:** walk a space, watch the cloud build with live coaching, scan saved.

## M2 — Storage + export (make a scan useful elsewhere)

- Finalize capture chunks → **COPC/LAZ** on device (`copc-lib`/`las-rs` bridge)
- Concrete `ScanStore` (catalog via Automerge doc + content-addressed blobs)
- Export **LAZ + E57 + PLY**; share sheet
- **Demo:** scan → export LAZ/E57 → open in CloudCompare/ReCap.

## M3 — No-ceiling multi-scan registration (the first moat)

The headline differentiator. Highest technical risk → time-boxed spike first.

- Bridge **small_gicp** (fine) + **TEASER++** (coarse) + **GTSAM** (pose graph)
- `Registrar`: incremental scan-to-submap registration as a background job
- Pose-graph optimization on add; loop-closure constraints (RTAB-Map-style)
- Set view: many scans merged into one cloud, reversible scan re-assign/split
- **Demo:** capture 25+ scans of a site; they auto-merge into one aligned cloud.

## M4 — Measurement + cut/fill (the second moat)

- On-cloud distance/area measurement (Metal raycast point-pick) + annotations
- `HeightGrid` DEM from a set; `CutFillEngine` against design grade / base plane
- Volume/stockpile + cut/fill report
- **Demo:** measure a graded area; get cut/fill volumes a landscaper can quote.

Landed (CI-tested): `CutFillEngine` (volume math), `Contours` (marching-squares
topo from the DEM), and a pure-Swift `DXFExporter` (LINE/POINT/TEXT, survey
plan-view mapping) — the civil-export path consumer scanners skip. Remaining:
the on-cloud measurement UI and wiring DEM→contours→DXF in the app.

## M5 — Sync + sharing (opt-in, pluggable)

- One cloud `SyncProvider` driver behind the existing interface (likely hosted
  S3/R2 via background resumable upload, or iCloud first)
- Web viewer: **Potree** share link from a tiled (PDAL→COPC) upload
- **Demo:** scan on phone → open shareable web link on desktop.

## M6 — Pro export + polish → TestFlight → App Store

- Civil exports the consumer apps skip: **DXF / LandXML / IFC** (server-side)
- Georeferencing path (GPS + GCP constraints; RTK optional)
- Onboarding, empty states, error handling, entitlement gating verified open
- TestFlight beta during the gap, then submit.

## Parallelizable tracks

- **Cloud worker** (`services/worker`) — **skeleton committed**: pure, CI-tested
  PDAL pipeline builders (to-COPC, to-DEM, reproject) + CLI; native PDAL/GDAL
  execution wired but run server-side. Next: wire to storage + a job queue.
- **Web viewer** (`web/viewer`) — **skeleton committed**: Vite/TS/three.js points
  renderer + CI (typecheck + vitest). Next: swap in the COPC/Potree streaming
  loader and measurement tools.
- **Photogrammetry/splat** complement (COLMAP/gsplat, cloud) is post-v1.

## Risk register (tracked)

| Risk | Mitigation |
| --- | --- |
| Incremental registration drift/accuracy on large sets | Spike M3 early; pose-graph + loop closure; offload heavy global re-opt to cloud worker |
| On-device GTSAM/C++ binary size | Measure in M3 spike; fall back to cloud re-optimization if needed |
| Background upload reliability for multi-GB files | COPC to shrink; multipart/tus resume; persist transfer state |
| Export fidelity (survey-grade) | Server-side PDAL validation of LAS 1.4 / E57 / COPC |
| Incumbent-exit premise wrong ([ADR-0006](./decisions/0006-positioning-on-whitespace-not-timing.md)) | Position on whitespace, not timing; confirm intel with founder |

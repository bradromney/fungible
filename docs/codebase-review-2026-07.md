# Codebase review — July 2026

A full-stack diagnosis of Fungible (core package, iOS app, cloud worker, API,
web viewer, docs/CI), plus twelve prioritized ideas. Produced from a deep-dive
audit of every subsystem; all runnable test suites were executed as part of it.

## Verdict in one paragraph

Fungible is a genuinely well-engineered *skeleton with working baselines*:
disciplined layering, honest comments, oracle-style tests, and every risky
choice written down as an ADR. The measurement/earthwork math (the moat) is
real and correct. But the three things the product pitch depends on are still
placeholders: **registration** (the "no-ceiling" moat) initializes ICP from
identity and has no loop closure; **the end-to-end share loop** (scan → upload
→ process → link → browser) exists as four clean islands with zero connective
tissue; and **most app screens** run on synthetic data behind wireframe-faithful
UI. Nothing here is wasted work — the seams are exactly right — but the
distance from "demo" to "product" is concentrated in a small number of known,
nameable gaps.

## What's working

- **CI is green everywhere.** Verified this session: worker 18/18, viewer 11/11
  (plus clean `tsc`), API 13/13, and the GitHub `ci.yml` run on `main`
  (including the Swift core job and a macOS simulator compile of the app) is
  green.
- **FungibleCore architecture.** ~6,000 LOC, simd-free, Linux-CI-buildable,
  strict inward layering on `FungibleDomain`, protocol seams everywhere
  (`FineAligner`, `PoseGraphOptimizer`, `LoopCloser`, `SyncProvider`,
  `ScanStore`, `LLMReportGenerator`) so native engines can drop in later
  without touching callers.
- **The earthwork moat math is real.** `BestFitPlane` (correct normal-equation
  solve), `CutFillEngine` (exact oracle-tested volumes), marching-squares
  `Contours`, `HeightGrid` DEM. `RigidAlignment` is a correct, reflection-safe
  Horn quaternion solve. `ICPFineAligner` is real ICP with a spatial-hash
  nearest-neighbor index that soundly avoids O(n·m).
- **Exporters are spec-verified, not smoke-tested.** PLY (ascii+binary), XYZ,
  LAS 1.2 (round-trip decoded in tests, correct survey axis remap), DXF R12,
  OBJ, glTF 2.0 (decoded and byte-length-checked).
- **The single-scan capture loop in the app is genuinely wired.** Real
  `ARWorldTrackingConfiguration` with scene depth → immediate Sendable frame
  snapshot → CPU unprojection through the tested core `Unprojection` →
  `VoxelAccumulator` → blob write → `ScanSet` persisted via `FileScanStore`.
  Live guidance (`RuleBasedGuidanceEngine`) runs during capture.
- **The offline Metal orbit renderer works** (real pipeline, depth testing,
  orbit/pinch gestures, height-ramp coloring) and is on-demand-drawn.
- **Persistence round-trips.** ADR-0009 landed: editor screens mutate domain
  objects through `ProjectsViewModel.update` → `store.save`; content-addressed
  blobs, atomic writes, mark-and-sweep GC, tolerant field-level Codable.
- **Test discipline.** ~168 core test functions, property/recovery style
  (synthesize transform → assert recovery), exact volume oracles, an
  end-to-end pipeline integration test.
- **Docs discipline.** Ten ADRs, a candid roadmap, a real license gate for a
  commercial binary, and a researched buy/build/reuse matrix. The code's
  comments are honest about what's stubbed — rare and valuable.
- **A smart AI pattern.** `services/api`'s `/report` endpoint calls Claude with
  a facts-only prompt and *always* falls back to the deterministic
  `ReportComposer` summary — AI as enhancement, not dependency.

## What's not working

### The registration moat is a placeholder (highest-stakes gap)
- `PassthroughCoarseAligner` returns identity, so **ICP always starts from
  identity** — the ARKit world-pose prior the comments invoke is never
  threaded in (`IncrementalRegistrar.swift:42-45`). Real inter-scan motion
  will diverge.
- `ChainPoseGraphOptimizer` is a BFS spanning-tree composition, **not
  optimization**: redundant constraints, information weights, and loop-closure
  edges are silently ignored. No `LoopCloser` implementation exists. Drift
  accumulates linearly, forever.
- `SubmapSelector` is dead code — never wired into the registrar, so
  "scan-to-submap" is actually "scan-to-previous".
- ICP is point-to-point (comment promises point-to-plane), has no outlier
  rejection, and returns a stale `inlierRMSE` (computed one iteration behind
  the returned transform, `ICPFineAligner.swift:53-58`).
- The app never imports `FungibleRegistration` at all: `finishScan` hardcodes
  `pose: .identity, status: .registered`.

### The platform is four islands with no bridges
- **iOS → API:** the only `SyncProvider` is a local no-op; zero network calls
  exist in the app. Share links are locally fabricated strings
  (`share.fungible.app/<slug>-<random>`) that resolve to nothing.
- **API → worker:** blobs land in R2 but nothing ever triggers processing; the
  worker has no queue consumer, no R2 I/O, no container image — it's a pure
  pipeline-builder library plus a 10-line `pdal.execute()` never run in CI.
- **Worker → viewer:** outputs go to a local `out_dir`; the viewer's
  `ScanManifest` contract has no implementation behind it and doesn't match
  the API's `SetRecord`.
- **API auth: none.** Anyone can create sets, mint share tokens, and PUT/GET
  arbitrary R2 blobs via `/blobs/:key`. Blocking for any real deployment.
- **Format mismatch at every hop:** iOS produces LAS 1.2, the store uses a
  custom FPC1 codec, the docs' central bet is COPC, and the viewer can only
  whole-file-load LAS/LAZ.

### App screens are wireframes on synthetic data
- Export runs a fake progress spinner; no `FungibleExport` writer or share
  sheet is wired despite all six writers existing in core.
- Cut/Fill integrates a synthetic sine terrain, not the captured cloud.
  Measure/Annotate and ROI map 2D taps through a hardcoded `scale = 0.012`
  instead of picking against the real cloud. Settings buttons are empty
  closures.
- The Metal GPU unprojection kernel (`PointCloudUnprojector.metal`) is
  complete but **orphaned** — nothing dispatches it; capture is CPU-only, and
  there is no live cloud preview during capture (passthrough camera only).
- Not TestFlight-able: no committed Info.plist/entitlements/asset
  catalog/icon/signing; the ARKit axis-flip math is marked "verify on device"
  and never has been.

### Latent correctness bugs (silent-wrong-answer class)
1. `CutFillEngine` grid-to-grid compare validates dims/cellSize but **not
   grid origins** (`CutFill.swift:97-101`) — two DEMs built from different
   point sets will generally have different origins and produce silently
   wrong volumes.
2. FNV-1a-64 content hashing: a collision makes `FileScanStore.writeBlob`
   skip the write and silently serve the wrong points. The SHA-256 swap is
   planned but not done.
3. `PointCloudCodec` never checks its own version field — a future v2 blob
   would mis-decode rather than reject.
4. `FileScanStore.loadSets`: one corrupt catalog JSON aborts loading the
   entire library.
5. LAS export carries no VLR/GeoKeys, so `ScanSet.crs` never reaches the
   file — exports are not georeferenced even when an anchor exists.
6. Contours: saddle cells are connected "in encounter order" (topologically
   wrong) and segments are never stitched into polylines.

### Process gaps
- No linting (SwiftLint/ESLint/ruff), no coverage, no strict-concurrency
  enforcement in Package.swift (safety is manual `Sendable` annotation), no
  dependency caching, `npm install` instead of `npm ci`, and the worker's
  actual PDAL execution path has zero CI coverage.
- Doc drift: the ADR index omits 0009/0010; the architecture doc lists a
  `FungibleRendering` core module that doesn't exist and omits
  `FungibleInsights`/`FungiblePresentation`, which do; `Registrar.swift` and
  the app README make claims (point-to-plane, "Metal pipeline wrapper") the
  code contradicts.

## Twelve ideas to make it amazing

Ordered roughly by leverage. 1–6 make the existing promises true; 7–12 push
past them.

1. **Thread the ARKit pose prior into registration.** Replace
   `PassthroughCoarseAligner` with an aligner seeded from the device's ARKit
   world pose (already available at capture time), so ICP starts near the
   truth instead of identity. Smallest change with the biggest functional
   unlock — without it, multi-scan registration cannot work on a real device.

2. **Build the real no-ceiling backend: pose-graph optimization + loop
   closure + submaps.** A pure-Swift Gauss–Newton over SE(3) (or the
   ADR-0008 profiled GTSAM bridge) replacing the BFS chain, a first
   `LoopCloser` (revisit detection via the existing spatial hash + coverage
   grid), and actually wiring `SubmapSelector` into `IncrementalRegistrar`.
   This is moat #1; today it's the emptiest claim in the product.

3. **Close the loop: scan on phone → share link in browser in 60 seconds.**
   One thin `HTTPSyncProvider` (POST /sets, upload blob, mint share token),
   the viewer resolving `/share/:token` instead of `?url=`, and the app's
   ShareWebView minting real links. Every island already has its half of the
   contract built and tested — this is connective tissue, not new invention,
   and it converts the whole repo from "demo" to "product" in one stroke.

4. **Make export real and get on TestFlight.** Wire the six existing
   `FungibleExport` writers to the export sheet with a real
   `UIActivityViewController`, and commit the missing Info.plist/entitlements/
   icon/signing config. Days of work, and the app's most credibility-critical
   fake (a progress bar that exports nothing) disappears.

5. **Dispatch the orphaned Metal kernel and render the cloud live during
   capture.** The GPU unprojection kernel is written; give it a compute
   pipeline and feed the accumulating voxel cloud into the existing renderer
   as an AR overlay. Watching the model grow as you sweep the phone is the
   single most convincing moment a scanning app can offer — and it's the
   difference between "trust me it captured" and seeing it.

6. **Real measurement and cut/fill on captured geometry.** Point picking
   against the Metal render (replacing the hardcoded `scale = 0.012` tap
   mapping), DEM built from the actual cloud instead of the sine-wave
   terrain, ROI drawn on the render and persisted, and the dead "Export DXF /
   Add to report" buttons wired to the working core code. Moat #2 becomes
   demonstrable on a real backyard.

7. **Adopt COPC as the lingua franca and make the web viewer stream.**
   Bridge `laz-rs`/`copc-rs` (per the license matrix) so the store and
   exports speak COPC/LAZ natively, then implement the viewer's already-
   specced `ScanManifest` + HTTP range-read octree streaming with LOD, EDL
   shading, and OrbitControls. One format from device to browser, shares that
   load in seconds at any cloud size — this is the "universal interop"
   differentiator made visible.

8. **A correctness-hardening sprint on the silent-wrong-answer bugs.** Fix
   the CutFill origin check (+ a test with differently-originated DEMs),
   SHA-256 content hashing, codec version enforcement, per-file-tolerant
   `loadSets`, the ICP RMSE off-by-one, LAS GeoKey VLRs from `ScanSet.crs`,
   and contour saddle/stitching. Then turn on `StrictConcurrency` in
   Package.swift so `Sendable` is enforced, not hoped. Cheap insurance for a
   measurement product whose entire value is "the numbers are right."

9. **Turn the worker into an actual service.** A container image with pinned
   PDAL/GDAL, a Cloudflare Queues consumer deserializing the existing
   `ProcessRequest`, R2 get/put around the pipelines, status write-back to
   D1, and one CI integration test that runs PDAL on a fixture cloud (the
   execution path currently has zero coverage). The manifest was explicitly
   designed to ride a queue — give it one.

10. **Auth and scoped access on the API.** Per-device keys or signed upload
    URLs, set ownership, share-token expiry/revocation (the iOS UI already
    collects expiry and silently drops it), and locking down `/blobs/:key`.
    Unblocking prerequisite for shipping anything from ideas 3, 7, or 9.

11. **Make guided capture feel magical.** The `CoverageGrid` engine already
    computes coverage and gap directions — project it as a live heatmap on
    the AR view with directional arrows and a per-scan quality score in the
    handoff screen. "You can't scan wrong" is the strongest wedge against
    incumbents whose captures fail silently, and it's the launch vertical's
    field-usability story.

12. **Mesh + texture → USDZ/AR Quick Look, and lean into AI site reports.**
    ADR-0007 flags meshing/texturing as the top capability gap: a TSDF or
    Poisson reconstruction (server-side Open3D per the license matrix, seam
    already exists) feeding the existing OBJ/glTF exporters plus USDZ output
    means "scan a room, text someone a model they can stand inside in AR."
    Pair it with the already-well-designed LLM report endpoint (wire
    `LLMReportGenerator` to `/report`, add photos, export a shareable PDF)
    and Fungible's deliverable becomes insight, not just points.

## Suggested sequencing

- **Now (make the demo honest):** 4, 8, and doc-drift cleanup — small, high
  credibility.
- **Next (make the product true):** 1 → 2 on device, 5, 6 — the two moats
  become real.
- **Then (make it a platform):** 10 → 3 → 9 → 7 — the share loop, secured,
  streaming.
- **Amaze (make it unforgettable):** 11, 12.

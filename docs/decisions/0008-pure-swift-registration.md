# 0008 — Pure-Swift registration for v1; GICP is a profiled drop-in

- **Status:** Accepted
- **Date:** 2026-06-04
- **Deciders:** Founder + engineering

## Context

On-device speed/efficiency matters. The question: implement multi-scan
registration in **pure Swift**, or bridge the C++ **GICP** library
(`small_gicp`)? Key facts:

- The language is **not** the dominant cost. Swift compiles via LLVM and, with
  `simd` + good data structures, runs within a small factor of C++ for this math.
- The real costs are the **nearest-neighbor search** (must be indexed, not
  brute-force) and the **ICP variant** (point-to-plane > point-to-point).
- Registration is **not a 60fps operation.** The real-time path (depth→points)
  is already GPU/Metal. Registration runs as a **background job on scan-finalize**,
  on **voxel-downsampled** clouds (tens of thousands of points), with a generous
  time budget. Heavy global re-optimization offloads to the cloud worker.

## Decision

Implement registration in **pure Swift** for v1: `RigidAlignment` (Horn's
quaternion method, power-iteration eigenvector — no SVD/Accelerate) + an ICP loop
+ a **voxel-hash spatial index** for nearest-neighbor, on downsampled clouds, as
a background task. Keep everything behind the `CoarseAligner`/`FineAligner`
protocols so **`small_gicp` (C++) is a drop-in swap** — chosen *if and only if*
on-device profiling shows Swift can't hit the latency target **or** registration
quality on real scans is inadequate (GICP's covariance model aligns noisy LiDAR
better).

## Consequences

- ✅ No FFI / build-system / binary-size / device-toolchain cost for v1; the
  whole engine builds and unit-tests on Linux CI.
- ✅ The performance fix is the **spatial index**, not the language — addressed
  directly (`SpatialHashGrid`).
- ✅ The GICP escape hatch is isolated to one protocol conformance.
- ⚠️ Decide GICP with **measured device numbers**, not speculation. Add an
  on-device registration benchmark when M1 runs.
- ⚠️ Point-to-plane (needs per-point normals) is a follow-up to the initial
  point-to-point ICP; both are pure Swift.

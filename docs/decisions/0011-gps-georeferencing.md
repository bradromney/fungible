# 0011 — Per-scan GPS capture and coarse georeferencing

- **Status:** Accepted
- **Date:** 2026-07-02
- **Deciders:** Founder + engineering
- **Refines:** ADR-0007 (interop/export), the M6 georeferencing roadmap item

## Context

Scans were captured in a purely local frame — no real-world position — so an
exported cloud couldn't be placed on a map, aligned to a survey, or reprojected
into a CRS. The domain had `CoordinateReference` and an `anchored(...)` helper,
but nothing fed it: no location was ever captured.

Two honesty constraints shape the design:

1. **Phone GNSS is ±3–5 m** — tagging / coarse-georeferencing grade, not survey
   grade. We must store accuracy and never imply survey precision.
2. **Grid projection (lat/lon → UTM/State Plane meters) needs PROJ**, which is a
   server concern (the worker already has a `reproject` pipeline). On-device we
   should do only what we can do exactly.

## Decision

Capture a GPS fix per scan and derive a coarse georeference; leave projection to
the worker.

- **`GeoFix`** (new domain type) on `Scan.geoFix` — WGS84 lat/lon/alt, horizontal
  and vertical accuracy, optional true-north heading, timestamp. Optional and
  tolerant-decoded, so scans without a fix (or written before this) load fine.
- **`Geodesy`** (pure, tested) — the parts we can do honestly on-device: UTM zone
  and EPSG from lat/lon (exact), and a metric ENU offset between two fixes
  (equirectangular, <1% over a site). No projection library.
- **`CoordinateReference.geoAnchor`** — the WGS84 fix the local origin sits at.
  With the origin's real-world position plus the target `epsg`, the worker has
  everything to project without any on-device grid math.
- **`ScanSet.deriveGeoreference()`** — anchors to the FIRST pass's fix (the origin
  pass is at identity, so exact); else the most accurate fix (within GPS error).
  Names the UTM zone. Runs on each pass finalize.
- **North-aligned world frame** — capture runs ARKit with
  `worldAlignment = .gravityAndHeading`, so the scan frame's axes are already
  true-north (given location permission). That collapses the "rotate to north"
  refinement `Georeferencing.swift` deferred into a pure translation — the anchor
  alone georeferences the cloud. ARKit falls back to gravity-only without heading.
- **Opt-in, non-blocking** — location is requested once when capture opens; a fix
  is grabbed with a ~2 s cap at finalize. Declining or a slow fix never blocks a
  pass; the project is simply ungeoreferenced.

## Consequences

- ✅ Exports can be georeferenced: the CRS carries a real-world anchor + target
  grid, and the worker's reproject pipeline finishes the job.
- ✅ Honest about precision — accuracy is a first-class field; this is tagging /
  coarse georef, and the UI/consumers must present it as such (never survey grade).
- ✅ No new native dependency on-device; projection stays server-side where PROJ
  already lives.
- ⚠️ Heading alignment needs location permission and a clear-sky-ish environment;
  indoors it degrades to gravity-only and the north claim doesn't hold — the
  anchor still tags position, just not orientation. GCP/RTK-grade georef (survey
  control points, external receivers) remains a separate, later capability.
- 🔭 A per-scan-fix least-squares fit (using ENU offsets across several passes to
  refine the anchor and detect GPS outliers) is a natural follow-up on top of the
  `Geodesy.enu` primitive.

# 0007 — A general capture + interop platform; verticals sit on top

- **Status:** Accepted
- **Date:** 2026-06-04
- **Deciders:** Founder + engineering
- **Refines:** ADR-0006 (positioning), the competitive/research framing

## Context

Earlier docs leaned hard on **landscaping / earthwork** as the differentiator.
That's a current focus and a strong wedge — but it is **one vertical, not the
boundary of the product**. The founder is equally interested in:

- **Building / remodel / construction (AEC)** — as-builts, interiors, renovation
  scope, scan-to-CAD/BIM.
- **General 3D modeling** — producing usable meshes/models (not just point
  clouds) for visualization, games, design, AR.
- **File translation / interop** — moving between the many point-cloud and mesh
  formats reliably. This is a real, underserved pain point and a first-class
  value proposition in its own right, not merely an "export" feature.

## Decision

Position Fungible as a **general LiDAR / 3D capture, processing, and interop
platform.** Keep the **core capabilities market-agnostic** — capture,
registration, measurement, rendering, and format I/O serve every vertical — and
treat market-specific features as **modules layered on the same core**:

- Landscaping/site: earthwork cut/fill, contours, grading, georeferencing.
- AEC/remodel: RoomPlan/wall extraction, IFC/BIM, RCP-style CAD handoff,
  as-built measurement.
- General 3D: mesh reconstruction + texturing, OBJ/glTF/USDZ output, AR Quick
  Look.
- Interop: a broad, reliable **format translation hub** (point *and* mesh):
  LAS/LAZ/E57/PLY/XYZ/PTS/COPC ⇄ DXF/OBJ/glTF/USDZ — on-device for the common
  cases, via the PDAL/Assimp cloud worker for the long tail.

Landscaping is the **launch vertical** (sharp, underserved, demoable), not the
ceiling.

## Consequences

- ✅ Bigger addressable market; the same engine monetizes across AEC, 3D, and
  interop users.
- ✅ Interop becomes a headline pillar — it's broadly useful and we already have
  most of the machinery (on-device LAS/PLY/XYZ/DXF + the PDAL worker).
- ⚠️ Don't hard-code landscaping assumptions into core types (e.g. don't assume
  "ground/grade" everywhere; keep measurement/export general). Vertical logic
  stays in its own module.
- ⚠️ **Mesh output (OBJ/glTF/USDZ) and texturing rise in priority** — general 3D
  modeling and AEC both need meshes, not just points. Currently we export point
  formats well; meshing is the next capability gap to close.
- 🔭 Revisit the competitive doc's "earthwork is the moat" emphasis: earthwork is
  *a* moat; **breadth of capture + interop across verticals** is the platform play.

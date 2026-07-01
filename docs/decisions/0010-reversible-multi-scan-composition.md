# 0010 — Reversible multi-scan composition (hide / exclude / split)

- **Status:** Accepted
- **Date:** 2026-06-24
- **Deciders:** Founder + engineering
- **Refines:** ADR-0005 (no scan-count ceiling), ADR-0008 (pure-Swift registration)

## Context

The product promise is "one project, keep scanning, no ceiling" (ADR-0005). The
registration engine already supports that — each scan is registered against the
existing set incrementally, and the combined cloud is composed **lazily at
read/export time** by applying each scan's optimized pose (`ScanSetAssembler`),
never baked into a single irreversible blob. Per-scan blobs and poses are
retained.

Field use (and the SiteScape comparison) surfaced a missing capability on top of
that: a user needs to **curate** a multi-scan project — hide a bad pass, exclude
it from the export, or split some scans into their own project — the way
CloudCompare lets you show/hide/merge clouds. Because our scans stay separate,
this is a data-model gap, not an algorithm gap. Nothing in the model expressed
"this scan is currently excluded."

## Decision

Model project curation as **reversible visibility over retained scans**, not as
destructive edits:

- `ScanSet.hiddenScans: Set<ScanID>` — the scans the user has excluded. Hiding is
  non-destructive: the blob and pose stay; only membership in the *visible* set
  changes.
- `ScanSet.visibleScans` is the composition everything works from — registration,
  rendering, and export all consume the visible set. `ScanSetAssembler` unions
  the visible scans by default (`includeHidden: true` overrides for a full merge).
- `setScan(_:hidden:)` / `isVisible(_:)` are the reversible toggles.
- `split(scanIDs:name:)` extracts a subset into a **new** project, carrying each
  scan's pose (so it stands alone) and any pose-graph edges wholly inside the
  subset. The original is left intact; the caller decides whether to also hide
  the moved scans.
- The new field decodes with a default of `[]` (tolerant decode, per ADR-0009), so
  an older catalog still loads.

### Export provenance (planned follow-up)

To let *external* tools (CloudCompare, ReCap) unmerge a single exported file, the
assembler will stamp each point with its source scan via the LAS **point source
ID** field (LAS already reserves it for exactly this). That makes an exported
merge splittable outside our app too — tracked separately from this ADR.

## Consequences

- ✅ "Merge 5 scans, then cheaply unmerge/hide one" is native: composition is from
  the visible set, so hiding is O(1) metadata and re-export is automatic. No
  recompute, no lost data.
- ✅ Split/curate without leaving the no-ceiling model — the engine still registers
  incrementally against the visible set.
- ✅ Reversible by construction; a hidden scan is one toggle away from returning.
- ⚠️ Re-registration semantics after hiding are deferred: if hiding a scan removes
  overlap that others were aligned through, their poses may want re-optimizing.
  The cheap `ChainPoseGraphOptimizer` can re-run on the visible sub-graph; doing
  that automatically on hide is a follow-up (needs the M3 registration wiring).
- 🔭 True incremental de-optimization and loop-closure-aware removal wait on the
  GTSAM iSAM2 bridge (ADR-0008's drop-in path); the visibility model is designed
  to sit cleanly on top of it.

# 0005 — No scan-count ceiling via incremental registration

- **Status:** Accepted
- **Date:** 2026-06-03
- **Deciders:** Founder + engineering

## Context

The incumbent caps a set at ~10 scans. We believe this is a consequence of a
batch architecture: all scans in a set are registered together in one
(expensive, memory-heavy) pass, so the count must be bounded. This is a top
user pain point and a clear differentiation opportunity.

## Decision

Treat a "set" as an **incrementally grown** point cloud, not a fixed batch:

1. Every scan is **auto-saved** the moment it completes — the user can scan
   continuously without a save step.
2. Each new scan is registered **against the existing aggregated set** (or a
   relevant neighborhood of it), not against all prior scans pairwise.
3. Registration runs as a background job with a **pose graph** that can be
   refined/loop-closed over time, so accuracy improves without re-doing
   everything.
4. The app **signals** its automatic decisions (e.g. "added to current set",
   "this looks like a new area") and lets the user override, without *requiring*
   them to manage it.

## Consequences

- ✅ Removes the headline limitation of the incumbent; "scan, scan, scan" UX.
- ✅ Incremental + pose-graph keeps per-scan cost roughly constant instead of
   growing with set size.
- ⚠️ Incremental registration must handle drift and loop closure or large sets
   will warp. This is the core technical risk; the research pass is mapping the
   open-source options (Open3D, pose-graph/GTSAM-style optimization, ICP
   variants) before we commit an approach.
- ⚠️ Auto-save + auto-set-assignment needs a clear, reversible UX so the app's
   guesses never trap the user. Errors must be cheap to undo (re-assign a scan
   to a different set, split/merge sets).

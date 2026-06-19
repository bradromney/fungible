# 0009 — Persisting UI-authored project state

- **Status:** Accepted
- **Date:** 2026-06-19
- **Deciders:** Founder + engineering
- **Refines:** ADR-0003 (local-first, pluggable sync), ADR-0007 (multi-market core)

## Context

The wireframe build-out (screens 01–11) stood up the full UI, but every screen
that *authors* data did so into SwiftUI `@State` that evaporates when the view
goes away:

- **Measure / Annotate** (04) recorded measurements and pins to local session
  state only — `MeasureAnnotateView.save()` bumped a counter and reset.
- **Cut/Fill** (06) computed a real `volumeCutFill` result but never stored it.
- **Project type** (03/11) — Site / Interior / Object — lived as `@State` on
  `ProjectDetailView`; reopening the project reset it.
- **Share to web** (09) — the access toggles and chosen expiry were transient.

Meanwhile the persistence machinery already existed: `ScanSet` carries
`measurements` / `annotations`, and `ScanStore` already exposes
`save(_:)` / `loadSets()`. The gap was twofold:

1. **No domain home** for three things the UI authored — project *type*,
   annotation *category*, and share *intent*. These lived as display-only enums
   in `FungiblePresentation` with an explicit "promote to the domain model in
   its own ADR" TODO (`ProjectPresentation.swift`).
2. **No app-side bridge** that mutated a `ScanSet` and wrote it back through the
   store. The screens held value-copies of `ScanSet` and dropped their edits.

## Decision

**The `ScanStore` is the single source of truth for project state; the UI mutates
a `ScanSet` and writes it straight back.** Concretely:

### 1. Promote UI-authored facts onto the domain model

Move the *data* (not the display strings) into `FungibleDomain` so it can be
persisted and CI-tested:

- `ProjectType` (`site` / `interior` / `object`, plus the `detect(bounds:)`
  heuristic) → `FungibleDomain`; `ScanSet.type` now stores it.
- `AnnotationCategory` (`issue` / `todo` / `note` / `spec`) → `FungibleDomain`;
  `Annotation.category` now stores it.
- `ShareSettings` (enabled, allow-download, expiry, minted link slug) → a new
  value on `ScanSet.share`.

The **display mappings stay in `FungiblePresentation`** as extensions
(`chipLabel`, `factLabels`, `symbolName`, …). Data lives in the device-independent
core; vocabulary lives in the presentation layer. This keeps the module layering
acyclic (`FungiblePresentation → FungibleDomain`, never the reverse) and honours
the golden rule.

### 2. Schema evolution is tolerant by construction

The new fields decode with defaults (`type → .site`, `category → .note`,
`share → disabled`) via hand-written `init(from:)`, so a `ScanSet` written by an
older build still loads. Persistence must never hard-fail on a missing key.

### 3. Mutation primitives on the model, a thin view-model on top

`ScanSet` gains pure `mutating` helpers (`upsert(_:)` / `removeMeasurement(_:)` /
`upsert(_ annotation:)` / `removeAnnotation(_:)`) — small, CI-tested, the verified
core of "edit a project". The app's `ProjectsViewModel` mutates the in-memory set
through these and calls `store.save(_:)`; the editor screens (Measure, Cut/Fill,
Share, the type menu) hand their results back via callbacks rather than owning
state.

### 4. What does *not* move

- **Sync posture** (`SyncState`) stays a runtime concern owned by the
  `SyncProvider` (ADR-0003) — it is derived, not authored, so it is not stored on
  `ScanSet`.
- **Live share facts** — hosted view count, server-side expiry enforcement, the
  real minted URL — belong to the share/hosting provider. `ShareSettings` persists
  only the user's *intent* so the toggles survive a reopen.
- **Annotation photos** — deferred until capture/asset storage lands; the field
  can join `Annotation` the same tolerant way.

## Consequences

- ✅ Edits survive: measurements, pins, type, and share intent round-trip through
  the local-first store. The screens become functional, not just presentational.
- ✅ The "promote these enums (ADR follow-up)" debt in `FungiblePresentation` is
  paid; the data/vocabulary split is now explicit and enforced by module layering.
- ✅ Forward/backward-compatible decoding means the on-disk catalog can evolve
  without a migration for additive fields.
- ⚠️ `ProjectDetailView` now reads its `ScanSet` from the view-model (so it
  reflects saved edits) rather than holding a static copy — a small ownership
  shift the editor screens follow.
- 🔭 The same tolerant-decode pattern is the template for the next authored
  fields (annotation photos, per-measurement labels/styles, CRS chosen in-app).

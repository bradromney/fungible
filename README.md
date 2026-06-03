# Fungible

> Working codename. A modern, iOS-native LiDAR scanning app for construction,
> landscaping, and site planning — capturing real-world spaces as point clouds
> ("dot maps") so professionals can measure, annotate, and plan changes.

Built to step in as the incumbent ([SiteScape](https://www.sitescape.ai/)) winds
down. The thesis: the hard parts (real-time capture, multi-scan registration,
large-cloud performance, pro-grade export) are solvable with today's open-source
stack, and the real wedge is **a frictionless, guided capture experience with no
artificial scan limits.**

## Status

🚧 Early foundation (milestone M0). The device-independent core
([`apps/ios/FungibleCore`](./apps/ios/FungibleCore)) has a tested domain model,
the cut/fill and guidance engines, and the sync/registration seams; the ARKit +
Metal app target and the multi-scan pipeline come next. See:

- [Roadmap](./docs/roadmap.md) — milestones M0→M6 to a v1
- [Architecture](./docs/architecture/overview.md) — how it fits together
- [Decisions](./docs/decisions) — why the stack looks the way it does
- [Research](./docs/research) — OSS landscape + buy/build/reuse matrix
- [Third-party licenses](./docs/third-party-licenses.md) — what we may ship
- [Development setup](./docs/development.md) — build/test each tier
- [`CLAUDE.md`](./CLAUDE.md) — orientation for AI/dev sessions

This repo is a monorepo:

```
apps/ios/      # The iOS capture app (Swift / ARKit / Metal)         — primary
web/           # Web point-cloud viewer for sharing & desktop planning — later
services/      # Cloud workers (registration, tiling, export)         — later
docs/          # Architecture, decision records (ADRs), research
```

## Product pillars

1. **Guided capture** — robust, in-app, real-time guidance so a first-timer gets
   a usable scan. Coverage gaps, motion, lighting, and "you missed this" prompts.
2. **No scan ceiling** — auto-save every scan; incremental registration instead
   of a fixed 10-per-set batch. Scan, scan, scan — the app figures out the set.
3. **Local-first, sync-optional** — scans live on-device and stay usable offline;
   cloud backup and sharing are opt-in via a pluggable storage layer.
4. **Pro-grade export** — the formats surveyors, CAD, and BIM actually ingest
   (LAS/LAZ, E57, and friends).

## Key decisions

The foundational choices and their rationale live as Architecture Decision
Records in [`docs/decisions/`](./docs/decisions). Start there to understand why
the stack looks the way it does.

## Development

The iOS app must be built and run from **Xcode on macOS** with a LiDAR-equipped
device (iPhone 12 Pro or later / iPad Pro 2020 or later). This repository can be
developed on any platform, but device testing requires Apple hardware.

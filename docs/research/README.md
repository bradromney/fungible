# Research Dossier

A snapshot of the open-source and competitive landscape that informs Fungible's
architecture, captured **June 2026** from a five-track parallel research sweep.
Treat star counts, versions, and "actively maintained" notes as point-in-time.

## Contents

- [`open-source-components.md`](./open-source-components.md) — every viable OSS
  library/component by capability area, with **license**, maturity, and
  iOS-integration notes. Licenses are flagged for commercial-iOS risk.
- [`competitive-landscape.md`](./competitive-landscape.md) — incumbents and
  adjacent apps, what they export, pricing, and the gaps a new entrant can take.
- [`buy-build-reuse-matrix.md`](./buy-build-reuse-matrix.md) — the decision:
  each capability → reuse / build / server-side, with the chosen option and why.

## ⚠️ Premise check: is SiteScape actually shutting down?

**Not publicly confirmable** as of June 2026. Findings:

- SiteScape was acquired by **FARO Technologies on 2022-12-01** — an old
  acquisition, not a recent one. It's now "SiteScape by FARO," tied into FARO
  Sphere XG / HoloBuilder.
- It is **still actively maintained**: 2024–2025 updates include RCP export,
  HD photo annotations, and iPhone 15 Pro support. No public discontinuation
  notice was found.
- The "**10 scans**" limit is the Pro **Multi-Scan** feature (merge up to 10
  back-to-back scans into one model), i.e. a merge cap on a paid feature — not a
  free-tier scan quota.
- SiteScape's actual export set: **E57, PLY, RCP** (ReCap → Revit/AutoCAD).
  Pricing: free tier (one cloud-synced scan at a time) vs Pro (~$50/mo).

**Implication.** The founder may hold private information about a sunset that
isn't public; this dossier does not contradict that. But the go-to-market should
**not depend on the incumbent disappearing.** It should stand on the
differentiation in [`competitive-landscape.md`](./competitive-landscape.md):
mobile earthwork/cut-fill, civil/survey export, outdoor-tuned scan guidance, and
no-scan-ceiling capture — none of which any incumbent does well. This is recorded
as a risk in [ADR-0006](../decisions/0006-positioning-on-whitespace-not-timing.md).

## How the research was run

Five parallel agents, each fetching and citing primary sources (GitHub LICENSE
files, Apple docs, product pages, papers):

1. iOS LiDAR capture + on-device rendering
2. Multi-scan registration / SLAM + scan-quality guidance
3. Point-cloud formats / compression / tiling + cloud sync architecture
4. Web point-cloud viewers + photogrammetry/NeRF/Gaussian-splatting
5. Measurement / volume / CAD-BIM export + competitive landscape

Full source URLs are inline in each document.

# 0006 — Position on whitespace, not on the incumbent's exit

- **Status:** Accepted
- **Date:** 2026-06-03
- **Deciders:** Founder + engineering
- **Supersedes/Refines:** the go-to-market framing implied in ADR-0002

## Context

The project was kicked off on the premise that SiteScape (the incumbent) "just
got acquired and is shutting down at the end of the month," creating a timing
window to replace it. The research pass could **not** verify this:

- SiteScape was acquired by **FARO in December 2022** — not a recent event.
- It is **still actively maintained** in 2026 (RCP export, photo annotations,
  iPhone 15 Pro support); no public sunset announcement exists.
- The "10 scans" cap is the Pro **Multi-Scan** merge feature, not a free quota.

The founder may hold non-public information about a sunset, and this ADR does not
contradict that. But betting the company on a competitor disappearing — when that
can't be confirmed and may be wrong or delayed — is fragile.

## Decision

**Anchor positioning on durable differentiation, not on the incumbent's exit.**
The research identified clear, defensible whitespace that no incumbent (SiteScape,
Polycam, Scaniverse, Matterport, Pix4D) covers well:

1. Mobile **earthwork / cut-fill / stockpile volume** (no permissive mobile tool
   exists today).
2. **Civil/survey export** the consumer apps skip — LandXML, IFC4x3, contour/topo
   DXF, georeferenced SHP/GeoJSON.
3. **Outdoor/terrain-tuned scan guidance** (vs. everyone's room/object focus).
4. **No-scan-ceiling** incremental capture (ADR-0005).
5. Pricing wedge below SiteScape Pro ($50/mo) with a strong free tier.

Build the capture stack on **open SLAM** (RTAB-Map / small_gicp / GTSAM) so we
own it and depend on no incumbent's roadmap.

## Consequences

- ✅ The product stands whether or not SiteScape sunsets — resilient to a wrong
  premise.
- ✅ Focuses scarce build effort on the two moats (no-ceiling registration,
  mobile earthwork) rather than mere feature parity.
- ⚠️ "Foundation first" (ADR-0002) timing pressure is **lower** than assumed if
  the incumbent isn't leaving end-of-month — reinforces doing this right over
  rushing.
- 🔭 **Open follow-up for the founder:** confirm the shutdown intel. If firm, we
  add timing urgency on top of this positioning; if not, nothing in the build
  changes — only the marketing narrative.

# Wireframe brief (for Claude design)

A self-contained brief for fleshing out the iOS app's wireframes. It is grounded
in what already exists in this repo — the data model, the live-capture coaching
vocabulary, the export-format matrix, the entitlement seams, and the existing
SwiftUI capture screen. Design **to** these; don't invent around them.

---

You are a senior product designer. Flesh out the wireframes for an iOS-native
app whose engineering core already exists in this repo. Deliver them as clean,
low-to-mid fidelity HTML/CSS artifacts (grayscale, system font, no brand color
yet), one screen per artifact at iPhone 15 Pro size (393×852), with annotations.

## Read these first (they define the product — don't invent around them)

- `CLAUDE.md` — what the product is and who it's for.
- `docs/architecture/overview.md` — THE source of truth. Read: the data model
  (ScanSet → Scan → Measurement/Annotation), the capture→registration pipeline,
  the "Scan-quality guidance" section, "Measurement & cut/fill", and
  "Monetization seams."
- `docs/decisions/0005-no-scan-ceiling.md`, `0007-multi-market-positioning.md`,
  `0003-local-first-pluggable-sync.md`, `0004-free-mvp-monetization-ready.md`.
- `apps/ios/FungibleCore/Sources/FungibleGuidance/GuidanceEngine.swift` — the
  EXACT live-capture coaching vocabulary (`Prompt.Kind`: slowDown, moveCloser,
  improveLighting, rescanLowConfidence, fillGap [carries a direction vector for
  an on-screen arrow], coverageComplete, holdSteady). Design the overlay around
  these real states; show at most 1–2 at once.
- `apps/ios/FungibleCore/Sources/FungibleEntitlements/Entitlements.swift` — the
  real `Capability` list (exportLAZ/E57/DXF/IFC/LandXML, cutFillVolume,
  hostedStorage, byoCloud, cloudProcessing, webShare). Today ALL are on (free
  MVP); treat these as the paywall-candidate seams — mark them subtly, don't
  build a hard paywall.
- `apps/ios/FungibleApp/Sources/UI/` (`CaptureView.swift`, `GuidanceOverlay.swift`)
  — the existing, intentionally-minimal capture screen. EXTEND/refine this; don't
  reinvent it. It already has: a live point-count capsule, a status capsule, the
  guidance overlay, and a single "Finish Scan" button.

## What this app is (grounded summary)

iOS-native LiDAR capture + processing + interop platform. Walk a space → capture
it as a point cloud → measure, annotate, convert between formats, hand off to
CAD/BIM/3D. Three audiences, one market-agnostic core: AEC (build/remodel),
general 3D modeling, and site/landscaping (the launch vertical, not the limit).

Differentiators the UI must make legible:

- **No scan-count ceiling** (ADR-0005): a "project" (ScanSet) grows without
  limit by adding capture passes (Scans). The UI must NEVER imply a cap.
- **Universal interop**: "Convert/Export" is a first-class action across LAZ/COPC,
  E57, PLY, DXF, USDZ, LandXML, IFC, OBJ, glTF.
- **Guided capture**: real-time coaching (the Prompt.Kind vocabulary above).
- **Mobile cut/fill**: capture terrain → cut/fill volumes + contours on-device.
- **AI site reports** (FungibleInsights / the `/report` API): a generated,
  plain-language site summary with imperial units.

## Core mental model (match the data model exactly)

A **Project (ScanSet)** is a site that grows over time. It contains many
**Scans** (one capture pass each), stitched into one combined point cloud via a
pose graph. Each Scan has a quality report (coverage %, confidence, drift) and a
status: capturing → registering → registered → failed. Measurements and
Annotations attach to the Project, not a single Scan.

UX principle from the architecture — **"signal, don't gate":** the app surfaces
its automatic decisions ("added to current project", "looks like a new area")
and every guess is cheaply reversible (re-assign / split / merge). Avoid blocking
modals the user must manage. Registration runs in the background — show a
non-blocking "registering…" state; the project stays usable meanwhile.

## Screens to wireframe (priority order)

1. **Projects (home)** — list/grid of ScanSets: thumbnail, name, scan-pass count
   (never a limit), total point count, last-captured date, sync status. Entry to
   capture and to each project. Include the empty state ("no projects yet").
2. **Live Capture** — refine the existing screen. Full-screen AR viewfinder +
   guidance overlay driven by the real Prompt.Kind states (including the
   directional fillGap arrow), a coverage indicator scoped to a Region of
   Interest, live point count, and the capture/finish control. Show the
   "registering… (you can keep going)" non-blocking state.
3. **Project detail / 3D viewer** — orbitable combined point cloud; a list of the
   project's scan passes with per-scan status + quality, and the reversible
   re-assign/split/merge affordances. Toolbar: Measure, Annotate, Convert/Export,
   Cut/Fill (Cut/Fill appears contextually for site work, not every project),
   Share, Report. Metadata panel.
4. **Measure & Annotate** — pick points → distance / plan-area / volume; drop
   annotation pins with notes.
5. **Convert / Export** — the hero interop moment: pick target format from the
   real matrix above, options, destination (share sheet / hosted link / CAD
   handoff). Subtly badge the paywall-candidate formats.
6. **Cut/Fill (site vertical)** — set a reference/design surface (grade), show cut
   vs. fill volumes and a contour overlay with a results readout.
7. **Site Report** — the generated FungibleInsights summary (imperial units):
   key facts + narrative, with share/export.

Secondary if time allows: Region-of-Interest setup, Share (web-viewer link, the
`webShare` capability), and Settings/Account (where the entitlement seams and a
light "upgrade" affordance live — kept soft, since the MVP is free).

## What to IGNORE (engineering, not design surface — do not try to redesign)

- Backend/infra: `services/api/`, `services/worker/`, `web/viewer/` source. (Note
  the web viewer EXISTS as the share destination, but you're not designing its
  internals here — just the iOS-side "share to web" flow.)
- The Swift/Metal/registration/codec internals, ADR mechanics, CI, and license
  docs. Don't propose changes to the data model or capabilities — design TO them.

## How to work

- First propose an information architecture / nav model (tab bar vs. stack) with
  a short rationale, then ask up to 3 clarifying questions before drawing.
- Follow iOS Human Interface Guidelines: native nav, SF Symbols-style icons
  (the GuidanceOverlay already maps each prompt to an SF Symbol — reuse those),
  thumb-reachable primary actions, the standard share sheet for export.
- Annotate each screen: callouts for components, states, and interactions. Cover
  empty / loading / error states where they matter (no projects yet, capture
  interrupted / tracking lost, registering in background, format not supported).
- Grayscale only — we'll layer brand later. Prioritize layout, hierarchy, flow.
- Deliver screen 1, get a reaction, then proceed. Don't draw all seven before
  checking in.

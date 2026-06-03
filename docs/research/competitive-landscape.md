# Competitive Landscape

Captured June 2026 from product pages, App Store listings, and press. Pricing
figures are point-in-time; some vendor pages 403 automated fetches and are noted.

## Incumbent: SiteScape (by FARO)

| | |
| --- | --- |
| **Owner** | Acquired by **FARO**, 2022-12-01 ("SiteScape by FARO"; ties into Sphere XG / HoloBuilder). |
| **Status** | **Actively maintained** in 2026 (2024–25: RCP export, HD photo annotations, iPhone 15 Pro). No public sunset found. |
| **Platform / tech** | iOS only, iPhone/iPad **LiDAR** (ARKit). |
| **Exports** | **E57, PLY, RCP** (ReCap → Revit/AutoCAD). |
| **"10-scan limit"** | The Pro **Multi-Scan** feature merges up to 10 back-to-back scans into one model — a paid-feature merge cap, **not** a free quota. |
| **Pricing** | Free = unlimited local capture/export but **one cloud-synced scan at a time**; Pro ≈ **$50/mo** (~$450/yr) for Multi-Scan, larger scans, HD annotations, cloud sync. *(pricing page 403s automation — verify on-page.)* |
| **Strengths** | "Drop-dead easy" capture, real-time feedback, AEC focus, FARO ecosystem + RCP pipeline. |
| **Gaps** | No measurement/volume/cut-fill; building-interior focus (not landscaping/earthwork); cloud limited on free tier; no Android. |

> ⚠️ The "shutting down end of month" premise is **unverified** publicly — see the
> [dossier README](./README.md#️-premise-check-is-sitescape-actually-shutting-down)
> and [ADR-0006](../decisions/0006-positioning-on-whitespace-not-timing.md).

## Adjacent apps

| App | Platform / tech | Exports | Pricing | Strength → Gap |
| --- | --- | --- | --- | --- |
| **Polycam** | iOS+Android+web; LiDAR + photogrammetry + splats; floor plans | 15+: PLY/OBJ/FBX/USDZ/glTF/DAE/STL/**LAS/Geo-LAS/PTS/XYZ/DXF** | Sub ~$13–27/mo | Broadest formats/platforms, polished → no volume/cut-fill or civil (LandXML/IFC); not survey-grade by default |
| **Scaniverse** (Niantic) | iOS+Android; LiDAR + photogrammetry + **splats**; on-device | OBJ/FBX/GLB/USDZ/STL/PLY/**LAS**/SPZ | **Free** personal; biz Plus $20 / Pro $50 | Best free tier, fast on-device → consumer-leaning; no construction measurement/CAD |
| **3D Scanner App** (Laan Labs) | iOS; LiDAR + photogrammetry | OBJ/glTF/DAE/STL/USDZ; **PTS/PCD/PLY/XYZ/LAS**; floorplan **DXF** | **Free, no scan limit** | Generous free, measurement + floorplan, offline → no volume/cut-fill, no IFC/LandXML, no georef survey |
| **Pix4Dcatch** | iOS+Android; **photogrammetry+LiDAR+RTK/GNSS** (Emlid/viDoc) | **DXF, SHP**, PLY, glTF | Discovery free; paid Pix4D license | **RTK georeferencing**, survey accuracy, GIS/CAD → needs hardware/ecosystem; pricier; pro-survey UX; no turnkey cut/fill in-app |
| **Twindo** (ex-Canvas, Occipital) | iOS LiDAR; scan-to-CAD service | Scan-to-CAD → Revit/AutoCAD/SketchUp/ArchiCAD; 2D floor plans | Per-scan conversion | Human-assisted accurate as-builts → interior/AEC focus, latency/cost, not earthwork |
| **Matterport** | iOS/Android + Pro3/Pro2 HW; photogrammetry + (Pro3) LiDAR | E57/OBJ/XYZ/**RVT/DWG**/LOD200 BIM | Sub $10–69+/mo + per-export add-ons | Enterprise digital twin → phone capture is **second-class** (E57/BIM blocked w/o Pro3 HW); add-on costs stack; not earthwork |
| **RTAB-Map** | iOS app + OSS lib + ROS; LiDAR/RGB-D **SLAM** | PLY/LAS/OBJ | **Free / ✅ BSD** | **Open SLAM you can build on**, large-scale → engineer-UX, no measurement/CAD layer (reference codebase, not consumer rival) |
| **Metascan** | iOS LiDAR + photogrammetry | USDZ/OBJ/glTF/FBX/STL; **LAZ/PLY/XYZ** | Pro IAP ~$50 | All-in-one capture, AR targets → no measurement/volume/CAD-survey |

*"Tailor" in the brief appears to be an apparel body-scan app (out of scope); no
construction "Tailor" found — flag if a specific product was meant.*

## Where the whitespace is

1. **Mobile earthwork / cut-fill / stockpile volume.** *No* consumer scanner does
   it; it lives in GPL desktop (CloudCompare) and pricey civil software
   (Kubla Cubed, esurvey). A clean MIT/BSD on-device-or-fast-cloud **cut/fill +
   stockpile + design-vs-existing surface** engine is a real moat for
   landscaping/grading.
2. **Pro civil/survey export the consumer apps skip:** **LandXML** (Civil 3D),
   **IFC4x3** (infra/alignment), **contour/topo DXF**, **georeferenced SHP/GeoJSON**.
   Bridges cheap consumer scanners and expensive Pix4D/Trimble pipelines.
3. **Outdoor/terrain-tuned scan guidance.** Everyone optimizes for rooms/objects.
   Slopes, gravel, sun, featureless ground, and "you've covered enough of this
   grade" coaching is unaddressed.
4. **No-scan-ceiling capture** via incremental registration ([ADR-0005](../decisions/0005-no-scan-ceiling.md)).
5. **Georeferencing without a survey rig:** lightweight GCP/GPS-scale +
   RTK-optional, so landscapers without a $1k+ Emlid kit get "good enough" georef.
6. **Pricing wedge:** SiteScape Pro ($50/mo) and Matterport's add-on stacking
   leave room for a flat, pro-feature-inclusive tier; Scaniverse proves a strong
   free tier wins adoption.

## Strategic read

The defensible position is **"the scanner that actually finishes the job for
site/grading work"** — capture (no ceiling, guided) *plus* the measurement,
earthwork, and civil-export workflow that every consumer app stops short of, at a
landscaper-friendly price. Build the capture stack on **open SLAM (RTAB-Map/
small_gicp/GTSAM)** so we own it and don't depend on any incumbent's roadmap.

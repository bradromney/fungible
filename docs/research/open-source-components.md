# Open-Source Component Catalog

Every viable building block found, grouped by capability area. **License flags:**
✅ permissive (MIT/BSD/Apache/BSL/MPL) — safe for a closed-source commercial iOS
app · ⚠️ weak-copyleft or caveated (LGPL, dual-license, commercial-use clause) ·
🚫 strong-copyleft/non-commercial (GPL/AGPL/NC) — do **not** link into the app.

Verify any "verify" note against the repo's actual LICENSE before adopting;
captured June 2026.

---

## 1. iOS LiDAR / depth capture

| Component | License | Notes |
| --- | --- | --- |
| **Apple "Displaying a Point Cloud Using Scene Depth"** (WWDC20 sample) | ✅ Apple Sample Code | THE capture-core reference. Metal compute unprojects depth pixels → world-space points with per-point RGB + `ARConfidenceLevel`, accumulated in a persistent `MTLBuffer`, grid-sampled to bound growth. Harden a fork of this. Watch ARFrame retention (copy depth/confidence out before async work). |
| **Apple "Visualizing and Interacting with a Reconstructed Scene"** | ✅ Apple Sample Code | `sceneReconstruction = .meshWithClassification`, `ARMeshAnchor` geometry + occlusion + floor/wall/ceiling classification. Use for a meshed deliverable and coverage overlay. |
| **RealityKit Object Capture / `PhotogrammetrySession`** | Apple framework | On-device (iOS17+) / macOS photogrammetry → textured OBJ/USDZ. Object-scale, **not** site-scale; complement only. Its `ObjectCaptureSession.Feedback` enum is the gold UX reference for guidance (see §7). |
| **TokyoYoshida/ExampleOfiOSLiDAR** | ✅ MIT | Best grab-bag of technique demos: depth, confidence viz, real-time cloud, textured object scan, OBJ export. |
| **Waley-Z/ios-depth-point-cloud** | ✅ (verify exact) | Capture→export pipeline; records depth + smoothedDepth + confidence, exports full-res PLY; documents the ARFrame-retention fix. Model the save/export layer on this. |
| **cedanmisquith/SwiftUI-LiDAR** | ✅ MIT | Clean modern SwiftUI + ARKit + RealityKit mesh scan, OBJ export. Structure reference. |
| **tyang-gauntlet/LiDARKit** | ✅ MIT | Early "reusable capture framework" shape; reference architecture, not a dependency. |
| **CurvSurf/FindSurface-GUIDemo-iOS** | ⚠️ demo MIT, **engine proprietary** | Real-time plane/sphere/cylinder/cone fitting from ARKit points. Valuable for measured primitives, but the fitting **engine is a commercial CurvSurf SDK** — biggest licensing flag in capture. |
| isakdiaz/arkit-scenedepth-pointcloud, xiongyiheng/ARKit-Scanner, stevenroach7/3DScanr, zeitraumdev/iPadLIDARScanExport | verify | Smaller/older references (raw-data-out, pre-LiDAR feature points, minimal OBJ export). |

**Hardware reality:** iPhone LiDAR range ≈ 5 m (older) to ~10 m (newer Pro);
static accuracy <1 mm to plane, hand-held degrades to ~1 cm from pose drift;
field accuracy 2–5 cm. Best practice: 1–1.5 m standoff, slow small movements
(pose drift is the #1 error). Filter with `confidenceMap` + prefer
`smoothedSceneDepth`; optionally MPS joint-bilateral upsample depth with RGB.

## 2. On-device point-cloud rendering (iOS)

| Component | License | Notes |
| --- | --- | --- |
| **Apple scene-depth sample renderer** | ✅ Apple Sample | Point sprites from one persistent buffer; fine to low-millions, no LOD. |
| **SceneKit** (`SCNGeometry` point primitive) | ✅ first-party | Fastest to integrate; good for MVP preview; hits a wall in low-millions. |
| **RealityKit** | ✅ first-party | Great for mesh/AR/occlusion; **no** first-class large point-cloud rendering. |
| **Raw Metal + Potree-style octree** | — | Required for site-scale (multi-million/streamed). Build offline octree with **PotreeConverter 1.x** (✅ BSD-2); reimplement LOD/culling in Metal. |
| roberthein/Metal-Point-Cloud | ⚠️ license unspecified | Small point-sprite reference; no LOD/streaming. |
| SFraissTU/BA_PointCloud (Unity), momower1/PointCloudEngine (DX), KeKsBoTer/punctum, m-schuetz/CudaLOD | mixed (BSD / verify) | Architecture/LOD references only; not iOS-deployable as-is. |

**Performance levers:** 16-bit half-float attributes, voxel/grid dedup at capture
(measured ~3× tiler speedup), octree frustum/screen-space culling, page/stream
nodes rather than holding the whole cloud resident. Bandwidth — not compute — is
the binding constraint for point sprites.

## 3. Multi-scan registration / SLAM (the no-scan-ceiling engine)

| Component | License | On-device? | Notes |
| --- | --- | --- | --- |
| **small_gicp** | ✅ MIT | **Yes (best)** | Header-only, Eigen-based GICP/ICP/VGICP; no CUDA. Primary on-device fine-registration engine. |
| **libpointmatcher** | ✅ BSD-3 | Yes | Config-driven ICP (filters/matchers/outlier rejectors); Eigen-only, ARM-portable. Alternative to small_gicp. |
| **KISS-ICP** | ✅ MIT | Yes | Near-parameter-free LiDAR odometry (point-to-point ICP + adaptive threshold + constant-velocity). Reference for live scan-to-map drift control. |
| **TEASER++** | ✅ MIT | Yes | Certifiably-robust global registration (>99% outlier tolerant), ms-fast. Coarse init before ICP. |
| **GTSAM** | ✅ BSD | Yes | Factor-graph back-end with **iSAM2 incremental** solving — the key to decoupling per-scan cost from set size. |
| Ceres Solver / g2o | ✅ BSD | Yes | Alternative pose-graph optimizers (Ceres used by Cartographer). |
| **RTAB-Map** | ✅ BSD-3 | **Yes — ships an iOS app** | Full handheld SLAM: appearance-based (BoW) **loop closure** + pose-graph + memory mgmt + PLY/LAS/OBJ export. Closest full-stack analog; adopt or learn from. (Full build pulls PCL/OpenCV — manage binary size.) |
| **Open3D** | ✅ MIT | Cloud-preferred | ICP variants, FPFH+RANSAC/FGR global reg, TSDF, Poisson/ball-pivoting meshing. Heavy to embed; best as cloud worker / port small pieces. |
| **PCL** | ✅ BSD | Cloud-preferred | ICP/GICP/**NDT**, SAC-IA, meshing. Heavy deps (Boost/VTK); server-side. |
| **ORB-SLAM3**, OpenVSLAM/stella_vslam | 🚫 GPLv3 | — | Do **not** embed in closed-source. Quarantine as a separate service at most. |

**Why incumbents cap at ~10 scans, and how we remove it:** naive stitching does
all-pairs global-reg + ICP (≈O(N²), Kd-trees over millions of points) → memory/
time blowup → artificial cap. The fix: (1) incremental **scan-to-submap**
registration, not all-pairs; (2) **pose-graph** nodes/edges optimized with GTSAM
iSAM2; (3) **loop closure** (RTAB-Map BoW) to correct drift; (4) voxel-hashing/
TSDF submaps to bound the working set; (5) coarse→fine (TEASER++ → small_gicp) on
downsampled clouds. ARKit gives metric scale + gravity for free (advantage over
pure photogrammetry).

## 4. Point-cloud formats / compression / tiling

| Component | License | Notes |
| --- | --- | --- |
| **COPC** (Cloud-Optimized Point Cloud) | ✅ open spec | A valid **LAZ 1.4** file with a clustered octree + HTTP range reads. One file = on-device store + streaming + survey deliverable. **Standardize on this.** Impls: **copc-lib** (✅ MIT, C++), **copc-rs** (✅ MIT/Apache, Rust). |
| **LAS/LAZ** | — | Survey de-facto standard. Codecs: **LASzip** core (✅ Apache-2.0, C++ — *not* the proprietary LAStools suite), **laz-rs** + **las-rs** (✅ Apache/MIT, Rust — cleanest modern on-device stack). |
| **E57** | — | Required by ReCap/Cyclone/RealWorks/Faro Scene. **libE57Format** (✅ BSL-1.0, C++) or **e57** (✅ MIT/Apache, Rust). Keep double-precision on export. |
| **PLY/PTS/XYZ/OBJ** | ✅ MIT | Trivial; **tinyply**/**happly** (PLY), **tinyobjloader** (OBJ), or hand-rolled Swift. |
| **glTF/GLB** | ✅ MIT/Apache | **GLTFKit2** (✅ MIT) native loader/exporter; **Draco** (✅ Apache-2.0, has iOS build) for compressed transfer — visualization, **not** survey interchange. |
| **PDAL** | ✅ BSD-3 | "GDAL of point clouds": LAS/LAZ/E57/COPC/PLY I/O, reproject, `writers.gdal` (→DEM), `writers.copc`. Heavy deps → **server-side conversion microservice**, not on-device. |
| Entwine/EPT | ⚠️ LGPL-2.1 | Octree-of-tiles indexer; use **out-of-process** (CLI/server), don't link. COPC is the simpler single-file successor. |
| PotreeConverter **2.0** | ⚠️ non-commercial/paid | Use **1.x (BSD-2)** in a commercial product, or avoid. |
| libLAS | ✅ BSD but **deprecated** | Don't adopt (no LAS 1.4). |

**On-device flow:** append-only binary chunks + spatial grid index during live
capture → finalize/export to **COPC/LAZ** (and **E57** for survey). Lossless LAZ
≈ 5–10× smaller. Reserve Draco/lossy for visualization transfer only.

## 5. Web point-cloud viewer (sharing / desktop planning)

| Component | License | Notes |
| --- | --- | --- |
| **Potree** | ✅ BSD-2 | Turnkey large-cloud viewer with **built-in measure / elevation profile / volume / clipping / annotations**. Fastest "share a link to a scan." Reads its octree + EPT + LAS/LAZ. Monolithic/older three.js. |
| **potree-core (tentone)** | ✅ MIT | Rendering/loading core extracted for embedding in a custom-branded three.js/React viewer. Build your own measure/annotate UI. |
| **loaders.gl** | ✅ MIT | Modular LAS/PLY/PCD/Draco/3D-Tiles/Potree loaders; framework-agnostic parsing foundation. |
| **COPC.js / viewer.copc.io** | ✅ MIT/BSD | Streams a single COPC file via HTTP range — no tiling pipeline. Fits if we standardize on COPC. |
| **deck.gl** (PointCloudLayer / Tile3DLayer) | ✅ MIT | React-friendly, map-integrated planning UIs; needs pre-tiling for big clouds. |
| **CesiumJS + 3D Tiles** | ✅ Apache-2.0 | Georeferencing/terrain/basemaps + point clouds; heavier than Potree for a pure share. |
| **Giro3D** | ✅ MIT | three.js geospatial framework; renders Potree + COPC; modern middle ground. |
| CloudCompare (desktop) | 🚫 GPL | Reference only; no OSS web equivalent. |

**Tiling pipeline (server-side):** raw → **PDAL** (clean/reproject) → **COPC**
(single file, range reads) or **Entwine/EPT** (widest viewer support) →
Potree/COPC.js/Cesium. Run conversion as a cloud batch job on upload, never
in-browser.

## 6. Photogrammetry / NeRF / Gaussian splatting (complement, not core)

| Component | License | Notes |
| --- | --- | --- |
| **Apple Object Capture** | Apple framework | On-device (iOS17+)/macOS; textured mesh USDZ/OBJ. Object-scale, not site-scale; not measurement-grade. |
| **COLMAP** | ✅ BSD-3 | Gold-standard SfM+MVS; sparse+dense clouds/meshes. Best OSS base for a photogrammetry backend (GPU/server). |
| **OpenMVG** / **AliceVision** / **Meshroom** | ✅ MPL-2.0 | SfM + reconstruction (MPL = linking-friendly). SIFT patent expired 2020. |
| **gsplat** / **Nerfstudio** | ✅ Apache-2.0 | Commercially-usable 3D Gaussian Splatting + NeRF. |
| **OpenMVS** | 🚫 AGPL-3.0 | Dense MVS/meshing — **do not ship** (network-use disclosure). |
| **Inria gaussian-splatting** (original) | 🚫 non-commercial | **Do not ship.** Use gsplat instead. |
| **instant-ngp** | 🚫 NVIDIA non-commercial | **Do not ship.** Use nerfstudio instead. |

**Strategy:** LiDAR stays the **metric source of truth** for measurement;
photogrammetry/3DGS only for color, texture, gap-fill beyond LiDAR range, and
shareable visuals. Fusing them (LI-GS-style) is the research direction for
accurate large-scale geometry. Practical pattern (à la Scaniverse/Polycam):
capture on-device, **train/reconstruct in the cloud**.

## 7. Scan-quality guidance (key differentiator)

**Apple-native signals (free, on-device, the v1 foundation):**
- `ARDepthData.confidenceMap` (low/med/high) → flag/reject poor regions; "rescan
  this surface" overlays.
- `ARMeshAnchor` live incremental mesh → render coverage as it fills; holes = gaps.
- `ARCamera.TrackingState.limited(reason:)` → built-in **excessiveMotion** ("too
  fast") and **insufficientFeatures** ("too dark/featureless") prompts.
- `lightEstimate` (ambient intensity/temperature) → lighting warnings.
- **`ObjectCaptureSession.Feedback`** taxonomy (movingTooFast, environmentTooDark,
  objectTooFar/Close, outOfFieldOfView…) + `ObjectCaptureView` coaching — **copy
  this UX model** (sample: sfomuseum/ios-guided-capture).

**Coverage-gap engine:** voxel-hashing / TSDF occupancy (Nießner 2013; Voxblox;
Open3D TSDF, MIT) — mark observed voxels; "unobserved adjacent to observed
surface" inside a user-defined region-of-interest = a gap to prompt on.
Distinguish *observed-but-low-confidence* ("rescan slowly/closer") from
*never-observed* ("scan over there"). Evolve toward **Next-Best-View** (GenNBV,
VIN-NBV, PC-NBV — research code, verify licenses) later.

**Hard part for sites:** an open site has no natural "done" (unlike a bounded
object) → use a user-defined bounding region + coverage-% within it. This
outdoor/terrain-tuned guidance is whitespace competitors don't cover.

## 8. Cloud sync / storage (large binary assets)

**Architecture:** a pluggable `SyncProvider` protocol; all heavy transfers go
through a background-capable, **resumable, chunked** uploader (file-backed
`URLSession` background config). Catalog/metadata sync is separate from blob
transfer.

| Component | License | Notes |
| --- | --- | --- |
| **AWS SDK for Swift** / **Soto** | ✅ Apache-2.0 | S3 multipart (resume per-part); works against **R2/B2** (S3-compatible). Prefer presigned per-part PUTs from a backend (keep creds off-device). |
| **TUSKit** + **tusd** | ✅ MIT | tus.io resumable protocol with iOS background upload; cleanest resume semantics when we control the server. |
| **URLSession background transfer** | first-party | Foundation for reliability: background config + **file-backed** bodies + delegate API. Note: uploads do **not** auto-resume → implement via multipart/tus; persist upload state to disk. |
| **GTLR (GoogleAPIClientForREST)** + GoogleSignIn-iOS + GTMAppAuth + AppAuth | ✅ Apache-2.0 | BYO Google Drive (resumable uploads). Use least-privilege **`drive.file`** scope (avoids restricted-scope security assessment); `drive.appdata` for hidden sync state. |
| **swift-google-drive-client** | ✅ MIT | Lightweight pure-Swift Drive alternative (no heavy Google SDK). |
| **CloudKit / CKAsset / iCloud Drive** | first-party | Apple-native BYO option; CKAssets large (bounded by user's iСloud plan); iCloud Drive for user-visible files; `NSPersistentCloudKitContainer` for catalog. |
| **Automerge-swift** + **automerge-repo-swift** | ✅ MIT | CRDT for the **metadata/catalog** graph with pluggable network/storage providers (offline merge). **Never** route multi-GB clouds through a CRDT — content-address immutable blobs by hash, version instead of merge. |
| Cloudflare R2 / Backblaze B2 | — | S3-compatible; R2 has **no egress fees** (attractive for re-downloading big clouds). |

**Hard problems:** multi-GB files → COPC/LAZ to shrink 5–10× + multipart/tus so a
failed part ≠ failed GB + content-address for dedup/integrity; background upload
reliability → file-backed + own resume + persisted state + beware
`isDiscretionary` delays; **export fidelity** → preserve double-precision coords,
intensity, RGB, GPS time, classification, CRS (LAS GeoKeys / E57 metadata);
prefer server-side **PDAL** to produce/validate LAS 1.4 / E57 / COPC.

## 9. Measurement / volume / cut-fill / CAD-BIM-GIS export

| Component | License | Notes |
| --- | --- | --- |
| **Open3D** | ✅ MIT | Poisson / ball-pivoting / alpha-shape meshing, normals, voxel ops. Most practical MIT reconstruction lib (bridge C++ or server-side). |
| **PCL** | ✅ BSD-3 | Meshing + plane/cylinder fitting (grade/plane detection); heavy → server-side. |
| **CGAL** | ⚠️ GPL **or** commercial | Best-in-class meshing incl. **Polygonal Surface Reconstruction** (piecewise-planar — ideal for buildings/graded planes). Budget the commercial license to use in a closed app. |
| **CloudCompare** | 🚫 GPL | Reference for the **2.5D volume / cut-fill** math (study, don't link); desktop companion only. |
| **PDAL** + **GDAL** + **PROJ** | ✅ BSD / MIT / MIT | Point→DEM (`writers.gdal`), contour generation (`gdal_contour`), reprojection/CRS (GPS scale, UTM/State Plane, GCPs), DXF/GeoJSON/Shapefile out. Server-side. |
| **IfcOpenShell** | ⚠️ LGPL-3.0 | Full IFC2x3/IFC4/**IFC4x3 (infra/alignment)** read/write; `IfcConvert`→OBJ/glTF. Link dynamically / run server-side. |
| **ezdxf** | ✅ MIT | **DXF** create/modify (linework, contours, site plans). DXF only (no DWG). Default CAD export. |
| **LandXML** | ✅ open spec | Key **survey/civil** interchange (Civil 3D/InRoads) for TIN/parcels/alignments. No mature lib — emit XML via lxml; thin emitter we write. |
| **pyshp** / **Shapely** / **Fiona** | ✅ MIT / BSD-3 | Shapefile/GeoJSON I/O + geometry math (areas/buffers/intersections). |
| **Assimp** | ✅ BSD-3 | Broad mesh I/O (OBJ/glTF/FBX/DAE/STL/PLY). |
| **USDZ** | first-party | Native via ModelIO/RealityKit for AR QuickLook export — match every competitor for free. |
| **Triangle** (Shewchuk) | ⚠️ non-commercial | High-quality TIN, but commercial use needs a license — prefer Delaunay via scipy/CGAL-commercial. |
| **DWG** | 🚫 / closed | **No permissive DWG writer exists.** Ship DXF (ezdxf) as the open path; license **ODA Drawings SDK** (paid) only if enterprise demands native DWG. |

**Cut/fill reality:** no permissive drop-in exists — build it. Standard method:
point cloud → 2.5D raster/TIN DEM (PDAL/GDAL) → integrate height-difference ×
cell-area between existing and design/reference surfaces. The math is simple once
two surfaces are aligned; CloudCompare's 2.5D grid is the reference (GPL — study
only). **This is our moat — own it with an MIT/BSD stack.**

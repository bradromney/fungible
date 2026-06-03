# Buy / Build / Reuse Matrix

The decision for each capability: **Reuse** an OSS component, **Build** custom,
**Server** (run heavy/awkward-license code off-device), or **Apple** (first-party
framework). All "Reuse" picks are permissively licensed (MIT/BSD/Apache/BSL/MPL)
unless noted. Rationale is deliberately short; details live in
[`open-source-components.md`](./open-source-components.md).

| # | Capability | Decision | Chosen option | Rationale |
| --- | --- | --- | --- | --- |
| 1 | LiDAR depth/mesh capture | **Apple + Build** | ARKit `sceneDepth`/`smoothedSceneDepth`/`ARMeshAnchor`; hardened fork of Apple's scene-depth sample | No substitute for first-party ARKit; the sample is the proven capture core. Own the accumulation/export to avoid its known footguns. |
| 2 | Point unprojection & filtering | **Build** (Metal) | Metal compute + confidence filter + optional MPS bilateral upsample | Small, perf-critical, GPU-bound; must own it. |
| 3 | On-device preview render (MVP) | **Apple** | SceneKit point geometry | Fastest to ship; fine to low-millions for preview. |
| 4 | Site-scale render | **Build + Reuse** | Raw **Metal** + Potree-style octree; offline octree via **PotreeConverter 1.x** (BSD-2) | Only path to multi-million/streamed points; reuse the proven octree builder, reimplement LOD in Metal. |
| 5 | Fine registration (ICP/GICP) | **Reuse** | **small_gicp** (MIT) | Header-only, Eigen-only, no CUDA → compiles for ARM/iOS; fastest modern GICP. |
| 6 | Coarse/global registration | **Reuse** | **TEASER++** (MIT) + FPFH | Robust no-initial-guess alignment for stitching independent scans; ms-fast, portable. |
| 7 | Live odometry / drift control | **Reuse (adapt)** | **KISS-ICP** (MIT) pattern | Near-parameter-free scan-to-map; adapt from LiDAR streams to ARKit depth. |
| 8 | Pose-graph back-end | **Reuse** | **GTSAM** (BSD) iSAM2 | Incremental optimization is what removes the scan-count ceiling. |
| 9 | Loop closure | **Reuse (study/adapt)** | **RTAB-Map** (BSD) BoW detector | Production-proven on iOS already; adopt or learn the memory-mgmt + closure design. |
| 10 | Heavy global re-optimization / dense meshing | **Server** | **Open3D** (MIT) / **PCL** (BSD) workers | Too heavy to embed; runs comfortably server-side. |
| 11 | Visual-inertial SLAM (if needed) | **Avoid / Server-quarantine** | ~~ORB-SLAM3~~ (GPL) | 🚫 GPL — never link into the app. ARKit world tracking covers most needs anyway. |
| 12 | Storage + streaming + deliverable format | **Reuse** | **COPC** via **copc-lib**/**copc-rs** (MIT) | One LAZ-1.4 file = on-device store + HTTP-range streaming + survey deliverable. |
| 13 | LAS/LAZ codec | **Reuse** | **laz-rs + las-rs** (Apache/MIT) *or* **LASzip** core (Apache) | Clean on-device LAZ; Rust core also reusable server-side. (Avoid LAStools suite.) |
| 14 | E57 export | **Reuse** | **libE57Format** (BSL) *or* **e57-rs** (MIT/Apache) | Required by ReCap/Cyclone/Faro; permissive. |
| 15 | PLY/OBJ/glTF/USDZ | **Reuse + Apple** | tinyply/tinyobjloader/**GLTFKit2** (MIT); **USDZ** via ModelIO | Trivial/native; match competitors' format breadth cheaply. |
| 16 | Format conversion / DEM / reproject (heavy) | **Server** | **PDAL + GDAL + PROJ** (BSD/MIT) | Full format coverage + CRS + point→DEM; too heavy on-device, ideal as a microservice. |
| 17 | Web viewer (share a scan) | **Reuse** | **Potree** (BSD-2) MVP → **potree-core**/**loaders.gl** (MIT) custom | Built-in measure/annotate now; embeddable core when we want our own brand. |
| 18 | Photogrammetry (color/gap-fill) | **Server (later) + Apple** | **COLMAP** (BSD)/**AliceVision** (MPL) server; Apple **Object Capture** for objects | Complement only; LiDAR stays the metric truth. 🚫 Avoid OpenMVS (AGPL). |
| 19 | Gaussian splatting / NeRF (visuals) | **Server (later)** | **gsplat / Nerfstudio** (Apache-2.0) | Shareable visuals only. 🚫 Avoid Inria 3DGS + instant-ngp (non-commercial). |
| 20 | Scan-quality guidance | **Apple + Build** | ARKit confidence + `ARMeshAnchor` + `TrackingState` + `lightEstimate`; UX patterned on `ObjectCaptureSession.Feedback`; voxel/TSDF coverage engine (own) | The differentiator — built on free native signals + a custom outdoor-tuned coverage engine. NBV (research) later. |
| 21 | Surface reconstruction / meshing | **Reuse / Server** | **Open3D** Poisson/ball-pivoting (MIT) | Permissive; bridge or server-side. (CGAL only if we buy its commercial license.) |
| 22 | **Cut/fill / stockpile / volume** | **Build** | DEM/TIN diff on **PDAL/GDAL** surfaces; own the integration math | **No permissive drop-in exists** — this is our moat. CloudCompare's 2.5D method (GPL) is study-only reference. |
| 23 | Measurement (distance/area/volume) | **Build** | Metal raycast point-pick + geometry math; **Shapely** (BSD) for polygon math server-side | Small, core UX; own it. |
| 24 | CAD/BIM/GIS export | **Reuse / Server** | **ezdxf** (MIT, DXF) · **IfcOpenShell** (LGPL, dynamic-link/server, IFC) · **LandXML** thin emitter (build) · **pyshp/Fiona** (MIT/BSD, SHP/GeoJSON) | Covers pro civil needs the consumer apps skip. 🚫 No permissive DWG writer — DXF is the open path; license ODA only if enterprise demands DWG. |
| 25 | Hosted blob sync | **Reuse** | **AWS SDK for Swift**/**Soto** (Apache) → S3/**R2**/B2; or **TUSKit**/tusd (MIT) | Resumable multipart; R2 zero-egress for big re-downloads. |
| 26 | BYO Google Drive | **Reuse** | **GTLR** + GoogleSignIn/GTMAppAuth/AppAuth (Apache), `drive.file` scope; or **swift-google-drive-client** (MIT) | Least-privilege scope avoids Google security assessment. |
| 27 | BYO Apple cloud | **Apple** | CloudKit/CKAsset + iCloud Drive | Native, zero extra infra. |
| 28 | Background uploads | **Apple + Build** | file-backed background `URLSession` + own resume/state | iOS doesn't auto-resume uploads; persist multipart/tus state ourselves. |
| 29 | Catalog/metadata sync | **Reuse** | **Automerge-repo-swift** (MIT) | CRDT for the catalog graph; offline merge. Never route blobs through it — content-address by hash. |
| 30 | Georeferencing (no rig) | **Build + Reuse** | ARKit metric scale/gravity + GPS/GCP constraints in the pose graph; **PROJ** (MIT) for CRS | "Good enough" georef without forcing RTK hardware; RTK optional later. |

## Top licensing landmines (do not link into the app)

🚫 **AGPL:** OpenMVS · 🚫 **Non-commercial:** Inria gaussian-splatting, instant-ngp,
Triangle (commercial clause) · 🚫 **GPL:** ORB-SLAM3 / OpenVSLAM, CloudCompare,
libdxfrw/LibreDWG · ⚠️ **Dual/commercial:** CGAL (buy commercial), CurvSurf
FindSurface engine · ⚠️ **Weak-copyleft (isolate/dynamic-link or server):**
IfcOpenShell (LGPL), Entwine (LGPL) · ⚠️ **Non-commercial tool version:**
PotreeConverter **2.0** (use 1.x BSD-2).

## Net architecture implication

A small **on-device core** (ARKit capture + Metal + small_gicp/TEASER++/GTSAM
incremental registration + COPC/LAZ/E57 export + the coverage-guidance engine),
a **pluggable sync layer**, a **web viewer** (Potree → custom), and a **cloud
worker tier** (PDAL/GDAL/Open3D for heavy conversion, dense meshing, photogrammetry,
and global re-optimization). The two custom moats to own outright: **incremental
no-ceiling registration** and **mobile cut/fill/earthwork**.

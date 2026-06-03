# Third-Party License Register

Fungible is a **commercial, closed-source iOS app.** Every third-party component
must therefore be safe to ship in a proprietary binary. This register is the
single source of truth for what we may link, what must be isolated, and what is
forbidden. Update it whenever a dependency is added. License determinations are
from the [research dossier](./research/open-source-components.md) (June 2026) —
re-verify each component's LICENSE file at adoption time.

## ✅ Safe to link into the app (MIT / BSD / Apache / BSL / MPL)

| Component | License | Used for |
| --- | --- | --- |
| small_gicp | MIT | On-device fine registration (GICP/ICP) |
| TEASER++ | MIT | On-device coarse/global registration |
| GTSAM | BSD-3 | Pose-graph optimization (iSAM2) |
| KISS-ICP (adapted) | MIT | Live odometry reference |
| libpointmatcher | BSD-3 | Alternative ICP |
| copc-lib / copc-rs | MIT | COPC read/write (storage + deliverable) |
| LASzip core / laz-rs / las-rs | Apache-2.0 / MIT | LAS/LAZ codec |
| libE57Format | BSL-1.0 | E57 export |
| e57 (Rust) | MIT/Apache | E57 (Rust alternative) |
| tinyply / happly / tinyobjloader | MIT | PLY/OBJ I/O |
| GLTFKit2 | MIT | glTF/GLB I/O |
| Draco | Apache-2.0 | Compressed transfer (visualization only) |
| AWS SDK for Swift / Soto | Apache-2.0 | Hosted S3/R2/B2 sync |
| TUSKit | MIT | Resumable upload transport |
| GTLR / GoogleSignIn / GTMAppAuth / AppAuth | Apache-2.0 | BYO Google Drive |
| swift-google-drive-client | MIT | Lightweight Drive alternative |
| Automerge-swift / automerge-repo-swift | MIT | Catalog/metadata CRDT |
| PROJ | MIT/X11 | Coordinate reference transforms |
| Potree (1.x) / potree-core / loaders.gl | BSD-2 / MIT | Web viewer |
| PotreeConverter **1.x** | BSD-2 | Offline octree builder |

## ⚠️ Allowed only with care — isolate, dynamic-link, or run server-side

| Component | License | Constraint |
| --- | --- | --- |
| IfcOpenShell | LGPL-3.0 | Dynamic-link or run server-side; don't static-link into the app |
| Entwine | LGPL-2.1 | Use out-of-process (CLI/server) only; don't link |
| PDAL / GDAL | BSD / MIT | Permissive, but heavy → run as a **cloud worker**, not on-device |
| Open3D / PCL | MIT / BSD | Permissive, but heavy → cloud worker (or port small pieces) |
| COLMAP | BSD-3 | Permissive; GPU/server-side photogrammetry |
| OpenMVG / AliceVision / Meshroom | MPL-2.0 | File-level copyleft, linking OK; verify patented modules |
| gsplat / Nerfstudio | Apache-2.0 | Server-side splats/NeRF (visualization only) |

## 🚫 Forbidden — do NOT link into the app or a distributed binary

| Component | License | Why |
| --- | --- | --- |
| ORB-SLAM3 / OpenVSLAM (stella_vslam) | GPLv3 | Viral copyleft; ARKit world tracking covers our needs |
| OpenMVS | AGPL-3.0 | Network-use disclosure obligation |
| Inria gaussian-splatting (original) | Non-commercial research | Explicitly not for commercial use → use gsplat |
| instant-ngp | NVIDIA non-commercial | Not licensed for commercial use → use nerfstudio |
| CloudCompare | GPL | Desktop reference only; study the 2.5D cut/fill method, don't link |
| libdxfrw / LibreDWG | GPL | Use **ezdxf** (MIT) for DXF instead |
| PotreeConverter **2.0** | Non-commercial/paid | Use 1.x (BSD-2) |

## 💲 Commercial license required if used

| Component | Note |
| --- | --- |
| CGAL | GPL **or** paid commercial (GeometryFactory). Budget the commercial license if we adopt its meshing. |
| CurvSurf FindSurface (engine) | Demo is MIT; the fitting **engine** is a proprietary SDK. |
| Triangle (Shewchuk) | Free for non-commercial only; commercial needs a license → prefer scipy/CGAL-commercial Delaunay. |
| ODA Drawings SDK | The only real DWG read/write path; paid membership. Ship DXF (ezdxf) unless enterprise demands native DWG. |

## Process

1. Before adding a dependency, find it here or add a row with its verified
   license and tier.
2. 🚫 / 💲 components need explicit sign-off and (for 💲) a purchased license.
3. The shipped app bundles a generated attributions screen for all ✅/⚠️
   components per their notice requirements.

"""Fungible cloud worker.

Heavy, awkward-to-bundle point-cloud processing that runs server-side rather
than on-device (see docs/research/buy-build-reuse-matrix.md): format conversion,
reprojection, DEM rasterization, and COPC/Potree tiling via PDAL + GDAL.

The pipeline *builders* in `pipelines` are pure functions (they return PDAL
pipeline definitions as plain data) so they are unit-tested in CI without the
PDAL/GDAL native stack installed. Actual execution (`runner`) imports PDAL
lazily.
"""

__all__ = ["pipelines", "jobs"]

"""Pure PDAL pipeline builders.

Each function returns a PDAL pipeline as a list of stage dicts (the JSON PDAL
consumes). They take and return plain data only — no PDAL import — so they are
fully unit-testable in CI. `runner.run` executes them with the native library.
"""
from __future__ import annotations

from typing import Any


def to_copc(input_path: str, output_path: str) -> list[dict[str, Any]]:
    """Convert any PDAL-readable cloud to a Cloud-Optimized Point Cloud.

    COPC is a valid LAZ 1.4 file with a clustered octree + HTTP range support —
    our single streaming + deliverable format.
    """
    return [
        {"type": _reader_for(input_path), "filename": input_path},
        {"type": "writers.copc", "filename": output_path},
    ]


def reproject(input_path: str, output_path: str, in_srs: str, out_srs: str) -> list[dict[str, Any]]:
    """Reproject a cloud between coordinate reference systems (e.g. local → UTM).

    `in_srs`/`out_srs` are EPSG strings like "EPSG:4326" / "EPSG:32613".
    """
    return [
        {"type": _reader_for(input_path), "filename": input_path},
        {"type": "filters.reprojection", "in_srs": in_srs, "out_srs": out_srs},
        {"type": _writer_for(output_path), "filename": output_path},
    ]


def to_dem(
    input_path: str,
    output_path: str,
    resolution: float = 0.1,
    output_type: str = "idw",
) -> list[dict[str, Any]]:
    """Rasterize a cloud to a 2.5D DEM (GeoTIFF) — the surface the cut/fill and
    contour workflows build on. `resolution` is cell size in CRS units (meters).
    """
    if resolution <= 0:
        raise ValueError("resolution must be positive")
    valid = {"min", "max", "mean", "idw", "count", "stdev"}
    if output_type not in valid:
        raise ValueError(f"output_type must be one of {sorted(valid)}")
    return [
        {"type": _reader_for(input_path), "filename": input_path},
        {
            "type": "writers.gdal",
            "filename": output_path,
            "gdaldriver": "GTiff",
            "output_type": output_type,
            "resolution": resolution,
        },
    ]


def _reader_for(path: str) -> str:
    ext = path.rsplit(".", 1)[-1].lower()
    return {
        "las": "readers.las",
        "laz": "readers.las",
        "copc": "readers.copc",
        "ply": "readers.ply",
        "e57": "readers.e57",
        "xyz": "readers.text",
    }.get(ext, "readers.las")


def _writer_for(path: str) -> str:
    ext = path.rsplit(".", 1)[-1].lower()
    return {
        "las": "writers.las",
        "laz": "writers.las",
        "copc": "writers.copc",
        "ply": "writers.ply",
        "e57": "writers.e57",
    }.get(ext, "writers.las")

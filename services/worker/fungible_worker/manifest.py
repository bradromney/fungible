"""Set-processing orchestration.

Turns a finished scan set (its registered scan files) into the deliverables the
app and web viewer consume: one merged **COPC** (storage + streaming + survey
deliverable), a **DEM** GeoTIFF (the surface for cut/fill + contours), and a
downsampled **preview** for fast web loading.

`ProcessRequest` is JSON-serializable so it can ride a job queue; `plan` expands
it into named PDAL pipelines. Pure — no PDAL — so it is unit-tested in CI.
"""
from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Any

from . import pipelines


@dataclass(frozen=True)
class ProcessRequest:
    set_id: str
    input_paths: list[str]
    out_dir: str
    dem_resolution: float = 0.1
    preview_cell: float = 0.05

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @staticmethod
    def from_dict(d: dict[str, Any]) -> "ProcessRequest":
        return ProcessRequest(
            set_id=d["set_id"],
            input_paths=list(d["input_paths"]),
            out_dir=d["out_dir"],
            dem_resolution=float(d.get("dem_resolution", 0.1)),
            preview_cell=float(d.get("preview_cell", 0.05)),
        )


@dataclass(frozen=True)
class ProcessOutputs:
    copc: str
    dem: str
    preview: str


def outputs_for(req: ProcessRequest) -> ProcessOutputs:
    base = f"{req.out_dir.rstrip('/')}/{req.set_id}"
    return ProcessOutputs(
        copc=f"{base}.copc.laz",
        dem=f"{base}.dem.tif",
        preview=f"{base}.preview.laz",
    )


def plan(req: ProcessRequest) -> list[tuple[str, list[dict[str, Any]]]]:
    """Expand a request into ordered, named pipelines.

    merge inputs → COPC, then DEM and preview derive from the merged COPC.
    """
    if not req.input_paths:
        raise ValueError("input_paths is empty")
    out = outputs_for(req)
    return [
        ("merge", pipelines.merge(req.input_paths, out.copc)),
        ("dem", pipelines.to_dem(out.copc, out.dem, req.dem_resolution)),
        ("preview", pipelines.downsample(out.copc, out.preview, req.preview_cell)),
    ]

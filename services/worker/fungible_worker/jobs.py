"""Job model: a processing request and the pipeline it plans to.

Kept pure (no PDAL) so planning is unit-tested in CI. The runner executes the
planned pipeline.
"""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Any

from . import pipelines


class JobKind(str, Enum):
    TO_COPC = "to_copc"
    TO_DEM = "to_dem"
    REPROJECT = "reproject"
    DOWNSAMPLE = "downsample"


@dataclass(frozen=True)
class Job:
    kind: JobKind
    input_path: str
    output_path: str
    # Optional parameters by kind:
    in_srs: str | None = None
    out_srs: str | None = None
    resolution: float = 0.1
    output_type: str = "idw"


def plan(job: Job) -> list[dict[str, Any]]:
    """Build the PDAL pipeline for a job (pure)."""
    if job.kind is JobKind.TO_COPC:
        return pipelines.to_copc(job.input_path, job.output_path)
    if job.kind is JobKind.TO_DEM:
        return pipelines.to_dem(job.input_path, job.output_path, job.resolution, job.output_type)
    if job.kind is JobKind.DOWNSAMPLE:
        return pipelines.downsample(job.input_path, job.output_path, job.resolution)
    if job.kind is JobKind.REPROJECT:
        if not job.in_srs or not job.out_srs:
            raise ValueError("reproject requires in_srs and out_srs")
        return pipelines.reproject(job.input_path, job.output_path, job.in_srs, job.out_srs)
    raise ValueError(f"unknown job kind: {job.kind}")

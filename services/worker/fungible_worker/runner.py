"""Pipeline execution. Imports PDAL lazily so the rest of the package (and its
tests) work without the native PDAL/GDAL stack installed.
"""
from __future__ import annotations

import json
from typing import Any

from .jobs import Job, plan


def run_pipeline(stages: list[dict[str, Any]]) -> int:
    """Execute a PDAL pipeline; returns the number of points processed.

    Requires PDAL (install via conda: `conda install -c conda-forge pdal`).
    """
    import pdal  # lazy: not needed for planning/tests

    pipeline = pdal.Pipeline(json.dumps(stages))
    return pipeline.execute()


def run_job(job: Job) -> int:
    return run_pipeline(plan(job))

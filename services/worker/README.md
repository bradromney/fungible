# Fungible cloud worker

Server-side point-cloud processing that's too heavy or awkwardly-licensed to
bundle on-device (see the
[buy/build/reuse matrix](../../docs/research/buy-build-reuse-matrix.md)):
format conversion, reprojection, DEM rasterization, and COPC/Potree tiling via
**PDAL + GDAL** (both BSD/MIT).

## Design

- `fungible_worker/pipelines.py` — **pure** builders that return PDAL pipelines
  as plain data (no native deps), so they're fully unit-tested in CI.
- `fungible_worker/jobs.py` — the `Job` model and `plan()` dispatch (pure).
- `fungible_worker/runner.py` — executes a pipeline; imports PDAL lazily.
- `fungible_worker/cli.py` — `python -m fungible_worker …` (supports `--dry-run`
  to print a pipeline without running it).

## Test (no native stack needed)

```sh
cd services/worker
pip install -r requirements-dev.txt
pytest -q
```

CI runs exactly this. The pure builders are what we test; execution needs PDAL.

## Run for real

PDAL/GDAL are native — install via conda-forge:

```sh
conda install -c conda-forge pdal python-pdal gdal
python -m fungible_worker to-copc scan.laz scan.copc.laz
python -m fungible_worker to-dem  scan.laz dem.tif --resolution 0.1
python -m fungible_worker --dry-run to-dem scan.laz dem.tif   # inspect pipeline
```

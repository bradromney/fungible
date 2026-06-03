import pytest

from fungible_worker import pipelines
from fungible_worker.jobs import Job, JobKind, plan


def test_to_copc_uses_copc_writer_and_infers_reader():
    p = pipelines.to_copc("scan.laz", "out.copc.laz")
    assert p[0]["type"] == "readers.las"        # .laz reads via readers.las
    assert p[0]["filename"] == "scan.laz"
    assert p[-1]["type"] == "writers.copc"
    assert p[-1]["filename"] == "out.copc.laz"


def test_reader_inference_by_extension():
    assert pipelines.to_copc("a.e57", "o.copc.laz")[0]["type"] == "readers.e57"
    assert pipelines.to_copc("a.ply", "o.copc.laz")[0]["type"] == "readers.ply"
    assert pipelines.to_copc("a.xyz", "o.copc.laz")[0]["type"] == "readers.text"


def test_reproject_inserts_reprojection_filter():
    p = pipelines.reproject("in.las", "out.las", "EPSG:4326", "EPSG:32613")
    kinds = [s["type"] for s in p]
    assert "filters.reprojection" in kinds
    flt = next(s for s in p if s["type"] == "filters.reprojection")
    assert flt["in_srs"] == "EPSG:4326"
    assert flt["out_srs"] == "EPSG:32613"


def test_to_dem_sets_gdal_writer_and_resolution():
    p = pipelines.to_dem("in.laz", "dem.tif", resolution=0.25, output_type="mean")
    w = p[-1]
    assert w["type"] == "writers.gdal"
    assert w["gdaldriver"] == "GTiff"
    assert w["resolution"] == 0.25
    assert w["output_type"] == "mean"


def test_to_dem_rejects_bad_params():
    with pytest.raises(ValueError):
        pipelines.to_dem("in.laz", "dem.tif", resolution=0)
    with pytest.raises(ValueError):
        pipelines.to_dem("in.laz", "dem.tif", output_type="bogus")


def test_plan_dispatches_by_kind():
    assert plan(Job(JobKind.TO_COPC, "i.las", "o.copc.laz"))[-1]["type"] == "writers.copc"
    assert plan(Job(JobKind.TO_DEM, "i.las", "d.tif"))[-1]["type"] == "writers.gdal"


def test_plan_reproject_requires_srs():
    with pytest.raises(ValueError):
        plan(Job(JobKind.REPROJECT, "i.las", "o.las"))

from fungible_worker.cli import build_parser, job_from_args
from fungible_worker.jobs import JobKind, plan


def test_cli_to_dem_parses_into_job():
    args = build_parser().parse_args(["to-dem", "in.laz", "dem.tif", "--resolution", "0.5"])
    job = job_from_args(args)
    assert job.kind is JobKind.TO_DEM
    assert job.resolution == 0.5
    assert plan(job)[-1]["resolution"] == 0.5


def test_cli_reproject_parses_srs():
    args = build_parser().parse_args(
        ["reproject", "in.las", "out.las", "--in-srs", "EPSG:4326", "--out-srs", "EPSG:32613"]
    )
    job = job_from_args(args)
    assert job.in_srs == "EPSG:4326"
    assert job.out_srs == "EPSG:32613"

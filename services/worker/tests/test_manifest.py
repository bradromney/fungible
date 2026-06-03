import pytest

from fungible_worker.manifest import ProcessRequest, plan, outputs_for


def sample_request() -> ProcessRequest:
    return ProcessRequest(
        set_id="site-42",
        input_paths=["a.laz", "b.laz", "c.laz"],
        out_dir="/out/",
        dem_resolution=0.2,
        preview_cell=0.1,
    )


def test_outputs_naming():
    out = outputs_for(sample_request())
    assert out.copc == "/out/site-42.copc.laz"
    assert out.dem == "/out/site-42.dem.tif"
    assert out.preview == "/out/site-42.preview.laz"


def test_plan_is_merge_then_dem_then_preview():
    steps = plan(sample_request())
    assert [name for name, _ in steps] == ["merge", "dem", "preview"]

    merge_pipeline = steps[0][1]
    assert len([s for s in merge_pipeline if s["type"].startswith("readers.")]) == 3
    assert merge_pipeline[-1]["type"] == "writers.copc"  # .copc.laz detected

    dem_pipeline = steps[1][1]
    assert dem_pipeline[-1]["type"] == "writers.gdal"
    assert dem_pipeline[-1]["resolution"] == 0.2
    # DEM derives from the merged COPC, read back via the COPC reader.
    assert dem_pipeline[0]["type"] == "readers.copc"

    preview_pipeline = steps[2][1]
    flt = next(s for s in preview_pipeline if s["type"].startswith("filters."))
    assert flt["cell"] == 0.1


def test_plan_rejects_empty_inputs():
    with pytest.raises(ValueError):
        plan(ProcessRequest(set_id="x", input_paths=[], out_dir="/out"))


def test_request_json_round_trip():
    req = sample_request()
    restored = ProcessRequest.from_dict(req.to_dict())
    assert restored == req

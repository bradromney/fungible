"""Command-line entry for the worker.

    python -m fungible_worker to-copc  in.las out.copc.laz
    python -m fungible_worker to-dem   in.laz dem.tif --resolution 0.1
    python -m fungible_worker reproject in.las out.las --in-srs EPSG:4326 --out-srs EPSG:32613
"""
from __future__ import annotations

import argparse
import json
import sys

from .jobs import Job, JobKind, plan


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="fungible_worker")
    p.add_argument("--dry-run", action="store_true", help="print the PDAL pipeline and exit")
    sub = p.add_subparsers(dest="command", required=True)

    c = sub.add_parser("to-copc")
    c.add_argument("input"); c.add_argument("output")

    d = sub.add_parser("to-dem")
    d.add_argument("input"); d.add_argument("output")
    d.add_argument("--resolution", type=float, default=0.1)
    d.add_argument("--output-type", default="idw")

    r = sub.add_parser("reproject")
    r.add_argument("input"); r.add_argument("output")
    r.add_argument("--in-srs", required=True)
    r.add_argument("--out-srs", required=True)

    s = sub.add_parser("downsample")
    s.add_argument("input"); s.add_argument("output")
    s.add_argument("--cell", type=float, default=0.05)
    return p


def job_from_args(args: argparse.Namespace) -> Job:
    if args.command == "to-copc":
        return Job(JobKind.TO_COPC, args.input, args.output)
    if args.command == "to-dem":
        return Job(JobKind.TO_DEM, args.input, args.output,
                   resolution=args.resolution, output_type=args.output_type)
    if args.command == "reproject":
        return Job(JobKind.REPROJECT, args.input, args.output,
                   in_srs=args.in_srs, out_srs=args.out_srs)
    if args.command == "downsample":
        return Job(JobKind.DOWNSAMPLE, args.input, args.output, resolution=args.cell)
    raise ValueError(f"unknown command: {args.command}")


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    job = job_from_args(args)
    pipeline = plan(job)
    if args.dry_run:
        json.dump(pipeline, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return 0
    from .runner import run_pipeline  # lazy PDAL import
    count = run_pipeline(pipeline)
    print(f"processed {count} points -> {job.output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

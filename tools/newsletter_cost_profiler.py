#!/usr/bin/env python3
"""Build a per-run and per-phase cost ledger from retained newsletter runs."""

from __future__ import annotations

import argparse
import datetime as dt
from pathlib import Path

from newsletter_experiment_common import build_phase_estimates, load_json, scorecard_from_run, write_json


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", action="append", dest="run_dirs", help="Specific retained run dir; may repeat")
    parser.add_argument("--runs-root", default="runs/product_runs", help="Default retained run root")
    parser.add_argument("--pricing-snapshot", help="Explicit pricing snapshot JSON path")
    parser.add_argument("--output", help="Output JSON path")
    return parser.parse_args()


def discover_runs(args: argparse.Namespace) -> list[Path]:
    if args.run_dirs:
        return [Path(path).expanduser().resolve() for path in args.run_dirs]
    runs_root = Path(args.runs_root).expanduser()
    if not runs_root.is_absolute():
        runs_root = Path(__file__).resolve().parent.parent / runs_root
    return sorted(path.resolve() for path in runs_root.glob("*") if path.is_dir())


def main() -> int:
    args = parse_args()
    run_dirs = discover_runs(args)
    scorecards = []
    skipped_runs = []
    autodiscovered = not args.run_dirs
    for run_dir in run_dirs:
        scorecard_path = run_dir / "run-scorecard.json"
        try:
            if args.pricing_snapshot:
                scorecard = scorecard_from_run(run_dir, pricing_snapshot_path=args.pricing_snapshot)
            else:
                scorecard = load_json(scorecard_path) or scorecard_from_run(
                    run_dir,
                    pricing_snapshot_path=args.pricing_snapshot,
                )
        except SystemExit as exc:
            if not autodiscovered:
                raise
            skipped_runs.append({"run_dir": str(run_dir), "reason": str(exc)})
            continue
        scorecards.append(scorecard)

    phase_rows = []
    for scorecard in scorecards:
        phase_rows.extend(build_phase_estimates(scorecard))

    payload = {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "run_count": len(scorecards),
        "runs": scorecards,
        "phase_estimates": phase_rows,
        "skipped_runs": skipped_runs,
    }
    if args.output:
        output = Path(args.output).expanduser().resolve()
    else:
        output = Path(__file__).resolve().parent.parent / "runs" / "product_runs" / "newsletter-cost-profiler.json"
    write_json(output, payload)
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

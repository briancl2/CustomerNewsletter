#!/usr/bin/env python3
"""Audit retained run scorecards for cost and token hotspots."""

from __future__ import annotations

import argparse
import datetime as dt
from collections import defaultdict
from pathlib import Path

from newsletter_experiment_common import build_phase_estimates, load_json, scorecard_from_run, write_json


HEURISTIC_FIXES = [
    ("phase1b", "deterministic source normalization and dedupe"),
    ("phase2_event_sources", "deterministic event-source filtering and no-refetch checks"),
    ("phase2_events", "deterministic event row materialization"),
    ("phase3_working_set", "prompt/context compression before synthesis"),
    ("phase3_curated", "smaller-model or structured drafting experiment"),
    ("phase4_5_polishing", "deterministic formatting and lint-style polish rules"),
    ("phase4_6_video", "deterministic link matching and coverage checks"),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profiler-json", help="Existing profiler JSON path")
    parser.add_argument("--run-dir", action="append", dest="run_dirs", help="Specific retained run dir; may repeat")
    parser.add_argument("--pricing-snapshot", help="Explicit pricing snapshot JSON path")
    parser.add_argument("--output", help="Output JSON path")
    return parser.parse_args()


def load_payload(args: argparse.Namespace) -> dict:
    autodiscovered = False
    if args.profiler_json:
        payload = load_json(Path(args.profiler_json).expanduser().resolve())
        if payload:
            return payload
    run_dir_texts = list(args.run_dirs or [])
    if not run_dir_texts:
        runs_root = Path(__file__).resolve().parent.parent / "runs" / "product_runs"
        run_dir_texts = [str(path) for path in sorted(runs_root.glob("*")) if path.is_dir()]
        autodiscovered = True
    runs = []
    phase_rows = []
    skipped_runs = []
    for run_dir_text in run_dir_texts:
        run_dir = Path(run_dir_text).expanduser().resolve()
        try:
            scorecard = scorecard_from_run(run_dir, pricing_snapshot_path=args.pricing_snapshot)
        except SystemExit as exc:
            if not autodiscovered:
                raise
            skipped_runs.append({"run_dir": str(run_dir), "reason": str(exc)})
            continue
        runs.append(scorecard)
        phase_rows.extend(build_phase_estimates(scorecard))
    return {"runs": runs, "phase_estimates": phase_rows, "skipped_runs": skipped_runs}


def candidate_fix(transition: str) -> str:
    lowered = transition.lower()
    for needle, fix in HEURISTIC_FIXES:
        if needle in lowered:
            return fix
    return "inspect prompt scope and deterministic substitution opportunities"


def main() -> int:
    args = parse_args()
    payload = load_payload(args)
    runs = payload.get("runs", [])
    phase_rows = payload.get("phase_estimates", [])

    highest_cost_runs = sorted(
        runs,
        key=lambda item: (
            item.get("cost_estimate", {}).get("total_usd") is None,
            -(item.get("cost_estimate", {}).get("total_usd") or 0),
        ),
    )[:5]
    highest_output_runs = sorted(
        runs,
        key=lambda item: -(item.get("token_usage", {}).get("output_tokens") or 0),
    )[:5]
    slowest_receipt_runs = sorted(
        runs,
        key=lambda item: -(item.get("timing", {}).get("time_to_first_receipt_seconds") or 0),
    )[:5]

    transition_totals: dict[str, dict[str, float]] = defaultdict(
        lambda: {"cost": 0.0, "duration": 0.0, "count": 0.0, "observations": 0.0}
    )
    for row in phase_rows:
        transition = str(row.get("transition") or "unknown")
        transition_totals[transition]["observations"] += 1.0
        transition_totals[transition]["duration"] += float(row.get("duration_seconds") or 0.0)
        if row.get("estimated_cost_usd") is not None:
            transition_totals[transition]["cost"] += float(row.get("estimated_cost_usd") or 0.0)
            transition_totals[transition]["count"] += 1.0

    hottest_transitions = []
    for transition, totals in sorted(transition_totals.items(), key=lambda item: (-item[1]["cost"], -item[1]["duration"]))[:5]:
        hottest_transitions.append(
            {
                "transition": transition,
                "estimated_cost_usd": round(totals["cost"], 4),
                "total_duration_seconds": int(totals["duration"]),
                "sample_count": int(totals["count"]),
                "observation_count": int(totals["observations"]),
                "candidate_fix": candidate_fix(transition),
            }
        )

    output_transition_totals: dict[str, dict[str, float]] = defaultdict(
        lambda: {"output_tokens": 0.0, "duration": 0.0, "count": 0.0, "observations": 0.0}
    )
    for row in phase_rows:
        transition = str(row.get("transition") or "unknown")
        output_transition_totals[transition]["observations"] += 1.0
        output_transition_totals[transition]["duration"] += float(row.get("duration_seconds") or 0.0)
        if row.get("estimated_output_tokens") is not None:
            output_transition_totals[transition]["output_tokens"] += float(row.get("estimated_output_tokens") or 0.0)
            output_transition_totals[transition]["count"] += 1.0

    highest_output_transitions = []
    for transition, totals in sorted(
        output_transition_totals.items(),
        key=lambda item: (-item[1]["output_tokens"], -item[1]["duration"]),
    )[:5]:
        highest_output_transitions.append(
            {
                "transition": transition,
                "estimated_output_tokens": int(round(totals["output_tokens"])),
                "total_duration_seconds": int(totals["duration"]),
                "sample_count": int(totals["count"]),
                "observation_count": int(totals["observations"]),
                "candidate_fix": candidate_fix(transition),
            }
        )

    result = {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "highest_cost_runs": [
            {
                "run_id": row.get("run_id"),
                "primary_model": row.get("primary_model"),
                "estimated_cost_usd": row.get("cost_estimate", {}).get("total_usd"),
                "rubric_score": row.get("quality", {}).get("rubric_score"),
                "strict_pass": row.get("quality", {}).get("strict_pass"),
            }
            for row in highest_cost_runs
        ],
        "highest_output_runs": [
            {
                "run_id": row.get("run_id"),
                "primary_model": row.get("primary_model"),
                "output_tokens": row.get("token_usage", {}).get("output_tokens"),
                "estimated_cost_usd": row.get("cost_estimate", {}).get("total_usd"),
            }
            for row in highest_output_runs
        ],
        "slowest_first_receipt_runs": [
            {
                "run_id": row.get("run_id"),
                "primary_model": row.get("primary_model"),
                "time_to_first_receipt_seconds": row.get("timing", {}).get("time_to_first_receipt_seconds"),
                "estimated_cost_usd": row.get("cost_estimate", {}).get("total_usd"),
            }
            for row in slowest_receipt_runs
        ],
        "hottest_transitions": hottest_transitions,
        "highest_output_transitions": highest_output_transitions,
        "skipped_runs": payload.get("skipped_runs", []),
    }
    if args.output:
        output = Path(args.output).expanduser().resolve()
    else:
        output = Path(__file__).resolve().parent.parent / "runs" / "product_runs" / "newsletter-hotspot-audit.json"
    write_json(output, result)
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

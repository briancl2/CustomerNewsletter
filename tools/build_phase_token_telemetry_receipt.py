#!/usr/bin/env python3
"""Build a direct-only phase-boundary token telemetry receipt."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
from pathlib import Path
from typing import Any

from newsletter_experiment_common import (
    DIRECT_PROVIDER_TOKEN_FIELDS,
    load_json,
    parse_iso,
    sha256_path,
    stable_scorecard_sha256,
    write_json,
)
from product_run_common import logical_artifact_map


REPO_ROOT = Path(__file__).resolve().parent.parent
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
RAW_TOKEN_FIELDS = list(DIRECT_PROVIDER_TOKEN_FIELDS)
NORMALIZED_TOKEN_FIELDS = list(DIRECT_PROVIDER_TOKEN_FIELDS.values())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", action="append", required=True, help="Positive run directory")
    parser.add_argument(
        "--scorecard",
        action="append",
        default=[],
        help="Positive scorecard path; defaults to <run-dir>/run-scorecard.json",
    )
    parser.add_argument(
        "--negative-control",
        nargs=2,
        action="append",
        default=[],
        metavar=("RUN_DIR", "SCORECARD"),
        help="Run directory and scorecard expected to fail telemetry qualification",
    )
    parser.add_argument(
        "--phase-session-metrics",
        action="append",
        default=[],
        help="Optional per-phase metrics JSONL path; defaults to <run-dir>/session/phase-session-metrics.jsonl when present",
    )
    parser.add_argument("--output", required=True, help="Receipt JSON output path")
    return parser.parse_args()


def string_list(value: Any, label: str, errors: list[str]) -> list[str]:
    if not isinstance(value, list):
        errors.append(f"{label} must be a list")
        return []
    strings: list[str] = []
    for item in value:
        if not isinstance(item, str):
            errors.append(f"{label} contains non-string value")
            continue
        strings.append(item)
    return strings


def load_scorecard(path: Path) -> dict[str, Any]:
    payload = load_json(path)
    if not isinstance(payload, dict):
        raise SystemExit(f"Missing or invalid scorecard JSON: {path}")
    return payload


def run_metadata(run_dir: Path) -> dict[str, Any]:
    payload = load_json(run_dir / "run-metadata.json")
    if not isinstance(payload, dict):
        raise SystemExit(f"Missing run-metadata.json in {run_dir}")
    return payload


def retained_run_identity(path: Path, run_id: str) -> Path | None:
    parts = path.expanduser().parts
    for idx in range(len(parts) - 2):
        if parts[idx] == "runs" and parts[idx + 1] == "product_runs":
            return Path(*parts[idx:])
    if path.name == run_id:
        return Path("runs") / "product_runs" / run_id
    return None


def artifact_root(run_dir: Path, metadata: dict[str, Any]) -> Path:
    local_root = run_dir / "artifacts"
    if local_root.exists():
        return local_root.resolve()
    root = Path(str(metadata.get("artifact_root") or run_dir / "artifacts")).expanduser()
    if not root.is_absolute():
        root = REPO_ROOT / root
    return root.resolve()


def phase_receipts_path(run_dir: Path, metadata: dict[str, Any]) -> Path:
    start = str(metadata["start"])
    end = str(metadata["end"])
    root = artifact_root(run_dir, metadata)
    return root / logical_artifact_map(start, end)["receipts"]


def validate_scorecard_binding(
    run_dir: Path,
    scorecard_path: Path,
    scorecard: dict[str, Any],
    metadata: dict[str, Any],
    receipts_path: Path,
) -> None:
    errors: list[str] = []
    if scorecard.get("run_id") != run_dir.name:
        errors.append(f"run_id {scorecard.get('run_id')!r} != {run_dir.name!r}")

    scorecard_run_dir = scorecard.get("run_dir")
    if not scorecard_run_dir:
        errors.append("run_dir is missing")
    else:
        bound_identity = retained_run_identity(
            Path(str(scorecard_run_dir)).expanduser().resolve(),
            run_dir.name,
        )
        run_identity = retained_run_identity(run_dir.resolve(), run_dir.name)
        if bound_identity != run_identity:
            errors.append(f"run_dir identity {bound_identity} != {run_identity}")

    for field in ("start", "end", "mode"):
        if scorecard.get(field) != metadata.get(field):
            errors.append(
                f"{field} {scorecard.get(field)!r} != run metadata {metadata.get(field)!r}"
            )

    phase_receipts = scorecard.get("phase_receipts")
    if not isinstance(phase_receipts, dict):
        errors.append("phase_receipts object is missing")
    else:
        expected_sha = phase_receipts.get("receipt_file_sha256")
        if not expected_sha:
            errors.append("phase_receipts.receipt_file_sha256 is missing")
        elif not receipts_path.exists():
            errors.append(f"phase receipt file is missing: {receipts_path}")
        else:
            actual_sha = sha256_path(receipts_path)
            if actual_sha != expected_sha:
                errors.append(
                    "phase_receipts.receipt_file_sha256 does not match current "
                    f"workspace receipt file ({actual_sha} != {expected_sha})"
                )

    if errors:
        raise SystemExit(
            "Scorecard does not match run directory "
            f"{run_dir} ({scorecard_path}): " + "; ".join(errors)
        )


def sorted_phase_receipts(path: Path) -> list[dict[str, Any]]:
    payload = load_json(path)
    if not isinstance(payload, dict) or not isinstance(payload.get("receipts"), list):
        raise SystemExit(f"Missing or invalid phase receipt JSON: {path}")
    rows = [row for row in payload["receipts"] if isinstance(row, dict)]
    return sorted(rows, key=lambda row: int(row.get("receipt_order") or 0))


def token_totals_from_model_metrics(model_metrics: Any) -> dict[str, Any] | None:
    if not isinstance(model_metrics, dict) or not model_metrics:
        return None
    totals = {field: 0 for field in NORMALIZED_TOKEN_FIELDS}
    model_rows: dict[str, Any] = {}
    requested_field_sets: list[set[str]] = []
    requested_models: list[str] = []
    for model, payload in model_metrics.items():
        if not isinstance(payload, dict):
            continue
        requests = payload.get("requests") if isinstance(payload.get("requests"), dict) else {}
        usage = payload.get("usage") if isinstance(payload.get("usage"), dict) else {}
        request_count = int(requests.get("count", 0) or 0)
        present = [field for field in RAW_TOKEN_FIELDS if field in usage]
        missing = [field for field in RAW_TOKEN_FIELDS if field not in usage]
        if request_count > 0:
            requested_models.append(str(model))
            requested_field_sets.append(set(present))
        row = {
            "request_count": request_count,
            "direct_provider_token_fields_present": present,
            "missing_direct_provider_token_fields": missing,
        }
        for raw_field, normalized in DIRECT_PROVIDER_TOKEN_FIELDS.items():
            value = int(usage.get(raw_field, 0) or 0)
            totals[normalized] += value
            row[normalized] = value
        row["direct_provider_token_count"] = sum(row[field] for field in NORMALIZED_TOKEN_FIELDS)
        model_rows[str(model)] = row
    present_set = set.intersection(*requested_field_sets) if requested_field_sets else set()
    missing_fields = [field for field in RAW_TOKEN_FIELDS if field not in present_set]
    return {
        "requested_models": requested_models,
        "direct_provider_token_fields_present": [
            field for field in RAW_TOKEN_FIELDS if field in present_set
        ],
        "missing_direct_provider_token_fields": missing_fields,
        "model_direct_provider_token_fields": model_rows,
        **totals,
        "direct_provider_token_count": sum(totals.values()),
    }


def collect_direct_snapshots(session_log_path: Path) -> list[dict[str, Any]]:
    if not session_log_path.exists():
        return []
    snapshots: list[dict[str, Any]] = []
    for line_number, raw_line in enumerate(
        session_log_path.read_text(encoding="utf-8", errors="ignore").splitlines(),
        start=1,
    ):
        if not raw_line.strip():
            continue
        try:
            event = json.loads(raw_line)
        except json.JSONDecodeError:
            continue
        data = event.get("data") if isinstance(event, dict) else {}
        if not isinstance(data, dict) or "modelMetrics" not in data:
            continue
        timestamp = parse_iso(str(event.get("timestamp") or ""))
        totals = token_totals_from_model_metrics(data.get("modelMetrics"))
        if totals is None:
            continue
        snapshots.append(
            {
                "line_number": line_number,
                "event_type": event.get("type"),
                "timestamp": event.get("timestamp"),
                "timestamp_epoch": timestamp.timestamp() if timestamp else None,
                "direct_fields_complete": not totals["missing_direct_provider_token_fields"],
                **totals,
            }
        )
    return snapshots


def latest_snapshot_at_or_before(
    snapshots: list[dict[str, Any]],
    receipt_time: dt.datetime | None,
) -> dict[str, Any] | None:
    if receipt_time is None:
        return None
    eligible = [
        snapshot
        for snapshot in snapshots
        if isinstance(snapshot.get("timestamp_epoch"), (int, float))
        and snapshot["timestamp_epoch"] <= receipt_time.timestamp()
        and snapshot.get("direct_fields_complete") is True
    ]
    return eligible[-1] if eligible else None


def check_scorecard(scorecard_path: Path, scorecard: dict[str, Any]) -> dict[str, Any]:
    errors: list[str] = []
    token_usage = scorecard.get("token_usage")
    experiment = scorecard.get("experiment")
    if not isinstance(token_usage, dict):
        errors.append("token_usage object is missing or malformed")
        token_usage = {}
    if not isinstance(experiment, dict):
        errors.append("experiment object is missing or malformed")
        experiment = {}

    present = string_list(
        token_usage.get("direct_provider_token_fields_present"),
        "direct_provider_token_fields_present",
        errors,
    )
    missing = string_list(
        token_usage.get("missing_direct_provider_token_fields"),
        "missing_direct_provider_token_fields",
        errors,
    )
    for field in RAW_TOKEN_FIELDS:
        if field not in present:
            errors.append(f"direct provider token field missing from scorecard: {field}")
        if field in missing:
            errors.append(f"direct provider token field reported missing: {field}")

    equality = experiment.get("prompt_equality")
    if not isinstance(equality, dict):
        errors.append("prompt_equality object is missing or malformed")
        equality = {}
    retained_sha = equality.get("retained_prompt_sha256")
    current_sha = equality.get("current_renderer_sha256")
    if equality.get("available") is not True:
        errors.append("prompt equality comparison is unavailable")
    if not isinstance(retained_sha, str) or not SHA256_RE.match(retained_sha):
        errors.append("retained prompt hash is missing or invalid")
    if not isinstance(current_sha, str) or not SHA256_RE.match(current_sha):
        errors.append("current renderer hash is missing or invalid")
    reported_match = equality.get("matches_current_renderer")
    derived_match = retained_sha == current_sha if retained_sha and current_sha else None
    if not isinstance(reported_match, bool):
        errors.append("prompt equality match boolean is missing")
    elif derived_match is not None and reported_match is not derived_match:
        errors.append("prompt equality match boolean disagrees with retained/current hashes")

    return {
        "pass": not errors,
        "errors": errors,
        "prompt_equality_matches_current_renderer": reported_match,
        "scorecard_path": str(scorecard_path),
        "scorecard_sha256": stable_scorecard_sha256(scorecard),
        "scorecard_file_sha256": sha256_path(scorecard_path),
        "scorecard_hash_method": "stable_json_without_generated_at_with_repo_paths_normalized",
    }


def build_transition_deltas(
    boundary_rows: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    deltas: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []
    for previous, current in zip(boundary_rows, boundary_rows[1:]):
        prev_snapshot = previous.get("matched_snapshot")
        curr_snapshot = current.get("matched_snapshot")
        transition = f"{previous.get('phase_id')} -> {current.get('phase_id')}"
        if not prev_snapshot or not curr_snapshot:
            errors.append({"transition": transition, "reason": "missing direct snapshot at one or both phase boundaries"})
            continue
        if prev_snapshot.get("line_number") == curr_snapshot.get("line_number"):
            errors.append({"transition": transition, "reason": "same cumulative snapshot matched both phase boundaries"})
            continue
        delta: dict[str, Any] = {}
        negative_fields: list[str] = []
        for field in NORMALIZED_TOKEN_FIELDS:
            value = int(curr_snapshot.get(field, 0) or 0) - int(prev_snapshot.get(field, 0) or 0)
            delta[field] = value
            if value < 0:
                negative_fields.append(field)
        if negative_fields:
            errors.append(
                {
                    "transition": transition,
                    "reason": "non-monotonic token counters",
                    "negative_fields": negative_fields,
                }
            )
            continue
        delta["direct_provider_token_count"] = sum(delta[field] for field in NORMALIZED_TOKEN_FIELDS)
        deltas.append(
            {
                "transition": transition,
                "from_phase_id": previous.get("phase_id"),
                "to_phase_id": current.get("phase_id"),
                "from_snapshot_line": prev_snapshot.get("line_number"),
                "to_snapshot_line": curr_snapshot.get("line_number"),
                "delta": delta,
            }
        )
    return deltas, errors


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    rows: list[dict[str, Any]] = []
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if not raw.strip():
            continue
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if isinstance(payload, dict):
            rows.append(payload)
    return rows


def phase_metrics_path_for(run_dir: Path, explicit: Path | None) -> Path | None:
    if explicit is not None:
        if not explicit.exists():
            raise SystemExit(f"Missing explicit phase-session metrics file: {explicit}")
        return explicit
    candidate = run_dir / "session" / "phase-session-metrics.jsonl"
    return candidate if candidate.exists() else None


def token_usage_from_phase_metric(row: dict[str, Any]) -> dict[str, Any]:
    usage = row.get("token_usage") if isinstance(row.get("token_usage"), dict) else {}
    totals = {
        "input_tokens": int(usage.get("input_tokens", 0) or 0),
        "output_tokens": int(usage.get("output_tokens", 0) or 0),
        "cache_read_tokens": int(usage.get("cache_read_tokens", 0) or 0),
        "cache_write_tokens": int(usage.get("cache_write_tokens", 0) or 0),
        "reasoning_tokens": int(usage.get("reasoning_tokens", 0) or 0),
    }
    model_breakdown = usage.get("model_breakdown") if isinstance(usage.get("model_breakdown"), dict) else {}
    if model_breakdown and not any(totals.values()):
        for payload in model_breakdown.values():
            if not isinstance(payload, dict):
                continue
            totals["input_tokens"] += int(payload.get("input_tokens", 0) or 0)
            totals["output_tokens"] += int(payload.get("output_tokens", 0) or 0)
            totals["cache_read_tokens"] += int(payload.get("cache_read_tokens", 0) or 0)
            totals["cache_write_tokens"] += int(payload.get("cache_write_tokens", 0) or 0)
            totals["reasoning_tokens"] += int(payload.get("reasoning_tokens", 0) or 0)
    totals["direct_provider_token_count"] = sum(totals.values())
    return {
        **totals,
        "model_breakdown": model_breakdown,
        "direct_provider_token_fields_present": usage.get("direct_provider_token_fields_present", []),
        "missing_direct_provider_token_fields": usage.get("missing_direct_provider_token_fields", []),
        "source": usage.get("source"),
    }


def build_phase_invocation_deltas(
    metric_rows: list[dict[str, Any]],
    receipt_rows: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    receipt_order = {
        str(row.get("phase_id")): int(row.get("receipt_order") or index)
        for index, row in enumerate(receipt_rows, start=1)
        if row.get("phase_id")
    }
    rows_by_phase: dict[str, list[dict[str, Any]]] = {}
    for index, row in enumerate(metric_rows):
        phase_id = str(row.get("phase_id") or "")
        if phase_id not in receipt_order:
            continue
        enriched = {**row, "_metric_row_index": index}
        rows_by_phase.setdefault(phase_id, []).append(enriched)

    selected_metrics: list[dict[str, Any]] = []
    for phase_id, rows in rows_by_phase.items():
        successful = [row for row in rows if row.get("exit_code") == 0]
        candidates = successful or rows
        selected = sorted(
            candidates,
            key=lambda row: (str(row.get("ended_at_utc") or ""), int(row.get("_metric_row_index") or 0)),
        )[-1]
        selected["_superseded_metric_row_count"] = len(rows) - 1
        selected["_selected_metric_row_status"] = "final_successful" if successful else "final_attempt"
        selected_metrics.append(selected)

    ordered_metrics = sorted(
        selected_metrics,
        key=lambda row: receipt_order[str(row.get("phase_id"))],
    )
    coverage: list[dict[str, Any]] = []
    deltas: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []
    previous_phase_id: str | None = None
    complete_phase_ids: list[str] = []
    for row in ordered_metrics:
        phase_id = str(row.get("phase_id"))
        token_usage = token_usage_from_phase_metric(row)
        direct_complete = (
            row.get("exit_code") == 0
            and token_usage.get("source") == "session.shutdown.modelMetrics"
            and not token_usage.get("missing_direct_provider_token_fields")
        )
        if direct_complete:
            complete_phase_ids.append(phase_id)
        coverage.append(
            {
                "phase_id": phase_id,
                "receipt_order": receipt_order[phase_id],
                "selected_metric_row_status": row.get("_selected_metric_row_status"),
                "superseded_metric_row_count": row.get("_superseded_metric_row_count", 0),
                "exit_code": row.get("exit_code"),
                "session_log_path": row.get("session_log_path"),
                "session_log_sha256": row.get("session_log_sha256"),
                "direct_provider_token_count": token_usage["direct_provider_token_count"],
                "direct_fields_complete": direct_complete,
            }
        )
        if previous_phase_id is None:
            previous_phase_id = phase_id
            continue
        transition = f"{previous_phase_id} -> {phase_id}"
        if not direct_complete:
            errors.append({"transition": transition, "reason": "phase metric row lacks complete direct provider fields"})
            previous_phase_id = phase_id
            continue
        deltas.append(
            {
                "transition": transition,
                "from_phase_id": previous_phase_id,
                "to_phase_id": phase_id,
                "delta": {
                    "input_tokens": token_usage["input_tokens"],
                    "output_tokens": token_usage["output_tokens"],
                    "cache_read_tokens": token_usage["cache_read_tokens"],
                    "cache_write_tokens": token_usage["cache_write_tokens"],
                    "reasoning_tokens": token_usage["reasoning_tokens"],
                    "direct_provider_token_count": token_usage["direct_provider_token_count"],
                    "model_breakdown": token_usage["model_breakdown"],
                },
                "delta_method": "direct_provider_per_phase_session_shutdown",
                "phase_session_log_sha256": row.get("session_log_sha256"),
            }
        )
        previous_phase_id = phase_id
    if len(set(complete_phase_ids)) < 2:
        errors.append(
            {
                "reason": "fewer than two distinct successful phase ids have complete direct provider fields",
                "complete_phase_ids": complete_phase_ids,
            }
        )
        deltas = []
    return deltas, errors, coverage


def evaluate_run(
    run_dir: Path,
    scorecard_path: Path,
    expected_positive: bool,
    phase_metrics_path: Path | None = None,
) -> dict[str, Any]:
    run_dir = run_dir.resolve()
    scorecard_path = scorecard_path.resolve()
    metadata = run_metadata(run_dir)
    scorecard = load_scorecard(scorecard_path)
    receipts_path = phase_receipts_path(run_dir, metadata)
    validate_scorecard_binding(run_dir, scorecard_path, scorecard, metadata, receipts_path)
    scorecard_check = check_scorecard(scorecard_path, scorecard)
    receipt_rows = sorted_phase_receipts(receipts_path)
    snapshots = collect_direct_snapshots(run_dir / "session" / "events.jsonl")
    metrics_path = phase_metrics_path_for(run_dir, phase_metrics_path)
    metric_rows = read_jsonl(metrics_path) if metrics_path else []
    if metric_rows:
        deltas, delta_errors, boundary_rows = build_phase_invocation_deltas(
            metric_rows,
            receipt_rows,
        )
        telemetry_method = "direct_provider_per_phase_session_shutdown"
    else:
        boundary_rows = []
        for row in receipt_rows:
            recorded_at = parse_iso(str(row.get("recorded_at_utc") or ""))
            snapshot = latest_snapshot_at_or_before(snapshots, recorded_at)
            boundary_rows.append(
                {
                    "phase_id": row.get("phase_id"),
                    "receipt_order": row.get("receipt_order"),
                    "recorded_at_utc": row.get("recorded_at_utc"),
                    "matched_snapshot": (
                        {
                            "line_number": snapshot.get("line_number"),
                            "event_type": snapshot.get("event_type"),
                            "timestamp": snapshot.get("timestamp"),
                            "direct_provider_token_count": snapshot.get("direct_provider_token_count"),
                        }
                        if snapshot
                        else None
                    ),
                }
            )
        deltas, delta_errors = build_transition_deltas(boundary_rows)
        telemetry_method = "direct_provider_modelMetrics_cumulative_snapshot_delta"
    direct_snapshot_count = sum(1 for snapshot in snapshots if snapshot.get("direct_fields_complete") is True)
    boundary_snapshot_count = (
        sum(1 for row in boundary_rows if row.get("direct_fields_complete"))
        if metric_rows
        else sum(1 for row in boundary_rows if row.get("matched_snapshot"))
    )
    prompt_matches = scorecard_check.get("prompt_equality_matches_current_renderer") is True
    qualified = scorecard_check["pass"] and prompt_matches and bool(deltas)
    reason = None
    if not qualified:
        if not scorecard_check["pass"]:
            reason = "scorecard failed direct token or prompt equality checks"
        elif not metric_rows and direct_snapshot_count < 2:
            reason = "fewer than two direct provider modelMetrics snapshots exist in the session log"
        elif boundary_snapshot_count < 2:
            reason = "direct provider snapshots do not exist at two or more phase receipt boundaries"
        elif not deltas:
            reason = "direct provider snapshots could not produce phase transition deltas"
        elif not prompt_matches:
            reason = "prompt equality does not match current renderer"

    return {
        "run_id": run_dir.name,
        "run_dir": str(run_dir),
        "scorecard_path": str(scorecard_path),
        "expected_positive": expected_positive,
        "scorecard_check": scorecard_check,
        "phase_receipts_path": str(receipts_path),
        "phase_receipts_sha256": sha256_path(receipts_path),
        "session_log_path": str(run_dir / "session" / "events.jsonl"),
        "session_log_sha256": sha256_path(run_dir / "session" / "events.jsonl"),
        "phase_session_metrics_path": str(metrics_path) if metrics_path else None,
        "phase_session_metrics_sha256": sha256_path(metrics_path) if metrics_path else None,
        "phase_token_delta_method": telemetry_method,
        "direct_model_metrics_snapshot_count": len(snapshots),
        "direct_complete_snapshot_count": direct_snapshot_count,
        "phase_session_metric_row_count": len(metric_rows),
        "phase_receipt_count": len(receipt_rows),
        "phase_boundary_snapshot_count": boundary_snapshot_count,
        "direct_phase_token_telemetry_available": qualified,
        "qualification_reason": reason,
        "phase_boundary_snapshot_coverage": boundary_rows,
        "phase_transition_token_deltas": deltas,
        "phase_transition_delta_errors": delta_errors,
        "rejected_as_expected": (not expected_positive) and (not qualified),
    }


def paired_positive_runs(args: argparse.Namespace) -> list[tuple[Path, Path, Path | None]]:
    run_dirs = [Path(path).expanduser() for path in args.run_dir]
    scorecards = [Path(path).expanduser() for path in args.scorecard]
    metrics_paths = [Path(path).expanduser() for path in args.phase_session_metrics]
    if scorecards and len(scorecards) != len(run_dirs):
        raise SystemExit("--scorecard count must match --run-dir count when supplied")
    if metrics_paths and len(metrics_paths) != len(run_dirs):
        raise SystemExit("--phase-session-metrics count must match --run-dir count when supplied")
    return [
        (
            run_dir,
            scorecards[idx] if scorecards else run_dir / "run-scorecard.json",
            metrics_paths[idx] if metrics_paths else None,
        )
        for idx, run_dir in enumerate(run_dirs)
    ]


def main() -> int:
    args = parse_args()
    positives = [
        evaluate_run(run_dir, scorecard, True, metrics_path)
        for run_dir, scorecard, metrics_path in paired_positive_runs(args)
    ]
    negatives = [
        evaluate_run(Path(run_dir).expanduser(), Path(scorecard).expanduser(), False)
        for run_dir, scorecard in args.negative_control
    ]
    positive_receipts_valid = all(row["scorecard_check"]["pass"] for row in positives)
    negative_controls_pass = all(row["rejected_as_expected"] for row in negatives)
    qualified_runs = [row for row in positives if row["direct_phase_token_telemetry_available"]]
    payload = {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "receipt_type": "newsletter_phase_token_telemetry",
        "pass": positive_receipts_valid and negative_controls_pass,
        "receipt_result": (
            "qualified_direct_phase_token_deltas"
            if len(qualified_runs) == len(positives)
            else "fail_closed_no_phase_boundary_provider_snapshots"
        ),
        "direct_phase_token_telemetry_available": len(qualified_runs) == len(positives),
        "positive_scorecards_pass": positive_receipts_valid,
        "negative_controls_pass": negative_controls_pass,
        "negative_control_count": len(negatives),
        "required_event_shape": {
            "description": (
                "At least two cumulative direct provider modelMetrics snapshots with "
                "timestamps at or before distinct phase receipt boundaries."
            ),
            "required_provider_fields": RAW_TOKEN_FIELDS,
            "forbidden_methods": [
                "receipt-span proportional estimates",
                "wall-clock allocation",
                "whole-run shutdown-only token allocation",
            ],
        },
        "runs": positives,
        "negative_controls": negatives,
        "non_claims": [
            "This receipt does not claim production stop-gate adoption.",
            "This receipt does not claim durable dollar-cost savings.",
            "This receipt does not claim durable token-count savings unless direct phase-local deltas are qualified.",
            "Whole-run session.shutdown token metrics are direct run telemetry but not phase-boundary telemetry.",
            "No proxy, proportional, or wall-clock token allocation is used.",
        ],
    }
    raw_output = str(Path(args.output).expanduser())
    output_path = Path(args.output).expanduser().resolve()
    write_json(output_path, payload)
    if raw_output not in {"/dev/stdout", "/dev/stderr"}:
        print(args.output)
    return 0 if payload["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

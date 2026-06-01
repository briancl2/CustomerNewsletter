#!/usr/bin/env python3
"""Prove retained Phase 1C and Phase 3 stop gates against failed/passing runs."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
from pathlib import Path
from typing import Any

from newsletter_experiment_common import (
    estimate_costs,
    load_json,
    sha256_path,
    stable_scorecard_sha256,
    write_json,
)
from product_run_common import logical_artifact_map
from build_phase_token_telemetry_receipt import evaluate_run as evaluate_phase_token_telemetry_run

REPO_ROOT = Path(__file__).resolve().parent.parent
PHASE1C_RATIO_FLOOR = 0.08


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--failed-run", required=True, help="Retained failed product run directory")
    parser.add_argument("--passing-run", required=True, help="Retained passing product run directory")
    parser.add_argument(
        "--failed-scorecard",
        help="Scorecard JSON for the failed run (default: <failed-run>/run-scorecard.json)",
    )
    parser.add_argument(
        "--passing-scorecard",
        help="Scorecard JSON for the passing run (default: <passing-run>/run-scorecard.json)",
    )
    parser.add_argument(
        "--phase-token-telemetry",
        help="Optional phase-boundary token telemetry receipt from build_phase_token_telemetry_receipt.py",
    )
    parser.add_argument(
        "--pricing-snapshot",
        help="Optional public API pricing snapshot for direct phase-local dollar lower bounds",
    )
    parser.add_argument("--output", required=True, help="Stop-gate receipt output path")
    return parser.parse_args()


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="ignore")


def require_existing(path: Path, label: str) -> None:
    if not path.exists():
        raise SystemExit(f"Missing required Phase 1C input {label}: {path}")


def contains_version_ref(path: Path, version: str) -> bool:
    text = read_text(path).lower()
    if not text:
        return False
    normalized = version.lower().lstrip("v")
    slug = "v" + normalized.replace(".", "_")
    return normalized in text or slug in text


def count_heading_items(paths: list[Path]) -> int:
    count = 0
    for path in paths:
        for line in read_text(path).splitlines():
            if line.startswith("### "):
                count += 1
    return count


def run_metadata(run_dir: Path) -> dict[str, Any]:
    payload = load_json(run_dir / "run-metadata.json")
    if not isinstance(payload, dict):
        raise SystemExit(f"Missing run-metadata.json in {run_dir}")
    return payload


def artifact_root(run_dir: Path, metadata: dict[str, Any]) -> Path:
    local_root = run_dir / "artifacts"
    if local_root.exists():
        return local_root.resolve()
    root = Path(str(metadata.get("artifact_root") or run_dir / "artifacts")).expanduser()
    if not root.is_absolute():
        root = REPO_ROOT / root
    return root.resolve()


def artifact_paths(run_dir: Path) -> dict[str, Any]:
    metadata = run_metadata(run_dir)
    start = str(metadata["start"])
    end = str(metadata["end"])
    root = artifact_root(run_dir, metadata)
    logical = logical_artifact_map(start, end)
    return {
        "metadata": metadata,
        "start": start,
        "end": end,
        "mode": metadata.get("mode"),
        "artifact_root": root,
        "paths": {name: root / rel for name, rel in logical.items()},
    }


def receipt_rows(info: dict[str, Any]) -> dict[str, dict[str, Any]]:
    path = info["paths"]["receipts"]
    payload = load_json(path)
    if not isinstance(payload, dict) or not isinstance(payload.get("receipts"), list):
        raise SystemExit(f"Missing or invalid phase receipt JSON: {path}")
    rows = {
        str(row.get("phase_id")): row
        for row in payload["receipts"]
        if isinstance(row, dict) and row.get("phase_id")
    }
    return rows


def verify_receipt_hashes(info: dict[str, Any], phase_ids: list[str]) -> None:
    rows = receipt_rows(info)
    root = info["artifact_root"]
    for phase_id in phase_ids:
        row = rows.get(phase_id)
        if not row:
            raise SystemExit(f"Missing retained phase receipt row: {phase_id}")
        rel_path = row.get("artifact_path")
        expected_sha = row.get("artifact_sha256")
        if not rel_path or not expected_sha:
            raise SystemExit(f"Phase receipt row missing path or hash: {phase_id}")
        path = root / str(rel_path)
        require_existing(path, phase_id)
        actual_sha = sha256_path(path)
        if actual_sha != expected_sha:
            raise SystemExit(
                f"Phase receipt hash mismatch for {phase_id}: {actual_sha} != {expected_sha}"
            )


def expected_versions(scope_contract: Path) -> list[str]:
    payload = load_json(scope_contract)
    if not isinstance(payload, dict):
        raise SystemExit(f"Missing or invalid scope contract JSON: {scope_contract}")
    expected = payload.get("expected_versions")
    if not isinstance(expected, dict):
        raise SystemExit(f"Invalid scope contract expected_versions object: {scope_contract}")
    versions = expected.get("vscode")
    if not isinstance(versions, list):
        raise SystemExit(f"Invalid scope contract expected_versions.vscode list: {scope_contract}")
    return [str(item).strip().lstrip("v") for item in versions if str(item).strip()]


def phase1c_checkpoint(run_dir: Path) -> dict[str, Any]:
    info = artifact_paths(run_dir)
    paths = info["paths"]
    verify_receipt_hashes(
        info,
        [
            "phase0_scope_contract",
            "phase1b_github",
            "phase1b_vscode",
            "phase1b_visualstudio",
            "phase1b_jetbrains",
            "phase1b_xcode",
            "phase1c_discoveries",
        ],
    )
    phase1b_files = [
        paths["phase1b_github"],
        paths["phase1b_vscode"],
        paths["phase1b_visualstudio"],
        paths["phase1b_jetbrains"],
        paths["phase1b_xcode"],
    ]
    # Phase 1C writes the historical phase1a_discoveries filename for compatibility.
    phase1c_discoveries = paths["discoveries"]
    require_existing(paths["scope_contract"], "scope_contract")
    require_existing(phase1c_discoveries, "phase1c_discoveries")
    for phase1b_file in phase1b_files:
        require_existing(phase1b_file, "phase1b_file")

    phase1b_count = count_heading_items(phase1b_files)
    discoveries_count = count_heading_items([phase1c_discoveries])
    raw_ratio = None
    ratio = None
    if phase1b_count > 0:
        raw_ratio = discoveries_count / phase1b_count
        ratio = round(raw_ratio, 4)

    versions = expected_versions(paths["scope_contract"])
    missing_versions = [
        version for version in versions if not contains_version_ref(phase1c_discoveries, version)
    ]
    ratio_unavailable_stop = phase1b_count == 0
    ratio_stop = ratio_unavailable_stop or (
        raw_ratio is not None and raw_ratio < PHASE1C_RATIO_FLOOR
    )
    version_stop = bool(missing_versions)
    stop = ratio_stop or version_stop
    return {
        "gate": "proposed_strict_phase1c_stop_gate",
        "gate_basis": "proposed early-stop checkpoint, stricter than the current strict validator warning path",
        "result": "stop" if stop else "continue",
        "available_at_stop": True,
        "phase1b_heading_items": phase1b_count,
        "phase1c_discovery_headings": discoveries_count,
        "continuity_ratio": ratio,
        "continuity_ratio_floor": PHASE1C_RATIO_FLOOR,
        "continuity_ratio_unavailable_stop": ratio_unavailable_stop,
        "ratio_stop": ratio_stop,
        "expected_vscode_versions": versions,
        "missing_phase1c_vscode_versions": missing_versions,
        "version_signal_stop": version_stop,
        "current_validator_alignment": {
            "current_strict_validator_ratio_behavior": (
                "skips the continuity ratio check when headings are uncountable"
            ),
            "current_strict_validator_phase1c_version_behavior": (
                "warns on missing Phase 1C VS Code version references"
            ),
            "receipt_behavior": (
                "treats low continuity ratio or missing Phase 1C VS Code version "
                "references as a proposed early stop"
            ),
        },
        "input_artifacts": {
            "scope_contract": str(paths["scope_contract"]),
            "phase1c_discoveries": str(phase1c_discoveries),
            "phase1b_files": [str(path) for path in phase1b_files],
            "legacy_filename_note": (
                "Phase 1C content consolidation uses the newsletter_phase1a_discoveries "
                "filename for compatibility."
            ),
        },
    }


def benchmark_mode_for(metadata: dict[str, Any]) -> str | None:
    if metadata.get("benchmark_mode"):
        return str(metadata["benchmark_mode"])
    if metadata.get("mode") == "benchmark":
        if metadata.get("start") == "2025-12-05" and metadata.get("end") == "2026-02-13":
            return "feb2026_consistency"
        raise SystemExit(
            "Benchmark run metadata is missing benchmark_mode for "
            f"{metadata.get('start')} to {metadata.get('end')}"
        )
    return None


def phase3_checkpoint(run_dir: Path) -> dict[str, Any]:
    info = artifact_paths(run_dir)
    paths = info["paths"]
    metadata = info["metadata"]
    verify_receipt_hashes(info, ["phase3_working_set", "phase3_curated"])
    cmd = [
        "python3",
        "tools/validate_phase3_curated.py",
        info["start"],
        info["end"],
        str(paths["phase3_curated"]),
        "--working-set",
        str(paths["phase3_working_set"]),
    ]
    benchmark_mode = benchmark_mode_for(metadata)
    if benchmark_mode:
        cmd.extend(["--benchmark-mode", benchmark_mode])
    completed = subprocess.run(
        cmd,
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    stop = completed.returncode != 0
    failures = [
        line.strip()
        for line in (completed.stdout + "\n" + completed.stderr).splitlines()
        if line.strip().startswith("FAIL:")
    ]
    return {
        "gate": "phase3_curated_contract",
        "result": "stop" if stop else "continue",
        "available_at_stop": True,
        "exit_code": completed.returncode,
        "command": cmd,
        "benchmark_mode": benchmark_mode,
        "stdout": completed.stdout.strip(),
        "stderr": completed.stderr.strip(),
        "failures": failures,
        "input_artifacts": {
            "phase3_working_set": str(paths["phase3_working_set"]),
            "phase3_curated": str(paths["phase3_curated"]),
        },
    }


def load_scorecard(path: Path) -> dict[str, Any]:
    payload = load_json(path)
    if not isinstance(payload, dict):
        raise SystemExit(f"Missing or invalid scorecard JSON: {path}")
    return payload


def retained_run_identity(path: Path, run_id: str) -> Path | None:
    parts = path.expanduser().parts
    for idx in range(len(parts) - 2):
        if parts[idx] == "runs" and parts[idx + 1] == "product_runs":
            return Path(*parts[idx:])
    if path.name == run_id:
        return Path("runs") / "product_runs" / run_id
    return None


def validate_scorecard_binding(
    run_dir: Path,
    scorecard_path: Path,
    scorecard: dict[str, Any],
) -> None:
    metadata = run_metadata(run_dir)
    errors: list[str] = []
    if scorecard.get("run_id") != run_dir.name:
        errors.append(f"run_id {scorecard.get('run_id')!r} != {run_dir.name!r}")
    scorecard_run_dir = scorecard.get("run_dir")
    if not scorecard_run_dir:
        errors.append("run_dir is missing")
    else:
        bound_run_dir = Path(str(scorecard_run_dir)).expanduser().resolve()
        bound_identity = retained_run_identity(bound_run_dir, run_dir.name)
        run_identity = retained_run_identity(run_dir.resolve(), run_dir.name)
        if bound_identity != run_identity:
            errors.append(f"run_dir identity {bound_identity} != {run_identity}")
    for field in ("start", "end", "mode"):
        if scorecard.get(field) != metadata.get(field):
            errors.append(
                f"{field} {scorecard.get(field)!r} != run metadata {metadata.get(field)!r}"
            )

    receipts = scorecard.get("phase_receipts")
    if not isinstance(receipts, dict):
        errors.append("phase_receipts object is missing")
    else:
        if not isinstance(receipts.get("ordered_phase_ids"), list):
            errors.append("phase_receipts.ordered_phase_ids list is missing")
        if not isinstance(receipts.get("phase_spans_seconds"), dict):
            errors.append("phase_receipts.phase_spans_seconds object is missing")
        expected_receipt_sha = receipts.get("receipt_file_sha256")
        if not expected_receipt_sha:
            errors.append("phase_receipts.receipt_file_sha256 is missing")
        else:
            receipt_path = artifact_paths(run_dir)["paths"]["receipts"]
            if not receipt_path.exists():
                errors.append(f"phase receipt file is missing: {receipt_path}")
            else:
                actual_receipt_sha = sha256_path(receipt_path)
                if actual_receipt_sha != expected_receipt_sha:
                    errors.append(
                        "phase_receipts.receipt_file_sha256 does not match current "
                        f"workspace receipt file ({actual_receipt_sha} != {expected_receipt_sha})"
                    )

    audit = load_json(run_dir / "audit" / "RUN_AUDIT.json")
    if not isinstance(audit, dict):
        errors.append("audit/RUN_AUDIT.json is missing or invalid")
    else:
        audit_receipts = audit.get("receipts") or {}
        audit_metrics = audit.get("metrics") or {}
        if not isinstance(audit_receipts, dict):
            errors.append("audit receipts object is missing")
        if not isinstance(audit_metrics, dict):
            errors.append("audit metrics object is missing")
        if isinstance(receipts, dict) and isinstance(audit_receipts, dict):
            if receipts.get("ordered_phase_ids") != audit_receipts.get("ordered_phase_ids"):
                errors.append("phase_receipts.ordered_phase_ids does not match run audit")
            if receipts.get("receipt_span_seconds") != audit_receipts.get("receipt_span_seconds"):
                errors.append("phase_receipts.receipt_span_seconds does not match run audit")
        if isinstance(receipts, dict) and isinstance(audit_metrics, dict):
            if receipts.get("phase_spans_seconds") != audit_metrics.get("phase_spans_seconds"):
                errors.append("phase_receipts.phase_spans_seconds does not match run audit")

    if errors:
        raise SystemExit(
            "Scorecard does not match run directory "
            f"{run_dir} ({scorecard_path}): " + "; ".join(errors)
        )


def phase_token_telemetry_by_run(path: Path | None) -> dict[str, dict[str, Any]]:
    if path is None:
        return {}
    payload = load_json(path)
    if not isinstance(payload, dict):
        raise SystemExit(f"Missing or invalid phase-token telemetry receipt: {path}")
    if payload.get("receipt_type") != "newsletter_phase_token_telemetry":
        raise SystemExit(
            "Phase-token telemetry receipt has unexpected receipt_type "
            f"{payload.get('receipt_type')!r}: {path}"
        )
    if payload.get("pass") is not True:
        raise SystemExit(f"Phase-token telemetry receipt did not pass: {path}")
    rows = payload.get("runs")
    if not isinstance(rows, list):
        raise SystemExit(f"Phase-token telemetry receipt missing runs list: {path}")
    by_run: dict[str, dict[str, Any]] = {}
    for row in rows:
        if not isinstance(row, dict) or not row.get("run_id"):
            continue
        run_id = str(row["run_id"])
        if run_id in by_run:
            raise SystemExit(f"Duplicate phase-token telemetry row for run_id {run_id}: {path}")
        by_run[run_id] = row
    return by_run


def validate_phase_token_row_binding(
    run_dir: Path,
    scorecard_path: Path,
    scorecard: dict[str, Any],
    telemetry_row: dict[str, Any],
) -> None:
    errors: list[str] = []
    if telemetry_row.get("run_id") != run_dir.name:
        errors.append(f"run_id {telemetry_row.get('run_id')!r} != {run_dir.name!r}")

    telemetry_run_dir = telemetry_row.get("run_dir")
    if not telemetry_run_dir:
        errors.append("run_dir is missing")
    else:
        telemetry_identity = retained_run_identity(
            Path(str(telemetry_run_dir)).expanduser().resolve(),
            run_dir.name,
        )
        run_identity = retained_run_identity(run_dir.resolve(), run_dir.name)
        if telemetry_identity != run_identity:
            errors.append(f"run_dir identity {telemetry_identity} != {run_identity}")

    scorecard_check = telemetry_row.get("scorecard_check")
    if not isinstance(scorecard_check, dict) or scorecard_check.get("pass") is not True:
        errors.append("scorecard_check is missing or did not pass")
        scorecard_check = {}

    expected_scorecard_sha = scorecard_check.get("scorecard_sha256")
    actual_scorecard_sha = stable_scorecard_sha256(scorecard)
    if expected_scorecard_sha != actual_scorecard_sha:
        errors.append(
            "scorecard_sha256 mismatch "
            f"({expected_scorecard_sha} != {actual_scorecard_sha})"
        )

    expected_scorecard_file_sha = scorecard_check.get("scorecard_file_sha256")
    actual_scorecard_file_sha = sha256_path(scorecard_path)
    if expected_scorecard_file_sha != actual_scorecard_file_sha:
        errors.append(
            "scorecard_file_sha256 mismatch "
            f"({expected_scorecard_file_sha} != {actual_scorecard_file_sha})"
        )

    receipt_path = artifact_paths(run_dir)["paths"]["receipts"]
    expected_receipts_sha = telemetry_row.get("phase_receipts_sha256")
    actual_receipts_sha = sha256_path(receipt_path)
    if expected_receipts_sha != actual_receipts_sha:
        errors.append(
            "phase_receipts_sha256 mismatch "
            f"({expected_receipts_sha} != {actual_receipts_sha})"
        )

    session_path = run_dir / "session" / "events.jsonl"
    expected_session_sha = telemetry_row.get("session_log_sha256")
    actual_session_sha = sha256_path(session_path)
    if expected_session_sha != actual_session_sha:
        errors.append(
            "session_log_sha256 mismatch "
            f"({expected_session_sha} != {actual_session_sha})"
        )

    metrics_path: Path | None = None
    telemetry_method = telemetry_row.get("phase_token_delta_method")
    metrics_path_text = telemetry_row.get("phase_session_metrics_path")
    expected_metrics_sha = telemetry_row.get("phase_session_metrics_sha256")
    if metrics_path_text:
        metrics_path = Path(str(metrics_path_text)).expanduser().resolve()
        if not metrics_path.exists():
            errors.append(f"phase_session_metrics_path is missing: {metrics_path}")
        else:
            actual_metrics_sha = sha256_path(metrics_path)
            if expected_metrics_sha != actual_metrics_sha:
                errors.append(
                    "phase_session_metrics_sha256 mismatch "
                    f"({expected_metrics_sha} != {actual_metrics_sha})"
                )
    elif (
        telemetry_row.get("direct_phase_token_telemetry_available") is True
        and telemetry_method == "direct_provider_per_phase_session_shutdown"
    ):
        errors.append("direct per-phase telemetry is available but phase_session_metrics_path is missing")

    if not errors:
        recomputed = evaluate_phase_token_telemetry_run(
            run_dir,
            scorecard_path,
            True,
            metrics_path,
        )
        for key in (
            "direct_phase_token_telemetry_available",
            "qualification_reason",
            "phase_token_delta_method",
            "phase_session_metrics_sha256",
        ):
            if recomputed.get(key) != telemetry_row.get(key):
                errors.append(
                    f"recomputed telemetry {key} mismatch "
                    f"({recomputed.get(key)!r} != {telemetry_row.get(key)!r})"
                )
        recomputed_deltas = json.dumps(
            recomputed.get("phase_transition_token_deltas") or [],
            sort_keys=True,
            separators=(",", ":"),
        )
        retained_deltas = json.dumps(
            telemetry_row.get("phase_transition_token_deltas") or [],
            sort_keys=True,
            separators=(",", ":"),
        )
        if recomputed_deltas != retained_deltas:
            errors.append("phase_transition_token_deltas do not match recomputed metrics")

    if errors:
        raise SystemExit(
            "Phase-token telemetry row does not match run directory "
            f"{run_dir} ({scorecard_path}): " + "; ".join(errors)
        )


def direct_phase_token_lower_bound(
    scorecard: dict[str, Any],
    first_stop_phase: str,
    telemetry_row: dict[str, Any] | None,
    pricing_snapshot: dict[str, Any] | None = None,
) -> dict[str, Any]:
    if not telemetry_row:
        return {
            "token_count_lower_bound": None,
            "cost_usd_lower_bound": None,
            "token_cost_reason": "No phase-boundary token telemetry receipt was supplied.",
            "phase_token_telemetry_available": False,
        }
    if telemetry_row.get("direct_phase_token_telemetry_available") is not True:
        return {
            "token_count_lower_bound": None,
            "cost_usd_lower_bound": None,
            "token_cost_reason": (
                telemetry_row.get("qualification_reason")
                or "Direct phase-boundary token telemetry is unavailable."
            ),
            "phase_token_telemetry_available": False,
            "phase_token_telemetry_run_id": telemetry_row.get("run_id"),
        }

    receipts = scorecard.get("phase_receipts") or {}
    order = receipts.get("ordered_phase_ids") or []
    if first_stop_phase not in order:
        return {
            "token_count_lower_bound": None,
            "cost_usd_lower_bound": None,
            "token_cost_reason": f"{first_stop_phase} is not in raw retained phase order.",
            "phase_token_telemetry_available": True,
            "phase_token_telemetry_run_id": telemetry_row.get("run_id"),
        }
    index = {phase: idx for idx, phase in enumerate(order)}
    stop_index = index[first_stop_phase]
    eligible_deltas = []
    for row in telemetry_row.get("phase_transition_token_deltas") or []:
        if not isinstance(row, dict):
            continue
        src = row.get("from_phase_id")
        dst = row.get("to_phase_id")
        if src not in index or dst not in index:
            continue
        if index[src] >= stop_index and index[dst] > stop_index:
            eligible_deltas.append(row)

    if not eligible_deltas:
        return {
            "token_count_lower_bound": None,
            "cost_usd_lower_bound": None,
            "token_cost_reason": "No direct phase-token deltas were available after the stop point.",
            "phase_token_telemetry_available": True,
            "phase_token_telemetry_run_id": telemetry_row.get("run_id"),
        }
    token_total = 0
    model_rows: dict[str, dict[str, Any]] = {}
    primary_model = str(scorecard.get("primary_model") or "unknown")
    for row in eligible_deltas:
        delta = row.get("delta") if isinstance(row.get("delta"), dict) else {}
        token_total += int(delta.get("direct_provider_token_count", 0) or 0)
        model_breakdown = delta.get("model_breakdown") if isinstance(delta.get("model_breakdown"), dict) else {}
        if model_breakdown:
            for model, payload in model_breakdown.items():
                if not isinstance(payload, dict):
                    continue
                target = model_rows.setdefault(
                    str(model),
                    {
                        "model": str(model),
                        "request_count": 0,
                        "input_tokens": 0,
                        "output_tokens": 0,
                        "cache_read_tokens": 0,
                        "cache_write_tokens": 0,
                        "reasoning_tokens": 0,
                    },
                )
                target["request_count"] += int(payload.get("request_count", 0) or 0)
                for field in (
                    "input_tokens",
                    "output_tokens",
                    "cache_read_tokens",
                    "cache_write_tokens",
                    "reasoning_tokens",
                ):
                    target[field] += int(payload.get(field, 0) or 0)
        else:
            target = model_rows.setdefault(
                primary_model,
                {
                    "model": primary_model,
                    "request_count": 0,
                    "input_tokens": 0,
                    "output_tokens": 0,
                    "cache_read_tokens": 0,
                    "cache_write_tokens": 0,
                    "reasoning_tokens": 0,
                },
            )
            for field in (
                "input_tokens",
                "output_tokens",
                "cache_read_tokens",
                "cache_write_tokens",
                "reasoning_tokens",
            ):
                target[field] += int(delta.get(field, 0) or 0)
    cost = estimate_costs(
        {
            "primary_model": primary_model,
            "model_breakdown": model_rows,
        },
        pricing_snapshot,
    ) if pricing_snapshot else {"total_usd": None, "priced_models": [], "unpriced_models": list(model_rows)}
    priced_all = bool(model_rows) and not cost.get("unpriced_models") and cost.get("total_usd") is not None
    return {
        "token_count_lower_bound": token_total,
        "cost_usd_lower_bound": cost.get("total_usd") if priced_all else None,
        "token_cost_reason": (
            "Direct phase-local token deltas and public API pricing are available."
            if priced_all
            else "Direct phase-local token deltas are available; dollar lower bounds remain null because pricing is missing or incomplete."
        ),
        "phase_token_telemetry_available": True,
        "phase_token_telemetry_run_id": telemetry_row.get("run_id"),
        "phase_token_delta_count": len(eligible_deltas),
        "phase_token_delta_method": eligible_deltas[0].get(
            "delta_method",
            "direct_provider_modelMetrics_cumulative_snapshot_delta",
        ),
        "cost_estimate_method": (
            "api_equivalent_public_lab_pricing"
            if priced_all
            else "unpriced_or_partially_priced"
        ),
        "cost_model_breakdown": cost.get("model_breakdown", []),
    }


def lower_bound_avoided_work(
    scorecard: dict[str, Any],
    first_stop_phase: str,
    telemetry_row: dict[str, Any] | None = None,
    pricing_snapshot: dict[str, Any] | None = None,
) -> dict[str, Any]:
    receipts = scorecard.get("phase_receipts") or {}
    order = receipts.get("ordered_phase_ids") or []
    spans = (
        receipts.get("phase_spans_seconds")
        or {}
    )
    if first_stop_phase not in order:
        return {
            "available": False,
            "reason": f"{first_stop_phase} is not in raw retained phase order",
            "phase_count_lower_bound": None,
            "wall_clock_seconds_lower_bound": None,
            "token_count_lower_bound": None,
            "cost_usd_lower_bound": None,
        }

    index = {phase: idx for idx, phase in enumerate(order)}
    stop_index = index[first_stop_phase]
    post_stop_phases = [phase for phase in order if index[phase] > stop_index]
    positive_transitions: list[dict[str, Any]] = []
    ignored_transitions: list[dict[str, Any]] = []
    total_seconds = 0
    transition_re = re.compile(r"^(?P<src>[^-]+?)\s*->\s*(?P<dst>.+)$")
    for transition, seconds in spans.items():
        match = transition_re.match(str(transition))
        if not match:
            continue
        src = match.group("src").strip()
        dst = match.group("dst").strip()
        if src not in index or dst not in index or index[src] < stop_index:
            continue
        row = {"transition": transition, "duration_seconds": seconds}
        if isinstance(seconds, (int, float)) and seconds > 0:
            positive_transitions.append(row)
            total_seconds += int(seconds)
        else:
            ignored_transitions.append(row)

    token_lower_bound = direct_phase_token_lower_bound(
        scorecard,
        first_stop_phase,
        telemetry_row,
        pricing_snapshot,
    )
    return {
        "available": True,
        "basis": "retained raw post-stop phase receipt chronology only",
        "first_stop_phase": first_stop_phase,
        "post_stop_phase_ids": post_stop_phases,
        "phase_count_lower_bound": len(post_stop_phases),
        "wall_clock_seconds_lower_bound": total_seconds,
        "positive_transitions": positive_transitions,
        "ignored_non_positive_transitions": ignored_transitions,
        **token_lower_bound,
    }


def evaluate_run(
    run_dir: Path,
    scorecard_path: Path,
    phase_token_rows: dict[str, dict[str, Any]] | None = None,
    pricing_snapshot: dict[str, Any] | None = None,
) -> dict[str, Any]:
    scorecard = load_scorecard(scorecard_path)
    validate_scorecard_binding(run_dir, scorecard_path, scorecard)
    telemetry_row = (phase_token_rows or {}).get(run_dir.name)
    if telemetry_row is not None:
        validate_phase_token_row_binding(run_dir, scorecard_path, scorecard, telemetry_row)
    phase1c = phase1c_checkpoint(run_dir)
    phase3 = phase3_checkpoint(run_dir)
    first_stop_phase = None
    if phase1c["result"] == "stop":
        first_stop_phase = "phase1c_discoveries"
    elif phase3["result"] == "stop":
        first_stop_phase = "phase3_curated"
    return {
        "run_dir": str(run_dir),
        "scorecard_path": str(scorecard_path),
        "scorecard_phase_receipts_matched_run_audit": True,
        "scorecard_sha256": stable_scorecard_sha256(scorecard),
        "scorecard_file_sha256": sha256_path(scorecard_path),
        "scorecard_hash_method": "stable_json_without_generated_at_with_repo_paths_normalized",
        "run_id": run_dir.name,
        "role": None,
        "phase1c_checkpoint": phase1c,
        "phase3_checkpoint": phase3,
        "first_stop_phase": first_stop_phase,
        "stopped": first_stop_phase is not None,
        "avoided_work_lower_bound": (
            lower_bound_avoided_work(
                scorecard,
                first_stop_phase,
                telemetry_row,
                pricing_snapshot,
            )
            if first_stop_phase
            else {
                "available": False,
                "reason": "run did not stop",
                "phase_count_lower_bound": 0,
                "wall_clock_seconds_lower_bound": 0,
                "token_count_lower_bound": None,
                "cost_usd_lower_bound": None,
            }
        ),
    }


def main() -> int:
    args = parse_args()
    failed_run = Path(args.failed_run).expanduser().resolve()
    passing_run = Path(args.passing_run).expanduser().resolve()
    failed_scorecard = (
        Path(args.failed_scorecard).expanduser().resolve()
        if args.failed_scorecard
        else failed_run / "run-scorecard.json"
    )
    passing_scorecard = (
        Path(args.passing_scorecard).expanduser().resolve()
        if args.passing_scorecard
        else passing_run / "run-scorecard.json"
    )
    phase_token_rows = phase_token_telemetry_by_run(
        Path(args.phase_token_telemetry).expanduser().resolve()
        if args.phase_token_telemetry
        else None
    )
    pricing_snapshot = (
        load_json(Path(args.pricing_snapshot).expanduser().resolve())
        if args.pricing_snapshot
        else None
    )
    failed = evaluate_run(failed_run, failed_scorecard, phase_token_rows, pricing_snapshot)
    failed["role"] = "known_failed_run"
    passing = evaluate_run(passing_run, passing_scorecard, phase_token_rows, pricing_snapshot)
    passing["role"] = "known_passing_run"
    failed_phase1c_stopped = (
        failed["first_stop_phase"] == "phase1c_discoveries"
        and failed["phase1c_checkpoint"]["result"] == "stop"
    )
    passing_phase1c_continued = passing["phase1c_checkpoint"]["result"] == "continue"
    pass_result = (
        failed_phase1c_stopped
        and passing_phase1c_continued
        and passing["stopped"] is False
        and failed["avoided_work_lower_bound"].get("available") is True
    )
    payload = {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "receipt_type": "newsletter_stop_gates",
        "pass": pass_result,
        "failed_run_stopped": failed["stopped"],
        "failed_run_phase1c_stopped": failed_phase1c_stopped,
        "passing_run_false_stop": passing["stopped"],
        "passing_run_phase1c_continued": passing_phase1c_continued,
        "runs": [failed, passing],
        "source_hashes": {
            "failed_run_scorecard": failed["scorecard_sha256"],
            "passing_run_scorecard": passing["scorecard_sha256"],
            "failed_run_scorecard_file": failed["scorecard_file_sha256"],
            "passing_run_scorecard_file": passing["scorecard_file_sha256"],
            "phase_token_telemetry_receipt": (
                sha256_path(Path(args.phase_token_telemetry).expanduser().resolve())
                if args.phase_token_telemetry
                else None
            ),
            "pricing_snapshot": (
                sha256_path(Path(args.pricing_snapshot).expanduser().resolve())
                if args.pricing_snapshot
                else None
            ),
            "scorecard_hash_method": "stable_json_without_generated_at_with_repo_paths_normalized",
        },
        "non_claims": [
            "No production stop-policy adoption is claimed.",
            "The Phase 1C checkpoint is a proposed stricter early-stop gate, not proof that the current strict validator already hard-stops there.",
            "No durable dollar-cost savings claim is made.",
            "No durable token-count savings claim is made.",
            "Token and cost lower bounds stay null without direct phase-local token telemetry.",
            "The gate decision uses only data available at the proposed stop point.",
        ],
    }
    raw_output = str(Path(args.output).expanduser())
    output_path = Path(args.output).expanduser().resolve()
    write_json(output_path, payload)
    if raw_output not in {"/dev/stdout", "/dev/stderr"}:
        print(args.output)
    return 0 if pass_result else 1


if __name__ == "__main__":
    raise SystemExit(main())

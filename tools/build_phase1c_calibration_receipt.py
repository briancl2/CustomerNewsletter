#!/usr/bin/env python3
"""Build a labeled Phase 1C calibration receipt for retained proof runs."""

from __future__ import annotations

import argparse
import datetime as dt
from pathlib import Path
from typing import Any

from newsletter_experiment_common import load_json, parse_iso, sha256_path, write_json
from prove_newsletter_stop_gates import (
    evaluate_run,
    load_scorecard,
    phase_token_telemetry_by_run,
)


SNAPSHOT_MAX_AGE_DAYS = 30
WILSON_95_Z = 1.959963984540054
CANDIDATE_PHASE1C_RATIO_FLOOR = 0.1
CANDIDATE_PHASE1C_SEVERE_MISSING_VERSION_COUNT = 4
CANDIDATE_PHASE1C_SEVERE_MISSING_VERSION_RATIO = 0.5
CANDIDATE_PHASE1C_SEVERE_VERSION_RATIO_CEILING = 0.2
MAX_CANDIDATE_FPR_WILSON_UPPER_95 = 0.30
MIN_CANDIDATE_TPR_WILSON_LOWER_95 = 0.40


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--known-stop",
        action="append",
        default=[],
        help="Legacy run directory labeled as a true Phase 1C stop control",
    )
    parser.add_argument(
        "--no-stop",
        action="append",
        default=[],
        help="Legacy run directory labeled as a quality-passing no-stop control",
    )
    parser.add_argument(
        "--fresh-no-stop",
        action="append",
        default=[],
        help="Legacy fresh run directory labeled as a quality-passing no-stop control",
    )
    parser.add_argument(
        "--tuning-known-stop",
        action="append",
        default=[],
        help="Tuning run directory labeled as an independently justified Phase 1C stop",
    )
    parser.add_argument(
        "--holdout-known-stop",
        action="append",
        default=[],
        help="Holdout run directory labeled as an independently justified Phase 1C stop",
    )
    parser.add_argument(
        "--positive-control-known-stop",
        action="append",
        default=[],
        help=(
            "Synthetic or fixture positive-control run directory labeled as a "
            "Phase 1C stop. These rows may satisfy data-acquisition counts, "
            "but remain non-adoption-grade until fresh or non-synthetic "
            "corroboration exists."
        ),
    )
    parser.add_argument(
        "--tuning-no-stop",
        action="append",
        default=[],
        help="Tuning run directory labeled as a quality-passing no-stop control",
    )
    parser.add_argument(
        "--holdout-no-stop",
        action="append",
        default=[],
        help="Holdout run directory labeled as a quality-passing no-stop control",
    )
    parser.add_argument(
        "--fresh-post-repair-acceptance",
        action="append",
        default=[],
        help="Fresh post-repair quality-passing acceptance run directory",
    )
    parser.add_argument(
        "--scorecard",
        nargs=2,
        action="append",
        default=[],
        metavar=("RUN_DIR", "SCORECARD"),
        help="Override scorecard path for a run directory",
    )
    parser.add_argument(
        "--phase-token-telemetry",
        action="append",
        default=[],
        help="Phase-token telemetry receipt; may contain rows for one or more runs",
    )
    parser.add_argument(
        "--pricing-snapshot",
        help="Public API pricing snapshot for direct phase-local dollar lower bounds",
    )
    parser.add_argument("--target-tpr", type=float, default=1.0)
    parser.add_argument("--target-fpr", type=float, default=0.0)
    parser.add_argument("--min-known-stop-count", type=int, default=1)
    parser.add_argument("--min-no-stop-count", type=int, default=3)
    parser.add_argument("--min-fresh-no-stop-count", type=int, default=1)
    parser.add_argument("--min-fresh-post-repair-acceptance-count", type=int, default=0)
    parser.add_argument(
        "--min-model-window-combinations",
        type=int,
        default=2,
        help="Minimum model/window combinations across all quality-passing no-stop controls.",
    )
    parser.add_argument(
        "--min-fresh-model-window-combinations",
        type=int,
        default=0,
        help="Optional minimum model/window combinations across fresh no-stop controls only.",
    )
    parser.add_argument("--require-fresh-pricing", action="store_true")
    parser.add_argument("--require-prompt-equality", action="store_true")
    parser.add_argument("--require-direct-provider-token-fields", action="store_true")
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def utc_now() -> dt.datetime:
    return dt.datetime.now(tz=dt.timezone.utc)


def parse_generated_at(snapshot: dict[str, Any]) -> dt.datetime | None:
    for key in ("generated_at_utc", "generated_at"):
        parsed = parse_iso(str(snapshot.get(key) or ""))
        if parsed is not None:
            return parsed.astimezone(dt.timezone.utc)
    fetched_values = []
    for row in snapshot.get("models", []) if isinstance(snapshot.get("models"), list) else []:
        if isinstance(row, dict):
            parsed = parse_iso(str(row.get("fetched_at") or ""))
            if parsed is not None:
                fetched_values.append(parsed.astimezone(dt.timezone.utc))
    return max(fetched_values) if fetched_values else None


def pricing_status(path: Path | None) -> dict[str, Any]:
    if path is None:
        return {
            "path": None,
            "sha256": None,
            "fresh": False,
            "age_days": None,
            "max_age_days": SNAPSHOT_MAX_AGE_DAYS,
            "reason": "pricing snapshot was not supplied",
        }
    payload = load_json(path)
    if not isinstance(payload, dict):
        raise SystemExit(f"Missing or invalid pricing snapshot: {path}")
    generated_at = parse_generated_at(payload)
    age_days = None
    fresh = False
    reason = "pricing timestamp is missing"
    if generated_at is not None:
        age_days = (utc_now() - generated_at).total_seconds() / 86400
        fresh = age_days <= SNAPSHOT_MAX_AGE_DAYS
        reason = "pricing snapshot is within freshness window" if fresh else "pricing snapshot is stale"
    return {
        "path": str(path),
        "sha256": sha256_path(path),
        "fresh": fresh,
        "age_days": round(age_days, 3) if age_days is not None else None,
        "max_age_days": SNAPSHOT_MAX_AGE_DAYS,
        "reason": reason,
        "model_count": len(payload.get("models", [])) if isinstance(payload.get("models"), list) else 0,
    }


def scorecard_overrides(raw: list[list[str]]) -> dict[Path, Path]:
    mapping: dict[Path, Path] = {}
    for run_dir, scorecard in raw:
        mapping[Path(run_dir).expanduser().resolve()] = Path(scorecard).expanduser().resolve()
    return mapping


def phase_token_rows(paths: list[str]) -> dict[str, dict[str, Any]]:
    rows: dict[str, dict[str, Any]] = {}
    for raw_path in paths:
        path = Path(raw_path).expanduser().resolve()
        for run_id, row in phase_token_telemetry_by_run(path).items():
            if run_id in rows:
                raise SystemExit(f"Duplicate phase-token telemetry row for run_id {run_id}")
            rows[run_id] = row
    return rows


def scorecard_path_for(run_dir: Path, overrides: dict[Path, Path]) -> Path:
    return overrides.get(run_dir.resolve(), run_dir / "run-scorecard.json")


def classification(expected_phase1c_stop: bool, observed_phase1c_stop: bool) -> str:
    if expected_phase1c_stop and observed_phase1c_stop:
        return "true_positive"
    if expected_phase1c_stop:
        return "false_negative"
    if observed_phase1c_stop:
        return "false_positive"
    return "true_negative"


def candidate_phase1c_checkpoint(strict_checkpoint: dict[str, Any]) -> dict[str, Any]:
    versions = strict_checkpoint.get("expected_vscode_versions")
    missing_versions = strict_checkpoint.get("missing_phase1c_vscode_versions")
    versions = versions if isinstance(versions, list) else []
    missing_versions = missing_versions if isinstance(missing_versions, list) else []
    ratio = strict_checkpoint.get("continuity_ratio")
    missing_ratio = len(missing_versions) / len(versions) if versions else None
    ratio_unavailable_stop = strict_checkpoint.get("continuity_ratio_unavailable_stop") is True
    ratio_stop = ratio_unavailable_stop or (
        isinstance(ratio, (int, float)) and ratio < CANDIDATE_PHASE1C_RATIO_FLOOR
    )
    severe_version_stop = (
        len(missing_versions) >= CANDIDATE_PHASE1C_SEVERE_MISSING_VERSION_COUNT
        and missing_ratio is not None
        and missing_ratio >= CANDIDATE_PHASE1C_SEVERE_MISSING_VERSION_RATIO
        and (
            ratio is None
            or (
                isinstance(ratio, (int, float))
                and ratio <= CANDIDATE_PHASE1C_SEVERE_VERSION_RATIO_CEILING
            )
        )
    )
    stop = ratio_stop or severe_version_stop
    return {
        "gate": "evidence_only_candidate_phase1c_stop_gate_v1",
        "gate_basis": (
            "Evidence-only Burst-11 candidate. It narrows the Burst-10 strict "
            "gate to low continuity or severe missing-version collapse; it is "
            "not production policy."
        ),
        "result": "stop" if stop else "continue",
        "available_at_stop": strict_checkpoint.get("available_at_stop") is True,
        "continuity_ratio": ratio,
        "continuity_ratio_floor": CANDIDATE_PHASE1C_RATIO_FLOOR,
        "ratio_stop": ratio_stop,
        "expected_vscode_version_count": len(versions),
        "missing_phase1c_vscode_version_count": len(missing_versions),
        "missing_phase1c_vscode_version_ratio": (
            round(missing_ratio, 6) if missing_ratio is not None else None
        ),
        "severe_missing_version_count_floor": CANDIDATE_PHASE1C_SEVERE_MISSING_VERSION_COUNT,
        "severe_missing_version_ratio_floor": CANDIDATE_PHASE1C_SEVERE_MISSING_VERSION_RATIO,
        "severe_missing_version_ratio_ceiling": CANDIDATE_PHASE1C_SEVERE_VERSION_RATIO_CEILING,
        "severe_version_stop": severe_version_stop,
        "missing_phase1c_vscode_versions": missing_versions,
        "production_policy_adoption": False,
    }


def label_run(
    run_dir: Path,
    expected_phase1c_stop: bool,
    overrides: dict[Path, Path],
    telemetry_rows: dict[str, dict[str, Any]],
    pricing_snapshot: dict[str, Any] | None,
    *,
    fresh_control: bool = False,
    calibration_role: str = "diagnostic",
    fresh_post_repair_acceptance: bool = False,
    provenance_classification: str = "retained_or_fresh_run",
    synthetic_positive_control: bool = False,
) -> dict[str, Any]:
    run_dir = run_dir.expanduser().resolve()
    scorecard_path = scorecard_path_for(run_dir, overrides).expanduser().resolve()
    scorecard = load_scorecard(scorecard_path)
    evaluated = evaluate_run(run_dir, scorecard_path, telemetry_rows, pricing_snapshot)
    quality = scorecard.get("quality") if isinstance(scorecard.get("quality"), dict) else {}
    token_usage = scorecard.get("token_usage") if isinstance(scorecard.get("token_usage"), dict) else {}
    model_window = {
        "primary_model": scorecard.get("primary_model"),
        "mode": scorecard.get("mode"),
        "start": scorecard.get("start"),
        "end": scorecard.get("end"),
    }
    phase1c_stopped = evaluated.get("first_stop_phase") == "phase1c_discoveries"
    candidate_phase1c = candidate_phase1c_checkpoint(evaluated.get("phase1c_checkpoint", {}))
    candidate_phase1c_stopped = candidate_phase1c["result"] == "stop"
    any_stopped = evaluated.get("stopped") is True
    quality_qualified_no_stop_control = None
    if not expected_phase1c_stop:
        quality_qualified_no_stop_control = (
            quality.get("strict_pass") is True
            and quality.get("newsletter_pass") is True
            and quality.get("rubric_pass") is True
        )
    return {
        "run_id": run_dir.name,
        "run_dir": str(run_dir),
        "scorecard_path": str(scorecard_path),
        "scorecard_file_sha256": sha256_path(scorecard_path),
        "label": "known_stop" if expected_phase1c_stop else "known_no_stop",
        "calibration_role": calibration_role,
        "provenance_classification": provenance_classification,
        "synthetic_positive_control": synthetic_positive_control,
        "adoption_grade_control": not synthetic_positive_control,
        "corroboration_required_for_adoption": synthetic_positive_control,
        "fresh_control": fresh_control,
        "fresh_post_repair_acceptance": fresh_post_repair_acceptance,
        "expected_phase1c_stop": expected_phase1c_stop,
        "observed_phase1c_stop": phase1c_stopped,
        "candidate_observed_phase1c_stop": candidate_phase1c_stopped,
        "observed_any_stop": any_stopped,
        "classification": classification(expected_phase1c_stop, phase1c_stopped),
        "candidate_classification": classification(
            expected_phase1c_stop,
            candidate_phase1c_stopped,
        ),
        "first_stop_phase": evaluated.get("first_stop_phase"),
        "phase1c_checkpoint": evaluated.get("phase1c_checkpoint"),
        "candidate_phase1c_checkpoint": candidate_phase1c,
        "phase3_checkpoint": evaluated.get("phase3_checkpoint"),
        "avoided_work_lower_bound": evaluated.get("avoided_work_lower_bound"),
        "quality": {
            "strict_pass": quality.get("strict_pass"),
            "newsletter_pass": quality.get("newsletter_pass"),
            "rubric_pass": quality.get("rubric_pass"),
            "rubric_score": quality.get("rubric_score"),
        },
        "quality_qualified_no_stop_control": quality_qualified_no_stop_control,
        "prompt_equality": (
            scorecard.get("experiment", {}).get("prompt_equality")
            if isinstance(scorecard.get("experiment"), dict)
            else None
        ),
        "direct_provider_token_fields_present": token_usage.get(
            "direct_provider_token_fields_present", []
        ),
        "missing_direct_provider_token_fields": token_usage.get(
            "missing_direct_provider_token_fields", []
        ),
        "phase_token_telemetry_supplied": run_dir.name in telemetry_rows,
        "model_window": model_window,
    }


def model_window_key(row: dict[str, Any]) -> str:
    window = row.get("model_window") if isinstance(row.get("model_window"), dict) else {}
    return "|".join(
        str(window.get(field) or "")
        for field in ("primary_model", "mode", "start", "end")
    )


def rate(numerator: int, denominator: int) -> float | None:
    if denominator == 0:
        return None
    return round(numerator / denominator, 6)


def wilson_interval(successes: int, total: int, z: float = WILSON_95_Z) -> dict[str, Any]:
    if total == 0:
        return {
            "method": "wilson_score_95",
            "successes": successes,
            "total": total,
            "point_estimate": None,
            "lower": None,
            "upper": None,
        }
    phat = successes / total
    denominator = 1 + z * z / total
    center = (phat + z * z / (2 * total)) / denominator
    margin = (
        z
        * ((phat * (1 - phat) + z * z / (4 * total)) / total) ** 0.5
        / denominator
    )
    return {
        "method": "wilson_score_95",
        "successes": successes,
        "total": total,
        "point_estimate": round(phat, 6),
        "lower": round(max(0.0, center - margin), 6),
        "upper": round(min(1.0, center + margin), 6),
    }


def confusion_matrix(
    rows: list[dict[str, Any]],
    *,
    observed_key: str,
    gate_name: str,
    target_tpr: float,
    target_fpr: float,
) -> dict[str, Any]:
    true_positive = 0
    false_negative = 0
    true_negative = 0
    false_positive = 0
    false_positive_run_ids: list[str] = []
    false_negative_run_ids: list[str] = []
    for row in rows:
        observed = bool(row.get(observed_key))
        result = classification(bool(row["expected_phase1c_stop"]), observed)
        if result == "true_positive":
            true_positive += 1
        elif result == "false_negative":
            false_negative += 1
            false_negative_run_ids.append(str(row["run_id"]))
        elif result == "true_negative":
            true_negative += 1
        elif result == "false_positive":
            false_positive += 1
            false_positive_run_ids.append(str(row["run_id"]))
    known_stop_total = true_positive + false_negative
    no_stop_total = true_negative + false_positive
    tpr = rate(true_positive, known_stop_total)
    fpr = rate(false_positive, no_stop_total)
    tpr_interval = wilson_interval(true_positive, known_stop_total)
    fpr_interval = wilson_interval(false_positive, no_stop_total)
    candidate_wilson_target_met = (
        tpr_interval["lower"] is not None
        and fpr_interval["upper"] is not None
        and tpr_interval["lower"] >= MIN_CANDIDATE_TPR_WILSON_LOWER_95
        and fpr_interval["upper"] <= MAX_CANDIDATE_FPR_WILSON_UPPER_95
        and false_negative == 0
    )
    return {
        "gate": gate_name,
        "true_positive": true_positive,
        "false_negative": false_negative,
        "true_negative": true_negative,
        "false_positive": false_positive,
        "true_positive_rate": tpr,
        "false_positive_rate": fpr,
        "true_positive_rate_interval": tpr_interval,
        "false_positive_rate_interval": fpr_interval,
        "gate_meets_target": (
            tpr is not None
            and fpr is not None
            and tpr >= target_tpr
            and fpr <= target_fpr
            and false_negative == 0
        ),
        "preregistered_wilson_target_met": candidate_wilson_target_met,
        "preregistered_wilson_thresholds": {
            "maximum_candidate_gate_false_positive_wilson_upper_95": (
                MAX_CANDIDATE_FPR_WILSON_UPPER_95
            ),
            "minimum_candidate_gate_true_positive_wilson_lower_95": (
                MIN_CANDIDATE_TPR_WILSON_LOWER_95
            ),
        },
        "false_positive_run_ids": false_positive_run_ids,
        "false_negative_run_ids": false_negative_run_ids,
    }


def split_rows(rows: list[dict[str, Any]], role: str) -> list[dict[str, Any]]:
    return [row for row in rows if row.get("calibration_role") == role]


def row_passes_prompt_requirement(row: dict[str, Any]) -> bool:
    if row.get("synthetic_positive_control") is True:
        return True
    prompt_equality = row.get("prompt_equality")
    return (
        isinstance(prompt_equality, dict)
        and prompt_equality.get("available") is True
        and prompt_equality.get("matches_current_renderer") is True
    )


def row_passes_direct_token_requirement(row: dict[str, Any]) -> bool:
    if row.get("synthetic_positive_control") is True:
        return True
    required = {
        "inputTokens",
        "outputTokens",
        "cacheReadTokens",
        "cacheWriteTokens",
        "reasoningTokens",
    }
    present = row.get("direct_provider_token_fields_present")
    missing = row.get("missing_direct_provider_token_fields")
    return isinstance(present, list) and required.issubset(set(present)) and missing == []


def requirement_failures(
    rows: list[dict[str, Any]],
    *,
    require_prompt_equality: bool,
    require_direct_provider_token_fields: bool,
) -> dict[str, list[str]]:
    failures: dict[str, list[str]] = {
        "prompt_equality_failed_run_ids": [],
        "direct_provider_token_fields_failed_run_ids": [],
    }
    if require_prompt_equality:
        failures["prompt_equality_failed_run_ids"] = [
            str(row["run_id"]) for row in rows if not row_passes_prompt_requirement(row)
        ]
    if require_direct_provider_token_fields:
        failures["direct_provider_token_fields_failed_run_ids"] = [
            str(row["run_id"]) for row in rows if not row_passes_direct_token_requirement(row)
        ]
    return failures


def matrix_package(
    rows: list[dict[str, Any]],
    *,
    name: str,
    target_tpr: float,
    target_fpr: float,
) -> dict[str, Any]:
    return {
        "name": name,
        "run_ids": [str(row["run_id"]) for row in rows],
        "strict_current_gate": confusion_matrix(
            rows,
            observed_key="observed_phase1c_stop",
            gate_name="proposed_strict_phase1c_stop_gate",
            target_tpr=target_tpr,
            target_fpr=target_fpr,
        ),
        "evidence_only_candidate_gate": confusion_matrix(
            rows,
            observed_key="candidate_observed_phase1c_stop",
            gate_name="evidence_only_candidate_phase1c_stop_gate_v1",
            target_tpr=target_tpr,
            target_fpr=target_fpr,
        ),
    }


def matrix_meets_target(matrix: dict[str, Any]) -> bool:
    return matrix.get("gate_meets_target") is True


def candidate_repair_status(
    *,
    tuning_matrix: dict[str, Any],
    holdout_matrix: dict[str, Any],
    fresh_matrix: dict[str, Any],
    known_stop_count: int,
    min_known_stop_count: int,
    fresh_acceptance_count: int,
    min_fresh_acceptance_count: int,
    adoption_grade_known_stop_count: int,
    synthetic_positive_control_count: int,
) -> str:
    if not matrix_meets_target(tuning_matrix):
        return "candidate_blocked_tuning_failed"
    if (
        known_stop_count < min_known_stop_count
        and fresh_acceptance_count < min_fresh_acceptance_count
    ):
        return "candidate_blocked_positive_and_fresh_acceptance_insufficient"
    if known_stop_count < min_known_stop_count:
        return "candidate_blocked_positive_class_insufficient"
    if fresh_acceptance_count < min_fresh_acceptance_count:
        return "candidate_fitting_only_no_fresh_acceptance"
    if fresh_acceptance_count and fresh_matrix.get("false_positive", 0) > 0:
        return "candidate_blocked_fresh_acceptance_false_stop"
    if holdout_matrix.get("false_positive", 0) > 0 or holdout_matrix.get("false_negative", 0) > 0:
        return "candidate_blocked_holdout_error"
    if not holdout_matrix.get("run_ids") and fresh_acceptance_count == 0:
        return "candidate_fitting_only_no_independent_acceptance"
    if (
        synthetic_positive_control_count > 0
        and adoption_grade_known_stop_count < min_known_stop_count
    ):
        return "candidate_positive_control_probe_only_corroboration_required"
    return "candidate_evidence_only_holdout_passed"


def receipt_result(
    calibration_complete: bool,
    gate_meets_target: bool,
    known_stop_count: int,
    no_stop_count: int,
    *,
    synthetic_positive_control_count: int = 0,
    adoption_grade_known_stop_count: int | None = None,
    min_known_stop_count: int = 1,
) -> str:
    if known_stop_count == 0:
        return "incomplete_no_known_stop_controls"
    if no_stop_count == 0:
        return "incomplete_no_known_no_stop_controls"
    if not calibration_complete:
        return "incomplete_calibration_set"
    if (
        synthetic_positive_control_count > 0
        and adoption_grade_known_stop_count is not None
        and adoption_grade_known_stop_count < min_known_stop_count
    ):
        return "calibration_complete_positive_control_probe_non_adoption_grade"
    if gate_meets_target:
        return "calibration_complete_current_gate_meets_target"
    return "calibration_complete_current_gate_blocked"


def main() -> int:
    args = parse_args()
    known_stop_inputs = (
        args.known_stop
        + args.tuning_known_stop
        + args.holdout_known_stop
        + args.positive_control_known_stop
    )
    no_stop_inputs = (
        args.no_stop
        + args.fresh_no_stop
        + args.tuning_no_stop
        + args.holdout_no_stop
        + args.fresh_post_repair_acceptance
    )
    if not known_stop_inputs:
        raise SystemExit("At least one --known-stop run is required")
    if not no_stop_inputs:
        raise SystemExit("At least one --no-stop run is required")
    all_input_paths = [
        Path(path).expanduser().resolve()
        for path in (known_stop_inputs + no_stop_inputs)
    ]
    if len(all_input_paths) != len(set(all_input_paths)):
        raise SystemExit("Duplicate run directory supplied to calibration receipt")

    overrides = scorecard_overrides(args.scorecard)
    telemetry_rows = phase_token_rows(args.phase_token_telemetry)
    pricing_path = Path(args.pricing_snapshot).expanduser().resolve() if args.pricing_snapshot else None
    pricing_snapshot = load_json(pricing_path) if pricing_path else None
    if pricing_path and not isinstance(pricing_snapshot, dict):
        raise SystemExit(f"Missing or invalid pricing snapshot: {pricing_path}")
    pricing_info = pricing_status(pricing_path)

    known_stop_rows = [
        label_run(
            Path(path),
            True,
            overrides,
            telemetry_rows,
            pricing_snapshot,
            calibration_role="tuning",
        )
        for path in args.known_stop
    ]
    known_stop_rows.extend(
        label_run(
            Path(path),
            True,
            overrides,
            telemetry_rows,
            pricing_snapshot,
            calibration_role="tuning",
        )
        for path in args.tuning_known_stop
    )
    known_stop_rows.extend(
        label_run(
            Path(path),
            True,
            overrides,
            telemetry_rows,
            pricing_snapshot,
            calibration_role="holdout",
        )
        for path in args.holdout_known_stop
    )
    positive_control_known_stop_rows = [
        label_run(
            Path(path),
            True,
            overrides,
            telemetry_rows,
            pricing_snapshot,
            calibration_role="positive_control_fixture",
            provenance_classification="synthetic_fixture",
            synthetic_positive_control=True,
        )
        for path in args.positive_control_known_stop
    ]
    known_stop_rows.extend(positive_control_known_stop_rows)
    no_stop_rows = [
        label_run(
            Path(path),
            False,
            overrides,
            telemetry_rows,
            pricing_snapshot,
            calibration_role="tuning",
        )
        for path in args.no_stop
    ]
    no_stop_rows.extend(
        label_run(
            Path(path),
            False,
            overrides,
            telemetry_rows,
            pricing_snapshot,
            calibration_role="tuning",
        )
        for path in args.tuning_no_stop
    )
    no_stop_rows.extend(
        label_run(
            Path(path),
            False,
            overrides,
            telemetry_rows,
            pricing_snapshot,
            calibration_role="holdout",
        )
        for path in args.holdout_no_stop
    )
    fresh_no_stop_rows = [
        label_run(
            Path(path),
            False,
            overrides,
            telemetry_rows,
            pricing_snapshot,
            fresh_control=True,
            calibration_role="fresh_post_repair_acceptance",
            fresh_post_repair_acceptance=True,
        )
        for path in args.fresh_no_stop
    ]
    fresh_post_repair_rows = [
        label_run(
            Path(path),
            False,
            overrides,
            telemetry_rows,
            pricing_snapshot,
            fresh_control=True,
            calibration_role="fresh_post_repair_acceptance",
            fresh_post_repair_acceptance=True,
        )
        for path in args.fresh_post_repair_acceptance
    ]
    fresh_no_stop_rows.extend(fresh_post_repair_rows)
    no_stop_rows.extend(fresh_no_stop_rows)
    all_rows = known_stop_rows + no_stop_rows
    all_package = matrix_package(
        all_rows,
        name="combined_diagnostic",
        target_tpr=args.target_tpr,
        target_fpr=args.target_fpr,
    )
    tuning_package = matrix_package(
        split_rows(all_rows, "tuning"),
        name="tuning",
        target_tpr=args.target_tpr,
        target_fpr=args.target_fpr,
    )
    holdout_package = matrix_package(
        split_rows(all_rows, "holdout"),
        name="holdout",
        target_tpr=args.target_tpr,
        target_fpr=args.target_fpr,
    )
    fresh_acceptance_package = matrix_package(
        split_rows(all_rows, "fresh_post_repair_acceptance"),
        name="fresh_post_repair_acceptance",
        target_tpr=args.target_tpr,
        target_fpr=args.target_fpr,
    )
    strict_current_matrix = all_package["strict_current_gate"]
    candidate_tuning_matrix = tuning_package["evidence_only_candidate_gate"]
    candidate_holdout_matrix = holdout_package["evidence_only_candidate_gate"]
    candidate_fresh_matrix = fresh_acceptance_package["evidence_only_candidate_gate"]
    true_positive_count = strict_current_matrix["true_positive"]
    false_negative_count = strict_current_matrix["false_negative"]
    false_positive_rows = [row for row in no_stop_rows if row["classification"] == "false_positive"]
    false_positive_count = strict_current_matrix["false_positive"]
    quality_unqualified_no_stop_rows = [
        row for row in no_stop_rows if row.get("quality_qualified_no_stop_control") is not True
    ]
    req_failures = requirement_failures(
        all_rows,
        require_prompt_equality=args.require_prompt_equality,
        require_direct_provider_token_fields=args.require_direct_provider_token_fields,
    )
    combinations = sorted({model_window_key(row) for row in no_stop_rows if model_window_key(row).strip("|")})
    fresh_combinations = sorted(
        {model_window_key(row) for row in fresh_no_stop_rows if model_window_key(row).strip("|")}
    )
    tpr = strict_current_matrix["true_positive_rate"]
    fpr = strict_current_matrix["false_positive_rate"]
    fresh_acceptance_count = len(split_rows(all_rows, "fresh_post_repair_acceptance"))
    synthetic_positive_control_count = len(positive_control_known_stop_rows)
    adoption_grade_known_stop_count = len(
        [row for row in known_stop_rows if row.get("adoption_grade_control") is True]
    )
    pricing_fresh_enough = not args.require_fresh_pricing or pricing_info["fresh"] is True
    prompt_requirements_pass = not req_failures["prompt_equality_failed_run_ids"]
    direct_field_requirements_pass = not req_failures["direct_provider_token_fields_failed_run_ids"]
    calibration_complete = (
        len(known_stop_rows) >= args.min_known_stop_count
        and len(no_stop_rows) >= args.min_no_stop_count
        and len(fresh_no_stop_rows) >= args.min_fresh_no_stop_count
        and fresh_acceptance_count >= args.min_fresh_post_repair_acceptance_count
        and len(combinations) >= args.min_model_window_combinations
        and len(fresh_combinations) >= args.min_fresh_model_window_combinations
        and not quality_unqualified_no_stop_rows
        and pricing_fresh_enough
        and prompt_requirements_pass
        and direct_field_requirements_pass
    )
    gate_meets_target = (
        calibration_complete
        and tpr is not None
        and fpr is not None
        and tpr >= args.target_tpr
        and fpr <= args.target_fpr
        and false_negative_count == 0
    )
    candidate_status = candidate_repair_status(
        tuning_matrix=candidate_tuning_matrix,
        holdout_matrix=candidate_holdout_matrix,
        fresh_matrix=candidate_fresh_matrix,
        known_stop_count=len(known_stop_rows),
        min_known_stop_count=args.min_known_stop_count,
        fresh_acceptance_count=fresh_acceptance_count,
        min_fresh_acceptance_count=args.min_fresh_post_repair_acceptance_count,
        adoption_grade_known_stop_count=adoption_grade_known_stop_count,
        synthetic_positive_control_count=synthetic_positive_control_count,
    )
    candidate_combined_matrix = all_package["evidence_only_candidate_gate"]
    candidate_preregistered_wilson_target_met = (
        candidate_combined_matrix.get("preregistered_wilson_target_met") is True
    )
    candidate_preregistered_wilson_reason = (
        "combined candidate TPR/FPR Wilson thresholds pass"
        if candidate_preregistered_wilson_target_met
        else (
            "positive class underpowered: combined candidate TPR Wilson lower 95% is below "
            f"{MIN_CANDIDATE_TPR_WILSON_LOWER_95:.2f}"
            if (
                (candidate_combined_matrix.get("true_positive_rate_interval") or {}).get("lower")
                is not None
                and (candidate_combined_matrix.get("true_positive_rate_interval") or {}).get("lower")
                < MIN_CANDIDATE_TPR_WILSON_LOWER_95
            )
            else (
                "no-stop class underpowered or false positives present: combined candidate FPR "
                f"Wilson upper 95% is above {MAX_CANDIDATE_FPR_WILSON_UPPER_95:.2f}"
            )
        )
    )
    payload = {
        "schema_version": 1,
        "receipt_type": "newsletter_phase1c_calibration",
        "generated_at_utc": utc_now().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "pass": calibration_complete,
        "receipt_result": receipt_result(
            calibration_complete,
            gate_meets_target,
            len(known_stop_rows),
            len(no_stop_rows),
            synthetic_positive_control_count=synthetic_positive_control_count,
            adoption_grade_known_stop_count=adoption_grade_known_stop_count,
            min_known_stop_count=args.min_known_stop_count,
        ),
        "gate_under_test": "proposed_strict_phase1c_stop_gate",
        "candidate_gate_under_test": "evidence_only_candidate_phase1c_stop_gate_v1",
        "confidence_interval_method": "wilson_score_95",
        "target": {
            "true_positive_rate": args.target_tpr,
            "false_positive_rate": args.target_fpr,
            "min_known_stop_count": args.min_known_stop_count,
            "min_no_stop_count": args.min_no_stop_count,
            "min_fresh_no_stop_count": args.min_fresh_no_stop_count,
            "min_fresh_post_repair_acceptance_count": (
                args.min_fresh_post_repair_acceptance_count
            ),
            "min_model_window_combinations": args.min_model_window_combinations,
            "min_fresh_model_window_combinations": args.min_fresh_model_window_combinations,
            "preregistered_candidate_gate_wilson_thresholds": {
                "maximum_candidate_gate_false_positive_wilson_upper_95": (
                    MAX_CANDIDATE_FPR_WILSON_UPPER_95
                ),
                "minimum_candidate_gate_true_positive_wilson_lower_95": (
                    MIN_CANDIDATE_TPR_WILSON_LOWER_95
                ),
            },
            "require_fresh_pricing": args.require_fresh_pricing,
            "require_prompt_equality": args.require_prompt_equality,
            "require_direct_provider_token_fields": args.require_direct_provider_token_fields,
            "production_policy_adoption": False,
        },
        "calibration_set": {
            "complete": calibration_complete,
            "known_stop_count": len(known_stop_rows),
            "known_no_stop_count": len(no_stop_rows),
            "fresh_known_no_stop_count": len(fresh_no_stop_rows),
            "quality_qualified_no_stop_count": len(no_stop_rows)
            - len(quality_unqualified_no_stop_rows),
            "model_window_combinations": combinations,
            "model_window_combination_count": len(combinations),
            "fresh_model_window_combinations": fresh_combinations,
            "fresh_model_window_combination_count": len(fresh_combinations),
            "tuning_count": len(split_rows(all_rows, "tuning")),
            "holdout_count": len(split_rows(all_rows, "holdout")),
            "fresh_post_repair_acceptance_count": fresh_acceptance_count,
            "positive_control_known_stop_count": synthetic_positive_control_count,
            "adoption_grade_known_stop_count": adoption_grade_known_stop_count,
            "known_stop_positive_class_sufficient_for_data_acquisition": (
                len(known_stop_rows) >= args.min_known_stop_count
            ),
            "known_stop_positive_class_sufficient_for_adoption": (
                adoption_grade_known_stop_count >= args.min_known_stop_count
            ),
        },
        "confusion_matrix": strict_current_matrix | {"gate_meets_target": gate_meets_target},
        "holdout_safe_evaluation": {
            "combined_diagnostic": all_package,
            "tuning": tuning_package,
            "holdout": holdout_package,
            "fresh_post_repair_acceptance": fresh_acceptance_package,
        },
        "candidate_gate_repair": {
            "status": candidate_status,
            "production_policy_adoption": False,
            "same_label_repair_disposition": (
                "fitting_only"
                if candidate_status.startswith("candidate_fitting_only")
                or candidate_status == "candidate_blocked_positive_class_insufficient"
                or candidate_status == "candidate_positive_control_probe_only_corroboration_required"
                else "independent_acceptance_evaluated"
            ),
            "known_stop_positive_class_sufficient": len(known_stop_rows)
            >= args.min_known_stop_count,
            "adoption_grade_known_stop_positive_class_sufficient": (
                adoption_grade_known_stop_count >= args.min_known_stop_count
            ),
            "fresh_post_repair_acceptance_sufficient": fresh_acceptance_count
            >= args.min_fresh_post_repair_acceptance_count,
            "preregistered_wilson_target_met": candidate_preregistered_wilson_target_met,
            "preregistered_wilson_target_reason": candidate_preregistered_wilson_reason,
            "candidate_parameters": {
                "continuity_ratio_floor": CANDIDATE_PHASE1C_RATIO_FLOOR,
                "severe_missing_version_count_floor": CANDIDATE_PHASE1C_SEVERE_MISSING_VERSION_COUNT,
                "severe_missing_version_ratio_floor": CANDIDATE_PHASE1C_SEVERE_MISSING_VERSION_RATIO,
                "severe_missing_version_ratio_ceiling": CANDIDATE_PHASE1C_SEVERE_VERSION_RATIO_CEILING,
            },
        },
        "false_positive_run_ids": [row["run_id"] for row in false_positive_rows],
        "false_negative_run_ids": [
            row["run_id"] for row in known_stop_rows if row["classification"] == "false_negative"
        ],
        "fresh_no_stop_run_ids": [row["run_id"] for row in fresh_no_stop_rows],
        "fresh_post_repair_acceptance_run_ids": [
            row["run_id"] for row in split_rows(all_rows, "fresh_post_repair_acceptance")
        ],
        "positive_control_run_ids": [row["run_id"] for row in positive_control_known_stop_rows],
        "positive_control_adoption_boundary": {
            "synthetic_or_fixture_positive_controls_present": (
                synthetic_positive_control_count > 0
            ),
            "data_acquisition_counts_may_include_positive_controls": True,
            "production_policy_adoption": False,
            "adoption_grade_without_fresh_or_non_synthetic_corroboration": False,
            "corroboration_required": synthetic_positive_control_count > 0,
            "reason": (
                "Positive-control fixtures intentionally exercise Phase-1C-available "
                "collapse shapes. They can prove the evaluator recognizes the shape, "
                "but cannot by themselves prove production adoption readiness."
            ),
        },
        "quality_unqualified_no_stop_run_ids": [
            row["run_id"] for row in quality_unqualified_no_stop_rows
        ],
        "requirement_failures": req_failures,
        "pricing_snapshot": pricing_info,
        "phase_token_telemetry_receipts": [
            {"path": str(Path(path).expanduser().resolve()), "sha256": sha256_path(Path(path).expanduser().resolve())}
            for path in args.phase_token_telemetry
        ],
        "runs": all_rows,
        "non_claims": [
            "No production stop-gate adoption is claimed.",
            "No durable token-count savings claim is made.",
            "No durable dollar-cost savings claim is made.",
            "API-equivalent public lab pricing is not GitHub Copilot billing.",
            "Gate repair or narrowing remains blocked until the calibration set supports it.",
            "Synthetic or fixture positive controls are data-acquisition probes only and require fresh or non-synthetic corroboration before adoption-grade use.",
            "Gate decisions use only data available at the proposed stop point.",
        ],
    }
    write_json(Path(args.output).expanduser().resolve(), payload)
    print(args.output)
    return 0 if calibration_complete else 1


if __name__ == "__main__":
    raise SystemExit(main())

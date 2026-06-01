#!/usr/bin/env python3
"""Build a receipt for scorecard token-field and prompt-equality telemetry."""

from __future__ import annotations

import argparse
import datetime as dt
import re
from pathlib import Path
from typing import Any

from newsletter_experiment_common import (
    DIRECT_PROVIDER_TOKEN_FIELDS,
    load_json,
    render_prompt_snapshot,
    sha256_path,
    stable_scorecard_sha256,
    write_json,
)

SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scorecard", action="append", required=True, help="Positive scorecard JSON path")
    parser.add_argument(
        "--negative-scorecard",
        action="append",
        default=[],
        help="Negative-control scorecard JSON path expected to fail telemetry checks",
    )
    parser.add_argument("--output", required=True, help="Receipt JSON output path")
    return parser.parse_args()


def int_or_zero(value: Any) -> int:
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return 0


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


def suffix_after_run_id(path: Path, run_id: str) -> Path | None:
    parts = path.expanduser().parts
    for idx, part in enumerate(parts):
        if part == run_id:
            suffix_parts = parts[idx + 1 :]
            return Path(*suffix_parts) if suffix_parts else Path()
    return None


def scorecard_neighbor_run_dir(scorecard_path: Path, run_id: str) -> Path | None:
    parent = scorecard_path.parent
    if parent.name == run_id:
        return parent
    return None


def resolve_scorecard_path(
    payload: dict[str, Any],
    raw_path: Any,
    scorecard_path: Path,
) -> Path | None:
    if not raw_path:
        return None
    path = Path(str(raw_path)).expanduser()
    run_id = str(payload.get("run_id") or "").strip()
    run_dir = (
        Path(str(payload.get("run_dir"))).expanduser()
        if payload.get("run_dir")
        else None
    )
    candidates: list[Path] = []
    if run_id:
        suffix = suffix_after_run_id(path, run_id)
        if suffix is not None:
            colocated = scorecard_neighbor_run_dir(scorecard_path, run_id)
            if colocated:
                candidates.append(colocated / suffix)
            candidates.append(
                Path(__file__).resolve().parent.parent / "runs" / "product_runs" / run_id / suffix
            )
            if run_dir:
                candidates.append(run_dir / suffix)
    if not path.is_absolute():
        candidates.append(scorecard_path.parent / path)
        if run_dir:
            candidates.append(run_dir / path)
        candidates.append(Path(__file__).resolve().parent.parent / path)
    if path.is_absolute() and path.exists():
        candidates.append(path)
    for candidate in candidates:
        if candidate.exists():
            return candidate.resolve()
    return None


def sha256_text_file(path: Path) -> str:
    return sha256_path(path)


def empty_check_row(
    path: Path,
    expected_pass: bool,
    error: str,
    rejected_as_expected: bool | None = None,
) -> dict[str, Any]:
    required_provider_fields = list(DIRECT_PROVIDER_TOKEN_FIELDS)
    rejected = not expected_pass if rejected_as_expected is None else rejected_as_expected
    return {
        "scorecard_path": str(path),
        "scorecard_sha256": None,
        "scorecard_file_sha256": sha256_path(path) if path.exists() else None,
        "scorecard_hash_method": "stable_json_without_generated_at_with_repo_paths_normalized",
        "run_id": None,
        "expected_pass": expected_pass,
        "accepted": False,
        "rejected_as_expected": rejected,
        "token_field_check": {
            "source": None,
            "required_provider_fields": required_provider_fields,
            "direct_provider_token_fields_present": [],
            "missing_direct_provider_token_fields": required_provider_fields,
            "model_direct_provider_token_fields": {},
            "model_field_errors": [error],
            "pass": False,
        },
        "prompt_equality_check": {
            "available": None,
            "retained_prompt_sha256": None,
            "current_renderer_sha256": None,
            "matches_current_renderer": None,
            "reason": error,
            "pass": False,
        },
        "shape_errors": [error],
    }


def model_direct_field_rows(tokens: dict[str, Any]) -> dict[str, dict[str, Any]]:
    direct_rows = tokens.get("model_direct_provider_token_fields")
    if isinstance(direct_rows, dict) and direct_rows:
        return {
            str(model): row
            for model, row in direct_rows.items()
            if isinstance(row, dict)
        }
    return {}


def model_breakdown_request_rows(tokens: dict[str, Any]) -> dict[str, dict[str, Any]]:
    rows: dict[str, dict[str, Any]] = {}
    breakdown = tokens.get("model_breakdown") or []
    if isinstance(breakdown, dict):
        iterable = breakdown.items()
    elif isinstance(breakdown, list):
        iterable = (
            (row.get("model"), row)
            for row in breakdown
            if isinstance(row, dict)
        )
    else:
        iterable = []

    for raw_model, row in iterable:
        if not isinstance(row, dict):
            continue
        model = str(raw_model or row.get("model") or "").strip()
        if not model:
            continue
        request_count = int_or_zero(row.get("request_count", 0))
        if request_count > 0:
            rows[model] = row
    return rows


def requested_model_rows(tokens: dict[str, Any], errors: list[str]) -> dict[str, dict[str, Any]]:
    rows: dict[str, dict[str, Any]] = {}
    requested_models = tokens.get("requested_models")
    requested_names: set[str] = set()
    if not isinstance(requested_models, list) or not requested_models:
        errors.append("requested_models must be a non-empty list")
    else:
        for raw_model in requested_models:
            if not isinstance(raw_model, str):
                errors.append("requested_models contains non-string value")
                continue
            model = raw_model.strip()
            if model:
                requested_names.add(model)

    breakdown_rows = model_breakdown_request_rows(tokens)
    for model in sorted(set(breakdown_rows) - requested_names):
        errors.append(f"{model} model_breakdown request row is missing from requested_models")

    direct_rows = (
        tokens.get("model_direct_provider_token_fields")
        if isinstance(tokens.get("model_direct_provider_token_fields"), dict)
        else {}
    )
    for model in sorted(requested_names | set(breakdown_rows)):
        direct_row = direct_rows.get(model) if isinstance(direct_rows, dict) else None
        if not isinstance(direct_row, dict):
            direct_row = {}
        breakdown_row = breakdown_rows.get(model, {})
        rows[model] = {
            "request_count": (
                direct_row.get("request_count")
                or breakdown_row.get("request_count")
                or 1
            )
        }
    return rows


def check_scorecard(path: Path, expected_pass: bool) -> dict[str, Any]:
    if not path.exists():
        return empty_check_row(
            path,
            expected_pass,
            "scorecard JSON path does not exist",
            rejected_as_expected=False,
        )
    payload = load_json(path)
    if not isinstance(payload, dict):
        return empty_check_row(path, expected_pass, "scorecard JSON could not be read")

    tokens = payload.get("token_usage")
    if not isinstance(tokens, dict):
        return empty_check_row(path, expected_pass, "token_usage object is missing or malformed")
    experiment = payload.get("experiment")
    if not isinstance(experiment, dict):
        return empty_check_row(path, expected_pass, "experiment object is missing or malformed")
    equality = experiment.get("prompt_equality")
    if not isinstance(equality, dict):
        return empty_check_row(path, expected_pass, "prompt_equality object is missing or malformed")

    required_provider_fields = list(DIRECT_PROVIDER_TOKEN_FIELDS)
    shape_errors: list[str] = []
    present = string_list(
        tokens.get("direct_provider_token_fields_present"),
        "direct_provider_token_fields_present",
        shape_errors,
    )
    missing = string_list(
        tokens.get("missing_direct_provider_token_fields"),
        "missing_direct_provider_token_fields",
        shape_errors,
    )
    present_set = set(present)
    missing_set = set(missing)
    model_rows = model_direct_field_rows(tokens)
    requested_models = requested_model_rows(tokens, shape_errors)

    if tokens.get("source") != "session.shutdown.modelMetrics":
        shape_errors.append("token_usage.source is not session.shutdown.modelMetrics")
    missing_required = [field for field in required_provider_fields if field not in present_set]
    if missing_required:
        shape_errors.append("direct provider token fields missing: " + ", ".join(missing_required))
    unexpected_missing = [field for field in required_provider_fields if field in missing_set]
    if unexpected_missing:
        shape_errors.append("required fields reported missing: " + ", ".join(unexpected_missing))
    model_field_errors: list[str] = []
    if not model_rows:
        model_field_errors.append("model direct provider token fields are missing")
    requested_model_names = set(requested_models)
    for model in sorted(requested_models):
        if model not in model_rows:
            model_field_errors.append(
                f"{model} missing per-model direct provider token field row"
            )
    for model, row in model_rows.items():
        request_count = int_or_zero(row.get("request_count", 0))
        if request_count <= 0 and model not in requested_model_names:
            continue
        if request_count <= 0:
            model_field_errors.append(f"{model} requested model row has non-positive request_count")
        model_present = set(
            string_list(
                row.get("direct_provider_token_fields_present"),
                f"{model}.direct_provider_token_fields_present",
                model_field_errors,
            )
        )
        model_missing = set(
            string_list(
                row.get("missing_direct_provider_token_fields"),
                f"{model}.missing_direct_provider_token_fields",
                model_field_errors,
            )
        )
        model_missing_required = [
            field for field in required_provider_fields if field not in model_present
        ]
        model_unexpected_missing = [
            field for field in required_provider_fields if field in model_missing
        ]
        if model_missing_required or model_unexpected_missing:
            details = sorted(set(model_missing_required + model_unexpected_missing))
            model_field_errors.append(
                f"{model} direct provider token fields incomplete: " + ", ".join(details)
            )
    shape_errors.extend(model_field_errors)
    if equality.get("available") is not True:
        shape_errors.append("prompt equality comparison is unavailable")
    retained_prompt_sha = equality.get("retained_prompt_sha256")
    current_renderer_sha = equality.get("current_renderer_sha256")
    canonical_prompt_sha = experiment.get("prompt_sha256")
    if not retained_prompt_sha:
        shape_errors.append("retained prompt hash is missing")
    elif not isinstance(retained_prompt_sha, str) or not SHA256_RE.match(retained_prompt_sha):
        shape_errors.append("retained prompt hash is not a valid SHA-256")
    elif canonical_prompt_sha and retained_prompt_sha != canonical_prompt_sha:
        shape_errors.append("retained prompt hash does not match experiment.prompt_sha256")
    if not current_renderer_sha:
        shape_errors.append("current renderer hash is missing")
    elif not isinstance(current_renderer_sha, str) or not SHA256_RE.match(current_renderer_sha):
        shape_errors.append("current renderer hash is not a valid SHA-256")
    if expected_pass:
        prompt_path = resolve_scorecard_path(payload, experiment.get("prompt_path"), path)
        if not prompt_path:
            shape_errors.append("retained prompt path could not be resolved")
        else:
            retained_disk_sha = sha256_text_file(prompt_path)
            if canonical_prompt_sha != retained_disk_sha:
                shape_errors.append("experiment.prompt_sha256 does not match retained prompt file")
            if retained_prompt_sha != retained_disk_sha:
                shape_errors.append("retained prompt hash does not match retained prompt file")
        rendered = render_prompt_snapshot(
            str(payload.get("start") or ""),
            str(payload.get("end") or ""),
            str(payload.get("mode") or ""),
            str(experiment.get("source_pruning_policy", {}).get("policy_path") or "") or None,
            str(experiment.get("output_shape_policy", {}).get("policy_path") or "") or None,
        )
        rendered_sha = rendered.get("prompt_sha256")
        if not rendered_sha:
            shape_errors.append("current renderer hash could not be recomputed")
        elif current_renderer_sha and current_renderer_sha != rendered_sha:
            shape_errors.append("current renderer hash does not match freshly rendered prompt")
    reported_match = equality.get("matches_current_renderer")
    derived_prompt_match = (
        retained_prompt_sha == current_renderer_sha
        if retained_prompt_sha and current_renderer_sha
        else None
    )
    if not isinstance(reported_match, bool):
        shape_errors.append("prompt equality match boolean is missing")
    elif derived_prompt_match is not None and reported_match is not derived_prompt_match:
        shape_errors.append("prompt equality match boolean disagrees with retained/current hashes")

    prompt_match_pass = equality.get("available") is True and derived_prompt_match is True
    accepted = not shape_errors
    rejected_as_expected = expected_pass is False and (not accepted or not prompt_match_pass)
    return {
        "scorecard_path": str(path),
        "scorecard_sha256": stable_scorecard_sha256(payload),
        "scorecard_file_sha256": sha256_path(path) if path.exists() else None,
        "scorecard_hash_method": "stable_json_without_generated_at_with_repo_paths_normalized",
        "run_id": payload.get("run_id"),
        "expected_pass": expected_pass,
        "accepted": accepted,
        "rejected_as_expected": rejected_as_expected,
        "token_field_check": {
            "source": tokens.get("source"),
            "required_provider_fields": required_provider_fields,
            "direct_provider_token_fields_present": present,
            "missing_direct_provider_token_fields": missing,
            "model_direct_provider_token_fields": model_rows,
            "model_field_errors": model_field_errors,
            "pass": (
                not missing_required
                and not unexpected_missing
                and not model_field_errors
            ),
        },
        "prompt_equality_check": {
            "available": equality.get("available"),
            "retained_prompt_sha256": retained_prompt_sha,
            "current_renderer_sha256": current_renderer_sha,
            "matches_current_renderer": reported_match,
            "derived_matches_current_renderer": derived_prompt_match,
            "reason": equality.get("reason"),
            "pass": prompt_match_pass,
        },
        "shape_errors": shape_errors,
    }


def main() -> int:
    args = parse_args()
    positives = [check_scorecard(Path(path).expanduser().resolve(), True) for path in args.scorecard]
    negatives = [
        check_scorecard(Path(path).expanduser().resolve(), False)
        for path in args.negative_scorecard
    ]
    positive_pass = all(row["accepted"] for row in positives)
    negative_pass = all(row["rejected_as_expected"] for row in negatives)
    payload = {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "receipt_type": "scorecard_telemetry",
        "pass": positive_pass and negative_pass,
        "positive_scorecards_pass": positive_pass,
        "negative_controls_pass": negative_pass,
        "negative_control_count": len(negatives),
        "positive_prompt_matches": sum(
            1 for row in positives if row.get("prompt_equality_check", {}).get("pass") is True
        ),
        "positive_prompt_mismatches": sum(
            1 for row in positives if row.get("prompt_equality_check", {}).get("pass") is False
        ),
        "scorecards": positives,
        "negative_controls": negatives,
        "non_claims": [
            "This receipt proves scorecard telemetry shape only.",
            "A retained prompt mismatch is reported as renderer drift, not hidden as a failure or promoted as adoption proof.",
            "This receipt does not claim production adoption.",
            "This receipt does not claim durable dollar-cost or token-count savings.",
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

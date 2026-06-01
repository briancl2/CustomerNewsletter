#!/usr/bin/env python3
"""Compare matched output-shape proof rows and emit an evidence receipt."""

from __future__ import annotations

import argparse
import datetime as dt
from pathlib import Path
from typing import Any

from newsletter_experiment_common import DIRECT_PROVIDER_TOKEN_FIELDS, load_json, sha256_path, write_json
from product_run_common import logical_artifact_map

LIVE_OUTPUT_TOKEN_REDUCTION_FRACTION_FLOOR = 0.10
LIVE_OUTPUT_TOKEN_REDUCTION_TOKEN_FLOOR = 500


def require_scorecard(path: Path) -> dict[str, Any]:
    payload = load_json(path)
    if not isinstance(payload, dict):
        raise SystemExit(f"Missing or invalid scorecard: {path}")
    return payload


def prompt_equality_pass(scorecard: dict[str, Any]) -> bool:
    equality = ((scorecard.get("experiment") or {}).get("prompt_equality") or {})
    return equality.get("available") is True and equality.get("matches_current_renderer") is True


def direct_fields_pass(scorecard: dict[str, Any]) -> bool:
    token_usage = scorecard.get("token_usage") or {}
    if token_usage.get("source") != "session.shutdown.modelMetrics":
        return False
    present = token_usage.get("direct_provider_token_fields_present") or []
    missing = token_usage.get("missing_direct_provider_token_fields") or []
    if set(present) != set(DIRECT_PROVIDER_TOKEN_FIELDS) or missing != []:
        return False
    model_rows = token_usage.get("model_direct_provider_token_fields") or {}
    requested_models = token_usage.get("requested_models") or []
    if not requested_models or not isinstance(model_rows, dict):
        return False
    for model in requested_models:
        row = model_rows.get(model) or {}
        model_present = row.get("direct_provider_token_fields_present") or []
        model_missing = row.get("missing_direct_provider_token_fields") or []
        if set(model_present) != set(DIRECT_PROVIDER_TOKEN_FIELDS) or model_missing != []:
            return False
    return True


def quality_pass(scorecard: dict[str, Any]) -> bool:
    quality = scorecard.get("quality") or {}
    return (
        quality.get("strict_pass") is True
        and quality.get("newsletter_pass") is True
        and quality.get("rubric_pass") is True
        and int(quality.get("strict_warning_count") or 0) == 0
        and int(quality.get("newsletter_warning_count") or 0) == 0
    )


def pricing_pass(scorecard: dict[str, Any]) -> bool:
    cost = scorecard.get("cost_estimate") or {}
    return cost.get("total_usd") is not None and not (cost.get("unpriced_models") or [])


def token_summary(scorecard: dict[str, Any]) -> dict[str, Any]:
    tokens = scorecard.get("token_usage") or {}
    cost = scorecard.get("cost_estimate") or {}
    summary = {
        "input_tokens": tokens.get("input_tokens"),
        "output_tokens": tokens.get("output_tokens"),
        "cache_read_tokens": tokens.get("cache_read_tokens"),
        "cache_write_tokens": tokens.get("cache_write_tokens"),
        "reasoning_tokens": tokens.get("reasoning_tokens"),
        "request_count": tokens.get("request_count"),
        "total_usd": cost.get("total_usd"),
    }
    direct_token_values = [
        summary["input_tokens"],
        summary["output_tokens"],
        summary["cache_read_tokens"],
        summary["cache_write_tokens"],
        summary["reasoning_tokens"],
    ]
    summary["direct_provider_tokens_total"] = (
        sum(direct_token_values)
        if all(isinstance(value, (int, float)) for value in direct_token_values)
        else None
    )
    return summary


def delta(control: Any, variant: Any) -> Any:
    if isinstance(control, (int, float)) and isinstance(variant, (int, float)):
        return control - variant
    return None


def warning_classes(scorecard: dict[str, Any]) -> set[str]:
    return set(((scorecard.get("quality") or {}).get("warning_taxonomy_classes") or []))


def output_shape_artifact_paths(scorecard: dict[str, Any]) -> dict[str, Path] | None:
    run_dir = Path(str(scorecard.get("run_dir") or ""))
    if not run_dir.exists():
        return None
    start = str(scorecard.get("start") or "")
    end = str(scorecard.get("end") or "")
    logical = logical_artifact_map(start, end)
    return {
        "context": run_dir / "artifacts" / logical["output_shape_context"],
        "receipt": run_dir / "artifacts" / logical["output_shape_receipt"],
    }


def load_shape_receipt(scorecard: dict[str, Any]) -> tuple[Path | None, dict[str, Any] | None]:
    paths = output_shape_artifact_paths(scorecard)
    if not paths:
        return None, None
    path = paths["receipt"]
    if not path.exists():
        return path, None
    payload = load_json(path)
    return path, payload if isinstance(payload, dict) else None


def control_shape_artifacts_absent(scorecard: dict[str, Any]) -> bool:
    paths = output_shape_artifact_paths(scorecard)
    if not paths:
        return False
    return not paths["context"].exists() and not paths["receipt"].exists()


def build_receipt(control_path: Path, variant_path: Path) -> dict[str, Any]:
    control = require_scorecard(control_path)
    variant = require_scorecard(variant_path)
    control_tokens = token_summary(control)
    variant_tokens = token_summary(variant)
    shape_receipt_path, shape_receipt = load_shape_receipt(variant)
    policy = ((variant.get("experiment") or {}).get("output_shape_policy") or {})
    new_warning_classes = sorted(warning_classes(variant) - warning_classes(control))
    output_delta = delta(control_tokens["output_tokens"], variant_tokens["output_tokens"])
    input_delta = delta(control_tokens["input_tokens"], variant_tokens["input_tokens"])
    request_delta = delta(control_tokens["request_count"], variant_tokens["request_count"])
    cost_delta = delta(control_tokens["total_usd"], variant_tokens["total_usd"])
    total_token_delta = delta(
        control_tokens["direct_provider_tokens_total"],
        variant_tokens["direct_provider_tokens_total"],
    )
    relative_output_delta = (
        round(output_delta / control_tokens["output_tokens"], 6)
        if isinstance(output_delta, (int, float))
        and isinstance(control_tokens["output_tokens"], (int, float))
        and control_tokens["output_tokens"]
        else None
    )

    checks = {
        "same_mode": control.get("mode") == variant.get("mode"),
        "same_date_range": control.get("start") == variant.get("start")
        and control.get("end") == variant.get("end"),
        "same_primary_model": control.get("primary_model") == variant.get("primary_model"),
        "control_prompt_equality_pass": prompt_equality_pass(control),
        "variant_prompt_equality_pass": prompt_equality_pass(variant),
        "control_direct_token_fields_pass": direct_fields_pass(control),
        "variant_direct_token_fields_pass": direct_fields_pass(variant),
        "control_quality_pass": quality_pass(control),
        "variant_quality_pass": quality_pass(variant),
        "control_pricing_pass": pricing_pass(control),
        "variant_pricing_pass": pricing_pass(variant),
        "control_output_shape_artifacts_absent": control_shape_artifacts_absent(control),
        "variant_run_class_pass": ((variant.get("experiment") or {}).get("run_class") == "output_shape_candidate"),
        "output_shape_receipt_present": shape_receipt is not None,
        "output_shape_receipt_admission_pass": (shape_receipt or {}).get("pass") is True,
        "policy_hash_bound": (
            shape_receipt is not None
            and policy.get("policy_sha256") == shape_receipt.get("policy_sha256")
        ),
        "live_output_tokens_lower": isinstance(output_delta, (int, float)) and output_delta > 0,
        "live_output_tokens_reduction_at_least_10_percent": (
            isinstance(relative_output_delta, (int, float))
            and relative_output_delta >= LIVE_OUTPUT_TOKEN_REDUCTION_FRACTION_FLOOR
        ),
        "live_output_tokens_reduction_at_least_500": (
            isinstance(output_delta, (int, float))
            and output_delta >= LIVE_OUTPUT_TOKEN_REDUCTION_TOKEN_FLOOR
        ),
        "input_tokens_not_higher": not isinstance(input_delta, (int, float)) or input_delta >= 0,
        "request_count_not_higher": not isinstance(request_delta, (int, float)) or request_delta >= 0,
        "total_direct_provider_tokens_lower": (
            isinstance(total_token_delta, (int, float)) and total_token_delta > 0
        ),
        "api_equivalent_cost_not_higher": isinstance(cost_delta, (int, float)) and cost_delta >= 0,
        "no_new_warning_taxonomy": not new_warning_classes,
    }
    pair_pass = all(checks.values())
    return {
        "schema_version": 1,
        "receipt_type": "newsletter_output_shape_experiment_comparison",
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "control_scorecard_path": str(control_path),
        "control_scorecard_sha256": sha256_path(control_path),
        "variant_scorecard_path": str(variant_path),
        "variant_scorecard_sha256": sha256_path(variant_path),
        "mode": control.get("mode"),
        "start": control.get("start"),
        "end": control.get("end"),
        "primary_model": control.get("primary_model"),
        "control_run_id": control.get("run_id"),
        "variant_run_id": variant.get("run_id"),
        "output_shape_receipt_path": str(shape_receipt_path) if shape_receipt_path else None,
        "output_shape_receipt_sha256": (
            sha256_path(shape_receipt_path)
            if shape_receipt_path and shape_receipt_path.exists()
            else None
        ),
        "policy_id": policy.get("policy_id"),
        "policy_sha256": policy.get("policy_sha256"),
        "policy_admission": {
            "pass": (shape_receipt or {}).get("pass"),
            "materiality_pass": ((shape_receipt or {}).get("checks") or {}).get("materiality_pass"),
            "materiality_threshold": (shape_receipt or {}).get("materiality_threshold"),
            "potential_reduction_pct": (shape_receipt or {}).get("potential_reduction_pct"),
            "potential_reduction_words": (shape_receipt or {}).get("potential_reduction_words"),
        },
        "qualification_thresholds": {
            "policy_admission_materiality": (shape_receipt or {}).get("materiality_threshold"),
            "live_output_token_reduction_fraction_floor": LIVE_OUTPUT_TOKEN_REDUCTION_FRACTION_FLOOR,
            "live_output_token_reduction_token_floor": LIVE_OUTPUT_TOKEN_REDUCTION_TOKEN_FLOOR,
            "live_input_tokens_delta_max": 0,
            "live_request_count_delta_max": 0,
            "live_total_direct_provider_tokens_delta_must_be_positive": True,
            "api_equivalent_cost_delta_max": 0,
            "notes": [
                "The bound output-shape policy admission is word/materiality based.",
                "Live proof qualification is token/cost based because the matrix tests real provider token telemetry."
            ]
        },
        "checks": checks,
        "pair_pass": pair_pass,
        "control": control_tokens,
        "variant": variant_tokens,
        "deltas": {
            "output_tokens": output_delta,
            "output_token_reduction_fraction": relative_output_delta,
            "input_tokens": input_delta,
            "cache_read_tokens": delta(control_tokens["cache_read_tokens"], variant_tokens["cache_read_tokens"]),
            "cache_write_tokens": delta(control_tokens["cache_write_tokens"], variant_tokens["cache_write_tokens"]),
            "reasoning_tokens": delta(control_tokens["reasoning_tokens"], variant_tokens["reasoning_tokens"]),
            "request_count": request_delta,
            "direct_provider_tokens_total": total_token_delta,
            "api_equivalent_total_usd": cost_delta,
        },
        "new_warning_taxonomy_classes": new_warning_classes,
        "non_claims": [
            "No production adoption",
            "No durable token or dollar savings claim",
            "No GitHub Copilot billing proof",
            "No model recommendation",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--control-scorecard", required=True)
    parser.add_argument("--variant-scorecard", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    receipt = build_receipt(
        Path(args.control_scorecard).expanduser().resolve(),
        Path(args.variant_scorecard).expanduser().resolve(),
    )
    write_json(Path(args.output).expanduser().resolve(), receipt)
    print(Path(args.output).expanduser().resolve())
    return 0 if receipt.get("pair_pass") is True else 1


if __name__ == "__main__":
    raise SystemExit(main())

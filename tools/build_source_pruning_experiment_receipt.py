#!/usr/bin/env python3
"""Compare matched source-pruning proof rows and emit an evidence receipt."""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Any

from newsletter_experiment_common import DIRECT_PROVIDER_TOKEN_FIELDS, load_json, sha256_path, write_json
from product_run_common import logical_artifact_map


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
    )


def pricing_pass(scorecard: dict[str, Any]) -> bool:
    cost = scorecard.get("cost_estimate") or {}
    return cost.get("total_usd") is not None and not (cost.get("unpriced_models") or [])


def token_summary(scorecard: dict[str, Any]) -> dict[str, Any]:
    tokens = scorecard.get("token_usage") or {}
    cost = scorecard.get("cost_estimate") or {}
    return {
        "input_tokens": tokens.get("input_tokens"),
        "output_tokens": tokens.get("output_tokens"),
        "cache_read_tokens": tokens.get("cache_read_tokens"),
        "cache_write_tokens": tokens.get("cache_write_tokens"),
        "reasoning_tokens": tokens.get("reasoning_tokens"),
        "request_count": tokens.get("request_count"),
        "total_usd": cost.get("total_usd"),
    }


def delta(control: Any, pruned: Any) -> Any:
    if isinstance(control, (int, float)) and isinstance(pruned, (int, float)):
        return control - pruned
    return None


def warning_classes(scorecard: dict[str, Any]) -> set[str]:
    return set(((scorecard.get("quality") or {}).get("warning_taxonomy_classes") or []))


def source_pruning_artifact_paths(scorecard: dict[str, Any]) -> dict[str, Path] | None:
    run_dir = Path(str(scorecard.get("run_dir") or ""))
    if not run_dir.exists():
        return None
    start = str(scorecard.get("start") or "")
    end = str(scorecard.get("end") or "")
    logical = logical_artifact_map(start, end)
    return {
        "context": run_dir / "artifacts" / logical["source_pruning_context"],
        "receipt": run_dir / "artifacts" / logical["source_pruning_receipt"],
    }


def load_pruning_receipt(scorecard: dict[str, Any]) -> tuple[Path | None, dict[str, Any] | None]:
    paths = source_pruning_artifact_paths(scorecard)
    if not paths:
        return None, None
    path = paths["receipt"]
    payload = load_json(path)
    return path, payload if isinstance(payload, dict) else None


def control_pruning_artifacts_absent(scorecard: dict[str, Any]) -> bool:
    paths = source_pruning_artifact_paths(scorecard)
    if not paths:
        return False
    return not paths["context"].exists() and not paths["receipt"].exists()


def build_receipt(control_path: Path, pruned_path: Path) -> dict[str, Any]:
    control = require_scorecard(control_path)
    pruned = require_scorecard(pruned_path)
    control_tokens = token_summary(control)
    pruned_tokens = token_summary(pruned)
    pruning_receipt_path, pruning_receipt = load_pruning_receipt(pruned)
    policy = ((pruned.get("experiment") or {}).get("source_pruning_policy") or {})
    new_warning_classes = sorted(warning_classes(pruned) - warning_classes(control))
    input_delta = delta(control_tokens["input_tokens"], pruned_tokens["input_tokens"])
    cost_delta = delta(control_tokens["total_usd"], pruned_tokens["total_usd"])
    relative_input_delta = (
        round(input_delta / control_tokens["input_tokens"], 6)
        if isinstance(input_delta, (int, float))
        and isinstance(control_tokens["input_tokens"], (int, float))
        and control_tokens["input_tokens"]
        else None
    )

    checks = {
        "same_mode": control.get("mode") == pruned.get("mode"),
        "same_date_range": control.get("start") == pruned.get("start") and control.get("end") == pruned.get("end"),
        "same_primary_model": control.get("primary_model") == pruned.get("primary_model"),
        "control_prompt_equality_pass": prompt_equality_pass(control),
        "pruned_prompt_equality_pass": prompt_equality_pass(pruned),
        "control_direct_token_fields_pass": direct_fields_pass(control),
        "pruned_direct_token_fields_pass": direct_fields_pass(pruned),
        "control_quality_pass": quality_pass(control),
        "pruned_quality_pass": quality_pass(pruned),
        "control_pricing_pass": pricing_pass(control),
        "pruned_pricing_pass": pricing_pass(pruned),
        "control_pruning_artifacts_absent": control_pruning_artifacts_absent(control),
        "pruned_run_class_pass": ((pruned.get("experiment") or {}).get("run_class") == "source_pruning_candidate"),
        "pruning_receipt_present": pruning_receipt is not None,
        "pruning_receipt_admission_pass": ((pruning_receipt or {}).get("admission") or {}).get("pass") is True,
        "policy_hash_bound": (
            pruning_receipt is not None
            and policy.get("policy_sha256") == pruning_receipt.get("policy_sha256")
        ),
        "input_tokens_lower": isinstance(input_delta, (int, float)) and input_delta > 0,
        "no_new_warning_taxonomy": not new_warning_classes,
    }
    pair_pass = all(checks.values())
    return {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "control_scorecard_path": str(control_path),
        "control_scorecard_sha256": sha256_path(control_path),
        "pruned_scorecard_path": str(pruned_path),
        "pruned_scorecard_sha256": sha256_path(pruned_path),
        "mode": control.get("mode"),
        "start": control.get("start"),
        "end": control.get("end"),
        "primary_model": control.get("primary_model"),
        "control_run_id": control.get("run_id"),
        "pruned_run_id": pruned.get("run_id"),
        "pruning_receipt_path": str(pruning_receipt_path) if pruning_receipt_path else None,
        "pruning_receipt_sha256": sha256_path(pruning_receipt_path) if pruning_receipt_path and pruning_receipt_path.exists() else None,
        "policy_id": policy.get("policy_id"),
        "policy_sha256": policy.get("policy_sha256"),
        "checks": checks,
        "pair_pass": pair_pass,
        "control": control_tokens,
        "pruned": pruned_tokens,
        "deltas": {
            "input_tokens": input_delta,
            "input_token_reduction_fraction": relative_input_delta,
            "output_tokens": delta(control_tokens["output_tokens"], pruned_tokens["output_tokens"]),
            "cache_read_tokens": delta(control_tokens["cache_read_tokens"], pruned_tokens["cache_read_tokens"]),
            "cache_write_tokens": delta(control_tokens["cache_write_tokens"], pruned_tokens["cache_write_tokens"]),
            "reasoning_tokens": delta(control_tokens["reasoning_tokens"], pruned_tokens["reasoning_tokens"]),
            "request_count": delta(control_tokens["request_count"], pruned_tokens["request_count"]),
            "api_equivalent_total_usd": cost_delta,
        },
        "new_warning_taxonomy_classes": new_warning_classes,
        "non_claims": [
            "No production adoption",
            "No durable token or dollar savings claim",
            "No GitHub Copilot billing proof",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--control-scorecard", required=True)
    parser.add_argument("--pruned-scorecard", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    receipt = build_receipt(
        Path(args.control_scorecard).expanduser().resolve(),
        Path(args.pruned_scorecard).expanduser().resolve(),
    )
    write_json(Path(args.output).expanduser().resolve(), receipt)
    print(Path(args.output).expanduser().resolve())
    return 0 if receipt.get("pair_pass") is True else 1


if __name__ == "__main__":
    raise SystemExit(main())

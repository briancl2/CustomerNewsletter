#!/usr/bin/env python3
"""Classify a closed-bundle source-pruning proof pair."""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Any

from build_source_pruning_amplification_receipt import build_pair
from newsletter_experiment_common import load_json, load_text, sha256_path, write_json


REPO_ROOT = Path(__file__).resolve().parent.parent


def resolve_run_dir(raw: str) -> Path:
    path = Path(raw).expanduser()
    if not path.is_absolute():
        path = REPO_ROOT / path
    return path.resolve()


def require_scorecard(run_dir: Path) -> dict[str, Any]:
    path = run_dir / "run-scorecard.json"
    payload = load_json(path)
    if not isinstance(payload, dict):
        raise SystemExit(f"Missing or invalid scorecard: {path}")
    return payload


def resolve_policy_path(scorecard: dict[str, Any]) -> Path | None:
    raw = (((scorecard.get("experiment") or {}).get("source_pruning_policy") or {}).get("policy_path"))
    if not raw:
        return None
    path = Path(str(raw)).expanduser()
    if not path.is_absolute():
        path = REPO_ROOT / path
    return path.resolve()


def prompt_text_for(scorecard: dict[str, Any], run_dir: Path) -> str | None:
    raw = (scorecard.get("experiment") or {}).get("prompt_path") or str(run_dir / "prompt.txt")
    path = Path(str(raw))
    if not path.is_absolute():
        path = REPO_ROOT / path
    return load_text(path)


def closed_bundle_prompt_boundary(prompt: str | None) -> dict[str, Any]:
    required = [
        "Closed source bundle required: `true`",
        "After the closed bundle receipt passes, do not perform broad repo/source search expansion",
        "closed_bundle_missing_detail",
        "invalid as a closed-bundle proof row",
    ]
    missing = [needle for needle in required if not prompt or needle not in prompt]
    return {
        "present": not missing,
        "missing_required_phrases": missing,
        "required_phrases": required,
    }


def policy_summary(policy_path: Path | None) -> dict[str, Any]:
    if policy_path is None:
        return {
            "path": None,
            "exists": False,
            "sha256": None,
            "policy_id": None,
            "closed_bundle_required": False,
        }
    payload = load_json(policy_path)
    if not isinstance(payload, dict):
        return {
            "path": str(policy_path),
            "exists": policy_path.exists(),
            "sha256": sha256_path(policy_path) if policy_path.exists() else None,
            "policy_id": None,
            "closed_bundle_required": False,
        }
    return {
        "path": str(policy_path),
        "exists": True,
        "sha256": sha256_path(policy_path),
        "policy_id": payload.get("policy_id"),
        "closed_bundle_required": payload.get("closed_bundle_required") is True,
        "usage_boundary_extra_rules": payload.get("usage_boundary_extra_rules", []),
    }


def pruning_receipt_closed_bundle(pair: dict[str, Any]) -> bool:
    rows = ((pair.get("pruned") or {}).get("source_pruning_artifact_presence") or {}).get("rows") or []
    receipt_path = None
    for row in rows:
        if row.get("artifact_name") == "source_pruning_receipt":
            receipt_path = Path(str(row.get("path") or ""))
            break
    payload = load_json(receipt_path) if receipt_path else None
    return isinstance(payload, dict) and payload.get("closed_bundle_required") is True


def build_receipt(control_dir: Path, candidate_dir: Path) -> dict[str, Any]:
    pair = build_pair("burst27_closed_bundle_pair", control_dir, candidate_dir)
    candidate_scorecard = require_scorecard(candidate_dir)
    policy = policy_summary(resolve_policy_path(candidate_scorecard))
    prompt_boundary = closed_bundle_prompt_boundary(prompt_text_for(candidate_scorecard, candidate_dir))
    prompt_diff = pair.get("prompt_diff") or {}
    control_prompt_state = prompt_diff.get("control_source_pruning_prompt_state") or {}
    candidate_prompt_state = prompt_diff.get("pruned_source_pruning_prompt_state") or {}
    trace_delta = (((pair.get("deltas") or {}).get("trace_control_minus_pruned") or {}).get("command_category_counts") or {})
    search_delta = trace_delta.get("search_or_inspection")
    materialization_delta = trace_delta.get("materialization_or_builder")
    request_delta = (pair.get("deltas") or {}).get("request_count_control_minus_pruned")
    input_delta = (pair.get("deltas") or {}).get("input_tokens_control_minus_pruned")
    pair_checks = pair.get("checks") or {}
    base_pair_comparable = all(
        pair_checks.get(key) is True
        for key in (
            "same_mode",
            "same_date_range",
            "same_primary_model",
            "control_prompt_equality_pass",
            "pruned_prompt_equality_pass",
            "control_direct_token_fields_pass",
            "pruned_direct_token_fields_pass",
            "control_quality_pass",
            "pruned_quality_pass",
            "control_pricing_pass",
            "pruned_pricing_pass",
            "control_source_pruning_artifacts_absent",
            "pruned_source_pruning_artifacts_complete",
            "pruned_run_class_pass",
            "policy_hash_bound",
            "control_session_trace_qualified",
            "pruned_session_trace_qualified",
            "no_new_warning_taxonomy",
        )
    )
    checks = {
        "base_pair_comparable": base_pair_comparable,
        "policy_declares_closed_bundle": policy.get("closed_bundle_required") is True,
        "pruning_receipt_declares_closed_bundle": pruning_receipt_closed_bundle(pair),
        "prompt_boundary_bound": prompt_boundary.get("present") is True,
        "control_prompt_state_disabled": control_prompt_state.get("state") == "source_pruning_disabled_block",
        "candidate_prompt_state_enabled": candidate_prompt_state.get("state") == "source_pruning_enabled_block",
        "candidate_prompt_apply_policy_command_present": candidate_prompt_state.get("apply_policy_command_present") is True,
        "candidate_prompt_context_artifact_reference_present": candidate_prompt_state.get("context_artifact_reference_present") is True,
        "search_or_inspection_not_higher": isinstance(search_delta, (int, float)) and search_delta >= 0,
        "materialization_or_builder_not_higher": isinstance(materialization_delta, (int, float)) and materialization_delta >= 0,
        "request_count_not_higher": isinstance(request_delta, (int, float)) and request_delta >= 0,
        "input_tokens_lower": isinstance(input_delta, (int, float)) and input_delta > 0,
    }
    pass_value = all(checks.values())
    if pass_value:
        classification = "qualified_closed_bundle_source_pruning_signal"
    elif (
        not checks["policy_declares_closed_bundle"]
        or not checks["pruning_receipt_declares_closed_bundle"]
        or not checks["prompt_boundary_bound"]
        or not checks["control_prompt_state_disabled"]
        or not checks["candidate_prompt_state_enabled"]
        or not checks["candidate_prompt_apply_policy_command_present"]
        or not checks["candidate_prompt_context_artifact_reference_present"]
    ):
        classification = "closed_bundle_boundary_not_admitted"
    elif not checks["base_pair_comparable"]:
        classification = "closed_bundle_pair_not_qualified"
    elif isinstance(input_delta, (int, float)) and input_delta < 0:
        classification = "closed_bundle_input_amplification"
    elif (
        not checks["request_count_not_higher"]
        or not checks["search_or_inspection_not_higher"]
        or not checks["materialization_or_builder_not_higher"]
    ):
        classification = "closed_bundle_search_or_request_amplification"
    else:
        classification = "closed_bundle_pair_not_qualified"
    return {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "receipt_type": "closed_bundle_source_pruning_proof_pair",
        "classification": classification,
        "pass": pass_value,
        "control_run_dir": str(control_dir),
        "candidate_run_dir": str(candidate_dir),
        "policy": policy,
        "prompt_boundary": prompt_boundary,
        "checks": checks,
        "pair": pair,
        "recommended_next_owner_move": (
            "Run a small closed-bundle benchmark confirmation matrix."
            if pass_value
            else "Do not run more closed-bundle source-pruning rows until the failed check is repaired or the tactic is parked."
        ),
        "non_claims": [
            "No production adoption",
            "No durable token or dollar savings claim",
            "No GitHub Copilot billing proof",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--control-run-dir", required=True)
    parser.add_argument("--candidate-run-dir", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    receipt = build_receipt(resolve_run_dir(args.control_run_dir), resolve_run_dir(args.candidate_run_dir))
    output = Path(args.output).expanduser().resolve()
    write_json(output, receipt)
    print(output)
    return 0 if receipt.get("pass") is True else 1


if __name__ == "__main__":
    raise SystemExit(main())

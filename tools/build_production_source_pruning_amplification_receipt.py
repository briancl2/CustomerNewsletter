#!/usr/bin/env python3
"""Classify production source-pruning amplification and repair evidence."""

from __future__ import annotations

import argparse
import datetime as dt
from pathlib import Path
from typing import Any

from build_source_pruning_amplification_receipt import build_pair, parse_pair
from newsletter_experiment_common import write_json


def command_delta(pair: dict[str, Any], category: str) -> int | float | None:
    trace = ((pair.get("deltas") or {}).get("trace_control_minus_pruned") or {})
    categories = trace.get("command_category_counts") or {}
    value = categories.get(category)
    return value if isinstance(value, (int, float)) else None


def prompt_state(pair: dict[str, Any], side: str) -> str:
    diff = pair.get("prompt_diff") or {}
    key = f"{side}_source_pruning_prompt_state"
    state = (diff.get(key) or {}).get("state")
    return str(state or "unknown")


def classify_production_pair(pair: dict[str, Any]) -> dict[str, Any]:
    input_delta = ((pair.get("deltas") or {}).get("input_tokens_control_minus_pruned"))
    request_delta = ((pair.get("deltas") or {}).get("request_count_control_minus_pruned"))
    control_state = prompt_state(pair, "control")
    pruned_state = prompt_state(pair, "pruned")
    checks = pair.get("checks") or {}
    is_production = pair.get("mode") == "production"
    prompt_state_pass = (
        control_state == "source_pruning_disabled_block"
        and pruned_state == "source_pruning_enabled_block"
    )
    root_cause_checks = {
        "mode_is_production": is_production,
        "same_mode": checks.get("same_mode") is True,
        "same_date_range": checks.get("same_date_range") is True,
        "same_primary_model": checks.get("same_primary_model") is True,
        "control_prompt_equality_pass": checks.get("control_prompt_equality_pass") is True,
        "pruned_prompt_equality_pass": checks.get("pruned_prompt_equality_pass") is True,
        "control_prompt_state_disabled": control_state == "source_pruning_disabled_block",
        "pruned_prompt_state_enabled": pruned_state == "source_pruning_enabled_block",
        "control_trace_qualified": checks.get("control_session_trace_qualified") is True,
        "pruned_trace_qualified": checks.get("pruned_session_trace_qualified") is True,
        "control_artifacts_absent": checks.get("control_source_pruning_artifacts_absent") is True,
        "pruned_artifacts_complete": checks.get("pruned_source_pruning_artifacts_complete") is True,
        "quality_preserved": checks.get("control_quality_pass") is True
        and checks.get("pruned_quality_pass") is True,
        "direct_token_fields_present": checks.get("control_direct_token_fields_pass") is True
        and checks.get("pruned_direct_token_fields_pass") is True,
        "pricing_available": checks.get("control_pricing_pass") is True
        and checks.get("pruned_pricing_pass") is True,
        "pruned_run_class_pass": checks.get("pruned_run_class_pass") is True,
        "policy_hash_bound": checks.get("policy_hash_bound") is True,
        "prompt_state_comparable": prompt_state_pass,
    }
    root_cause_evidence_pass = all(root_cause_checks.values())
    amplification = {
        "input_token_amplification": isinstance(input_delta, (int, float)) and input_delta < 0,
        "request_count_amplification": isinstance(request_delta, (int, float)) and request_delta < 0,
        "search_or_inspection_amplification": (
            isinstance(command_delta(pair, "search_or_inspection"), (int, float))
            and command_delta(pair, "search_or_inspection") < 0
        ),
        "validation_or_receipt_amplification": (
            isinstance(command_delta(pair, "validation_or_receipt"), (int, float))
            and command_delta(pair, "validation_or_receipt") < 0
        ),
        "materialization_or_builder_amplification": (
            isinstance(command_delta(pair, "materialization_or_builder"), (int, float))
            and command_delta(pair, "materialization_or_builder") < 0
        ),
        "source_pruning_policy_overhead": (
            isinstance(command_delta(pair, "source_pruning"), (int, float))
            and command_delta(pair, "source_pruning") < 0
        ),
    }
    command_work_amplification = (
        amplification["search_or_inspection_amplification"]
        or amplification["validation_or_receipt_amplification"]
        or amplification["materialization_or_builder_amplification"]
    )
    if not root_cause_evidence_pass:
        classification = "fail_closed_incomplete_production_root_cause_evidence"
    elif pair.get("admitted_for_mode_specific_follow_on") is True and not command_work_amplification:
        classification = "qualified_production_repair_signal"
    elif amplification["input_token_amplification"] and amplification["request_count_amplification"]:
        classification = "production_input_and_request_amplification"
    elif amplification["input_token_amplification"]:
        classification = "production_input_amplification"
    elif amplification["request_count_amplification"]:
        classification = "production_request_amplification"
    elif command_work_amplification:
        classification = "production_command_work_amplification"
    else:
        classification = "production_not_qualified_without_amplification"
    return {
        "pair_name": pair.get("pair_name"),
        "classification": classification,
        "root_cause_evidence_pass": root_cause_evidence_pass,
        "root_cause_checks": root_cause_checks,
        "amplification_flags": amplification,
        "control_prompt_state": control_state,
        "pruned_prompt_state": pruned_state,
        "input_tokens_control_minus_pruned": input_delta,
        "request_count_control_minus_pruned": request_delta,
        "command_category_deltas": ((pair.get("deltas") or {}).get("trace_control_minus_pruned") or {}).get(
            "command_category_counts", {}
        ),
        "blockers": pair.get("blockers") or [],
    }


def build_receipt(pairs: list[tuple[str, Path, Path]]) -> dict[str, Any]:
    pair_rows = [build_pair(name, control, pruned) for name, control, pruned in pairs]
    classifications = [classify_production_pair(pair) for pair in pair_rows]
    root_cause_pass_count = sum(1 for row in classifications if row["root_cause_evidence_pass"])
    amplification_classes = {
        "production_input_and_request_amplification",
        "production_input_amplification",
        "production_request_amplification",
        "production_command_work_amplification",
    }
    amplification_count = sum(
        1 for row in classifications if row["classification"] in amplification_classes
    )
    qualified_count = sum(
        1 for row in classifications if row["classification"] == "qualified_production_repair_signal"
    )
    all_production = all(pair.get("mode") == "production" for pair in pair_rows)
    if qualified_count:
        result = "production_repair_signal_observed"
    elif amplification_count:
        result = "production_amplification_root_cause_retained"
    else:
        result = "fail_closed_no_production_amplification_or_repair_signal"
    evidence_complete = bool(pair_rows) and all_production and root_cause_pass_count == len(pair_rows)
    pass_value = evidence_complete and qualified_count > 0
    return {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "receipt_type": "production_source_pruning_amplification_root_cause",
        "result": result,
        "pass": pass_value,
        "evidence_complete": evidence_complete,
        "pair_count": len(pair_rows),
        "root_cause_evidence_pass_count": root_cause_pass_count,
        "production_amplification_pair_count": amplification_count,
        "qualified_production_repair_pair_count": qualified_count,
        "classifications": classifications,
        "pairs": pair_rows,
        "recommended_next_owner_move": (
            "If a production repair pair qualifies, run a small production confirmation matrix. "
            "If only retained amplification is classified, constrain the request/materialization path "
            "before additional production live spend."
        ),
        "non_claims": [
            "No production adoption",
            "No durable token or dollar savings claim",
            "No GitHub Copilot billing proof",
            "No model recommendation",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pair", action="append", required=True, help="name:control_run_dir:pruned_run_dir")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    receipt = build_receipt([parse_pair(raw) for raw in args.pair])
    output = Path(args.output).expanduser().resolve()
    write_json(output, receipt)
    print(output)
    return 0 if receipt.get("pass") is True else 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Classify source-pruning variance and admit only bounded repair probes."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
from pathlib import Path
from typing import Any

from newsletter_experiment_common import sha256_path, write_json


def load_json(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise SystemExit(f"Expected JSON object: {path}")
    return payload


def number(value: Any) -> int | float | None:
    return value if isinstance(value, (int, float)) else None


def token_value(pair: dict[str, Any], side: str, key: str) -> int | float | None:
    return number(((pair.get(side) or {}).get("tokens") or {}).get(key))


def delta_value(pair: dict[str, Any], key: str) -> int | float | None:
    return number((pair.get("deltas") or {}).get(key))


def trace_category_delta(pair: dict[str, Any], category: str) -> int | float | None:
    trace = ((pair.get("deltas") or {}).get("trace_control_minus_pruned") or {})
    categories = trace.get("command_category_counts") if isinstance(trace, dict) else {}
    if not isinstance(categories, dict):
        return None
    return number(categories.get(category))


def compact_pair(pair: dict[str, Any], source_receipt: str) -> dict[str, Any]:
    control_input = token_value(pair, "control", "input_tokens")
    pruned_input = token_value(pair, "pruned", "input_tokens")
    control_cache_read = token_value(pair, "control", "cache_read_tokens")
    pruned_cache_read = token_value(pair, "pruned", "cache_read_tokens")
    control_cache_write = token_value(pair, "control", "cache_write_tokens") or 0
    pruned_cache_write = token_value(pair, "pruned", "cache_write_tokens") or 0
    control_uncached = (
        control_input - control_cache_read - control_cache_write
        if isinstance(control_input, (int, float)) and isinstance(control_cache_read, (int, float))
        else None
    )
    pruned_uncached = (
        pruned_input - pruned_cache_read - pruned_cache_write
        if isinstance(pruned_input, (int, float)) and isinstance(pruned_cache_read, (int, float))
        else None
    )
    input_delta = delta_value(pair, "input_tokens_control_minus_pruned")
    cache_read_delta = delta_value(pair, "cache_read_tokens_control_minus_pruned")
    request_delta = delta_value(pair, "request_count_control_minus_pruned")
    uncached_delta = (
        control_uncached - pruned_uncached
        if isinstance(control_uncached, (int, float)) and isinstance(pruned_uncached, (int, float))
        else None
    )
    search_delta = trace_category_delta(pair, "search_or_inspection")
    materialization_delta = trace_category_delta(pair, "materialization_or_builder")
    qualified = pair.get("admitted_for_mode_specific_follow_on") is True
    mechanism_tags: list[str] = []
    if isinstance(input_delta, (int, float)) and input_delta < 0:
        mechanism_tags.append("total_input_amplification")
    if isinstance(request_delta, (int, float)) and request_delta < 0:
        mechanism_tags.append("request_amplification")
    if isinstance(search_delta, (int, float)) and search_delta < 0:
        mechanism_tags.append("search_or_inspection_amplification")
    if (
        isinstance(input_delta, (int, float))
        and input_delta < 0
        and isinstance(cache_read_delta, (int, float))
        and cache_read_delta < 0
        and abs(cache_read_delta) >= abs(input_delta) * 0.75
    ):
        mechanism_tags.append("cache_read_dominates_total_input_amplification")
    if isinstance(uncached_delta, (int, float)) and uncached_delta < 0:
        mechanism_tags.append("uncached_input_amplification")
    return {
        "source_receipt": source_receipt,
        "pair_name": pair.get("pair_name"),
        "qualified": qualified,
        "classification": pair.get("classification"),
        "control_run_id": pair.get("control_run_id"),
        "pruned_run_id": pair.get("pruned_run_id"),
        "input_tokens_control_minus_pruned": input_delta,
        "cache_read_tokens_control_minus_pruned": cache_read_delta,
        "uncached_input_tokens_control_minus_pruned": uncached_delta,
        "request_count_control_minus_pruned": request_delta,
        "search_or_inspection_control_minus_pruned": search_delta,
        "materialization_or_builder_control_minus_pruned": materialization_delta,
        "api_equivalent_usd_control_minus_pruned": delta_value(
            pair, "api_equivalent_usd_control_minus_pruned"
        ),
        "blockers": pair.get("blockers") or [],
        "mechanism_tags": mechanism_tags,
    }


def policy_summary(path: Path | None) -> dict[str, Any] | None:
    if path is None:
        return None
    payload = load_json(path)
    rules = payload.get("usage_boundary_extra_rules")
    rules_present = isinstance(rules, list) and bool(rules)
    joined_rules = " ".join(str(rule).lower() for rule in rules or [])
    has_search_guard = (
        re.search(r"\bdo not perform broad\b.{0,80}\bsearch expansion\b", joined_rules)
        is not None
    )
    has_materialization_guard = (
        re.search(
            r"\bdo not rerun phase 1,\s*phase 2,\s*or phase 3 source materialization\b",
            joined_rules,
        )
        is not None
    )
    return {
        "path": str(path),
        "sha256": sha256_path(path),
        "policy_id": payload.get("policy_id"),
        "usage_boundary_extra_rules_present": rules_present,
        "search_expansion_guard_present": has_search_guard,
        "materialization_guard_present": has_materialization_guard,
        "admitted_for_bounded_probe": rules_present and has_search_guard and has_materialization_guard,
    }


def build_receipt(amplification_paths: list[Path], repair_policy: Path | None) -> dict[str, Any]:
    pair_rows: list[dict[str, Any]] = []
    for path in amplification_paths:
        payload = load_json(path)
        for pair in payload.get("pairs") or []:
            if isinstance(pair, dict):
                pair_rows.append(compact_pair(pair, str(path)))
    qualified_rows = [row for row in pair_rows if row["qualified"] is True]
    failed_rows = [row for row in pair_rows if row["qualified"] is not True]
    failed_with_request_amp = [
        row for row in failed_rows if "request_amplification" in row["mechanism_tags"]
    ]
    failed_with_search_amp = [
        row for row in failed_rows if "search_or_inspection_amplification" in row["mechanism_tags"]
    ]
    failed_input_amplified = [
        row for row in failed_rows if "total_input_amplification" in row["mechanism_tags"]
    ]
    failed_cache_dominated = [
        row for row in failed_rows if "cache_read_dominates_total_input_amplification" in row["mechanism_tags"]
    ]
    qualified_with_uncached_amp = [
        row for row in qualified_rows if "uncached_input_amplification" in row["mechanism_tags"]
    ]
    failed_with_uncached_savings = [
        row
        for row in failed_rows
        if isinstance(row.get("uncached_input_tokens_control_minus_pruned"), (int, float))
        and row["uncached_input_tokens_control_minus_pruned"] > 0
    ]
    repair = policy_summary(repair_policy)
    checks = {
        "pair_evidence_present": bool(pair_rows),
        "has_winning_and_losing_pairs": bool(qualified_rows) and bool(failed_rows),
        "failed_pairs_show_request_or_search_amplification": bool(
            failed_with_request_amp or failed_with_search_amp
        ),
        "failed_input_amplification_cache_read_dominated": (
            bool(failed_input_amplified)
            and len(failed_cache_dominated) * 2 > len(failed_input_amplified)
        ),
        "uncached_input_not_sufficient_predictor": bool(
            qualified_with_uncached_amp or failed_with_uncached_savings
        ),
        "repair_policy_probe_guard_admitted": (
            (repair or {}).get("admitted_for_bounded_probe") is True if repair else False
        ),
    }
    mechanism = "post_pruning_search_request_and_cache_read_variance"
    if all(
        checks[key]
        for key in (
            "pair_evidence_present",
            "has_winning_and_losing_pairs",
            "failed_pairs_show_request_or_search_amplification",
            "failed_input_amplification_cache_read_dominated",
            "uncached_input_not_sufficient_predictor",
            "repair_policy_probe_guard_admitted",
        )
    ):
        result = "repair_candidate_admitted_for_bounded_probe"
        pass_value = True
        next_move = (
            "Run at most two serialized benchmark gpt-5.5 control/pruned probes with the "
            "repair policy, then stop for synthesis before any broader matrix."
        )
    elif checks["repair_policy_probe_guard_admitted"] is not True:
        result = "fail_closed_repair_policy_not_admitted"
        pass_value = False
        next_move = "Do not run live probes until a repair policy names search/request guardrails."
    else:
        result = "fail_closed_no_controllable_variance_mechanism"
        pass_value = False
        next_move = "Park current source-pruning policy and do not spend on another same-policy matrix."
    return {
        "schema_version": 1,
        "receipt_type": "source_pruning_variance_rca",
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "result": result,
        "pass": pass_value,
        "mechanism": mechanism,
        "checks": checks,
        "input_receipts": [
            {"path": str(path), "sha256": sha256_path(path)} for path in amplification_paths
        ],
        "repair_policy": repair,
        "summary": {
            "pair_count": len(pair_rows),
            "qualified_pair_count": len(qualified_rows),
            "failed_pair_count": len(failed_rows),
            "failed_request_amplification_count": len(failed_with_request_amp),
            "failed_search_or_inspection_amplification_count": len(failed_with_search_amp),
            "failed_cache_read_dominated_count": len(failed_cache_dominated),
            "qualified_uncached_input_amplification_count": len(qualified_with_uncached_amp),
            "failed_uncached_input_savings_count": len(failed_with_uncached_savings),
        },
        "pairs": pair_rows,
        "recommended_next_owner_move": next_move,
        "non_claims": [
            "No production adoption",
            "No durable token or dollar savings claim",
            "No GitHub Copilot billing proof",
            "No model recommendation",
            "Repair admission allows only bounded probes, not broad matrix promotion",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--amplification-receipt", action="append", required=True)
    parser.add_argument("--repair-policy")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    repair_policy = Path(args.repair_policy).expanduser().resolve() if args.repair_policy else None
    receipt = build_receipt(
        [Path(raw).expanduser().resolve() for raw in args.amplification_receipt],
        repair_policy,
    )
    output = Path(args.output).expanduser().resolve()
    write_json(output, receipt)
    print(output)
    return 0 if receipt.get("pass") is True else 1


if __name__ == "__main__":
    raise SystemExit(main())

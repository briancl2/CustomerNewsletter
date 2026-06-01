#!/usr/bin/env python3
"""Build a variance receipt for fresh benchmark source-pruning pairs."""

from __future__ import annotations

import argparse
import datetime as dt
import statistics
from pathlib import Path
from typing import Any

from build_source_pruning_amplification_receipt import build_pair, parse_pair
from newsletter_experiment_common import write_json


DIRECT_TOKEN_DELTA_KEYS = (
    "input_tokens_control_minus_pruned",
    "output_tokens_control_minus_pruned",
    "cache_read_tokens_control_minus_pruned",
    "cache_write_tokens_control_minus_pruned",
    "reasoning_tokens_control_minus_pruned",
)


def reduction_fraction(pair: dict[str, Any]) -> float | None:
    control = ((pair.get("control") or {}).get("tokens") or {}).get("input_tokens")
    delta = ((pair.get("deltas") or {}).get("input_tokens_control_minus_pruned"))
    if not isinstance(control, (int, float)) or control <= 0:
        return None
    if not isinstance(delta, (int, float)):
        return None
    return round(delta / control, 6)


def numeric_delta(pair: dict[str, Any], key: str) -> int | float | None:
    value = (pair.get("deltas") or {}).get(key)
    return value if isinstance(value, (int, float)) else None


def median(values: list[int | float]) -> int | float | None:
    if not values:
        return None
    return statistics.median(values)


def total_direct_token_delta(pair: dict[str, Any]) -> int | float | None:
    values = [numeric_delta(pair, key) for key in DIRECT_TOKEN_DELTA_KEYS]
    if not all(isinstance(value, (int, float)) for value in values):
        return None
    return sum(values)


def sum_numeric_or_none(rows: list[dict[str, Any]], key: str) -> int | float | None:
    values = [row.get(key) for row in rows]
    if not all(isinstance(value, (int, float)) for value in values):
        return None
    return sum(values)


def values_present(values: list[Any]) -> bool:
    return all(value not in (None, "") for value in values)


def unique_values(values: list[Any]) -> bool:
    normalized = [str(value) for value in values]
    return len(set(normalized)) == len(normalized)


def compact_pair(pair: dict[str, Any]) -> dict[str, Any]:
    input_delta = numeric_delta(pair, "input_tokens_control_minus_pruned")
    request_delta = numeric_delta(pair, "request_count_control_minus_pruned")
    cost_delta = numeric_delta(pair, "api_equivalent_usd_control_minus_pruned")
    total_delta = total_direct_token_delta(pair)
    return {
        "pair_name": pair.get("pair_name"),
        "classification": pair.get("classification"),
        "qualified": pair.get("admitted_for_mode_specific_follow_on") is True,
        "mode": pair.get("mode"),
        "control_run_id": pair.get("control_run_id"),
        "pruned_run_id": pair.get("pruned_run_id"),
        "input_tokens_control_minus_pruned": input_delta,
        "input_token_reduction_fraction": reduction_fraction(pair),
        "request_count_control_minus_pruned": request_delta,
        "output_tokens_control_minus_pruned": numeric_delta(pair, "output_tokens_control_minus_pruned"),
        "reasoning_tokens_control_minus_pruned": numeric_delta(pair, "reasoning_tokens_control_minus_pruned"),
        "total_direct_tokens_control_minus_pruned": total_delta,
        "api_equivalent_usd_control_minus_pruned": cost_delta,
        "blockers": pair.get("blockers") or [],
        "failed_checks": sorted(
            key for key, value in (pair.get("checks") or {}).items() if value is not True
        ),
    }


def build_receipt(
    pairs: list[tuple[str, Path, Path]],
    *,
    attempted_live_rows: int,
    max_live_row_attempts: int,
    min_qualified_pairs: int,
    median_input_reduction_min: float,
) -> dict[str, Any]:
    pair_rows = [build_pair(name, control, pruned) for name, control, pruned in pairs]
    compact_pairs = [compact_pair(pair) for pair in pair_rows]
    qualified_pairs = [pair for pair in compact_pairs if pair["qualified"] is True]
    all_reduction_values = [
        pair["input_token_reduction_fraction"]
        for pair in compact_pairs
        if isinstance(pair.get("input_token_reduction_fraction"), (int, float))
    ]
    qualified_reduction_values = [
        pair["input_token_reduction_fraction"]
        for pair in qualified_pairs
        if isinstance(pair.get("input_token_reduction_fraction"), (int, float))
    ]
    all_request_deltas = [
        pair["request_count_control_minus_pruned"]
        for pair in compact_pairs
        if isinstance(pair.get("request_count_control_minus_pruned"), (int, float))
    ]
    qualified_request_deltas = [
        pair["request_count_control_minus_pruned"]
        for pair in qualified_pairs
        if isinstance(pair.get("request_count_control_minus_pruned"), (int, float))
    ]
    all_modes = sorted({str(pair.get("mode") or "unknown") for pair in compact_pairs})
    median_reduction = median(all_reduction_values)
    median_request_delta = median(all_request_deltas)
    qualified_median_reduction = median(qualified_reduction_values)
    qualified_median_request_delta = median(qualified_request_deltas)
    all_pairs_have_numeric_input_and_request_metrics = (
        len(all_reduction_values) == len(compact_pairs)
        and len(all_request_deltas) == len(compact_pairs)
    )
    attempted_live_rows_covers_pair_count = attempted_live_rows >= len(compact_pairs) * 2
    pair_names = [pair.get("pair_name") for pair in compact_pairs]
    control_run_ids = [pair.get("control_run_id") for pair in compact_pairs]
    pruned_run_ids = [pair.get("pruned_run_id") for pair in compact_pairs]
    pair_names_present = values_present(pair_names)
    control_run_ids_present = values_present(control_run_ids)
    pruned_run_ids_present = values_present(pruned_run_ids)
    pair_names_unique = pair_names_present and unique_values(pair_names)
    control_run_ids_unique = control_run_ids_present and unique_values(control_run_ids)
    pruned_run_ids_unique = pruned_run_ids_present and unique_values(pruned_run_ids)
    checks = {
        "benchmark_only": all_modes == ["benchmark"],
        "attempt_budget_observed": attempted_live_rows <= max_live_row_attempts,
        "attempted_live_rows_covers_pair_count": attempted_live_rows_covers_pair_count,
        "pair_names_present": pair_names_present,
        "control_run_ids_present": control_run_ids_present,
        "pruned_run_ids_present": pruned_run_ids_present,
        "pair_names_unique": pair_names_unique,
        "control_run_ids_unique": control_run_ids_unique,
        "pruned_run_ids_unique": pruned_run_ids_unique,
        "all_pairs_have_numeric_input_and_request_metrics": (
            all_pairs_have_numeric_input_and_request_metrics
        ),
        "qualified_pair_floor_met": len(qualified_pairs) >= min_qualified_pairs,
        "median_input_reduction_met": (
            all_pairs_have_numeric_input_and_request_metrics
            and
            isinstance(median_reduction, (int, float))
            and median_reduction >= median_input_reduction_min
        ),
        "median_request_count_not_amplified": (
            all_pairs_have_numeric_input_and_request_metrics
            and
            isinstance(median_request_delta, (int, float))
            and median_request_delta >= 0
        ),
    }
    pass_value = all(checks.values())
    if pass_value:
        result = "benchmark_source_pruning_variance_bounded"
        next_move = (
            "Prepare a narrow benchmark adoption-readiness packet or a separate "
            "production search-architecture re-entry batch; do not generalize to production."
        )
    elif checks["benchmark_only"] is not True:
        result = "fail_closed_non_benchmark_input"
        next_move = "Use this receipt only for benchmark rows; run a separate mode-specific receipt for production."
    elif checks["attempt_budget_observed"] is not True:
        result = "fail_closed_attempt_budget_exceeded"
        next_move = "Close the batch as over budget or create a new preregistered attempt budget before interpreting results."
    elif (
        checks["pair_names_present"] is not True
        or checks["control_run_ids_present"] is not True
        or checks["pruned_run_ids_present"] is not True
    ):
        result = "fail_closed_missing_pair_identifier"
        next_move = "Repair missing pair or run identifiers before any variance claim."
    elif (
        checks["pair_names_unique"] is not True
        or checks["control_run_ids_unique"] is not True
        or checks["pruned_run_ids_unique"] is not True
    ):
        result = "fail_closed_duplicate_pair_evidence"
        next_move = "Repair the pair manifest so each variance row is independent before any variance claim."
    elif checks["attempted_live_rows_covers_pair_count"] is not True:
        result = "fail_closed_attempt_count_underreported"
        next_move = "Correct the attempted-live-row count before interpreting the variance receipt."
    elif checks["all_pairs_have_numeric_input_and_request_metrics"] is not True:
        result = "fail_closed_missing_variance_metrics"
        next_move = (
            "Repair the missing pair-level input-token or request-count telemetry before "
            "any variance or adoption-readiness claim."
        )
    elif (
        checks["median_input_reduction_met"] is not True
        or checks["median_request_count_not_amplified"] is not True
    ):
        result = "fail_closed_source_pruning_variance_unbounded"
        next_move = (
            "Park the current benchmark source-pruning policy for adoption-readiness "
            "and run a root-cause/repair batch for input-token and request-count amplification."
        )
    elif len(qualified_pairs) < min_qualified_pairs:
        result = "fail_closed_insufficient_qualified_pairs"
        next_move = "Acquire more fresh benchmark pairs or name the exact row-level blocker before any adoption-readiness claim."
    else:
        result = "fail_closed_variance_contract_not_met"
        next_move = "Inspect failed checks and repair only the exact evidence boundary before more live spend."
    return {
        "schema_version": 1,
        "receipt_type": "benchmark_source_pruning_variance_matrix",
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "result": result,
        "pass": pass_value,
        "thresholds": {
            "min_qualified_pairs": min_qualified_pairs,
            "median_input_reduction_min": median_input_reduction_min,
            "max_live_row_attempts": max_live_row_attempts,
        },
        "attempted_live_rows": attempted_live_rows,
        "pair_count": len(pair_rows),
        "qualified_pair_count": len(qualified_pairs),
        "checks": checks,
        "aggregate": {
            "median_input_token_reduction_fraction": median_reduction,
            "median_request_count_control_minus_pruned": median_request_delta,
            "total_input_tokens_control_minus_pruned": sum_numeric_or_none(
                compact_pairs, "input_tokens_control_minus_pruned"
            ),
            "total_request_count_control_minus_pruned": sum_numeric_or_none(
                compact_pairs, "request_count_control_minus_pruned"
            ),
            "total_direct_tokens_control_minus_pruned": sum_numeric_or_none(
                compact_pairs, "total_direct_tokens_control_minus_pruned"
            ),
            "total_api_equivalent_usd_control_minus_pruned": (
                round(sum_numeric_or_none(compact_pairs, "api_equivalent_usd_control_minus_pruned"), 6)
                if isinstance(
                    sum_numeric_or_none(compact_pairs, "api_equivalent_usd_control_minus_pruned"),
                    (int, float),
                )
                else None
            ),
            "qualified_median_input_token_reduction_fraction": qualified_median_reduction,
            "qualified_median_request_count_control_minus_pruned": qualified_median_request_delta,
            "qualified_total_input_tokens_control_minus_pruned": sum_numeric_or_none(
                qualified_pairs, "input_tokens_control_minus_pruned"
            ),
            "qualified_total_request_count_control_minus_pruned": sum_numeric_or_none(
                qualified_pairs, "request_count_control_minus_pruned"
            ),
            "qualified_total_direct_tokens_control_minus_pruned": sum_numeric_or_none(
                qualified_pairs, "total_direct_tokens_control_minus_pruned"
            ),
            "qualified_total_api_equivalent_usd_control_minus_pruned": (
                round(
                    sum_numeric_or_none(qualified_pairs, "api_equivalent_usd_control_minus_pruned"),
                    6,
                )
                if isinstance(
                    sum_numeric_or_none(qualified_pairs, "api_equivalent_usd_control_minus_pruned"),
                    (int, float),
                )
                else None
            ),
        },
        "pairs": compact_pairs,
        "full_pair_receipt_rows": pair_rows,
        "recommended_next_owner_move": next_move,
        "non_claims": [
            "No production adoption",
            "No durable token or dollar savings claim",
            "No GitHub Copilot billing proof",
            "No model recommendation",
            "Benchmark-only result; production remains blocked",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pair", action="append", required=True, help="name:control_run_dir:pruned_run_dir")
    parser.add_argument("--attempted-live-rows", type=int, required=True)
    parser.add_argument("--max-live-row-attempts", type=int, default=12)
    parser.add_argument("--min-qualified-pairs", type=int, default=5)
    parser.add_argument("--median-input-reduction-min", type=float, default=0.05)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    receipt = build_receipt(
        [parse_pair(raw) for raw in args.pair],
        attempted_live_rows=args.attempted_live_rows,
        max_live_row_attempts=args.max_live_row_attempts,
        min_qualified_pairs=args.min_qualified_pairs,
        median_input_reduction_min=args.median_input_reduction_min,
    )
    output = Path(args.output).expanduser().resolve()
    write_json(output, receipt)
    print(output)
    return 0 if receipt.get("pass") is True else 1


if __name__ == "__main__":
    raise SystemExit(main())

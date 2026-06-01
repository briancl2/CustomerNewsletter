#!/usr/bin/env python3
"""Aggregate closed-bundle source-pruning proof-pair receipts."""

from __future__ import annotations

import argparse
import datetime as dt
import statistics
from pathlib import Path
from typing import Any

from newsletter_experiment_common import load_json, sha256_path, write_json


DIRECT_TOKEN_KEYS = (
    "input_tokens",
    "output_tokens",
    "cache_read_tokens",
    "cache_write_tokens",
    "reasoning_tokens",
)


def _as_number(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    return None


def _token_total(tokens: dict[str, Any]) -> float:
    total = 0.0
    for key in DIRECT_TOKEN_KEYS:
        value = _as_number(tokens.get(key))
        if value is not None:
            total += value
    return total


def _all_direct_token_values_present(tokens: dict[str, Any]) -> bool:
    return all(_as_number(tokens.get(key)) is not None for key in DIRECT_TOKEN_KEYS)


def _required_boundary_checks(checks: dict[str, Any]) -> dict[str, bool]:
    keys = (
        "base_pair_comparable",
        "policy_declares_closed_bundle",
        "pruning_receipt_declares_closed_bundle",
        "prompt_boundary_bound",
        "control_prompt_state_disabled",
        "candidate_prompt_state_enabled",
        "candidate_prompt_apply_policy_command_present",
        "candidate_prompt_context_artifact_reference_present",
    )
    return {key: checks.get(key) is True for key in keys}


def summarize_pair(path: Path, source: str) -> dict[str, Any]:
    payload = load_json(path)
    if not isinstance(payload, dict):
        raise SystemExit(f"Missing or invalid pair receipt: {path}")
    checks = payload.get("checks") or {}
    boundary_checks = _required_boundary_checks(checks)
    pair = payload.get("pair") or {}
    pair_checks = pair.get("checks") or {}
    deltas = pair.get("deltas") or {}
    logical_key_complete = all(
        pair.get(key)
        for key in ("control_run_id", "pruned_run_id", "mode", "primary_model")
    )
    control_tokens = ((pair.get("control") or {}).get("tokens") or {})
    candidate_tokens = ((pair.get("pruned") or {}).get("tokens") or {})
    control_token_values_present = _all_direct_token_values_present(control_tokens)
    candidate_token_values_present = _all_direct_token_values_present(candidate_tokens)
    control_total = _token_total(control_tokens) if control_token_values_present else None
    candidate_total = _token_total(candidate_tokens) if candidate_token_values_present else None
    total_delta = (
        control_total - candidate_total
        if control_total is not None and candidate_total is not None
        else None
    )
    request_delta = _as_number(deltas.get("request_count_control_minus_pruned"))
    reduction_fraction = (
        total_delta / control_total
        if total_delta is not None and control_total is not None and control_total > 0
        else None
    )
    required_pair_checks = {
        "same_mode": pair_checks.get("same_mode") is True,
        "same_date_range": pair_checks.get("same_date_range") is True,
        "same_primary_model": pair_checks.get("same_primary_model") is True,
        "control_prompt_equality_pass": pair_checks.get("control_prompt_equality_pass") is True,
        "candidate_prompt_equality_pass": pair_checks.get("pruned_prompt_equality_pass") is True,
        "control_direct_token_fields_pass": pair_checks.get("control_direct_token_fields_pass") is True,
        "candidate_direct_token_fields_pass": pair_checks.get("pruned_direct_token_fields_pass") is True,
        "control_quality_pass": pair_checks.get("control_quality_pass") is True,
        "candidate_quality_pass": pair_checks.get("pruned_quality_pass") is True,
        "control_pricing_pass": pair_checks.get("control_pricing_pass") is True,
        "candidate_pricing_pass": pair_checks.get("pruned_pricing_pass") is True,
        "control_source_pruning_artifacts_absent": pair_checks.get("control_source_pruning_artifacts_absent") is True,
        "candidate_source_pruning_artifacts_complete": pair_checks.get("pruned_source_pruning_artifacts_complete") is True,
        "policy_hash_bound": pair_checks.get("policy_hash_bound") is True,
        "control_session_trace_qualified": pair_checks.get("control_session_trace_qualified") is True,
        "candidate_session_trace_qualified": pair_checks.get("pruned_session_trace_qualified") is True,
        "no_new_warning_taxonomy": pair_checks.get("no_new_warning_taxonomy") is True,
    }
    metrics_complete = (
        control_token_values_present
        and candidate_token_values_present
        and control_total is not None
        and control_total > 0
        and reduction_fraction is not None
        and request_delta is not None
    )
    evidence_complete = (
        logical_key_complete
        and all(boundary_checks.values())
        and all(required_pair_checks.values())
        and metrics_complete
    )
    positive = (
        evidence_complete
        and reduction_fraction is not None
        and reduction_fraction >= 0.05
        and request_delta is not None
        and request_delta >= 0
    )
    token_delta_available = control_total is not None and candidate_total is not None
    request_delta_available = request_delta is not None
    amplification_signal = (
        (token_delta_available and candidate_total > control_total)
        or (request_delta_available and request_delta < 0)
    )
    amplification = metrics_complete and (
        (total_delta is not None and total_delta < 0)
        or (request_delta is not None and request_delta < 0)
    )
    return {
        "path": str(path),
        "sha256": sha256_path(path),
        "source": source,
        "classification": payload.get("classification"),
        "pair_name": pair.get("pair_name"),
        "control_run_id": pair.get("control_run_id"),
        "candidate_run_id": pair.get("pruned_run_id"),
        "mode": pair.get("mode"),
        "model": pair.get("primary_model"),
        "evidence_complete_pair": evidence_complete,
        "metrics_complete_pair": metrics_complete,
        "logical_key_complete": logical_key_complete,
        "positive_pair": positive,
        "amplification_pair": amplification,
        "amplification_signal_pair": amplification_signal,
        "amplification_signal_complete": token_delta_available or request_delta_available,
        "boundary_checks": boundary_checks,
        "control_total_direct_tokens": control_total,
        "candidate_total_direct_tokens": candidate_total,
        "total_direct_tokens_control_minus_candidate": total_delta,
        "total_direct_token_reduction_fraction": reduction_fraction,
        "request_count_control_minus_candidate": request_delta,
        "api_equivalent_usd_control_minus_candidate": deltas.get("api_equivalent_usd_control_minus_pruned"),
        "pair_checks": required_pair_checks,
        "token_values_present": {
            "control_all_direct_token_values_present": control_token_values_present,
            "candidate_all_direct_token_values_present": candidate_token_values_present,
        },
    }


def median(values: list[float]) -> float | None:
    return statistics.median(values) if values else None


def build_receipt(
    prior_receipts: list[Path],
    fresh_receipts: list[Path],
    *,
    min_total_pairs: int,
    min_prior_pairs: int,
    min_fresh_pairs: int,
    reduction_threshold: float,
) -> dict[str, Any]:
    raw_pairs = [summarize_pair(path, "prior") for path in prior_receipts]
    raw_pairs.extend(summarize_pair(path, "fresh") for path in fresh_receipts)
    pairs: list[dict[str, Any]] = []
    duplicate_pair_inputs: list[dict[str, str]] = []
    seen_logical_keys: set[tuple[str, str, str, str]] = set()
    for pair in raw_pairs:
        logical_key = (
            str(pair.get("control_run_id") or ""),
            str(pair.get("candidate_run_id") or ""),
            str(pair.get("mode") or ""),
            str(pair.get("model") or ""),
        )
        if logical_key in seen_logical_keys:
            duplicate_pair_inputs.append(
                {
                    "path": str(pair["path"]),
                    "sha256": str(pair["sha256"]),
                    "source": str(pair["source"]),
                    "logical_key": "|".join(logical_key),
                }
            )
            continue
        seen_logical_keys.add(logical_key)
        pairs.append(pair)
    evidence_pairs = [pair for pair in pairs if pair["evidence_complete_pair"]]
    prior_evidence_pairs = [pair for pair in evidence_pairs if pair["source"] == "prior"]
    fresh_evidence_pairs = [pair for pair in evidence_pairs if pair["source"] == "fresh"]
    reduction_fractions = [
        float(pair["total_direct_token_reduction_fraction"])
        for pair in evidence_pairs
        if pair["total_direct_token_reduction_fraction"] is not None
    ]
    request_deltas = [
        float(pair["request_count_control_minus_candidate"])
        for pair in evidence_pairs
        if pair["request_count_control_minus_candidate"] is not None
    ]
    median_reduction = median(reduction_fractions)
    median_request_delta = median(request_deltas)
    checks = {
        "min_total_evidence_complete_pairs_met": len(evidence_pairs) >= min_total_pairs,
        "min_prior_evidence_complete_pairs_met": len(prior_evidence_pairs) >= min_prior_pairs,
        "min_fresh_evidence_complete_pairs_met": len(fresh_evidence_pairs) >= min_fresh_pairs,
        "median_total_direct_token_reduction_met": median_reduction is not None and median_reduction >= reduction_threshold,
        "median_request_count_not_higher": median_request_delta is not None and median_request_delta >= 0,
        "all_evidence_complete_pairs_positive": bool(evidence_pairs)
        and all(pair["positive_pair"] for pair in evidence_pairs),
        "no_duplicate_pair_inputs": not duplicate_pair_inputs,
        "all_logical_keys_complete": all(pair["logical_key_complete"] for pair in pairs),
    }
    floor_met = (
        checks["min_total_evidence_complete_pairs_met"]
        and checks["min_prior_evidence_complete_pairs_met"]
        and checks["min_fresh_evidence_complete_pairs_met"]
        and checks["no_duplicate_pair_inputs"]
        and checks["all_logical_keys_complete"]
    )
    metrics_complete_pairs = [pair for pair in pairs if pair["metrics_complete_pair"]]
    prior_metrics_pairs = [pair for pair in metrics_complete_pairs if pair["source"] == "prior"]
    fresh_metrics_pairs = [pair for pair in metrics_complete_pairs if pair["source"] == "fresh"]
    metrics_floor_met = (
        len(metrics_complete_pairs) >= min_total_pairs
        and len(prior_metrics_pairs) >= min_prior_pairs
        and len(fresh_metrics_pairs) >= min_fresh_pairs
        and checks["no_duplicate_pair_inputs"]
    )
    all_metrics_pairs_amplify = bool(metrics_complete_pairs) and all(
        pair["amplification_pair"] for pair in metrics_complete_pairs
    )
    amplification_signal_pairs = [pair for pair in pairs if pair["amplification_signal_complete"]]
    prior_signal_pairs = [pair for pair in amplification_signal_pairs if pair["source"] == "prior"]
    fresh_signal_pairs = [pair for pair in amplification_signal_pairs if pair["source"] == "fresh"]
    signal_floor_met = (
        len(amplification_signal_pairs) >= min_total_pairs
        and len(prior_signal_pairs) >= min_prior_pairs
        and len(fresh_signal_pairs) >= min_fresh_pairs
        and checks["no_duplicate_pair_inputs"]
    )
    all_signal_pairs_amplify = bool(amplification_signal_pairs) and all(
        pair["amplification_signal_pair"] for pair in amplification_signal_pairs
    )
    if duplicate_pair_inputs:
        result = "blocked_duplicate_pair_inputs"
        recommended = "Do not classify the tactic until duplicate logical pair inputs are removed."
    elif not checks["all_logical_keys_complete"]:
        result = "blocked_missing_pair_identity"
        recommended = "Do not classify the tactic until every pair receipt has control and candidate run IDs, mode, and model."
    elif floor_met:
        positive_count = sum(1 for pair in evidence_pairs if pair["positive_pair"])
        if (
            checks["median_total_direct_token_reduction_met"]
            and checks["median_request_count_not_higher"]
            and checks["all_evidence_complete_pairs_positive"]
        ):
            result = "qualified_closed_bundle_positive_signal"
            recommended = "Promote a narrow closed-bundle source-pruning confirmation/adoption-readiness packet without durable savings claims."
        elif all(pair["amplification_pair"] for pair in evidence_pairs) or (
            metrics_floor_met and all_metrics_pairs_amplify
        ) or (
            signal_floor_met and all_signal_pairs_amplify
        ):
            result = "fail_closed_repeated_closed_bundle_amplification"
            recommended = "Park the current closed-bundle policy path and pivot to a different savings family or a new architecture."
        elif positive_count == 0:
            result = "fail_closed_no_signal_flat_evidence"
            recommended = "Do not promote; pivot or redesign because the evidence-complete floor produced no positive pairs."
        else:
            result = "partial_mixed_closed_bundle_evidence"
            recommended = "Do not promote; synthesize whether to continue, redesign, or pivot."
    elif (metrics_floor_met and all_metrics_pairs_amplify) or (
        signal_floor_met and all_signal_pairs_amplify
    ):
        result = "fail_closed_repeated_closed_bundle_amplification_incomplete_evidence"
        recommended = "Do not promote; repair evidence binding before any continuation because metrics-complete rows repeatedly amplified."
    else:
        result = "blocked_insufficient_evidence_complete_pairs"
        recommended = "Do not classify the tactic until the evidence-complete pair floor is met or the missing evidence blocker is repaired."
    return {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "receipt_type": "closed_bundle_source_pruning_replication",
        "result": result,
        "pass": result == "qualified_closed_bundle_positive_signal",
        "checks": checks,
        "thresholds": {
            "min_total_evidence_complete_pairs": min_total_pairs,
            "min_prior_evidence_complete_pairs": min_prior_pairs,
            "min_fresh_evidence_complete_pairs": min_fresh_pairs,
            "median_total_direct_token_reduction_fraction": reduction_threshold,
            "median_request_count_control_minus_candidate": 0,
        },
        "counts": {
            "pair_receipts": len(raw_pairs),
            "unique_pair_receipts": len(pairs),
            "duplicate_pair_receipts": len(duplicate_pair_inputs),
            "metrics_complete_pairs": len(metrics_complete_pairs),
            "amplification_signal_complete_pairs": len(amplification_signal_pairs),
            "evidence_complete_pairs": len(evidence_pairs),
            "prior_evidence_complete_pairs": len(prior_evidence_pairs),
            "fresh_evidence_complete_pairs": len(fresh_evidence_pairs),
            "positive_pairs": sum(1 for pair in evidence_pairs if pair["positive_pair"]),
            "amplification_pairs": sum(1 for pair in evidence_pairs if pair["amplification_pair"]),
        },
        "aggregate": {
            "median_total_direct_token_reduction_fraction": median_reduction,
            "median_request_count_control_minus_candidate": median_request_delta,
            "control_minus_candidate_sign_convention": "positive means control used more than candidate; negative means candidate used more than control",
            "aggregate_direction": (
                "unknown_no_metrics_complete_pairs"
                if median_reduction is None
                else
                "candidate_lower_total_tokens"
                if median_reduction > 0
                else "candidate_higher_or_equal_total_tokens"
            ),
            "total_direct_tokens_control_minus_candidate": sum(
                float(pair["total_direct_tokens_control_minus_candidate"]) for pair in evidence_pairs
            ),
            "api_equivalent_usd_control_minus_candidate": (
                sum(float(pair["api_equivalent_usd_control_minus_candidate"]) for pair in evidence_pairs)
                if all(
                    _as_number(pair.get("api_equivalent_usd_control_minus_candidate")) is not None
                    for pair in evidence_pairs
                )
                else None
            ),
            "api_equivalent_usd_pairs_complete": all(
                _as_number(pair.get("api_equivalent_usd_control_minus_candidate")) is not None
                for pair in evidence_pairs
            ),
        },
        "pairs": pairs,
        "duplicate_pair_inputs": duplicate_pair_inputs,
        "recommended_next_owner_move": recommended,
        "non_claims": [
            "No production adoption",
            "No durable token or dollar savings claim",
            "No GitHub Copilot billing proof",
            "No model recommendation",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prior-pair-receipt", action="append", default=[])
    parser.add_argument("--fresh-pair-receipt", action="append", default=[])
    parser.add_argument("--min-total-pairs", type=int, default=3)
    parser.add_argument("--min-prior-pairs", type=int, default=1)
    parser.add_argument("--min-fresh-pairs", type=int, default=2)
    parser.add_argument("--reduction-threshold", type=float, default=0.05)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    receipt = build_receipt(
        [Path(path).expanduser().resolve() for path in args.prior_pair_receipt],
        [Path(path).expanduser().resolve() for path in args.fresh_pair_receipt],
        min_total_pairs=args.min_total_pairs,
        min_prior_pairs=args.min_prior_pairs,
        min_fresh_pairs=args.min_fresh_pairs,
        reduction_threshold=args.reduction_threshold,
    )
    output = Path(args.output).expanduser().resolve()
    write_json(output, receipt)
    print(output)
    return 0 if receipt.get("pass") is True else 1


if __name__ == "__main__":
    raise SystemExit(main())

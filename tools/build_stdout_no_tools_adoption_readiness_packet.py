#!/usr/bin/env python3
"""Build a disabled-by-default adoption-readiness packet for stdout/no-tools reuse."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
from pathlib import Path
from typing import Any

from newsletter_experiment_common import sha256_path, write_json


REQUIRED_CONFIG_GATES = {
    "qualified_pair_count",
    "minimum_total_direct_token_reduction_pct",
    "candidate_tool_calls",
    "candidate_request_count_not_higher",
    "direct_provider_token_fields_required",
    "session_binding_required",
    "no_refetch_binding_required",
    "quality_pass_required",
}
REQUIRED_NON_CLAIM_BOUNDARIES: dict[str, tuple[re.Pattern[str], ...]] = {
    "production enablement": (
        re.compile(r"\b(?:not|does not|no)\b[^.]*\bproduction (?:enablement|behavior|adoption)\b"),
        re.compile(r"\bdoes not enable production behavior\b"),
    ),
    "durable savings": (
        re.compile(r"\bnot\b[^.]*\bdurable savings\b"),
        re.compile(r"\bno\b[^.]*\bdurable savings\b"),
    ),
    "billing proof": (
        re.compile(r"\bnot\b[^.]*\b(?:github copilot billing|billing proof|billing claim)\b"),
        re.compile(r"\bno\b[^.]*\b(?:github copilot billing|billing proof|billing claim)\b"),
    ),
    "model recommendation": (
        re.compile(r"\bnot\b[^.]*\bmodel recommendation\b"),
        re.compile(r"\bno\b[^.]*\bmodel recommendation\b"),
    ),
}
AFFIRMATIVE_CLAIM_TERMS: dict[str, tuple[str, ...]] = {
    "production enablement": ("production enablement", "enable production behavior", "production adoption"),
    "durable savings": ("durable savings claim", "durable savings proof"),
    "billing proof": ("github copilot billing", "billing proof", "billing claim"),
    "model recommendation": ("model recommendation",),
}
REQUIRED_PAIR_SIDECARS = {
    "phase2_selected_source_ids",
    "phase2_fetch_attempt_ledger",
    "phase2_no_refetch_compliance",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adoption-config", required=True)
    parser.add_argument("--production-confirmation-receipt", required=True)
    parser.add_argument("--burst40-adoption-packet", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--minimum-production-pairs", type=int, default=2)
    parser.add_argument("--minimum-reduction-pct", type=float, default=5.0)
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def missing_non_claim_boundaries(haystack: list[Any]) -> list[str]:
    items = [str(item).lower() for item in haystack]
    missing: list[str] = []
    for boundary, terms in AFFIRMATIVE_CLAIM_TERMS.items():
        patterns = REQUIRED_NON_CLAIM_BOUNDARIES[boundary]
        for item in items:
            if any(term in item for term in terms) and not any(pattern.search(item) for pattern in patterns):
                missing.append(f"affirmative {boundary}")
                break
    for boundary, patterns in REQUIRED_NON_CLAIM_BOUNDARIES.items():
        if not any(pattern.search(item) for pattern in patterns for item in items):
            missing.append(boundary)
    return missing


def as_dict(value: Any, label: str, errors: list[str]) -> dict[str, Any]:
    if isinstance(value, dict):
        return value
    errors.append(f"{label} must be an object")
    return {}


def as_list(value: Any, label: str, errors: list[str]) -> list[Any]:
    if isinstance(value, list):
        return value
    errors.append(f"{label} must be a list")
    return []


def coerce_int(value: Any, label: str, errors: list[str]) -> int | None:
    if type(value) is not int:
        errors.append(f"{label} must be an integer")
        return None
    return value


def coerce_float(value: Any, label: str, errors: list[str]) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        errors.append(f"{label} must be a number")
        return None


def validate_config(config: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if config.get("status") != "disabled_by_default":
        errors.append("adoption config status must be disabled_by_default")
    if config.get("default_enabled") is not False:
        errors.append("adoption config default_enabled must be false")
    if config.get("production_behavior_enabled") is not False:
        errors.append("adoption config production_behavior_enabled must be false")
    if config.get("target_phase") != "phase3_curation":
        errors.append("adoption config target_phase must be phase3_curation")
    if config.get("tactic") != "phase3_stdout_no_tools_artifact_reuse":
        errors.append("adoption config tactic must be phase3_stdout_no_tools_artifact_reuse")

    floor = as_dict(config.get("benchmark_evidence_floor"), "adoption config benchmark_evidence_floor", errors)
    if floor:
        missing_gates = sorted(REQUIRED_CONFIG_GATES - set(floor))
        if missing_gates:
            errors.append(f"adoption config missing benchmark evidence gates: {', '.join(missing_gates)}")
        qualified_pair_count = coerce_int(
            floor.get("qualified_pair_count"), "benchmark evidence floor qualified_pair_count", errors
        )
        minimum_reduction = coerce_float(
            floor.get("minimum_total_direct_token_reduction_pct"),
            "benchmark evidence floor minimum_total_direct_token_reduction_pct",
            errors,
        )
        if qualified_pair_count is not None and qualified_pair_count < 3:
            errors.append("benchmark evidence floor must require at least three qualified pairs")
        if minimum_reduction is not None and minimum_reduction < 5.0:
            errors.append("benchmark evidence floor must require at least 5% token reduction")
        if floor.get("candidate_tool_calls") != 0:
            errors.append("benchmark evidence floor must require zero candidate tool calls")
        for key in (
            "candidate_request_count_not_higher",
            "direct_provider_token_fields_required",
            "session_binding_required",
            "no_refetch_binding_required",
            "quality_pass_required",
        ):
            if floor.get(key) is not True:
                errors.append(f"benchmark evidence floor {key} must be true")

    admission = as_dict(config.get("production_admission_state"), "adoption config production_admission_state", errors)
    if admission:
        if admission.get("no_refetch_admission_attempted") is not True:
            errors.append("production admission must record attempted no-refetch admission")

    if not config.get("rollback_notes"):
        errors.append("adoption config must include rollback_notes")
    missing_non_claims = missing_non_claim_boundaries(list(config.get("non_claims") or []))
    for claim in missing_non_claims:
        errors.append(f"adoption config non_claims missing boundary: {claim}")
    return errors


def validate_burst40_packet(packet: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if packet.get("disabled_by_default") is not True:
        errors.append("Burst-40 adoption packet must be disabled_by_default")
    if packet.get("readiness_verdict") != "ready_for_explicit_future_adoption_review":
        errors.append("Burst-40 adoption packet must be ready_for_explicit_future_adoption_review")
    approval = str(packet.get("required_future_approval") or "").lower()
    if "explicit operator authorization" not in approval:
        errors.append("Burst-40 adoption packet must require explicit operator authorization")
    if not packet.get("rollback_notes"):
        errors.append("Burst-40 adoption packet must include rollback notes")
    missing_non_claims = missing_non_claim_boundaries(list(packet.get("non_claims") or []))
    for claim in missing_non_claims:
        errors.append(f"Burst-40 adoption packet non_claims missing boundary: {claim}")
    return errors


def resolve_receipt_path(raw: Any) -> Path | None:
    if not isinstance(raw, str) or not raw.strip():
        return None
    path = Path(raw).expanduser()
    return path if path.is_absolute() else Path.cwd() / path


def require_true(value: Any, label: str, errors: list[str]) -> None:
    if value is not True:
        errors.append(f"{label} must be true")


def require_zero(value: Any, label: str, errors: list[str]) -> None:
    if value != 0:
        errors.append(f"{label} must be zero")


def validate_pair_receipt(pair: dict[str, Any], minimum_reduction_pct: float) -> tuple[list[str], dict[str, Any]]:
    errors: list[str] = []
    pair_id = str(pair.get("pair_id") or "<unknown>")
    receipt_path = resolve_receipt_path(pair.get("receipt_path"))
    if receipt_path is None:
        return [f"{pair_id}: receipt_path is required"], {"exists": False}
    if not receipt_path.exists():
        return [f"{pair_id}: pair receipt does not exist: {receipt_path}"], {
            "path": str(receipt_path),
            "exists": False,
        }
    try:
        receipt = load_json(receipt_path)
    except (OSError, json.JSONDecodeError) as exc:
        return [f"{pair_id}: pair receipt is not valid JSON: {exc}"], {
            "path": str(receipt_path),
            "exists": True,
            "sha256": sha256_path(receipt_path),
        }
    if not isinstance(receipt, dict):
        return [f"{pair_id}: pair receipt must be an object"], {
            "path": str(receipt_path),
            "exists": True,
            "sha256": sha256_path(receipt_path),
        }

    if receipt.get("receipt_type") != "artifact_reuse_stdout_no_tools_phase3_pair":
        errors.append(f"{pair_id}: pair receipt type is not artifact_reuse_stdout_no_tools_phase3_pair")
    slice_info = as_dict(receipt.get("slice"), f"{pair_id}: pair receipt slice", errors)
    if slice_info.get("mode") != "production":
        errors.append(f"{pair_id}: pair receipt mode must be production")
    admission = as_dict(receipt.get("admission"), f"{pair_id}: pair receipt admission", errors)
    require_true(admission.get("admitted_for_single_live_phase3_pair"), f"{pair_id}: pair admission", errors)
    if admission.get("verdict") != "admit_single_pair_stdout_no_tools_evidence":
        errors.append(f"{pair_id}: pair admission verdict must be admit_single_pair_stdout_no_tools_evidence")
    if admission.get("blockers") not in ([], None):
        errors.append(f"{pair_id}: pair admission blockers must be empty")

    candidate = as_dict(receipt.get("candidate"), f"{pair_id}: pair receipt candidate", errors)
    control = as_dict(receipt.get("control"), f"{pair_id}: pair receipt control", errors)
    for row_name, row in (("candidate", candidate), ("control", control)):
        require_true(row.get("passes"), f"{pair_id}: {row_name} passes", errors)
        metrics = as_dict(row.get("metrics"), f"{pair_id}: {row_name} metrics", errors)
        require_true(metrics.get("direct_fields_complete"), f"{pair_id}: {row_name} direct_fields_complete", errors)
        if metrics.get("session_detection_status") != "bound_candidate":
            errors.append(f"{pair_id}: {row_name} session_detection_status must be bound_candidate")
        if metrics.get("bound_candidate_count") != 1:
            errors.append(f"{pair_id}: {row_name} bound_candidate_count must be 1")
        if metrics.get("candidate_count") != 1:
            errors.append(f"{pair_id}: {row_name} candidate_count must be 1")
        require_true(metrics.get("numeric_fields_complete"), f"{pair_id}: {row_name} numeric_fields_complete", errors)
        if row_name == "candidate":
            require_zero(metrics.get("tool_calls"), f"{pair_id}: candidate metrics tool_calls", errors)
            require_zero(metrics.get("tool_event_count"), f"{pair_id}: candidate metrics tool_event_count", errors)
            if metrics.get("phase_id") != "phase3_stdout_no_tools_artifact_reuse":
                errors.append(f"{pair_id}: candidate phase_id must be phase3_stdout_no_tools_artifact_reuse")
        elif metrics.get("phase_id") != "phase3_curation":
            errors.append(f"{pair_id}: control phase_id must be phase3_curation")

    selected = as_dict(
        receipt.get("selected_source_no_refetch"), f"{pair_id}: selected_source_no_refetch", errors
    )
    if selected.get("admission_verdict") != "admit_no_refetch":
        errors.append(f"{pair_id}: selected_source_no_refetch verdict must be admit_no_refetch")
    sidecars = as_dict(selected.get("sidecars"), f"{pair_id}: selected_source_no_refetch sidecars", errors)
    missing_sidecars = sorted(REQUIRED_PAIR_SIDECARS - set(sidecars))
    if missing_sidecars:
        errors.append(f"{pair_id}: selected_source_no_refetch missing sidecars: {', '.join(missing_sidecars)}")
    for sidecar_name, state in sidecars.items():
        state_dict = as_dict(state, f"{pair_id}: selected sidecar {sidecar_name}", errors)
        require_true(state_dict.get("exists"), f"{pair_id}: selected sidecar {sidecar_name} exists", errors)
        if not state_dict.get("sha256"):
            errors.append(f"{pair_id}: selected sidecar {sidecar_name} missing sha256")

    sidecar_materialization = as_dict(
        candidate.get("no_refetch_sidecar_materialization"),
        f"{pair_id}: candidate no_refetch_sidecar_materialization",
        errors,
    )
    materialized_sidecars = as_dict(
        sidecar_materialization.get("sidecars"),
        f"{pair_id}: candidate materialized no-refetch sidecars",
        errors,
    )
    missing_materialized = sorted(REQUIRED_PAIR_SIDECARS - set(materialized_sidecars))
    if missing_materialized:
        errors.append(f"{pair_id}: materialized sidecars missing: {', '.join(missing_materialized)}")
    for sidecar_name, state in materialized_sidecars.items():
        state_dict = as_dict(state, f"{pair_id}: materialized sidecar {sidecar_name}", errors)
        if not state_dict.get("sha256"):
            errors.append(f"{pair_id}: materialized sidecar {sidecar_name} missing sha256")
        if state_dict.get("sha256") != state_dict.get("source_sha256"):
            errors.append(f"{pair_id}: materialized sidecar {sidecar_name} sha256 must match source_sha256")

    validation_payload = as_dict(candidate.get("validation_payload"), f"{pair_id}: candidate validation_payload", errors)
    if validation_payload.get("exit_code") != 0:
        errors.append(f"{pair_id}: candidate validation exit_code must be 0")
    require_true(
        as_dict(candidate.get("stdout_artifact"), f"{pair_id}: candidate stdout_artifact", errors).get("exists"),
        f"{pair_id}: candidate stdout_artifact exists",
        errors,
    )
    materialized = as_dict(candidate.get("materialized_artifact"), f"{pair_id}: candidate materialized_artifact", errors)
    require_true(materialized.get("exists"), f"{pair_id}: candidate materialized_artifact exists", errors)
    require_true(
        as_dict(candidate.get("validation_result"), f"{pair_id}: candidate validation_result", errors).get("exists"),
        f"{pair_id}: candidate validation_result exists",
        errors,
    )

    deltas = as_dict(receipt.get("deltas"), f"{pair_id}: pair receipt deltas", errors)
    require_true(
        deltas.get("candidate_total_direct_tokens_at_least_5pct_lower"),
        f"{pair_id}: candidate_total_direct_tokens_at_least_5pct_lower",
        errors,
    )
    require_true(
        deltas.get("candidate_request_count_not_higher"),
        f"{pair_id}: candidate_request_count_not_higher",
        errors,
    )
    reduction = coerce_float(
        deltas.get("total_direct_token_reduction_pct"), f"{pair_id}: receipt total_direct_token_reduction_pct", errors
    )
    if reduction is not None and reduction < minimum_reduction_pct:
        errors.append(f"{pair_id}: receipt total direct token reduction must be at least {minimum_reduction_pct:g}%")

    return errors, {
        "path": str(receipt_path),
        "exists": True,
        "sha256": sha256_path(receipt_path),
        "receipt_verdict": admission.get("verdict"),
    }


def pair_errors(pair: dict[str, Any], minimum_reduction_pct: float) -> list[str]:
    errors: list[str] = []
    pair = as_dict(pair, "production confirmation pair", errors)
    pair_id = pair.get("pair_id") or "<unknown>"
    if pair.get("evidence_complete") is not True:
        errors.append(f"{pair_id}: evidence_complete must be true")
    if pair.get("qualifies") is not True:
        errors.append(f"{pair_id}: qualifies must be true")
    if pair.get("blockers"):
        errors.append(f"{pair_id}: blockers must be empty")
    candidate = as_dict(pair.get("candidate"), f"{pair_id}: candidate", errors)
    deltas = as_dict(pair.get("deltas"), f"{pair_id}: deltas", errors)
    candidate_tool_calls = coerce_int(candidate.get("tool_calls"), f"{pair_id}: candidate tool_calls", errors)
    request_delta = coerce_int(
        deltas.get("request_count_candidate_minus_control"),
        f"{pair_id}: request_count_candidate_minus_control",
        errors,
    )
    tool_delta = coerce_int(
        deltas.get("tool_calls_candidate_minus_control"), f"{pair_id}: tool_calls_candidate_minus_control", errors
    )
    if candidate_tool_calls is not None and candidate_tool_calls != 0:
        errors.append(f"{pair_id}: candidate tool_calls must be zero")
    if request_delta is not None and request_delta > 0:
        errors.append(f"{pair_id}: candidate request count must not exceed control")
    if tool_delta is not None and tool_delta > 0:
        errors.append(f"{pair_id}: candidate tool calls must not exceed control")
    reduction = coerce_float(
        deltas.get("total_direct_token_reduction_pct"), f"{pair_id}: total_direct_token_reduction_pct", errors
    )
    if reduction is not None and reduction < minimum_reduction_pct:
        errors.append(f"{pair_id}: total direct token reduction must be at least {minimum_reduction_pct:g}%")
    if not pair.get("receipt_path"):
        errors.append(f"{pair_id}: receipt_path is required")
    receipt_errors, _state = validate_pair_receipt(pair, minimum_reduction_pct)
    errors.extend(receipt_errors)
    return errors


def validate_confirmation(
    receipt: dict[str, Any], minimum_pairs: int, minimum_reduction_pct: float
) -> tuple[list[str], list[dict[str, Any]]]:
    errors: list[str] = []
    pairs = as_list(receipt.get("pairs"), "production confirmation pairs", errors)
    if receipt.get("outcome") != "strong_pass_two_production_pairs_qualified":
        errors.append("production confirmation outcome must be strong_pass_two_production_pairs_qualified")
    qualified_pairs = coerce_int(receipt.get("qualified_pairs"), "production confirmation qualified_pairs", errors)
    if qualified_pairs is not None and qualified_pairs < minimum_pairs:
        errors.append(f"production confirmation must include at least {minimum_pairs} qualified pairs")
    if len(pairs) < minimum_pairs:
        errors.append(f"production confirmation pairs list must include at least {minimum_pairs} pairs")
    metrics = as_dict(receipt.get("aggregate_metrics"), "production confirmation aggregate_metrics", errors)
    median = coerce_float(
        metrics.get("median_total_direct_token_reduction_pct"),
        "median_total_direct_token_reduction_pct",
        errors,
    )
    median_request_delta = coerce_float(metrics.get("median_request_delta"), "median_request_delta", errors)
    median_tool_delta = coerce_float(metrics.get("median_tool_call_delta"), "median_tool_call_delta", errors)
    if median is not None and median < minimum_reduction_pct:
        errors.append(f"median total direct token reduction must be at least {minimum_reduction_pct:g}%")
    if median_request_delta is not None and median_request_delta > 0:
        errors.append("median request delta must not be positive")
    if median_tool_delta is not None and median_tool_delta > 0:
        errors.append("median tool-call delta must not be positive")
    for pair in pairs[:minimum_pairs]:
        errors.extend(pair_errors(pair, minimum_reduction_pct))
    missing_non_claims = missing_non_claim_boundaries(as_list(receipt.get("non_claims"), "non_claims", errors))
    for claim in missing_non_claims:
        errors.append(f"production confirmation receipt non_claims missing boundary: {claim}")
    return errors, pairs


def pair_summary(pair: Any) -> dict[str, Any]:
    if not isinstance(pair, dict):
        return {
            "pair_id": None,
            "evidence_complete": None,
            "qualifies": None,
            "receipt_path": None,
            "total_direct_token_reduction_pct": None,
            "request_delta": None,
            "tool_call_delta": None,
            "invalid_shape": True,
        }
    deltas = pair.get("deltas") if isinstance(pair.get("deltas"), dict) else {}
    return {
        "pair_id": pair.get("pair_id"),
        "evidence_complete": pair.get("evidence_complete"),
        "qualifies": pair.get("qualifies"),
        "receipt_path": pair.get("receipt_path"),
        "total_direct_token_reduction_pct": deltas.get("total_direct_token_reduction_pct"),
        "request_delta": deltas.get("request_count_candidate_minus_control"),
        "tool_call_delta": deltas.get("tool_calls_candidate_minus_control"),
    }


def main() -> int:
    args = parse_args()
    config_path = Path(args.adoption_config)
    confirmation_path = Path(args.production_confirmation_receipt)
    burst40_packet_path = Path(args.burst40_adoption_packet)
    output_path = Path(args.output)

    source_errors: list[str] = []
    for label, path in (
        ("adoption config", config_path),
        ("production confirmation receipt", confirmation_path),
        ("Burst-40 adoption packet", burst40_packet_path),
    ):
        if not path.exists():
            source_errors.append(f"{label} does not exist: {path}")
    if source_errors:
        write_json(
            output_path,
            {
                "schema_version": 1,
                "receipt_type": "stdout_no_tools_adoption_readiness_review",
                "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "verdict": "blocked_missing_sources",
                "blockers": source_errors,
            },
        )
        return 2

    config = load_json(config_path)
    confirmation = load_json(confirmation_path)
    burst40_packet = load_json(burst40_packet_path)
    blockers: list[str] = []
    if not isinstance(config, dict):
        blockers.append("adoption config is not a JSON object")
        config = {}
    if not isinstance(confirmation, dict):
        blockers.append("production confirmation receipt is not a JSON object")
        confirmation = {}
    if not isinstance(burst40_packet, dict):
        blockers.append("Burst-40 adoption packet is not a JSON object")
        burst40_packet = {}

    blockers.extend(validate_config(config))
    blockers.extend(validate_burst40_packet(burst40_packet))
    confirmation_blockers, pairs = validate_confirmation(
        confirmation, args.minimum_production_pairs, args.minimum_reduction_pct
    )
    blockers.extend(confirmation_blockers)

    ready = not blockers
    packet = {
        "schema_version": 1,
        "receipt_type": "stdout_no_tools_adoption_readiness_review",
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "verdict": "ready_for_disabled_enablement_prep_review" if ready else "blocked_adoption_readiness_review",
        "ready_for_production_enablement": False,
        "ready_for_disabled_enablement_prep_review": ready,
        "requires_explicit_operator_approval_before_enablement": True,
        "production_behavior_enabled": False,
        "durable_savings_claim": False,
        "github_copilot_billing_claim": False,
        "model_recommendation": False,
        "sources": {
            "adoption_config": {"path": str(config_path), "sha256": sha256_path(config_path)},
            "production_confirmation_receipt": {
                "path": str(confirmation_path),
                "sha256": sha256_path(confirmation_path),
            },
            "burst40_adoption_packet": {
                "path": str(burst40_packet_path),
                "sha256": sha256_path(burst40_packet_path),
            },
        },
        "qualified_production_evidence": {
            "minimum_required_pairs": args.minimum_production_pairs,
            "qualified_pairs": confirmation.get("qualified_pairs"),
            "attempted_pairs": confirmation.get("attempted_pairs"),
            "median_total_direct_token_reduction_pct": as_dict(
                confirmation.get("aggregate_metrics"), "production confirmation aggregate_metrics", []
            ).get("median_total_direct_token_reduction_pct"),
            "median_request_delta": as_dict(
                confirmation.get("aggregate_metrics"), "production confirmation aggregate_metrics", []
            ).get("median_request_delta"),
            "median_tool_call_delta": as_dict(
                confirmation.get("aggregate_metrics"), "production confirmation aggregate_metrics", []
            ).get("median_tool_call_delta"),
            "pairs": [pair_summary(pair) for pair in pairs],
        },
        "future_enablement_review_requirements": [
            "Keep the wrapper disabled by default until explicit operator approval names the enablement branch.",
            "Retain the canonical Phase 3 control path and rollback switch.",
            "Require per-run direct provider token fields, exact session binding, selected-source/no-refetch binding, validation pass, and zero candidate tool calls.",
            "Disable or fail closed on any request-count increase, candidate tool call, missing direct field, validation failure, no-refetch gap, or materialization sidecar gap.",
            "Run at least one approved enablement-prep dry run before any later production default or durable savings claim.",
        ],
        "rollback_notes": [
            "Set the enable/default_enabled flag to false/off or use the canonical Phase 3 curation runner.",
            "Discard candidate rows with tool calls, request amplification, missing session binding, or missing no-refetch sidecars.",
            "Rebuild adoption-readiness receipts after any wrapper, prompt, fixture, validator, or sidecar-materialization change.",
        ],
        "non_claims": [
            "This is an adoption-readiness review packet, not production enablement.",
            "This is not a durable savings claim.",
            "This is not a GitHub Copilot billing claim.",
            "This is not a model recommendation.",
            "It does not mutate public CustomerNewsletter or sibling/fleet repos.",
        ],
        "blockers": blockers,
        "recommended_next_batch": "Explicit operator-approved disabled-switch enablement-prep dry run for Phase 3 stdout tool-constrained reuse.",
    }
    write_json(output_path, packet)
    return 0 if ready else 2


if __name__ == "__main__":
    raise SystemExit(main())

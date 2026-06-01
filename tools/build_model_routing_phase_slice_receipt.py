#!/usr/bin/env python3
"""Compare a matched model-routing Phase 3 slice pair."""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Any

from newsletter_experiment_common import estimate_costs, load_json, sha256_path


TOKEN_FIELDS = [
    "input_tokens",
    "output_tokens",
    "cache_read_tokens",
    "cache_write_tokens",
    "reasoning_tokens",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pair-id", required=True)
    parser.add_argument("--mode", required=True, choices=["benchmark", "production"])
    parser.add_argument("--surface-id", default="phase2_entry_surface")
    parser.add_argument("--control-binding", required=True)
    parser.add_argument("--candidate-binding", required=True)
    parser.add_argument("--control-summary", required=True)
    parser.add_argument("--candidate-summary", required=True)
    parser.add_argument("--pricing-snapshot", required=True)
    parser.add_argument("--expected-phase-id", default="phase3_curation")
    parser.add_argument("--control-prompt-metadata", default="")
    parser.add_argument("--candidate-prompt-metadata", default="")
    parser.add_argument("--candidate-prompt-policy", default="")
    parser.add_argument("--control-prompt-file", default="")
    parser.add_argument("--candidate-prompt-file", default="")
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def utc_now() -> str:
    return dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def display_path(path: Path | None) -> str | None:
    if path is None:
        return None
    resolved = path.resolve()
    try:
        return str(resolved.relative_to(Path.cwd().resolve()))
    except ValueError:
        return str(resolved)


def load_last_jsonl(path: Path) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if isinstance(payload, dict):
            rows.append(payload)
    if not rows:
        raise SystemExit(f"no JSON rows found in {path}")
    return rows[-1]


def summary_status(path: Path) -> str | None:
    if not path.exists():
        return None
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if line.startswith("- Final Status:"):
            return line.split(":", 1)[1].strip()
    return None


def int_value(value: Any) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def total_direct_tokens(usage: dict[str, Any]) -> int | None:
    values = [int_value(usage.get(field)) for field in TOKEN_FIELDS]
    if any(value is None for value in values):
        return None
    return sum(value or 0 for value in values)


def row_from_binding(
    binding: dict[str, Any],
    summary_path: Path,
    pricing_snapshot: dict[str, Any],
    pricing_path: Path,
) -> dict[str, Any]:
    metrics_path_text = str(binding.get("metrics_path") or "").strip()
    if not metrics_path_text:
        return blocked_row(binding, summary_path, "binding receipt does not include metrics_path")
    metrics_path = Path(metrics_path_text).expanduser()
    if not metrics_path.is_absolute():
        metrics_path = metrics_path.resolve()
    if not metrics_path.is_file():
        return blocked_row(binding, summary_path, f"metrics_path is not an existing file: {metrics_path}")
    metrics_row = load_last_jsonl(metrics_path)
    metrics_sha = sha256_path(metrics_path)
    binding_usage = binding.get("token_usage") if isinstance(binding.get("token_usage"), dict) else {}
    metrics_usage = metrics_row.get("token_usage") if isinstance(metrics_row.get("token_usage"), dict) else {}
    usage = metrics_usage
    cost = estimate_costs(usage, pricing_snapshot)
    if isinstance(cost, dict) and cost.get("method") == "direct_token_estimate":
        cost["pricing_snapshot_path"] = display_path(pricing_path)
    return {
        "requested_model": binding.get("requested_model"),
        "admitted": binding.get("admitted") is True,
        "binding_verdict": binding.get("verdict"),
        "binding_receipt_type": binding.get("receipt_type"),
        "binding_checks_all_pass": all(
            value is True for value in (binding.get("checks") or {}).values()
        )
        if isinstance(binding.get("checks"), dict)
        else False,
        "quality_status": summary_status(summary_path),
        "summary_path": display_path(summary_path),
        "summary_sha256": sha256_path(summary_path) if summary_path.exists() else None,
        "metrics_path": display_path(metrics_path),
        "metrics_sha256": metrics_sha,
        "binding_metrics_sha256": binding.get("metrics_sha256"),
        "binding_metrics_hash_match": binding.get("metrics_sha256") == metrics_sha,
        "binding_token_usage_matches_metrics": binding_usage == metrics_usage,
        "phase_id": metrics_row.get("phase_id"),
        "original_prompt_sha256": metrics_row.get("original_prompt_sha256"),
        "prompt_sha256": metrics_row.get("prompt_sha256"),
        "artifact_paths": metrics_row.get("artifact_paths") or [],
        "token_usage": usage,
        "total_direct_tokens": total_direct_tokens(usage),
        "request_count": int_value(usage.get("request_count")),
        "tool_calls": int_value(usage.get("tool_calls")),
        "cost_estimate": cost,
    }


def blocked_row(binding: dict[str, Any], summary_path: Path, error: str) -> dict[str, Any]:
    return {
        "requested_model": binding.get("requested_model"),
        "admitted": binding.get("admitted") is True,
        "binding_verdict": binding.get("verdict"),
        "binding_receipt_type": binding.get("receipt_type"),
        "binding_checks_all_pass": False,
        "quality_status": summary_status(summary_path),
        "summary_path": display_path(summary_path),
        "summary_sha256": sha256_path(summary_path) if summary_path.exists() else None,
        "metrics_path": str(binding.get("metrics_path") or ""),
        "metrics_sha256": None,
        "binding_metrics_sha256": binding.get("metrics_sha256"),
        "binding_metrics_hash_match": False,
        "binding_token_usage_matches_metrics": False,
        "phase_id": None,
        "original_prompt_sha256": None,
        "prompt_sha256": None,
        "artifact_paths": [],
        "token_usage": {},
        "total_direct_tokens": None,
        "request_count": None,
        "tool_calls": None,
        "cost_estimate": {
            "pricing_snapshot_path": None,
            "method": "unpriced",
            "total_usd": None,
            "priced_models": [],
            "unpriced_models": [],
            "model_breakdown": [],
        },
        "row_errors": [error],
    }


def cost_available(row: dict[str, Any]) -> bool:
    cost = row.get("cost_estimate") if isinstance(row.get("cost_estimate"), dict) else {}
    return cost.get("total_usd") is not None and not cost.get("unpriced_models")


def load_prompt_metadata(path_text: str) -> dict[str, Any] | None:
    if not path_text:
        return None
    path = Path(path_text).expanduser().resolve()
    if not path.is_file():
        return {"path": display_path(path), "valid": False, "error": "metadata file missing"}
    payload = load_json(path)
    if not isinstance(payload, dict):
        return {"path": display_path(path), "valid": False, "error": "metadata JSON invalid"}
    payload["path"] = display_path(path)
    payload["sha256"] = sha256_path(path)
    payload["valid"] = (
        payload.get("receipt_type") == "phase3_prompt_policy_metadata"
        and bool(payload.get("base_prompt_sha256"))
        and bool(payload.get("full_prompt_sha256"))
        and "policy_enabled" in payload
    )
    return payload


def prompt_policy_sha(path_text: str) -> str | None:
    if not path_text:
        return None
    path = Path(path_text).expanduser().resolve()
    if not path.is_file():
        return None
    return sha256_path(path)


def prompt_policy_payload(path_text: str) -> dict[str, Any] | None:
    if not path_text:
        return None
    path = Path(path_text).expanduser().resolve()
    if not path.is_file():
        return None
    payload = load_json(path)
    return payload if isinstance(payload, dict) else None


def prompt_policy_text(policy: dict[str, Any] | None) -> str:
    if not policy:
        return ""
    prompt_append = policy.get("prompt_append")
    if isinstance(prompt_append, list):
        if not all(isinstance(item, str) for item in prompt_append):
            return ""
        return "\n".join(item.rstrip() for item in prompt_append).strip()
    return str(prompt_append or "").strip()


def load_prompt_file(path_text: str) -> dict[str, Any] | None:
    if not path_text:
        return None
    path = Path(path_text).expanduser().resolve()
    if not path.is_file():
        return {"path": display_path(path), "valid": False, "error": "prompt file missing"}
    text = path.read_text(encoding="utf-8", errors="ignore")
    return {
        "path": display_path(path),
        "valid": True,
        "sha256": sha256_path(path),
        "text": text,
    }


def expected_policy_prompt(control_prompt: str, policy: dict[str, Any] | None) -> str | None:
    if not policy:
        return None
    policy_id = str(policy.get("policy_id") or "").strip()
    append_text = prompt_policy_text(policy)
    if not policy_id or not append_text:
        return None
    return (
        control_prompt
        + "\nEvidence-only model-routing request/tool budget policy "
        + f"({policy_id}):\n{append_text}\n"
    )


def prompt_variant_checks(
    *,
    control: dict[str, Any],
    candidate: dict[str, Any],
    control_metadata: dict[str, Any] | None,
    candidate_metadata: dict[str, Any] | None,
    candidate_policy_sha256: str | None,
    control_prompt_file: dict[str, Any] | None,
    candidate_prompt_file: dict[str, Any] | None,
    candidate_policy: dict[str, Any] | None,
) -> dict[str, bool]:
    if control_metadata is None and candidate_metadata is None:
        return {}
    control_valid = bool(control_metadata and control_metadata.get("valid") is True)
    candidate_valid = bool(candidate_metadata and candidate_metadata.get("valid") is True)
    control_base = control_metadata.get("base_prompt_sha256") if control_metadata else None
    candidate_base = candidate_metadata.get("base_prompt_sha256") if candidate_metadata else None
    candidate_policy_sha = candidate_metadata.get("policy_sha256") if candidate_metadata else None
    checks = {
        "control_prompt_metadata_valid": control_valid,
        "candidate_prompt_metadata_valid": candidate_valid,
        "control_full_prompt_hash_matches_metrics": control_valid
        and control_metadata.get("full_prompt_sha256") == control.get("original_prompt_sha256"),
        "candidate_full_prompt_hash_matches_metrics": candidate_valid
        and candidate_metadata.get("full_prompt_sha256") == candidate.get("original_prompt_sha256"),
        "same_base_prompt_hash": bool(control_base) and control_base == candidate_base,
    }
    if candidate_policy is None:
        return checks
    control_file_valid = bool(control_prompt_file and control_prompt_file.get("valid") is True)
    candidate_file_valid = bool(candidate_prompt_file and candidate_prompt_file.get("valid") is True)
    expected_candidate_prompt = (
        expected_policy_prompt(str(control_prompt_file.get("text")), candidate_policy)
        if control_file_valid
        else None
    )
    checks.update(
        {
            "control_prompt_policy_disabled": control_valid and control_metadata.get("policy_enabled") is False,
            "candidate_prompt_policy_enabled": candidate_valid and candidate_metadata.get("policy_enabled") is True,
            "candidate_prompt_policy_hash_present": bool(candidate_policy_sha),
            "candidate_prompt_policy_hash_matches_config": (
                candidate_policy_sha256 is not None and candidate_policy_sha == candidate_policy_sha256
            ),
            "control_prompt_file_valid": control_file_valid,
            "candidate_prompt_file_valid": candidate_file_valid,
            "control_prompt_file_hash_matches_metrics": control_file_valid
            and control_prompt_file.get("sha256") == control.get("original_prompt_sha256"),
            "candidate_prompt_file_hash_matches_metrics": candidate_file_valid
            and candidate_prompt_file.get("sha256") == candidate.get("original_prompt_sha256"),
            "control_prompt_file_hash_matches_metadata": control_file_valid
            and control_valid
            and control_prompt_file.get("sha256") == control_metadata.get("full_prompt_sha256"),
            "candidate_prompt_file_hash_matches_metadata": candidate_file_valid
            and candidate_valid
            and candidate_prompt_file.get("sha256") == candidate_metadata.get("full_prompt_sha256"),
            "candidate_prompt_equals_control_plus_policy": candidate_file_valid
            and expected_candidate_prompt is not None
            and candidate_prompt_file.get("text") == expected_candidate_prompt,
        }
    )
    return checks


def numeric_lte(left: int | None, right: int | None) -> bool:
    return left is not None and right is not None and left <= right


def numeric_lt(left: float | int | None, right: float | int | None) -> bool:
    return left is not None and right is not None and left < right


def delta(control: int | float | None, candidate: int | float | None) -> dict[str, Any]:
    if control is None or candidate is None:
        return {"absolute": None, "percent": None}
    absolute = candidate - control
    percent = None if control == 0 else round((absolute / control) * 100.0, 4)
    return {"absolute": absolute, "percent": percent}


def main() -> int:
    args = parse_args()
    control_binding_path = Path(args.control_binding).expanduser().resolve()
    candidate_binding_path = Path(args.candidate_binding).expanduser().resolve()
    pricing_path = Path(args.pricing_snapshot).expanduser().resolve()
    control_binding = load_json(control_binding_path)
    candidate_binding = load_json(candidate_binding_path)
    pricing_snapshot = load_json(pricing_path)
    control_prompt_metadata = load_prompt_metadata(args.control_prompt_metadata)
    candidate_prompt_metadata = load_prompt_metadata(args.candidate_prompt_metadata)
    candidate_prompt_policy_sha = prompt_policy_sha(args.candidate_prompt_policy)
    candidate_policy = prompt_policy_payload(args.candidate_prompt_policy)
    control_prompt_file = load_prompt_file(args.control_prompt_file)
    candidate_prompt_file = load_prompt_file(args.candidate_prompt_file)
    if not isinstance(control_binding, dict):
        raise SystemExit(f"invalid control binding receipt: {control_binding_path}")
    if not isinstance(candidate_binding, dict):
        raise SystemExit(f"invalid candidate binding receipt: {candidate_binding_path}")
    if not isinstance(pricing_snapshot, dict):
        raise SystemExit(f"invalid pricing snapshot: {pricing_path}")

    control = row_from_binding(control_binding, Path(args.control_summary), pricing_snapshot, pricing_path)
    candidate = row_from_binding(candidate_binding, Path(args.candidate_summary), pricing_snapshot, pricing_path)
    control_cost = (
        control.get("cost_estimate", {}).get("total_usd")
        if isinstance(control.get("cost_estimate"), dict)
        else None
    )
    candidate_cost = (
        candidate.get("cost_estimate", {}).get("total_usd")
        if isinstance(candidate.get("cost_estimate"), dict)
        else None
    )
    expected_phase_id = str(args.expected_phase_id or "").strip() or "phase3_curation"

    checks = {
        "control_binding_admitted": control["admitted"] is True,
        "candidate_binding_admitted": candidate["admitted"] is True,
        "control_binding_receipt_type_valid": control["binding_receipt_type"] == "model_routing_binding",
        "candidate_binding_receipt_type_valid": candidate["binding_receipt_type"] == "model_routing_binding",
        "control_binding_verdict_admitted": control["binding_verdict"] == "model_binding_admitted",
        "candidate_binding_verdict_admitted": candidate["binding_verdict"] == "model_binding_admitted",
        "control_binding_checks_all_pass": control["binding_checks_all_pass"] is True,
        "candidate_binding_checks_all_pass": candidate["binding_checks_all_pass"] is True,
        "control_metrics_hash_matches_binding": control["binding_metrics_hash_match"] is True,
        "candidate_metrics_hash_matches_binding": candidate["binding_metrics_hash_match"] is True,
        "control_binding_token_usage_matches_metrics": control["binding_token_usage_matches_metrics"] is True,
        "candidate_binding_token_usage_matches_metrics": candidate["binding_token_usage_matches_metrics"] is True,
        "control_quality_pass": control["quality_status"] == "pass",
        "candidate_quality_pass": candidate["quality_status"] == "pass",
        "control_phase_matches_expected": control["phase_id"] == expected_phase_id,
        "candidate_phase_matches_expected": candidate["phase_id"] == expected_phase_id,
        "same_phase": bool(control["phase_id"]) and control["phase_id"] == candidate["phase_id"],
        "control_original_prompt_hash_present": bool(control["original_prompt_sha256"]),
        "candidate_original_prompt_hash_present": bool(candidate["original_prompt_sha256"]),
        "same_original_prompt_hash": bool(control["original_prompt_sha256"])
        and control["original_prompt_sha256"] == candidate["original_prompt_sha256"],
        "control_artifact_paths_present": bool(control["artifact_paths"]),
        "candidate_artifact_paths_present": bool(candidate["artifact_paths"]),
        "same_artifact_paths": bool(control["artifact_paths"])
        and control["artifact_paths"] == candidate["artifact_paths"],
        "control_pricing_available": cost_available(control),
        "candidate_pricing_available": cost_available(candidate),
        "candidate_request_count_not_higher": numeric_lte(candidate["request_count"], control["request_count"]),
        "candidate_tool_calls_not_higher": numeric_lte(candidate["tool_calls"], control["tool_calls"]),
        "candidate_api_equivalent_cost_lower": numeric_lt(candidate_cost, control_cost),
    }
    variant_checks = prompt_variant_checks(
        control=control,
        candidate=candidate,
        control_metadata=control_prompt_metadata,
        candidate_metadata=candidate_prompt_metadata,
        candidate_policy_sha256=candidate_prompt_policy_sha,
        control_prompt_file=control_prompt_file,
        candidate_prompt_file=candidate_prompt_file,
        candidate_policy=candidate_policy,
    )
    if expected_phase_id == "phase3_curation":
        checks["control_phase_is_phase3_curation"] = control["phase_id"] == "phase3_curation"
        checks["candidate_phase_is_phase3_curation"] = candidate["phase_id"] == "phase3_curation"
    checks.update(variant_checks)
    qualification_checks = dict(checks)
    if variant_checks and variant_checks.get("candidate_prompt_equals_control_plus_policy") is True:
        qualification_checks.pop("same_original_prompt_hash", None)
    qualified = all(qualification_checks.values())
    deltas = {
        "input_tokens": delta(control["token_usage"].get("input_tokens"), candidate["token_usage"].get("input_tokens")),
        "output_tokens": delta(control["token_usage"].get("output_tokens"), candidate["token_usage"].get("output_tokens")),
        "cache_read_tokens": delta(control["token_usage"].get("cache_read_tokens"), candidate["token_usage"].get("cache_read_tokens")),
        "cache_write_tokens": delta(control["token_usage"].get("cache_write_tokens"), candidate["token_usage"].get("cache_write_tokens")),
        "reasoning_tokens": delta(control["token_usage"].get("reasoning_tokens"), candidate["token_usage"].get("reasoning_tokens")),
        "total_direct_tokens": delta(control["total_direct_tokens"], candidate["total_direct_tokens"]),
        "request_count": delta(control["request_count"], candidate["request_count"]),
        "tool_calls": delta(control["tool_calls"], candidate["tool_calls"]),
        "api_equivalent_cost_usd": delta(control_cost, candidate_cost),
    }
    blockers = [name for name, passed in qualification_checks.items() if not passed]
    receipt = {
        "schema_version": 1,
        "receipt_type": "model_routing_phase_slice_comparison",
        "generated_at_utc": utc_now(),
        "pair_id": args.pair_id,
        "mode": args.mode,
        "surface_id": args.surface_id,
        "expected_phase_id": expected_phase_id,
        "verdict": "qualified_model_routing_signal" if qualified else "model_routing_pair_failed_closed",
        "qualified": qualified,
        "blockers": blockers,
        "checks": checks,
        "qualification_checks": qualification_checks,
        "control_binding_path": display_path(control_binding_path),
        "candidate_binding_path": display_path(candidate_binding_path),
        "control_prompt_metadata": control_prompt_metadata,
        "candidate_prompt_metadata": candidate_prompt_metadata,
        "control_prompt_file": {key: value for key, value in (control_prompt_file or {}).items() if key != "text"} if control_prompt_file else None,
        "candidate_prompt_file": {key: value for key, value in (candidate_prompt_file or {}).items() if key != "text"} if candidate_prompt_file else None,
        "candidate_prompt_policy_path": display_path(Path(args.candidate_prompt_policy).expanduser()) if args.candidate_prompt_policy else None,
        "candidate_prompt_policy_sha256": candidate_prompt_policy_sha,
        "pricing_snapshot_path": display_path(pricing_path),
        "pricing_snapshot_sha256": sha256_path(pricing_path),
        "control": control,
        "candidate": candidate,
        "deltas_candidate_minus_control": deltas,
        "non_claims": [
            "This is a bounded phase-slice comparison, not a production adoption or model recommendation.",
            "Dollar estimates use public API-equivalent pricing only, not GitHub Copilot billing.",
            "A qualified pair is evidence for this slice only and is not a durable savings claim.",
        ],
    }
    output_path = Path(args.output).expanduser().resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"qualified": qualified, "output": str(output_path), "verdict": receipt["verdict"]}, sort_keys=True))
    return 0 if qualified else 1


if __name__ == "__main__":
    raise SystemExit(main())

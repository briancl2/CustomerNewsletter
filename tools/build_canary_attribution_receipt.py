#!/usr/bin/env python3
"""Build a retained phase-level attribution receipt for the Burst-45 canary."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


DIRECT_FIELDS = ("input_tokens", "output_tokens", "reasoning_tokens")
TOKEN_FIELDS = (
    "input_tokens",
    "output_tokens",
    "reasoning_tokens",
    "cache_read_tokens",
    "cache_write_tokens",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--control-run-dir", required=True, type=Path)
    parser.add_argument("--opt-in-run-dir", required=True, type=Path)
    parser.add_argument("--canary-run-dir", required=True, type=Path)
    parser.add_argument("--control-receipt", required=True, type=Path)
    parser.add_argument("--canary-receipt", required=True, type=Path)
    parser.add_argument("--rollback-receipt", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def sha256_path(path: Path) -> str | None:
    if not path.exists():
        return None
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path) -> Any:
    with path.open() as handle:
        return json.load(handle)


def metrics_path(run_dir: Path) -> Path | None:
    candidates = [
        run_dir / "orchestrated" / "session" / "phase-session-metrics.jsonl",
        run_dir / "session" / "phase-session-metrics.jsonl",
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None


def load_metrics(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open() as handle:
        for line_no, line in enumerate(handle, start=1):
            stripped = line.strip()
            if not stripped:
                continue
            try:
                row = json.loads(stripped)
            except json.JSONDecodeError as exc:
                raise SystemExit(f"{path}:{line_no}: invalid JSON: {exc}") from exc
            if isinstance(row, dict):
                rows.append(row)
    return rows


def canonical_phase(phase_id: str) -> str:
    if phase_id.startswith("phase3"):
        return "phase3"
    return phase_id


def numeric(row: dict[str, Any], key: str) -> int:
    token_usage = row.get("token_usage") if isinstance(row.get("token_usage"), dict) else {}
    value = row.get(key)
    if value is None:
        value = token_usage.get(key)
    if value is None:
        return 0
    return int(value)


def summarize_row(label: str, run_dir: Path) -> dict[str, Any]:
    path = metrics_path(run_dir)
    if path is None:
        return {
            "label": label,
            "run_dir": str(run_dir),
            "metrics_path": None,
            "status": "missing_metrics",
            "blockers": ["missing_phase_session_metrics"],
            "phases": {},
            "totals": {},
        }

    rows = load_metrics(path)
    phases: dict[str, dict[str, Any]] = {}
    blockers: list[str] = []
    for row in rows:
        phase_id = str(row.get("phase_id") or "unknown")
        phase = canonical_phase(phase_id)
        bucket = phases.setdefault(
            phase,
            {
                "phase_id": phase,
                "original_phase_ids": [],
                "input_tokens": 0,
                "output_tokens": 0,
                "reasoning_tokens": 0,
                "cache_read_tokens": 0,
                "cache_write_tokens": 0,
                "total_direct_tokens": 0,
                "request_count": 0,
                "tool_calls": 0,
                "duration_seconds": 0.0,
                "direct_fields_complete": True,
                "session_statuses": [],
                "models": [],
            },
        )
        bucket["original_phase_ids"].append(phase_id)
        for field in TOKEN_FIELDS:
            bucket[field] += numeric(row, field)
        bucket["total_direct_tokens"] += sum(numeric(row, field) for field in DIRECT_FIELDS)
        bucket["request_count"] += numeric(row, "request_count")
        bucket["tool_calls"] += numeric(row, "tool_calls")
        bucket["duration_seconds"] += float(row.get("duration_seconds") or 0.0)
        token_usage = row.get("token_usage") if isinstance(row.get("token_usage"), dict) else {}
        missing = (
            row.get("direct_token_missing_fields")
            or row.get("missing_direct_provider_token_fields")
            or token_usage.get("missing_direct_provider_token_fields")
            or []
        )
        missing_values = []
        for field in DIRECT_FIELDS:
            token_usage_value = token_usage.get(field)
            if row.get(field) is None and token_usage_value is None:
                missing_values.append(field)
        if missing or missing_values:
            bucket["direct_fields_complete"] = False
            blockers.append(f"{phase}:missing_direct_token_fields")
        detection = row.get("session_log_detection") if isinstance(row.get("session_log_detection"), dict) else {}
        session_status = row.get("session_status") or detection.get("status")
        bucket["session_statuses"].append(session_status)
        if session_status != "bound_candidate":
            blockers.append(f"{phase}:session_not_bound_candidate")
        model = row.get("model") or row.get("primary_model")
        if model and model not in bucket["models"]:
            bucket["models"].append(model)

    totals = {
        field: sum(int(phase.get(field) or 0) for phase in phases.values())
        for field in TOKEN_FIELDS
    }
    totals["total_direct_tokens"] = sum(
        int(phase.get("total_direct_tokens") or 0) for phase in phases.values()
    )
    totals["request_count"] = sum(
        int(phase.get("request_count") or 0) for phase in phases.values()
    )
    totals["tool_calls"] = sum(int(phase.get("tool_calls") or 0) for phase in phases.values())
    totals["duration_seconds"] = round(
        sum(float(phase.get("duration_seconds") or 0.0) for phase in phases.values()), 3
    )

    return {
        "label": label,
        "run_dir": str(run_dir),
        "metrics_path": str(path),
        "metrics_sha256": sha256_path(path),
        "status": "complete" if not blockers else "blocked",
        "blockers": sorted(set(blockers)),
        "phases": phases,
        "totals": totals,
    }


def phase_delta(
    lhs: dict[str, Any], rhs: dict[str, Any], lhs_label: str, rhs_label: str
) -> dict[str, Any]:
    phases = sorted(set(lhs.get("phases", {})) | set(rhs.get("phases", {})))
    per_phase: dict[str, dict[str, int]] = {}
    for phase in phases:
        lhs_phase = lhs.get("phases", {}).get(phase, {})
        rhs_phase = rhs.get("phases", {}).get(phase, {})
        per_phase[phase] = {
            field: int(lhs_phase.get(field) or 0) - int(rhs_phase.get(field) or 0)
            for field in (*TOKEN_FIELDS, "total_direct_tokens", "request_count", "tool_calls")
        }
    total_delta = {
        field: int(lhs.get("totals", {}).get(field) or 0)
        - int(rhs.get("totals", {}).get(field) or 0)
        for field in (*TOKEN_FIELDS, "total_direct_tokens", "request_count", "tool_calls")
    }
    largest_positive = max(
        (
            {
                "phase_id": phase,
                "total_direct_tokens_delta": values["total_direct_tokens"],
                "input_tokens_delta": values["input_tokens"],
                "output_tokens_delta": values["output_tokens"],
                "reasoning_tokens_delta": values["reasoning_tokens"],
                "cache_read_tokens_delta": values["cache_read_tokens"],
            }
            for phase, values in per_phase.items()
            if values["total_direct_tokens"] > 0
        ),
        key=lambda item: item["total_direct_tokens_delta"],
        default=None,
    )
    return {
        "lhs": lhs_label,
        "rhs": rhs_label,
        "totals": total_delta,
        "per_phase": per_phase,
        "largest_positive_phase_delta": largest_positive,
    }


def classify_cause(comparison: dict[str, Any], blockers: list[str]) -> tuple[str, list[str]]:
    if blockers:
        return "receipt_or_metric_binding_gap", blockers
    largest = comparison.get("largest_positive_phase_delta")
    if not largest:
        return "unattributed_fail_closed", ["no_positive_phase_delta_to_explain_increase"]
    phase = largest["phase_id"]
    notes = [
        f"largest_positive_phase={phase}",
        f"largest_positive_total_direct_delta={largest['total_direct_tokens_delta']}",
    ]
    if phase == "phase3":
        return "phase3_default_mode_overhead", notes
    if phase.startswith("phase0") or phase.startswith("phase1") or phase.startswith("phase2"):
        if largest.get("cache_read_tokens_delta", 0) > 0:
            notes.append("cache_read_tokens_also_increased")
        return "pre_phase_context_or_source_delta", notes
    if phase.startswith("phase4"):
        return "phase4_or_validation_overhead", notes
    return "retained_control_age_or_run_order_gap", notes


def main() -> int:
    args = parse_args()
    rows = {
        "burst44a_control": summarize_row("burst44a_control", args.control_run_dir),
        "burst44a_opt_in": summarize_row("burst44a_opt_in", args.opt_in_run_dir),
        "burst45_canary": summarize_row("burst45_canary", args.canary_run_dir),
    }
    receipt_inputs = {
        "control_receipt": {
            "path": str(args.control_receipt),
            "exists": args.control_receipt.exists(),
            "sha256": sha256_path(args.control_receipt),
        },
        "canary_receipt": {
            "path": str(args.canary_receipt),
            "exists": args.canary_receipt.exists(),
            "sha256": sha256_path(args.canary_receipt),
        },
        "rollback_receipt": {
            "path": str(args.rollback_receipt),
            "exists": args.rollback_receipt.exists(),
            "sha256": sha256_path(args.rollback_receipt),
        },
    }
    blockers = [
        f"{name}:missing"
        for name, details in receipt_inputs.items()
        if not details["exists"]
    ]
    for label, row in rows.items():
        blockers.extend(f"{label}:{blocker}" for blocker in row.get("blockers", []))

    control_receipt = load_json(args.control_receipt) if args.control_receipt.exists() else {}
    canary_receipt = load_json(args.canary_receipt) if args.canary_receipt.exists() else {}
    rollback_receipt = load_json(args.rollback_receipt) if args.rollback_receipt.exists() else {}

    canary_vs_control = phase_delta(
        rows["burst45_canary"],
        rows["burst44a_control"],
        "burst45_canary",
        "burst44a_control",
    )
    canary_vs_opt_in = phase_delta(
        rows["burst45_canary"],
        rows["burst44a_opt_in"],
        "burst45_canary",
        "burst44a_opt_in",
    )
    cause, notes = classify_cause(canary_vs_control, sorted(set(blockers)))
    if cause == "phase3_default_mode_overhead":
        disposition = "repair_structurally"
    elif cause == "receipt_or_metric_binding_gap":
        disposition = "repair_structurally"
    elif cause == "unattributed_fail_closed":
        disposition = "park_default"
    else:
        disposition = "opt_in_only"
    verdict = (
        "attribution_pass_named_source"
        if cause not in {"receipt_or_metric_binding_gap", "unattributed_fail_closed"}
        else "attribution_fail_closed"
    )

    receipt = {
        "schema": "newsletter-canary-attribution-receipt.v1",
        "verdict": verdict,
        "cause_classification": cause,
        "cause_notes": notes,
        "stdout_no_tools_default_disposition": disposition,
        "rows": rows,
        "comparisons": {
            "canary_minus_retained_control": canary_vs_control,
            "canary_minus_retained_opt_in": canary_vs_opt_in,
        },
        "receipt_inputs": receipt_inputs,
        "retained_receipt_status": {
            "control_pair_qualified": control_receipt.get("qualified"),
            "canary_verdict": canary_receipt.get("verdict"),
            "rollback_verdict": rollback_receipt.get("verdict"),
        },
        "blockers": sorted(set(blockers)),
        "non_claims": [
            "not_a_production_enablement_receipt",
            "not_a_durable_savings_claim",
            "not_a_model_recommendation",
            "not_github_copilot_billing_proof",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    return 0 if verdict == "attribution_pass_named_source" else 2


if __name__ == "__main__":
    raise SystemExit(main())

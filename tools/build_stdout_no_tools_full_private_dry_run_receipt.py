#!/usr/bin/env python3
"""Build a fail-closed receipt for a full private stdout/no-tools dry run."""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Any

from newsletter_experiment_common import sha256_path, write_json


REQUIRED_DIRECT_FIELDS = {
    "inputTokens",
    "outputTokens",
    "cacheReadTokens",
    "cacheWriteTokens",
    "reasoningTokens",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--control-run-dir", required=True)
    parser.add_argument("--candidate-run-dir", required=True)
    parser.add_argument("--feature-config", required=True)
    parser.add_argument("--disabled-switch-receipt", required=True)
    parser.add_argument("--no-refetch-admission", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--minimum-reduction-pct", type=float, default=5.0)
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    rows: list[dict[str, Any]] = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw.strip():
            continue
        rows.append(json.loads(raw))
    return rows


def source_state(path: Path) -> dict[str, Any]:
    return {
        "path": str(path),
        "exists": path.exists(),
        "sha256": sha256_path(path) if path.exists() else None,
    }


def token_usage(scorecard: dict[str, Any], blockers: list[str], label: str) -> dict[str, Any]:
    usage = scorecard.get("token_usage")
    if not isinstance(usage, dict):
        blockers.append(f"{label} scorecard missing token_usage")
        return {}
    required = ("input_tokens", "output_tokens", "reasoning_tokens", "request_count")
    for key in required:
        if type(usage.get(key)) is not int:
            blockers.append(f"{label} scorecard token_usage.{key} must be an integer")
    total = int(usage.get("input_tokens") or 0) + int(usage.get("output_tokens") or 0) + int(usage.get("reasoning_tokens") or 0)
    return {
        "input_tokens": int(usage.get("input_tokens") or 0),
        "output_tokens": int(usage.get("output_tokens") or 0),
        "reasoning_tokens": int(usage.get("reasoning_tokens") or 0),
        "total_direct_tokens": total,
        "request_count": int(usage.get("request_count") or 0),
        "primary_model": usage.get("primary_model") or scorecard.get("primary_model"),
        "source": usage.get("source"),
    }


def quality_state(scorecard: dict[str, Any], blockers: list[str], label: str) -> dict[str, Any]:
    quality = scorecard.get("quality")
    if not isinstance(quality, dict):
        blockers.append(f"{label} scorecard missing quality")
        return {"passes": False}
    passes = (
        quality.get("strict_pass") is True
        and quality.get("newsletter_pass") is True
        and quality.get("rubric_pass") is True
    )
    if not passes:
        blockers.append(f"{label} quality gates did not all pass")
    return {
        "strict_pass": quality.get("strict_pass"),
        "newsletter_pass": quality.get("newsletter_pass"),
        "rubric_pass": quality.get("rubric_pass"),
        "rubric_score": quality.get("rubric_score"),
        "warning_taxonomy_classes": quality.get("warning_taxonomy_classes") or [],
        "passes": passes,
    }


def run_result_state(run_dir: Path, blockers: list[str], label: str) -> dict[str, Any]:
    path = run_dir / "run-result.json"
    payload = load_json(path) if path.exists() else {}
    if not path.exists():
        blockers.append(f"{label} run-result.json missing")
    for key in ("copilot_exit_code", "source_drift_exit_code", "snapshot_exit_code", "audit_exit_code", "scorecard_exit_code"):
        if key in payload and payload.get(key) != 0:
            blockers.append(f"{label} {key} is nonzero")
    return {"path": str(path), "exists": path.exists(), "sha256": sha256_path(path) if path.exists() else None, "payload": payload}


def direct_fields_complete(row: dict[str, Any]) -> bool:
    present = set(row.get("direct_provider_token_fields_present") or [])
    missing = set(row.get("missing_direct_provider_token_fields") or [])
    return REQUIRED_DIRECT_FIELDS.issubset(present) and not missing


def metrics_state(run_dir: Path, blockers: list[str], label: str) -> dict[str, Any]:
    path = run_dir / "session" / "phase-session-metrics.jsonl"
    rows = load_jsonl(path)
    if not rows:
        blockers.append(f"{label} phase-session-metrics.jsonl missing or empty")
    incomplete = [
        row.get("phase_id")
        for row in rows
        if row.get("exit_code") != 0 or not direct_fields_complete(row)
    ]
    if incomplete:
        blockers.append(f"{label} has phases without exit 0 plus direct token fields: {', '.join(str(x) for x in incomplete)}")
    phases = [str(row.get("phase_id") or "") for row in rows]
    stdout_rows = [row for row in rows if row.get("phase_id") == "phase3_stdout_no_tools_artifact_reuse"]
    phase3_control_rows = [row for row in rows if row.get("phase_id") in {"phase3_curated", "phase3_curation"}]
    tool_calls = 0
    for row in stdout_rows:
        usage = row.get("token_usage") if isinstance(row.get("token_usage"), dict) else {}
        tool_calls += int(usage.get("tool_calls") or 0)
    return {
        "path": str(path),
        "exists": path.exists(),
        "sha256": sha256_path(path) if path.exists() else None,
        "phase_ids": phases,
        "all_direct_fields_complete": bool(rows) and not incomplete,
        "stdout_phase_count": len(stdout_rows),
        "control_phase3_count": len(phase3_control_rows),
        "stdout_tool_calls": tool_calls,
    }


def row_state(run_dir: Path, label: str) -> tuple[dict[str, Any], list[str]]:
    blockers: list[str] = []
    scorecard_path = run_dir / "run-scorecard.json"
    metadata_path = run_dir / "run-metadata.json"
    scorecard = load_json(scorecard_path) if scorecard_path.exists() else {}
    metadata = load_json(metadata_path) if metadata_path.exists() else {}
    if not scorecard_path.exists():
        blockers.append(f"{label} run-scorecard.json missing")
    if not metadata_path.exists():
        blockers.append(f"{label} run-metadata.json missing")
    state = {
        "run_dir": str(run_dir),
        "scorecard": source_state(scorecard_path),
        "run_metadata": source_state(metadata_path),
        "run_result": run_result_state(run_dir, blockers, label),
        "tokens": token_usage(scorecard if isinstance(scorecard, dict) else {}, blockers, label),
        "quality": quality_state(scorecard if isinstance(scorecard, dict) else {}, blockers, label),
        "metrics": metrics_state(run_dir, blockers, label),
        "experiment": (scorecard.get("experiment") if isinstance(scorecard, dict) else {}) or {},
        "metadata_payload": metadata if isinstance(metadata, dict) else {},
    }
    return state, blockers


def validate_feature_config(path: Path, blockers: list[str]) -> dict[str, Any]:
    payload = load_json(path) if path.exists() else {}
    if not path.exists():
        blockers.append("feature config missing")
    if payload.get("configured_mode") != "off":
        blockers.append("feature config configured_mode must remain off")
    if payload.get("default_mode") != "off":
        blockers.append("feature config default_mode must remain off")
    if payload.get("production_default_enabled") is not False:
        blockers.append("feature config production_default_enabled must be false")
    if payload.get("public_customernewsletter_in_scope") is not False:
        blockers.append("feature config public_customernewsletter_in_scope must be false")
    return payload if isinstance(payload, dict) else {}


def validate_disabled_switch(path: Path, blockers: list[str]) -> dict[str, Any]:
    payload = load_json(path) if path.exists() else {}
    if not path.exists():
        blockers.append("disabled-switch receipt missing")
    if payload.get("verdict") != "pass_disabled_switch_dry_run":
        blockers.append("disabled-switch receipt verdict must be pass_disabled_switch_dry_run")
    if payload.get("ready_for_private_default_enablement") is not False:
        blockers.append("disabled-switch receipt must not mark private default ready")
    if payload.get("blockers") not in ([], None):
        blockers.append("disabled-switch receipt blockers must be empty")
    return payload if isinstance(payload, dict) else {}


def validate_no_refetch(path: Path, blockers: list[str]) -> dict[str, Any]:
    payload = load_json(path) if path.exists() else {}
    if not path.exists():
        blockers.append("no-refetch admission missing")
    if payload.get("admission_verdict") != "admit_no_refetch":
        blockers.append("no-refetch admission verdict must be admit_no_refetch")
    if payload.get("no_refetch_compliance") != "pass":
        blockers.append("no-refetch admission compliance must pass")
    if payload.get("blockers") not in ([], None):
        blockers.append("no-refetch admission blockers must be empty")
    return payload if isinstance(payload, dict) else {}


def main() -> int:
    args = parse_args()
    control_dir = Path(args.control_run_dir).expanduser().resolve()
    candidate_dir = Path(args.candidate_run_dir).expanduser().resolve()
    feature_config = Path(args.feature_config).expanduser().resolve()
    switch_receipt = Path(args.disabled_switch_receipt).expanduser().resolve()
    no_refetch = Path(args.no_refetch_admission).expanduser().resolve()
    output = Path(args.output).expanduser().resolve()

    blockers: list[str] = []
    feature_payload = validate_feature_config(feature_config, blockers)
    switch_payload = validate_disabled_switch(switch_receipt, blockers)
    no_refetch_payload = validate_no_refetch(no_refetch, blockers)
    control, control_blockers = row_state(control_dir, "control")
    candidate, candidate_blockers = row_state(candidate_dir, "candidate")
    blockers.extend(control_blockers)
    blockers.extend(candidate_blockers)

    if control["metadata_payload"].get("phase3_stdout_no_tools_enabled") is True:
        blockers.append("control run metadata must not enable phase3 stdout/no-tools")
    if candidate["metadata_payload"].get("phase3_stdout_no_tools_enabled") is not True:
        blockers.append("candidate run metadata must enable phase3 stdout/no-tools")
    expected_no_refetch = str(no_refetch.resolve())
    if candidate["metadata_payload"].get("phase3_stdout_no_tools_no_refetch_admission") != expected_no_refetch:
        blockers.append("candidate metadata no-refetch admission path does not match receipt input")
    if candidate["metrics"].get("stdout_phase_count") != 1:
        blockers.append("candidate must include exactly one phase3 stdout/no-tools metrics row")
    if candidate["metrics"].get("stdout_tool_calls") != 0:
        blockers.append("candidate phase3 stdout/no-tools row must have zero tool calls")
    if control["metrics"].get("control_phase3_count") != 1:
        blockers.append("control must include exactly one canonical phase3 metrics row")

    if control["tokens"].get("primary_model") != candidate["tokens"].get("primary_model"):
        blockers.append("control and candidate primary models differ")
    if control["tokens"].get("request_count") is not None and candidate["tokens"].get("request_count") is not None:
        if candidate["tokens"]["request_count"] > control["tokens"]["request_count"]:
            blockers.append("candidate request_count is higher than control")

    control_total = int(control["tokens"].get("total_direct_tokens") or 0)
    candidate_total = int(candidate["tokens"].get("total_direct_tokens") or 0)
    reduction_pct = ((control_total - candidate_total) / control_total * 100.0) if control_total else None
    if reduction_pct is None or reduction_pct < args.minimum_reduction_pct:
        blockers.append(f"candidate total direct tokens are not at least {args.minimum_reduction_pct:g}% lower")

    receipt = {
        "schema_version": 1,
        "receipt_type": "stdout_no_tools_full_private_production_dry_run",
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "verdict": "pass_full_private_dry_run" if not blockers else "fail_closed_full_private_dry_run",
        "qualifies": not blockers,
        "minimum_reduction_pct": args.minimum_reduction_pct,
        "sources": {
            "feature_config": source_state(feature_config),
            "disabled_switch_receipt": source_state(switch_receipt),
            "no_refetch_admission": source_state(no_refetch),
        },
        "source_verdicts": {
            "feature_config_mode": feature_payload.get("configured_mode"),
            "disabled_switch_verdict": switch_payload.get("verdict"),
            "no_refetch_admission_verdict": no_refetch_payload.get("admission_verdict"),
        },
        "control": control,
        "candidate": candidate,
        "deltas": {
            "total_direct_tokens_candidate_minus_control": candidate_total - control_total,
            "total_direct_token_reduction_pct": round(reduction_pct, 4) if reduction_pct is not None else None,
            "request_count_candidate_minus_control": candidate["tokens"].get("request_count", 0) - control["tokens"].get("request_count", 0),
        },
        "non_claims": [
            "This is a full private production dry-run receipt, not production default enablement.",
            "This is not a durable savings claim.",
            "This is not a GitHub Copilot billing claim.",
            "This is not a model recommendation.",
            "This receipt does not mutate public CustomerNewsletter.",
        ],
        "blockers": blockers,
    }
    write_json(output, receipt)
    return 0 if receipt["qualifies"] else 2


if __name__ == "__main__":
    raise SystemExit(main())

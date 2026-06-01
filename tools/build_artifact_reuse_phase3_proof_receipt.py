#!/usr/bin/env python3
"""Build a bounded Phase 3 artifact-reuse proof receipt."""

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
END = "2026-02-13"
NO_REFETCH_ARTIFACTS = {
    "phase2_selected_source_ids": f"workspace/newsletter_phase2_selected_source_ids_{END}.json",
    "phase2_fetch_attempt_ledger": f"workspace/newsletter_phase2_fetch_attempt_ledger_{END}.json",
    "phase2_no_refetch_compliance": f"workspace/newsletter_phase2_no_refetch_compliance_{END}.json",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--control-run-dir", required=True)
    parser.add_argument("--reuse-run-dir", required=True)
    parser.add_argument("--control-repo", required=True)
    parser.add_argument("--reuse-repo", required=True)
    parser.add_argument("--no-refetch-admission", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def load_jsonl_last(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    rows = [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if not rows:
        return None
    return json.loads(rows[-1])


def parse_summary(path: Path) -> dict[str, Any]:
    summary_path = path / "summary.md"
    values: dict[str, str] = {}
    if summary_path.exists():
        for line in summary_path.read_text(encoding="utf-8").splitlines():
            if not line.startswith("- ") or ":" not in line:
                continue
            key, value = line[2:].split(":", 1)
            values[key.strip().lower().replace(" ", "_")] = value.strip()

    def return_code(name: str) -> int:
        raw = values.get(name)
        if raw in {None, "", "None", "null"}:
            return 999
        try:
            return int(raw)
        except (TypeError, ValueError):
            return 999

    return {
        "path": str(summary_path),
        "exists": summary_path.exists(),
        "sha256": sha256_path(summary_path) if summary_path.exists() else None,
        "final_status": values.get("final_status"),
        "overall_return_code": return_code("overall_return_code"),
        "phase_return_code": return_code("phase_return_code"),
        "validation_return_code": return_code("validation_return_code"),
        "curated_receipt_return_code": return_code("curated_receipt_return_code"),
    }


def int_token(row: dict[str, Any], key: str, errors: list[str]) -> int:
    token_usage = row.get("token_usage") or {}
    raw = token_usage.get(key)
    if raw in {None, ""}:
        errors.append(f"missing numeric token_usage.{key}")
        return 0
    try:
        return int(raw)
    except (TypeError, ValueError):
        errors.append(f"invalid numeric token_usage.{key}")
        return 0


def metric_row(run_dir: Path) -> dict[str, Any]:
    metrics_path = run_dir / "session" / "phase-session-metrics.jsonl"
    row = load_jsonl_last(metrics_path)
    if not isinstance(row, dict):
        return {
            "path": str(metrics_path),
            "exists": metrics_path.exists(),
            "sha256": sha256_path(metrics_path) if metrics_path.exists() else None,
            "loaded": False,
            "errors": ["phase-session-metrics JSONL missing or empty"],
        }
    present = set(row.get("direct_provider_token_fields_present") or [])
    missing = set(row.get("missing_direct_provider_token_fields") or [])
    detection = row.get("session_log_detection") or {}
    token_usage = row.get("token_usage") or {}
    numeric_errors: list[str] = []
    input_tokens = int_token(row, "input_tokens", numeric_errors)
    output_tokens = int_token(row, "output_tokens", numeric_errors)
    cache_read_tokens = int_token(row, "cache_read_tokens", numeric_errors)
    cache_write_tokens = int_token(row, "cache_write_tokens", numeric_errors)
    reasoning_tokens = int_token(row, "reasoning_tokens", numeric_errors)
    request_count = int_token(row, "request_count", numeric_errors)
    tool_calls = int_token({"token_usage": token_usage}, "tool_calls", numeric_errors)
    return {
        "path": str(metrics_path),
        "exists": True,
        "sha256": sha256_path(metrics_path),
        "loaded": True,
        "phase_id": row.get("phase_id"),
        "model": row.get("model"),
        "exit_code": row.get("exit_code"),
        "session_detection_status": detection.get("status"),
        "bound_candidate_count": detection.get("bound_candidate_count"),
        "direct_provider_token_fields_present": sorted(present),
        "missing_direct_provider_token_fields": sorted(missing),
        "direct_fields_complete": REQUIRED_DIRECT_FIELDS.issubset(present) and not missing,
        "original_prompt_sha256": row.get("original_prompt_sha256"),
        "effective_prompt_sha256": row.get("prompt_sha256"),
        "prompt_binding_marker_included": row.get("prompt_binding_marker_included"),
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "cache_read_tokens": cache_read_tokens,
        "cache_write_tokens": cache_write_tokens,
        "reasoning_tokens": reasoning_tokens,
        "request_count": request_count,
        "tool_calls": tool_calls,
        "source": token_usage.get("source"),
        "numeric_fields_complete": not numeric_errors,
        "errors": numeric_errors,
    }


def artifact_state(repo: Path) -> dict[str, Any]:
    rows: dict[str, Any] = {}
    for name, rel_path in NO_REFETCH_ARTIFACTS.items():
        path = repo / rel_path
        rows[name] = {
            "path": str(path),
            "exists": path.exists(),
            "sha256": sha256_path(path) if path.exists() else None,
            "size_bytes": path.stat().st_size if path.exists() else None,
        }
    return rows


def load_no_refetch_compliance(repo: Path) -> dict[str, Any]:
    path = repo / NO_REFETCH_ARTIFACTS["phase2_no_refetch_compliance"]
    if not path.exists():
        return {"path": str(path), "exists": False, "pass": False, "errors": ["missing no-refetch compliance artifact"]}
    payload = load_json(path)
    errors: list[str] = []
    if payload.get("compliance") != "pass":
        errors.append("no-refetch compliance is not pass")
    if payload.get("network_access_permitted") is not False:
        errors.append("network_access_permitted must be false")
    if int(payload.get("fetch_attempt_count") or 0) != 0:
        errors.append("fetch_attempt_count must be zero")
    return {
        "path": str(path),
        "exists": True,
        "sha256": sha256_path(path),
        "pass": not errors,
        "network_access_permitted": payload.get("network_access_permitted"),
        "fetch_attempt_count": payload.get("fetch_attempt_count"),
        "selection_manifest_sha256": payload.get("selection_manifest_sha256"),
        "event_sources_sha256": payload.get("event_sources_sha256"),
        "phase2_events_sha256": payload.get("phase2_events_sha256"),
        "errors": errors,
    }


def load_no_refetch_binding(repo: Path, admission: dict[str, Any]) -> dict[str, Any]:
    selected_path = repo / NO_REFETCH_ARTIFACTS["phase2_selected_source_ids"]
    fetch_path = repo / NO_REFETCH_ARTIFACTS["phase2_fetch_attempt_ledger"]
    compliance_path = repo / NO_REFETCH_ARTIFACTS["phase2_no_refetch_compliance"]
    errors: list[str] = []
    selected_payload = load_json(selected_path) if selected_path.exists() else {}
    fetch_payload = load_json(fetch_path) if fetch_path.exists() else {}
    compliance_payload = load_json(compliance_path) if compliance_path.exists() else {}

    selected_ids = selected_payload.get("selected_source_ids") or []
    admission_selected_ids = admission.get("selected_source_ids") or []
    if selected_payload.get("selection_manifest_sha256") != admission.get("selection_manifest_sha256"):
        errors.append("selected-source artifact selection manifest hash does not match admission")
    if selected_payload.get("event_sources_sha256") != admission.get("event_sources_sha256"):
        errors.append("selected-source artifact event sources hash does not match admission")
    if selected_ids != admission_selected_ids:
        errors.append("selected-source IDs do not match admission receipt")
    if len(selected_ids) != int(admission.get("selected_source_count") or -1):
        errors.append("selected-source count does not match admission receipt")

    if fetch_payload.get("network_access_permitted") is not False:
        errors.append("fetch ledger network_access_permitted must be false")
    if int(fetch_payload.get("fetch_attempt_count") or 0) != 0:
        errors.append("fetch ledger fetch_attempt_count must be zero")
    if fetch_payload.get("fetch_attempts") not in ([], None):
        errors.append("fetch ledger fetch_attempts must be empty")

    if compliance_payload.get("selection_manifest_sha256") != admission.get("selection_manifest_sha256"):
        errors.append("compliance selection manifest hash does not match admission")
    if compliance_payload.get("event_sources_sha256") != admission.get("event_sources_sha256"):
        errors.append("compliance event sources hash does not match admission")
    if compliance_payload.get("selected_source_ids_sha256") != sha256_path(selected_path):
        errors.append("compliance selected-source artifact hash does not match file")
    if compliance_payload.get("fetch_attempt_ledger_sha256") != sha256_path(fetch_path):
        errors.append("compliance fetch-ledger hash does not match file")

    return {
        "pass": not errors,
        "selected_source_count": len(selected_ids),
        "admission_selected_source_count": admission.get("selected_source_count"),
        "selection_manifest_sha256": selected_payload.get("selection_manifest_sha256"),
        "event_sources_sha256": selected_payload.get("event_sources_sha256"),
        "fetch_attempt_count": fetch_payload.get("fetch_attempt_count"),
        "network_access_permitted": fetch_payload.get("network_access_permitted"),
        "errors": errors,
    }


def run_row(run_dir: Path, repo: Path, row_class: str) -> dict[str, Any]:
    summary = parse_summary(run_dir)
    metrics = metric_row(run_dir)
    artifacts = artifact_state(repo)
    errors: list[str] = []
    if summary["final_status"] != "pass" or summary["overall_return_code"] != 0:
        errors.append("phase3 summary did not pass")
    if not metrics.get("loaded"):
        errors.extend(metrics.get("errors") or [])
    else:
        if metrics.get("phase_id") != "phase3_curation":
            errors.append("metrics phase_id is not phase3_curation")
        if metrics.get("exit_code") != 0:
            errors.append("metrics exit_code is nonzero")
        if metrics.get("session_detection_status") != "bound_candidate":
            errors.append("session detection is not bound_candidate")
        if metrics.get("direct_fields_complete") is not True:
            errors.append("direct provider token fields are incomplete")
        if metrics.get("numeric_fields_complete") is not True:
            errors.append("numeric token telemetry fields are incomplete")
    if row_class == "control" and any(row.get("exists") for row in artifacts.values()):
        errors.append("control repo contains no-refetch artifacts")
    if row_class == "reuse" and not all(row.get("exists") for row in artifacts.values()):
        errors.append("reuse repo is missing no-refetch artifacts")
    return {
        "row_class": row_class,
        "run_dir": str(run_dir),
        "repo": str(repo),
        "summary": summary,
        "metrics": metrics,
        "no_refetch_artifacts": artifacts,
        "passes_row_checks": not errors,
        "errors": errors,
    }


def deltas(control: dict[str, Any], reuse: dict[str, Any]) -> dict[str, Any]:
    c = control["metrics"]
    r = reuse["metrics"]
    total_control = c.get("input_tokens", 0) + c.get("output_tokens", 0)
    total_reuse = r.get("input_tokens", 0) + r.get("output_tokens", 0)
    total_with_reasoning_control = total_control + c.get("reasoning_tokens", 0)
    total_with_reasoning_reuse = total_reuse + r.get("reasoning_tokens", 0)
    return {
        "input_tokens_delta": r.get("input_tokens", 0) - c.get("input_tokens", 0),
        "output_tokens_delta": r.get("output_tokens", 0) - c.get("output_tokens", 0),
        "reasoning_tokens_delta": r.get("reasoning_tokens", 0) - c.get("reasoning_tokens", 0),
        "request_count_delta": r.get("request_count", 0) - c.get("request_count", 0),
        "tool_calls_delta": r.get("tool_calls", 0) - c.get("tool_calls", 0),
        "total_input_output_tokens_delta": total_reuse - total_control,
        "total_with_reasoning_tokens_delta": total_with_reasoning_reuse - total_with_reasoning_control,
        "reuse_input_tokens_lower": r.get("input_tokens", 0) < c.get("input_tokens", 0),
        "reuse_total_tokens_lower": total_reuse < total_control,
        "reuse_request_count_not_higher": r.get("request_count", 0) <= c.get("request_count", 0),
    }


def main() -> int:
    args = parse_args()
    control_run_dir = Path(args.control_run_dir).expanduser().resolve()
    reuse_run_dir = Path(args.reuse_run_dir).expanduser().resolve()
    control_repo = Path(args.control_repo).expanduser().resolve()
    reuse_repo = Path(args.reuse_repo).expanduser().resolve()
    output = Path(args.output).expanduser().resolve()
    admission_path = Path(args.no_refetch_admission).expanduser().resolve()

    admission = load_json(admission_path)
    admission_errors: list[str] = []
    if admission.get("admission_verdict") != "admit_no_refetch":
        admission_errors.append("admission receipt verdict is not admit_no_refetch")
    if int(admission.get("selected_source_count") or 0) <= 0:
        admission_errors.append("admission receipt selected_source_count is zero")

    control = run_row(control_run_dir, control_repo, "control")
    reuse = run_row(reuse_run_dir, reuse_repo, "reuse")
    reuse_compliance = load_no_refetch_compliance(reuse_repo)
    if not reuse_compliance.get("pass"):
        reuse["errors"].extend(reuse_compliance.get("errors") or [])
        reuse["passes_row_checks"] = False
    reuse_binding = load_no_refetch_binding(reuse_repo, admission)
    if not reuse_binding.get("pass"):
        reuse["errors"].extend(reuse_binding.get("errors") or [])
        reuse["passes_row_checks"] = False
    delta = deltas(control, reuse)
    prompt_match = (
        control["metrics"].get("original_prompt_sha256")
        and control["metrics"].get("original_prompt_sha256") == reuse["metrics"].get("original_prompt_sha256")
    )
    model_match = (
        control["metrics"].get("model")
        and control["metrics"].get("model") == reuse["metrics"].get("model")
    )
    rows_qualified = (
        control["passes_row_checks"]
        and reuse["passes_row_checks"]
        and not admission_errors
        and prompt_match
        and model_match
    )
    positive_signal = rows_qualified and (
        delta["reuse_total_tokens_lower"] or delta["reuse_input_tokens_lower"]
    ) and delta["reuse_request_count_not_higher"]
    if rows_qualified and positive_signal:
        verdict = "qualified_positive_signal"
    elif rows_qualified:
        verdict = "qualified_negative_or_neutral_signal"
    else:
        verdict = "blocked_incomplete_evidence"

    receipt = {
        "schema_version": 1,
        "receipt_type": "artifact_reuse_phase3_proof",
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "surface": "benchmark_phase3_slice",
        "window": {"start": "2025-12-05", "end": END, "mode": "benchmark"},
        "control": control,
        "reuse": reuse,
        "no_refetch_admission": {
            "path": str(admission_path),
            "sha256": sha256_path(admission_path),
            "admission_verdict": admission.get("admission_verdict"),
            "selected_source_count": admission.get("selected_source_count"),
            "source_pack_sha256": admission.get("source_pack_sha256"),
            "renderer_or_prompt_hash": admission.get("renderer_or_prompt_hash"),
            "selection_manifest_sha256": admission.get("selection_manifest_sha256"),
            "errors": admission_errors,
        },
        "reuse_no_refetch_compliance": reuse_compliance,
        "reuse_no_refetch_binding": reuse_binding,
        "prompt_equality": {
            "original_prompt_sha256_match": bool(prompt_match),
            "control_original_prompt_sha256": control["metrics"].get("original_prompt_sha256"),
            "reuse_original_prompt_sha256": reuse["metrics"].get("original_prompt_sha256"),
            "note": "Effective prompt hashes differ because the phase runner injects unique session-binding markers.",
        },
        "model_equality": {
            "model_match": bool(model_match),
            "control_model": control["metrics"].get("model"),
            "reuse_model": reuse["metrics"].get("model"),
        },
        "deltas": delta,
        "qualification": {
            "rows_qualified": rows_qualified,
            "positive_signal": positive_signal,
            "verdict": verdict,
            "blockers": [
                *admission_errors,
                *control["errors"],
                *reuse["errors"],
                *(["original prompt hashes do not match"] if not prompt_match else []),
                *(["control and reuse models do not match"] if not model_match else []),
            ],
        },
        "non_claims": [
            "This receipt compares one bounded benchmark Phase 3 slice only.",
            "It is not an end-to-end artifact-reuse savings claim.",
            "It is not production adoption, durable savings proof, billing proof, a cache savings claim, or a model recommendation.",
        ],
    }
    write_json(output, receipt)
    return 0 if rows_qualified else 2


if __name__ == "__main__":
    raise SystemExit(main())

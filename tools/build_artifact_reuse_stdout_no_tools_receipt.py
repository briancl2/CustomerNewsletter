#!/usr/bin/env python3
"""Build fail-closed receipts for Phase 3 stdout/no-tools artifact reuse."""

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
EXPECTED_PHASE_IDS = {
    "control": "phase3_curation",
    "candidate": "phase3_stdout_no_tools_artifact_reuse",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-run-dir", required=True)
    parser.add_argument("--candidate-repo", required=True)
    parser.add_argument("--no-refetch-admission", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--control-run-dir", default="")
    parser.add_argument("--control-repo", default="")
    parser.add_argument("--manifest", default="")
    parser.add_argument("--expected-prompt-sha256", default="")
    parser.add_argument("--expected-prompt-policy-sha256", default="")
    parser.add_argument("--expected-source-pack-sha256", default="")
    parser.add_argument("--stdout-artifact", default="")
    parser.add_argument("--materialized-artifact", default="")
    parser.add_argument("--validation-result", default="")
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


def parse_summary(run_dir: Path) -> dict[str, Any]:
    path = run_dir / "summary.md"
    values: dict[str, str] = {}
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            if not line.startswith("- ") or ":" not in line:
                continue
            key, value = line[2:].split(":", 1)
            values[key.strip().lower().replace(" ", "_")] = value.strip()

    def code(name: str) -> int:
        raw = values.get(name)
        if raw in {None, "", "None", "null"}:
            return 999
        try:
            return int(raw)
        except (TypeError, ValueError):
            return 999

    return {
        "path": str(path),
        "exists": path.exists(),
        "sha256": sha256_path(path) if path.exists() else None,
        "run_id": values.get("run_id"),
        "date_range": values.get("date_range"),
        "mode": values.get("mode"),
        "model": values.get("model"),
        "final_status": values.get("final_status"),
        "overall_return_code": code("overall_return_code"),
        "phase_return_code": code("phase_return_code"),
        "validation_return_code": code("validation_return_code"),
        "curated_receipt_return_code": code("curated_receipt_return_code"),
        "materialization_return_code": code("materialization_return_code"),
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


def tool_events(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    events: list[dict[str, Any]] = []
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if not raw.strip():
            continue
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if str(payload.get("type") or "").startswith("tool."):
            events.append(payload)
    return events


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
    session_path = Path(str(row.get("session_log_path") or run_dir / "session" / "events.jsonl"))
    events = tool_events(session_path)
    return {
        "path": str(metrics_path),
        "exists": True,
        "sha256": sha256_path(metrics_path),
        "loaded": True,
        "phase_id": row.get("phase_id"),
        "model": row.get("model"),
        "exit_code": row.get("exit_code"),
        "prompt_sha256": row.get("prompt_sha256"),
        "original_prompt_sha256": row.get("original_prompt_sha256"),
        "session_log_path": str(session_path),
        "session_log_sha256": sha256_path(session_path) if session_path.exists() else row.get("session_log_sha256"),
        "session_detection_status": detection.get("status"),
        "bound_candidate_count": detection.get("bound_candidate_count"),
        "candidate_count": detection.get("candidate_count"),
        "direct_provider_token_fields_present": sorted(present),
        "missing_direct_provider_token_fields": sorted(missing),
        "direct_fields_complete": REQUIRED_DIRECT_FIELDS.issubset(present) and not missing,
        "input_tokens": int_token(row, "input_tokens", numeric_errors),
        "output_tokens": int_token(row, "output_tokens", numeric_errors),
        "cache_read_tokens": int_token(row, "cache_read_tokens", numeric_errors),
        "cache_write_tokens": int_token(row, "cache_write_tokens", numeric_errors),
        "reasoning_tokens": int_token(row, "reasoning_tokens", numeric_errors),
        "request_count": int_token(row, "request_count", numeric_errors),
        "tool_calls": int_token({"token_usage": token_usage}, "tool_calls", numeric_errors),
        "source": token_usage.get("source"),
        "numeric_fields_complete": not numeric_errors,
        "tool_filters": row.get("tool_filters") or {},
        "artifact_paths": row.get("artifact_paths") or [],
        "receipt_ids": row.get("receipt_ids") or [],
        "tool_event_count": len(events),
        "tool_events": [
            {
                "type": event.get("type"),
                "toolName": ((event.get("data") or {}).get("toolName") if isinstance(event.get("data"), dict) else None),
            }
            for event in events
        ],
        "errors": numeric_errors,
    }


def run_metadata(run_dir: Path) -> dict[str, Any]:
    path = run_dir / "run-metadata.json"
    if not path.exists():
        return {"path": str(path), "exists": False, "loaded": False}
    payload = load_json(path)
    if not isinstance(payload, dict):
        return {"path": str(path), "exists": True, "loaded": False}
    payload["_path"] = str(path)
    payload["_sha256"] = sha256_path(path)
    payload["exists"] = True
    payload["loaded"] = True
    return payload


def resolve_path(raw: str, base: Path) -> Path:
    path = Path(raw).expanduser()
    if path.is_absolute():
        return path.resolve()
    return (base / path).resolve()


def path_state(path: Path) -> dict[str, Any]:
    return {
        "path": str(path),
        "exists": path.exists(),
        "sha256": sha256_path(path) if path.exists() else None,
        "size_bytes": path.stat().st_size if path.exists() else None,
    }


def sidecar_paths(repo: Path, end: str) -> dict[str, Path]:
    return {
        "phase2_selected_source_ids": repo / "workspace" / f"newsletter_phase2_selected_source_ids_{end}.json",
        "phase2_fetch_attempt_ledger": repo / "workspace" / f"newsletter_phase2_fetch_attempt_ledger_{end}.json",
        "phase2_no_refetch_compliance": repo / "workspace" / f"newsletter_phase2_no_refetch_compliance_{end}.json",
    }


def no_refetch_checks(admission_path: Path, candidate_repo: Path, end: str) -> tuple[dict[str, Any], list[str]]:
    errors: list[str] = []
    admission = load_json(admission_path) if admission_path.exists() else {}
    if not isinstance(admission, dict):
        admission = {}
        errors.append("selected-source/no-refetch receipt is missing or invalid JSON")
    if admission.get("admission_verdict") != "admit_no_refetch":
        errors.append("selected-source/no-refetch receipt verdict is not admit_no_refetch")
    sidecars = sidecar_paths(candidate_repo, end)
    sidecar_states = {name: path_state(path) for name, path in sidecars.items()}
    for name, state in sidecar_states.items():
        if not state["exists"]:
            errors.append(f"candidate repo missing no-refetch sidecar: {name}")
    generated_artifacts = admission.get("generated_artifacts") if isinstance(admission.get("generated_artifacts"), dict) else {}
    for name, state in sidecar_states.items():
        expected = generated_artifacts.get(name) if isinstance(generated_artifacts.get(name), dict) else {}
        expected_sha = expected.get("sha256")
        if not expected_sha:
            errors.append(f"admission receipt missing generated artifact hash for {name}")
        elif expected_sha != state.get("sha256"):
            errors.append(f"admission generated artifact hash does not match candidate sidecar: {name}")

    selected_payload = load_json(sidecars["phase2_selected_source_ids"]) if sidecars["phase2_selected_source_ids"].exists() else {}
    fetch_payload = load_json(sidecars["phase2_fetch_attempt_ledger"]) if sidecars["phase2_fetch_attempt_ledger"].exists() else {}
    compliance_payload = load_json(sidecars["phase2_no_refetch_compliance"]) if sidecars["phase2_no_refetch_compliance"].exists() else {}
    if fetch_payload.get("network_access_permitted") is not False:
        errors.append("fetch ledger network_access_permitted must be false")
    if int(fetch_payload.get("fetch_attempt_count") or 0) != 0:
        errors.append("fetch ledger fetch_attempt_count must be zero")
    if fetch_payload.get("fetch_attempts") not in ([], None):
        errors.append("fetch ledger fetch_attempts must be empty")
    if compliance_payload.get("compliance") != "pass":
        errors.append("no-refetch compliance sidecar is not pass")
    if compliance_payload.get("network_access_permitted") is not False:
        errors.append("no-refetch compliance network_access_permitted must be false")
    if int(compliance_payload.get("fetch_attempt_count") or 0) != 0:
        errors.append("no-refetch compliance fetch_attempt_count must be zero")
    for field in ("source_pack_sha256", "selection_manifest_sha256", "event_sources_sha256"):
        if selected_payload.get(field) != admission.get(field):
            errors.append(f"selected-source sidecar {field} does not match admission receipt")
        if compliance_payload.get(field) != admission.get(field):
            errors.append(f"no-refetch compliance sidecar {field} does not match admission receipt")
    if not compliance_payload.get("selected_source_ids_sha256"):
        errors.append("no-refetch compliance missing selected-source file hash")
    elif compliance_payload.get("selected_source_ids_sha256") != sidecar_states["phase2_selected_source_ids"]["sha256"]:
        errors.append("no-refetch compliance selected-source hash does not match file")
    if not compliance_payload.get("fetch_attempt_ledger_sha256"):
        errors.append("no-refetch compliance missing fetch-ledger file hash")
    elif compliance_payload.get("fetch_attempt_ledger_sha256") != sidecar_states["phase2_fetch_attempt_ledger"]["sha256"]:
        errors.append("no-refetch compliance fetch-ledger hash does not match file")
    if selected_payload.get("selected_source_ids") != admission.get("selected_source_ids"):
        errors.append("selected-source sidecar does not match admission receipt")
    if len(selected_payload.get("selected_source_ids") or []) != int(admission.get("selected_source_count") or -1):
        errors.append("selected-source count does not match admission receipt")

    return {
        "path": str(admission_path),
        "exists": admission_path.exists(),
        "sha256": sha256_path(admission_path) if admission_path.exists() else None,
        "admission_verdict": admission.get("admission_verdict"),
        "selected_source_count": admission.get("selected_source_count"),
        "source_pack_sha256": admission.get("source_pack_sha256"),
        "renderer_or_prompt_hash": admission.get("renderer_or_prompt_hash"),
        "selection_manifest_sha256": admission.get("selection_manifest_sha256"),
        "event_sources_sha256": admission.get("event_sources_sha256"),
        "sidecars": sidecar_states,
    }, errors


def row_checks(
    *,
    row_name: str,
    run_dir: Path,
    repo: Path,
    stdout_artifact: Path | None,
    materialized_artifact: Path | None,
    validation_result: Path | None,
    end: str,
) -> dict[str, Any]:
    summary = parse_summary(run_dir)
    metrics = metric_row(run_dir)
    metadata = run_metadata(run_dir)
    errors: list[str] = []
    if not summary["exists"]:
        errors.append(f"{row_name} summary is missing")
    elif summary["final_status"] != "pass" or summary["overall_return_code"] != 0:
        errors.append(f"{row_name} summary did not pass")
    if not metrics.get("loaded"):
        errors.extend(metrics.get("errors") or [])
    else:
        expected_phase_id = EXPECTED_PHASE_IDS[row_name]
        if metrics.get("phase_id") != expected_phase_id:
            errors.append(f"{row_name} metrics phase_id is not {expected_phase_id}")
        if metrics.get("exit_code") != 0:
            errors.append(f"{row_name} metrics exit_code is nonzero")
        if metrics.get("session_detection_status") != "bound_candidate" or metrics.get("bound_candidate_count") != 1:
            errors.append(f"{row_name} session is missing or ambiguous")
        if metrics.get("direct_fields_complete") is not True:
            errors.append(f"{row_name} direct provider token fields are incomplete")
        if metrics.get("numeric_fields_complete") is not True:
            errors.append(f"{row_name} numeric token telemetry fields are incomplete")
        if row_name == "candidate" and (
            int(metrics.get("tool_calls") or 0) != 0 or int(metrics.get("tool_event_count") or 0) != 0
        ):
            errors.append(f"{row_name} session contains candidate tool calls")
    stdout_state = path_state(stdout_artifact) if stdout_artifact else {"path": None, "exists": False}
    materialized_state = path_state(materialized_artifact) if materialized_artifact else {"path": None, "exists": False}
    validation_state = path_state(validation_result) if validation_result else {"path": None, "exists": False}
    validation_payload = load_json(validation_result) if validation_result and validation_result.exists() else {}
    if row_name == "candidate":
        if not stdout_state["exists"]:
            errors.append("candidate stdout artifact is missing")
        if not materialized_state["exists"]:
            errors.append("candidate materialized artifact is missing")
        if not validation_state["exists"]:
            errors.append("candidate validation result is missing")
        if validation_payload.get("exit_code") != 0:
            errors.append("candidate validation result did not pass")
        if validation_payload.get("validated_artifact_sha256") and validation_payload.get("validated_artifact_sha256") != stdout_state.get("sha256"):
            errors.append("validator artifact hash does not bind to stdout artifact")
        if stdout_state.get("sha256") and materialized_state.get("sha256") != stdout_state.get("sha256"):
            errors.append("materialized artifact hash does not match validated stdout artifact")
        if metadata.get("loaded"):
            if metadata.get("stdout_artifact_sha256") != stdout_state.get("sha256"):
                errors.append("run metadata stdout hash does not match stdout artifact")
            if metadata.get("materialized_artifact_sha256") != materialized_state.get("sha256"):
                errors.append("run metadata materialized hash does not match materialized artifact")
            if metadata.get("validation_result_sha256") != validation_state.get("sha256"):
                errors.append("run metadata validation hash does not match validation artifact")
            materialization = metadata.get("no_refetch_sidecar_materialization")
            if not isinstance(materialization, dict):
                errors.append("candidate run metadata missing no-refetch sidecar materialization")
            else:
                if not materialization.get("materialized_at_utc"):
                    errors.append("candidate no-refetch sidecar materialization missing timestamp")
                materialized_sidecars = materialization.get("sidecars")
                if not isinstance(materialized_sidecars, dict):
                    errors.append("candidate no-refetch sidecar materialization missing sidecars")
                else:
                    for sidecar_name, sidecar_path in sidecar_paths(repo, end).items():
                        state = path_state(sidecar_path)
                        entry = materialized_sidecars.get(sidecar_name)
                        if not isinstance(entry, dict):
                            errors.append(f"candidate run metadata missing sidecar copy record: {sidecar_name}")
                            continue
                        if Path(str(entry.get("destination_path") or "")).expanduser().resolve() != sidecar_path.resolve():
                            errors.append(f"candidate sidecar materialization destination mismatch: {sidecar_name}")
                        source_path = Path(str(entry.get("source_path") or "")).expanduser()
                        if not source_path.is_absolute():
                            source_path = (run_dir / source_path).resolve()
                        if not source_path.exists():
                            errors.append(f"candidate sidecar materialization source missing: {sidecar_name}")
                            continue
                        actual_source_sha = sha256_path(source_path)
                        if entry.get("source_sha256") != actual_source_sha:
                            errors.append(f"candidate sidecar materialization source hash does not match source file: {sidecar_name}")
                        if entry.get("sha256") != state.get("sha256"):
                            errors.append(f"candidate sidecar materialization hash mismatch: {sidecar_name}")
                        if actual_source_sha != state.get("sha256"):
                            errors.append(f"candidate sidecar materialization source hash mismatch: {sidecar_name}")
        else:
            errors.append("candidate run metadata is missing or invalid")
    no_refetch_sidecars = {
        name: path_state(path)
        for name, path in sidecar_paths(repo, end).items()
        if path.exists()
    }
    if row_name == "control" and no_refetch_sidecars:
        errors.append("control repo contains candidate no-refetch sidecars")
    return {
        "row_name": row_name,
        "run_dir": str(run_dir),
        "repo": str(repo),
        "summary": summary,
        "metrics": metrics,
        "run_metadata": metadata,
        "stdout_artifact": stdout_state,
        "materialized_artifact": materialized_state,
        "validation_result": validation_state,
        "validation_payload": validation_payload,
        "no_refetch_sidecars": no_refetch_sidecars,
        "no_refetch_sidecar_materialization": (
            metadata.get("no_refetch_sidecar_materialization") if isinstance(metadata, dict) else None
        ),
        "passes": not errors,
        "errors": errors,
    }


def infer_end(metadata: dict[str, Any], manifest: dict[str, Any] | None) -> str:
    if metadata.get("end"):
        return str(metadata["end"])
    if manifest and manifest.get("end"):
        return str(manifest["end"])
    return "2026-02-13"


def expected_date_range(start: str | None, end: str | None) -> str:
    return f"{start} to {end}" if start and end else ""


def add_comparability_errors(
    *,
    control: dict[str, Any] | None,
    candidate: dict[str, Any],
    manifest: dict[str, Any] | None,
    candidate_metadata: dict[str, Any],
) -> list[str]:
    errors: list[str] = []
    expected_start = str(candidate_metadata.get("start") or (manifest or {}).get("start") or "")
    expected_end = str(candidate_metadata.get("end") or (manifest or {}).get("end") or "")
    expected_mode = str(candidate_metadata.get("mode") or (manifest or {}).get("mode") or "")
    expected_range = expected_date_range(expected_start, expected_end)
    for row in [candidate, *( [control] if control else [] )]:
        if row is None:
            continue
        name = str(row.get("row_name") or "row")
        summary = row.get("summary") or {}
        metrics = row.get("metrics") or {}
        if expected_range and summary.get("date_range") != expected_range:
            errors.append(f"{name} summary date range does not match manifest")
        if expected_mode and summary.get("mode") != expected_mode:
            errors.append(f"{name} summary mode does not match manifest")
        if metrics.get("model") and summary.get("model") != metrics.get("model"):
            errors.append(f"{name} summary model does not match metrics model")
    if control:
        if control["metrics"].get("model") != candidate["metrics"].get("model"):
            errors.append("control and candidate metrics models differ")
        if control["summary"].get("date_range") != candidate["summary"].get("date_range"):
            errors.append("control and candidate summary date ranges differ")
        if control["summary"].get("mode") != candidate["summary"].get("mode"):
            errors.append("control and candidate summary modes differ")
    return errors


def main() -> int:
    args = parse_args()
    candidate_run_dir = Path(args.candidate_run_dir).expanduser().resolve()
    candidate_repo = Path(args.candidate_repo).expanduser().resolve()
    output = Path(args.output).expanduser().resolve()
    admission_path = Path(args.no_refetch_admission).expanduser().resolve()
    manifest_path = Path(args.manifest).expanduser().resolve() if args.manifest else None
    manifest = load_json(manifest_path) if manifest_path and manifest_path.exists() else None
    candidate_metadata = run_metadata(candidate_run_dir)
    end = infer_end(candidate_metadata, manifest if isinstance(manifest, dict) else None)

    stdout_artifact = (
        resolve_path(args.stdout_artifact, candidate_repo)
        if args.stdout_artifact
        else Path(str(candidate_metadata.get("stdout_artifact_path") or candidate_run_dir / "stdout" / "phase3_curated_candidate.md"))
    )
    materialized_artifact = (
        resolve_path(args.materialized_artifact, candidate_repo)
        if args.materialized_artifact
        else Path(str(candidate_metadata.get("materialized_artifact_path") or candidate_repo / "workspace" / f"newsletter_phase3_curated_sections_{end}.md"))
    )
    validation_result = (
        resolve_path(args.validation_result, candidate_repo)
        if args.validation_result
        else Path(str(candidate_metadata.get("validation_result_path") or candidate_run_dir / "validation" / "phase3_stdout_validation.txt"))
    )

    candidate = row_checks(
        row_name="candidate",
        run_dir=candidate_run_dir,
        repo=candidate_repo,
        stdout_artifact=stdout_artifact,
        materialized_artifact=materialized_artifact,
        validation_result=validation_result,
        end=end,
    )
    no_refetch, no_refetch_errors = no_refetch_checks(admission_path, candidate_repo, end)
    candidate["errors"].extend(no_refetch_errors)
    candidate["passes"] = not candidate["errors"]

    control = None
    control_errors: list[str] = []
    if args.control_run_dir or args.control_repo:
        if not args.control_run_dir or not args.control_repo:
            control_errors.append("control run dir and control repo must be provided together")
        else:
            control_run_dir = Path(args.control_run_dir).expanduser().resolve()
            control_repo = Path(args.control_repo).expanduser().resolve()
            control = row_checks(
                row_name="control",
                run_dir=control_run_dir,
                repo=control_repo,
                stdout_artifact=None,
                materialized_artifact=None,
                validation_result=None,
                end=end,
            )
            if control_run_dir == candidate_run_dir or control_repo == candidate_repo:
                control["errors"].append("control and candidate paths must be distinct")
                control["passes"] = False
            if control["metrics"].get("loaded") and candidate["metrics"].get("loaded"):
                if int(candidate["metrics"].get("request_count") or 0) > int(control["metrics"].get("request_count") or 0):
                    control["errors"].append("candidate request_count is higher than control")
                    control["passes"] = False
    else:
        control_errors.append("single-pair admission requires control run dir and control repo")

    hash_errors: list[str] = []
    if args.expected_prompt_sha256 and candidate["metrics"].get("original_prompt_sha256") != args.expected_prompt_sha256:
        hash_errors.append("candidate original prompt hash does not match expected prompt hash")
    policy_sha = (candidate_metadata.get("prompt_metadata_sha256") or "")
    raw_prompt_metadata = str(candidate_metadata.get("prompt_metadata_path") or "").strip()
    prompt_metadata_path = (
        Path(raw_prompt_metadata)
        if raw_prompt_metadata
        else candidate_run_dir / "prompt-metadata" / "phase3_stdout_no_tools_prompt_metadata.json"
    )
    if prompt_metadata_path.exists() and prompt_metadata_path.is_file():
        prompt_metadata = load_json(prompt_metadata_path)
        policy_sha = str(prompt_metadata.get("policy_sha256") or policy_sha)
    if args.expected_prompt_policy_sha256 and policy_sha != args.expected_prompt_policy_sha256:
        hash_errors.append("candidate prompt policy hash does not match expected policy hash")
    source_pack_sha = str(no_refetch.get("source_pack_sha256") or "")
    if args.expected_source_pack_sha256 and source_pack_sha != args.expected_source_pack_sha256:
        hash_errors.append("selected-source/source pack hash does not match expected source hash")
    comparability_errors = add_comparability_errors(
        control=control,
        candidate=candidate,
        manifest=manifest if isinstance(manifest, dict) else None,
        candidate_metadata=candidate_metadata,
    )

    deltas: dict[str, Any] = {}
    qualification_errors: list[str] = []
    if control and control["metrics"].get("loaded") and candidate["metrics"].get("loaded"):
        control_total_direct_tokens = (
            control["metrics"]["input_tokens"]
            + control["metrics"]["output_tokens"]
            + control["metrics"]["reasoning_tokens"]
        )
        candidate_total_direct_tokens = (
            candidate["metrics"]["input_tokens"]
            + candidate["metrics"]["output_tokens"]
            + candidate["metrics"]["reasoning_tokens"]
        )
        total_direct_token_reduction_pct = (
            ((control_total_direct_tokens - candidate_total_direct_tokens) / control_total_direct_tokens) * 100
            if control_total_direct_tokens
            else None
        )
        deltas = {
            "input_tokens_candidate_minus_control": candidate["metrics"]["input_tokens"] - control["metrics"]["input_tokens"],
            "output_tokens_candidate_minus_control": candidate["metrics"]["output_tokens"] - control["metrics"]["output_tokens"],
            "reasoning_tokens_candidate_minus_control": candidate["metrics"]["reasoning_tokens"] - control["metrics"]["reasoning_tokens"],
            "total_direct_tokens_candidate_minus_control": candidate_total_direct_tokens - control_total_direct_tokens,
            "total_direct_token_reduction_pct": round(total_direct_token_reduction_pct, 4)
            if total_direct_token_reduction_pct is not None
            else None,
            "candidate_total_direct_tokens_at_least_5pct_lower": (
                total_direct_token_reduction_pct is not None and total_direct_token_reduction_pct >= 5.0
            ),
            "request_count_candidate_minus_control": candidate["metrics"]["request_count"] - control["metrics"]["request_count"],
            "tool_calls_candidate_minus_control": candidate["metrics"]["tool_calls"] - control["metrics"]["tool_calls"],
            "candidate_request_count_not_higher": candidate["metrics"]["request_count"] <= control["metrics"]["request_count"],
        }
        if total_direct_token_reduction_pct is None or total_direct_token_reduction_pct < 5.0:
            qualification_errors.append("candidate total direct tokens are not at least 5% lower than control")

    blockers = [
        *candidate["errors"],
        *control_errors,
        *(control["errors"] if control else []),
        *hash_errors,
        *comparability_errors,
        *qualification_errors,
    ]
    admitted = not blockers
    receipt = {
        "schema_version": 1,
        "receipt_type": "artifact_reuse_stdout_no_tools_phase3_pair",
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "slice": {
            "start": (candidate_metadata.get("start") or (manifest or {}).get("start")),
            "end": end,
            "mode": (candidate_metadata.get("mode") or (manifest or {}).get("mode")),
            "model": candidate["metrics"].get("model"),
            "candidate_run_id": candidate_metadata.get("run_id"),
        },
        "fixture": {
            "manifest_path": str(manifest_path) if manifest_path else None,
            "manifest_sha256": sha256_path(manifest_path) if manifest_path and manifest_path.exists() else None,
            "manifest_id": (manifest or {}).get("manifest_id") if isinstance(manifest, dict) else None,
            "source_pack_sha256": source_pack_sha,
        },
        "selected_source_no_refetch": no_refetch,
        "candidate": candidate,
        "control": control,
        "deltas": deltas,
        "expected_hash_checks": {
            "expected_prompt_sha256": args.expected_prompt_sha256 or None,
            "expected_prompt_policy_sha256": args.expected_prompt_policy_sha256 or None,
            "expected_source_pack_sha256": args.expected_source_pack_sha256 or None,
            "errors": hash_errors,
        },
        "admission": {
            "admitted_for_single_live_phase3_pair": admitted,
            "verdict": "admit_single_pair_stdout_no_tools_evidence" if admitted else "blocked_incomplete_evidence",
            "blockers": blockers,
        },
        "non_claims": [
            "This receipt admits at most one bounded Phase 3 control/candidate pair.",
            "It is not production behavior, not a durable savings proof, not a billing claim, and not a cache-savings claim.",
            "Token deltas are direct telemetry inputs only; adoption requires coordinator promotion and live proof.",
        ],
    }
    write_json(output, receipt)
    return 0 if admitted else 2


if __name__ == "__main__":
    raise SystemExit(main())

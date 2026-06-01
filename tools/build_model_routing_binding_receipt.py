#!/usr/bin/env python3
"""Build a fail-closed receipt for requested-vs-actual Copilot model binding."""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Any

from newsletter_experiment_common import DIRECT_PROVIDER_TOKEN_FIELDS, sha256_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build model routing binding receipt")
    parser.add_argument("--model", required=True, help="Requested model name")
    parser.add_argument("--metrics", required=True, help="phase-session-metrics.jsonl path")
    parser.add_argument("--session-log", help="Optional bound session events.jsonl path")
    parser.add_argument("--log", help="Optional Copilot stdout/stderr log path")
    parser.add_argument("--output", required=True, help="Receipt JSON path")
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


def normalize_session_state_paths(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: normalize_session_state_paths(item) for key, item in value.items()}
    if isinstance(value, list):
        return [normalize_session_state_paths(item) for item in value]
    if isinstance(value, str) and "/.copilot/session-state/" in value:
        parts = Path(value).parts
        try:
            index = parts.index("session-state")
        except ValueError:
            return "<copilot-session-state>/" + Path(value).name
        return "<copilot-session-state>/" + "/".join(parts[index + 1 :])
    return value


def load_last_jsonl(path: Path) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            row = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if isinstance(row, dict):
            rows.append(row)
    if not rows:
        raise SystemExit(f"no JSON rows found in metrics: {path}")
    return rows[-1]


def load_events(path: Path | None) -> list[dict[str, Any]]:
    if path is None or not path.exists():
        return []
    rows: list[dict[str, Any]] = []
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            row = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if isinstance(row, dict):
            rows.append(row)
    return rows


def data_for(event: dict[str, Any]) -> dict[str, Any]:
    data = event.get("data")
    return data if isinstance(data, dict) else {}


def session_identity(events: list[dict[str, Any]]) -> dict[str, Any]:
    selected_models: list[str] = []
    current_models: list[str] = []
    model_metrics_keys: list[str] = []
    model_metric_request_counts: dict[str, int] = {}
    for event in events:
        data = data_for(event)
        if event.get("type") == "session.start" and data.get("selectedModel"):
            selected_models.append(str(data.get("selectedModel")))
        if event.get("type") == "session.shutdown":
            if data.get("currentModel"):
                current_models.append(str(data.get("currentModel")))
            metrics = data.get("modelMetrics") if isinstance(data.get("modelMetrics"), dict) else {}
            for model, payload in metrics.items():
                model_metrics_keys.append(str(model))
                requests = payload.get("requests") if isinstance(payload, dict) else {}
                count = requests.get("count", 0) if isinstance(requests, dict) else 0
                try:
                    model_metric_request_counts[str(model)] = int(count or 0)
                except (TypeError, ValueError):
                    model_metric_request_counts[str(model)] = 0
    return {
        "selected_models": selected_models,
        "current_models": current_models,
        "model_metrics_keys": sorted(set(model_metrics_keys)),
        "model_metric_request_counts": model_metric_request_counts,
    }


def session_direct_field_report(events: list[dict[str, Any]]) -> dict[str, Any]:
    model_reports: dict[str, dict[str, Any]] = {}
    for event in events:
        if event.get("type") != "session.shutdown":
            continue
        data = data_for(event)
        metrics = data.get("modelMetrics") if isinstance(data.get("modelMetrics"), dict) else {}
        for model, payload in metrics.items():
            if not isinstance(payload, dict):
                continue
            requests = payload.get("requests") if isinstance(payload.get("requests"), dict) else {}
            try:
                request_count = int(requests.get("count", 0) or 0)
            except (TypeError, ValueError):
                request_count = 0
            if request_count <= 0:
                continue
            usage = payload.get("usage") if isinstance(payload.get("usage"), dict) else {}
            missing = [field for field in DIRECT_PROVIDER_TOKEN_FIELDS if field not in usage]
            model_reports[str(model)] = {
                "request_count": request_count,
                "direct_provider_token_fields_present": [
                    field for field in DIRECT_PROVIDER_TOKEN_FIELDS if field in usage
                ],
                "missing_direct_provider_token_fields": missing,
            }
    return {
        "model_reports": model_reports,
        "complete": bool(model_reports)
        and all(not row["missing_direct_provider_token_fields"] for row in model_reports.values()),
    }


def command_model(metrics_row: dict[str, Any]) -> str | None:
    argv = metrics_row.get("command_argv")
    if not isinstance(argv, list):
        return None
    for index, item in enumerate(argv):
        if item == "--model" and index + 1 < len(argv):
            return str(argv[index + 1])
    return None


def log_has_response(path: Path | None) -> bool | None:
    if path is None:
        return None
    if not path.exists():
        return False
    text = path.read_text(encoding="utf-8", errors="ignore").strip()
    if not text:
        return False
    return any(line.strip() and not line.startswith("[orchestrator]") for line in text.splitlines())


def artifact_hash_checks(
    metrics_row: dict[str, Any],
    *,
    session_log_path: Path | None,
    log_path: Path | None,
) -> dict[str, Any]:
    expected_session_sha = str(metrics_row.get("session_log_sha256") or "").strip()
    expected_log_sha = str(metrics_row.get("log_sha256") or "").strip()
    actual_session_sha = (
        sha256_path(session_log_path) if session_log_path is not None and session_log_path.exists() else None
    )
    actual_log_sha = sha256_path(log_path) if log_path is not None and log_path.exists() else None
    return {
        "expected_session_log_sha256": expected_session_sha or None,
        "actual_session_log_sha256": actual_session_sha,
        "session_log_hash_match": bool(expected_session_sha and actual_session_sha == expected_session_sha),
        "expected_log_sha256": expected_log_sha or None,
        "actual_log_sha256": actual_log_sha,
        "log_hash_match": bool(expected_log_sha and actual_log_sha == expected_log_sha),
    }


def direct_fields_complete(metrics_row: dict[str, Any]) -> bool:
    present = set(metrics_row.get("direct_provider_token_fields_present") or [])
    missing = list(metrics_row.get("missing_direct_provider_token_fields") or [])
    return present == set(DIRECT_PROVIDER_TOKEN_FIELDS) and missing == []


def classify(
    requested_model: str,
    metrics_row: dict[str, Any],
    identity: dict[str, Any],
    session_direct_report: dict[str, Any],
    *,
    response_present: bool | None,
    artifact_checks: dict[str, Any],
) -> tuple[str, list[str], dict[str, Any]]:
    blockers: list[str] = []
    detection = metrics_row.get("session_log_detection")
    detection_status = detection.get("status") if isinstance(detection, dict) else None
    exit_code = metrics_row.get("exit_code")
    token_usage = metrics_row.get("token_usage") if isinstance(metrics_row.get("token_usage"), dict) else {}
    primary_model = token_usage.get("primary_model")
    metric_requested_models = token_usage.get("requested_models") or []
    recorded_model = str(metrics_row.get("model") or "").strip()
    argv_model = command_model(metrics_row)
    selected_models = identity.get("selected_models") or []
    current_models = identity.get("current_models") or []
    model_metrics_keys = identity.get("model_metrics_keys") or []
    request_counts = identity.get("model_metric_request_counts") or {}

    if exit_code != 0:
        blockers.append(f"exit code is {exit_code}")
    if response_present is None:
        blockers.append("copilot log was not provided")
    if response_present is False:
        blockers.append("copilot log has no response output")
    if not artifact_checks.get("session_log_hash_match"):
        blockers.append("provided session log does not match the session_log_sha256 recorded in metrics")
    if not artifact_checks.get("log_hash_match"):
        blockers.append("provided Copilot log does not match the log_sha256 recorded in metrics")
    if detection_status != "bound_candidate":
        blockers.append(f"session detection status is {detection_status}")
    if not direct_fields_complete(metrics_row):
        blockers.append("direct provider token fields are incomplete")
    if not session_direct_report.get("complete"):
        blockers.append("session log direct provider token fields are incomplete")
    if recorded_model != requested_model:
        blockers.append(
            f"metrics row model does not exactly match requested model: metrics={recorded_model or None}, requested={requested_model}"
        )
    if argv_model is not None and argv_model != requested_model:
        blockers.append(
            f"command_argv --model does not exactly match requested model: command={argv_model}, requested={requested_model}"
        )
    if not recorded_model and argv_model is None:
        blockers.append("metrics row does not record a requested model")
    if selected_models != [requested_model]:
        blockers.append(
            f"session selectedModel does not exactly match requested model: selected={selected_models}, requested={requested_model}"
        )
    if current_models != [requested_model]:
        blockers.append(
            f"session shutdown currentModel does not exactly match requested model: current={current_models}, requested={requested_model}"
        )
    positive_metric_models = sorted(model for model, count in request_counts.items() if count > 0)
    if positive_metric_models != [requested_model]:
        blockers.append(
            "modelMetrics request-bearing keys do not exactly match requested model: "
            f"keys={positive_metric_models}, requested={requested_model}"
        )
    if primary_model != requested_model:
        blockers.append(
            f"parsed primary_model does not match requested model: primary={primary_model}, requested={requested_model}"
        )
    if metric_requested_models != [requested_model]:
        blockers.append(
            "parsed requested_models/modelMetrics keys do not exactly match requested model: "
            f"requested_models={metric_requested_models}, requested={requested_model}"
        )

    checks = {
        "exit_zero": exit_code == 0,
        "response_present": response_present,
        "session_log_hash_match": artifact_checks.get("session_log_hash_match") is True,
        "log_hash_match": artifact_checks.get("log_hash_match") is True,
        "bound_session": detection_status == "bound_candidate",
        "direct_fields_complete": direct_fields_complete(metrics_row),
        "session_log_direct_fields_complete": session_direct_report.get("complete") is True,
        "metrics_row_model_match": recorded_model == requested_model,
        "command_argv_model_match": argv_model is None or argv_model == requested_model,
        "selected_model_match": selected_models == [requested_model],
        "current_model_match": current_models == [requested_model],
        "model_metrics_key_match": positive_metric_models == [requested_model],
        "primary_model_match": primary_model == requested_model,
        "parsed_model_metrics_key_match": metric_requested_models == [requested_model],
    }
    if not blockers:
        return "model_binding_admitted", blockers, checks
    if any("does not exactly match requested model" in blocker for blocker in blockers):
        return "model_binding_mismatch", blockers, checks
    return "model_binding_blocked_incomplete_evidence", blockers, checks


def main() -> int:
    args = parse_args()
    metrics_path = Path(args.metrics).expanduser().resolve()
    session_log_path = Path(args.session_log).expanduser().resolve() if args.session_log else None
    log_path = Path(args.log).expanduser().resolve() if args.log else None
    metrics_row = load_last_jsonl(metrics_path)
    events = load_events(session_log_path)
    identity = session_identity(events)
    session_direct_report = session_direct_field_report(events)
    response_present = log_has_response(log_path)
    artifact_checks = artifact_hash_checks(
        metrics_row,
        session_log_path=session_log_path,
        log_path=log_path,
    )
    verdict, blockers, checks = classify(
        args.model,
        metrics_row,
        identity,
        session_direct_report,
        response_present=response_present,
        artifact_checks=artifact_checks,
    )
    receipt = {
        "schema_version": 1,
        "receipt_type": "model_routing_binding",
        "generated_at_utc": utc_now(),
        "requested_model": args.model,
        "verdict": verdict,
        "admitted": verdict == "model_binding_admitted",
        "blockers": blockers,
        "checks": checks,
        "metrics_path": display_path(metrics_path),
        "metrics_sha256": sha256_path(metrics_path),
        "session_log_path": display_path(session_log_path),
        "session_log_sha256": sha256_path(session_log_path) if session_log_path and session_log_path.exists() else None,
        "log_path": display_path(log_path),
        "log_sha256": sha256_path(log_path) if log_path and log_path.exists() else None,
        "artifact_hash_checks": artifact_checks,
        "session_identity": identity,
        "session_direct_field_report": session_direct_report,
        "token_usage": metrics_row.get("token_usage"),
        "session_log_detection": normalize_session_state_paths(metrics_row.get("session_log_detection")),
        "direct_provider_token_fields_present": metrics_row.get("direct_provider_token_fields_present") or [],
        "missing_direct_provider_token_fields": metrics_row.get("missing_direct_provider_token_fields") or [],
        "non_claims": [
            "This receipt proves only requested-vs-actual model binding for one Copilot invocation.",
            "It is not a model recommendation, production adoption, or durable savings claim.",
        ],
    }
    output_path = Path(args.output).expanduser().resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"verdict": verdict, "output": str(output_path)}, sort_keys=True))
    return 0 if verdict == "model_binding_admitted" else 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Run a single Copilot CLI phase with timeout and log capture."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import signal
import shutil
import subprocess
import sys
import time
import uuid
from pathlib import Path

from newsletter_experiment_common import (
    DIRECT_PROVIDER_TOKEN_FIELDS,
    parse_session_metrics,
    sha256_path,
    sha256_text,
)

INVOCATION_MARKER_PREFIX = "newsletter_phase_invocation_id:"
HOMEBREW_COPILOT = Path("/opt/homebrew/bin/copilot")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run one Copilot CLI prompt with timeout")
    parser.add_argument("--agent", default="", help="Optional Copilot agent name")
    parser.add_argument("--model", required=True, help="Copilot model name")
    parser.add_argument(
        "--copilot-bin",
        default=os.environ.get("COPILOT_BIN", "copilot"),
        help="Copilot CLI executable path or name",
    )
    parser.add_argument("--prompt-file", required=True, help="Path to markdown prompt file")
    parser.add_argument("--log", required=True, help="Path to log file")
    parser.add_argument(
        "--stdout-out",
        help="Optional path where raw Copilot stdout should be written separately from stderr",
    )
    parser.add_argument(
        "--expected-response-marker",
        help=(
            "Optional exact marker expected in Copilot stdout. If stdout truncates, "
            "the bound session final assistant message can satisfy the replacement "
            "identity proof."
        ),
    )
    parser.add_argument("--timeout", type=int, default=1800, help="Timeout seconds")
    parser.add_argument("--cwd", default=".", help="Working directory")
    parser.add_argument(
        "--use-copilot-cwd-flag",
        action="store_true",
        help="Also pass -C <cwd> to Copilot instead of relying only on subprocess cwd",
    )
    parser.add_argument("--silent", action="store_true", help="Pass --silent to Copilot")
    parser.add_argument("--output-format", choices=["text", "json"], help="Pass --output-format")
    parser.add_argument(
        "--available-tool",
        action="append",
        default=[],
        help=(
            "Restrict Copilot-visible tools via --available-tools. May be repeated. "
            "This is evidence-only runner plumbing; proof receipts still decide qualification."
        ),
    )
    parser.add_argument(
        "--excluded-tool",
        action="append",
        default=[],
        help="Hide Copilot tools via --excluded-tools. May be repeated.",
    )
    parser.add_argument("--log-level", help="Pass --log-level to Copilot")
    parser.add_argument("--log-dir", help="Pass --log-dir to Copilot")
    parser.add_argument("--name", help="Pass --name to Copilot")
    parser.add_argument(
        "--reasoning-effort",
        choices=["low", "medium", "high", "xhigh"],
        help="Pass --reasoning-effort to Copilot and retain the requested effort in metrics",
    )
    parser.add_argument(
        "--enable-reasoning-summaries",
        action="store_true",
        help="Pass --enable-reasoning-summaries to Copilot when supported",
    )
    parser.add_argument(
        "--session-state-base",
        default=os.environ.get("COPILOT_SESSION_STATE_BASE"),
        help="Test-only override for Copilot session-state directory",
    )
    parser.add_argument("--phase-id", help="Logical phase or boundary receipt id for telemetry")
    parser.add_argument(
        "--session-out",
        help="Optional path where the detected Copilot session events.jsonl should be copied",
    )
    parser.add_argument(
        "--metrics-out",
        help="Optional JSONL file to append one phase telemetry row to",
    )
    parser.add_argument(
        "--require-session-log",
        action="store_true",
        help="Fail the phase when exactly one Copilot session events.jsonl cannot be attributed",
    )
    parser.add_argument(
        "--require-direct-token-fields",
        action="store_true",
        help="Fail when the bound session log lacks direct provider token fields",
    )
    parser.add_argument(
        "--artifact-path",
        action="append",
        default=[],
        help="Logical or repo-relative artifact path produced by this phase",
    )
    parser.add_argument(
        "--receipt-id",
        action="append",
        default=[],
        help="Receipt id expected from this phase",
    )
    return parser.parse_args()


def write_log(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def sha256_file(path: Path) -> str | None:
    if not path.exists():
        return None
    return sha256_path(path)


def resolve_copilot_bin(raw: str) -> str:
    candidate = str(raw or "").strip() or "copilot"
    path = Path(candidate).expanduser()
    if path.is_absolute() or "/" in candidate:
        if path.exists():
            return str(path.resolve())
        return candidate
    resolved = shutil.which(candidate)
    if resolved:
        return str(Path(resolved).resolve())
    if candidate == "copilot" and HOMEBREW_COPILOT.exists():
        return str(HOMEBREW_COPILOT.resolve())
    return candidate


def session_state_base(args: argparse.Namespace) -> Path:
    if args.session_state_base:
        return Path(str(args.session_state_base)).expanduser()
    return Path.home() / ".copilot" / "session-state"


def detect_session_logs(start_epoch: float, end_epoch: float, base: Path) -> list[Path]:
    candidates: list[tuple[float, Path]] = []
    if not base.exists():
        return []
    for path in base.glob("*/events.jsonl"):
        try:
            stat = path.stat()
        except FileNotFoundError:
            continue
        if stat.st_mtime > start_epoch and stat.st_mtime <= end_epoch + 5:
            candidates.append((stat.st_mtime, path.resolve()))
    candidates.sort()
    return [path for _, path in candidates]


def detect_session_log(start_epoch: float, end_epoch: float, base: Path) -> Path | None:
    candidates = detect_session_logs(start_epoch, end_epoch, base)
    if len(candidates) != 1:
        return None
    return candidates[0]


def session_logs_containing_marker(base: Path, marker: str) -> list[Path]:
    matches: list[Path] = []
    if not base.exists() or not marker:
        return matches
    for path in base.glob("*/events.jsonl"):
        try:
            raw = path.read_text(encoding="utf-8")
        except (FileNotFoundError, UnicodeDecodeError):
            continue
        if marker in raw:
            matches.append(path.resolve())
    return sorted(matches)


def build_marker_scan(base: Path, marker: str) -> dict[str, object]:
    matches = session_logs_containing_marker(base, marker)
    return {
        "schema_version": 1,
        "marker": marker,
        "session_state_base": str(base.expanduser()),
        "match_count": len(matches),
        "matching_paths": [str(path) for path in matches],
        "clean": len(matches) == 0,
    }


def iter_session_events(path: Path) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    try:
        raw_lines = path.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError:
        return rows
    for raw in raw_lines:
        raw = raw.strip()
        if not raw:
            continue
        try:
            event = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if isinstance(event, dict):
            rows.append(event)
    return rows


def marker_text(invocation_id: str | None) -> str | None:
    if invocation_id is None:
        return None
    return f"{INVOCATION_MARKER_PREFIX} {invocation_id}"


def session_binding_status(
    path: Path,
    args: argparse.Namespace,
    invocation_id: str | None,
) -> dict[str, object]:
    events = iter_session_events(path)
    expected_cwd = str(Path(args.cwd).expanduser().resolve())
    prompt_marker = marker_text(invocation_id)
    marker_found = False
    agent_found = not bool(args.agent)
    cwd_found = False
    selected_model_found = False
    for event in events:
        data = event.get("data") if isinstance(event.get("data"), dict) else {}
        if prompt_marker and prompt_marker in json.dumps(data, sort_keys=True):
            marker_found = True
        if args.agent and event.get("type") == "subagent.selected" and data.get("agentName") == args.agent:
            agent_found = True
        if event.get("type") == "session.start":
            context = data.get("context") if isinstance(data.get("context"), dict) else {}
            cwd_found = context.get("cwd") == expected_cwd or context.get("gitRoot") == expected_cwd
            selected_model_found = data.get("selectedModel") == args.model
    checks = {
        "invocation_marker": marker_found,
        "agent": agent_found,
        "cwd": cwd_found,
        "selected_model": selected_model_found,
    }
    return {
        "path": str(path),
        "matches": all(checks.values()),
        "checks": checks,
    }


def session_detection_status(
    candidates: list[Path],
    *,
    require_binding: bool = False,
    binding_statuses: list[dict[str, object]] | None = None,
) -> dict[str, object]:
    bound_count = sum(1 for row in binding_statuses or [] if row.get("matches") is True)
    if require_binding:
        if bound_count == 1:
            status = "bound_candidate"
            reason = None
        elif not candidates:
            status = "no_candidates"
            reason = "no Copilot session events.jsonl was modified in the phase window"
        elif bound_count == 0:
            status = "binding_failed"
            reason = "no Copilot session candidate contained the phase invocation marker and expected context"
        else:
            status = "ambiguous_bound_candidates"
            reason = "multiple Copilot session candidates matched the phase invocation marker and expected context"
    elif len(candidates) == 1:
        status = "single_candidate"
        reason = None
    elif not candidates:
        status = "no_candidates"
        reason = "no Copilot session events.jsonl was modified in the phase window"
    else:
        status = "ambiguous_candidates"
        reason = "multiple Copilot session events.jsonl files were modified in the phase window"
    return {
        "status": status,
        "reason": reason,
        "candidate_count": len(candidates),
        "bound_candidate_count": bound_count if require_binding else None,
        "candidate_paths": [str(path) for path in candidates],
        "binding": binding_statuses or [],
    }


def copy_session_log(source: Path | None, destination_text: str | None) -> Path | None:
    if source is None or not destination_text:
        return source
    destination = Path(destination_text).expanduser()
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(source.read_bytes())
    return destination.resolve()


def write_effective_prompt_snapshot(
    original_prompt_path: Path,
    prompt_for_copilot: str,
    log_path: Path,
) -> Path:
    if prompt_for_copilot == original_prompt_path.read_text(encoding="utf-8"):
        return original_prompt_path
    snapshot_path = log_path.with_name(f"{log_path.name}.prompt.md")
    snapshot_path.parent.mkdir(parents=True, exist_ok=True)
    snapshot_path.write_text(prompt_for_copilot, encoding="utf-8")
    return snapshot_path.resolve()


def token_usage_for_session(args: argparse.Namespace, session_log_path: Path | None) -> dict[str, object]:
    session_metrics = (
        parse_session_metrics(session_log_path)
        if session_log_path is not None and session_log_path.exists()
        else None
    )
    return session_metrics or {
        "source": None,
        "primary_model": args.model,
        "model_breakdown": {},
        "requested_models": [],
        "direct_provider_token_fields_present": [],
        "missing_direct_provider_token_fields": [
            "inputTokens",
            "outputTokens",
            "cacheReadTokens",
            "cacheWriteTokens",
            "reasoningTokens",
        ],
    }


def copilot_command(args: argparse.Namespace, prompt_for_copilot: str) -> list[str]:
    cmd = [resolve_copilot_bin(args.copilot_bin)]
    if args.use_copilot_cwd_flag:
        cmd.extend(["-C", str(Path(args.cwd).expanduser().resolve())])
    if args.agent:
        cmd.extend(["--agent", args.agent])
    for tool_filter in args.available_tool:
        cmd.extend(["--available-tools", tool_filter])
    for tool_filter in args.excluded_tool:
        cmd.extend(["--excluded-tools", tool_filter])
    cmd.extend(
        [
            "--model",
            args.model,
            "--allow-all",
            "--deny-tool",
            "agent",
            "--no-ask-user",
            "--stream",
            "off",
        ]
    )
    if args.silent:
        cmd.append("--silent")
    if args.output_format:
        cmd.extend(["--output-format", args.output_format])
    if args.log_level:
        cmd.extend(["--log-level", args.log_level])
    if args.log_dir:
        cmd.extend(["--log-dir", args.log_dir])
    if args.name:
        cmd.extend(["--name", args.name])
    if args.reasoning_effort:
        cmd.extend(["--reasoning-effort", args.reasoning_effort])
    if args.enable_reasoning_summaries:
        cmd.append("--enable-reasoning-summaries")
    cmd.extend(["-p", prompt_for_copilot])
    return cmd


def redacted_command_argv(command: list[str]) -> list[str]:
    redacted: list[str] = []
    skip_next = False
    for index, part in enumerate(command):
        if skip_next:
            skip_next = False
            continue
        redacted.append(part)
        if part in {"-p", "--prompt"} and index + 1 < len(command):
            redacted.append("<prompt>")
            skip_next = True
    return redacted


def _int_token(value: object) -> int:
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return 0


def _direct_fields_complete(missing_fields: object) -> bool:
    return isinstance(missing_fields, list) and len(missing_fields) == 0


def _direct_field_status(usage: dict[str, object]) -> tuple[list[str], list[str]]:
    present = [field for field in DIRECT_PROVIDER_TOKEN_FIELDS if field in usage]
    missing = [field for field in DIRECT_PROVIDER_TOKEN_FIELDS if field not in usage]
    return present, missing


def _has_exact_marker_line(text: str | None, marker: str | None) -> bool:
    if not text or not marker:
        return False
    return any(line.strip() == marker for line in text.splitlines())


def _assistant_message_visible_texts(data: dict[str, object]) -> list[str]:
    texts: list[str] = []
    content = data.get("content")
    if isinstance(content, str):
        texts.append(content)
    elif isinstance(content, list):
        for part in content:
            if isinstance(part, str):
                texts.append(part)
            elif isinstance(part, dict):
                text = part.get("text")
                if isinstance(text, str):
                    texts.append(text)
    message = data.get("message")
    if isinstance(message, str):
        texts.append(message)
    return texts


def provider_token_event_scan(session_log_path: Path | None) -> dict[str, object]:
    if session_log_path is None or not session_log_path.exists():
        return {
            "schema_version": 1,
            "status": "session_log_unavailable",
            "total_event_count": 0,
            "events_with_direct_usage_count": 0,
            "events_with_request_index_count": 0,
            "events_with_turn_index_count": 0,
            "session_shutdown_model_metrics_available": False,
            "event_types_with_direct_usage": [],
        }
    event_type_counts: dict[str, int] = {}
    usage_event_types: set[str] = set()
    usage_count = 0
    request_indexed_count = 0
    turn_indexed_count = 0
    shutdown_model_metrics = False
    for event in iter_session_events(session_log_path):
        event_type = str(event.get("type") or "unknown")
        event_type_counts[event_type] = event_type_counts.get(event_type, 0) + 1
        data = event.get("data") if isinstance(event.get("data"), dict) else {}
        usage = data.get("usage") if isinstance(data.get("usage"), dict) else data.get("tokenUsage")
        if isinstance(usage, dict) and any(field in usage for field in DIRECT_PROVIDER_TOKEN_FIELDS):
            usage_count += 1
            usage_event_types.add(event_type)
            request_index = data.get(
                "requestIndex",
                data.get("request_index", data.get("requestId", data.get("request_id"))),
            )
            if request_index is not None:
                request_indexed_count += 1
            if data.get("turnIndex", data.get("turn_index")) is not None:
                turn_indexed_count += 1
        if event_type == "session.shutdown":
            model_metrics = data.get("modelMetrics")
            shutdown_model_metrics = isinstance(model_metrics, dict) and bool(model_metrics)
    status = (
        "indexed_provider_request_events_available"
        if request_indexed_count
        else "turn_indexed_provider_token_events_only"
        if turn_indexed_count
        else "aggregate_shutdown_only"
        if shutdown_model_metrics
        else "no_direct_provider_token_events"
    )
    return {
        "schema_version": 1,
        "status": status,
        "total_event_count": sum(event_type_counts.values()),
        "event_type_counts": event_type_counts,
        "events_with_direct_usage_count": usage_count,
        "events_with_request_index_count": request_indexed_count,
        "events_with_turn_index_count": turn_indexed_count,
        "session_shutdown_model_metrics_available": shutdown_model_metrics,
        "event_types_with_direct_usage": sorted(usage_event_types),
    }


def provider_token_evidence_policy(
    provider_token_rows: list[dict[str, object]],
    route_lock: dict[str, object],
    event_scan: dict[str, object],
) -> dict[str, object]:
    request_rows = [
        row
        for row in provider_token_rows
        if row.get("telemetry_scope") == "provider_request_event"
    ]
    incomplete_request_rows = [
        row
        for row in request_rows
        if row.get("direct_fields_complete") is not True
    ]
    aggregate_rows = [
        row
        for row in provider_token_rows
        if row.get("telemetry_scope") == "session_shutdown_model_aggregate"
    ]
    incomplete_aggregate_rows = [
        row
        for row in aggregate_rows
        if row.get("direct_fields_complete") is not True
    ]
    if request_rows and not incomplete_request_rows:
        status = "true_request_level_provider_token_rows"
        candidate_or_savings_ready = False
        blocker = (
            "request-level provider-token rows are present, but candidate/savings "
            "measurement still requires later route-level validation"
        )
    elif request_rows:
        status = "request_level_provider_token_rows_incomplete"
        candidate_or_savings_ready = False
        blocker = "indexed provider request events are present but direct token fields are incomplete"
    elif aggregate_rows and route_lock.get("route_id") and not incomplete_aggregate_rows:
        status = "equivalent_route_topology_lock_with_session_shutdown_model_aggregate"
        candidate_or_savings_ready = False
        blocker = (
            "current Copilot session events expose direct provider tokens only through "
            "session.shutdown.modelMetrics, not indexed provider request events"
        )
    elif aggregate_rows:
        status = "aggregate_provider_token_rows_incomplete"
        candidate_or_savings_ready = False
        blocker = "aggregate shutdown provider-token rows are present but direct fields are incomplete"
    else:
        status = "fail_closed_no_provider_token_rows"
        candidate_or_savings_ready = False
        blocker = "no direct provider-token rows were available from the bound session log"
    return {
        "schema_version": 1,
        "status": status,
        "candidate_or_savings_measurement_ready": candidate_or_savings_ready,
        "blocker": blocker,
        "event_scan_status": event_scan.get("status"),
        "route_topology_lock_available": bool(route_lock.get("route_id")),
        "request_level_row_count": len(request_rows),
        "incomplete_request_level_row_count": len(incomplete_request_rows),
        "aggregate_row_count": len(aggregate_rows),
        "incomplete_aggregate_row_count": len(incomplete_aggregate_rows),
    }


def response_marker_identity(
    *,
    expected_marker: str | None,
    stdout_path: Path | None,
    session_log_path: Path | None,
    session_detection: dict[str, object],
) -> dict[str, object]:
    if not expected_marker:
        return {
            "schema_version": 1,
            "status": "not_requested",
            "expected_marker": None,
        }
    stdout_text = None
    if stdout_path is not None and stdout_path.exists():
        stdout_text = stdout_path.read_text(encoding="utf-8", errors="replace")
    stdout_exact = _has_exact_marker_line(stdout_text, expected_marker)
    stdout_prefix_only = False
    if stdout_text and not stdout_exact:
        stripped_lines = [line.strip() for line in stdout_text.splitlines() if line.strip()]
        stdout_prefix_only = any(expected_marker.startswith(line) for line in stripped_lines)

    session_exact = False
    final_event_types: set[str] = set()
    final_assistant_texts: list[str] = []
    if session_log_path is not None and session_log_path.exists():
        for event in iter_session_events(session_log_path):
            event_type = str(event.get("type") or "")
            if event_type.startswith("assistant."):
                final_event_types.add(event_type)
            if event_type == "tool.execution_start":
                final_assistant_texts = []
            if event_type == "assistant.message":
                data = event.get("data") if isinstance(event.get("data"), dict) else {}
                if data.get("toolRequests") or data.get("tool_requests"):
                    final_assistant_texts = []
                else:
                    final_assistant_texts = _assistant_message_visible_texts(data)
        session_exact = any(
            _has_exact_marker_line(text, expected_marker)
            for text in final_assistant_texts
        )
    bound_session = session_detection.get("status") == "bound_candidate"
    replacement_available = bool(session_exact and bound_session)
    if stdout_exact:
        status = "stdout_exact_marker"
    elif replacement_available:
        status = "bound_session_final_message_exact_marker"
    else:
        status = "marker_identity_missing"
    return {
        "schema_version": 1,
        "status": status,
        "expected_marker": expected_marker,
        "stdout_exact_marker_returned": stdout_exact,
        "stdout_prefix_only_observed": stdout_prefix_only,
        "session_final_exact_marker_returned": session_exact,
        "replacement_identity_proof_available": replacement_available,
        "bound_session_required_for_replacement": True,
        "session_detection_status": session_detection.get("status"),
        "assistant_event_types_scanned": sorted(final_event_types),
        "stdout_path": str(stdout_path) if stdout_path else None,
        "stdout_sha256": sha256_file(stdout_path) if stdout_path else None,
    }


def provider_request_rows_from_session_events(
    session_log_path: Path | None,
    *,
    route_id: str,
    fallback_model: str,
) -> list[dict[str, object]]:
    if session_log_path is None or not session_log_path.exists():
        return []
    rows: list[dict[str, object]] = []
    for line_number, event in enumerate(iter_session_events(session_log_path), start=1):
        data = event.get("data") if isinstance(event.get("data"), dict) else {}
        usage = data.get("usage") if isinstance(data.get("usage"), dict) else data.get("tokenUsage")
        if not isinstance(usage, dict):
            continue
        request_index = data.get(
            "requestIndex",
            data.get("request_index", data.get("requestId", data.get("request_id"))),
        )
        turn_index = data.get("turnIndex", data.get("turn_index"))
        if request_index is None:
            continue
        present, missing = _direct_field_status(usage)
        row = {
            "schema_version": 1,
            "telemetry_scope": "provider_request_event",
            "route_id": route_id,
            "request_index": request_index,
            "turn_index": turn_index,
            "model": data.get("model") or data.get("currentModel") or fallback_model,
            "input_tokens": _int_token(usage.get("inputTokens")),
            "output_tokens": _int_token(usage.get("outputTokens")),
            "cache_read_tokens": _int_token(usage.get("cacheReadTokens")),
            "cache_write_tokens": _int_token(usage.get("cacheWriteTokens")),
            "reasoning_tokens": _int_token(usage.get("reasoningTokens")),
            "request_count": _int_token(data.get("requestCount") or 1),
            "direct_provider_token_fields_present": present,
            "missing_direct_provider_token_fields": missing,
            "direct_fields_complete": _direct_fields_complete(missing),
            "source_event_type": event.get("type"),
            "source_line_number": line_number,
        }
        row["cached_tokens_total"] = row["cache_read_tokens"] + row["cache_write_tokens"]
        rows.append(row)
    return rows


def aggregate_provider_token_rows(
    token_usage: dict[str, object],
    *,
    route_id: str,
    fallback_model: str,
) -> list[dict[str, object]]:
    if token_usage.get("source") != "session.shutdown.modelMetrics":
        return []
    model_breakdown = (
        token_usage.get("model_breakdown")
        if isinstance(token_usage.get("model_breakdown"), dict)
        else {}
    )
    if not model_breakdown:
        return []
    rows: list[dict[str, object]] = []
    for model, payload in model_breakdown.items():
        usage = payload if isinstance(payload, dict) else {}
        present = usage.get("direct_provider_token_fields_present")
        missing = usage.get("missing_direct_provider_token_fields")
        if not isinstance(present, list) or not isinstance(missing, list):
            present, missing = _direct_field_status(
                {
                    raw: usage.get(normalized)
                    for raw, normalized in DIRECT_PROVIDER_TOKEN_FIELDS.items()
                    if usage.get(normalized) is not None
                }
            )
        row = {
            "schema_version": 1,
            "telemetry_scope": "session_shutdown_model_aggregate",
            "route_id": route_id,
            "request_index": None,
            "turn_index": None,
            "model": str(model),
            "input_tokens": _int_token(usage.get("input_tokens")),
            "output_tokens": _int_token(usage.get("output_tokens")),
            "cache_read_tokens": _int_token(usage.get("cache_read_tokens")),
            "cache_write_tokens": _int_token(usage.get("cache_write_tokens")),
            "reasoning_tokens": _int_token(usage.get("reasoning_tokens")),
            "request_count": _int_token(usage.get("request_count")),
            "direct_provider_token_fields_present": present,
            "missing_direct_provider_token_fields": missing,
            "direct_fields_complete": _direct_fields_complete(missing),
            "source_event_type": "session.shutdown",
        }
        row["cached_tokens_total"] = row["cache_read_tokens"] + row["cache_write_tokens"]
        rows.append(row)
    return rows


def build_provider_token_rows(
    session_log_path: Path | None,
    token_usage: dict[str, object],
    *,
    route_id: str,
    fallback_model: str,
) -> list[dict[str, object]]:
    request_rows = provider_request_rows_from_session_events(
        session_log_path,
        route_id=route_id,
        fallback_model=fallback_model,
    )
    if request_rows:
        return request_rows
    return aggregate_provider_token_rows(
        token_usage,
        route_id=route_id,
        fallback_model=fallback_model,
    )


def quality_gate_state(returncode: int, session_detection: dict[str, object], token_usage: dict[str, object]) -> str:
    status = session_detection.get("status")
    if status == "preexisting_invocation_marker":
        return "phase_prelaunch_session_log_preexisting_invocation_marker"
    if status == "bound_candidate_before_child_launch":
        return "phase_exit_zero_session_log_bound_candidate_before_child_launch"
    if returncode != 0:
        return "phase_execution_failed"
    if status in {
        "no_candidates",
        "binding_failed",
        "ambiguous_bound_candidates",
        "ambiguous_candidates",
    }:
        return f"phase_exit_zero_session_log_{status}"
    missing = token_usage.get("missing_direct_provider_token_fields", [])
    if missing:
        return "phase_exit_zero_direct_fields_incomplete"
    return "phase_exit_zero_direct_fields_complete_pending_orchestrator_artifact_gate"


def route_lock_for_phase(
    args: argparse.Namespace,
    *,
    effective_prompt_path: Path,
    token_usage: dict[str, object],
    command_argv: list[str],
    returncode: int,
    session_detection: dict[str, object],
) -> dict[str, object]:
    rendered_prompt_sha256 = sha256_file(effective_prompt_path)
    original_prompt_sha256 = sha256_file(Path(args.prompt_file))
    route_seed = {
        "agent": args.agent,
        "artifact_paths": args.artifact_path,
        "available_tools": args.available_tool,
        "command_surface": "copilot_cli_phase",
        "cwd": str(Path(args.cwd).expanduser().resolve()),
        "excluded_tools": args.excluded_tool,
        "model": args.model,
        "original_prompt_sha256": original_prompt_sha256,
        "phase_id": args.phase_id,
        "receipt_ids": args.receipt_id,
        "reasoning_effort": args.reasoning_effort,
        "rendered_prompt_sha256": rendered_prompt_sha256,
    }
    frozen_manifest_sha256 = sha256_text(
        json.dumps(route_seed, sort_keys=True, separators=(",", ":"))
    )
    route_id = sha256_text(
        json.dumps(
            {
                "command_surface": "copilot_cli_phase",
                "model": args.model,
                "phase_id": args.phase_id,
                "rendered_prompt_sha256": rendered_prompt_sha256,
                "frozen_pre_render_input_manifest_sha256": frozen_manifest_sha256,
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    direct_missing = token_usage.get("missing_direct_provider_token_fields", [])
    return {
        "schema_version": 1,
        "status": "route_topology_lock",
        "route_id": route_id,
        "route_command_argv": redacted_command_argv(command_argv),
        "model": args.model,
        "agent": args.agent,
        "command_surface": "copilot_cli_phase",
        "original_prompt_sha256": original_prompt_sha256,
        "rendered_prompt_sha256": rendered_prompt_sha256,
        "rendered_prompt_normalization_policy": (
            "rendered prompt equals original prompt except when --require-session-log "
            "appends an invocation marker for session attribution"
        ),
        "frozen_pre_render_input_manifest": route_seed,
        "frozen_pre_render_input_manifest_sha256": frozen_manifest_sha256,
        "quality_gate_state": quality_gate_state(returncode, session_detection, token_usage),
        "request_count": token_usage.get("request_count"),
        "tool_calls": token_usage.get("tool_calls"),
        "direct_fields_complete": _direct_fields_complete(direct_missing),
        "missing_direct_provider_token_fields": direct_missing,
    }


def append_metrics_row(
    args: argparse.Namespace,
    *,
    started_at_utc: str,
    ended_at_utc: str,
    start_epoch: float,
    end_epoch: float,
    returncode: int,
    session_log_path: Path | None,
    session_detection: dict[str, object],
    effective_prompt_path: Path,
    token_usage: dict[str, object],
    command_argv: list[str],
    telemetry_provenance: dict[str, object] | None = None,
) -> None:
    if not args.metrics_out:
        return
    prompt_path = Path(args.prompt_file)
    log_path = Path(args.log)
    route_lock = route_lock_for_phase(
        args,
        effective_prompt_path=effective_prompt_path,
        token_usage=token_usage,
        command_argv=command_argv,
        returncode=returncode,
        session_detection=session_detection,
    )
    provider_token_rows = build_provider_token_rows(
        session_log_path,
        token_usage,
        route_id=str(route_lock["route_id"]),
        fallback_model=args.model,
    )
    provider_event_scan = provider_token_event_scan(session_log_path)
    provider_evidence_policy = provider_token_evidence_policy(
        provider_token_rows,
        route_lock,
        provider_event_scan,
    )
    marker_identity = response_marker_identity(
        expected_marker=getattr(args, "expected_response_marker", None),
        stdout_path=Path(args.stdout_out).expanduser()
        if getattr(args, "stdout_out", None)
        else None,
        session_log_path=session_log_path,
        session_detection=session_detection,
    )
    request_level_rows_available = any(
        row.get("telemetry_scope") == "provider_request_event"
        for row in provider_token_rows
    )
    first_turn_rows_available = any(
        row.get("turn_index") in {0, 1, "0", "1"}
        for row in provider_token_rows
    )
    token_row_fallback_reason = None
    if not request_level_rows_available and provider_token_rows:
        token_row_fallback_reason = (
            "copilot_session_events_expose_shutdown_modelMetrics_not_request_token_events"
        )
    elif not provider_token_rows:
        token_row_fallback_reason = "provider_token_rows_unavailable_no_session_shutdown_modelMetrics"
    row = {
        "schema_version": 1,
        "phase_id": args.phase_id,
        "route_id": route_lock["route_id"],
        "agent": args.agent,
        "model": args.model,
        "reasoning_effort": args.reasoning_effort,
        "reasoning_summaries_enabled": bool(args.enable_reasoning_summaries),
        "command_surface": "copilot_cli_phase",
        "copilot_bin": resolve_copilot_bin(args.copilot_bin),
        "tool_filters": {
            "available_tools": args.available_tool,
            "excluded_tools": args.excluded_tool,
        },
        "command_argv": redacted_command_argv(command_argv),
        "route_command_argv": route_lock["route_command_argv"],
        "started_at_utc": started_at_utc,
        "ended_at_utc": ended_at_utc,
        "start_epoch": start_epoch,
        "end_epoch": end_epoch,
        "duration_seconds": round(end_epoch - start_epoch, 3),
        "exit_code": returncode,
        "prompt_path": str(effective_prompt_path.resolve()),
        "prompt_sha256": sha256_file(effective_prompt_path),
        "rendered_prompt_sha256": route_lock["rendered_prompt_sha256"],
        "original_prompt_path": str(prompt_path.resolve()),
        "original_prompt_sha256": sha256_file(prompt_path),
        "rendered_prompt_normalization_policy": route_lock[
            "rendered_prompt_normalization_policy"
        ],
        "frozen_pre_render_input_manifest_sha256": route_lock[
            "frozen_pre_render_input_manifest_sha256"
        ],
        "prompt_binding_marker_included": args.require_session_log,
        "telemetry_provenance": telemetry_provenance or {},
        "log_path": str(log_path.resolve()),
        "log_sha256": sha256_file(log_path),
        "session_log_path": str(session_log_path) if session_log_path else None,
        "session_log_sha256": sha256_file(session_log_path) if session_log_path else None,
        "session_log_detection": session_detection,
        "artifact_paths": args.artifact_path,
        "receipt_ids": args.receipt_id,
        "token_usage": token_usage,
        "provider_token_rows": provider_token_rows,
        "provider_token_telemetry": {
            "schema_version": 1,
            "route_id": route_lock["route_id"],
            "row_count": len(provider_token_rows),
            "telemetry_scopes": sorted(
                {
                    str(row.get("telemetry_scope"))
                    for row in provider_token_rows
                    if row.get("telemetry_scope")
                }
            ),
            "request_level_rows_available": request_level_rows_available,
            "first_turn_rows_available": first_turn_rows_available,
            "equivalent_route_topology_lock_available": bool(route_lock["route_id"]),
            "fallback_reason": token_row_fallback_reason,
            "event_scan": provider_event_scan,
            "evidence_policy": provider_evidence_policy,
        },
        "response_marker_identity": marker_identity,
        "route_topology_lock": route_lock,
        "direct_provider_token_fields_present": token_usage.get(
            "direct_provider_token_fields_present", []
        ),
        "missing_direct_provider_token_fields": token_usage.get(
            "missing_direct_provider_token_fields", []
        ),
        "direct_fields_complete": route_lock["direct_fields_complete"],
        "quality_gate_state": route_lock["quality_gate_state"],
        "input_tokens": token_usage.get("input_tokens"),
        "output_tokens": token_usage.get("output_tokens"),
        "cache_read_tokens": token_usage.get("cache_read_tokens"),
        "cache_write_tokens": token_usage.get("cache_write_tokens"),
        "cached_tokens_total": token_usage.get("cached_tokens_total"),
        "reasoning_tokens": token_usage.get("reasoning_tokens"),
        "request_count": token_usage.get("request_count"),
        "tool_calls": token_usage.get("tool_calls"),
        "primary_model": token_usage.get("primary_model"),
        "non_claims": [
            "This row is per-phase telemetry for a Copilot CLI phase invocation.",
            "It is not by itself a production adoption or savings claim.",
        ],
    }
    metrics_path = Path(args.metrics_out).expanduser()
    metrics_path.parent.mkdir(parents=True, exist_ok=True)
    with metrics_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(row, sort_keys=True) + "\n")


def _to_text(value: object) -> str:
    # Defensive conversion: timeout exceptions can carry non-str values.
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return str(value)


def run_phase(args: argparse.Namespace) -> int:
    prompt_path = Path(args.prompt_file)
    if not prompt_path.exists():
        print(f"ERROR: prompt file not found: {prompt_path}", file=sys.stderr)
        return 2
    if args.expected_response_marker and not args.stdout_out:
        args.stdout_out = str(Path(args.log).with_name(f"{Path(args.log).name}.stdout"))
    if args.stdout_out:
        write_log(Path(args.stdout_out), "")

    prompt = prompt_path.read_text(encoding="utf-8")
    invocation_id = uuid.uuid4().hex if args.require_session_log else None
    prompt_marker = marker_text(invocation_id)
    prompt_for_copilot = prompt
    if invocation_id is not None:
        prompt_for_copilot = (
            f"{prompt.rstrip()}\n\n<!-- {prompt_marker} -->\n"
        )
    effective_prompt_path = write_effective_prompt_snapshot(
        prompt_path,
        prompt_for_copilot,
        Path(args.log),
    )
    cmd = copilot_command(args, prompt_for_copilot)

    state_base = session_state_base(args)
    pre_launch_marker_scan = (
        build_marker_scan(state_base, str(prompt_marker))
        if prompt_marker is not None
        else {
            "schema_version": 1,
            "marker": None,
            "session_state_base": str(state_base.expanduser()),
            "match_count": 0,
            "matching_paths": [],
            "clean": True,
        }
    )
    start_epoch = time.time()
    started_at_utc = dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    returncode = 1
    session_log_path: Path | None = None
    child_process_provenance: dict[str, object] = {
        "pid": None,
        "pgid": None,
        "started_at_utc": None,
        "ended_at_utc": None,
        "start_epoch": None,
        "end_epoch": None,
        "returncode": None,
        "timeout_kill_attempted": False,
    }
    telemetry_provenance: dict[str, object] = {
        "schema_version": 1,
        "invocation_id": invocation_id,
        "invocation_marker": prompt_marker,
        "pre_launch_marker_scan": pre_launch_marker_scan,
        "child_process": child_process_provenance,
    }

    if args.require_session_log and not pre_launch_marker_scan.get("clean", False):
        returncode = 2
        end_epoch = time.time()
        ended_at_utc = dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        child_process_provenance["end_epoch"] = None
        child_process_provenance["ended_at_utc"] = None
        child_process_provenance["returncode"] = None
        session_detection = {
            "status": "preexisting_invocation_marker",
            "reason": "phase invocation marker was present before launching Copilot",
            "candidate_count": 0,
            "bound_candidate_count": 0,
            "candidate_paths": [],
            "binding": [],
        }
        telemetry_provenance.update(
            {
                "post_launch_session_candidate_count": 0,
                "post_launch_bound_candidate_count": 0,
                "exactly_one_post_launch_bound_session_candidate": False,
            }
        )
        message = (
            "[orchestrator] PREEXISTING_INVOCATION_MARKER: "
            "phase invocation marker was present before launching Copilot\n"
        )
        write_log(Path(args.log), message)
        print(message, end="")
        token_usage = token_usage_for_session(args, None)
        append_metrics_row(
            args,
            started_at_utc=started_at_utc,
            ended_at_utc=ended_at_utc,
            start_epoch=start_epoch,
            end_epoch=end_epoch,
            returncode=returncode,
            session_log_path=None,
            session_detection=session_detection,
            effective_prompt_path=effective_prompt_path,
            token_usage=token_usage,
            command_argv=cmd,
            telemetry_provenance=telemetry_provenance,
        )
        return returncode

    try:
        child_process_provenance["start_epoch"] = time.time()
        child_process_provenance["started_at_utc"] = dt.datetime.now(
            tz=dt.timezone.utc
        ).strftime("%Y-%m-%dT%H:%M:%SZ")
        process = subprocess.Popen(
            cmd,
            cwd=args.cwd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            start_new_session=True,
        )
        child_process_provenance["pid"] = process.pid
        try:
            child_process_provenance["pgid"] = os.getpgid(process.pid)
        except OSError:
            child_process_provenance["pgid"] = None
        stdout_raw, stderr_raw = process.communicate(timeout=args.timeout)
        child_process_provenance["returncode"] = process.returncode
        stdout_text = _to_text(stdout_raw)
        stderr_text = _to_text(stderr_raw)
        if args.stdout_out:
            write_log(Path(args.stdout_out), stdout_text)
        combined = stdout_text + stderr_text
        if process.returncode != 0 and not combined.strip():
            combined = (
                f"[orchestrator] COPILOT_EXITED_WITHOUT_OUTPUT: "
                f"copilot returned {process.returncode} with empty stdout/stderr\n"
            )
        write_log(Path(args.log), combined)
        if combined:
            print(combined, end="")
        returncode = int(process.returncode or 0)
    except subprocess.TimeoutExpired as exc:
        child_process_provenance["timeout_kill_attempted"] = True
        pgid = child_process_provenance.get("pgid")
        if isinstance(pgid, int):
            try:
                os.killpg(pgid, signal.SIGKILL)
            except OSError:
                process.kill()
        else:
            process.kill()
        timeout_stdout, timeout_stderr = process.communicate()
        if args.stdout_out:
            write_log(
                Path(args.stdout_out),
                _to_text(exc.stdout) or _to_text(timeout_stdout),
            )
        combined = _to_text(exc.stdout) + _to_text(exc.stderr)
        if not combined:
            combined = _to_text(timeout_stdout) + _to_text(timeout_stderr)
        combined += f"\n[orchestrator] TIMEOUT after {args.timeout}s\n"
        write_log(Path(args.log), combined)
        if combined:
            print(combined, end="")
        returncode = 124
        child_process_provenance["returncode"] = returncode
    except OSError as exc:
        combined = f"[orchestrator] COPILOT_LAUNCH_FAILED: {exc}\n"
        write_log(Path(args.log), combined)
        print(combined, end="")
        returncode = 127
        child_process_provenance["returncode"] = returncode
    finally:
        child_process_provenance["end_epoch"] = time.time()
        child_process_provenance["ended_at_utc"] = dt.datetime.now(
            tz=dt.timezone.utc
        ).strftime("%Y-%m-%dT%H:%M:%SZ")
        end_epoch = time.time()
        ended_at_utc = dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        candidates = detect_session_logs(start_epoch, end_epoch, state_base)
        binding_statuses = (
            [
                session_binding_status(candidate, args, invocation_id)
                for candidate in candidates
            ]
            if args.require_session_log
            else []
        )
        session_detection = session_detection_status(
            candidates,
            require_binding=args.require_session_log,
            binding_statuses=binding_statuses,
        )
        telemetry_provenance.update(
            {
                "post_launch_session_candidate_count": len(candidates),
                "post_launch_bound_candidate_count": session_detection.get(
                    "bound_candidate_count"
                ),
                "exactly_one_post_launch_bound_session_candidate": session_detection.get(
                    "status"
                )
                == "bound_candidate",
            }
        )
        if args.require_session_log:
            bound_candidates = [
                candidate
                for candidate, binding in zip(candidates, binding_statuses)
                if binding.get("matches") is True
            ]
            detected = bound_candidates[0] if len(bound_candidates) == 1 else None
            child_start_epoch = child_process_provenance.get("start_epoch")
            if detected is not None and isinstance(child_start_epoch, (int, float)):
                try:
                    selected_mtime = detected.stat().st_mtime
                except FileNotFoundError:
                    selected_mtime = None
                if selected_mtime is not None and selected_mtime < float(child_start_epoch):
                    session_detection = {
                        **session_detection,
                        "status": "bound_candidate_before_child_launch",
                        "reason": "bound Copilot session log timestamp predates child launch",
                        "selected_session_mtime_epoch": selected_mtime,
                    }
                    detected = None
                    telemetry_provenance[
                        "exactly_one_post_launch_bound_session_candidate"
                    ] = False
        else:
            detected = candidates[0] if len(candidates) == 1 else None
        source_session_log_path = detected
        source_session_log_sha256 = sha256_file(source_session_log_path) if source_session_log_path else None
        session_log_path = copy_session_log(detected, args.session_out)
        telemetry_provenance.update(
            {
                "source_session_log_path": str(source_session_log_path)
                if source_session_log_path
                else None,
                "source_session_log_sha256": source_session_log_sha256,
                "copied_session_log_path": str(session_log_path) if session_log_path else None,
                "copied_session_log_sha256": sha256_file(session_log_path)
                if session_log_path
                else None,
                "copied_session_hash_matches_source": (
                    source_session_log_sha256 == sha256_file(session_log_path)
                    if source_session_log_sha256 and session_log_path
                    else None
                ),
                "prompt_snapshot_sha256": sha256_file(effective_prompt_path),
            }
        )
        if args.require_session_log and detected is None:
            reason = session_detection.get("reason") or "session log attribution failed"
            message = f"\n[orchestrator] SESSION_LOG_ATTRIBUTION_FAILED: {reason}\n"
            log_path = Path(args.log)
            log_path.parent.mkdir(parents=True, exist_ok=True)
            with log_path.open("a", encoding="utf-8") as handle:
                handle.write(message)
            print(message, end="")
            if returncode == 0:
                returncode = 2
        token_usage = token_usage_for_session(args, session_log_path)
        missing_direct_fields = list(token_usage.get("missing_direct_provider_token_fields", []))
        if args.require_direct_token_fields and missing_direct_fields:
            message = (
                "\n[orchestrator] DIRECT_TOKEN_FIELDS_MISSING: "
                + ", ".join(str(field) for field in missing_direct_fields)
                + "\n"
            )
            log_path = Path(args.log)
            log_path.parent.mkdir(parents=True, exist_ok=True)
            with log_path.open("a", encoding="utf-8") as handle:
                handle.write(message)
            print(message, end="")
            if returncode == 0:
                returncode = 3
        telemetry_provenance["stdout_stderr_log_sha256"] = sha256_file(Path(args.log))
        append_metrics_row(
            args,
            started_at_utc=started_at_utc,
            ended_at_utc=ended_at_utc,
            start_epoch=start_epoch,
            end_epoch=end_epoch,
            returncode=returncode,
            session_log_path=session_log_path,
            session_detection=session_detection,
            effective_prompt_path=effective_prompt_path,
            token_usage=token_usage,
            command_argv=cmd,
            telemetry_provenance=telemetry_provenance,
        )
    return returncode


def main() -> int:
    args = parse_args()
    if args.require_direct_token_fields:
        args.require_session_log = True
    return run_phase(args)


if __name__ == "__main__":
    raise SystemExit(main())

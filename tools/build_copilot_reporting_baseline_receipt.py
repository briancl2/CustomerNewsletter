#!/usr/bin/env python3
"""Build the Burst-46 frozen Copilot CLI reporting baseline receipt."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


REQUIRED_SMOKES = (
    "json_output_smoke",
    "reasoning_effort_low_smoke",
    "reasoning_effort_medium_smoke",
    "reasoning_effort_high_smoke",
    "reasoning_summaries_smoke",
    "log_dir_name_smoke",
    "otel_file_export_smoke",
)
DIRECT_FIELDS = ("input_tokens", "output_tokens", "reasoning_tokens")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metrics", required=True, type=Path)
    parser.add_argument("--copilot-bin", required=True, type=Path)
    parser.add_argument("--version-output", required=True, type=Path)
    parser.add_argument("--help-output", required=True, type=Path)
    parser.add_argument("--update-help-output", type=Path)
    parser.add_argument("--otel-file", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def sha256_path(path: Path | None) -> str | None:
    if path is None or not path.exists():
        return None
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(errors="replace")


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


def parse_otel_file(path: Path | None) -> dict[str, Any]:
    if path is None:
        return {"status": "not_requested", "path": None, "parseable_records": 0, "blockers": []}
    if not path.exists():
        return {
            "status": "missing",
            "path": str(path),
            "parseable_records": 0,
            "blockers": ["otel_file_missing"],
        }
    parseable = 0
    blockers: list[str] = []
    with path.open(errors="replace") as handle:
        for line_no, line in enumerate(handle, start=1):
            stripped = line.strip()
            if not stripped:
                continue
            try:
                json.loads(stripped)
                parseable += 1
            except json.JSONDecodeError:
                blockers.append(f"line_{line_no}_not_json")
    if parseable == 0:
        blockers.append("otel_file_has_no_parseable_json_records")
    return {
        "status": "parseable" if not blockers else "blocked",
        "path": str(path),
        "sha256": sha256_path(path),
        "parseable_records": parseable,
        "blockers": blockers,
    }


def argv(row: dict[str, Any]) -> list[str]:
    raw = row.get("command_argv") or []
    return [str(item) for item in raw]


def has_direct_fields(row: dict[str, Any]) -> bool:
    if row.get("direct_token_missing_fields") or row.get("missing_direct_provider_token_fields"):
        return False
    return all(row.get(field) is not None for field in DIRECT_FIELDS)


def smoke_status(phase_id: str, row: dict[str, Any] | None) -> dict[str, Any]:
    if row is None:
        return {"phase_id": phase_id, "status": "missing", "blockers": ["missing_smoke_row"]}
    blockers: list[str] = []
    command = argv(row)
    detection = row.get("session_log_detection") if isinstance(row.get("session_log_detection"), dict) else {}
    session_status = row.get("session_status") or detection.get("status")
    if row.get("exit_code") != 0:
        blockers.append("nonzero_exit")
    if session_status != "bound_candidate":
        blockers.append("session_not_bound_candidate")
    if not has_direct_fields(row):
        blockers.append("missing_direct_token_fields")
    if row.get("model") in (None, ""):
        blockers.append("missing_model_binding")
    if phase_id == "json_output_smoke" and "--output-format" not in command:
        blockers.append("json_output_flag_not_forwarded")
    if phase_id.startswith("reasoning_effort_"):
        requested = phase_id.replace("reasoning_effort_", "").replace("_smoke", "")
        if "--reasoning-effort" not in command and "--effort" not in command:
            blockers.append("reasoning_effort_flag_not_forwarded")
        if requested not in command and row.get("reasoning_effort") != requested:
            blockers.append("reasoning_effort_value_not_bound")
    if phase_id == "reasoning_summaries_smoke" and "--enable-reasoning-summaries" not in command:
        blockers.append("reasoning_summaries_flag_not_forwarded")
    if phase_id == "log_dir_name_smoke":
        if "--log-dir" not in command:
            blockers.append("log_dir_flag_not_forwarded")
        if "--name" not in command:
            blockers.append("name_flag_not_forwarded")
    return {
        "phase_id": phase_id,
        "status": "pass" if not blockers else "blocked",
        "blockers": blockers,
        "model": row.get("model"),
        "reasoning_effort": row.get("reasoning_effort"),
        "token_fields": {
            "input_tokens": row.get("input_tokens"),
            "output_tokens": row.get("output_tokens"),
            "reasoning_tokens": row.get("reasoning_tokens"),
            "cache_read_tokens": row.get("cache_read_tokens"),
            "cache_write_tokens": row.get("cache_write_tokens"),
        },
        "request_count": row.get("request_count"),
        "tool_calls": row.get("tool_calls"),
        "session_status": session_status,
        "command_contains": {
            "output_format": "--output-format" in command,
            "reasoning_effort": "--reasoning-effort" in command or "--effort" in command,
            "reasoning_summaries": "--enable-reasoning-summaries" in command,
            "log_dir": "--log-dir" in command,
            "name": "--name" in command,
        },
    }


def main() -> int:
    args = parse_args()
    metrics_rows = load_metrics(args.metrics) if args.metrics.exists() else []
    by_phase = {str(row.get("phase_id")): row for row in metrics_rows}
    statuses = {phase: smoke_status(phase, by_phase.get(phase)) for phase in REQUIRED_SMOKES}

    help_text = read_text(args.help_output)
    version_text = read_text(args.version_output).strip()
    version_match = re.search(r"(\d+\.\d+\.\d+)", version_text)
    flag_support = {
        "output_format": "--output-format" in help_text,
        "reasoning_effort": "--reasoning-effort" in help_text or "--effort" in help_text,
        "reasoning_summaries": "--enable-reasoning-summaries" in help_text,
        "log_dir": "--log-dir" in help_text,
        "name": "--name" in help_text,
    }
    flag_blockers = [
        f"help_missing_{flag}" for flag, supported in flag_support.items() if not supported
    ]
    smoke_blockers = [
        f"{phase}:{blocker}"
        for phase, status in statuses.items()
        for blocker in status.get("blockers", [])
    ]
    otel_status = parse_otel_file(args.otel_file)
    blockers = flag_blockers + smoke_blockers
    if otel_status["status"] != "parseable":
        blockers.extend(f"otel:{blocker}" for blocker in otel_status.get("blockers", []))

    non_otel_blockers = [blocker for blocker in blockers if not blocker.startswith("otel:")]
    if not blockers:
        verdict = "reporting_baseline_pass"
    elif not non_otel_blockers:
        verdict = "reporting_baseline_partial_otel_blocked"
    else:
        verdict = "reporting_baseline_fail_closed"

    receipt = {
        "schema": "copilot-reporting-baseline-receipt.v1",
        "verdict": verdict,
        "copilot_binary": {
            "path": str(args.copilot_bin),
            "exists": args.copilot_bin.exists(),
            "sha256": sha256_path(args.copilot_bin),
            "version_output": version_text,
            "version": version_match.group(1) if version_match else None,
            "help_output_path": str(args.help_output),
            "help_output_sha256": sha256_path(args.help_output),
            "update_help_output_path": str(args.update_help_output)
            if args.update_help_output
            else None,
            "update_help_output_sha256": sha256_path(args.update_help_output),
            "in_place_update_run": False,
        },
        "flag_support": flag_support,
        "smoke_status": statuses,
        "otel_file_export": otel_status,
        "observable_fields": {
            "model": all(status.get("model") for status in statuses.values()),
            "reasoning_effort_requested": all(
                statuses[phase].get("status") == "pass"
                for phase in (
                    "reasoning_effort_low_smoke",
                    "reasoning_effort_medium_smoke",
                    "reasoning_effort_high_smoke",
                )
            ),
            "direct_tokens": all(
                not any(
                    blocker == "missing_direct_token_fields"
                    for blocker in status.get("blockers", [])
                )
                for status in statuses.values()
            ),
            "request_count": all(
                statuses[phase].get("request_count") is not None for phase in statuses
            ),
            "tool_calls": all(statuses[phase].get("tool_calls") is not None for phase in statuses),
            "session_binding": all(
                statuses[phase].get("session_status") == "bound_candidate" for phase in statuses
            ),
            "api_equivalent_cost": False,
            "duration": True,
        },
        "metrics_path": str(args.metrics),
        "metrics_sha256": sha256_path(args.metrics),
        "blockers": blockers,
        "non_claims": [
            "not_a_model_recommendation",
            "not_a_fleet_adoption_receipt",
            "not_github_copilot_billing_proof",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    return 0 if verdict in {"reporting_baseline_pass", "reporting_baseline_partial_otel_blocked"} else 2


if __name__ == "__main__":
    raise SystemExit(main())

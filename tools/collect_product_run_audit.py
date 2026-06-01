#!/usr/bin/env python3
"""Collect retained product-run audit artifacts for benchmark or production runs."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import shutil
import subprocess
import sys
from collections import Counter
from pathlib import Path
from typing import Any

from product_run_common import receipt_phase_logical_paths, resolved_artifact_map


def run_cmd(cmd: list[str], cwd: Path) -> dict[str, Any]:
    completed = subprocess.run(
        cmd,
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )
    return {
        "cmd": cmd,
        "returncode": completed.returncode,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
    }


def safe_version(binary: str) -> dict[str, Any]:
    path = shutil.which(binary)
    if not path:
        return {"path": None, "version": None}
    result = subprocess.run([path, "--version"], text=True, capture_output=True, check=False)
    version_line = (result.stdout or result.stderr).strip().splitlines()
    return {
        "path": path,
        "version": version_line[0] if version_line else None,
    }


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.rstrip() + "\n", encoding="utf-8")


def load_json(path: Path | None) -> dict[str, Any] | None:
    if path is None or not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def session_tool_name(payload: dict[str, Any]) -> str | None:
    data = payload.get("data")
    if not isinstance(data, dict):
        data = {}

    event_type = payload.get("type")
    if event_type == "tool.execution_start":
        # Count only execution_start so the paired completion event does not
        # double-count the same tool call in the current Copilot CLI schema.
        tool_name = data.get("toolName")
        if isinstance(tool_name, str) and tool_name:
            return tool_name

    # Legacy retained fixtures still expose tool names at the top level.
    # This runs only when the current-schema early return above did not match,
    # which keeps old replay tests working without counting nested hook
    # payloads from the current schema as tool calls.
    for candidate in (
        payload.get("tool_name"),
        payload.get("tool"),
        payload.get("recipient_name"),
        payload.get("name"),
    ):
        if isinstance(candidate, str) and candidate:
            return candidate
    return None


def nested_error_flag(value: Any, depth: int = 0, max_depth: int = 50) -> bool:
    """Look for explicit error fields only; depth bound keeps malformed input finite."""
    if depth >= max_depth:
        return False
    if isinstance(value, dict):
        for key, nested in value.items():
            key_text = str(key).lower()
            if key_text == "level" and isinstance(nested, str) and nested.lower() == "error":
                return True
            if key_text in {"error", "errors"}:
                if isinstance(nested, bool):
                    if nested:
                        return True
                elif nested not in (None, "", [], {}):
                    return True
            if nested_error_flag(nested, depth + 1, max_depth):
                return True
        return False
    if isinstance(value, list):
        return any(nested_error_flag(item, depth + 1, max_depth) for item in value)
    return False


def session_error_event(payload: dict[str, Any]) -> bool:
    event_markers: list[str] = []

    payload_type = payload.get("type")
    if isinstance(payload_type, str) and payload_type:
        event_markers.append(payload_type.lower())

    data = payload.get("data")
    if isinstance(data, dict):
        data_type = data.get("type")
        if isinstance(data_type, str) and data_type:
            event_markers.append(data_type.lower())

    return any("error" in marker for marker in event_markers) or nested_error_flag(payload)


def parse_session_log(path: Path | None) -> dict[str, Any]:
    if path is None:
        return {
            "present": False,
            "path": None,
            "total_events": 0,
            "tool_calls": 0,
            "tool_counts": {},
            "error_events": 0,
            "started_at": None,
            "ended_at": None,
            "duration_seconds": None,
            "notes": ["No session log provided."],
        }

    summary: dict[str, Any] = {
        "present": path.exists(),
        "path": str(path),
        "total_events": 0,
        "tool_calls": 0,
        "tool_counts": {},
        "error_events": 0,
        "started_at": None,
        "ended_at": None,
        "duration_seconds": None,
        "notes": [],
    }
    if not path.exists():
        summary["notes"].append("Session log path does not exist.")
        return summary

    tool_counts: Counter[str] = Counter()
    timestamps: list[dt.datetime] = []
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue
            summary["total_events"] += 1
            try:
                payload = json.loads(line)
            except json.JSONDecodeError:
                continue

            tool_name = session_tool_name(payload)
            if isinstance(tool_name, str) and tool_name:
                tool_counts[tool_name] += 1
                summary["tool_calls"] += 1

            if session_error_event(payload):
                summary["error_events"] += 1

            for key in ("timestamp", "time", "created_at", "recorded_at"):
                value = payload.get(key)
                if not isinstance(value, str):
                    continue
                try:
                    stamp = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
                except ValueError:
                    continue
                timestamps.append(stamp)
                break

    summary["tool_counts"] = dict(sorted(tool_counts.items()))
    if timestamps:
        start = min(timestamps)
        end = max(timestamps)
        summary["started_at"] = start.isoformat()
        summary["ended_at"] = end.isoformat()
        summary["duration_seconds"] = int((end - start).total_seconds())
    return summary


def discover_run_context(run_dir: Path, explicit_artifact_root: Path | None) -> dict[str, Path | None]:
    artifact_root = explicit_artifact_root
    run_context = run_dir

    candidates = [run_dir, run_dir.parent]
    for candidate in candidates:
        if candidate is None:
            continue
        if artifact_root is None and (candidate / "artifacts").is_dir():
            artifact_root = (candidate / "artifacts").resolve()
        if (
            (candidate / "run-metadata.json").exists()
            or (candidate / "session").is_dir()
            or (candidate / "start_epoch.txt").exists()
            or (candidate / "session_log_path.txt").exists()
        ):
            run_context = candidate.resolve()
            break

    if artifact_root is None:
        raise SystemExit(
            "No retained artifact snapshot found. Expected --artifact-root, "
            f"{run_dir / 'artifacts'}, or {(run_dir.parent / 'artifacts').resolve()}."
        )
    if not artifact_root.exists():
        raise SystemExit(f"Artifact root does not exist: {artifact_root}")

    return {
        "run_context": run_context.resolve(),
        "artifact_root": artifact_root.resolve(),
    }


def discover_session_log(run_context: Path, explicit_session_log: Path | None) -> Path | None:
    if explicit_session_log is not None:
        return explicit_session_log.resolve()

    copied_session = run_context / "session" / "events.jsonl"
    if copied_session.exists():
        return copied_session.resolve()

    session_log_path = run_context / "session_log_path.txt"
    if session_log_path.exists():
        candidate = Path(session_log_path.read_text(encoding="utf-8").strip())
        if candidate.exists():
            return candidate.resolve()
    return None


def summarize_artifacts(artifact_root: Path, start: str, end: str) -> dict[str, Any]:
    summary: dict[str, Any] = {}
    for name, payload in resolved_artifact_map(artifact_root, start, end).items():
        resolved_path = Path(str(payload["resolved_path"]))
        summary[name] = {
            "logical_path": payload["logical_path"],
            "resolved_path": str(resolved_path),
            "exists": resolved_path.exists(),
            "size_bytes": resolved_path.stat().st_size if resolved_path.exists() else None,
            "mtime_epoch": int(resolved_path.stat().st_mtime) if resolved_path.exists() else None,
        }
    return summary


def parse_receipts(receipts_path: Path) -> dict[str, Any]:
    if not receipts_path.exists():
        return {
            "present": False,
            "schema_version": None,
            "ordered_phase_ids": [],
            "phase_spans_seconds": {},
            "receipt_span_seconds": None,
            "ordering_mode": None,
            "warnings": ["Receipts file missing."],
        }

    payload = json.loads(receipts_path.read_text(encoding="utf-8"))
    receipts = payload.get("receipts", [])

    normalized: list[dict[str, Any]] = []
    ordering_mode = "recorded_at_epoch"
    warnings: list[str] = []
    for receipt in receipts:
        phase_id = receipt.get("phase_id")
        if not isinstance(phase_id, str) or not phase_id:
            continue
        entry = dict(receipt)
        recorded_at_epoch = entry.get("recorded_at_epoch")
        if isinstance(recorded_at_epoch, str) and recorded_at_epoch.isdigit():
            entry["recorded_at_epoch"] = int(recorded_at_epoch)
        elif not isinstance(recorded_at_epoch, int):
            entry["recorded_at_epoch"] = None

        receipt_order = entry.get("receipt_order")
        if isinstance(receipt_order, str) and receipt_order.isdigit():
            entry["receipt_order"] = int(receipt_order)
        elif not isinstance(receipt_order, int):
            entry["receipt_order"] = None
        normalized.append(entry)

    if normalized and all(entry.get("receipt_order") is not None for entry in normalized):
        ordering_mode = "receipt_order"
        ordered = sorted(normalized, key=lambda item: int(item["receipt_order"]))
    else:
        ordered = sorted(
            normalized,
            key=lambda item: (int(item.get("recorded_at_epoch") or 0), item.get("phase_id", "")),
        )
        warnings.append(
            "Legacy receipt ordering fallback in use; chronology is based on recorded_at_epoch."
        )

    phase_spans: dict[str, int | None] = {}
    previous = None
    for receipt in ordered:
        if previous is not None:
            key = f"{previous['phase_id']} -> {receipt['phase_id']}"
            if previous.get("recorded_at_epoch") is None or receipt.get("recorded_at_epoch") is None:
                phase_spans[key] = None
            else:
                phase_spans[key] = int(receipt["recorded_at_epoch"]) - int(previous["recorded_at_epoch"])
        previous = receipt

    observed_phase_ids = [entry["phase_id"] for entry in ordered]
    canonical_phase_ids = list(receipt_phase_logical_paths(str(payload.get("start") or ""), str(payload.get("end") or "")).keys())
    canonical_rank = {phase_id: index for index, phase_id in enumerate(canonical_phase_ids)}
    comparable_ordered = sorted(
        ordered,
        key=lambda item: (canonical_rank.get(item["phase_id"], len(canonical_rank)), observed_phase_ids.index(item["phase_id"])),
    )
    comparable_phase_spans: dict[str, int | None] = {}
    comparable_warnings: list[str] = []
    previous = None
    for receipt in comparable_ordered:
        if previous is not None:
            key = f"{previous['phase_id']} -> {receipt['phase_id']}"
            if previous.get("recorded_at_epoch") is None or receipt.get("recorded_at_epoch") is None:
                comparable_phase_spans[key] = None
            else:
                seconds = int(receipt["recorded_at_epoch"]) - int(previous["recorded_at_epoch"])
                comparable_phase_spans[key] = seconds
                if seconds < 0:
                    comparable_warnings.append(
                        f"Comparable phase order places {receipt['phase_id']} before retained receipt chronology."
                    )
        previous = receipt

    comparable_phase_ids = [entry["phase_id"] for entry in comparable_ordered]
    phase_order_normalization = {
        "applied": comparable_phase_ids != observed_phase_ids,
        "mode": "canonical_product_phase_order",
        "source": "tools.product_run_common.receipt_phase_logical_paths",
        "preserves_retained_ordered_phase_ids": True,
        "reason": (
            "Normalize optional same-cycle post-assembly receipt order for cross-anchor comparison; "
            "raw retained receipt chronology remains in ordered_phase_ids."
        ),
        "warnings": comparable_warnings,
    }

    first_receipt_epoch = ordered[0].get("recorded_at_epoch") if ordered else None
    last_receipt_epoch = ordered[-1].get("recorded_at_epoch") if ordered else None
    if (
        first_receipt_epoch is not None
        and last_receipt_epoch is not None
        and len(ordered) >= 1
    ):
        receipt_span_seconds = int(last_receipt_epoch) - int(first_receipt_epoch)
    else:
        receipt_span_seconds = None

    return {
        "present": True,
        "schema_version": payload.get("schema_version"),
        "run_id": payload.get("run_id"),
        "prepared_at_epoch": payload.get("prepared_at_epoch"),
        "first_receipt_epoch": first_receipt_epoch,
        "last_receipt_epoch": last_receipt_epoch,
        "receipt_span_seconds": receipt_span_seconds,
        "phase_spans_seconds": phase_spans,
        "ordered_phase_ids": [entry["phase_id"] for entry in ordered],
        "comparable_ordered_phase_ids": comparable_phase_ids,
        "comparable_phase_spans_seconds": comparable_phase_spans,
        "phase_order_normalization": phase_order_normalization,
        "ordering_mode": ordering_mode,
        "warnings": warnings,
    }


def build_validator_commands(
    args: argparse.Namespace,
    repo_root: Path,
    artifact_root: Path,
    artifacts: dict[str, Any],
    audit_dir: Path,
) -> dict[str, list[str]]:
    strict_report_path = (audit_dir / "strict-validator-report.md").resolve()
    strict_cmd = [
        "bash",
        "tools/validate_pipeline_strict.sh",
        args.start,
        args.end,
        "--artifact-root",
        str(artifact_root),
        "--report-path",
        str(strict_report_path),
    ]
    if args.require_fresh:
        strict_cmd.append("--require-fresh")
    if args.mode == "benchmark":
        strict_cmd.extend(["--benchmark-mode", "feb2026_consistency"])
    else:
        strict_cmd.append("--production-artifacts")

    newsletter_cmd = [
        "bash",
        ".github/skills/newsletter-validation/scripts/validate_newsletter.sh",
        str(artifacts["output"]["resolved_path"]),
    ]
    score_cmd = ["bash", "tools/score-v2-rubric.sh"]
    if args.mode == "production":
        score_cmd.extend(["--mode", "auto"])
    score_cmd.append(str(artifacts["output"]["resolved_path"]))

    return {
        "strict": strict_cmd,
        "newsletter": newsletter_cmd,
        "rubric": score_cmd,
    }


def format_validator_summary(results: dict[str, dict[str, Any]]) -> str:
    lines = ["# Strict Gap Report", ""]
    for name, result in results.items():
        lines.append(f"## {name}")
        lines.append(f"- Command: `{' '.join(result['cmd'])}`")
        lines.append(f"- Exit: `{result['returncode']}`")
        output = (result["stdout"] + "\n" + result["stderr"]).strip()
        if output:
            lines.append("")
            lines.append("```text")
            lines.append(output)
            lines.append("```")
        else:
            lines.append("- Output: none")
        lines.append("")
    return "\n".join(lines)


def current_environment(repo_root: Path) -> dict[str, Any]:
    git_status = run_cmd(["git", "status", "--short"], repo_root)
    git_branch = run_cmd(["git", "rev-parse", "--abbrev-ref", "HEAD"], repo_root)
    git_sha = run_cmd(["git", "rev-parse", "HEAD"], repo_root)
    return {
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "git_sha": git_sha["stdout"].strip() or None,
        "git_branch": git_branch["stdout"].strip() or None,
        "git_dirty": bool(git_status["stdout"].strip()),
        "dirty_files": [line for line in git_status["stdout"].splitlines() if line.strip()],
        "copilot": safe_version("copilot"),
        "timeout": safe_version("timeout") if shutil.which("timeout") else safe_version("gtimeout"),
        "python": sys.version.split()[0],
    }


def load_retained_run_metadata(run_context: Path) -> dict[str, Any]:
    metadata = load_json(run_context / "run-metadata.json") or {}
    start_epoch_path = run_context / "start_epoch.txt"
    if "start_epoch" not in metadata and start_epoch_path.exists():
        raw = start_epoch_path.read_text(encoding="utf-8").strip()
        if raw.isdigit():
            metadata["start_epoch"] = int(raw)
    if "started_at_utc" not in metadata and isinstance(metadata.get("start_epoch"), int):
        metadata["started_at_utc"] = dt.datetime.fromtimestamp(
            int(metadata["start_epoch"]), tz=dt.timezone.utc
        ).strftime("%Y-%m-%dT%H:%M:%SZ")
    session_log_path = run_context / "session_log_path.txt"
    if "session_log_path" not in metadata and session_log_path.exists():
        metadata["session_log_path"] = session_log_path.read_text(encoding="utf-8").strip()
    return metadata


def format_environment_receipt(
    retained_metadata: dict[str, Any],
    collector_environment: dict[str, Any],
) -> str:
    retained_lines = ["## Retained Run Metadata"]
    if retained_metadata:
        for key in (
            "mode",
            "start",
            "end",
            "started_at_utc",
            "start_epoch",
            "git_sha",
            "git_branch",
            "git_dirty",
            "command",
            "session_log_path",
            "notes",
        ):
            value = retained_metadata.get(key)
            if value is None:
                continue
            retained_lines.append(f"- {key}: `{value}`")
    else:
        retained_lines.append("- none")

    collector_lines = [
        "## Collector Environment",
        f"- generated_at: `{collector_environment['generated_at']}`",
        f"- git_sha: `{collector_environment['git_sha']}`",
        f"- git_branch: `{collector_environment['git_branch']}`",
        f"- git_dirty: `{collector_environment['git_dirty']}`",
        f"- dirty_files: `{', '.join(collector_environment['dirty_files']) if collector_environment['dirty_files'] else 'none'}`",
        f"- copilot_path: `{collector_environment['copilot']['path']}`",
        f"- copilot_version: `{collector_environment['copilot']['version']}`",
        f"- timeout_path: `{collector_environment['timeout']['path']}`",
        f"- timeout_version: `{collector_environment['timeout']['version']}`",
        f"- python_version: `{collector_environment['python']}`",
    ]
    return "\n".join(["# Environment Receipt", "", *retained_lines, "", *collector_lines])


def format_git_history(repo_root: Path) -> str:
    git_history = run_cmd(
        [
            "git",
            "log",
            "--date=short",
            "--pretty=format:%h %ad %s",
            "-n",
            "20",
            "--",
            ".github/agents/customer_newsletter.agent.md",
            "Makefile",
            "README.md",
            "planning/PRODUCT_RUN_PLAYBOOK.md",
            "release_bundle/2026-04_newsletter_launch",
            "tools",
        ],
        repo_root,
    )
    git_history_md = [
        "# Git History Summary",
        "",
        "## Recent related commits",
    ]
    history_text = git_history["stdout"].strip()
    if history_text:
        git_history_md.append("```text")
        git_history_md.append(history_text)
        git_history_md.append("```")
    else:
        git_history_md.append("- none")
    return "\n".join(git_history_md)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("start")
    parser.add_argument("end")
    parser.add_argument("--mode", required=True, choices=["benchmark", "production"])
    parser.add_argument("--run-dir", required=True)
    parser.add_argument("--session-log")
    parser.add_argument("--artifact-root")
    parser.add_argument("--require-fresh", action="store_true")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    run_dir = Path(args.run_dir).resolve()
    run_dir.mkdir(parents=True, exist_ok=True)

    context = discover_run_context(
        run_dir,
        Path(args.artifact_root).resolve() if args.artifact_root else None,
    )
    artifact_root = Path(str(context["artifact_root"]))
    run_context = Path(str(context["run_context"]))
    session_log = discover_session_log(
        run_context,
        Path(args.session_log).resolve() if args.session_log else None,
    )

    artifacts = summarize_artifacts(artifact_root, args.start, args.end)
    receipt_summary = parse_receipts(Path(str(artifacts["receipts"]["resolved_path"])))
    session_summary = parse_session_log(session_log)
    retained_metadata = load_retained_run_metadata(run_context)
    collector_env = current_environment(repo_root)

    baseline_epoch = None
    if isinstance(retained_metadata.get("start_epoch"), int):
        baseline_epoch = int(retained_metadata["start_epoch"])
    elif receipt_summary.get("prepared_at_epoch") is not None:
        baseline_epoch = int(receipt_summary["prepared_at_epoch"])
    elif session_summary.get("started_at"):
        baseline_epoch = int(
            dt.datetime.fromisoformat(str(session_summary["started_at"]).replace("Z", "+00:00")).timestamp()
        )

    first_receipt_epoch = receipt_summary.get("first_receipt_epoch")
    first_artifact_epoch = min(
        (
            item["mtime_epoch"]
            for item in artifacts.values()
            if item["mtime_epoch"] is not None
        ),
        default=None,
    )
    time_to_first_receipt = (
        int(first_receipt_epoch) - baseline_epoch
        if baseline_epoch is not None and first_receipt_epoch is not None
        else None
    )
    time_to_first_artifact = (
        int(first_artifact_epoch) - baseline_epoch
        if baseline_epoch is not None and first_artifact_epoch is not None
        else None
    )

    commands = build_validator_commands(args, repo_root, artifact_root, artifacts, run_dir)
    validator_results = {name: run_cmd(cmd, repo_root) for name, cmd in commands.items()}

    write_text(run_dir / "environment-receipt.md", format_environment_receipt(retained_metadata, collector_env))

    session_summary_md = [
        "# Session Log Summary",
        "",
        f"- Present: `{session_summary['present']}`",
        f"- Path: `{session_summary['path']}`",
        f"- Total events: `{session_summary['total_events']}`",
        f"- Tool calls: `{session_summary['tool_calls']}`",
        f"- Error events: `{session_summary['error_events']}`",
        f"- Started at: `{session_summary['started_at']}`",
        f"- Ended at: `{session_summary['ended_at']}`",
        f"- Duration seconds: `{session_summary['duration_seconds']}`",
        "",
        "## Tool Counts",
    ]
    if session_summary["tool_counts"]:
        session_summary_md.extend(
            f"- `{tool}`: `{count}`" for tool, count in session_summary["tool_counts"].items()
        )
    else:
        session_summary_md.append("- none")
    if session_summary["notes"]:
        session_summary_md.append("")
        session_summary_md.append("## Notes")
        session_summary_md.extend(f"- {note}" for note in session_summary["notes"])
    write_text(run_dir / "session-log-summary.md", "\n".join(session_summary_md))

    write_text(run_dir / "git-history-summary.md", format_git_history(repo_root))
    write_text(run_dir / "strict-gap-report.md", format_validator_summary(validator_results))

    audit_json = {
        "start": args.start,
        "end": args.end,
        "mode": args.mode,
        "run_dir": str(run_dir),
        "run_context": str(run_context),
        "artifact_root": str(artifact_root),
        "retained_run_metadata": retained_metadata,
        "collector_environment": collector_env,
        "session_log": session_summary,
        "artifacts": artifacts,
        "receipts": receipt_summary,
        "metrics": {
            "receipt_span_seconds": receipt_summary.get("receipt_span_seconds"),
            "time_to_first_receipt_seconds": time_to_first_receipt,
            "time_to_first_artifact_seconds": time_to_first_artifact,
            "phase_spans_seconds": receipt_summary.get("phase_spans_seconds", {}),
            "comparable_phase_spans_seconds": receipt_summary.get("comparable_phase_spans_seconds", {}),
        },
        "validators": validator_results,
    }
    write_text(run_dir / "RUN_AUDIT.json", json.dumps(audit_json, indent=2, sort_keys=True))

    validator_status_lines = [
        f"- `{name}`: exit `{result['returncode']}`"
        for name, result in validator_results.items()
    ]
    artifact_lines = [
        f"- `{name}`: `{data['logical_path']}` -> `{data['resolved_path']}` "
        f"({'present' if data['exists'] else 'missing'}, {data['size_bytes']} bytes)"
        for name, data in artifacts.items()
    ]
    phase_span_lines = [
        f"- `{name}`: `{seconds}` seconds"
        for name, seconds in receipt_summary.get("phase_spans_seconds", {}).items()
    ]
    ordered_phase_lines = [
        f"- `{phase}`" for phase in receipt_summary.get("ordered_phase_ids", [])
    ]

    run_audit_md = [
        "# Product Run Audit",
        "",
        f"- Mode: `{args.mode}`",
        f"- Date range: `{args.start}` through `{args.end}`",
        f"- Require fresh: `{args.require_fresh}`",
        f"- Run context: `{run_context}`",
        f"- Artifact root: `{artifact_root}`",
        "",
        "## Validator Results",
        *(validator_status_lines or ["- none"]),
        "",
        "## Timing Metrics",
        f"- Receipt span seconds: `{receipt_summary.get('receipt_span_seconds')}`",
        f"- Time to first receipt seconds: `{time_to_first_receipt}`",
        f"- Time to first artifact seconds: `{time_to_first_artifact}`",
        "",
        "## Receipt Ordering",
        f"- Ordering mode: `{receipt_summary.get('ordering_mode')}`",
        *(f"- Warning: {warning}" for warning in receipt_summary.get("warnings", [])),
        "",
        "### Ordered Phases",
        *(ordered_phase_lines or ["- none"]),
        "",
        "## Phase Spans",
        *(phase_span_lines or ["- none"]),
        "",
        "## Artifact Inventory",
        *artifact_lines,
        "",
        "## Supporting Reports",
        "- `environment-receipt.md`",
        "- `session-log-summary.md`",
        "- `git-history-summary.md`",
        "- `strict-validator-report.md`",
        "- `strict-gap-report.md`",
    ]
    write_text(run_dir / "RUN_AUDIT.md", "\n".join(run_audit_md))

    return 1 if any(result["returncode"] != 0 for result in validator_results.values()) else 0


if __name__ == "__main__":
    raise SystemExit(main())

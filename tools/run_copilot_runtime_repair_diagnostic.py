#!/usr/bin/env python3
"""Run the Burst-30B Copilot noninteractive runtime diagnostic matrix."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any

from newsletter_experiment_common import sha256_path
from run_copilot_phase import resolve_copilot_bin


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run bounded Copilot runtime repair probes")
    parser.add_argument("--run-dir", required=True, help="Directory for diagnostic artifacts")
    parser.add_argument("--output", required=True, help="Diagnostic receipt JSON path")
    parser.add_argument("--model", default="gpt-5.5")
    parser.add_argument("--agent", default="customer_newsletter")
    parser.add_argument("--cwd", default=".")
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--copilot-bin", default="copilot")
    parser.add_argument("--session-state-base", help="Override session-state directory")
    return parser.parse_args()


def utc_now() -> str:
    return dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    if not path.exists():
        return rows
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw.strip():
            continue
        try:
            row = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if isinstance(row, dict):
            rows.append(row)
    return rows


def log_has_response(path: Path) -> bool:
    if not path.exists():
        return False
    text = path.read_text(encoding="utf-8", errors="ignore").strip()
    if not text:
        return False
    stripped_lines = [
        line
        for line in text.splitlines()
        if line.strip() and not line.startswith("[orchestrator]")
    ]
    return bool(stripped_lines)


def variant_matrix(args: argparse.Namespace, run_dir: Path) -> list[dict[str, Any]]:
    return [
        {"id": "current_wrapper", "agent": args.agent, "flags": []},
        {"id": "raw_no_agent", "agent": "", "flags": []},
        {"id": "raw_with_agent", "agent": args.agent, "flags": []},
        {"id": "silent_with_agent", "agent": args.agent, "flags": ["--silent"]},
        {
            "id": "json_with_agent",
            "agent": args.agent,
            "flags": ["--output-format", "json"],
        },
        {
            "id": "explicit_cwd_with_agent",
            "agent": args.agent,
            "flags": ["--use-copilot-cwd-flag"],
        },
        {
            "id": "log_dir_with_agent",
            "agent": args.agent,
            "flags": ["--log-level", "all", "--log-dir", str(run_dir / "copilot-logs")],
        },
        {
            "id": "name_with_agent",
            "agent": args.agent,
            "flags": ["--name", f"burst30b-{uuid.uuid4().hex[:12]}"],
        },
    ]


def classify_variant(
    variant: dict[str, Any],
    *,
    returncode: int,
    log_path: Path,
    metrics_path: Path,
) -> dict[str, Any]:
    metrics_rows = load_jsonl(metrics_path)
    metrics = metrics_rows[-1] if metrics_rows else {}
    detection = metrics.get("session_log_detection") if isinstance(metrics, dict) else {}
    missing_fields = metrics.get("missing_direct_provider_token_fields") if isinstance(metrics, dict) else []
    present_fields = metrics.get("direct_provider_token_fields_present") if isinstance(metrics, dict) else []
    response_present = log_has_response(log_path)
    bound = isinstance(detection, dict) and detection.get("status") == "bound_candidate"
    direct_fields_present = bool(present_fields) and not missing_fields
    qualifies = returncode == 0 and response_present and bound and direct_fields_present
    if qualifies:
        status = "qualified_runtime_and_telemetry"
    elif response_present and bound and missing_fields:
        status = "runtime_bound_missing_direct_token_fields"
    elif response_present and not bound:
        status = "runtime_output_without_session_binding"
    elif not response_present:
        status = "no_runtime_output"
    else:
        status = "runtime_failed"
    return {
        "variant_id": variant["id"],
        "agent": variant["agent"],
        "flags": variant["flags"],
        "exit_code": returncode,
        "status": status,
        "qualifies": qualifies,
        "response_present": response_present,
        "session_log_detection": detection,
        "direct_provider_token_fields_present": present_fields or [],
        "missing_direct_provider_token_fields": missing_fields or [],
        "log_path": str(log_path),
        "log_sha256": sha256_path(log_path) if log_path.exists() else None,
        "metrics_path": str(metrics_path),
        "session_log_path": metrics.get("session_log_path") if isinstance(metrics, dict) else None,
    }


def overall_verdict(rows: list[dict[str, Any]], selected: dict[str, Any] | None) -> str:
    if selected:
        return "runtime_repaired_with_direct_token_telemetry"
    if any(row["status"] == "runtime_bound_missing_direct_token_fields" for row in rows):
        return "runtime_repaired_missing_direct_token_fields"
    if any(row["status"] == "runtime_output_without_session_binding" for row in rows):
        return "runtime_output_session_binding_blocked"
    if rows and all(row["status"] == "no_runtime_output" for row in rows):
        return "human_auth_escalation_recommended"
    return "runtime_not_repaired"


def main() -> int:
    args = parse_args()
    resolved_copilot_bin = resolve_copilot_bin(args.copilot_bin)
    run_dir = Path(args.run_dir).expanduser().resolve()
    output_path = Path(args.output).expanduser().resolve()
    run_dir.mkdir(parents=True, exist_ok=True)
    prompt_path = run_dir / "runtime_probe.prompt.md"
    prompt_path.write_text("Return only OK\n", encoding="utf-8")

    rows: list[dict[str, Any]] = []
    selected: dict[str, Any] | None = None
    for variant in variant_matrix(args, run_dir):
        variant_dir = run_dir / "variants" / variant["id"]
        variant_dir.mkdir(parents=True, exist_ok=True)
        log_path = variant_dir / "copilot.log"
        metrics_path = variant_dir / "phase-session-metrics.jsonl"
        cmd = [
            sys.executable,
            "tools/run_copilot_phase.py",
            "--model",
            args.model,
            "--copilot-bin",
            resolved_copilot_bin,
            "--prompt-file",
            str(prompt_path),
            "--log",
            str(log_path),
            "--timeout",
            str(args.timeout),
            "--cwd",
            args.cwd,
            "--phase-id",
            f"burst30b_{variant['id']}",
            "--metrics-out",
            str(metrics_path),
            "--require-session-log",
            "--require-direct-token-fields",
        ]
        if args.session_state_base:
            cmd.extend(["--session-state-base", args.session_state_base])
        if variant["agent"]:
            cmd.extend(["--agent", variant["agent"]])
        cmd.extend(str(flag) for flag in variant["flags"])
        completed = subprocess.run(cmd, text=True, capture_output=True, check=False)
        (variant_dir / "stdout.txt").write_text(completed.stdout, encoding="utf-8")
        (variant_dir / "stderr.txt").write_text(completed.stderr, encoding="utf-8")
        row = classify_variant(
            variant,
            returncode=completed.returncode,
            log_path=log_path,
            metrics_path=metrics_path,
        )
        row["wrapper_stdout_sha256"] = sha256_path(variant_dir / "stdout.txt")
        row["wrapper_stderr_sha256"] = sha256_path(variant_dir / "stderr.txt")
        rows.append(row)
        if row["qualifies"] and variant["agent"] == args.agent:
            selected = row
            break

    receipt = {
        "schema_version": 1,
        "generated_at_utc": utc_now(),
        "run_dir": str(run_dir),
        "model": args.model,
        "agent": args.agent,
        "copilot_bin": resolved_copilot_bin,
        "session_state_base": args.session_state_base,
        "prompt_path": str(prompt_path),
        "prompt_sha256": sha256_path(prompt_path),
        "variants": rows,
        "selected_variant": selected,
        "verdict": overall_verdict(rows, selected),
        "human_help_text": [
            "Please run `copilot login` in a normal terminal and complete the browser/device flow. Do not paste tokens into chat.",
            f"Then run: `cd {Path(args.cwd).expanduser().resolve()} && {resolved_copilot_bin} --model {args.model} --allow-all --no-ask-user --stream off -p 'Return only OK'`.",
            "Tell me whether it printed `OK`, failed, or opened an interactive/auth prompt. Do not share secrets.",
        ],
        "non_claims": [
            "This diagnostic is runtime proof only.",
            "It is not a model recommendation, production adoption, or durable savings claim.",
        ],
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"verdict": receipt["verdict"], "output": str(output_path)}, sort_keys=True))
    return 0 if selected else 1


if __name__ == "__main__":
    raise SystemExit(main())

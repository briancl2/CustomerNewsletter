#!/usr/bin/env python3
"""Run a single Copilot CLI phase with timeout and log capture."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run one Copilot CLI prompt with timeout")
    parser.add_argument("--agent", required=True, help="Copilot agent name")
    parser.add_argument("--model", required=True, help="Copilot model name")
    parser.add_argument("--prompt-file", required=True, help="Path to markdown prompt file")
    parser.add_argument("--log", required=True, help="Path to log file")
    parser.add_argument("--timeout", type=int, default=1800, help="Timeout seconds")
    parser.add_argument("--cwd", default=".", help="Working directory")
    return parser.parse_args()


def write_log(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


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

    prompt = prompt_path.read_text(encoding="utf-8")
    cmd = [
        "copilot",
        "--agent",
        args.agent,
        "--model",
        args.model,
        "--allow-all",
        "--deny-tool",
        "agent",
        "--no-ask-user",
        "--stream",
        "off",
        "-p",
        prompt,
    ]

    try:
        completed = subprocess.run(
            cmd,
            cwd=args.cwd,
            text=True,
            capture_output=True,
            timeout=args.timeout,
            check=False,
        )
        combined = _to_text(completed.stdout) + _to_text(completed.stderr)
        write_log(Path(args.log), combined)
        if combined:
            print(combined, end="")
        return completed.returncode
    except subprocess.TimeoutExpired as exc:
        combined = _to_text(exc.stdout) + _to_text(exc.stderr)
        combined += f"\n[orchestrator] TIMEOUT after {args.timeout}s\n"
        write_log(Path(args.log), combined)
        if combined:
            print(combined, end="")
        return 124


def main() -> int:
    args = parse_args()
    return run_phase(args)


if __name__ == "__main__":
    raise SystemExit(main())

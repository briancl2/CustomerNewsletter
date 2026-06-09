#!/usr/bin/env python3
"""Emit comparable local and CI closure-run identity fields."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path


def local_run_id() -> str:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return f"local-{timestamp}-{os.getpid()}"


def current_git_head() -> str:
    try:
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        )
    except Exception:
        return "unknown-head"
    return result.stdout.strip() or "unknown-head"


def build_identity(phase: str, parent_command: str) -> dict[str, str | None]:
    github_run_id = os.environ.get("GITHUB_RUN_ID") or None
    github_run_attempt = os.environ.get("GITHUB_RUN_ATTEMPT") or None
    closure_run_id = (
        os.environ.get("CLOSURE_RUN_ID")
        or (
            f"{github_run_id}-{github_run_attempt}"
            if github_run_id and github_run_attempt
            else None
        )
        or local_run_id()
    )
    closure_phase = os.environ.get("CLOSURE_PHASE") or phase
    closure_trigger = (
        os.environ.get("CLOSURE_TRIGGER")
        or os.environ.get("GITHUB_EVENT_NAME")
        or "manual"
    )
    parent = (
        os.environ.get("PARENT_COMMAND")
        or os.environ.get("CLOSURE_PARENT_COMMAND")
        or parent_command
    )
    evidence_reuse_key = (
        os.environ.get("EVIDENCE_REUSE_KEY")
        or f"{closure_phase}:{parent}:{current_git_head()}"
    )

    return {
        "closure_run_id": closure_run_id,
        "closure_phase": closure_phase,
        "closure_trigger": closure_trigger,
        "evidence_reuse_key": evidence_reuse_key,
        "parent_command": parent,
        "github_run_id": github_run_id,
        "github_run_attempt": github_run_attempt,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", default="local-validation")
    parser.add_argument("--parent-command", default="manual")
    parser.add_argument(
        "--receipt",
        default=os.environ.get("CLOSURE_IDENTITY_RECEIPT_PATH", ""),
        help="Optional JSON receipt path.",
    )
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    identity = build_identity(args.phase, args.parent_command)
    rendered = json.dumps(identity, sort_keys=True)

    if args.receipt:
        receipt_path = Path(args.receipt)
        receipt_path.parent.mkdir(parents=True, exist_ok=True)
        receipt_path.write_text(
            json.dumps(identity, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

    if not args.quiet:
        print(rendered)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

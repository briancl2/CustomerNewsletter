#!/usr/bin/env python3
"""Admit or fail closed on newsletter proof-run no-cache controls."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


SUPPORTED_MECHANISMS = [
    {
        "type": "argv",
        "args": ["--no-cache"],
        "needles": ["--no-cache"],
        "evidence_surfaces": ["copilot --help"],
        "description": "Copilot CLI explicitly exposes --no-cache.",
    },
    {
        "type": "argv",
        "args": ["--disable-cache"],
        "needles": ["--disable-cache"],
        "evidence_surfaces": ["copilot --help"],
        "description": "Copilot CLI explicitly exposes --disable-cache.",
    },
    {
        "type": "argv",
        "args": ["--no-prompt-cache"],
        "needles": ["--no-prompt-cache"],
        "evidence_surfaces": ["copilot --help"],
        "description": "Copilot CLI explicitly exposes --no-prompt-cache.",
    },
]

HELP_COMMANDS = [
    ("copilot --help", ["--help"]),
    ("copilot help environment", ["help", "environment"]),
    ("copilot help config", ["help", "config"]),
    ("copilot help providers", ["help", "providers"]),
]
NEGATED_OPTION_CONTEXTS = [
    "not supported",
    "unsupported",
    "does not support",
    "do not use",
    "not available",
]


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def run_surface(copilot_bin: str, args: list[str]) -> dict[str, Any]:
    resolved = shutil.which(copilot_bin) or copilot_bin
    try:
        completed = subprocess.run(
            [resolved, *args],
            text=True,
            capture_output=True,
            check=False,
            timeout=20,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {
            "exit_code": None,
            "stdout_sha256": None,
            "stderr_sha256": None,
            "combined_sha256": None,
            "cache_terms": [],
            "error": str(exc),
        }

    combined = (completed.stdout or "") + "\n" + (completed.stderr or "")
    cache_terms = []
    for line in combined.splitlines():
        lowered = line.lower()
        if "cache" in lowered or "cached" in lowered or "reuse" in lowered:
            cache_terms.append(line.strip())
    return {
        "exit_code": completed.returncode,
        "stdout_sha256": sha256_text(completed.stdout or ""),
        "stderr_sha256": sha256_text(completed.stderr or ""),
        "combined_sha256": sha256_text(combined),
        "cache_terms": cache_terms[:20],
        "error": None,
        "combined_text": combined,
    }


def option_line_admits(line: str, option: str) -> bool:
    lowered = line.lower()
    if any(phrase in lowered for phrase in NEGATED_OPTION_CONTEXTS):
        return False
    option_re = re.compile(rf"(^|[\s\[,]){re.escape(option)}($|[\s\],=])")
    return bool(option_re.search(line))


def validate_argv_mechanism(
    copilot_bin: str,
    model: str,
    mechanism: dict[str, Any],
) -> dict[str, Any]:
    args = [
        "--model",
        model,
        *mechanism["args"],
        "--allow-all",
        "--deny-tool",
        "agent",
        "--no-ask-user",
        "--stream",
        "off",
        "--help",
    ]
    row = run_surface(copilot_bin, args)
    row.pop("combined_text", None)
    row["validation_command"] = "copilot proof-run option parser with --help"
    row["validation_args"] = args
    row["pass"] = row.get("exit_code") == 0 and not row.get("error")
    return row


def detect_mechanism(
    copilot_bin: str,
    model: str,
    surfaces: list[dict[str, Any]],
) -> tuple[dict[str, Any] | None, list[dict[str, Any]]]:
    validation_errors = []
    for pattern in SUPPORTED_MECHANISMS:
        for surface in surfaces:
            if surface.get("exit_code") != 0 or surface.get("error"):
                continue
            if surface.get("name") not in pattern.get("evidence_surfaces", []):
                continue
            for line in str(surface.get("combined_text", "")).splitlines():
                if all(option_line_admits(line, needle) for needle in pattern["needles"]):
                    if pattern["type"] != "argv":
                        validation_errors.append(
                            {
                                "mechanism_type": pattern["type"],
                                "reason": "mechanism type is not yet runner-applicable",
                            }
                        )
                        continue
                    validation = validate_argv_mechanism(copilot_bin, model, pattern)
                    if not validation["pass"]:
                        validation_errors.append(
                            {
                                "mechanism_type": pattern["type"],
                                "args": pattern["args"],
                                "validation": validation,
                            }
                        )
                        continue
                    return {
                        "type": pattern["type"],
                        "args": pattern["args"],
                        "description": pattern["description"],
                        "evidence_needles": pattern["needles"],
                        "evidence_surface": surface.get("name"),
                        "evidence_line_sha256": sha256_text(line.strip()),
                        "validation": validation,
                    }, validation_errors
    return None, validation_errors


def surface_failures(surfaces: list[dict[str, Any]]) -> list[dict[str, Any]]:
    failures = []
    for surface in surfaces:
        if surface.get("exit_code") != 0 or surface.get("error"):
            failures.append(
                {
                    "name": surface.get("name"),
                    "exit_code": surface.get("exit_code"),
                    "error": surface.get("error"),
                }
            )
    return failures


def build_receipt(copilot_bin: str, model: str) -> dict[str, Any]:
    resolved = shutil.which(copilot_bin) or copilot_bin
    version = run_surface(copilot_bin, ["--version"])
    version_text = None
    if version.get("combined_text"):
        version_text = str(version["combined_text"]).strip().splitlines()[0]
    version.pop("combined_text", None)

    surfaces = []
    for name, args in HELP_COMMANDS:
        row = run_surface(copilot_bin, args)
        row["name"] = name
        row["args"] = args
        surfaces.append(row)

    failures = surface_failures(surfaces)
    mechanism, validation_errors = detect_mechanism(copilot_bin, model, surfaces)
    for surface in surfaces:
        surface.pop("combined_text", None)
    admitted = mechanism is not None and not failures
    status = (
        "admitted"
        if admitted
        else "inspection_failed"
        if failures
        else "blocked_no_supported_mechanism"
    )
    return {
        "schema_version": 1,
        "receipt_type": "newsletter_no_cache_control_admission",
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "copilot_bin": copilot_bin,
        "copilot_resolved_path": resolved,
        "copilot_version": version_text,
        "model": model,
        "pass": admitted,
        "status": status,
        "inspection_complete": not failures,
        "surface_failures": failures,
        "admitted_mechanism": mechanism,
        "recommended_copilot_args": mechanism["args"] if mechanism else [],
        "supported_mechanism_types": ["argv"],
        "candidate_validation_errors": validation_errors,
        "inspected_surfaces": surfaces,
        "rejected_candidates": [
            {
                "candidate": "tools/prepare_newsletter_cycle.sh --no-reuse",
                "reason": "Owner artifact reuse control; it does not disable provider prompt/cache behavior.",
            },
            {
                "candidate": "fresh COPILOT_HOME or new Copilot session",
                "reason": "CLI-local state isolation is not proof that provider-side prompt caching is disabled.",
            },
            {
                "candidate": "COPILOT_PROVIDER_BASE_URL BYOK",
                "reason": "Changes provider/model routing and is not the same GitHub Copilot gpt-5.5 proof surface.",
            },
        ],
        "non_claims": [
            "No matched cache-control run is admitted unless pass is true.",
            "No durable token savings claim.",
            "No durable dollar savings claim.",
            "No model recommendation.",
            "No production adoption.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--copilot-bin", default="copilot")
    parser.add_argument("--model", default="gpt-5.5")
    parser.add_argument("--output", required=True)
    parser.add_argument("--args-output")
    parser.add_argument("--require-admitted", action="store_true")
    args = parser.parse_args()

    receipt = build_receipt(args.copilot_bin, args.model)
    output_path = Path(args.output).expanduser().resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    if args.args_output:
        args_path = Path(args.args_output).expanduser().resolve()
        args_path.parent.mkdir(parents=True, exist_ok=True)
        args_path.write_text(
            "\n".join(receipt.get("recommended_copilot_args") or []) + "\n",
            encoding="utf-8",
        )

    if args.require_admitted and not receipt["pass"]:
        print(
            "No admitted Copilot CLI no-cache/uncached mechanism was found; receipt written to "
            f"{output_path}",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

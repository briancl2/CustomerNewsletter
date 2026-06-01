#!/usr/bin/env python3
"""Scan Phase 3 experiment logs for validator stop signatures."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


VALIDATOR_COMMAND_RE = re.compile(
    r"^(?:(?:python3|python|uv\s+run\s+python)\s+)?tools/validate_phase3_curated\.py\b"
    r"|^(?:python3|python|uv\s+run\s+python)\s+tools/validate_phase3_curated\.py\b",
    re.I,
)
PYTHON_ONLY_RE = re.compile(r"^(?:python3|python|uv\s+run\s+python)\s*$", re.I)
VALIDATOR_PATH_RE = re.compile(r"^tools/validate_phase3_curated\.py\b", re.I)
FAILURE_LINE_RE = re.compile(r"^FAIL:\s+.*(?:scaffold|placeholder|known-placeholder|bullet floor|24-bullet floor)", re.I)
SCAFFOLD_RE = re.compile(r"\bscaffold|placeholder|known-placeholder|bullet floor|24-bullet floor\b", re.I)
PASS_RE = re.compile(r"^PASS: curated artifact contract satisfied\b", re.I)
NEGATED_FAILURE_RE = re.compile(r"\b(?:do not|don't|won't|will not|should not)\b.*\b(?:fail|validator)", re.I)


def command_line_text(line: str) -> str:
    text = line.strip()
    if text.startswith("│"):
        text = text[1:].strip()
    if text.startswith(("$", ">")):
        text = text[1:].strip()
    return text


def looks_like_command_line(line: str) -> bool:
    text = line.strip()
    normalized = command_line_text(line)
    return text.startswith(("$", ">", "│")) or normalized.startswith(("python3 ", "python ", "uv run python ", "tools/"))


def is_validator_command(lines: list[str], idx: int) -> bool:
    line = lines[idx]
    normalized = command_line_text(line)
    if looks_like_command_line(line) and VALIDATOR_COMMAND_RE.search(normalized):
        return True
    if not PYTHON_ONLY_RE.match(normalized):
        return False
    for next_line in lines[idx + 1 : idx + 4]:
        if VALIDATOR_PATH_RE.search(command_line_text(next_line)):
            return True
    return False


def scan_log(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""
    lines = text.splitlines()
    intermediate: list[dict[str, Any]] = []
    final_pass_lines: list[int] = []
    validator_command_lines: list[int] = []
    for idx, line in enumerate(lines):
        if PASS_RE.search(line):
            final_pass_lines.append(idx + 1)
        if is_validator_command(lines, idx):
            validator_command_lines.append(idx + 1)
        validator_context = any(0 <= idx + 1 - command_line <= 12 for command_line in validator_command_lines)
        before_final_pass = not final_pass_lines
        if (
            validator_context
            and before_final_pass
            and FAILURE_LINE_RE.search(line)
            and SCAFFOLD_RE.search(line)
            and not PASS_RE.search(line)
            and not NEGATED_FAILURE_RE.search(line)
        ):
            window = "\n".join(lines[max(0, idx - 2) : min(len(lines), idx + 3)])
            intermediate.append(
                {
                    "line": idx + 1,
                    "signature": "intermediate-scaffold-validator-failure",
                    "excerpt": " ".join(part.strip() for part in window.splitlines())[:500],
                }
            )
    if intermediate and final_pass_lines:
        classification = "intermediate_scaffold_validator_failure_final_passed"
    elif intermediate:
        classification = "intermediate_scaffold_validator_failure"
    elif final_pass_lines:
        classification = "clean_final_validation_passed"
    else:
        classification = "no_phase3_validator_signal"
    return {
        "path": str(path),
        "exists": path.exists(),
        "classification": classification,
        "intermediate_signature_count": len(intermediate),
        "intermediate_signatures": intermediate,
        "final_validation_pass_lines": final_pass_lines,
    }


def summarize(rows: list[dict[str, Any]]) -> dict[str, Any]:
    intermediate = [row for row in rows if row["intermediate_signature_count"]]
    final_pass = [row for row in rows if row["final_validation_pass_lines"]]
    combined = [row for row in rows if row["intermediate_signature_count"] and row["final_validation_pass_lines"]]
    if combined:
        classification = "intermediate_scaffold_validator_failure_final_passed"
    elif intermediate and final_pass:
        classification = "mixed_independent_validator_signals"
    elif intermediate:
        classification = "intermediate_scaffold_validator_failure"
    elif final_pass:
        classification = "clean_final_validation_passed"
    else:
        classification = "no_phase3_validator_signal"
    return {
        "schema_version": 1,
        "classification": classification,
        "has_intermediate_scaffold_validator_failure": bool(intermediate),
        "has_final_validation_pass": bool(final_pass),
        "logs": rows,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("logs", nargs="+", help="Phase 3 log files to scan.")
    args = parser.parse_args()
    paths = [Path(item) for item in args.logs]
    missing = [str(path) for path in paths if not path.exists()]
    if missing:
        print(json.dumps({"schema_version": 1, "error": "missing_log_file", "missing_logs": missing}, indent=2, sort_keys=True))
        return 2
    rows = [scan_log(path) for path in paths]
    print(json.dumps(summarize(rows), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

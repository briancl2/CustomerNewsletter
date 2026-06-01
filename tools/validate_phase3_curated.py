#!/usr/bin/env python3
"""Fail-closed validator for Phase 3 curated sections."""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
from pathlib import Path

PARSE_COMPLETENESS = re.compile(
    r"^\*\*Parse Completeness\*\*:\s*Parsed\s+(\d+)/(\d+)\s+items\s+\(([0-9]+(?:\.[0-9]+)?)%\)\s*$",
    re.MULTILINE,
)
DEFAULT_PARSE_COMPLETENESS_THRESHOLD = 80.0
BENCHMARK_PLATFORM_FOLD_MODES = {"feb2026_consistency"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate the Phase 3 curated sections contract"
    )
    parser.add_argument("start", help="Cycle start date (YYYY-MM-DD)")
    parser.add_argument("end", help="Cycle end date (YYYY-MM-DD)")
    parser.add_argument("artifact", help="Path to curated sections artifact")
    parser.add_argument(
        "--benchmark-mode",
        default="",
        help="Optional benchmark mode that can relax section layout checks",
    )
    parser.add_argument(
        "--working-set",
        default="",
        help="Optional path to the corresponding Phase 3 working set artifact",
    )
    parser.add_argument(
        "--parse-completeness-threshold",
        default=os.environ.get(
            "PHASE3_PARSE_COMPLETENESS_THRESHOLD", str(DEFAULT_PARSE_COMPLETENESS_THRESHOLD)
        ),
        help="Minimum acceptable parse completeness percentage before fail-closed behavior triggers",
    )
    return parser.parse_args()


def resolve_parse_completeness_threshold(raw: str) -> float:
    try:
        threshold = float(raw)
    except ValueError as exc:
        raise SystemExit(f"Invalid parse completeness threshold: {raw}") from exc
    if threshold <= 0.0 or threshold > 100.0:
        raise SystemExit(f"Parse completeness threshold must be within (0, 100], got {threshold}")
    return threshold


def benchmark_folds_platform_updates(mode: str) -> bool:
    return mode in BENCHMARK_PLATFORM_FOLD_MODES


def bullet_floor(start: str, end: str) -> int:
    start_date = dt.date.fromisoformat(start)
    end_date = dt.date.fromisoformat(end)
    window_days = (end_date - start_date).days + 1
    if window_days >= 60:
        return 24
    if window_days >= 30:
        return 18
    return 12


def default_working_set_path(artifact: Path, end: str) -> Path:
    return artifact.parent / f"newsletter_phase3_working_set_{end}.md"


def validate_working_set_receipt(working_set: Path, threshold: float) -> list[str]:
    failures: list[str] = []
    if not working_set.exists():
        failures.append(f"missing working set artifact: {working_set}")
        return failures

    match = PARSE_COMPLETENESS.search(working_set.read_text(encoding="utf-8"))
    if not match:
        failures.append(f"working set missing parse completeness receipt: {working_set}")
        return failures

    parsed = int(match.group(1))
    expected = int(match.group(2))
    percent = float(match.group(3))
    if expected <= 0:
        failures.append(f"working set parse completeness receipt has non-positive expected total: {working_set}")
    if parsed > expected:
        failures.append(
            f"working set parse completeness receipt is inconsistent ({parsed} > {expected}): {working_set}"
        )
    if percent < threshold:
        failures.append(
            f"working set parse completeness below floor ({percent:.1f}% < {threshold:.1f}%): {working_set}"
        )
    return failures


def main() -> int:
    args = parse_args()
    artifact = Path(args.artifact)
    parse_completeness_threshold = resolve_parse_completeness_threshold(
        args.parse_completeness_threshold
    )

    if not artifact.exists():
        print(f"FAIL: missing artifact: {artifact}")
        return 2

    working_set = Path(args.working_set) if args.working_set else default_working_set_path(artifact, args.end)

    text = artifact.read_text(encoding="utf-8")
    failures: list[str] = []
    if working_set.exists() or args.working_set:
        failures.extend(validate_working_set_receipt(working_set, parse_completeness_threshold))

    if "TODO" in text:
        failures.append("TODO markers remain in the curated sections artifact")
    if "<!--" in text:
        failures.append("HTML comment placeholders remain in the curated sections artifact")

    required_headings = [
        "# Copilot",
        "## Latest Releases",
        "## IDE Parity",
        "## Enterprise and Security Updates",
        "## Resources and Best Practices",
    ]
    if not benchmark_folds_platform_updates(args.benchmark_mode):
        required_headings.append("## GitHub Platform Updates")
    elif "## GitHub Platform Updates" in text:
        failures.append("benchmark mode forbids a dedicated GitHub Platform Updates section")

    for heading in required_headings:
        if heading not in text:
            failures.append(f"missing required heading: {heading}")

    bullet_count = sum(
        1
        for line in text.splitlines()
        if line.startswith("- ") or line.startswith("-   ") or line.startswith("  - ")
    )
    min_bullets = bullet_floor(args.start, args.end)
    if bullet_count < min_bullets:
        failures.append(
            f"bullet count below floor ({bullet_count} < {min_bullets}) for {args.start}..{args.end}"
        )

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}")
        return 2

    print(
        f"PASS: curated artifact contract satisfied ({artifact}, bullets={bullet_count}, floor={min_bullets})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

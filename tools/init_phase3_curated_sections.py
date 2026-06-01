#!/usr/bin/env python3
"""Create a bounded scaffold for Phase 3 curated newsletter sections."""

from __future__ import annotations

import argparse
import os
from datetime import datetime, timezone
from pathlib import Path

BENCHMARK_PLATFORM_FOLD_MODES = {"feb2026_consistency"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Initialize the canonical Phase 3 curated sections scaffold"
    )
    parser.add_argument("start", help="Cycle start date (YYYY-MM-DD)")
    parser.add_argument("end", help="Cycle end date (YYYY-MM-DD)")
    parser.add_argument(
        "--benchmark-mode",
        default=os.environ.get("BENCHMARK_MODE", ""),
        help="Optional benchmark mode that can fold platform updates into enterprise/security sections",
    )
    return parser.parse_args()


def benchmark_folds_platform_updates(mode: str) -> bool:
    return mode in BENCHMARK_PLATFORM_FOLD_MODES


def build_scaffold(start: str, end: str, benchmark_mode: str) -> str:
    curated_day = datetime.now(timezone.utc).date().isoformat()
    lines = [
        "# Phase 3: Curated Newsletter Sections",
        f"**Date Range**: {start} to {end}",
        f"**Curated**: {curated_day}",
        "**Sources**: Phase 3 working set (Phase 1C fallback only when the working set flags missing data)",
        (
            "**Target Audience**: Engineering Managers, DevOps Leads, "
            "IT Leadership (Healthcare, Manufacturing, Financial Services)"
        ),
        f"**Benchmark Mode**: {benchmark_mode or 'off'}",
    ]
    if benchmark_folds_platform_updates(benchmark_mode):
        lines.append(
            "**Section Policy**: Fold GitHub platform-only items into Enterprise and Security Updates for this run."
        )
    else:
        lines.append("**Section Policy**: Keep GitHub Platform Updates as a dedicated section when the working set supports it.")

    lines.extend(
        [
            "",
            "# Copilot",
            "",
            "## Latest Releases",
            "- Add sourced release bullets from the working set and keep enterprise impact explicit.",
            "",
            "## IDE Parity",
            "- Improved IDE Feature Parity",
            "  - Replace this line with IDE-specific rollout or capability deltas grounded in the working set.",
            "  - Keep the standard rollout note only when rollout timing differs by IDE.",
            "",
            "## Enterprise and Security Updates",
            "- Add governance, billing, security, and administration updates grounded in the working set.",
        ]
    )
    if benchmark_folds_platform_updates(benchmark_mode):
        lines.append(
            "- Fold GitHub platform-only items here when benchmark mode forbids a dedicated platform section."
        )
    lines.extend([""])
    if not benchmark_folds_platform_updates(benchmark_mode):
        lines.extend(
            [
                "## GitHub Platform Updates",
                "- Add GitHub platform-only items here when they remain distinct from enterprise/security updates.",
                "",
            ]
        )
    lines.extend(
        [
            "## Resources and Best Practices",
            "- Add enablement, prompting, operator guidance, and reference materials grounded in the working set.",
            "",
        ]
    )
    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()
    out = Path(f"workspace/newsletter_phase3_curated_sections_{args.end}.md")
    out.parent.mkdir(parents=True, exist_ok=True)
    if not out.exists():
        out.write_text(build_scaffold(args.start, args.end, args.benchmark_mode), encoding="utf-8")
    print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

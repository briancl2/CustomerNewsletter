#!/usr/bin/env python3
"""Validate the cross-surface Phase 3 instruction and path contract."""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class ContractRule:
    label: str
    pattern: str


@dataclass(frozen=True)
class SurfaceContract:
    relative_path: str
    required: tuple[ContractRule, ...]
    forbidden: tuple[ContractRule, ...] = ()


SURFACES: tuple[SurfaceContract, ...] = (
    SurfaceContract(
        relative_path=".github/agents/customer_newsletter.agent.md",
        required=(
            ContractRule("working set artifact listed", r"`phase3_working_set`"),
            ContractRule(
                "working-set receipt before curation",
                r"record `phase3_working_set` before any Phase 3 curation edits",
            ),
            ContractRule(
                "working set is primary source",
                r"use it as the primary Phase 3 source",
            ),
            ContractRule(
                "curated scaffold placeholders cleared",
                r"replace all TODO markers and HTML comment placeholders",
            ),
        ),
    ),
    SurfaceContract(
        relative_path=".github/skills/content-curation/SKILL.md",
        required=(
            ContractRule(
                "working set primary input path",
                r"workspace/newsletter_phase3_working_set_YYYY-MM-DD\.md",
            ),
            ContractRule(
                "discoveries fallback wording",
                r"when no working set exists or the working set flags missing data",
            ),
            ContractRule(
                "working set primary instruction",
                r"use it as the primary Phase 3 input",
            ),
        ),
        forbidden=(
            ContractRule(
                "discoveries marked as required input",
                r"Phase 1C Discoveries.*\(required\)",
            ),
        ),
    ),
    SurfaceContract(
        relative_path=".github/prompts/phase_3_content_curation.prompt.md",
        required=(
            ContractRule(
                "working set path called out",
                r"workspace/newsletter_phase3_working_set_YYYY-MM-DD\.md",
            ),
            ContractRule(
                "working set primary instruction",
                r"Only if the working set flags missing data should you consult Phase 1C discoveries",
            ),
            ContractRule(
                "curated path called out",
                r"workspace/newsletter_phase3_curated_sections_YYYY-MM-DD\.md",
            ),
            ContractRule(
                "placeholder cleanup instruction",
                r"Replace all TODO markers and HTML comment placeholders",
            ),
        ),
        forbidden=(
            ContractRule(
                "raw discoveries as the default input",
                r"Review and analyze.*raw content list from Phase 1C",
            ),
        ),
    ),
    SurfaceContract(
        relative_path="tools/init_phase3_curated_sections.py",
        required=(
            ContractRule(
                "scaffold sources reference working set",
                r"\*\*Sources\*\*: Phase 3 working set",
            ),
        ),
    ),
    SurfaceContract(
        relative_path="tools/validate_phase3_curated.py",
        required=(
            ContractRule(
                "validator references working set path",
                r"newsletter_phase3_working_set_",
            ),
            ContractRule(
                "validator enforces missing working set failure",
                r"missing working set artifact",
            ),
            ContractRule(
                "validator enforces parse completeness",
                r"working set parse completeness",
            ),
        ),
    ),
    SurfaceContract(
        relative_path="tools/run_newsletter_orchestrated.sh",
        required=(
            ContractRule(
                "orchestrator missing-data gate",
                r"Only if \$phase3_working_set contains \[MISSING_DATA\]",
            ),
            ContractRule(
                "orchestrator receipts working set before curation",
                r"Record receipt phase3_working_set immediately after",
            ),
            ContractRule(
                "orchestrator edits curated file in place",
                r"Edit \$phase3_curated in place until all TODO markers are removed",
            ),
        ),
    ),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate the Phase 3 instruction/path contract across agent, skill, prompt, and runtime surfaces."
    )
    parser.add_argument(
        "--root",
        default="",
        help="Optional repo root override for fixture testing.",
    )
    return parser.parse_args()


def load_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise SystemExit(f"Missing instruction-contract surface: {path}") from exc


def main() -> int:
    args = parse_args()
    repo_root = Path(args.root).resolve() if args.root else Path(__file__).resolve().parent.parent

    failures: list[str] = []
    for surface in SURFACES:
        path = repo_root / surface.relative_path
        text = load_text(path)
        for rule in surface.required:
            if re.search(rule.pattern, text, re.MULTILINE) is None:
                failures.append(f"{surface.relative_path}: missing {rule.label}")
        for rule in surface.forbidden:
            if re.search(rule.pattern, text, re.MULTILINE):
                failures.append(f"{surface.relative_path}: forbidden {rule.label}")

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}")
        return 2

    print(f"PASS: Phase 3 instruction contract is aligned across {len(SURFACES)} surfaces")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

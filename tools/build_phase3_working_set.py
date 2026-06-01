#!/usr/bin/env python3
"""Compile a bounded Phase 3 working set for curated newsletter writing."""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import sys
import textwrap
from pathlib import Path

ITEM_HEADING = re.compile(r"^###\s+(?:\d+\.\s+)?(.*)$")
FIELD_LINE = re.compile(r"^- \*\*(.+?)\*\*:\s*(.*)$")
INLINE_DISCOVERY_ITEM = re.compile(r"^\d+\.\s+\*\*(.+?)\*\*(.*)$")
BULLET_ITEM = re.compile(r"^- \*\*(.+?)\*\*\s+[\-–—]\s+(.*)$")
DECLARED_TOTAL_DISCOVERIES = re.compile(r"^\*\*Total Discoveries\*\*:\s*(\d+)\s*$")
CANDIDATE_DISCOVERY_PATTERNS = (
    re.compile(r"^###\s+"),
    re.compile(r"^####\s+"),
    re.compile(r"^\d+\.\s+\*\*"),
    re.compile(r"^[-*]\s+\*\*.+?\*\*\s+[\-–—]\s+"),
)
DEFAULT_PARSE_COMPLETENESS_THRESHOLD = 80.0
BENCHMARK_PLATFORM_FOLD_MODES = {"feb2026_consistency"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build a compact Phase 3 working set from canonical inputs"
    )
    parser.add_argument("start", help="Cycle start date (YYYY-MM-DD)")
    parser.add_argument("end", help="Cycle end date (YYYY-MM-DD)")
    parser.add_argument(
        "--benchmark-mode",
        default=os.environ.get("BENCHMARK_MODE", ""),
        help="Optional benchmark mode that adjusts section expectations",
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


def normalize_field(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.strip().lower()).strip("_")


def parse_markdown_items(path: Path) -> list[dict[str, object]]:
    items: list[dict[str, object]] = []
    section = ""
    current: dict[str, object] | None = None
    last_field: str | None = None

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.rstrip()
        if line.startswith("## "):
            if current:
                items.append(current)
                current = None
            section = line[3:].strip()
            last_field = None
            continue

        heading = ITEM_HEADING.match(line)
        if heading:
            if current:
                items.append(current)
            current = {"section": section, "title": heading.group(1).strip(), "fields": {}}
            last_field = None
            continue

        if current is None:
            continue

        field = FIELD_LINE.match(line)
        if field:
            key = normalize_field(field.group(1))
            value = field.group(2).strip()
            current["fields"][key] = value
            last_field = key
            continue

        if last_field and line.startswith("    - "):
            fields = current["fields"]
            fields[last_field] = f"{fields[last_field]} {line.strip()}"

    if current:
        items.append(current)

    return items


def extract_links(raw: str) -> str:
    links = re.findall(r"\[[^\]]+\]\([^)]+\)", raw or "")
    return " | ".join(links)


def infer_ide_support(raw: str) -> str:
    haystack = (raw or "").lower()
    labels = []
    for label in ["VS Code", "Visual Studio", "JetBrains", "Xcode", "Eclipse"]:
        if label.lower() in haystack:
            labels.append(label)
    return ", ".join(labels) if labels else "n/a"


def ide_path_hint(path: Path) -> str:
    stem = path.stem.lower()
    labels = []
    if "visualstudio" in stem or "visual_studio" in stem:
        labels.append("Visual Studio")
    if "jetbrains" in stem:
        labels.append("JetBrains")
    if "xcode" in stem:
        labels.append("Xcode")
    if "eclipse" in stem:
        labels.append("Eclipse")
    return " ".join(labels + [path.stem])


def infer_relevance(raw: str, section: str = "") -> str:
    haystack = f"{section} {raw}".lower()
    score = 7
    if "[flagship]" in haystack:
        score = 10
    elif "generally available" in haystack or "`ga`" in haystack or "(ga)" in haystack:
        score = 9
    elif "preview" in haystack:
        score = 8
    if section in {"Security & Compliance", "Enterprise Administration"}:
        score = max(score, 8)
    return f"{score}/10"


def extract_date_hint(raw: str) -> str:
    match = re.search(
        r"(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4}",
        raw,
    )
    return match.group(0) if match else "n/a"


def build_item(
    *,
    section: str,
    title: str,
    description: str,
    sources: str,
    date: str = "n/a",
    ide_support: str = "n/a",
    relevance_score: str = "7/10",
) -> dict[str, object]:
    return {
        "section": section,
        "title": title.strip(),
        "fields": {
            "date": date,
            "relevance_score": relevance_score,
            "ide_support": ide_support,
            "description": description.strip(),
            "enterprise_impact": description.strip(),
            "sources": sources.strip(),
        },
    }


def dedupe_items(items: list[dict[str, object]]) -> list[dict[str, object]]:
    unique: list[dict[str, object]] = []
    seen: set[tuple[str, str]] = set()
    for item in items:
        key = (str(item["section"]).strip(), str(item["title"]).strip())
        if key in seen:
            continue
        seen.add(key)
        unique.append(item)
    return unique


def parse_inline_discovery_items(path: Path) -> list[dict[str, object]]:
    """Parse fallback Phase 1C markdown where discoveries are inline-numbered.

    This supports compact benchmark-era files shaped like
    `1. **Title** — summary - [Link](...)` instead of the richer `###` item
    blocks that `parse_markdown_items` handles first.
    """
    items: list[dict[str, object]] = []
    section = ""

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.rstrip()
        if line.startswith("## "):
            section = line[3:].strip()
            continue

        match = INLINE_DISCOVERY_ITEM.match(line)
        if not match:
            continue

        title = match.group(1).strip()
        remainder = match.group(2).strip()
        _, separator, description = remainder.partition(" — ")
        if separator:
            remainder = description

        summary, _, explicit_links = remainder.partition(" - [")
        links = f"[{explicit_links}" if explicit_links else extract_links(remainder)
        body = summary.replace("**[FLAGSHIP]**", "").strip()

        items.append(
            build_item(
                section=section,
                title=title,
                description=body,
                sources=links,
                date="n/a",
                ide_support=infer_ide_support(f"{title} {body} {links}"),
                relevance_score=infer_relevance(remainder, section),
            )
        )

    return items


def parse_phase1b_items(path: Path) -> list[dict[str, object]]:
    """Parse canonical Phase 1B interim entries into normalized item records.

    Current Phase 1B interims use `### Title` blocks with field lines such as
    `- **Description**: ...`. Older compact fixtures use bullets of the form
    `- **Title** — body [links]`. Both shapes are normalized into the fields
    expected by the Phase 3 IDE seed renderer.
    """
    items: list[dict[str, object]] = []
    for item in parse_markdown_items(path):
        fields = item["fields"]
        if not isinstance(fields, dict):
            continue
        title = str(item["title"])
        description = str(fields.get("description") or fields.get("summary") or "")
        sources = str(fields.get("sources") or fields.get("links") or "")
        date = str(fields.get("date") or extract_date_hint(description))
        ide_support = str(
            fields.get("ide_support")
            or infer_ide_support(f"{ide_path_hint(path)} {title} {description} {sources}")
        )
        relevance_score = str(
            fields.get("relevance_score")
            or infer_relevance(f"{title} {description}", str(item.get("section") or ""))
        )
        if not description and not sources:
            continue
        items.append(
            build_item(
                section=str(item.get("section") or path.stem),
                title=title,
                description=description,
                sources=sources,
                date=date,
                ide_support=ide_support,
                relevance_score=relevance_score,
            )
        )

    section = ""
    subsection = ""

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.rstrip()
        if line.startswith("## "):
            section = line[3:].strip()
            subsection = ""
            continue
        if line.startswith("### "):
            subsection = line[4:].strip()
            continue

        match = BULLET_ITEM.match(line)
        if not match:
            continue

        title = match.group(1).strip()
        body = match.group(2).strip()
        links = extract_links(body)
        if links:
            body = re.sub(
                r"\s*(?:\[[^\]]+\]\([^)]+\))(?:\s*\|\s*\[[^\]]+\]\([^)]+\))*\s*$",
                "",
                body,
            ).strip()
        item_section = subsection or section or path.stem

        items.append(
            build_item(
                section=item_section,
                title=title,
                description=body,
                sources=links,
                date=extract_date_hint(section),
                ide_support=infer_ide_support(f"{ide_path_hint(path)} {title} {body}"),
                relevance_score=infer_relevance(body, item_section),
            )
        )

    return dedupe_items(items)


def parse_discovery_items(path: Path) -> list[dict[str, object]]:
    return dedupe_items(parse_markdown_items(path) + parse_inline_discovery_items(path))


def extract_declared_total_discoveries(path: Path) -> int | None:
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        match = DECLARED_TOTAL_DISCOVERIES.match(raw_line.strip())
        if match:
            return int(match.group(1))
    return None


def count_candidate_discovery_lines(path: Path) -> int:
    total = 0
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.rstrip()
        if any(pattern.match(line) for pattern in CANDIDATE_DISCOVERY_PATTERNS):
            total += 1
    return total


def build_parse_receipt(
    path: Path, items: list[dict[str, object]], threshold: float
) -> dict[str, float | int | str | bool]:
    declared_total = extract_declared_total_discoveries(path)
    candidate_total = count_candidate_discovery_lines(path)
    expected_total = max(declared_total or 0, candidate_total)
    parsed_total = len(items)
    if expected_total == 0:
        expected_total = parsed_total
    percent = 100.0 if expected_total == 0 else (parsed_total / expected_total) * 100.0
    return {
        "input_source": "raw_phase1c",
        "parsed_total": parsed_total,
        "expected_total": expected_total,
        "percent": percent,
        "threshold": threshold,
        "below_threshold": percent < threshold,
    }


def classify_discovery_bundle(item: dict[str, object], benchmark_mode: str = "") -> str:
    section = str(item["section"])
    fields = item["fields"]
    text = " ".join(
        [
            str(item["title"]),
            str(fields.get("description", "")),
            str(fields.get("sources", "")),
        ]
    ).lower()

    if any(token in text for token in ["deprecation", "retiring", "migration"]):
        return "Deprecations and Migrations"
    if section in {"Security & Compliance", "Enterprise Administration"}:
        return "Copilot at Scale (Governance & Administration)"
    if section == "Platform & DevEx":
        if benchmark_folds_platform_updates(benchmark_mode):
            return "Copilot at Scale (Governance & Administration)"
        return "GitHub Platform Updates"
    if any(
        token in text
        for token in [
            "byok",
            "organization-wide custom instructions",
            "copilot metrics",
            "code review",
            "data residency",
            "custom properties",
            "budgets",
        ]
    ):
        return "Copilot at Scale (Governance & Administration)"
    return "Copilot Latest Releases"


def build_discovery_bundles(
    items: list[dict[str, object]], benchmark_mode: str = ""
) -> dict[str, list[dict[str, object]]]:
    """Collapse normalized discovery items into the bounded Phase 3 section set.

    These bundle names are the compact vocabulary consumed by the scaffolded
    curated sections and benchmark prompts. New classifiers should still map to
    this fixed set to avoid section drift in replay runs.
    """
    bundles = {
        "Monthly Announcement Candidates": [],
        "Copilot Latest Releases": [],
        "Copilot at Scale (Governance & Administration)": [],
        "Deprecations and Migrations": [],
    }
    if not benchmark_folds_platform_updates(benchmark_mode):
        bundles["GitHub Platform Updates"] = []

    def sort_key(item: dict[str, object]) -> tuple[int, str]:
        return (-parse_relevance(str(item["fields"].get("relevance_score", ""))), str(item["title"]))

    for item in items:
        bundle = classify_discovery_bundle(item, benchmark_mode)
        if bundle not in bundles:
            bundle = "Copilot Latest Releases"
        bundles[bundle].append(item)

        lead_text = " ".join(
            [
                str(item["title"]),
                str(item["fields"].get("description", "")),
                str(item["fields"].get("sources", "")),
            ]
        ).lower()
        if "[flagship]" in lead_text or any(
            token in lead_text
            for token in [
                "agent skills",
                "third-party coding agents",
                "model availability",
                "agentic workflows",
                "copilot memory",
                "mcp",
            ]
        ):
            bundles["Monthly Announcement Candidates"].append(item)

    bundle_limits = {
        "Monthly Announcement Candidates": 6,
        "Copilot Latest Releases": 14,
        "Copilot at Scale (Governance & Administration)": 12,
        "Deprecations and Migrations": 6,
    }
    if not benchmark_folds_platform_updates(benchmark_mode):
        bundle_limits["GitHub Platform Updates"] = 10
    for name, values in bundles.items():
        seen: set[str] = set()
        unique: list[dict[str, object]] = []
        for item in sorted(values, key=sort_key):
            title = str(item["title"])
            if title in seen:
                continue
            seen.add(title)
            unique.append(item)
        bundles[name] = unique[: bundle_limits[name]]

    return bundles


def parse_relevance(raw: str) -> int:
    match = re.search(r"(\d+)\s*/\s*10", raw or "")
    return int(match.group(1)) if match else 0


def shorten(text: str, width: int) -> str:
    cleaned = " ".join((text or "").split())
    if not cleaned:
        return ""
    return textwrap.shorten(cleaned, width=width, placeholder="...")


def extract_curator_signals(path: Path) -> list[str]:
    if not path.exists():
        return []

    lines = path.read_text(encoding="utf-8").splitlines()
    signals: list[str] = []
    in_emphasis = False
    current_heading = ""
    action_line = ""

    for line in lines:
        if line.startswith("## Emphasis Signals"):
            in_emphasis = True
            continue
        if in_emphasis and line.startswith("## "):
            if current_heading and action_line:
                signals.append(f"- {current_heading}: {action_line}")
            break
        if not in_emphasis:
            continue
        if line.startswith("### "):
            if current_heading and action_line:
                signals.append(f"- {current_heading}: {action_line}")
            current_heading = re.sub(r"^\d+\.\s*", "", line[4:].strip())
            action_line = ""
            continue
        if line.startswith("**Action for Phase 3**:"):
            action_line = line.split(":", 1)[1].strip()

    if current_heading and action_line:
        signals.append(f"- {current_heading}: {action_line}")

    theme_lines: list[str] = []
    capture_theme = False
    for line in lines:
        if line.startswith("## Theme Recommendations for Phase 3"):
            capture_theme = True
            continue
        if capture_theme and line.startswith("## "):
            break
        if capture_theme and re.match(r"^\d+\.\s+\*\*", line):
            match = re.match(r"^\d+\.\s+\*\*(.+?)\*\*:\s*(.*)$", line)
            if match:
                theme_lines.append(f"- {match.group(1)}: {match.group(2)}")

    return signals[:5] + theme_lines[:5]


def render_item(item: dict[str, object]) -> list[str]:
    fields = item["fields"]
    title = str(item["title"])
    date = str(fields.get("date", "n/a"))
    score = parse_relevance(str(fields.get("relevance_score", "")))
    ide = str(fields.get("ide_support", "n/a"))
    description = shorten(str(fields.get("description", "")), 220)
    impact = shorten(str(fields.get("enterprise_impact", "")), 180)
    sources = shorten(str(fields.get("sources", "")), 240)
    metadata = [f"score {score}/10"]
    if date != "n/a":
        metadata.append(date)
    if ide != "n/a":
        metadata.append(ide)
    return [
        f"- **{title}** | {' | '.join(metadata)}",
        f"  Summary: {description}",
        f"  Impact: {impact}",
        f"  Links: {sources}",
    ]


def render_section(title: str, items: list[dict[str, object]]) -> list[str]:
    if not items:
        return [f"### {title}", "- No in-scope items found."]

    ordered = sorted(
        items,
        key=lambda item: (
            -parse_relevance(str(item["fields"].get("relevance_score", ""))),
            str(item["fields"].get("date", "")),
            str(item["title"]),
        ),
    )
    lines = [f"### {title}"]
    for item in ordered:
        lines.extend(render_item(item))
    return lines


def render_ide_seed(path: Path, label: str) -> list[str]:
    if not path.exists():
        return [f"### {label}", f"- [MISSING_DATA] {path}"]

    items = parse_phase1b_items(path)
    if not items:
        return [f"### {label}", f"- [MISSING_DATA] Could not parse IDE interim file: {path}"]
    filtered = [
        item
        for item in items
        if parse_relevance(str(item["fields"].get("relevance_score", ""))) >= 7
    ]
    if not filtered:
        filtered = items[:3]
    filtered = filtered[:4]

    lines = [f"### {label}"]
    for item in filtered:
        title = str(item["title"])
        score = parse_relevance(str(item["fields"].get("relevance_score", "")))
        summary = shorten(str(item["fields"].get("description", "")), 180)
        links = str(item["fields"].get("sources", ""))
        lines.append(f"- **{title}** | score {score}/10")
        lines.append(f"  Summary: {summary}")
        lines.append(f"  Links: {links}")
    return lines


def bullet_floor(start: str, end: str) -> int:
    start_date = dt.date.fromisoformat(start)
    end_date = dt.date.fromisoformat(end)
    window_days = (end_date - start_date).days + 1
    if window_days >= 60:
        return 24
    if window_days >= 30:
        return 18
    return 12


def main() -> int:
    args = parse_args()
    parse_completeness_threshold = resolve_parse_completeness_threshold(
        args.parse_completeness_threshold
    )

    workspace = Path("workspace")
    discoveries = workspace / f"newsletter_phase1a_discoveries_{args.start}_to_{args.end}.md"
    curated = workspace / f"newsletter_phase3_curated_sections_{args.end}.md"
    output = workspace / f"newsletter_phase3_working_set_{args.end}.md"
    cycle_ym = args.end[:7]
    curator_signals = workspace / f"curator_notes_editorial_signals_{cycle_ym}.md"
    visualstudio = workspace / f"newsletter_phase1b_interim_visualstudio_{args.start}_to_{args.end}.md"
    jetbrains = workspace / f"newsletter_phase1b_interim_jetbrains_{args.start}_to_{args.end}.md"
    xcode = workspace / f"newsletter_phase1b_interim_xcode_{args.start}_to_{args.end}.md"

    expected_inputs = [discoveries, visualstudio, jetbrains, xcode]
    missing = [str(path) for path in expected_inputs if not path.exists()]
    if not discoveries.exists():
        raise SystemExit(f"Missing required discoveries file: {discoveries}")

    discovery_items = parse_discovery_items(discoveries)
    parse_receipt = build_parse_receipt(
        discoveries, discovery_items, threshold=parse_completeness_threshold
    )
    bundles = build_discovery_bundles(discovery_items, args.benchmark_mode)
    folds_platform_updates = benchmark_folds_platform_updates(args.benchmark_mode)

    rules = [
        f"- Target bullet floor for this window: {bullet_floor(args.start, args.end)} bullets.",
        "- Required sections: optional lead, `# Copilot`, `## Latest Releases`, `## IDE Parity`, `## Enterprise and Security Updates`, `## Resources and Best Practices`.",
        "- Keep Copilot CLI in the Copilot section and include DPA + Pre-Release Terms links while CLI remains pre-release.",
        "- Remove every TODO marker and HTML comment before receipt recording.",
        "- Use inline markdown links only. No raw URLs. No em dashes.",
        "- IDE Parity must use one parent bullet with nested bullets plus the standard rollout note.",
        "- V2 readiness: compress model availability/model update items into one curated bullet.",
        "- V2 readiness: include competitive, platform-choice, customer-choice, or agent-provider-choice language when the source bundle contains those signals.",
        "- V2 readiness: keep official source links close to each main bullet and preserve link density for final assembly.",
        "- V2 readiness: preserve every explicit VS Code version token from the source context instead of summarizing only a version range.",
    ]
    if folds_platform_updates:
        rules.append(
            "- Benchmark mode folds GitHub platform-only items into Enterprise and Security Updates; do not emit a dedicated `## GitHub Platform Updates` section."
        )
    else:
        rules.append(
            "- Include `## GitHub Platform Updates` unless benchmark mode explicitly folds platform items into Enterprise and Security."
        )
    if args.benchmark_mode:
        rules.append(
            f"- Active benchmark mode: {args.benchmark_mode}. Respect any benchmark-specific section folding already encoded in this run."
        )

    lines: list[str] = [
        "# Phase 3 Working Set",
        f"**Date Range**: {args.start} to {args.end}",
        f"**Generated**: {dt.datetime.now(dt.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}",
        f"**Input Source**: {parse_receipt['input_source']}",
        (
            "**Parse Completeness**: "
            f"Parsed {parse_receipt['parsed_total']}/{parse_receipt['expected_total']} items "
            f"({parse_receipt['percent']:.1f}%)"
        ),
        f"**Parse Threshold**: {parse_receipt['threshold']:.1f}%",
        "",
        "## Execution Contract",
        "- Read this file first. It compiles the Phase 3 rules, candidate bundles, curator emphasis, and IDE parity seed for this run.",
        f"- Primary write target: `{curated}`",
        "- Read the current curated file only to continue editing. Do not restart from scratch after the scaffold exists.",
        "- Do not open raw discoveries, interim IDE files, skill references, or editorial-intelligence unless this file explicitly marks missing data.",
        "- Record `phase3_curated` only after the curated artifact passes `python3 tools/validate_phase3_curated.py START END <artifact>`.",
        "",
    ]

    if not discovery_items:
        missing.append(f"Could not parse discovery items from {discoveries}")
    if parse_receipt["below_threshold"]:
        missing.append(
            "Parse completeness below floor: "
            f"{parse_receipt['parsed_total']}/{parse_receipt['expected_total']} items "
            f"({parse_receipt['percent']:.1f}% < {parse_receipt['threshold']:.1f}%)."
        )

    if missing:
        lines.extend(
            [
                "## Missing Data Gate",
                "[MISSING_DATA]",
                *[f"- {path}" for path in missing],
                "",
            ]
        )
    else:
        lines.extend(
            [
                "## Missing Data Gate",
                "- No missing prerequisite data detected for the compact Phase 3 path.",
                "",
            ]
        )

    lines.extend(["## Writing Rules", *rules, ""])

    lines.extend(
        [
            "## Benchmark Structure Snapshot",
            "- Use a content-driven lead only if one theme clearly dominates.",
            "- `# Copilot` should contain `## Latest Releases` and `## IDE Parity`.",
            "- `## Enterprise and Security Updates` should carry governance, billing, security, and migration items.",
            "- `## Resources and Best Practices` should carry enablement material, model prompting guides, and community/operator references when present.",
            "- Use bold headlines with concise enterprise-oriented descriptions and inline source links.",
            "",
        ]
    )
    if folds_platform_updates:
        lines.insert(
            len(lines) - 1,
            "- Benchmark mode folds platform-only items into `## Enterprise and Security Updates`; do not create `## GitHub Platform Updates` for this run.",
        )

    curator_lines = extract_curator_signals(curator_signals)
    lines.append("## Curator Signals")
    if curator_lines:
        lines.extend(curator_lines)
    else:
        lines.append("- No curator signals file found for this cycle.")
    lines.append("")

    lines.append("## Discovery Bundles")
    section_order = [
        "Monthly Announcement Candidates",
        "Copilot Latest Releases",
        "Copilot at Scale (Governance & Administration)",
        "Deprecations and Migrations",
    ]
    if not folds_platform_updates:
        section_order.insert(3, "GitHub Platform Updates")
    for section in section_order:
        lines.extend(render_section(section, bundles.get(section, [])))
        lines.append("")

    lines.extend(
        [
            "## IDE Parity Seed",
            "- Use these condensed IDE extracts instead of rereading the full interim files unless a required detail is missing.",
        ]
    )
    lines.extend(render_ide_seed(visualstudio, "Visual Studio"))
    lines.append("")
    lines.extend(render_ide_seed(jetbrains, "JetBrains"))
    lines.append("")
    lines.extend(render_ide_seed(xcode, "Xcode"))
    lines.append("")

    lines.extend(
        [
            "## Mandatory Links",
            "- Copilot DPA previews: [DPA-Covered Previews](https://docs.github.com/en/site-policy/github-terms/github-dpa-previews)",
            "- Copilot pre-release terms: [Pre-Release License Terms](https://docs.github.com/en/site-policy/github-terms/github-pre-release-license-terms)",
            "- Copilot CLI releases: [Copilot CLI Releases](https://github.com/github/copilot-cli/releases)",
            "- Copilot changelog feed: [GitHub Copilot Changelog](https://github.blog/changelog/label/copilot/feed/)",
            "- VS Code Copilot changelog: [VS Code Copilot Changelog](https://code.visualstudio.com/updates/#_github-copilot)",
            "- Visual Studio Copilot changelog: [Visual Studio Copilot Changelog](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes#github-copilot)",
            "- JetBrains Copilot changelog: [JetBrains Copilot Changelog](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable)",
            "- Xcode Copilot changelog: [Xcode Copilot Changelog](https://github.com/github/CopilotForXcode/blob/main/CHANGELOG.md)",
            "",
        ]
    )

    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    if parse_receipt["below_threshold"]:
        print(
            "ERROR: parse completeness below floor for "
            f"{discoveries}: {parse_receipt['parsed_total']}/{parse_receipt['expected_total']} "
            f"({parse_receipt['percent']:.1f}% < {parse_receipt['threshold']:.1f}%)",
            file=sys.stderr,
        )
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

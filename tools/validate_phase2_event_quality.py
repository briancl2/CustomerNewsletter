#!/usr/bin/env python3
"""Validate Phase 2 event coverage and event-source quality."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
from collections import Counter
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("events_path")
    parser.add_argument("start")
    parser.add_argument("end")
    parser.add_argument("strict_mode")
    parser.add_argument("event_sources_path")
    parser.add_argument("strict_production_artifacts")
    parser.add_argument("benchmark_mode")
    parser.add_argument("note_paths", nargs="*")
    return parser.parse_args()


def is_table_row(line: str) -> bool:
    stripped = line.strip()
    if not stripped.startswith("|"):
        return False
    if re.match(r"^\|\s*-[-\s|:]*\|?$", stripped):
        return False
    if re.match(r"^\|\s*Event\s*\|\s*Date\s*\|", stripped, re.IGNORECASE):
        return False
    if re.match(r"^\|\s*Date\s*\|\s*Event\s*\|", stripped, re.IGNORECASE):
        return False
    return True


def load_event_sources(path: Path) -> tuple[list[str], bool]:
    event_sources = json.loads(path.read_text(encoding="utf-8"))
    candidates = event_sources.get("candidate_urls", [])
    if not isinstance(candidates, list):
        candidates = []

    candidate_urls: list[str] = []
    for item in candidates:
        if isinstance(item, dict):
            url = item.get("url")
            if isinstance(url, str) and url.strip():
                candidate_urls.append(url.strip().rstrip("/"))

    sources = event_sources.get("sources", [])
    if not isinstance(sources, list):
        sources = []
    fetch_rows = [row for row in sources if isinstance(row, dict) and row.get("kind") == "web"]
    fetches_succeeded = bool(fetch_rows) and all(row.get("fetch_ok") is True for row in fetch_rows)
    return candidate_urls, fetches_succeeded


def main() -> int:
    args = parse_args()
    events_path = Path(args.events_path)
    start = dt.datetime.strptime(args.start, "%Y-%m-%d").date()
    end = dt.datetime.strptime(args.end, "%Y-%m-%d").date()
    strict_mode = args.strict_mode == "1"
    event_sources_path = Path(args.event_sources_path)
    strict_production_artifacts = args.strict_production_artifacts == "1"
    benchmark_mode = bool(args.benchmark_mode.strip())
    note_paths = [Path(p) for p in args.note_paths]
    corpus_aware_event_floor = os.environ.get("NEWSLETTER_PHASE2_CORPUS_AWARE_EVENT_FLOOR") == "1"

    today = dt.datetime.now(dt.timezone.utc).date()
    effective_end = end if end <= today else today
    future_boundary = end > today

    text = events_path.read_text(encoding="utf-8", errors="ignore")
    lines = text.splitlines()

    section = ""
    virtual_rows = 0
    in_person_rows = 0
    table_row_urls: list[str] = []
    for line in lines:
        if line.startswith("## "):
            section = line.lower()
            continue
        if is_table_row(line):
            table_row_urls.extend(re.findall(r"\[[^\]]+\]\((https?://[^)\s]+)\)", line))
            if "virtual events" in section:
                virtual_rows += 1
            elif "in-person events" in section or "in person events" in section:
                in_person_rows += 1

    total_rows = virtual_rows + in_person_rows
    day_span = (effective_end - start).days + 1 if effective_end >= start else 0
    if day_span >= 60:
        min_total = 12
    elif day_span >= 30:
        min_total = 8
    else:
        min_total = 4

    has_reactor = ("developer.microsoft.com/en-us/reactor" in text) or ("reactor/events/" in text)
    has_github_resources = ("github.com/resources/events" in text) or ("github.registration.goldcast.io" in text)
    mentions_kuwc = "kuwc" in text.lower()

    normalized_row_urls = [u.rstrip("/") for u in table_row_urls]
    row_counter = Counter(normalized_row_urls)
    max_reuse = max(row_counter.values()) if row_counter else 0

    banned_exact = {
        "https://resources.github.com/events",
        "https://github.com/resources/events",
        "https://resources.github.com/copilot-fridays-english-on-demand",
        "https://developer.microsoft.com/en-us/reactor/search",
    }
    banned_patterns = [
        re.compile(r"^https://developer\.microsoft\.com/en-us/reactor/\?search=", re.IGNORECASE),
        re.compile(r"^https://developer\.microsoft\.com/en-us/reactor/search", re.IGNORECASE),
    ]
    generic_urls = sorted(
        {
            url
            for url in normalized_row_urls
            if url in banned_exact or any(p.search(url) for p in banned_patterns)
        }
    )
    too_reused = sorted(url for url, count in row_counter.items() if count > 2)

    candidate_urls: list[str] = []
    source_fetches_succeeded = False
    event_sources_loaded = False
    event_sources_error = ""
    if event_sources_path.exists():
        try:
            candidate_urls, source_fetches_succeeded = load_event_sources(event_sources_path)
            event_sources_loaded = True
        except Exception as exc:  # noqa: BLE001
            event_sources_error = str(exc)

    github_deep = sorted(
        {
            url
            for url in candidate_urls
            if re.match(r"^https://github\.com/resources/events/[a-z0-9-]+$", url, re.IGNORECASE)
        }
    )
    reactor_deep = sorted(
        {
            url
            for url in candidate_urls
            if re.match(r"^https://developer\.microsoft\.com/en-us/reactor/events/[0-9]+$", url, re.IGNORECASE)
        }
    )

    github_fail_floor = 5
    github_warn_floor = 5
    if strict_production_artifacts and not benchmark_mode:
        github_fail_floor = 3
        github_warn_floor = 3

    github_floor_ok = future_boundary or len(github_deep) >= github_fail_floor
    reactor_floor_ok = future_boundary or len(reactor_deep) >= 6
    row_quality_ok = bool(normalized_row_urls) and len(row_counter) >= 6 and max_reuse <= 2 and not generic_urls
    floor_lowering_allowed = (
        corpus_aware_event_floor
        and strict_mode
        and not benchmark_mode
        and strict_production_artifacts
        and not future_boundary
        and min_total == 8
        and total_rows == 7
        and virtual_rows > 0
        and in_person_rows > 0
        and event_sources_loaded
        and source_fetches_succeeded
        and github_floor_ok
        and reactor_floor_ok
        and row_quality_ok
    )

    print(f"PASS: Event coverage stats: virtual={virtual_rows} in_person={in_person_rows} total={total_rows} min_required={min_total}")
    if floor_lowering_allowed:
        print(
            "PASS: Corpus-aware event floor accepted current-cycle event scarcity "
            f"(total={total_rows}, nominal_min={min_total}, accepted_min=7)"
        )
    if future_boundary:
        print(
            "WARN: Event validation range extends past today; "
            f"coverage floors use observable range through {effective_end.isoformat()}"
        )
    if total_rows < min_total and not floor_lowering_allowed:
        print(f"FAIL: Event coverage too low for {day_span}-day range ({total_rows} < {min_total})")
    if virtual_rows == 0:
        print("FAIL: No virtual events found in Phase 2 output")
    if day_span >= 30 and in_person_rows == 0:
        print("WARN: No in-person events found for a 30+ day range")
    if not has_reactor:
        print("WARN: No Reactor-linked events found; confirm Reactor scan/filter step")
    if not has_github_resources:
        print("WARN: No GitHub Resources/Goldcast event links found; confirm source coverage")

    print(f"PASS: Event row URL stats: unique={len(row_counter)} rows_with_links={len(normalized_row_urls)} max_reuse={max_reuse}")

    if generic_urls:
        joined = ", ".join(generic_urls)
        if strict_mode:
            print(f"FAIL: Generic event URLs found in event rows (strict mode): {joined}")
        else:
            print(f"WARN: Generic event URLs found in event rows: {joined}")

    if too_reused:
        summary = ", ".join(f"{url} ({row_counter[url]}x)" for url in too_reused)
        if strict_mode:
            print(f"FAIL: Event URL reuse exceeds threshold (>2 duplicates): {summary}")
        else:
            print(f"WARN: Event URL reuse exceeds threshold (>2 duplicates): {summary}")

    if event_sources_loaded:
        print(
            "PASS: Event source deep-link stats: "
            f"github_resources={len(github_deep)} reactor={len(reactor_deep)}"
        )
        print(
            "PASS: Event source fetch stats: "
            f"all_web_fetches_succeeded={str(source_fetches_succeeded).lower()}"
        )
        github_floor_strict = strict_mode and not future_boundary
        reactor_floor_strict = strict_mode and not future_boundary
        if github_floor_strict and len(github_deep) < github_fail_floor:
            print(
                "FAIL: Phase 2 event sources deep-link floor not met for GitHub Resources "
                f"({len(github_deep)} < {github_fail_floor})"
            )
        elif len(github_deep) < github_warn_floor:
            print(
                "WARN: Phase 2 event sources deep-link floor low for GitHub Resources "
                f"({len(github_deep)} < {github_warn_floor})"
            )

        if reactor_floor_strict and len(reactor_deep) < 6:
            print(
                f"FAIL: Phase 2 event sources deep-link floor not met for Reactor ({len(reactor_deep)} < 6)"
            )
        elif len(reactor_deep) < 6:
            print(
                f"WARN: Phase 2 event sources deep-link floor low for Reactor ({len(reactor_deep)} < 6)"
            )
        if strict_mode and not source_fetches_succeeded:
            print("FAIL: Phase 2 event source web fetches did not all succeed")
    elif event_sources_error:
        print(f"FAIL: Could not parse event sources artifact: {event_sources_error}")
        return 2
    else:
        if strict_mode:
            print(f"FAIL: Phase 2 event sources artifact missing: {event_sources_path}")
        else:
            print(f"WARN: Phase 2 event sources artifact missing: {event_sources_path}")

    notes_text = ""
    for note_path in note_paths:
        if note_path.exists():
            notes_text += note_path.read_text(encoding="utf-8", errors="ignore") + "\n"

    if notes_text:
        notes_lower = notes_text.lower()
        if "kuwc" in notes_lower and not mentions_kuwc:
            print("WARN: Curator notes mention KUWC but Phase 2 output has no KUWC entry")
        if ("reactor" in notes_lower or "developer.microsoft.com/en-us/reactor" in notes_lower) and not has_reactor:
            print("WARN: Curator notes mention Reactor but Phase 2 output has no Reactor-linked event")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Deterministically extract Phase 2 candidate event URLs.

Usage:
  python3 tools/extract_event_sources.py START_DATE END_DATE

Output:
  workspace/newsletter_phase2_event_sources_<END_DATE>.json
"""

from __future__ import annotations

import argparse
import datetime as dt
import glob
import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = ROOT / "kb" / "EVENT_SOURCES.yaml"
WORKSPACE = ROOT / "workspace"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract deterministic event-source candidates")
    parser.add_argument("start", help="Start date (YYYY-MM-DD)")
    parser.add_argument("end", help="End date (YYYY-MM-DD)")
    return parser.parse_args()


def validate_date(value: str) -> str:
    try:
        dt.datetime.strptime(value, "%Y-%m-%d")
    except ValueError as exc:
        raise SystemExit(f"Invalid date '{value}', expected YYYY-MM-DD") from exc
    return value


def load_config(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise SystemExit(f"Config file not found: {path}")
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit(f"Config must be a mapping: {path}")
    return data


def fetch_text(url: str, timeout: int = 30) -> dict[str, Any]:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (compatible; newsletter-event-extractor/1.0)",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            status = getattr(resp, "status", 200)
            raw = resp.read()
            encoding = resp.headers.get_content_charset() or "utf-8"
            text = raw.decode(encoding, errors="ignore")
            return {
                "fetch_ok": True,
                "status_code": int(status),
                "bytes": len(raw),
                "text": text,
                "error": "",
            }
    except urllib.error.HTTPError as exc:
        return {
            "fetch_ok": False,
            "status_code": int(exc.code),
            "bytes": 0,
            "text": "",
            "error": f"HTTPError: {exc}",
        }
    except Exception as exc:  # noqa: BLE001
        return {
            "fetch_ok": False,
            "status_code": 0,
            "bytes": 0,
            "text": "",
            "error": f"FetchError: {exc}",
        }


def normalize_url(url: str) -> str:
    cleaned = url.strip()
    cleaned = cleaned.split("#", 1)[0]
    if cleaned.endswith(")") and cleaned.count("(") < cleaned.count(")"):
        cleaned = cleaned[:-1]
    return cleaned.rstrip("/")


def extract_github_resources_deeplinks(text: str) -> set[str]:
    found: set[str] = set()

    for match in re.findall(r"https?://github\.com/resources/events/[a-z0-9-]+", text, flags=re.IGNORECASE):
        found.add(normalize_url(match))

    for match in re.findall(r"/resources/events/[a-z0-9-]+", text, flags=re.IGNORECASE):
        found.add(normalize_url(f"https://github.com{match}"))

    # Exclude landing page if ever captured
    found.discard("https://github.com/resources/events")
    return found


def extract_reactor_event_deeplinks(text: str) -> set[str]:
    found: set[str] = set()

    for event_id in re.findall(
        r"https?://developer\.microsoft\.com/(?:en-us/)?reactor/events/([0-9]+)/?",
        text,
        flags=re.IGNORECASE,
    ):
        found.add(f"https://developer.microsoft.com/en-us/reactor/events/{event_id}")

    for event_id in re.findall(r"/(?:en-us/)?reactor/events/([0-9]+)/?", text, flags=re.IGNORECASE):
        found.add(f"https://developer.microsoft.com/en-us/reactor/events/{event_id}")

    return found


def load_curator_note_paths(config: dict[str, Any]) -> list[Path]:
    notes_cfg = config.get("curator_notes", {})
    if not isinstance(notes_cfg, dict):
        return []

    include_globs = notes_cfg.get("globs", [])
    exclude_globs = notes_cfg.get("exclude_globs", [])
    if not isinstance(include_globs, list):
        include_globs = []
    if not isinstance(exclude_globs, list):
        exclude_globs = []

    included: set[Path] = set()
    for pattern in include_globs:
        if not isinstance(pattern, str):
            continue
        for path in glob.glob(str(ROOT / pattern)):
            included.add(Path(path))

    excluded: set[Path] = set()
    for pattern in exclude_globs:
        if not isinstance(pattern, str):
            continue
        for path in glob.glob(str(ROOT / pattern)):
            excluded.add(Path(path))

    resolved = sorted(p for p in included if p.exists() and p not in excluded)
    return resolved


def extract_curator_urls(text: str, allowed_patterns: list[str]) -> set[str]:
    urls = set(re.findall(r"https?://[^\s)>\]\"']+", text))
    regexes = [re.compile(pat, flags=re.IGNORECASE) for pat in allowed_patterns if isinstance(pat, str)]

    kept: set[str] = set()
    for url in urls:
        clean = normalize_url(url)
        if any(regex.search(clean) for regex in regexes):
            kept.add(clean)
    return kept


def add_candidate(
    merged: dict[str, dict[str, Any]],
    url: str,
    source_type: str,
    source_name: str,
) -> None:
    entry = merged.setdefault(
        url,
        {
            "url": url,
            "source_types": set(),
            "source_names": set(),
        },
    )
    entry["source_types"].add(source_type)
    entry["source_names"].add(source_name)


def main() -> int:
    args = parse_args()
    start = validate_date(args.start)
    end = validate_date(args.end)
    # Date range is metadata/provenance for this deterministic candidate artifact.
    # Phase 2 filtering and final curation happen downstream.

    config = load_config(CONFIG_PATH)

    github_resources_url = config.get("github_resources_events_url", "")
    reactor_series_seed_urls = config.get("reactor_series_seed_urls", [])

    if not isinstance(github_resources_url, str) or not github_resources_url:
        raise SystemExit("Missing github_resources_events_url in kb/EVENT_SOURCES.yaml")
    if not isinstance(reactor_series_seed_urls, list):
        raise SystemExit("reactor_series_seed_urls must be a list in kb/EVENT_SOURCES.yaml")

    WORKSPACE.mkdir(parents=True, exist_ok=True)
    out_path = WORKSPACE / f"newsletter_phase2_event_sources_{end}.json"

    merged: dict[str, dict[str, Any]] = {}
    sources: list[dict[str, Any]] = []

    # Source 1: GitHub Resources events page
    github_fetch = fetch_text(github_resources_url)
    github_candidates = (
        sorted(extract_github_resources_deeplinks(github_fetch["text"]))
        if github_fetch["fetch_ok"]
        else []
    )
    for url in github_candidates:
        add_candidate(merged, url, "github_resources", "github_resources_events")
    sources.append(
        {
            "name": "github_resources_events",
            "kind": "web",
            "url_or_path": github_resources_url,
            "fetch_ok": github_fetch["fetch_ok"],
            "status_code": github_fetch["status_code"],
            "bytes": github_fetch["bytes"],
            "error": github_fetch["error"],
            "candidate_urls": github_candidates,
        }
    )

    # Source 2..N: Reactor series pages
    for index, series_url in enumerate(reactor_series_seed_urls, start=1):
        if not isinstance(series_url, str) or not series_url:
            continue
        fetch = fetch_text(series_url)
        candidates = sorted(extract_reactor_event_deeplinks(fetch["text"])) if fetch["fetch_ok"] else []
        source_name = f"reactor_series_{index}"
        for url in candidates:
            add_candidate(merged, url, "reactor", source_name)
        sources.append(
            {
                "name": source_name,
                "kind": "web",
                "url_or_path": series_url,
                "fetch_ok": fetch["fetch_ok"],
                "status_code": fetch["status_code"],
                "bytes": fetch["bytes"],
                "error": fetch["error"],
                "candidate_urls": candidates,
            }
        )

    # Source: Curator notes (optional)
    notes_cfg = config.get("curator_notes", {})
    allowed_patterns = []
    if isinstance(notes_cfg, dict):
        allowed_patterns = notes_cfg.get("allowed_url_patterns", []) or []

    curator_paths = load_curator_note_paths(config)
    for path in curator_paths:
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except Exception as exc:  # noqa: BLE001
            sources.append(
                {
                    "name": f"curator_note::{path.name}",
                    "kind": "file",
                    "url_or_path": str(path.relative_to(ROOT)),
                    "fetch_ok": False,
                    "status_code": 0,
                    "bytes": 0,
                    "error": f"ReadError: {exc}",
                    "candidate_urls": [],
                }
            )
            continue

        candidates = sorted(extract_curator_urls(text, allowed_patterns))
        source_name = f"curator_note::{path.name}"
        for url in candidates:
            add_candidate(merged, url, "curator", source_name)

        sources.append(
            {
                "name": source_name,
                "kind": "file",
                "url_or_path": str(path.relative_to(ROOT)),
                "fetch_ok": True,
                "status_code": 0,
                "bytes": len(text.encode("utf-8")),
                "error": "",
                "candidate_urls": candidates,
            }
        )

    candidate_urls = []
    for url in sorted(merged.keys()):
        entry = merged[url]
        candidate_urls.append(
            {
                "url": url,
                "source_types": sorted(entry["source_types"]),
                "source_names": sorted(entry["source_names"]),
            }
        )

    payload = {
        "schema_version": int(config.get("schema_version", 1)),
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "start": start,
        "end": end,
        "config_path": str(CONFIG_PATH.relative_to(ROOT)),
        "sources": sources,
        "candidate_urls": candidate_urls,
    }

    out_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    github_count = sum(1 for item in candidate_urls if "github_resources" in item["source_types"])
    reactor_count = sum(1 for item in candidate_urls if "reactor" in item["source_types"])
    curator_count = sum(1 for item in candidate_urls if "curator" in item["source_types"])

    print(f"Wrote {out_path}")
    print(
        "Candidate summary: "
        f"total={len(candidate_urls)} github_resources={github_count} reactor={reactor_count} curator={curator_count}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

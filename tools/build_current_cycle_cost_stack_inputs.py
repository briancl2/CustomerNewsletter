#!/usr/bin/env python3
"""Build current-cycle fixture and no-refetch inputs for the opt-in cost stack."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
from pathlib import Path
from typing import Any

from newsletter_experiment_common import load_json, sha256_path, sha256_text, write_json
from product_run_common import resolved_artifact_map


PHASE2_ENTRY_ARTIFACTS = [
    "marker",
    "receipts",
    "scope_contract",
    "manifest",
    "phase1b_github",
    "phase1b_vscode",
    "phase1b_visualstudio",
    "phase1b_jetbrains",
    "phase1b_xcode",
    "discoveries",
    "event_sources",
    "phase2_selected_source_ids",
    "phase2_fetch_attempt_ledger",
    "phase2_no_refetch_compliance",
]

GENERATED_NO_REFETCH_ARTIFACTS = {
    "phase2_selected_source_ids",
    "phase2_fetch_attempt_ledger",
    "phase2_no_refetch_compliance",
}

MARKDOWN_LINK_RE = re.compile(r"\[([^\]]+)\]\((https?://[^)]+)\)")
RAW_URL_RE = re.compile(r"https?://[^\s)>\"]+")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--start", required=True, help="Cycle start date, YYYY-MM-DD")
    parser.add_argument("--end", required=True, help="Cycle end date, YYYY-MM-DD")
    parser.add_argument(
        "--source-root",
        required=True,
        help="Baseline owner worktree/root containing current-cycle workspace artifacts",
    )
    parser.add_argument(
        "--output-dir",
        required=True,
        help="Directory where the generated manifest, admission, and sidecars are written",
    )
    parser.add_argument(
        "--manifest-id",
        default="burst160_current_cycle_cost_stack_inputs",
        help="Stable fixture manifest id",
    )
    parser.add_argument("--mode", default="current_cycle_cost_stack")
    return parser.parse_args()


def stable_hash(payload: Any) -> str:
    return sha256_text(json.dumps(payload, sort_keys=True, separators=(",", ":")))


def section_id(raw: str) -> str:
    text = raw.strip().lower()
    text = re.sub(r"[^a-z0-9]+", "_", text).strip("_")
    return text or "unknown"


def extract_event_links(path: Path) -> list[dict[str, str]]:
    links: list[dict[str, str]] = []
    current_section = "unknown"
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            current_section = section_id(line[3:])
            continue
        for match in MARKDOWN_LINK_RE.finditer(line):
            links.append(
                {
                    "url": match.group(2).strip(),
                    "title": match.group(1).strip(),
                    "section": current_section,
                    "source": "markdown_link",
                }
            )
        linked_urls = {item["url"] for item in links if item.get("section") == current_section}
        for raw_match in RAW_URL_RE.finditer(line):
            url = raw_match.group(0).rstrip(".,;:")
            if url not in linked_urls:
                links.append(
                    {
                        "url": url,
                        "title": "",
                        "section": current_section,
                        "source": "raw_url",
                    }
                )
    return links


def candidate_index(event_sources: dict[str, Any]) -> dict[str, dict[str, Any]]:
    rows = event_sources.get("candidate_urls")
    if not isinstance(rows, list):
        raise SystemExit("event_sources candidate_urls is missing or not a list")
    index: dict[str, dict[str, Any]] = {}
    for row in rows:
        if not isinstance(row, dict):
            continue
        url = str(row.get("url") or "").strip()
        if url:
            index[url] = row
    if not index:
        raise SystemExit("event_sources has no candidate URL rows")
    return index


def selected_source_rows(events_path: Path, event_sources: dict[str, Any]) -> list[dict[str, Any]]:
    selected: list[dict[str, Any]] = []
    seen: set[str] = set()
    by_url = candidate_index(event_sources)
    for order, link in enumerate(extract_event_links(events_path), start=1):
        url = link["url"]
        if url in seen or url not in by_url:
            continue
        seen.add(url)
        candidate = by_url[url]
        selected.append(
            {
                "section": link["section"],
                "order": len(selected) + 1,
                "source_id": url,
                "title": link["title"] or candidate.get("title"),
                "date_label": candidate.get("date_label"),
                "source_types": candidate.get("source_types", []),
                "source_names": candidate.get("source_names", []),
                "selection_source": link["source"],
                "markdown_order": order,
            }
        )
    if not selected:
        raise SystemExit("phase2 events artifact contains no selected URLs matching event_sources")
    return selected


def artifact_entry(name: str, logical_path: str, path: Path, source_root: Path) -> dict[str, Any]:
    return {
        "artifact_name": name,
        "logical_path": logical_path,
        "source_path": str(path.resolve()),
        "exists": path.exists(),
        "sha256": sha256_path(path) if path.exists() else None,
        "size_bytes": path.stat().st_size if path.exists() else None,
    }


def build_surface(source_root: Path, output_dir: Path, start: str, end: str) -> list[dict[str, Any]]:
    artifacts = resolved_artifact_map(source_root, start, end)
    surface: list[dict[str, Any]] = []
    missing: list[str] = []
    for name in PHASE2_ENTRY_ARTIFACTS:
        payload = artifacts[name]
        logical_path = str(payload["logical_path"])
        path = (
            output_dir / logical_path
            if name in GENERATED_NO_REFETCH_ARTIFACTS
            else Path(payload["resolved_path"])
        )
        row = artifact_entry(name, logical_path, path, source_root)
        surface.append(row)
        if not row["exists"]:
            missing.append(f"{name}:{logical_path}")
    if missing:
        raise SystemExit("missing required current-cycle artifacts: " + ", ".join(missing))
    return surface


def generated_artifact(path: Path) -> dict[str, Any]:
    return {
        "path": str(path.resolve()),
        "sha256": sha256_path(path),
        "size_bytes": path.stat().st_size,
    }


def main() -> int:
    args = parse_args()
    start = args.start
    end = args.end
    source_root = Path(args.source_root).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()
    if not source_root.exists():
        raise SystemExit(f"source root not found: {source_root}")
    workspace = output_dir / "workspace"
    workspace.mkdir(parents=True, exist_ok=True)

    artifacts = resolved_artifact_map(source_root, start, end)
    event_sources_path = Path(artifacts["event_sources"]["resolved_path"])
    events_path = Path(artifacts["events"]["resolved_path"])
    event_sources = load_json(event_sources_path)
    if not isinstance(event_sources, dict):
        raise SystemExit(f"event_sources artifact is missing or invalid: {event_sources_path}")
    if not events_path.exists():
        raise SystemExit(f"phase2 events artifact is missing: {events_path}")

    selected = selected_source_rows(events_path, event_sources)
    common = {
        "schema_version": 1,
        "run_id": f"{start}_to_{end}",
        "manifest_id": args.manifest_id,
        "surface_id": "phase2_entry_surface",
        "start": start,
        "end": end,
        "mode": args.mode,
        "event_sources_path": str(event_sources_path),
        "event_sources_sha256": sha256_path(event_sources_path),
        "events_path": str(events_path),
        "events_sha256": sha256_path(events_path),
    }

    selected_path = workspace / f"newsletter_phase2_selected_source_ids_{end}.json"
    fetch_path = workspace / f"newsletter_phase2_fetch_attempt_ledger_{end}.json"
    compliance_path = workspace / f"newsletter_phase2_no_refetch_compliance_{end}.json"
    write_json(
        selected_path,
        {
            **common,
            "artifact_kind": "phase2_selected_source_ids",
            "selected_source_ids": selected,
        },
    )
    write_json(
        fetch_path,
        {
            **common,
            "artifact_kind": "phase2_fetch_attempt_ledger",
            "network_access_permitted": False,
            "fetch_attempt_count": 0,
            "fetch_attempts": [],
        },
    )
    write_json(
        compliance_path,
        {
            **common,
            "artifact_kind": "phase2_no_refetch_compliance",
            "network_access_permitted": False,
            "fetch_attempt_count": 0,
            "compliance": "pass",
            "selected_source_ids_sha256": sha256_path(selected_path),
            "fetch_attempt_ledger_sha256": sha256_path(fetch_path),
            "reason": "Current-cycle no-refetch sidecars were generated from baseline Phase 2 artifacts only.",
        },
    )

    surface = build_surface(source_root, output_dir, start, end)
    manifest = {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "manifest_id": args.manifest_id,
        "run_id": f"{start}_to_{end}",
        "start": start,
        "end": end,
        "mode": args.mode,
        "source_artifact_root": str(source_root),
        "surfaces": {
            "phase2_entry_surface": surface,
        },
        "non_claims": [
            "This manifest binds current-cycle artifacts for opt-in stack execution only.",
            "It is not billing proof, durable savings proof, or production/default adoption.",
        ],
    }
    manifest_path = output_dir / "current-cycle-fixture-manifest.json"
    write_json(manifest_path, manifest)

    generated = {
        "phase2_selected_source_ids": generated_artifact(selected_path),
        "phase2_fetch_attempt_ledger": generated_artifact(fetch_path),
        "phase2_no_refetch_compliance": generated_artifact(compliance_path),
    }
    admission = {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "attempt_id": "burst160_current_cycle_deterministic_generation",
        "manifest_path": str(manifest_path),
        "manifest_sha256": sha256_path(manifest_path),
        "manifest_id": args.manifest_id,
        "source_run_id": f"{start}_to_{end}",
        "start": start,
        "end": end,
        "mode": args.mode,
        "surface_id": "phase2_entry_surface",
        "source_pack_sha256": stable_hash(surface),
        "event_sources_path": str(event_sources_path),
        "event_sources_sha256": sha256_path(event_sources_path),
        "events_path": str(events_path),
        "events_sha256": sha256_path(events_path),
        "selected_source_count": len(selected),
        "selected_source_ids": selected,
        "fetch_attempt_ledger": {
            "network_access_permitted": False,
            "fetch_attempt_count": 0,
        },
        "no_refetch_compliance": "pass",
        "generated_artifacts": generated,
        "admission_verdict": "admit_no_refetch",
        "blockers": [],
        "notes": "Generated from the current-cycle baseline run to bind stdout/no-tools stack inputs.",
        "non_claims": [
            "This receipt admits deterministic no-refetch binding for the opt-in stack only.",
            "It is not billing proof, durable savings proof, request-level provider-token proof, or production/default adoption.",
        ],
    }
    admission_path = output_dir / "current-cycle-no-refetch-admission.json"
    write_json(admission_path, admission)
    print(json.dumps({"manifest": str(manifest_path), "admission": str(admission_path)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

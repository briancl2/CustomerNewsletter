#!/usr/bin/env python3
"""Freeze one retained product run into a reusable experiment fixture manifest."""

from __future__ import annotations

import argparse
import datetime as dt
from pathlib import Path
from typing import Any

from product_run_common import resolved_artifact_map
from newsletter_experiment_common import load_json, sha256_path, write_json


SURFACES = {
    "phase0_to_phase1b_surface": [
        "marker",
        "receipts",
        "scope_contract",
        "manifest",
        "phase1b_github",
        "phase1b_vscode",
        "phase1b_visualstudio",
        "phase1b_jetbrains",
        "phase1b_xcode",
    ],
    "phase2_entry_surface": [
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
    ],
    "phase4_fast_surface": [
        "marker",
        "receipts",
        "scope_contract",
        "phase3_working_set",
        "phase3_curated",
        "events",
    ],
    "full_anchor_surface": [
        "marker",
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
        "events",
        "phase3_working_set",
        "phase3_curated",
        "phase45_polishing",
        "phase46_video_report",
        "scope_results",
        "editorial_review",
        "editorial_corrections",
        "output",
        "receipts",
    ],
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", required=True, help="Retained product run directory")
    parser.add_argument("--manifest-id", required=True, help="Stable manifest id")
    parser.add_argument("--output", required=True, help="Output manifest path")
    return parser.parse_args()


def build_surface_entries(artifacts: dict[str, Any], names: list[str]) -> list[dict[str, Any]]:
    rows = []
    repo = Path(__file__).resolve().parent.parent
    for name in names:
        payload = artifacts.get(name)
        if not payload:
            continue
        resolved = Path(str(payload["resolved_path"]))
        try:
            source_path = str(resolved.relative_to(repo))
        except ValueError:
            source_path = str(resolved)
        rows.append(
            {
                "artifact_name": name,
                "logical_path": payload["logical_path"],
                "source_path": source_path,
                "exists": resolved.exists(),
                "sha256": sha256_path(resolved) if resolved.exists() else None,
                "size_bytes": resolved.stat().st_size if resolved.exists() else None,
            }
        )
    return rows


def main() -> int:
    args = parse_args()
    run_dir = Path(args.run_dir).expanduser().resolve()
    metadata = load_json(run_dir / "run-metadata.json") or {}
    if not metadata:
        raise SystemExit(f"Missing run-metadata.json in {run_dir}")
    start = str(metadata.get("start") or "")
    end = str(metadata.get("end") or "")
    if not start or not end:
        raise SystemExit(f"Run metadata missing start/end in {run_dir}")

    artifact_root = run_dir / "artifacts"
    artifacts = resolved_artifact_map(artifact_root, start, end)
    payload = {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "manifest_id": args.manifest_id,
        "run_id": run_dir.name,
        "start": start,
        "end": end,
        "mode": metadata.get("mode"),
        "source_run_dir": str(run_dir.relative_to(Path(__file__).resolve().parent.parent)),
        "source_artifact_root": str(artifact_root.relative_to(Path(__file__).resolve().parent.parent)),
        "surfaces": {
            surface_id: build_surface_entries(artifacts, artifact_names)
            for surface_id, artifact_names in SURFACES.items()
        },
    }
    write_json(Path(args.output).expanduser().resolve(), payload)
    print(Path(args.output).expanduser().resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

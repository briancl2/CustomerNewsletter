#!/usr/bin/env python3
"""Backfill receipt_order into legacy newsletter receipt files."""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Any


PHASE_HINT_ORDER = {
    "phase0_scope_contract": 10,
    "phase1a_manifest": 20,
    "phase1b_github": 30,
    "phase1b_vscode": 31,
    "phase1b_visualstudio": 32,
    "phase1b_jetbrains": 33,
    "phase1b_xcode": 34,
    "phase1c_discoveries": 40,
    "phase1_5_curator_processed": 50,
    "phase1_5_curator_signals": 51,
    "phase2_event_sources": 60,
    "phase2_events": 61,
    "phase3_working_set": 70,
    "phase3_curated": 71,
    "phase4_5_polishing": 80,
    "phase4_editorial_review": 81,
    "phase4_output": 82,
    "phase4_6_video": 83,
    "phase4_scope_results": 84,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Backfill receipt_order into a legacy receipt file using retained artifact mtimes."
    )
    parser.add_argument("receipt_file", help="Path to newsletter_phase_receipts_*.json")
    parser.add_argument(
        "--artifact-root",
        required=True,
        help="Root directory that contains the retained workspace/ and output/ trees.",
    )
    return parser.parse_args()


def resolve_artifact_mtime(artifact_root: Path, receipt: dict[str, Any]) -> float:
    raw_path = receipt.get("artifact_path")
    if not isinstance(raw_path, str) or not raw_path.strip():
        return float(receipt.get("artifact_mtime_epoch") or 0)

    path = Path(raw_path)
    if path.is_absolute():
        resolved = path
    else:
        resolved = artifact_root / path
    if resolved.exists():
        return resolved.stat().st_mtime
    return float(receipt.get("artifact_mtime_epoch") or 0)


def normalize_receipts(artifact_root: Path, payload: dict[str, Any]) -> list[dict[str, Any]]:
    normalized: list[tuple[tuple[float, int, int], dict[str, Any]]] = []
    for index, receipt in enumerate(payload.get("receipts", []), start=1):
        item = dict(receipt)
        phase_id = str(item.get("phase_id", ""))
        recorded_at_epoch = item.get("recorded_at_epoch")
        if isinstance(recorded_at_epoch, str) and recorded_at_epoch.isdigit():
            recorded_at_epoch = int(recorded_at_epoch)
        if not isinstance(recorded_at_epoch, int):
            recorded_at_epoch = 0
        item["recorded_at_epoch"] = recorded_at_epoch

        mtime = resolve_artifact_mtime(artifact_root, item)
        phase_hint = PHASE_HINT_ORDER.get(phase_id, 1000 + index)
        normalized.append(((mtime, phase_hint, index), item))

    normalized.sort(key=lambda entry: entry[0])
    ordered_receipts: list[dict[str, Any]] = []
    for order, (_, receipt) in enumerate(normalized, start=1):
        receipt["receipt_order"] = order
        ordered_receipts.append(receipt)
    return ordered_receipts


def main() -> int:
    args = parse_args()
    receipt_file = Path(args.receipt_file).resolve()
    artifact_root = Path(args.artifact_root).resolve()

    payload = json.loads(receipt_file.read_text(encoding="utf-8"))
    payload["schema_version"] = 2
    payload["receipts"] = normalize_receipts(artifact_root, payload)
    payload["updated_at_utc"] = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    receipt_file.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Backfilled receipt_order for {len(payload['receipts'])} receipts: {receipt_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

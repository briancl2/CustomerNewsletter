#!/usr/bin/env python3
"""Validate that recorded phase receipts still match current artifact bytes."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from product_run_common import logical_artifact_map, receipt_phase_logical_paths

IMMUTABLE_RECEIPT_FIELDS = (
    "artifact_path",
    "artifact_sha256",
    "artifact_bytes",
    "artifact_lines",
    "artifact_size_bytes",
    "artifact_mtime_epoch",
    "artifact_mtime_epoch_ns",
    "artifact_mtime_utc",
    "recorded_at_epoch",
    "recorded_at_epoch_ns",
    "recorded_at_utc",
    "receipt_order",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 64), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SystemExit(f"Missing JSON file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON file: {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise SystemExit(f"Expected JSON object: {path}")
    return payload


def safe_relative(path_text: str, *, phase_id: str) -> Path:
    path = Path(path_text)
    if path.is_absolute():
        raise SystemExit(f"{phase_id}: artifact_path must be repo-relative: {path_text}")
    if ".." in path.parts:
        raise SystemExit(f"{phase_id}: artifact_path must not traverse parents: {path_text}")
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("start")
    parser.add_argument("end")
    parser.add_argument(
        "--source-root",
        default=".",
        help="Root containing workspace/output artifacts; defaults to repo root",
    )
    parser.add_argument(
        "--receipts",
        help="Receipt file path; defaults to logical receipt path under source root",
    )
    parser.add_argument(
        "--baseline-receipts",
        help="Frozen pre-phase receipts whose rows must remain unchanged.",
    )
    parser.add_argument(
        "--require-mtime",
        action="store_true",
        help="Also require artifact mtime fields to match receipts.",
    )
    args = parser.parse_args()

    source_root = Path(args.source_root).expanduser().resolve()
    receipt_path = (
        Path(args.receipts).expanduser().resolve()
        if args.receipts
        else source_root / logical_artifact_map(args.start, args.end)["receipts"]
    )
    if not receipt_path.exists():
        return 0

    payload = load_json(receipt_path)
    baseline_payload = (
        load_json(Path(args.baseline_receipts).expanduser().resolve())
        if args.baseline_receipts
        else None
    )
    expected_paths = receipt_phase_logical_paths(args.start, args.end)
    errors: list[str] = []
    checked = 0
    if baseline_payload is not None:
        current_by_phase = {
            str(receipt.get("phase_id")): receipt
            for receipt in payload.get("receipts", [])
            if isinstance(receipt, dict) and receipt.get("phase_id")
        }
        for baseline_receipt in baseline_payload.get("receipts", []):
            if not isinstance(baseline_receipt, dict):
                continue
            phase_id = str(baseline_receipt.get("phase_id") or "")
            if not phase_id:
                errors.append("baseline receipt row missing phase_id")
                continue
            current_receipt = current_by_phase.get(phase_id)
            if current_receipt is None:
                errors.append(f"{phase_id}: baseline receipt row missing from current receipts")
                continue
            for field in IMMUTABLE_RECEIPT_FIELDS:
                if baseline_receipt.get(field) != current_receipt.get(field):
                    errors.append(
                        f"{phase_id}: baseline receipt field changed: {field} "
                        f"({current_receipt.get(field)!r} != {baseline_receipt.get(field)!r})"
                    )

    for receipt in payload.get("receipts", []):
        if not isinstance(receipt, dict):
            continue
        phase_id = str(receipt.get("phase_id") or "")
        if not phase_id:
            errors.append("receipt row missing phase_id")
            continue
        artifact_path_text = receipt.get("artifact_path")
        if not isinstance(artifact_path_text, str) or not artifact_path_text.strip():
            errors.append(f"{phase_id}: receipt row missing artifact_path")
            continue
        logical_path = safe_relative(artifact_path_text.strip(), phase_id=phase_id)
        expected = expected_paths.get(phase_id)
        if expected and logical_path.as_posix() != expected:
            errors.append(f"{phase_id}: artifact_path {logical_path.as_posix()} != {expected}")
            continue

        artifact_path = source_root / logical_path
        if not artifact_path.exists():
            errors.append(f"{phase_id}: artifact missing on disk: {artifact_path}")
            continue

        expected_sha = receipt.get("artifact_sha256")
        if not isinstance(expected_sha, str) or not expected_sha.strip():
            errors.append(f"{phase_id}: receipt row missing artifact_sha256")
        else:
            actual_sha = sha256(artifact_path)
            if actual_sha != expected_sha:
                errors.append(
                    f"{phase_id}: artifact hash drift detected for {artifact_path} "
                    f"({actual_sha} != {expected_sha})"
                )

        if args.require_mtime:
            expected_mtime = receipt.get("artifact_mtime_epoch")
            if not isinstance(expected_mtime, int):
                errors.append(f"{phase_id}: receipt row missing artifact_mtime_epoch")
            else:
                actual_mtime = int(artifact_path.stat().st_mtime)
                if actual_mtime != expected_mtime:
                    errors.append(
                        f"{phase_id}: artifact mtime drift detected for {artifact_path} "
                        f"({actual_mtime} != {expected_mtime})"
                    )

            expected_mtime_ns = receipt.get("artifact_mtime_epoch_ns")
            if "artifact_mtime_epoch_ns" in receipt and not isinstance(expected_mtime_ns, int):
                errors.append(f"{phase_id}: receipt row has invalid artifact_mtime_epoch_ns")
            elif isinstance(expected_mtime_ns, int):
                actual_mtime_ns = int(artifact_path.stat().st_mtime_ns)
                if actual_mtime_ns != expected_mtime_ns:
                    errors.append(
                        f"{phase_id}: artifact mtime_ns drift detected for {artifact_path} "
                        f"({actual_mtime_ns} != {expected_mtime_ns})"
                    )
        checked += 1

    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        return 1
    print(f"PASS: phase receipt drift check passed ({checked} receipts)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

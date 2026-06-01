#!/usr/bin/env python3
"""Snapshot canonical product-run artifacts into a retained run directory."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path
from typing import Any

from product_run_common import logical_artifact_map, receipt_phase_logical_paths


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(1024 * 64)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def load_receipts(receipts_path: Path) -> dict[str, Any] | None:
    if not receipts_path.exists():
        return None
    return json.loads(receipts_path.read_text(encoding="utf-8"))


def assert_safe_relative_path(path_text: str) -> Path:
    path = Path(path_text)
    if path.is_absolute():
        raise SystemExit(f"Receipt path must be repo-relative, got absolute path: {path_text}")
    if ".." in path.parts:
        raise SystemExit(f"Receipt path must not traverse parents: {path_text}")
    return path


def verify_receipts(source_root: Path, start: str, end: str) -> dict[str, Any]:
    artifacts = logical_artifact_map(start, end)
    receipts_path = source_root / artifacts["receipts"]
    payload = load_receipts(receipts_path)
    if payload is None:
        return {
            "present": False,
            "verified_receipts": 0,
            "receipt_paths": [],
        }

    expected_phase_paths = receipt_phase_logical_paths(start, end)
    verified_paths: set[str] = set()
    verified_receipts = 0

    for receipt in payload.get("receipts", []):
        phase_id = receipt.get("phase_id")
        raw_path = receipt.get("artifact_path")
        if not isinstance(raw_path, str) or not raw_path.strip():
            raise SystemExit(f"Receipt for phase {phase_id!r} is missing artifact_path")

        logical_path = assert_safe_relative_path(raw_path.strip()).as_posix()
        expected_logical_path = expected_phase_paths.get(str(phase_id))
        if expected_logical_path and logical_path != expected_logical_path:
            raise SystemExit(
                f"Receipt artifact path mismatch for {phase_id}: "
                f"{logical_path} != {expected_logical_path}"
            )

        source_path = source_root / logical_path
        if not source_path.exists():
            raise SystemExit(
                f"Receipt artifact missing on disk for {phase_id}: {source_path}"
            )

        recorded_sha = receipt.get("artifact_sha256")
        if isinstance(recorded_sha, str) and recorded_sha.strip():
            actual_sha = sha256(source_path)
            if actual_sha != recorded_sha:
                raise SystemExit(
                    f"Receipt artifact hash drift for {phase_id}: "
                    f"{source_path} ({actual_sha} != {recorded_sha})"
                )

        verified_receipts += 1
        verified_paths.add(logical_path)

    return {
        "present": True,
        "verified_receipts": verified_receipts,
        "receipt_paths": sorted(verified_paths),
    }


def copy_preserving_mtime(source_root: Path, dest_root: Path, logical_paths: list[str]) -> list[dict[str, Any]]:
    copied: list[dict[str, Any]] = []
    for logical_path in logical_paths:
        source_path = source_root / logical_path
        if not source_path.exists():
            continue
        dest_path = dest_root / logical_path
        dest_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_path, dest_path)
        copied.append(
            {
                "logical_path": logical_path,
                "source_path": str(source_path),
                "dest_path": str(dest_path),
                "mtime_epoch": int(dest_path.stat().st_mtime),
                "size_bytes": dest_path.stat().st_size,
            }
        )
    return copied


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("start")
    parser.add_argument("end")
    parser.add_argument("--source-root")
    parser.add_argument("--dest-root", required=True)
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    source_root = Path(args.source_root).resolve() if args.source_root else repo_root
    dest_root = Path(args.dest_root).resolve()
    dest_root.mkdir(parents=True, exist_ok=True)

    receipt_summary = verify_receipts(source_root, args.start, args.end)
    artifact_map = logical_artifact_map(args.start, args.end)

    logical_paths = sorted(
        {
            *artifact_map.values(),
            *receipt_summary.get("receipt_paths", []),
        }
    )
    copied = copy_preserving_mtime(source_root, dest_root, logical_paths)

    manifest = {
        "schema_version": 1,
        "start": args.start,
        "end": args.end,
        "source_root": str(source_root),
        "dest_root": str(dest_root),
        "verified_receipts": receipt_summary,
        "copied_files": copied,
    }
    manifest_path = dest_root / "snapshot-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print(f"Snapshot root: {dest_root}")
    print(f"Copied files: {len(copied)}")
    print(f"Snapshot manifest: {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

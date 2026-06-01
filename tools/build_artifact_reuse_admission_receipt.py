#!/usr/bin/env python3
"""Build a static admission receipt for retained newsletter artifact reuse."""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Any

from newsletter_experiment_common import load_json, sha256_path, write_json


NO_REFETCH_ARTIFACTS = {
    "phase2_selected_source_ids",
    "phase2_fetch_attempt_ledger",
    "phase2_no_refetch_compliance",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, help="Fixture-pack manifest to inspect")
    parser.add_argument("--output", required=True, help="Receipt JSON path to write")
    parser.add_argument(
        "--surface-id",
        action="append",
        default=[],
        help="Surface id to inspect. Defaults to all surfaces.",
    )
    parser.add_argument(
        "--freshness-class",
        default="pinned_window_replay_only",
        help="Freshness class for the reuse candidate.",
    )
    parser.add_argument(
        "--require-no-refetch-audit",
        action="store_true",
        help="Require selected-source and no-refetch audit artifacts for admission.",
    )
    parser.add_argument("--notes", default="")
    return parser.parse_args()


def die(message: str) -> None:
    raise SystemExit(message)


def resolve_manifest_repo_root(manifest_path: Path, manifest: dict[str, Any]) -> Path:
    probe_paths: list[Path] = []
    for key in ("source_run_dir", "source_artifact_root"):
        value = str(manifest.get(key) or "").strip()
        if value:
            probe_paths.append(Path(value))
    if not probe_paths:
        return manifest_path.parent
    for candidate in (manifest_path.parent, *manifest_path.parents):
        if any((candidate / probe).exists() for probe in probe_paths):
            return candidate
    return manifest_path.parent


def source_path_for_artifact(
    artifact: dict[str, Any],
    manifest_repo_root: Path,
) -> Path | None:
    source_text = str(artifact.get("source_path") or "").strip()
    if not source_text:
        return None
    path = Path(source_text)
    if not path.is_absolute():
        path = manifest_repo_root / path
    return path


def inspect_surface(
    *,
    surface_id: str,
    artifacts: list[dict[str, Any]],
    manifest_repo_root: Path,
    require_no_refetch_audit: bool,
) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    present_count = 0
    missing_count = 0
    absent_optional_count = 0
    present_size_bytes = 0
    artifact_names: set[str] = set()
    source_present_artifact_names: set[str] = set()
    missing_artifacts: list[str] = []
    absent_optional_artifacts: list[str] = []
    hash_mismatches: list[str] = []

    for artifact in artifacts:
        name = str(artifact.get("artifact_name") or "")
        logical_path = str(artifact.get("logical_path") or "")
        artifact_names.add(name)
        source_path = source_path_for_artifact(artifact, manifest_repo_root)
        manifest_exists = bool(artifact.get("exists"))
        source_exists = bool(source_path and source_path.exists())
        exists = bool(source_exists and manifest_exists)
        actual_sha256 = sha256_path(source_path) if source_exists and source_path else None
        expected_sha256 = str(artifact.get("sha256") or "")
        if exists:
            present_count += 1
            source_present_artifact_names.add(name)
            present_size_bytes += int(artifact.get("size_bytes") or source_path.stat().st_size)
            if expected_sha256 and actual_sha256 and expected_sha256 != actual_sha256:
                hash_mismatches.append(logical_path or name)
        elif manifest_exists:
            missing_count += 1
            missing_artifacts.append(logical_path or name)
        else:
            absent_optional_count += 1
            absent_optional_artifacts.append(logical_path or name)
        rows.append(
            {
                "artifact_name": name,
                "logical_path": logical_path,
                "source_path": str(source_path) if source_path else None,
                "manifest_exists": manifest_exists,
                "source_exists": source_exists,
                "expected_sha256": expected_sha256 or None,
                "actual_sha256": actual_sha256,
                "size_bytes": int(artifact.get("size_bytes") or 0),
            }
        )

    no_refetch_present = sorted(NO_REFETCH_ARTIFACTS.intersection(source_present_artifact_names))
    no_refetch_missing = sorted(NO_REFETCH_ARTIFACTS.difference(source_present_artifact_names))
    token_proxy_estimate = (present_size_bytes + 3) // 4
    verdict = "admit_static_probe"
    blockers: list[str] = []
    if not present_count:
        verdict = "blocked_no_present_artifacts"
        blockers.append("surface has no present retained artifacts")
    if missing_count:
        verdict = "blocked_missing_artifacts"
        blockers.append("one or more manifest artifacts are missing on disk")
    if hash_mismatches:
        verdict = "blocked_hash_mismatch"
        blockers.append("one or more retained artifact hashes do not match the manifest")
    if require_no_refetch_audit and no_refetch_missing:
        verdict = "blocked_missing_no_refetch_audit"
        blockers.append("selected-source/no-refetch audit artifacts are absent")

    return {
        "surface_id": surface_id,
        "artifact_count": len(artifacts),
        "present_count": present_count,
        "missing_count": missing_count,
        "absent_optional_count": absent_optional_count,
        "present_size_bytes": present_size_bytes,
        "token_proxy_estimate": token_proxy_estimate,
        "missing_artifacts": missing_artifacts,
        "absent_optional_artifacts": absent_optional_artifacts,
        "hash_mismatches": hash_mismatches,
        "no_refetch_audit_artifacts_present": no_refetch_present,
        "no_refetch_audit_artifacts_missing": no_refetch_missing,
        "require_no_refetch_audit": require_no_refetch_audit,
        "verdict": verdict,
        "blockers": blockers,
        "artifacts": rows,
    }


def main() -> int:
    args = parse_args()
    manifest_path = Path(args.manifest).expanduser().resolve()
    manifest = load_json(manifest_path)
    if not isinstance(manifest, dict):
        die(f"Manifest not found or invalid JSON: {manifest_path}")
    surfaces = manifest.get("surfaces")
    if not isinstance(surfaces, dict) or not surfaces:
        die(f"Manifest has no surfaces: {manifest_path}")

    selected_surface_ids = args.surface_id or sorted(surfaces)
    manifest_repo_root = resolve_manifest_repo_root(manifest_path, manifest)
    inspected = []
    for surface_id in selected_surface_ids:
        artifacts = surfaces.get(surface_id)
        if not isinstance(artifacts, list):
            die(f"Surface missing from manifest: {surface_id}")
        inspected.append(
            inspect_surface(
                surface_id=surface_id,
                artifacts=artifacts,
                manifest_repo_root=manifest_repo_root,
                require_no_refetch_audit=args.require_no_refetch_audit,
            )
        )

    admitted = [row for row in inspected if row.get("verdict") == "admit_static_probe"]
    blockers = [
        {"surface_id": row.get("surface_id"), "verdict": row.get("verdict"), "blockers": row.get("blockers")}
        for row in inspected
        if row.get("verdict") != "admit_static_probe"
    ]
    overall_verdict = "admit_static_probe" if admitted and not blockers else "blocked_or_partial"
    if not admitted:
        overall_verdict = "blocked"

    receipt = {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "manifest_path": str(manifest_path),
        "manifest_sha256": sha256_path(manifest_path),
        "manifest_id": manifest.get("manifest_id"),
        "source_run_id": manifest.get("run_id"),
        "start": manifest.get("start"),
        "end": manifest.get("end"),
        "mode": manifest.get("mode"),
        "freshness_class": args.freshness_class,
        "notes": args.notes,
        "surfaces": inspected,
        "overall_verdict": overall_verdict,
        "admitted_surface_ids": [row["surface_id"] for row in admitted],
        "blocked_surfaces": blockers,
        "non_claims": [
            "This receipt is a static artifact-reuse admission check.",
            "It is not a production adoption, durable savings claim, or cache-savings claim.",
            "Pinned retained artifacts require fresh or replay validation before reuse can support workflow savings claims.",
        ],
    }
    write_json(Path(args.output), receipt)
    return 0 if admitted else 2


if __name__ == "__main__":
    raise SystemExit(main())

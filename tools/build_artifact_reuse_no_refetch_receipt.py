#!/usr/bin/env python3
"""Build selected-source/no-refetch admission receipts for artifact reuse."""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Any

from newsletter_experiment_common import load_json, sha256_path, sha256_text, write_json


DEFAULT_BENCHMARK_SELECTION = Path("config/benchmark_lanes/newsletter_phase2_to_phase3_selection_feb2026.json")
NO_REFETCH_NAMES = (
    "phase2_selected_source_ids",
    "phase2_fetch_attempt_ledger",
    "phase2_no_refetch_compliance",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, help="Fixture-pack manifest to inspect")
    parser.add_argument("--output", required=True, help="Receipt JSON path to write")
    parser.add_argument("--surface-id", default="phase2_entry_surface")
    parser.add_argument("--selection-manifest", default="", help="Pinned selected-source manifest")
    parser.add_argument("--artifact-output-dir", default="", help="Optional directory for generated sidecar artifacts")
    parser.add_argument("--attempt-id", default="retained_inventory_plus_deterministic_generation")
    parser.add_argument("--notes", default="")
    return parser.parse_args()


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


def artifact_path(artifact: dict[str, Any], manifest_repo_root: Path) -> Path | None:
    raw = str(artifact.get("source_path") or "").strip()
    if not raw:
        return None
    path = Path(raw)
    if not path.is_absolute():
        path = manifest_repo_root / path
    return path


def stable_json_bytes(payload: Any) -> bytes:
    return json.dumps(payload, indent=2, sort_keys=True).encode("utf-8") + b"\n"


def stable_json_sha256(payload: Any) -> str:
    return sha256_text(stable_json_bytes(payload).decode("utf-8"))


def surface_pack_hash(surface: list[dict[str, Any]], manifest_repo_root: Path) -> str:
    rows: list[dict[str, Any]] = []
    for artifact in surface:
        path = artifact_path(artifact, manifest_repo_root)
        rows.append(
            {
                "artifact_name": artifact.get("artifact_name"),
                "logical_path": artifact.get("logical_path"),
                "source_path": artifact.get("source_path"),
                "manifest_exists": bool(artifact.get("exists")),
                "source_exists": bool(path and path.exists()),
                "sha256": sha256_path(path) if path and path.exists() else artifact.get("sha256"),
            }
        )
    return stable_json_sha256(rows)


def validator_audit_inputs(surface: list[dict[str, Any]], manifest_repo_root: Path) -> list[dict[str, Any]]:
    inputs: list[dict[str, Any]] = []
    for artifact in surface:
        name = str(artifact.get("artifact_name") or "")
        if name in set(NO_REFETCH_NAMES):
            continue
        path = artifact_path(artifact, manifest_repo_root)
        if not path or not path.exists():
            continue
        inputs.append(
            {
                "artifact_name": name,
                "logical_path": artifact.get("logical_path"),
                "source_path": artifact.get("source_path"),
                "sha256": sha256_path(path),
                "size_bytes": path.stat().st_size,
            }
        )
    return inputs


def infer_selection_manifest(repo_root: Path, start: str, end: str) -> Path | None:
    candidate = repo_root / DEFAULT_BENCHMARK_SELECTION
    payload = load_json(candidate)
    if isinstance(payload, dict) and payload.get("start") == start and payload.get("end") == end:
        return candidate
    return None


def selected_items(selection: dict[str, Any], candidates_by_url: dict[str, dict[str, Any]]) -> tuple[list[dict[str, Any]], list[str]]:
    selected: list[dict[str, Any]] = []
    blockers: list[str] = []
    for section in ("virtual_events", "in_person_events"):
        rows = selection.get(section)
        if not isinstance(rows, list):
            blockers.append(f"selection manifest missing list: {section}")
            continue
        for order, item in enumerate(rows, start=1):
            if not isinstance(item, dict):
                blockers.append(f"selection manifest has non-object row: {section}[{order}]")
                continue
            source_id = str(item.get("source_id") or "").strip()
            if not source_id:
                blockers.append(f"selection manifest missing source_id: {section}[{order}]")
                continue
            candidate = candidates_by_url.get(source_id)
            if candidate is None:
                blockers.append(f"selected source_id not present in retained event sources: {source_id}")
                continue
            selected.append(
                {
                    "section": section,
                    "order": order,
                    "source_id": source_id,
                    "title": item.get("title"),
                    "date_label": item.get("date_label"),
                    "source_types": candidate.get("source_types", []),
                    "source_names": candidate.get("source_names", []),
                }
            )
    if not selected:
        blockers.append("selection manifest produced no selected source ids")
    return selected, blockers


def write_sidecar(path: Path | None, payload: dict[str, Any]) -> dict[str, Any]:
    if path is not None:
        write_json(path, payload)
        return {
            "path": str(path),
            "sha256": sha256_path(path),
            "size_bytes": path.stat().st_size,
        }
    return {
        "path": None,
        "sha256": stable_json_sha256(payload),
        "size_bytes": len(stable_json_bytes(payload)),
    }


def main() -> int:
    args = parse_args()
    manifest_path = Path(args.manifest).expanduser().resolve()
    output_path = Path(args.output).expanduser().resolve()
    manifest = load_json(manifest_path)
    if not isinstance(manifest, dict):
        raise SystemExit(f"Manifest not found or invalid JSON: {manifest_path}")
    repo_root = Path(__file__).resolve().parent.parent
    manifest_repo_root = resolve_manifest_repo_root(manifest_path, manifest)
    surface = (manifest.get("surfaces") or {}).get(args.surface_id)
    blockers: list[str] = []
    generated_artifacts: dict[str, Any] = {}

    if not isinstance(surface, list) or not surface:
        blockers.append(f"surface missing or empty: {args.surface_id}")
        surface = []

    start = str(manifest.get("start") or "")
    end = str(manifest.get("end") or "")
    event_sources_artifact = next((row for row in surface if row.get("artifact_name") == "event_sources"), None)
    event_sources_path = artifact_path(event_sources_artifact, manifest_repo_root) if event_sources_artifact else None
    event_sources: dict[str, Any] = {}
    if not event_sources_artifact or not event_sources_path or not event_sources_path.exists():
        blockers.append("retained phase2 event_sources artifact is missing")
    else:
        expected_sha = str(event_sources_artifact.get("sha256") or "")
        actual_sha = sha256_path(event_sources_path)
        if expected_sha and expected_sha != actual_sha:
            blockers.append("retained phase2 event_sources hash mismatch")
        loaded = load_json(event_sources_path)
        if not isinstance(loaded, dict):
            blockers.append("retained phase2 event_sources artifact is invalid JSON")
        else:
            event_sources = loaded

    selection_path = Path(args.selection_manifest).expanduser().resolve() if args.selection_manifest else infer_selection_manifest(repo_root, start, end)
    selection: dict[str, Any] = {}
    if selection_path is None or not selection_path.exists():
        blockers.append("no pinned selection manifest is available for this run window")
    else:
        loaded_selection = load_json(selection_path)
        if not isinstance(loaded_selection, dict):
            blockers.append("selection manifest is invalid JSON")
        else:
            selection = loaded_selection
            if selection.get("start") != start or selection.get("end") != end:
                blockers.append(
                    f"selection manifest date range mismatch: {selection.get('start')}..{selection.get('end')} != {start}..{end}"
                )

    candidates_by_url = {
        str(item.get("url")): item
        for item in event_sources.get("candidate_urls", [])
        if isinstance(item, dict) and item.get("url")
    }
    selected_source_ids: list[dict[str, Any]] = []
    if selection and event_sources:
        selected_source_ids, selection_blockers = selected_items(selection, candidates_by_url)
        blockers.extend(selection_blockers)

    source_pack_sha256 = surface_pack_hash(surface, manifest_repo_root) if surface else None
    materializer_path = repo_root / "tools" / "materialize_lane_a_phase2_events.py"
    renderer_or_prompt_hash = sha256_path(materializer_path) if materializer_path.exists() else None
    selection_sha = sha256_path(selection_path) if selection_path and selection_path.exists() else None
    event_sources_sha = sha256_path(event_sources_path) if event_sources_path and event_sources_path.exists() else None
    artifact_dir = Path(args.artifact_output_dir).expanduser().resolve() if args.artifact_output_dir else None
    if artifact_dir:
        artifact_dir.mkdir(parents=True, exist_ok=True)

    if not blockers:
        common = {
            "schema_version": 1,
            "run_id": manifest.get("run_id"),
            "manifest_id": manifest.get("manifest_id"),
            "surface_id": args.surface_id,
            "start": start,
            "end": end,
            "mode": manifest.get("mode"),
            "source_pack_sha256": source_pack_sha256,
            "selection_manifest_path": str(selection_path),
            "selection_manifest_sha256": selection_sha,
            "event_sources_path": str(event_sources_path),
            "event_sources_sha256": event_sources_sha,
        }
        selected_payload = {
            **common,
            "artifact_kind": "phase2_selected_source_ids",
            "selected_source_ids": selected_source_ids,
        }
        fetch_payload = {
            **common,
            "artifact_kind": "phase2_fetch_attempt_ledger",
            "network_access_permitted": False,
            "fetch_attempt_count": 0,
            "fetch_attempts": [],
        }
        generated_artifacts = {
            "phase2_selected_source_ids": write_sidecar(
                artifact_dir / f"newsletter_phase2_selected_source_ids_{end}.json" if artifact_dir else None,
                selected_payload,
            ),
            "phase2_fetch_attempt_ledger": write_sidecar(
                artifact_dir / f"newsletter_phase2_fetch_attempt_ledger_{end}.json" if artifact_dir else None,
                fetch_payload,
            ),
        }
        compliance_payload = {
            **common,
            "artifact_kind": "phase2_no_refetch_compliance",
            "network_access_permitted": False,
            "fetch_attempt_count": 0,
            "compliance": "pass",
            "selected_source_ids_sha256": generated_artifacts["phase2_selected_source_ids"].get("sha256"),
            "fetch_attempt_ledger_sha256": generated_artifacts["phase2_fetch_attempt_ledger"].get("sha256"),
            "reason": "Selected-source evidence was generated from retained event_sources and a pinned selection manifest only.",
        }
        generated_artifacts["phase2_no_refetch_compliance"] = write_sidecar(
            artifact_dir / f"newsletter_phase2_no_refetch_compliance_{end}.json" if artifact_dir else None,
            compliance_payload,
        )

    verdict = "admit_no_refetch" if not blockers else "blocked"
    receipt = {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "attempt_id": args.attempt_id,
        "manifest_path": str(manifest_path),
        "manifest_sha256": sha256_path(manifest_path),
        "manifest_id": manifest.get("manifest_id"),
        "source_run_id": manifest.get("run_id"),
        "start": start,
        "end": end,
        "mode": manifest.get("mode"),
        "surface_id": args.surface_id,
        "source_pack_sha256": source_pack_sha256,
        "renderer_or_prompt_hash": renderer_or_prompt_hash,
        "renderer_or_prompt_binding": {
            "kind": "deterministic_phase2_materializer",
            "path": "tools/materialize_lane_a_phase2_events.py",
            "sha256": renderer_or_prompt_hash,
        },
        "selection_manifest_path": str(selection_path) if selection_path else None,
        "selection_manifest_sha256": selection_sha,
        "event_sources_path": str(event_sources_path) if event_sources_path else None,
        "event_sources_sha256": event_sources_sha,
        "selected_source_count": len(selected_source_ids),
        "selected_source_ids": selected_source_ids,
        "fetch_attempt_ledger": {
            "network_access_permitted": False,
            "fetch_attempt_count": 0 if not blockers else None,
        },
        "no_refetch_compliance": "pass" if not blockers else "blocked",
        "generated_artifacts": generated_artifacts,
        "validator_audit_input_hashes": validator_audit_inputs(surface, manifest_repo_root),
        "admission_verdict": verdict,
        "blockers": blockers,
        "notes": args.notes,
        "non_claims": [
            "This receipt is an artifact-reuse no-refetch admission check.",
            "It is not a production adoption, durable savings claim, billing claim, or cache-savings claim.",
            "Generated sidecar artifacts prove only deterministic selected-source binding from retained inputs and a pinned selection manifest.",
        ],
    }
    write_json(output_path, receipt)
    return 0 if verdict == "admit_no_refetch" else 2


if __name__ == "__main__":
    raise SystemExit(main())

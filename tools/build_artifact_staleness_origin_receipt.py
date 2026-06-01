#!/usr/bin/env python3
"""Classify full-run artifact staleness origin from retained run evidence."""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--control-run-dir", required=True)
    parser.add_argument("--candidate-run-dir", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def find_artifact(path: Path, name: str) -> Path | None:
    matches = sorted((path / "artifacts").glob(f"**/{name}"))
    if matches:
        return matches[0]
    return None


def receipt_epochs(path: Path | None) -> list[dict[str, Any]]:
    if path is None or not path.exists():
        return []
    payload = load_json(path)
    rows = payload.get("receipts") if isinstance(payload, dict) else []
    if not isinstance(rows, list):
        return []
    result = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        phase_id = str(row.get("phase_id") or "")
        recorded = row.get("recorded_at_epoch")
        mtime = row.get("artifact_mtime_epoch")
        result.append(
            {
                "phase_id": phase_id,
                "artifact_path": row.get("artifact_path"),
                "recorded_at_epoch": recorded if isinstance(recorded, int) else None,
                "artifact_mtime_epoch": mtime if isinstance(mtime, int) else None,
                "run_id": row.get("run_id"),
            }
        )
    return result


def run_state(run_dir: Path) -> dict[str, Any]:
    metadata_path = run_dir / "run-metadata.json"
    metadata = load_json(metadata_path) if metadata_path.exists() else {}
    start = str(metadata.get("start") or "")
    end = str(metadata.get("end") or "")
    marker_path = find_artifact(run_dir, f"newsletter_run_marker_{start}_to_{end}.json") if start and end else None
    receipts_path = find_artifact(run_dir, f"newsletter_phase_receipts_{end}.json") if end else None
    marker = load_json(marker_path) if marker_path and marker_path.exists() else {}
    receipts = receipt_epochs(receipts_path)
    dirty_files = metadata.get("dirty_files") if isinstance(metadata.get("dirty_files"), list) else []
    return {
        "run_dir": str(run_dir),
        "metadata_path": str(metadata_path),
        "metadata_exists": metadata_path.exists(),
        "metadata": metadata,
        "marker_path": str(marker_path) if marker_path else None,
        "marker": marker if isinstance(marker, dict) else {},
        "receipts_path": str(receipts_path) if receipts_path else None,
        "receipts": receipts,
        "dirty_files": dirty_files,
    }


def generated_dirty_files(dirty_files: list[Any]) -> list[str]:
    generated: list[str] = []
    for item in dirty_files:
        raw = str(item)
        path_text = raw[3:] if len(raw) >= 3 and raw[2] == " " else raw.strip()
        candidates = [path_text]
        if " -> " in path_text:
            candidates.extend(path_text.split(" -> ", 1))
        if any(candidate.startswith(("workspace/", "output/")) for candidate in candidates):
            generated.append(raw)
    return generated


def staleness_evidence(run: dict[str, Any]) -> tuple[list[str], dict[str, Any]]:
    evidence: dict[str, Any] = {}
    marker = run["marker"]
    receipts = run["receipts"]
    if not marker:
        return ["marker missing from retained artifact snapshot"], evidence
    if not receipts:
        return ["receipts missing from retained artifact snapshot"], evidence

    marker_epoch = marker.get("prepared_at_epoch")
    receipt_epochs = [
        value
        for row in receipts
        for value in (row.get("recorded_at_epoch"), row.get("artifact_mtime_epoch"))
        if isinstance(value, int)
    ]
    if not isinstance(marker_epoch, int) or not receipt_epochs:
        return ["marker or receipt epochs are incomplete"], evidence

    stale_receipts = [
        row
        for row in receipts
        if (
            isinstance(row.get("recorded_at_epoch"), int)
            and row["recorded_at_epoch"] < marker_epoch
        )
        or (
            isinstance(row.get("artifact_mtime_epoch"), int)
            and row["artifact_mtime_epoch"] < marker_epoch
        )
    ]
    dirty_generated = generated_dirty_files(run["dirty_files"])
    evidence = {
        "marker_prepared_at_epoch": marker_epoch,
        "min_receipt_epoch": min(receipt_epochs),
        "stale_receipt_count": len(stale_receipts),
        "stale_receipts": stale_receipts,
        "dirty_generated_files": dirty_generated,
        "marker_phase_experiment": marker.get("phase_experiment"),
        "marker_source_fixture_run_id": marker.get("source_fixture_run_id"),
    }
    blockers: list[str] = []
    if stale_receipts:
        blockers.append("run has receipts or artifacts older than its marker")
    if dirty_generated:
        blockers.append("run metadata includes generated workspace/output dirty state")
    return blockers, evidence


def classify(control: dict[str, Any], candidate: dict[str, Any]) -> tuple[str, list[str], dict[str, Any]]:
    control_blockers, control_evidence = staleness_evidence(control)
    if control_blockers:
        return (
            "unresolved_fail_closed",
            [f"control baseline is not clean: {item}" for item in control_blockers],
            {"control": control_evidence},
        )

    candidate_blockers, evidence = staleness_evidence(candidate)
    if candidate_blockers and "marker missing from retained artifact snapshot" in candidate_blockers:
        return "unresolved_fail_closed", ["candidate marker missing from retained artifact snapshot"], evidence
    if candidate_blockers and "receipts missing from retained artifact snapshot" in candidate_blockers:
        return "unresolved_fail_closed", ["candidate receipts missing from retained artifact snapshot"], evidence
    if candidate_blockers and "marker or receipt epochs are incomplete" in candidate_blockers:
        return "unresolved_fail_closed", ["candidate marker or receipt epochs are incomplete"], evidence

    stale_count = int(evidence.get("stale_receipt_count") or 0)
    dirty_generated = evidence.get("dirty_generated_files") or []
    if stale_count and evidence.get("marker_phase_experiment") == "phase3-curation":
        return "wrapper_materialization_timestamp_bug", [], evidence
    if stale_count:
        return "marker_receipt_semantics_bug", [], evidence
    if dirty_generated:
        return "inherited_generated_artifacts", [], evidence
    return "unresolved_fail_closed", ["no stale marker or generated-artifact inheritance signal found"], evidence


def main() -> int:
    args = parse_args()
    control = run_state(Path(args.control_run_dir).expanduser().resolve())
    candidate = run_state(Path(args.candidate_run_dir).expanduser().resolve())
    classification, blockers, evidence = classify(control, candidate)
    passed = classification != "unresolved_fail_closed" and not blockers
    receipt = {
        "schema_version": 1,
        "receipt_type": "artifact_staleness_origin_receipt",
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "verdict": "pass_classified_staleness_origin" if passed else "fail_closed_unresolved_staleness_origin",
        "classification": classification,
        "blockers": blockers,
        "control": {
            "run_dir": control["run_dir"],
            "marker_path": control["marker_path"],
            "receipts_path": control["receipts_path"],
            "dirty_generated_files": generated_dirty_files(control["dirty_files"]),
        },
        "candidate": {
            "run_dir": candidate["run_dir"],
            "marker_path": candidate["marker_path"],
            "receipts_path": candidate["receipts_path"],
            "dirty_generated_files": generated_dirty_files(candidate["dirty_files"]),
        },
        "evidence": evidence,
        "repair_contract": {
            "preserve_full_run_marker_inside_stdout_no_tools_wrapper": True,
            "use_separate_clean_worktrees_for_full_control_and_candidate": True,
            "reject_dirty_generated_state_before_live_rows": True,
        },
        "non_claims": [
            "This receipt classifies provenance failure origin only.",
            "This receipt is not savings proof and not enablement authorization.",
        ],
    }
    output = Path(args.output).expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())

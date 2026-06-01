#!/usr/bin/env python3
"""Build Phase 1C positive-control fixtures for calibration data acquisition."""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Any

from build_phase1c_calibration_receipt import candidate_phase1c_checkpoint
from newsletter_experiment_common import load_json, sha256_path, write_json
from product_run_common import receipt_phase_logical_paths
from prove_newsletter_stop_gates import evaluate_run


REPO_ROOT = Path(__file__).resolve().parent.parent
REQUIRED_PHASE_IDS = [
    "phase0_scope_contract",
    "phase1b_github",
    "phase1b_vscode",
    "phase1b_visualstudio",
    "phase1b_jetbrains",
    "phase1b_xcode",
    "phase1c_discoveries",
    "phase3_working_set",
    "phase3_curated",
]
PHASE1B_IDS = [
    "phase1b_github",
    "phase1b_vscode",
    "phase1b_visualstudio",
    "phase1b_jetbrains",
    "phase1b_xcode",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-run", required=True, help="Retained known-stop source run")
    parser.add_argument(
        "--source-scorecard",
        help="Scorecard for source run; defaults to <source-run>/run-scorecard.json",
    )
    parser.add_argument("--output-dir", required=True, help="Planning directory to populate")
    parser.add_argument("--output", required=True, help="Positive-control probe receipt path")
    return parser.parse_args()


def read_required_json(path: Path, label: str) -> dict[str, Any]:
    payload = load_json(path)
    if not isinstance(payload, dict):
        raise SystemExit(f"Missing or invalid {label}: {path}")
    return payload


def read_required_text(path: Path, label: str) -> str:
    if not path.exists():
        raise SystemExit(f"Missing {label}: {path}")
    return path.read_text(encoding="utf-8", errors="ignore")


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n", encoding="utf-8")


def artifact_root(run_dir: Path, metadata: dict[str, Any]) -> Path:
    local_root = run_dir / "artifacts"
    if local_root.exists():
        return local_root.resolve()
    root = Path(str(metadata.get("artifact_root") or run_dir / "artifacts")).expanduser()
    if not root.is_absolute():
        root = REPO_ROOT / root
    return root.resolve()


def count_lines(path: Path) -> int:
    return len(path.read_text(encoding="utf-8", errors="ignore").splitlines())


def phase1b_text(phase_id: str, headings: int, *, shape: str) -> str:
    lines = [
        f"# Positive-control {phase_id}",
        "",
        f"Fixture shape: {shape}.",
        "This file is synthetic and uses only Phase-1C-available evidence.",
        "",
    ]
    for idx in range(1, headings + 1):
        lines.extend(
            [
                f"### Synthetic Phase 1B signal {phase_id}-{idx:02d}",
                "",
                "Synthetic pre-Phase-1C source bullet retained for collapse-shape accounting.",
                "",
            ]
        )
    return "\n".join(lines)


def phase1c_low_continuity_text() -> str:
    return "\n".join(
        [
            "# Positive-control Phase 1C discoveries",
            "",
            "Synthetic fixture: low continuity collapse.",
            "",
            "### GitHub and editor signal collapsed into one generic item",
            "",
            "The output intentionally drops the expected VS Code release references.",
            "",
            "### Non-version general release summary",
            "",
            "This fixture is not adoption proof and is retained only as a data-acquisition probe.",
            "",
            "### Routing note",
            "",
            "The shape is available at Phase 1C because it only compares Phase 1B headings, Phase 1C headings, and expected scope-contract versions.",
        ]
    )


def phase1c_severe_version_loss_text(kept_versions: list[str]) -> str:
    return "\n".join(
        [
            "# Positive-control Phase 1C discoveries",
            "",
            "Synthetic fixture: severe version-retention collapse.",
            "",
            "### VS Code versions partially retained",
            "",
            "Retained versions: " + ", ".join(kept_versions),
            "",
            "### Broad product summary",
            "",
            "At least half of the expected VS Code version signals are intentionally missing.",
        ]
    )


def copy_source_artifact(source_root: Path, target_root: Path, logical_path: str) -> Path:
    source_path = source_root / logical_path
    content = read_required_text(source_path, logical_path)
    target_path = target_root / logical_path
    write_text(target_path, content)
    return target_path


def write_receipts(target_root: Path, start: str, end: str, run_id: str) -> dict[str, Any]:
    logical = receipt_phase_logical_paths(start, end)
    rows: list[dict[str, Any]] = []
    now = dt.datetime.now(tz=dt.timezone.utc)
    base_epoch = int(now.timestamp())
    for idx, phase_id in enumerate(REQUIRED_PHASE_IDS, start=1):
        logical_path = logical[phase_id]
        path = target_root / logical_path
        if not path.exists():
            raise SystemExit(f"Missing positive-control artifact for {phase_id}: {path}")
        stat = path.stat()
        rows.append(
            {
                "phase_id": phase_id,
                "artifact_path": logical_path,
                "artifact_sha256": sha256_path(path),
                "artifact_bytes": stat.st_size,
                "artifact_lines": count_lines(path),
                "artifact_mtime_epoch": int(stat.st_mtime),
                "artifact_mtime_epoch_ns": stat.st_mtime_ns,
                "artifact_mtime_utc": dt.datetime.fromtimestamp(
                    stat.st_mtime,
                    tz=dt.timezone.utc,
                ).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "recorded_at_epoch": base_epoch + idx,
                "recorded_at_epoch_ns": (base_epoch + idx) * 1_000_000_000,
                "recorded_at_utc": dt.datetime.fromtimestamp(
                    base_epoch + idx,
                    tz=dt.timezone.utc,
                ).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "receipt_order": idx,
            }
        )
    receipt = {
        "schema_version": 2,
        "run_id": run_id,
        "start": start,
        "end": end,
        "receipts": rows,
    }
    receipt_path = target_root / f"workspace/newsletter_phase_receipts_{end}.json"
    write_json(receipt_path, receipt)
    return {"path": receipt_path, "payload": receipt}


def phase_receipt_summary(receipt_path: Path, receipt_rows: list[dict[str, Any]]) -> dict[str, Any]:
    ordered_phase_ids = [str(row["phase_id"]) for row in receipt_rows]
    recorded_at = {
        str(row["phase_id"]): int(row.get("recorded_at_epoch", 0) or 0)
        for row in receipt_rows
    }
    spans = {}
    for idx in range(len(ordered_phase_ids) - 1):
        src = ordered_phase_ids[idx]
        dst = ordered_phase_ids[idx + 1]
        spans[f"{src} -> {dst}"] = max(0, recorded_at[dst] - recorded_at[src])
    receipt_span_seconds = (
        max(recorded_at.values()) - min(recorded_at.values())
        if recorded_at
        else 0
    )
    return {
        "present": True,
        "ordered_phase_ids": ordered_phase_ids,
        "comparable_ordered_phase_ids": ordered_phase_ids,
        "phase_spans_seconds": spans,
        "comparable_phase_spans_seconds": spans,
        "receipt_span_seconds": receipt_span_seconds,
        "phase_order_normalization": {
            "applied": False,
            "mode": "positive_control_fixture_order",
            "preserves_retained_ordered_phase_ids": True,
            "reason": "Synthetic positive-control fixture uses explicit Phase-1C-available order.",
            "source": "tools/build_phase1c_positive_control_probe.py",
            "warnings": [],
        },
        "receipt_file_path": str(receipt_path),
        "receipt_file_sha256": sha256_path(receipt_path),
    }


def build_fixture(
    *,
    run_id: str,
    shape_id: str,
    source_run: Path,
    source_root: Path,
    source_metadata: dict[str, Any],
    source_scorecard: dict[str, Any],
    source_scorecard_path: Path,
    output_dir: Path,
    phase1b_heading_counts: dict[str, int],
    phase1c_text: str,
) -> tuple[Path, Path]:
    run_dir = output_dir / "positive-control-runs" / run_id
    artifact_dir = run_dir / "artifacts"
    start = str(source_metadata["start"])
    end = str(source_metadata["end"])
    logical = receipt_phase_logical_paths(start, end)

    # Copy the source scope and Phase 3 artifacts; mutate only Phase-1C-available surfaces.
    copy_source_artifact(source_root, artifact_dir, logical["phase0_scope_contract"])
    copy_source_artifact(source_root, artifact_dir, logical["phase3_working_set"])
    copy_source_artifact(source_root, artifact_dir, logical["phase3_curated"])
    for phase_id in PHASE1B_IDS:
        write_text(
            artifact_dir / logical[phase_id],
            phase1b_text(phase_id, phase1b_heading_counts[phase_id], shape=shape_id),
        )
    write_text(artifact_dir / logical["phase1c_discoveries"], phase1c_text)

    receipt_info = write_receipts(artifact_dir, start, end, run_id)
    phase_receipts = phase_receipt_summary(
        receipt_info["path"],
        receipt_info["payload"]["receipts"],
    )

    metadata = dict(source_metadata)
    metadata.update(
        {
            "artifact_root": str(artifact_dir.resolve()),
            "run_id": run_id,
            "run_class": "phase1c_positive_control_fixture",
            "positive_control_source_run": str(source_run),
            "positive_control_shape": shape_id,
        }
    )
    write_json(run_dir / "run-metadata.json", metadata)

    audit = {
        "schema_version": 1,
        "run_id": run_id,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "receipts": phase_receipts,
        "metrics": {
            "phase_spans_seconds": phase_receipts["phase_spans_seconds"],
            "comparable_phase_spans_seconds": phase_receipts["comparable_phase_spans_seconds"],
            "receipt_span_seconds": phase_receipts["receipt_span_seconds"],
        },
        "pass": None,
        "positive_control_fixture": {
            "shape_id": shape_id,
            "source_run": str(source_run),
            "phase1c_available_only": True,
            "phase3_artifacts_copied_for_legacy_evaluator_binding_only": True,
            "production_policy_adoption": False,
        },
    }
    write_json(run_dir / "audit" / "RUN_AUDIT.json", audit)

    quality = {
        "strict_pass": None,
        "newsletter_pass": None,
        "rubric_pass": None,
        "rubric_score": None,
        "fixture_note": "Synthetic positive-control fixture; quality fields are not live proof-run results.",
    }
    token_usage = {
        "source": "synthetic_positive_control_fixture",
        "primary_model": source_scorecard.get("primary_model"),
        "request_count": None,
        "input_tokens": None,
        "output_tokens": None,
        "cache_read_tokens": None,
        "cache_write_tokens": None,
        "cached_tokens_total": None,
        "reasoning_tokens": None,
        "direct_provider_token_fields_present": [],
        "missing_direct_provider_token_fields": [
            "inputTokens",
            "outputTokens",
            "cacheReadTokens",
            "cacheWriteTokens",
            "reasoningTokens",
        ],
        "fixture_note": "Synthetic positive-control fixture; token fields are intentionally not inherited from the source run.",
    }
    experiment = {
        "experiment_id": f"burst16_positive_control_{shape_id}",
        "run_class": "phase1c_positive_control_fixture",
        "fixture_pack": "phase1c_positive_control",
        "prompt_sha256": None,
        "prompt_source": "synthetic_fixture",
        "prompt_path": None,
        "prompt_renderer_command": None,
        "prompt_equality": None,
    }
    experiment.update(
        {
            "positive_control_shape": shape_id,
            "positive_control_provenance": {
                "classification": "synthetic_fixture",
                "source_run": str(source_run),
                "source_scorecard_sha256": sha256_path(source_scorecard_path),
                "phase1c_available_only": True,
                "phase3_artifacts_copied_for_legacy_evaluator_binding_only": True,
                "adoption_grade": False,
                "corroboration_required": True,
            },
        }
    )
    scorecard = {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "run_id": run_id,
        "run_dir": str(run_dir.resolve()),
        "start": start,
        "end": end,
        "mode": source_metadata.get("mode"),
        "primary_model": source_scorecard.get("primary_model"),
        "run_class": "phase1c_positive_control_fixture",
        "phase_receipts": phase_receipts,
        "quality": quality,
        "token_usage": token_usage,
        "experiment": experiment,
        "positive_control_fixture": {
            "shape_id": shape_id,
            "provenance_classification": "synthetic_fixture",
            "source_run": str(source_run),
            "source_scorecard": str(source_scorecard_path),
            "source_scorecard_sha256": sha256_path(source_scorecard_path),
            "phase1c_available_only": True,
            "phase3_artifacts_copied_for_legacy_evaluator_binding_only": True,
            "adoption_grade": False,
            "corroboration_required": True,
        },
        "non_claims": [
            "Synthetic fixture scorecard; no live proof-run quality or token metrics are claimed.",
            "No production stop-gate adoption is claimed.",
            "No durable token-count or dollar-cost savings claim is made.",
        ],
    }
    scorecard_path = run_dir / "run-scorecard.json"
    write_json(scorecard_path, scorecard)
    return run_dir, scorecard_path


def expected_vscode_versions(source_root: Path, start: str, end: str) -> list[str]:
    logical = receipt_phase_logical_paths(start, end)
    scope = read_required_json(source_root / logical["phase0_scope_contract"], "source scope contract")
    expected = scope.get("expected_versions")
    if not isinstance(expected, dict) or not isinstance(expected.get("vscode"), list):
        raise SystemExit("Source scope contract is missing expected_versions.vscode")
    return [str(item) for item in expected["vscode"]]


def kept_versions_for_severe_loss(versions: list[str]) -> list[str]:
    if len(versions) < 4:
        raise SystemExit(
            "Severe version-loss positive control needs at least four expected VS Code "
            f"versions; source has {len(versions)}."
        )
    missing_floor = max(4, (len(versions) + 1) // 2)
    return versions[: max(0, len(versions) - missing_floor)]


def main() -> int:
    args = parse_args()
    source_run = Path(args.source_run).expanduser().resolve()
    source_metadata = read_required_json(source_run / "run-metadata.json", "source metadata")
    source_root = artifact_root(source_run, source_metadata)
    source_scorecard_path = (
        Path(args.source_scorecard).expanduser().resolve()
        if args.source_scorecard
        else source_run / "run-scorecard.json"
    )
    source_scorecard = read_required_json(source_scorecard_path, "source scorecard")
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    versions = expected_vscode_versions(
        source_root,
        str(source_metadata["start"]),
        str(source_metadata["end"]),
    )

    fixtures = [
        {
            "run_id": "phase1c_positive_control_low_continuity",
            "shape_id": "low_continuity_and_full_version_loss",
            "phase1b_heading_counts": {
                "phase1b_github": 12,
                "phase1b_vscode": 12,
                "phase1b_visualstudio": 12,
                "phase1b_jetbrains": 12,
                "phase1b_xcode": 12,
            },
            "phase1c_text": phase1c_low_continuity_text(),
        },
        {
            "run_id": "phase1c_positive_control_severe_version_loss",
            "shape_id": "severe_version_loss_with_borderline_continuity",
            "phase1b_heading_counts": {
                "phase1b_github": 2,
                "phase1b_vscode": 2,
                "phase1b_visualstudio": 2,
                "phase1b_jetbrains": 2,
                "phase1b_xcode": 2,
            },
            "phase1c_text": phase1c_severe_version_loss_text(
                kept_versions_for_severe_loss(versions)
            ),
        },
    ]
    rows: list[dict[str, Any]] = []
    for fixture in fixtures:
        run_dir, scorecard_path = build_fixture(
            run_id=str(fixture["run_id"]),
            shape_id=str(fixture["shape_id"]),
            source_run=source_run,
            source_root=source_root,
            source_metadata=source_metadata,
            source_scorecard=source_scorecard,
            source_scorecard_path=source_scorecard_path,
            output_dir=output_dir,
            phase1b_heading_counts=fixture["phase1b_heading_counts"],
            phase1c_text=str(fixture["phase1c_text"]),
        )
        evaluated = evaluate_run(run_dir, scorecard_path, {}, None)
        candidate = candidate_phase1c_checkpoint(evaluated.get("phase1c_checkpoint", {}))
        phase1c = evaluated.get("phase1c_checkpoint", {})
        rows.append(
            {
                "run_id": run_dir.name,
                "run_dir": str(run_dir),
                "scorecard_path": str(scorecard_path),
                "scorecard_sha256": sha256_path(scorecard_path),
                "provenance_classification": "synthetic_fixture",
                "positive_control_shape": fixture["shape_id"],
                "phase1c_available_only": phase1c.get("available_at_stop") is True,
                "phase3_artifacts_copied_for_legacy_evaluator_binding_only": True,
                "synthetic_or_fixture": True,
                "adoption_grade": False,
                "corroboration_required_for_adoption": True,
                "observed_phase1c_stop": evaluated.get("first_stop_phase") == "phase1c_discoveries",
                "candidate_observed_phase1c_stop": candidate.get("result") == "stop",
                "phase1b_heading_items": phase1c.get("phase1b_heading_items"),
                "phase1c_discovery_headings": phase1c.get("phase1c_discovery_headings"),
                "continuity_ratio": phase1c.get("continuity_ratio"),
                "missing_phase1c_vscode_versions": phase1c.get("missing_phase1c_vscode_versions"),
                "candidate_phase1c_checkpoint": candidate,
            }
        )

    pass_result = (
        len(rows) >= 2
        and all(row["phase1c_available_only"] for row in rows)
        and all(row["observed_phase1c_stop"] for row in rows)
        and all(row["candidate_observed_phase1c_stop"] for row in rows)
        and all(row["adoption_grade"] is False for row in rows)
    )
    payload = {
        "schema_version": 1,
        "receipt_type": "newsletter_phase1c_positive_control_probe",
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "pass": pass_result,
        "source_run": str(source_run),
        "source_scorecard": str(source_scorecard_path),
        "source_hashes": {
            "source_run_metadata": sha256_path(source_run / "run-metadata.json"),
            "source_scorecard": sha256_path(source_scorecard_path),
        },
        "positive_control_count": len(rows),
        "positive_controls": rows,
        "adoption_boundary": {
            "production_policy_adoption": False,
            "fixture_positive_controls_are_adoption_grade": False,
            "fresh_or_non_synthetic_corroboration_required": True,
        },
        "non_claims": [
            "No production stop-gate adoption is claimed.",
            "No durable token-count or dollar-cost savings claim is made.",
            "Positive-control fixtures intentionally exercise collapse shapes and require fresh or non-synthetic corroboration before adoption-grade use.",
            "Labels use only Phase-1C-available evidence: scope-contract expected versions, Phase 1B headings, and Phase 1C discovery content.",
        ],
    }
    write_json(Path(args.output).expanduser().resolve(), payload)
    print(args.output)
    return 0 if pass_result else 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Classify output-shape proof pairs with retained trace evidence."""

from __future__ import annotations

import argparse
import datetime as dt
import difflib
from pathlib import Path
from typing import Any

from build_output_shape_experiment_receipt import (
    direct_fields_pass,
    pricing_pass,
    prompt_equality_pass,
    quality_pass,
    token_summary,
    warning_classes,
)
from build_source_pruning_amplification_receipt import (
    numeric_delta,
    parse_session_trace,
    trace_deltas,
)
from newsletter_experiment_common import load_json, load_text, sha256_path, sha256_text, write_json
from product_run_common import logical_artifact_map


REPO_ROOT = Path(__file__).resolve().parent.parent


def resolve_run_dir(raw: str) -> Path:
    path = Path(raw).expanduser()
    if not path.is_absolute():
        path = REPO_ROOT / path
    return path.resolve()


def parse_pair(raw: str) -> tuple[str, Path, Path]:
    parts = raw.split(":")
    if len(parts) != 3 or not all(parts):
        raise SystemExit(f"Invalid --pair value, expected name:control_run_dir:variant_run_dir: {raw}")
    return parts[0], resolve_run_dir(parts[1]), resolve_run_dir(parts[2])


def require_scorecard(run_dir: Path) -> dict[str, Any]:
    path = run_dir / "run-scorecard.json"
    payload = load_json(path)
    if not isinstance(payload, dict):
        raise SystemExit(f"Missing or invalid scorecard: {path}")
    return payload


def is_within(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
    except ValueError:
        return False
    return True


def prompt_path_for(scorecard: dict[str, Any], run_dir: Path) -> Path:
    retained_snapshot = run_dir / "prompt.txt"
    if retained_snapshot.exists():
        return retained_snapshot
    raw = ((scorecard.get("experiment") or {}).get("prompt_path") or "")
    if raw:
        path = Path(str(raw)).expanduser()
        if not path.is_absolute():
            path = run_dir / path
        if path.exists() and is_within(path, run_dir):
            return path
    return retained_snapshot


def prompt_summary(scorecard: dict[str, Any], run_dir: Path) -> dict[str, Any]:
    path = prompt_path_for(scorecard, run_dir)
    text = load_text(path)
    if text is None:
        return {
            "path": str(path),
            "exists": False,
            "sha256": None,
            "bytes": None,
            "lines": None,
            "words": None,
            "output_shape_prompt_state": output_shape_prompt_state(None),
        }
    return {
        "path": str(path),
        "exists": True,
        "sha256": sha256_text(text),
        "bytes": len(text.encode("utf-8")),
        "lines": len(text.splitlines()),
        "words": len(text.split()),
        "output_shape_prompt_state": output_shape_prompt_state(text),
    }


def output_shape_prompt_state(text: str | None) -> dict[str, Any]:
    if text is None:
        return {
            "state": "output_shape_prompt_missing",
            "block_present": False,
            "enabled_marker_present": False,
            "disabled_marker_present": False,
            "apply_policy_command_present": False,
            "context_artifact_reference_present": False,
        }
    block_present = "Output-shape budget experiment:" in text
    enabled = "- Enabled with policy:" in text
    disabled = "- Disabled. Use the canonical output shape and quality bar." in text
    if enabled and not disabled:
        state = "output_shape_enabled_block"
    elif disabled and not enabled:
        state = "output_shape_disabled_block"
    elif not block_present:
        state = "output_shape_block_absent"
    else:
        state = "output_shape_block_ambiguous"
    return {
        "state": state,
        "block_present": block_present,
        "enabled_marker_present": enabled,
        "disabled_marker_present": disabled,
        "apply_policy_command_present": "apply_newsletter_output_shape_policy.py" in text,
        "context_artifact_reference_present": "newsletter_output_shape_context_" in text,
    }


def output_shape_prompt_surface_pass(prompt: dict[str, Any], expected_state: str) -> bool:
    state = prompt.get("output_shape_prompt_state") or {}
    if expected_state == "output_shape_disabled_block":
        return (
            state.get("state") == expected_state
            and state.get("block_present") is True
            and state.get("disabled_marker_present") is True
            and state.get("enabled_marker_present") is False
            and state.get("apply_policy_command_present") is False
            and state.get("context_artifact_reference_present") is False
        )
    if expected_state == "output_shape_enabled_block":
        return (
            state.get("state") == expected_state
            and state.get("block_present") is True
            and state.get("enabled_marker_present") is True
            and state.get("disabled_marker_present") is False
            and state.get("apply_policy_command_present") is True
            and state.get("context_artifact_reference_present") is True
        )
    return False


def prompt_diff_summary(control: dict[str, Any], variant: dict[str, Any]) -> dict[str, Any]:
    control_text = load_text(Path(str(control["path"]))) if control.get("exists") else None
    variant_text = load_text(Path(str(variant["path"]))) if variant.get("exists") else None
    if control_text is None or variant_text is None:
        return {"available": False, "reason": "one or both prompt snapshots are missing"}
    control_lines = control_text.splitlines()
    variant_lines = variant_text.splitlines()
    diff_lines = list(difflib.unified_diff(control_lines, variant_lines, lineterm=""))
    return {
        "available": True,
        "comparison_method": "retained_prompt_snapshot_text_diff",
        "control_words": control["words"],
        "variant_words": variant["words"],
        "word_delta_control_minus_variant": numeric_delta(control["words"], variant["words"]),
        "control_lines": control["lines"],
        "variant_lines": variant["lines"],
        "line_delta_control_minus_variant": numeric_delta(control["lines"], variant["lines"]),
        "similarity_ratio": round(difflib.SequenceMatcher(None, control_text, variant_text).ratio(), 6),
        "unified_diff_line_count": len(diff_lines),
        "control_output_shape_prompt_state": control["output_shape_prompt_state"],
        "variant_output_shape_prompt_state": variant["output_shape_prompt_state"],
    }


def snapshot_manifest_summary(run_dir: Path, start: str, end: str) -> dict[str, Any]:
    path = run_dir / "artifacts" / "snapshot-manifest.json"
    payload = load_json(path)
    logical = logical_artifact_map(start, end)
    output_shape_logical_paths = {
        "output_shape_context": logical["output_shape_context"],
        "output_shape_receipt": logical["output_shape_receipt"],
    }
    if not isinstance(payload, dict):
        return {
            "path": str(path),
            "exists": path.exists(),
            "sha256": sha256_path(path) if path.exists() else None,
            "copied_file_count": None,
            "copied_total_bytes": None,
            "output_shape_logical_paths": output_shape_logical_paths,
            "output_shape_files_in_manifest": [],
        }
    copied = payload.get("copied_files") if isinstance(payload.get("copied_files"), list) else []
    in_manifest = sorted(
        str(row.get("logical_path"))
        for row in copied
        if isinstance(row, dict) and row.get("logical_path") in output_shape_logical_paths.values()
    )
    return {
        "path": str(path),
        "exists": True,
        "sha256": sha256_path(path),
        "copied_file_count": len(copied),
        "copied_total_bytes": sum(
            int(row.get("size_bytes", 0) or 0) for row in copied if isinstance(row, dict)
        ),
        "output_shape_logical_paths": output_shape_logical_paths,
        "output_shape_files_in_manifest": in_manifest,
    }


def output_shape_artifact_presence(
    run_dir: Path,
    scorecard: dict[str, Any],
    manifest: dict[str, Any],
    *,
    expected_present: bool,
) -> dict[str, Any]:
    start = str(scorecard.get("start") or "")
    end = str(scorecard.get("end") or "")
    logical = logical_artifact_map(start, end)
    completeness = scorecard.get("artifact_completeness") or {}
    optional_missing_raw = completeness.get("optional_missing")
    required_missing_raw = completeness.get("required_missing")
    optional_missing = set(optional_missing_raw if isinstance(optional_missing_raw, list) else [])
    required_missing = set(required_missing_raw if isinstance(required_missing_raw, list) else [])
    manifest_paths = set(manifest.get("output_shape_files_in_manifest") or [])
    rows = []
    for name in ("output_shape_context", "output_shape_receipt"):
        path = run_dir / "artifacts" / logical[name]
        receipt_payload = load_json(path) if name == "output_shape_receipt" else None
        rows.append(
            {
                "artifact_name": name,
                "logical_path": logical[name],
                "path": str(path),
                "exists": path.exists(),
                "sha256": sha256_path(path) if path.exists() else None,
                "listed_in_snapshot_manifest": logical[name] in manifest_paths,
                "scorecard_optional_missing": name in optional_missing,
                "scorecard_required_missing": name in required_missing,
                "receipt_pass": (
                    receipt_payload.get("pass") is True
                    if isinstance(receipt_payload, dict) and name == "output_shape_receipt"
                    else None
                ),
                "receipt_policy_sha256": (
                    receipt_payload.get("policy_sha256")
                    if isinstance(receipt_payload, dict) and name == "output_shape_receipt"
                    else None
                ),
            }
        )
    actual_present = [
        row["artifact_name"]
        for row in rows
        if row["exists"] or row["listed_in_snapshot_manifest"]
    ]
    return {
        "rows": rows,
        "expected_present": expected_present,
        "absent_from_filesystem_and_manifest": not actual_present,
        "all_expected_artifacts_present_in_filesystem_and_manifest": all(
            row["exists"] and row["listed_in_snapshot_manifest"] for row in rows
        ),
        "scorecard_required_artifacts_not_missing": not any(
            row["scorecard_required_missing"] for row in rows
        ),
        "receipt_pass": any(
            row["artifact_name"] == "output_shape_receipt" and row["receipt_pass"] is True
            for row in rows
        ),
        "stale_or_unexpected_artifacts": [] if expected_present else actual_present,
    }


def request_count_matches_scorecard(trace: dict[str, Any], scorecard: dict[str, Any]) -> bool:
    trace_count = trace.get("shutdown_request_count")
    scorecard_count = (scorecard.get("token_usage") or {}).get("request_count")
    return isinstance(trace_count, int) and trace_count == scorecard_count


def command_delta(pair: dict[str, Any], category: str) -> int | float | None:
    trace = ((pair.get("deltas") or {}).get("trace_control_minus_variant") or {})
    categories = trace.get("command_category_counts") or {}
    value = categories.get(category)
    return value if isinstance(value, (int, float)) else None


def classify_pair(pair: dict[str, Any]) -> str:
    checks = pair.get("checks") or {}
    deltas = pair.get("deltas") or {}
    output_delta = deltas.get("output_tokens_control_minus_variant")
    input_delta = deltas.get("input_tokens_control_minus_variant")
    request_delta = deltas.get("request_count_control_minus_variant")
    total_delta = deltas.get("direct_provider_tokens_total_control_minus_variant")
    trace_delta = ((deltas.get("trace_control_minus_variant") or {}).get("tool_execution_start_count"))
    if not checks.get("control_output_shape_artifacts_absent"):
        return "control_artifact_contamination"
    if (
        not checks.get("variant_output_shape_artifacts_complete")
        or not checks.get("variant_run_class_pass")
        or not checks.get("policy_hash_bound")
    ):
        return "variant_artifact_or_policy_binding_defect"
    if not checks.get("control_session_trace_qualified") or not checks.get("variant_session_trace_qualified"):
        return "trace_incomplete_fail_closed"
    if (
        not checks.get("control_prompt_equality_pass")
        or not checks.get("variant_prompt_equality_pass")
        or not checks.get("prompt_state_comparable")
        or not checks.get("control_prompt_surface_pass")
        or not checks.get("variant_prompt_surface_pass")
        or not checks.get("control_run_class_pass")
        or not checks.get("control_trace_request_count_matches_scorecard")
        or not checks.get("variant_trace_request_count_matches_scorecard")
    ):
        return "prompt_renderer_or_scorecard_binding_defect"
    if pair.get("pair_qualified") is True:
        return "qualified_repair_signal"
    if (
        isinstance(request_delta, (int, float)) and request_delta < 0
    ) or (
        isinstance(trace_delta, (int, float)) and trace_delta < 0
    ) or (
        isinstance(command_delta(pair, "search_or_inspection"), (int, float))
        and command_delta(pair, "search_or_inspection") < 0
    ):
        return "request_or_tool_trace_amplification"
    if isinstance(command_delta(pair, "validation_or_receipt"), (int, float)) and command_delta(pair, "validation_or_receipt") < 0:
        return "validation_or_receipt_overhead_amplification"
    if isinstance(command_delta(pair, "materialization_or_builder"), (int, float)) and command_delta(pair, "materialization_or_builder") < 0:
        return "materialization_or_builder_amplification"
    if any(isinstance(value, (int, float)) and value < 0 for value in (output_delta, input_delta, total_delta)):
        return "model_behavior_output_budget_counterproductive"
    return "current_policy_path_failed_closed"


def build_pair(name: str, control_dir: Path, variant_dir: Path) -> dict[str, Any]:
    control_scorecard = require_scorecard(control_dir)
    variant_scorecard = require_scorecard(variant_dir)
    control_tokens = token_summary(control_scorecard)
    variant_tokens = token_summary(variant_scorecard)
    control_prompt = prompt_summary(control_scorecard, control_dir)
    variant_prompt = prompt_summary(variant_scorecard, variant_dir)
    control_manifest = snapshot_manifest_summary(
        control_dir, str(control_scorecard.get("start") or ""), str(control_scorecard.get("end") or "")
    )
    variant_manifest = snapshot_manifest_summary(
        variant_dir, str(variant_scorecard.get("start") or ""), str(variant_scorecard.get("end") or "")
    )
    control_artifacts = output_shape_artifact_presence(
        control_dir, control_scorecard, control_manifest, expected_present=False
    )
    variant_artifacts = output_shape_artifact_presence(
        variant_dir, variant_scorecard, variant_manifest, expected_present=True
    )
    control_trace = parse_session_trace(control_dir)
    variant_trace = parse_session_trace(variant_dir)
    shape_receipt_row = next(
        (row for row in variant_artifacts["rows"] if row["artifact_name"] == "output_shape_receipt"),
        {},
    )
    variant_policy = ((variant_scorecard.get("experiment") or {}).get("output_shape_policy") or {})
    policy_hash_bound = (
        variant_policy.get("policy_sha256") is not None
        and variant_policy.get("policy_sha256") == shape_receipt_row.get("receipt_policy_sha256")
    )
    control_state = control_prompt["output_shape_prompt_state"]["state"]
    variant_state = variant_prompt["output_shape_prompt_state"]["state"]
    prompt_state_comparable = (
        control_state == "output_shape_disabled_block"
        and variant_state == "output_shape_enabled_block"
    )
    control_prompt_surface_pass = output_shape_prompt_surface_pass(control_prompt, "output_shape_disabled_block")
    variant_prompt_surface_pass = output_shape_prompt_surface_pass(variant_prompt, "output_shape_enabled_block")
    output_delta = numeric_delta(control_tokens.get("output_tokens"), variant_tokens.get("output_tokens"))
    input_delta = numeric_delta(control_tokens.get("input_tokens"), variant_tokens.get("input_tokens"))
    request_delta = numeric_delta(control_tokens.get("request_count"), variant_tokens.get("request_count"))
    cost_delta = numeric_delta(control_tokens.get("total_usd"), variant_tokens.get("total_usd"))
    total_delta = numeric_delta(
        control_tokens.get("direct_provider_tokens_total"),
        variant_tokens.get("direct_provider_tokens_total"),
    )
    new_warning_classes = sorted(warning_classes(variant_scorecard) - warning_classes(control_scorecard))
    checks = {
        "same_mode": control_scorecard.get("mode") == variant_scorecard.get("mode"),
        "same_date_range": control_scorecard.get("start") == variant_scorecard.get("start")
        and control_scorecard.get("end") == variant_scorecard.get("end"),
        "same_primary_model": control_scorecard.get("primary_model") == variant_scorecard.get("primary_model"),
        "control_prompt_equality_pass": prompt_equality_pass(control_scorecard),
        "variant_prompt_equality_pass": prompt_equality_pass(variant_scorecard),
        "prompt_state_comparable": prompt_state_comparable,
        "control_prompt_surface_pass": control_prompt_surface_pass,
        "variant_prompt_surface_pass": variant_prompt_surface_pass,
        "control_direct_token_fields_pass": direct_fields_pass(control_scorecard),
        "variant_direct_token_fields_pass": direct_fields_pass(variant_scorecard),
        "control_quality_pass": quality_pass(control_scorecard),
        "variant_quality_pass": quality_pass(variant_scorecard),
        "control_pricing_pass": pricing_pass(control_scorecard),
        "variant_pricing_pass": pricing_pass(variant_scorecard),
        "control_output_shape_artifacts_absent": control_artifacts["absent_from_filesystem_and_manifest"],
        "variant_output_shape_artifacts_complete": variant_artifacts[
            "all_expected_artifacts_present_in_filesystem_and_manifest"
        ]
        and variant_artifacts["scorecard_required_artifacts_not_missing"]
        and variant_artifacts["receipt_pass"],
        "control_run_class_pass": (
            ((control_scorecard.get("experiment") or {}).get("run_class") in {"output_shape_control", "anchor_control"})
        ),
        "variant_run_class_pass": (
            ((variant_scorecard.get("experiment") or {}).get("run_class") == "output_shape_candidate")
        ),
        "policy_hash_bound": policy_hash_bound,
        "control_session_trace_qualified": control_trace["trace_variance_qualified"],
        "variant_session_trace_qualified": variant_trace["trace_variance_qualified"],
        "control_trace_request_count_matches_scorecard": request_count_matches_scorecard(
            control_trace, control_scorecard
        ),
        "variant_trace_request_count_matches_scorecard": request_count_matches_scorecard(
            variant_trace, variant_scorecard
        ),
        "output_tokens_lower": isinstance(output_delta, (int, float)) and output_delta > 0,
        "input_tokens_not_higher": not isinstance(input_delta, (int, float)) or input_delta >= 0,
        "request_count_not_higher": not isinstance(request_delta, (int, float)) or request_delta >= 0,
        "total_direct_provider_tokens_lower": isinstance(total_delta, (int, float)) and total_delta > 0,
        "api_equivalent_cost_not_higher": isinstance(cost_delta, (int, float)) and cost_delta >= 0,
        "no_new_warning_taxonomy": not new_warning_classes,
    }
    evidence_checks = (
        "same_mode",
        "same_date_range",
        "same_primary_model",
        "control_prompt_equality_pass",
        "variant_prompt_equality_pass",
        "prompt_state_comparable",
        "control_prompt_surface_pass",
        "variant_prompt_surface_pass",
        "control_direct_token_fields_pass",
        "variant_direct_token_fields_pass",
        "control_quality_pass",
        "variant_quality_pass",
        "control_pricing_pass",
        "variant_pricing_pass",
        "control_output_shape_artifacts_absent",
        "variant_output_shape_artifacts_complete",
        "control_run_class_pass",
        "variant_run_class_pass",
        "policy_hash_bound",
        "control_session_trace_qualified",
        "variant_session_trace_qualified",
        "control_trace_request_count_matches_scorecard",
        "variant_trace_request_count_matches_scorecard",
        "no_new_warning_taxonomy",
    )
    pair_qualified = all(checks.values())
    row: dict[str, Any] = {
        "pair_name": name,
        "mode": control_scorecard.get("mode"),
        "start": control_scorecard.get("start"),
        "end": control_scorecard.get("end"),
        "primary_model": control_scorecard.get("primary_model"),
        "control_run_id": control_scorecard.get("run_id"),
        "variant_run_id": variant_scorecard.get("run_id"),
        "control_run_dir": str(control_dir),
        "variant_run_dir": str(variant_dir),
        "control_scorecard_sha256": sha256_path(control_dir / "run-scorecard.json"),
        "variant_scorecard_sha256": sha256_path(variant_dir / "run-scorecard.json"),
        "checks": checks,
        "evidence_complete": all(checks[key] for key in evidence_checks),
        "pair_qualified": pair_qualified,
        "control": {
            "tokens": control_tokens,
            "prompt": control_prompt,
            "snapshot_manifest": control_manifest,
            "output_shape_artifact_absence": control_artifacts,
            "session_trace": control_trace,
        },
        "variant": {
            "tokens": variant_tokens,
            "scorecard_experiment": variant_scorecard.get("experiment") or {},
            "prompt": variant_prompt,
            "snapshot_manifest": variant_manifest,
            "output_shape_artifact_presence": variant_artifacts,
            "session_trace": variant_trace,
        },
        "prompt_diff": prompt_diff_summary(control_prompt, variant_prompt),
        "deltas": {
            "input_tokens_control_minus_variant": input_delta,
            "output_tokens_control_minus_variant": output_delta,
            "cache_read_tokens_control_minus_variant": numeric_delta(
                control_tokens.get("cache_read_tokens"), variant_tokens.get("cache_read_tokens")
            ),
            "cache_write_tokens_control_minus_variant": numeric_delta(
                control_tokens.get("cache_write_tokens"), variant_tokens.get("cache_write_tokens")
            ),
            "reasoning_tokens_control_minus_variant": numeric_delta(
                control_tokens.get("reasoning_tokens"), variant_tokens.get("reasoning_tokens")
            ),
            "request_count_control_minus_variant": request_delta,
            "direct_provider_tokens_total_control_minus_variant": total_delta,
            "api_equivalent_usd_control_minus_variant": cost_delta,
            "trace_control_minus_variant": trace_deltas(control_trace, variant_trace),
        },
        "new_warning_taxonomy_classes": new_warning_classes,
    }
    row["classification"] = classify_pair(row)
    return row


def tested_policy_ids(pairs: list[dict[str, Any]]) -> list[str]:
    ids = set()
    for pair in pairs:
        policy = (((pair.get("variant") or {}).get("scorecard_experiment") or {}).get("output_shape_policy") or {})
        policy_id = policy.get("policy_id")
        if policy_id:
            ids.add(str(policy_id))
    return sorted(ids)


def mode_summaries(pairs: list[dict[str, Any]]) -> dict[str, Any]:
    summaries: dict[str, dict[str, Any]] = {}
    for pair in pairs:
        mode = str(pair.get("mode") or "unknown")
        summary = summaries.setdefault(
            mode,
            {
                "pair_count": 0,
                "evidence_complete_count": 0,
                "qualified_pair_count": 0,
                "classification_counts": {},
                "pair_names": [],
            },
        )
        summary["pair_count"] += 1
        summary["pair_names"].append(pair.get("pair_name"))
        if pair.get("evidence_complete") is True:
            summary["evidence_complete_count"] += 1
        if pair.get("pair_qualified") is True:
            summary["qualified_pair_count"] += 1
        classification = str(pair.get("classification") or "unknown")
        counts = summary["classification_counts"]
        counts[classification] = counts.get(classification, 0) + 1
    for summary in summaries.values():
        summary["evidence_complete"] = summary["pair_count"] == summary["evidence_complete_count"]
        summary["all_pairs_qualified"] = summary["pair_count"] == summary["qualified_pair_count"]
    return dict(sorted(summaries.items()))


def aggregate_result(pairs: list[dict[str, Any]]) -> tuple[str, str, dict[str, Any]]:
    classifications = [str(pair.get("classification") or "") for pair in pairs]
    summaries = mode_summaries(pairs)
    qualified_modes = sorted(
        mode for mode, summary in summaries.items() if summary.get("qualified_pair_count", 0) > 0
    )
    all_modes_fully_qualified = bool(summaries) and all(
        summary.get("all_pairs_qualified") is True for summary in summaries.values()
    )
    if all_modes_fully_qualified:
        return (
            "output_shape_repair_signal_observed",
            "Promote a small benchmark confirmation matrix only for the qualified repaired output-shape path.",
            summaries,
        )
    if qualified_modes:
        return (
            "mode_specific_output_shape_repair_signal_observed",
            "Promote only the qualified mode(s): "
            + ", ".join(qualified_modes)
            + "; keep non-qualified modes fail-closed.",
            summaries,
        )
    if any(
        classification
        in {
            "control_artifact_contamination",
            "variant_artifact_or_policy_binding_defect",
            "prompt_renderer_or_scorecard_binding_defect",
        }
        for classification in classifications
    ):
        return (
            "repairable_current_path_defect",
            "Fix the named owner-side binding/artifact defect before additional live output-shape spend.",
            summaries,
        )
    if any(classification == "trace_incomplete_fail_closed" for classification in classifications):
        return (
            "trace_incomplete_fail_closed",
            "Repair the exact session trace or request-count binding blocker before any replication row.",
            summaries,
        )
    if pairs and all(pair.get("evidence_complete") is True for pair in pairs):
        return (
            "current_policy_path_counterproductive",
            "Park the tested output-shape policy path as a promoted optimization path unless a later batch authorizes a new mechanism.",
            summaries,
        )
    return (
        "current_policy_path_failed_closed",
        "Do not promote output-shape until the non-qualified checks are repaired and replayed.",
        summaries,
    )


def build_receipt(pairs: list[tuple[str, Path, Path]], *, fresh_live_spend_used: bool = False) -> dict[str, Any]:
    pair_rows = [build_pair(name, control, variant) for name, control, variant in pairs]
    result, next_move, summaries = aggregate_result(pair_rows)
    classifications: dict[str, int] = {}
    for pair in pair_rows:
        key = str(pair.get("classification") or "unknown")
        classifications[key] = classifications.get(key, 0) + 1
    evidence_pass_count = sum(1 for pair in pair_rows if pair.get("evidence_complete") is True)
    return {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "receipt_type": "newsletter_output_shape_amplification_trace_rca",
        "result": result,
        "pass": result == "output_shape_repair_signal_observed",
        "evidence_complete": bool(pair_rows) and evidence_pass_count == len(pair_rows),
        "fresh_live_spend_used": fresh_live_spend_used,
        "tested_policy_ids": tested_policy_ids(pair_rows),
        "pair_count": len(pair_rows),
        "trace_evidence_pass_count": evidence_pass_count,
        "classification_counts": dict(sorted(classifications.items())),
        "mode_summaries": summaries,
        "pairs": pair_rows,
        "recommended_next_owner_move": next_move,
        "non_claims": [
            "No production adoption",
            "No durable token or dollar savings claim",
            "No GitHub Copilot billing proof",
            "No model recommendation",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pair", action="append", required=True, help="name:control_run_dir:variant_run_dir")
    parser.add_argument(
        "--fresh-live-spend-used",
        action="store_true",
        help="Mark the receipt as including fresh live proof rows.",
    )
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    receipt = build_receipt(
        [parse_pair(raw) for raw in args.pair],
        fresh_live_spend_used=args.fresh_live_spend_used,
    )
    output = Path(args.output).expanduser().resolve()
    write_json(output, receipt)
    print(output)
    return 0 if receipt.get("pass") is True else 1


if __name__ == "__main__":
    raise SystemExit(main())

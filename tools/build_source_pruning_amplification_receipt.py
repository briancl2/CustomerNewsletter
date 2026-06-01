#!/usr/bin/env python3
"""Replay source-pruning proof pairs and classify amplification evidence."""

from __future__ import annotations

import argparse
import datetime as dt
import difflib
import json
from collections import Counter
from pathlib import Path
from typing import Any

from build_source_pruning_experiment_receipt import (
    direct_fields_pass,
    pricing_pass,
    prompt_equality_pass,
    quality_pass,
    token_summary,
    warning_classes,
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
        raise SystemExit(f"Invalid --pair value, expected name:control_run_dir:pruned_run_dir: {raw}")
    return parts[0], resolve_run_dir(parts[1]), resolve_run_dir(parts[2])


def require_scorecard(run_dir: Path) -> dict[str, Any]:
    path = run_dir / "run-scorecard.json"
    payload = load_json(path)
    if not isinstance(payload, dict):
        raise SystemExit(f"Missing or invalid scorecard: {path}")
    return payload


def int_or_none(value: Any) -> int | None:
    try:
        if value is None:
            return None
        return int(float(value))
    except (TypeError, ValueError):
        return None


def numeric_delta(control: Any, pruned: Any) -> int | float | None:
    if isinstance(control, (int, float)) and isinstance(pruned, (int, float)):
        return control - pruned
    return None


def prompt_path_for(scorecard: dict[str, Any], run_dir: Path) -> Path:
    path = Path(str(((scorecard.get("experiment") or {}).get("prompt_path") or "")))
    if path.exists():
        return path
    return run_dir / "prompt.txt"


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
        }
    return {
        "path": str(path),
        "exists": True,
        "sha256": sha256_text(text),
        "bytes": len(text.encode("utf-8")),
        "lines": len(text.splitlines()),
        "words": len(text.split()),
    }


def prompt_diff_summary(control: dict[str, Any], pruned: dict[str, Any]) -> dict[str, Any]:
    control_text = load_text(Path(str(control["path"]))) if control.get("exists") else None
    pruned_text = load_text(Path(str(pruned["path"]))) if pruned.get("exists") else None
    if control_text is None or pruned_text is None:
        return {
            "available": False,
            "reason": "one or both prompt snapshots are missing",
        }
    control_state = source_pruning_prompt_state(control_text)
    pruned_state = source_pruning_prompt_state(pruned_text)
    control_lines = control_text.splitlines()
    pruned_lines = pruned_text.splitlines()
    diff_lines = list(difflib.unified_diff(control_lines, pruned_lines, lineterm=""))
    return {
        "available": True,
        "comparison_method": "retained_prompt_snapshot_text_diff",
        "control_words": control["words"],
        "pruned_words": pruned["words"],
        "word_delta_control_minus_pruned": numeric_delta(control["words"], pruned["words"]),
        "control_lines": control["lines"],
        "pruned_lines": pruned["lines"],
        "line_delta_control_minus_pruned": numeric_delta(control["lines"], pruned["lines"]),
        "similarity_ratio": round(difflib.SequenceMatcher(None, control_text, pruned_text).ratio(), 6),
        "unified_diff_line_count": len(diff_lines),
        "pruned_source_pruning_block_present": "Source-pruning experiment:" in pruned_text,
        "control_source_pruning_block_present": "Source-pruning experiment:" in control_text,
        "control_source_pruning_prompt_state": control_state,
        "pruned_source_pruning_prompt_state": pruned_state,
    }


def source_pruning_prompt_state(text: str) -> dict[str, Any]:
    block_present = "Source-pruning experiment:" in text
    enabled = "- Enabled with policy:" in text
    disabled = "- Disabled. Use the canonical source/candidate artifacts directly." in text
    if enabled and not disabled:
        state = "source_pruning_enabled_block"
    elif disabled and not enabled:
        state = "source_pruning_disabled_block"
    elif not block_present:
        state = "source_pruning_block_absent"
    else:
        state = "source_pruning_block_ambiguous"
    return {
        "state": state,
        "block_present": block_present,
        "enabled_marker_present": enabled,
        "disabled_marker_present": disabled,
        "apply_policy_command_present": "apply_newsletter_source_pruning_policy.py" in text,
        "context_artifact_reference_present": "newsletter_source_pruning_context_" in text,
    }


def snapshot_manifest_summary(run_dir: Path, start: str, end: str) -> dict[str, Any]:
    path = run_dir / "artifacts" / "snapshot-manifest.json"
    payload = load_json(path)
    logical = logical_artifact_map(start, end)
    source_pruning_logical_paths = {
        "source_pruning_context": logical["source_pruning_context"],
        "source_pruning_receipt": logical["source_pruning_receipt"],
    }
    if not isinstance(payload, dict):
        return {
            "path": str(path),
            "exists": path.exists(),
            "sha256": sha256_path(path) if path.exists() else None,
            "copied_file_count": None,
            "copied_total_bytes": None,
            "source_pruning_logical_paths": source_pruning_logical_paths,
            "source_pruning_files_in_manifest": [],
        }
    copied = payload.get("copied_files") if isinstance(payload.get("copied_files"), list) else []
    in_manifest = sorted(
        str(row.get("logical_path"))
        for row in copied
        if isinstance(row, dict) and row.get("logical_path") in source_pruning_logical_paths.values()
    )
    return {
        "path": str(path),
        "exists": True,
        "sha256": sha256_path(path),
        "copied_file_count": len(copied),
        "copied_total_bytes": sum(
            int(row.get("size_bytes", 0) or 0) for row in copied if isinstance(row, dict)
        ),
        "source_pruning_logical_paths": source_pruning_logical_paths,
        "source_pruning_files_in_manifest": in_manifest,
    }


def source_pruning_artifact_presence(
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
    optional_present_raw = completeness.get("optional_present")
    required_missing_raw = completeness.get("required_missing")
    optional_missing = set(optional_missing_raw if isinstance(optional_missing_raw, list) else [])
    optional_present = set(optional_present_raw if isinstance(optional_present_raw, list) else [])
    required_missing = set(required_missing_raw if isinstance(required_missing_raw, list) else [])
    rows = []
    for name in ("source_pruning_context", "source_pruning_receipt"):
        path = run_dir / "artifacts" / logical[name]
        receipt_payload = load_json(path) if name == "source_pruning_receipt" else None
        rows.append(
            {
                "artifact_name": name,
                "logical_path": logical[name],
                "path": str(path),
                "exists": path.exists(),
                "sha256": sha256_path(path) if path.exists() else None,
                "listed_in_snapshot_manifest": logical[name]
                in set(manifest.get("source_pruning_files_in_manifest") or []),
                "scorecard_optional_missing": name in optional_missing,
                "scorecard_optional_present": name in optional_present,
                "scorecard_required_missing": name in required_missing,
                "receipt_admission_pass": (
                    ((receipt_payload or {}).get("admission") or {}).get("pass") is True
                    if name == "source_pruning_receipt"
                    else None
                ),
            }
        )
    actual_present = [
        row["artifact_name"]
        for row in rows
        if row["exists"] or row["listed_in_snapshot_manifest"] or row["scorecard_optional_present"]
    ]
    stale_present = []
    if not expected_present:
        stale_present = actual_present
    return {
        "rows": rows,
        "expected_present": expected_present,
        "absent_from_filesystem_manifest_and_scorecard": not actual_present,
        "all_expected_artifacts_present_in_filesystem_and_manifest": all(
            row["exists"] and row["listed_in_snapshot_manifest"] for row in rows
        ),
        "scorecard_required_artifacts_not_missing": not any(
            row["scorecard_required_missing"] for row in rows
        ),
        "receipt_admission_pass": any(
            row["artifact_name"] == "source_pruning_receipt"
            and row["receipt_admission_pass"] is True
            for row in rows
        ),
        "stale_or_unexpected_artifacts": stale_present,
    }


def categorize_command(tool_name: str, command: str) -> set[str]:
    categories: set[str] = set()
    lowered = command.lower()
    if tool_name in {"rg", "glob", "view"} or any(
        needle in lowered
        for needle in ("rg ", "find ", "grep", "ls ", "sed ", "cat ", "jq ", "head ", "tail ")
    ):
        categories.add("search_or_inspection")
    if any(
        needle in lowered
        for needle in (
            "prepare_newsletter_cycle",
            "generate_scope_contract",
            "extract_event_sources",
            "materialize",
            "build_phase3_working_set",
            "init_phase3_curated",
            "cp ",
            "install ",
        )
    ):
        categories.add("materialization_or_builder")
    if any(
        needle in lowered
        for needle in (
            "validate_",
            "score-",
            "rubric",
            "record_phase_receipt",
            "snapshot_product_run_artifacts",
        )
    ):
        categories.add("validation_or_receipt")
    if "source_pruning" in lowered or "source-pruning" in lowered:
        categories.add("source_pruning")
    if "output_shape" in lowered or "output-shape" in lowered:
        categories.add("output_shape")
    return categories


def parse_session_trace(run_dir: Path) -> dict[str, Any]:
    path = run_dir / "session" / "events.jsonl"
    if not path.exists():
        return {
            "path": str(path),
            "exists": False,
            "parse_error_count": 0,
            "event_count": 0,
            "tool_execution_start_count": 0,
            "tool_counts": {},
            "command_category_counts": {},
            "shutdown_model_metrics_present": False,
            "shutdown_request_count": None,
            "trace_variance_qualified": False,
            "qualification_reason": "session/events.jsonl is missing",
        }
    event_count = 0
    parse_error_count = 0
    tool_counts: Counter[str] = Counter()
    category_counts: Counter[str] = Counter()
    shutdown_request_count = 0
    shutdown_model_metrics_present = False
    session_ids: set[str] = set()
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if not line.strip():
            continue
        event_count += 1
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            parse_error_count += 1
            continue
        data = event.get("data") if isinstance(event.get("data"), dict) else {}
        if event.get("type") == "session.start":
            session_id = ((data.get("sessionId") if isinstance(data, dict) else None) or "")
            if session_id:
                session_ids.add(str(session_id))
        if event.get("type") == "tool.execution_start":
            tool_name = str(data.get("toolName") or "")
            tool_counts[tool_name] += 1
            args = data.get("arguments") if isinstance(data.get("arguments"), dict) else {}
            command = str(args.get("command") or "")
            for category in categorize_command(tool_name, command):
                category_counts[category] += 1
        if event.get("type") == "session.shutdown":
            metrics = data.get("modelMetrics") if isinstance(data.get("modelMetrics"), dict) else {}
            shutdown_model_metrics_present = shutdown_model_metrics_present or bool(metrics)
            for row in metrics.values():
                if not isinstance(row, dict):
                    continue
                requests = row.get("requests") if isinstance(row.get("requests"), dict) else {}
                count = int_or_none(requests.get("count"))
                if count is not None:
                    shutdown_request_count += count
    qualified = parse_error_count == 0 and event_count > 0 and sum(tool_counts.values()) > 0
    qualified = qualified and shutdown_model_metrics_present
    reason = (
        "retained session trace exposes tool starts and shutdown modelMetrics"
        if qualified
        else "retained session trace is missing tool starts or shutdown modelMetrics"
    )
    return {
        "path": str(path),
        "exists": True,
        "sha256": sha256_path(path),
        "parse_error_count": parse_error_count,
        "event_count": event_count,
        "session_ids": sorted(session_ids),
        "tool_execution_start_count": sum(tool_counts.values()),
        "tool_counts": dict(sorted(tool_counts.items())),
        "command_category_counts": dict(sorted(category_counts.items())),
        "shutdown_model_metrics_present": shutdown_model_metrics_present,
        "shutdown_request_count": shutdown_request_count,
        "trace_variance_qualified": qualified,
        "qualification_reason": reason,
    }


def trace_deltas(control: dict[str, Any], pruned: dict[str, Any]) -> dict[str, Any]:
    categories = sorted(
        set(control.get("command_category_counts") or {})
        | set(pruned.get("command_category_counts") or {})
    )
    return {
        "tool_execution_start_count": numeric_delta(
            control.get("tool_execution_start_count"),
            pruned.get("tool_execution_start_count"),
        ),
        "shutdown_request_count": numeric_delta(
            control.get("shutdown_request_count"),
            pruned.get("shutdown_request_count"),
        ),
        "command_category_counts": {
            category: numeric_delta(
                (control.get("command_category_counts") or {}).get(category, 0),
                (pruned.get("command_category_counts") or {}).get(category, 0),
            )
            for category in categories
        },
    }


def build_pair(name: str, control_dir: Path, pruned_dir: Path) -> dict[str, Any]:
    control_scorecard = require_scorecard(control_dir)
    pruned_scorecard = require_scorecard(pruned_dir)
    control_tokens = token_summary(control_scorecard)
    pruned_tokens = token_summary(pruned_scorecard)
    control_prompt = prompt_summary(control_scorecard, control_dir)
    pruned_prompt = prompt_summary(pruned_scorecard, pruned_dir)
    control_manifest = snapshot_manifest_summary(
        control_dir, str(control_scorecard.get("start") or ""), str(control_scorecard.get("end") or "")
    )
    pruned_manifest = snapshot_manifest_summary(
        pruned_dir, str(pruned_scorecard.get("start") or ""), str(pruned_scorecard.get("end") or "")
    )
    control_artifacts = source_pruning_artifact_presence(
        control_dir, control_scorecard, control_manifest, expected_present=False
    )
    pruned_artifacts = source_pruning_artifact_presence(
        pruned_dir, pruned_scorecard, pruned_manifest, expected_present=True
    )
    control_trace = parse_session_trace(control_dir)
    pruned_trace = parse_session_trace(pruned_dir)
    input_delta = numeric_delta(control_tokens.get("input_tokens"), pruned_tokens.get("input_tokens"))
    request_delta = numeric_delta(control_tokens.get("request_count"), pruned_tokens.get("request_count"))
    cost_delta = numeric_delta(control_tokens.get("total_usd"), pruned_tokens.get("total_usd"))
    new_warning_classes = sorted(warning_classes(pruned_scorecard) - warning_classes(control_scorecard))
    pruned_policy = ((pruned_scorecard.get("experiment") or {}).get("source_pruning_policy") or {})
    pruning_receipt_path = (
        pruned_dir
        / "artifacts"
        / logical_artifact_map(
            str(pruned_scorecard.get("start") or ""), str(pruned_scorecard.get("end") or "")
        )["source_pruning_receipt"]
    )
    pruning_receipt = load_json(pruning_receipt_path)
    policy_hash_bound = (
        isinstance(pruning_receipt, dict)
        and pruned_policy.get("policy_sha256") == pruning_receipt.get("policy_sha256")
    )
    checks = {
        "same_mode": control_scorecard.get("mode") == pruned_scorecard.get("mode"),
        "same_date_range": control_scorecard.get("start") == pruned_scorecard.get("start")
        and control_scorecard.get("end") == pruned_scorecard.get("end"),
        "same_primary_model": control_scorecard.get("primary_model")
        == pruned_scorecard.get("primary_model"),
        "control_prompt_equality_pass": prompt_equality_pass(control_scorecard),
        "pruned_prompt_equality_pass": prompt_equality_pass(pruned_scorecard),
        "control_direct_token_fields_pass": direct_fields_pass(control_scorecard),
        "pruned_direct_token_fields_pass": direct_fields_pass(pruned_scorecard),
        "control_quality_pass": quality_pass(control_scorecard),
        "pruned_quality_pass": quality_pass(pruned_scorecard),
        "control_pricing_pass": pricing_pass(control_scorecard),
        "pruned_pricing_pass": pricing_pass(pruned_scorecard),
        "control_source_pruning_artifacts_absent": control_artifacts[
            "absent_from_filesystem_manifest_and_scorecard"
        ],
        "pruned_source_pruning_artifacts_complete": pruned_artifacts[
            "all_expected_artifacts_present_in_filesystem_and_manifest"
        ]
        and pruned_artifacts["scorecard_required_artifacts_not_missing"]
        and pruned_artifacts["receipt_admission_pass"],
        "pruned_run_class_pass": (
            ((pruned_scorecard.get("experiment") or {}).get("run_class") == "source_pruning_candidate")
        ),
        "policy_hash_bound": policy_hash_bound,
        "control_session_trace_qualified": control_trace["trace_variance_qualified"],
        "pruned_session_trace_qualified": pruned_trace["trace_variance_qualified"],
        "input_tokens_lower": isinstance(input_delta, (int, float)) and input_delta > 0,
        "request_count_not_higher": isinstance(request_delta, (int, float)) and request_delta >= 0,
        "no_new_warning_taxonomy": not new_warning_classes,
    }
    base_evidence_pass = all(
        checks[key]
        for key in (
            "same_mode",
            "same_date_range",
            "same_primary_model",
            "control_prompt_equality_pass",
            "pruned_prompt_equality_pass",
            "control_direct_token_fields_pass",
            "pruned_direct_token_fields_pass",
            "control_quality_pass",
            "pruned_quality_pass",
            "control_pricing_pass",
            "pruned_pricing_pass",
            "control_source_pruning_artifacts_absent",
            "pruned_source_pruning_artifacts_complete",
            "pruned_run_class_pass",
            "policy_hash_bound",
            "control_session_trace_qualified",
            "pruned_session_trace_qualified",
            "no_new_warning_taxonomy",
        )
    )
    blockers = []
    if not checks["control_source_pruning_artifacts_absent"]:
        blockers.append("control_stale_source_pruning_artifacts_present")
    if not checks["control_session_trace_qualified"] or not checks["pruned_session_trace_qualified"]:
        blockers.append("missing_retained_session_trace_variance_evidence")
    if isinstance(input_delta, (int, float)) and input_delta < 0:
        blockers.append("input_token_amplification_detected")
    if isinstance(request_delta, (int, float)) and request_delta < 0:
        blockers.append("request_count_amplification_detected")
    if not checks["input_tokens_lower"] and "input_token_amplification_detected" not in blockers:
        blockers.append("input_token_reduction_not_observed")
    if new_warning_classes:
        blockers.append("new_warning_taxonomy_detected")
    admitted = base_evidence_pass and checks["input_tokens_lower"] and checks["request_count_not_higher"]
    if admitted:
        classification = "qualified_mode_specific_source_pruning_signal"
    elif "control_stale_source_pruning_artifacts_present" in blockers:
        classification = "blocked_by_stale_control_pruning_artifacts"
    elif any("amplification" in blocker for blocker in blockers):
        classification = "amplification_detected"
    elif "missing_retained_session_trace_variance_evidence" in blockers:
        classification = "fail_closed_missing_variance_evidence"
    else:
        classification = "not_qualified"
    return {
        "pair_name": name,
        "classification": classification,
        "admitted_for_mode_specific_follow_on": admitted,
        "mode": control_scorecard.get("mode"),
        "start": control_scorecard.get("start"),
        "end": control_scorecard.get("end"),
        "primary_model": control_scorecard.get("primary_model"),
        "control_run_id": control_scorecard.get("run_id"),
        "pruned_run_id": pruned_scorecard.get("run_id"),
        "control_run_dir": str(control_dir),
        "pruned_run_dir": str(pruned_dir),
        "control_scorecard_sha256": sha256_path(control_dir / "run-scorecard.json"),
        "pruned_scorecard_sha256": sha256_path(pruned_dir / "run-scorecard.json"),
        "checks": checks,
        "blockers": blockers,
        "control": {
            "tokens": control_tokens,
            "prompt": control_prompt,
            "snapshot_manifest": control_manifest,
            "source_pruning_artifact_absence": control_artifacts,
            "session_trace": control_trace,
        },
        "pruned": {
            "tokens": pruned_tokens,
            "prompt": pruned_prompt,
            "snapshot_manifest": pruned_manifest,
            "source_pruning_artifact_presence": pruned_artifacts,
            "session_trace": pruned_trace,
        },
        "prompt_diff": prompt_diff_summary(control_prompt, pruned_prompt),
        "deltas": {
            "input_tokens_control_minus_pruned": input_delta,
            "output_tokens_control_minus_pruned": numeric_delta(
                control_tokens.get("output_tokens"), pruned_tokens.get("output_tokens")
            ),
            "cache_read_tokens_control_minus_pruned": numeric_delta(
                control_tokens.get("cache_read_tokens"), pruned_tokens.get("cache_read_tokens")
            ),
            "cache_write_tokens_control_minus_pruned": numeric_delta(
                control_tokens.get("cache_write_tokens"), pruned_tokens.get("cache_write_tokens")
            ),
            "reasoning_tokens_control_minus_pruned": numeric_delta(
                control_tokens.get("reasoning_tokens"), pruned_tokens.get("reasoning_tokens")
            ),
            "request_count_control_minus_pruned": request_delta,
            "api_equivalent_usd_control_minus_pruned": cost_delta,
            "trace_control_minus_pruned": trace_deltas(control_trace, pruned_trace),
        },
        "new_warning_taxonomy_classes": new_warning_classes,
    }


def summarize_modes(pairs: list[dict[str, Any]]) -> dict[str, Any]:
    summaries: dict[str, Any] = {}
    for pair in pairs:
        mode = str(pair.get("mode") or "unknown")
        summary = summaries.setdefault(
            mode,
            {
                "pair_count": 0,
                "qualified_pair_count": 0,
                "amplification_pair_count": 0,
                "stale_control_pair_count": 0,
                "missing_variance_pair_count": 0,
                "qualified_pair_names": [],
                "blocked_pair_names": [],
            },
        )
        summary["pair_count"] += 1
        if pair.get("admitted_for_mode_specific_follow_on") is True:
            summary["qualified_pair_count"] += 1
            summary["qualified_pair_names"].append(pair["pair_name"])
        else:
            summary["blocked_pair_names"].append(pair["pair_name"])
        blockers = pair.get("blockers") or []
        if any("amplification" in blocker for blocker in blockers):
            summary["amplification_pair_count"] += 1
        if "control_stale_source_pruning_artifacts_present" in blockers:
            summary["stale_control_pair_count"] += 1
        if "missing_retained_session_trace_variance_evidence" in blockers:
            summary["missing_variance_pair_count"] += 1
    return summaries


def overall_result(mode_summaries: dict[str, Any]) -> tuple[str, str]:
    production = mode_summaries.get("production") or {}
    benchmark = mode_summaries.get("benchmark") or {}
    production_qualified = int(production.get("qualified_pair_count", 0) or 0) > 0
    benchmark_qualified = int(benchmark.get("qualified_pair_count", 0) or 0) > 0
    if benchmark_qualified and not production_qualified:
        if int(production.get("amplification_pair_count", 0) or 0) > 0:
            blocker = "production_amplification"
            next_move = (
                "Do not run a broad production pruning matrix yet; promote a benchmark-only "
                "confirmation or first repair the production amplification root cause with "
                "trace-instrumented retained replay."
            )
        elif int(production.get("stale_control_pair_count", 0) or 0) > 0:
            blocker = "production_stale_control_artifact_blocker"
            next_move = (
                "Do not run production pruning rows until clean production controls prove "
                "source-pruning optional artifacts are absent from retained snapshots and "
                "scorecards."
            )
        elif int(production.get("missing_variance_pair_count", 0) or 0) > 0:
            blocker = "production_missing_variance_evidence"
            next_move = (
                "Do not run production pruning rows until retained or fresh production pairs "
                "bind request/search/materialization traces for both control and pruned rows."
            )
        else:
            blocker = "production_not_qualified"
            next_move = (
                "Promote a benchmark-only confirmation and keep production blocked until the "
                "non-qualified production pair checks are repaired."
            )
        return (
            f"partial_benchmark_signal_with_{blocker}",
            next_move,
        )
    if production_qualified and benchmark_qualified:
        return (
            "qualified_cross_mode_source_pruning_signal",
            "Run the next fresh matched source-pruning matrix with the same policy, retaining request/search/materialization trace receipts for every row.",
        )
    if production_qualified or benchmark_qualified:
        return (
            "partial_mode_specific_source_pruning_signal",
            "Promote only the qualified mode and keep the other mode blocked until amplification or missing-variance evidence is resolved.",
        )
    return (
        "fail_closed_no_qualified_source_pruning_signal",
        "Do not spend on deeper live source-pruning rows until a retained or synthetic trace identifies a policy/root-cause change that avoids stale artifacts and request/input amplification.",
    )


def build_receipt(
    pairs: list[tuple[str, Path, Path]],
    *,
    fresh_live_spend_used: bool = False,
) -> dict[str, Any]:
    pair_rows = [build_pair(name, control, pruned) for name, control, pruned in pairs]
    mode_summaries = summarize_modes(pair_rows)
    result, next_move = overall_result(mode_summaries)
    receipt_type = (
        "source_pruning_amplification_live_probe"
        if fresh_live_spend_used
        else "source_pruning_amplification_retained_replay"
    )
    spend_claim = (
        "Fresh live spend was used by this receipt only for the named proof pairs."
        if fresh_live_spend_used
        else "No fresh live spend was used by this retained replay receipt."
    )
    return {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "receipt_type": receipt_type,
        "result": result,
        "fresh_live_spend_used": fresh_live_spend_used,
        "pass": any(pair.get("admitted_for_mode_specific_follow_on") is True for pair in pair_rows),
        "mode_summaries": mode_summaries,
        "pairs": pair_rows,
        "recommended_next_owner_move": next_move,
        "non_claims": [
            "No production adoption",
            "No durable token or dollar savings claim",
            "No GitHub Copilot billing proof",
            spend_claim,
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--pair",
        action="append",
        required=True,
        help="Pair spec in the form name:control_run_dir:pruned_run_dir",
    )
    parser.add_argument(
        "--fresh-live-spend-used",
        action="store_true",
        help="Mark the receipt as a live-probe receipt instead of retained replay.",
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

#!/usr/bin/env python3
"""Shared helpers for product-run artifacts and receipts."""

from __future__ import annotations

from pathlib import Path


def month_name(month: str) -> str:
    return {
        "01": "january",
        "02": "february",
        "03": "march",
        "04": "april",
        "05": "may",
        "06": "june",
        "07": "july",
        "08": "august",
        "09": "september",
        "10": "october",
        "11": "november",
        "12": "december",
    }[month]


def logical_artifact_map(start: str, end: str) -> dict[str, str]:
    year, month = end.split("-")[0], end.split("-")[1]
    cycle_ym = "-".join(end.split("-")[:2])
    return {
        "marker": f"workspace/newsletter_run_marker_{start}_to_{end}.json",
        "scope_contract": f"workspace/newsletter_scope_contract_{end}.json",
        "manifest": f"workspace/newsletter_phase1a_url_manifest_{start}_to_{end}.md",
        "phase1b_github": f"workspace/newsletter_phase1b_interim_github_{start}_to_{end}.md",
        "phase1b_vscode": f"workspace/newsletter_phase1b_interim_vscode_{start}_to_{end}.md",
        "phase1b_vscode_theme_summary": f"workspace/newsletter_phase1b_vscode_theme_summary_{start}_to_{end}.md",
        "phase1b_visualstudio": f"workspace/newsletter_phase1b_interim_visualstudio_{start}_to_{end}.md",
        "phase1b_jetbrains": f"workspace/newsletter_phase1b_interim_jetbrains_{start}_to_{end}.md",
        "phase1b_xcode": f"workspace/newsletter_phase1b_interim_xcode_{start}_to_{end}.md",
        "discoveries": f"workspace/newsletter_phase1a_discoveries_{start}_to_{end}.md",
        "curator_processed": f"workspace/curator_notes_processed_{cycle_ym}.md",
        "curator_signals": f"workspace/curator_notes_editorial_signals_{cycle_ym}.md",
        "event_sources": f"workspace/newsletter_phase2_event_sources_{end}.json",
        "phase2_selected_source_ids": f"workspace/newsletter_phase2_selected_source_ids_{end}.json",
        "phase2_fetch_attempt_ledger": f"workspace/newsletter_phase2_fetch_attempt_ledger_{end}.json",
        "phase2_no_refetch_compliance": f"workspace/newsletter_phase2_no_refetch_compliance_{end}.json",
        "events": f"workspace/newsletter_phase2_events_{end}.md",
        "phase3_working_set": f"workspace/newsletter_phase3_working_set_{end}.md",
        "phase3_capability_map": f"workspace/newsletter_phase3_capability_map_{start}_to_{end}.json",
        "phase3_curated": f"workspace/newsletter_phase3_curated_sections_{end}.md",
        "copilot_cli_release_inventory": f"workspace/copilot_cli_release_inventory_{start}_to_{end}.md",
        "copilot_app_release_inventory": f"workspace/copilot_app_release_inventory_{start}_to_{end}.md",
        "phase45_polishing": f"workspace/newsletter_phase4_5_polishing_{end}.md",
        "phase46_video_report": f"workspace/newsletter_phase4_6_video_matches_{end}.md",
        "source_pruning_context": f"workspace/newsletter_source_pruning_context_{end}.md",
        "source_pruning_receipt": f"workspace/newsletter_source_pruning_receipt_{end}.json",
        "output_shape_context": f"workspace/newsletter_output_shape_context_{end}.md",
        "output_shape_receipt": f"workspace/newsletter_output_shape_receipt_{end}.json",
        "scope_results": f"workspace/newsletter_scope_results_{end}.md",
        "editorial_review": f"workspace/{cycle_ym}_editorial_review.md",
        "editorial_corrections": f"workspace/{cycle_ym}_editorial_corrections.md",
        "pipeline_contract": f"workspace/newsletter_pipeline_contract_{end}.md",
        "receipts": f"workspace/newsletter_phase_receipts_{end}.json",
        "output": f"output/{year}-{month}_{month_name(month)}_newsletter.md",
    }


def receipt_phase_logical_paths(start: str, end: str) -> dict[str, str]:
    artifacts = logical_artifact_map(start, end)
    return {
        "phase0_scope_contract": artifacts["scope_contract"],
        "phase1a_manifest": artifacts["manifest"],
        "phase1b_github": artifacts["phase1b_github"],
        "phase1b_vscode": artifacts["phase1b_vscode"],
        "phase1b_visualstudio": artifacts["phase1b_visualstudio"],
        "phase1b_jetbrains": artifacts["phase1b_jetbrains"],
        "phase1b_xcode": artifacts["phase1b_xcode"],
        "phase1c_discoveries": artifacts["discoveries"],
        "phase1_5_curator_processed": artifacts["curator_processed"],
        "phase1_5_curator_signals": artifacts["curator_signals"],
        "phase2_event_sources": artifacts["event_sources"],
        "phase2_events": artifacts["events"],
        "phase3_working_set": artifacts["phase3_working_set"],
        "phase3_curated": artifacts["phase3_curated"],
        "phase4_output": artifacts["output"],
        "phase4_5_polishing": artifacts["phase45_polishing"],
        "phase4_6_video": artifacts["phase46_video_report"],
        "phase4_scope_results": artifacts["scope_results"],
        "phase4_editorial_review": artifacts["editorial_review"],
    }


def resolved_artifact_map(root: Path, start: str, end: str) -> dict[str, dict[str, Path | str]]:
    root = root.resolve()
    resolved: dict[str, dict[str, Path | str]] = {}
    for name, logical_path in logical_artifact_map(start, end).items():
        resolved[name] = {
            "logical_path": logical_path,
            "resolved_path": root / logical_path,
        }
    return resolved

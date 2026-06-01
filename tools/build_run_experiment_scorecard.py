#!/usr/bin/env python3
"""Build one per-run experiment scorecard from a retained product run."""

from __future__ import annotations

import argparse
from pathlib import Path

from newsletter_experiment_common import scorecard_from_run, write_json, write_text


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", required=True, help="Retained product run directory")
    parser.add_argument("--output", help="Output JSON path (default: <run-dir>/run-scorecard.json)")
    parser.add_argument("--markdown-output", help="Optional markdown summary path")
    parser.add_argument("--pricing-snapshot", help="Explicit pricing snapshot JSON path")
    return parser.parse_args()


def render_markdown(scorecard: dict) -> str:
    quality = scorecard["quality"]
    tokens = scorecard["token_usage"]
    experiment = scorecard["experiment"]
    prompt_equality = experiment.get("prompt_equality") or {}
    timing = scorecard["timing"]
    completeness = scorecard["artifact_completeness"]
    cost = scorecard["cost_estimate"]
    warning_classes = ", ".join(quality.get("warning_taxonomy_classes") or [])
    if not warning_classes:
        warning_classes = "<none>"
    direct_fields = ", ".join(tokens.get("direct_provider_token_fields_present") or [])
    if not direct_fields:
        direct_fields = "<none>"
    missing_fields = ", ".join(tokens.get("missing_direct_provider_token_fields") or [])
    if not missing_fields:
        missing_fields = "<none>"
    return "\n".join(
        [
            "# Run Experiment Scorecard",
            "",
            f"- Run: `{scorecard['run_id']}`",
            f"- Date range: `{scorecard['start']}` to `{scorecard['end']}`",
            f"- Mode: `{scorecard['mode']}`",
            f"- Primary model: `{scorecard['primary_model']}`",
            f"- Run class: `{experiment['run_class']}`",
            f"- Experiment id: `{experiment['experiment_id']}`",
            f"- Fixture pack: `{experiment['fixture_pack']}`",
            f"- Prompt checksum: `{experiment['prompt_sha256']}` ({experiment['prompt_source']})",
            f"- Prompt equals current renderer: `{prompt_equality.get('matches_current_renderer')}`",
            f"- Current renderer checksum: `{prompt_equality.get('current_renderer_sha256')}`",
            "",
            "## Tokens",
            f"- Input: `{tokens['input_tokens']}`",
            f"- Output: `{tokens['output_tokens']}`",
            f"- Cached total: `{tokens['cached_tokens_total']}`",
            f"- Reasoning: `{tokens['reasoning_tokens']}`",
            f"- Requests: `{tokens['request_count']}`",
            f"- Direct provider fields present: `{direct_fields}`",
            f"- Missing direct provider fields: `{missing_fields}`",
            "",
            "## Cost And Timing",
            f"- Estimated cost (USD): `{cost['total_usd']}`",
            f"- Pricing snapshot: `{cost['pricing_snapshot_path']}`",
            f"- Wall clock seconds: `{timing['wall_clock_seconds']}`",
            f"- Time to first artifact: `{timing['time_to_first_artifact_seconds']}`",
            f"- Time to first receipt: `{timing['time_to_first_receipt_seconds']}`",
            f"- Receipt span: `{timing['receipt_span_seconds']}`",
            "",
            "## Quality",
            f"- Strict: exit `{quality['strict_exit_code']}` warnings `{quality['strict_warning_count']}`",
            f"- Newsletter: exit `{quality['newsletter_exit_code']}` warnings `{quality['newsletter_warning_count']}`",
            f"- Warning taxonomy present: `{quality.get('warning_taxonomy_present')}`",
            f"- Warning taxonomy classes: `{warning_classes}`",
            f"- Rubric: `{quality['rubric_score']}/50` (pass=`{quality['rubric_pass']}`)",
            "",
            "## Artifact Completeness",
            f"- Required present: `{completeness['required_present']}/{completeness['required_total']}`",
            f"- Optional present: `{completeness['optional_present']}/{completeness['optional_total']}`",
        ]
    )


def main() -> int:
    args = parse_args()
    run_dir = Path(args.run_dir).expanduser().resolve()
    output_path = Path(args.output).expanduser().resolve() if args.output else run_dir / "run-scorecard.json"
    markdown_path = (
        Path(args.markdown_output).expanduser().resolve()
        if args.markdown_output
        else run_dir / "audit" / "RUN_SCORECARD.md"
    )
    scorecard = scorecard_from_run(run_dir, pricing_snapshot_path=args.pricing_snapshot)
    write_json(output_path, scorecard)
    write_text(markdown_path, render_markdown(scorecard))
    print(output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

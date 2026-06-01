#!/usr/bin/env python3
"""Emit an evidence-only output-shape context and admission receipt."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from product_run_common import logical_artifact_map


def sha256_path(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.rstrip() + "\n", encoding="utf-8")


def word_count(path: Path) -> int | None:
    if not path.exists():
        return None
    return len(path.read_text(encoding="utf-8", errors="ignore").split())


def count_headings(path: Path) -> dict[str, int] | None:
    if not path.exists():
        return None
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    return {
        "h1": sum(1 for line in lines if line.startswith("# ")),
        "h2": sum(1 for line in lines if line.startswith("## ")),
        "any_heading": sum(1 for line in lines if line.startswith("#")),
    }


def resolve_retained_output(source_root: Path, logical_output: str, start: str, end: str) -> tuple[Path, str]:
    live_output = source_root / logical_output
    if live_output.exists():
        return live_output, "live_output"
    preflight_name = f"{live_output.stem}_preflight_prev.md"
    archive_root = source_root / "workspace" / "archived" / "preflight"
    candidates = sorted(archive_root.glob(f"{start}_to_{end}_*/{preflight_name}"))
    if candidates:
        return candidates[-1], "preflight_archive"
    return live_output, "missing"


def infer_mode(start: str, end: str) -> str:
    if start == "2025-12-05" and end == "2026-02-13":
        return "benchmark"
    if start == "2026-02-14" and end == "2026-04-16":
        return "production"
    raise SystemExit(f"Unsupported Burst-22 output-shape date range: {start} to {end}")


def resolve_policy(root: Path, raw: str) -> Path:
    path = Path(raw).expanduser()
    if not path.is_absolute():
        path = root / path
    path = path.resolve()
    if not path.exists():
        raise SystemExit(f"Output-shape policy not found: {path}")
    try:
        path.relative_to(root.resolve())
    except ValueError:
        raise SystemExit(f"Output-shape policy must be inside repo: {path}")
    return path


def build_context(policy: dict[str, Any], mode: str, target: dict[str, Any]) -> str:
    preserve = "\n".join(f"- {item}" for item in policy.get("preserve", []))
    shortcuts = "\n".join(f"- {item}" for item in policy.get("forbidden_shortcuts", []))
    return f"""# Newsletter Output-Shape Budget Context

Policy: `{policy.get("policy_id")}`
Mode: `{mode}`

This is an evidence-only output-shape budget experiment. It is not production
adoption and it does not establish durable token or dollar savings.

## Budget

- Target final output words: `{target["target_final_output_words"]}`
- Minimum final output words: `{target["minimum_final_output_words"]}`
- Maximum H1 count: `{target.get("max_h1_count")}`
- Maximum H2 count: `{target.get("max_h2_count")}`

## Preserve

{preserve}

## Forbidden Shortcuts

{shortcuts}
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("start")
    parser.add_argument("end")
    parser.add_argument("--policy", required=True)
    parser.add_argument("--source-root", default=".")
    parser.add_argument("--output-root", default=".")
    parser.add_argument("--require-admission", action="store_true")
    parser.add_argument("--require-materiality", action="store_true")
    args = parser.parse_args()

    source_root = Path(args.source_root).expanduser().resolve()
    output_root = Path(args.output_root).expanduser().resolve()
    policy_path = resolve_policy(source_root, args.policy)
    policy = load_json(policy_path)
    mode = infer_mode(args.start, args.end)
    mode_targets = policy.get("mode_targets") if isinstance(policy.get("mode_targets"), dict) else {}
    target = mode_targets.get(mode)
    if not isinstance(target, dict):
        raise SystemExit(f"Policy {policy_path} has no target for mode {mode}")

    date_range = target.get("date_range") if isinstance(target.get("date_range"), dict) else {}
    date_range_matches = date_range.get("start") == args.start and date_range.get("end") == args.end
    target_words = target.get("target_final_output_words")
    minimum_words = target.get("minimum_final_output_words")
    valid_budget = (
        isinstance(target_words, int)
        and isinstance(minimum_words, int)
        and 0 < minimum_words <= target_words
    )

    artifacts = logical_artifact_map(args.start, args.end)
    retained_output, retained_output_source = resolve_retained_output(
        source_root, artifacts["output"], args.start, args.end
    )
    retained_output_exists = retained_output.exists()
    observed_words = word_count(retained_output)
    observed_headings = count_headings(retained_output) or {"h1": None, "h2": None, "any_heading": None}
    reduction_words = observed_words - target_words if observed_words is not None else None
    reduction_pct = (
        round(reduction_words / observed_words, 6)
        if observed_words and reduction_words is not None
        else None
    )
    threshold = policy.get("materiality_threshold") if isinstance(policy.get("materiality_threshold"), dict) else {}
    min_reduction_words = int(threshold.get("min_reduction_words") or 0)
    min_reduction_pct = float(threshold.get("min_reduction_pct") or 0)
    max_h1 = target.get("max_h1_count")
    max_h2 = target.get("max_h2_count")
    valid_heading_budget = isinstance(max_h1, int) and isinstance(max_h2, int) and max_h1 > 0 and max_h2 > 0
    heading_budget_pass = (
        retained_output_exists
        and valid_heading_budget
        and isinstance(observed_headings.get("h1"), int)
        and isinstance(observed_headings.get("h2"), int)
        and observed_headings.get("h1", 0) <= max_h1
        and observed_headings.get("h2", 0) <= max_h2
    )
    materiality_pass = (
        reduction_words is not None
        and reduction_words >= min_reduction_words
        and reduction_pct is not None
        and reduction_pct >= min_reduction_pct
    )

    checks = {
        "policy_evidence_only": policy.get("evidence_only") is True,
        "policy_non_production": policy.get("production_adoption") is False,
        "policy_non_savings_claim": policy.get("durable_savings_claim") is False,
        "date_range_matches_mode": date_range_matches,
        "valid_budget": valid_budget,
        "retained_output_present": retained_output_exists,
        "valid_heading_budget": valid_heading_budget,
        "retained_heading_budget_pass": heading_budget_pass,
        "materiality_pass": materiality_pass,
    }
    admission_pass = all(
        checks[key]
        for key in (
            "policy_evidence_only",
            "policy_non_production",
            "policy_non_savings_claim",
            "date_range_matches_mode",
            "valid_budget",
            "retained_output_present",
            "valid_heading_budget",
            "retained_heading_budget_pass",
        )
    )
    if args.require_materiality:
        admission_pass = admission_pass and materiality_pass

    context_path = output_root / artifacts["output_shape_context"]
    receipt_path = output_root / artifacts["output_shape_receipt"]
    write_text(context_path, build_context(policy, mode, target))
    receipt = {
        "schema_version": 1,
        "receipt_type": "newsletter_output_shape_policy_admission",
        "start": args.start,
        "end": args.end,
        "mode": mode,
        "policy_path": str(policy_path),
        "policy_sha256": sha256_path(policy_path),
        "policy_id": policy.get("policy_id"),
        "context_path": str(context_path),
        "context_sha256": sha256_path(context_path),
        "retained_output_path": str(retained_output),
        "retained_output_source": retained_output_source,
        "retained_output_exists": retained_output_exists,
        "retained_output_words": observed_words,
        "retained_output_headings": observed_headings,
        "target_final_output_words": target_words,
        "minimum_final_output_words": minimum_words,
        "max_h1_count": max_h1,
        "max_h2_count": max_h2,
        "potential_reduction_words": reduction_words,
        "potential_reduction_pct": reduction_pct,
        "materiality_threshold": {
            "min_reduction_words": min_reduction_words,
            "min_reduction_pct": min_reduction_pct,
        },
        "checks": checks,
        "pass": admission_pass,
        "non_claims": {
            "production_adoption": False,
            "durable_token_savings": False,
            "durable_dollar_savings": False,
            "github_copilot_billing_proof": False,
        },
    }
    write_json(receipt_path, receipt)
    print(receipt_path)
    if args.require_admission and not admission_pass:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

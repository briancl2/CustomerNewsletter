#!/usr/bin/env python3
"""Build an additive source-pruning context artifact for newsletter proof runs."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
from pathlib import Path
from typing import Any

from product_run_common import logical_artifact_map


WORD_RE = re.compile(r"\b[\w'-]+\b")
LINK_RE = re.compile(r"\[[^\]]+\]\([^)]+\)")


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.rstrip() + "\n", encoding="utf-8")


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def sha256_path(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def word_count(text: str) -> int:
    return len(WORD_RE.findall(text))


def load_policy(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if payload.get("schema_version") != 1:
        raise SystemExit("Pruning policy schema_version must be 1")
    if not payload.get("policy_id"):
        raise SystemExit("Pruning policy must include policy_id")
    for key in ("selected_context_artifacts", "required_source_classes"):
        if not isinstance(payload.get(key), list) or not payload[key]:
            raise SystemExit(f"Pruning policy must include non-empty {key}")
    return payload


def section_from_markdown(text: str, heading: str) -> str:
    wanted = "## " + heading
    lines = text.splitlines()
    captured: list[str] = []
    in_section = False
    for line in lines:
        if line.strip() == wanted:
            in_section = True
            captured.append(line)
            continue
        if in_section and line.startswith("## "):
            break
        if in_section:
            captured.append(line)
    return "\n".join(captured).strip()


def header_block(text: str) -> str:
    lines: list[str] = []
    for line in text.splitlines():
        if line.startswith("## "):
            break
        lines.append(line)
    return "\n".join(lines).strip()


def source_highlights(text: str, limit: int) -> list[str]:
    retained: list[str] = []
    for raw in text.splitlines():
        line = raw.rstrip()
        stripped = line.strip()
        if not stripped:
            continue
        keep = (
            stripped.startswith("#")
            or stripped.startswith("- **Date**:")
            or stripped.startswith("- **Sources**:")
            or stripped.startswith("- **Links**:")
            or stripped.startswith("- **Relevance Score**:")
            or stripped.startswith("- **Enterprise Impact**:")
            or stripped.startswith("- **IDE Support**:")
            or stripped.startswith("**VS Code")
            or stripped.startswith("| Source |")
            or stripped.startswith("|--------|")
            or LINK_RE.search(stripped) is not None
        )
        if keep:
            retained.append(line)
        if len(retained) >= limit:
            break
    return retained


def event_source_summary(path: Path, limit: int) -> list[str]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return source_highlights(read_text(path), limit)
    lines = [f"- JSON source type: `{type(payload).__name__}`"]
    if isinstance(payload, dict):
        lines.append(f"- Top-level keys: `{', '.join(sorted(map(str, payload.keys()))[:12])}`")
        for key, value in payload.items():
            if isinstance(value, list):
                lines.append(f"- `{key}` rows: `{len(value)}`")
            elif isinstance(value, dict):
                lines.append(f"- `{key}` keys: `{len(value)}`")
            if len(lines) >= limit:
                break
    elif isinstance(payload, list):
        lines.append(f"- Rows: `{len(payload)}`")
    return lines[:limit]


def artifact_rows(
    source_root: Path,
    artifact_map: dict[str, str],
    artifact_names: list[str],
) -> list[dict[str, Any]]:
    rows = []
    for name in artifact_names:
        logical = artifact_map.get(name)
        if not logical:
            rows.append({"artifact_name": name, "exists": False, "reason": "unknown_artifact_name"})
            continue
        path = source_root / logical
        text = read_text(path) if path.exists() else ""
        rows.append(
            {
                "artifact_name": name,
                "logical_path": logical,
                "path": str(path),
                "exists": path.exists(),
                "sha256": sha256_path(path) if path.exists() else None,
                "size_bytes": path.stat().st_size if path.exists() else None,
                "word_count": word_count(text) if path.exists() else 0,
            }
        )
    return rows


def build_context(
    *,
    start: str,
    end: str,
    policy: dict[str, Any],
    policy_path: Path,
    policy_sha: str,
    source_root: Path,
    artifacts: dict[str, str],
    rows: list[dict[str, Any]],
) -> str:
    by_name = {row["artifact_name"]: row for row in rows}
    working_set = source_root / artifacts["phase3_working_set"]
    curated = source_root / artifacts["phase3_curated"]
    closed_bundle_required = policy.get("closed_bundle_required") is True
    lines = [
        "# Closed Source Bundle" if closed_bundle_required else "# Source Pruning Context",
        f"**Policy**: `{policy['policy_id']}`",
        f"**Policy SHA256**: `{policy_sha}`",
        f"**Date Range**: {start} to {end}",
        "",
        "## Source Inventory",
    ]
    for row in rows:
        lines.append(
            "- `{artifact_name}`: `{logical_path}` words=`{word_count}` sha256=`{sha256}`".format(
                artifact_name=row.get("artifact_name"),
                logical_path=row.get("logical_path"),
                word_count=row.get("word_count"),
                sha256=row.get("sha256"),
            )
        )

    lines.extend(
        [
            "",
            "## Parser And Validator Context",
            header_block(read_text(working_set)) if working_set.exists() else "- Missing Phase 3 working set.",
        ]
    )
    working_set_text = read_text(working_set) if working_set.exists() else ""
    for heading in policy.get("working_set_sections", []):
        section = section_from_markdown(working_set_text, str(heading))
        if section:
            lines.extend(["", section])

    lines.extend(["", "## Curated Candidate Sections"])
    if policy.get("include_full_curated_sections", True) and curated.exists():
        lines.append(read_text(curated))
    else:
        lines.append("- Curated sections omitted by policy.")

    lines.extend(["", "## Source Candidate Highlights"])
    limit = int(policy.get("source_highlight_line_limit", 18) or 18)
    for row in rows:
        name = str(row.get("artifact_name"))
        if name in {"phase3_working_set", "phase3_curated"}:
            continue
        path = source_root / str(row.get("logical_path"))
        lines.extend(["", f"### {name}"])
        if not path.exists():
            lines.append("- Missing.")
        elif name == "event_sources":
            lines.extend(event_source_summary(path, limit))
        else:
            highlights = source_highlights(read_text(path), limit)
            lines.extend(highlights or ["- No deterministic highlights extracted."])

    lines.extend(
        [
            "",
            "## Usage Boundary",
            (
                "- Use this additive artifact as the closed source bundle for the pruning experiment row."
                if closed_bundle_required
                else "- Use this additive artifact as the compact source/candidate context for the pruning experiment row."
            ),
            "- Do not delete, overwrite, or mutate the canonical source artifacts named above.",
        ]
    )
    if closed_bundle_required:
        lines.extend(
            [
                "- After this receipt passes, do not perform broad repo/source search expansion or source rediscovery.",
                "- Do not run rg, grep, find, or broad file listing over canonical source artifacts for final drafting.",
                "- If a required detail is missing here, stop and report closed_bundle_missing_detail instead of searching.",
            ]
        )
    else:
        lines.append(
            "- If a required detail is missing here, reopen the original source artifact named in Source Inventory and record the reason in the run notes."
        )
    extra_rules = policy.get("usage_boundary_extra_rules")
    if isinstance(extra_rules, list) and extra_rules:
        lines.extend(["", "## Policy-Specific Rules"])
        lines.extend(f"- {rule}" for rule in extra_rules if isinstance(rule, str) and rule.strip())
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("start")
    parser.add_argument("end")
    parser.add_argument("--policy", required=True)
    parser.add_argument("--source-root", default=".")
    parser.add_argument("--output-root", default=".")
    parser.add_argument("--require-admission", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source_root = Path(args.source_root).expanduser().resolve()
    output_root = Path(args.output_root).expanduser().resolve()
    policy_path = Path(args.policy).expanduser().resolve()
    policy = load_policy(policy_path)
    policy_sha = sha256_path(policy_path)
    artifacts = logical_artifact_map(args.start, args.end)

    required_rows = artifact_rows(source_root, artifacts, list(policy["required_source_classes"]))
    selected_rows = artifact_rows(source_root, artifacts, list(policy["selected_context_artifacts"]))
    missing_required = [
        row.get("artifact_name")
        for row in required_rows
        if not row.get("exists")
    ]
    if missing_required:
        payload = {
            "schema_version": 1,
            "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "policy_id": policy["policy_id"],
            "policy_path": str(policy_path),
            "policy_sha256": policy_sha,
            "closed_bundle_required": policy.get("closed_bundle_required") is True,
            "start": args.start,
            "end": args.end,
            "source_root": str(source_root),
            "output_root": str(output_root),
            "admission": {
                "pass": False,
                "reason": "missing_required_source_classes",
                "missing_required_source_classes": missing_required,
            },
            "source_artifacts": selected_rows,
        }
        receipt_path = output_root / artifacts["source_pruning_receipt"]
        write_json(receipt_path, payload)
        if args.require_admission:
            raise SystemExit(f"Missing required source classes: {', '.join(map(str, missing_required))}")
        print(receipt_path)
        return 0

    context = build_context(
        start=args.start,
        end=args.end,
        policy=policy,
        policy_path=policy_path,
        policy_sha=policy_sha,
        source_root=source_root,
        artifacts=artifacts,
        rows=selected_rows,
    )
    context_path = output_root / artifacts["source_pruning_context"]
    receipt_path = output_root / artifacts["source_pruning_receipt"]
    write_text(context_path, context)

    baseline_words = sum(int(row.get("word_count") or 0) for row in selected_rows)
    baseline_bytes = sum(int(row.get("size_bytes") or 0) for row in selected_rows)
    pruned_words = word_count(context)
    pruned_bytes = len(context.encode("utf-8"))
    reduction_words = baseline_words - pruned_words
    reduction_bytes = baseline_bytes - pruned_bytes
    reduction_fraction = (reduction_words / baseline_words) if baseline_words else None
    min_words = int(policy.get("min_reduction_words", 0) or 0)
    min_fraction = float(policy.get("min_reduction_fraction", 0) or 0)
    admission_pass = (
        reduction_words >= min_words
        and reduction_fraction is not None
        and reduction_fraction >= min_fraction
        and not missing_required
    )
    receipt = {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "policy_id": policy["policy_id"],
        "policy_path": str(policy_path),
        "policy_sha256": policy_sha,
        "closed_bundle_required": policy.get("closed_bundle_required") is True,
        "start": args.start,
        "end": args.end,
        "source_root": str(source_root),
        "output_root": str(output_root),
        "context_logical_path": artifacts["source_pruning_context"],
        "context_path": str(context_path),
        "context_sha256": sha256_path(context_path),
        "receipt_logical_path": artifacts["source_pruning_receipt"],
        "selected_context_baseline_words": baseline_words,
        "selected_context_pruned_words": pruned_words,
        "selected_context_reduction_words": reduction_words,
        "selected_context_reduction_fraction": round(reduction_fraction, 6) if reduction_fraction is not None else None,
        "selected_context_baseline_bytes": baseline_bytes,
        "selected_context_pruned_bytes": pruned_bytes,
        "selected_context_reduction_bytes": reduction_bytes,
        "required_source_classes": list(policy["required_source_classes"]),
        "required_source_classes_preserved": not missing_required,
        "missing_required_source_classes": missing_required,
        "source_artifacts": selected_rows,
        "admission": {
            "pass": admission_pass,
            "min_reduction_words": min_words,
            "min_reduction_fraction": min_fraction,
            "reason": "passed" if admission_pass else "reduction_threshold_not_met",
        },
        "non_claims": [
            "No production adoption",
            "No durable token or dollar savings claim",
            "No GitHub Copilot billing proof",
        ],
    }
    write_json(receipt_path, receipt)
    if args.require_admission and not admission_pass:
        raise SystemExit("Source pruning admission failed")
    print(receipt_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

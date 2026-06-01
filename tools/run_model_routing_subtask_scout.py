#!/usr/bin/env python3
"""Evidence-only Phase 3 subtask-boundary model-routing scout."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any

from newsletter_phase_experimenter import (
    append_log,
    env_flag_enabled,
    json_dumps,
    load_manifest,
    materialize_surface,
    path_for_copilot_phase,
    resolve_copilot_bin,
    resolve_manifest_repo_root,
    run_logged,
    run_phase3_signature_scan,
    sha256_file,
)


ROOT = Path(__file__).resolve().parent.parent
PLACEHOLDER = "BURST35_SUBTASK_PLACEHOLDER"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    for subparser in (
        subparsers.add_parser("admit", help="Build static admission receipt"),
        subparsers.add_parser("run", help="Run one bounded section subtask row"),
    ):
        subparser.add_argument("--manifest", required=True)
        subparser.add_argument("--surface-id", default="phase4_fast_surface")
        subparser.add_argument("--target-repo", default=str(ROOT))
        subparser.add_argument("--section-heading", required=True)
        subparser.add_argument("--benchmark-mode", default="")
        subparser.add_argument("--min-section-bullets", type=int, default=2)
        subparser.add_argument("--min-section-links", type=int, default=2)
        subparser.add_argument("--max-source-section-words", type=int, default=300)

    admit = subparsers.choices["admit"]
    admit.add_argument("--output", required=True)

    run = subparsers.choices["run"]
    run.add_argument("--model", required=True)
    run.add_argument("--run-dir-override", required=True)
    run.add_argument("--admission-receipt", required=True)
    run.add_argument("--phase-timeout-seconds", type=int, default=600)
    run.add_argument("--copilot-agent-mode", choices=["agent-flag", "prompt-mention-only"], default="prompt-mention-only")

    return parser.parse_args()


def utc_now() -> str:
    return dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def rel_or_abs(path: Path, root: Path = ROOT) -> str:
    resolved = path.resolve()
    try:
        return str(resolved.relative_to(root.resolve()))
    except ValueError:
        return str(resolved)


def manifest_artifact_path(manifest: dict[str, Any], surface_id: str, artifact_name: str) -> Path:
    surface = (manifest.get("surfaces") or {}).get(surface_id)
    if not isinstance(surface, list):
        raise SystemExit(f"surface not found in manifest: {surface_id}")
    repo_root = resolve_manifest_repo_root(manifest)
    for artifact in surface:
        if artifact.get("artifact_name") != artifact_name:
            continue
        source_path = Path(str(artifact.get("source_path") or ""))
        if not source_path.is_absolute():
            source_path = repo_root / source_path
        if not source_path.exists():
            raise SystemExit(f"manifest artifact missing on disk: {source_path}")
        return source_path.resolve()
    raise SystemExit(f"artifact {artifact_name!r} not found in surface {surface_id!r}")


def heading_pattern(heading: str) -> re.Pattern[str]:
    escaped = re.escape(heading.strip())
    return re.compile(rf"(?m)^{escaped}\s*$")


def section_bounds(text: str, heading: str) -> tuple[int, int, int]:
    match = heading_pattern(heading).search(text)
    if not match:
        raise ValueError(f"section heading not found: {heading}")
    next_heading = re.search(r"(?m)^#{1,2}\s+", text[match.end() :])
    end = match.end() + next_heading.start() if next_heading else len(text)
    return match.start(), match.end(), end


def section_text(text: str, heading: str) -> str:
    start, _heading_end, end = section_bounds(text, heading)
    return text[start:end]


def section_metrics(text: str, heading: str) -> dict[str, Any]:
    try:
        section = section_text(text, heading)
    except ValueError as exc:
        return {
            "heading": heading,
            "present": False,
            "error": str(exc),
            "word_count": None,
            "bullet_count": None,
            "link_count": None,
        }
    return {
        "heading": heading,
        "present": True,
        "sha256": hashlib_text(section),
        "word_count": len(section.split()),
        "bullet_count": sum(1 for line in section.splitlines() if line.startswith("- ")),
        "link_count": len(re.findall(r"\[[^\]]+\]\([^)]+\)", section)),
        "placeholder_present": PLACEHOLDER in section,
        "todo_present": "TODO" in section,
        "html_comment_present": "<!--" in section,
    }


def hashlib_text(text: str) -> str:
    import hashlib

    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def validate_curated(
    *,
    target_repo: Path,
    start: str,
    end: str,
    curated: Path,
    working_set: Path,
    benchmark_mode: str,
) -> tuple[int, str]:
    cmd = [
        "python3",
        "tools/validate_phase3_curated.py",
        start,
        end,
        str(curated.relative_to(target_repo) if curated.is_relative_to(target_repo) else curated),
        "--working-set",
        str(working_set.relative_to(target_repo) if working_set.is_relative_to(target_repo) else working_set),
    ]
    if benchmark_mode:
        cmd.extend(["--benchmark-mode", benchmark_mode])
    completed = subprocess.run(cmd, cwd=target_repo, text=True, capture_output=True, check=False)
    return completed.returncode, completed.stdout + completed.stderr


def validate_section_output(path: Path, heading: str, min_bullets: int, min_links: int) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    metrics = section_metrics(text, heading)
    checks = {
        "section_present": metrics.get("present") is True,
        "placeholder_removed": metrics.get("placeholder_present") is False,
        "todo_absent": metrics.get("todo_present") is False,
        "html_comment_absent": metrics.get("html_comment_present") is False,
        "min_section_bullets": (metrics.get("bullet_count") or 0) >= min_bullets,
        "min_section_links": (metrics.get("link_count") or 0) >= min_links,
    }
    return {
        "metrics": metrics,
        "checks": checks,
        "passed": all(checks.values()),
        "blockers": [key for key, value in checks.items() if not value],
    }


def build_static_admission(args: argparse.Namespace, manifest: dict[str, Any]) -> dict[str, Any]:
    target_repo = Path(args.target_repo).expanduser().resolve()
    start = str(manifest["start"])
    end = str(manifest["end"])
    curated = manifest_artifact_path(manifest, args.surface_id, "phase3_curated")
    working_set = manifest_artifact_path(manifest, args.surface_id, "phase3_working_set")
    curated_text = curated.read_text(encoding="utf-8", errors="ignore")
    metrics = section_metrics(curated_text, args.section_heading)
    validate_rc, validate_output = validate_curated(
        target_repo=target_repo,
        start=start,
        end=end,
        curated=curated,
        working_set=working_set,
        benchmark_mode=args.benchmark_mode,
    )
    checks = {
        "source_curated_exists": curated.is_file(),
        "source_working_set_exists": working_set.is_file(),
        "source_curated_validates": validate_rc == 0,
        "section_present": metrics.get("present") is True,
        "section_word_count_bounded": metrics.get("word_count") is not None
        and int(metrics["word_count"]) <= args.max_source_section_words,
        "section_min_bullets": (metrics.get("bullet_count") or 0) >= args.min_section_bullets,
        "section_min_links": (metrics.get("link_count") or 0) >= args.min_section_links,
    }
    admitted = all(checks.values())
    return {
        "schema_version": "1.0.0",
        "receipt_type": "model_routing_subtask_static_admission",
        "generated_at_utc": utc_now(),
        "admitted": admitted,
        "verdict": "subtask_route_admitted" if admitted else "subtask_route_failed_closed",
        "manifest_path": rel_or_abs(Path(str(manifest["_manifest_path"]))),
        "surface_id": args.surface_id,
        "mode": str(manifest.get("mode") or ""),
        "start": start,
        "end": end,
        "section_heading": args.section_heading,
        "thresholds": {
            "min_section_bullets": args.min_section_bullets,
            "min_section_links": args.min_section_links,
            "max_source_section_words": args.max_source_section_words,
        },
        "checks": checks,
        "blockers": [key for key, value in checks.items() if not value],
        "source_artifacts": {
            "phase3_curated": {
                "path": rel_or_abs(curated),
                "sha256": sha256_file(curated),
            },
            "phase3_working_set": {
                "path": rel_or_abs(working_set),
                "sha256": sha256_file(working_set),
            },
        },
        "section_metrics": metrics,
        "source_validation": {
            "return_code": validate_rc,
            "output": validate_output.strip(),
        },
        "route_boundary": {
            "type": "phase3_section_subtask",
            "expansion_controls": [
                "Prompt edits only the selected markdown section.",
                "Prompt uses retained Phase 3 working set and curated artifact only.",
                "Wrapper validates the full curated artifact and section-specific bullets/links.",
                "Pair receipt rejects request/tool amplification.",
            ],
        },
        "non_claims": [
            "Static admission is not a savings claim.",
            "This route is evidence-only and does not change production behavior.",
        ],
    }


def blank_section(text: str, heading: str) -> str:
    start, heading_end, end = section_bounds(text, heading)
    heading_text = text[start:heading_end].rstrip()
    replacement = (
        f"{heading_text}\n"
        f"<!-- {PLACEHOLDER}: replace this section only. -->\n"
        f"- {PLACEHOLDER}: use the Phase 3 working set to restore this section with concise, sourced bullets.\n"
    )
    return text[:start] + replacement + text[end:]


def write_summary(
    *,
    run_dir: Path,
    run_id: str,
    start: str,
    end: str,
    model: str,
    section_heading: str,
    codes: dict[str, int | None],
    section_validation: dict[str, Any] | None,
    log_file: Path,
) -> None:
    known = [value for value in codes.values() if value is not None]
    overall = next((value for value in known if value != 0), 0 if known and all(value == 0 for value in known) else None)
    if section_validation is not None and not section_validation.get("passed") and overall == 0:
        overall = 2
    final_status = "pass" if overall == 0 else "fail"
    summary = run_dir / "summary.md"
    summary.write_text(
        f"""# Phase 3 Section Subtask Experiment Summary
- Run ID: {run_id}
- Date Range: {start} to {end}
- Model: {model}
- Section Heading: {section_heading}
- Phase Return Code: {codes.get('phase')}
- Signature Scan Return Code: {codes.get('signature_scan')}
- Validation Return Code: {codes.get('validate')}
- Section Validation Passed: {section_validation.get('passed') if section_validation else None}
- Receipt Return Code: {codes.get('receipt')}
- Overall Return Code: {overall}
- Final Status: {final_status}
- Log: {log_file}
""",
        encoding="utf-8",
    )


def run_subtask(args: argparse.Namespace, manifest: dict[str, Any]) -> int:
    admission_path = Path(args.admission_receipt).expanduser().resolve()
    admission = json.loads(admission_path.read_text(encoding="utf-8"))
    if admission.get("admitted") is not True:
        raise SystemExit(f"static admission did not pass: {admission_path}")
    if admission.get("section_heading") != args.section_heading:
        raise SystemExit("admission section heading does not match requested run")

    target_repo = Path(args.target_repo).expanduser().resolve()
    if args.phase_timeout_seconds > 900:
        raise SystemExit("phase timeout must be <= 900 seconds")
    env = os.environ.copy()
    env["COPILOT_BIN"] = resolve_copilot_bin(env)
    env["MODEL"] = args.model
    if args.benchmark_mode:
        env["BENCHMARK_MODE"] = args.benchmark_mode

    materialize_surface(manifest, args.surface_id, str(target_repo))
    start = str(manifest["start"])
    end = str(manifest["end"])
    run_id = Path(args.run_dir_override).name
    run_dir = Path(args.run_dir_override).expanduser()
    if not run_dir.is_absolute():
        run_dir = target_repo / run_dir
    run_dir = run_dir.resolve()
    prompt_dir = run_dir / "prompts"
    log_dir = run_dir / "logs"
    session_dir = run_dir / "session"
    receipt_dir = run_dir / "receipts"
    for path in (prompt_dir, log_dir, session_dir, receipt_dir):
        path.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / "phase3_section_subtask.log"

    working_set = target_repo / "workspace" / f"newsletter_phase3_working_set_{end}.md"
    curated = target_repo / "workspace" / f"newsletter_phase3_curated_sections_{end}.md"
    backup_root = run_dir / "backups" / "workspace"
    backup_root.mkdir(parents=True, exist_ok=True)
    shutil.copy2(working_set, backup_root / working_set.name)
    shutil.copy2(curated, backup_root / curated.name)

    original_curated_text = curated.read_text(encoding="utf-8", errors="ignore")
    prepared_text = blank_section(original_curated_text, args.section_heading)
    curated.write_text(prepared_text, encoding="utf-8")
    prepared_path = run_dir / "prepared" / curated.name
    prepared_path.parent.mkdir(parents=True, exist_ok=True)
    prepared_path.write_text(prepared_text, encoding="utf-8")

    validate_cmd = [
        "python3",
        "tools/validate_phase3_curated.py",
        start,
        end,
        str(curated.relative_to(target_repo)),
        "--working-set",
        str(working_set.relative_to(target_repo)),
    ]
    if args.benchmark_mode:
        validate_cmd.extend(["--benchmark-mode", args.benchmark_mode])

    prompt_file = prompt_dir / "phase3_section_subtask.prompt.md"
    prompt = f"""@customer_newsletter
Run only the bounded Phase 3 section subtask for DATE_RANGE {start} to {end}.

Inputs:
- workspace/newsletter_phase3_working_set_{end}.md
- workspace/newsletter_phase3_curated_sections_{end}.md

Task boundary:
- Edit only this markdown section: {args.section_heading}
- Replace every `{PLACEHOLDER}` marker in that section.
- Use only the Phase 3 working set and existing curated artifact as sources.
- Do not run phases 0-2, Phase 4, product proof wrappers, source fetching, broad search, or unrelated validators.
- Do not edit receipts manually.
- Preserve all other sections byte-for-byte unless the validator reports an error inside the target section.

Quality floor for the target section:
- At least {args.min_section_bullets} sourced bullets.
- At least {args.min_section_links} markdown links.
- No TODO markers, HTML comments, or `{PLACEHOLDER}` markers remain.

Run this validator before stopping:
{' '.join(validate_cmd)}

Stop as soon as the curated artifact validates and the target section is complete.
"""
    prompt_file.write_text(prompt, encoding="utf-8")

    copilot_log = log_dir / "phase3_section_subtask_copilot.log"
    phase_cmd = [
        "python3",
        "tools/run_copilot_phase.py",
        "--model",
        args.model,
        "--copilot-bin",
        env["COPILOT_BIN"],
        "--prompt-file",
        path_for_copilot_phase(prompt_file, target_repo),
        "--log",
        path_for_copilot_phase(copilot_log, target_repo),
        "--timeout",
        str(args.phase_timeout_seconds),
        "--cwd",
        str(target_repo),
        "--phase-id",
        "phase3_section_subtask",
        "--session-out",
        path_for_copilot_phase(session_dir / "events.jsonl", target_repo),
        "--metrics-out",
        path_for_copilot_phase(session_dir / "phase-session-metrics.jsonl", target_repo),
        "--artifact-path",
        str(curated.relative_to(target_repo)),
        "--receipt-id",
        "phase3_section_subtask",
    ]
    if args.copilot_agent_mode == "agent-flag":
        phase_cmd[2:2] = ["--agent", "customer_newsletter"]
    if env_flag_enabled(env, "PHASE_REQUIRE_SESSION_LOG"):
        phase_cmd.append("--require-session-log")
    if env_flag_enabled(env, "PHASE_REQUIRE_DIRECT_TOKEN_FIELDS"):
        phase_cmd.append("--require-direct-token-fields")

    phase_rc = run_logged(phase_cmd, cwd=target_repo, env=env, log_file=log_file)
    signature_scan_rc = None
    validate_rc = None
    receipt_rc = None
    section_validation = None
    if phase_rc == 0:
        signature_scan_rc = run_phase3_signature_scan(
            target_repo=target_repo,
            log_paths=[copilot_log],
            env=env,
            log_file=log_file,
        )
    if phase_rc == 0 and signature_scan_rc == 0:
        validate_rc = run_logged(validate_cmd, cwd=target_repo, env=env, log_file=log_file)
    if phase_rc == 0 and signature_scan_rc == 0 and validate_rc == 0:
        section_validation = validate_section_output(
            curated,
            args.section_heading,
            args.min_section_bullets,
            args.min_section_links,
        )
        section_receipt = {
            "schema_version": "1.0.0",
            "receipt_type": "phase3_section_subtask_output",
            "generated_at_utc": utc_now(),
            "run_id": run_id,
            "model": args.model,
            "section_heading": args.section_heading,
            "admission_receipt_path": rel_or_abs(admission_path),
            "source_curated_sha256": admission["source_artifacts"]["phase3_curated"]["sha256"],
            "prepared_curated_sha256": sha256_file(prepared_path),
            "output_curated_path": rel_or_abs(curated),
            "output_curated_sha256": sha256_file(curated),
            "section_validation": section_validation,
            "non_claims": [
                "This is an evidence-only bounded subtask row.",
                "This row is not a production adoption, durable savings claim, or model recommendation.",
            ],
        }
        section_receipt_path = receipt_dir / "phase3_section_subtask_output_receipt.json"
        section_receipt_path.write_text(json.dumps(section_receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        receipt_rc = 0 if section_validation["passed"] else 2
    if phase_rc == 0 and signature_scan_rc == 0 and validate_rc == 0 and receipt_rc == 0:
        receipt_rc = run_logged(
            [
                "bash",
                "tools/record_phase_receipt.sh",
                start,
                end,
                "phase3_section_subtask",
                str(curated.relative_to(target_repo)),
            ],
            cwd=target_repo,
            env=env,
            log_file=log_file,
        )

    evidence_dir = run_dir / "run-evidence"
    evidence_dir.mkdir(parents=True, exist_ok=True)
    for source in (working_set, curated):
        if source.exists():
            shutil.copy2(source, evidence_dir / source.name)

    write_summary(
        run_dir=run_dir,
        run_id=run_id,
        start=start,
        end=end,
        model=args.model,
        section_heading=args.section_heading,
        codes={
            "phase": phase_rc,
            "signature_scan": signature_scan_rc,
            "validate": validate_rc,
            "receipt": receipt_rc,
        },
        section_validation=section_validation,
        log_file=log_file,
    )
    return next(
        (
            code
            for code in (phase_rc, signature_scan_rc, validate_rc, receipt_rc)
            if code not in (None, 0)
        ),
        0,
    )


def main() -> int:
    args = parse_args()
    manifest = load_manifest(args.manifest)
    if args.command == "admit":
        receipt = build_static_admission(args, manifest)
        output = Path(args.output).expanduser().resolve()
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(json.dumps({"admitted": receipt["admitted"], "output": str(output)}, sort_keys=True))
        return 0 if receipt["admitted"] else 1
    if args.command == "run":
        return run_subtask(args, manifest)
    raise SystemExit(f"unsupported command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())

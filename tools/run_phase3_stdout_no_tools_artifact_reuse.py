#!/usr/bin/env python3
"""Evidence-only Phase 3 stdout/no-tools artifact-reuse runner."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

from newsletter_experiment_common import load_json, sha256_path, sha256_text
from newsletter_phase_experimenter import (
    load_phase3_prompt_policy,
    materialize_surface,
    prompt_policy_text,
    refresh_phase_experiment_provenance,
    resolve_repo_path,
)

ROOT = Path(__file__).resolve().parent.parent
HOMEBREW_COPILOT = Path("/opt/homebrew/bin/copilot")
NO_REFETCH_SIDECAR_FILENAMES = {
    "phase2_selected_source_ids": "newsletter_phase2_selected_source_ids_{end}.json",
    "phase2_fetch_attempt_ledger": "newsletter_phase2_fetch_attempt_ledger_{end}.json",
    "phase2_no_refetch_compliance": "newsletter_phase2_no_refetch_compliance_{end}.json",
}
COMPETITIVE_CHOICE_PATTERNS = (
    re.compile(
        r"competitive|rival|claude code|alternative|market|ecosystem|"
        r"platform[- ]choice|customer[- ]choice|provider[- ]choice|agent[- ]provider[- ]choice",
        re.IGNORECASE,
    ),
    re.compile(r"bring.*subscription|take.*subscription|anywhere|platform.*open", re.IGNORECASE),
    re.compile(r"agent.*choice|pick.*agent|choose.*agent|multiple.*provider", re.IGNORECASE),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, help="Fixture-pack manifest")
    parser.add_argument("--surface-id", default="phase2_entry_surface")
    parser.add_argument("--target-repo", required=True)
    parser.add_argument("--model", default="gpt-5.5")
    parser.add_argument("--benchmark-mode", default="")
    parser.add_argument("--run-dir-override", default="")
    parser.add_argument("--phase-timeout-seconds", type=int, default=900)
    parser.add_argument(
        "--copilot-bin",
        default=os.environ.get("COPILOT_BIN") or str(HOMEBREW_COPILOT),
        help="Copilot CLI executable. Defaults to COPILOT_BIN or /opt/homebrew/bin/copilot.",
    )
    parser.add_argument("--agent", default="", help="Optional Copilot agent flag")
    parser.add_argument("--available-tool", action="append", default=[])
    parser.add_argument("--excluded-tool", action="append", default=[])
    parser.add_argument("--skip-materialize", action="store_true")
    parser.add_argument(
        "--preserve-existing-provenance",
        action="store_true",
        help=(
            "Do not refresh the cycle marker or rebind existing receipts before "
            "Phase 3. Use when the wrapper is called inside a full orchestrated "
            "run that already prepared the run marker."
        ),
    )
    parser.add_argument(
        "--phase3-prompt-policy",
        default="",
        help="Optional evidence-only prompt policy JSON to append to the stdout prompt",
    )
    parser.add_argument(
        "--source-pruning-policy",
        default="",
        help=(
            "Optional compact working-set source pruning policy JSON. When set, "
            "the wrapper builds the canonical working set, applies the policy, "
            "and embeds the compact policy output in the no-tools prompt while "
            "validating against the canonical working set."
        ),
    )
    parser.add_argument(
        "--no-refetch-admission",
        default="",
        help="Optional selected-source/no-refetch admission receipt to bind in run metadata",
    )
    parser.add_argument(
        "--require-v2-readiness",
        action="store_true",
        help="Fail closed unless the stdout Phase 3 artifact passes deterministic V2-readiness checks.",
    )
    return parser.parse_args()


def die(message: str) -> None:
    raise SystemExit(message)


def resolve_copilot_bin(raw: str) -> str:
    candidate = str(raw or "").strip() or str(HOMEBREW_COPILOT)
    path = Path(candidate).expanduser()
    if path.is_absolute() or "/" in candidate:
        return str(path.resolve()) if path.exists() else candidate
    resolved = shutil.which(candidate)
    if resolved:
        return str(Path(resolved).resolve())
    if candidate == "copilot" and HOMEBREW_COPILOT.exists():
        return str(HOMEBREW_COPILOT.resolve())
    return candidate


def json_dumps(payload: Any) -> str:
    return json.dumps(payload, indent=2, sort_keys=True) + "\n"


def append_log(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(text)
        if text and not text.endswith("\n"):
            handle.write("\n")


def run_logged(cmd: list[str], *, cwd: Path, env: dict[str, str], log_file: Path) -> int:
    append_log(log_file, "$ " + " ".join(cmd) + "\n")
    completed = subprocess.run(cmd, cwd=cwd, env=env, text=True, capture_output=True, check=False)
    append_log(log_file, completed.stdout)
    append_log(log_file, completed.stderr)
    return completed.returncode


def load_manifest(path_text: str) -> dict[str, Any]:
    path = Path(path_text).expanduser().resolve()
    payload = load_json(path)
    if not isinstance(payload, dict):
        die(f"Fixture manifest not found or invalid JSON: {path}")
    payload["_manifest_path"] = str(path)
    return payload


def write_prompt_metadata(
    *,
    path: Path,
    base_prompt: str,
    full_prompt: str,
    policy: dict[str, Any] | None,
    policy_path: Path | None,
    working_set: Path,
    scaffold: Path,
    source_pruning_policy: Path | None,
    source_pruning_context: Path | None,
    source_pruning_receipt: Path | None,
    no_refetch_admission: Path | None,
    no_refetch_sidecar_materialization: dict[str, Any] | None,
) -> None:
    payload = {
        "schema_version": 1,
        "receipt_type": "phase3_stdout_no_tools_prompt_metadata",
        "base_prompt_sha256": sha256_text(base_prompt),
        "full_prompt_sha256": sha256_text(full_prompt),
        "working_set_path": str(working_set),
        "working_set_sha256": sha256_path(working_set) if working_set.exists() else None,
        "scaffold_path": str(scaffold),
        "scaffold_sha256": sha256_path(scaffold) if scaffold.exists() else None,
        "source_pruning_applied": source_pruning_context is not None,
        "source_pruning_policy_path": str(source_pruning_policy) if source_pruning_policy else None,
        "source_pruning_policy_sha256": (
            sha256_path(source_pruning_policy)
            if source_pruning_policy and source_pruning_policy.exists()
            else None
        ),
        "source_pruning_context_path": str(source_pruning_context) if source_pruning_context else None,
        "source_pruning_context_sha256": (
            sha256_path(source_pruning_context)
            if source_pruning_context and source_pruning_context.exists()
            else None
        ),
        "source_pruning_receipt_path": str(source_pruning_receipt) if source_pruning_receipt else None,
        "source_pruning_receipt_sha256": (
            sha256_path(source_pruning_receipt)
            if source_pruning_receipt and source_pruning_receipt.exists()
            else None
        ),
        "policy_enabled": policy is not None,
        "policy_id": policy.get("policy_id") if policy else None,
        "policy_path": str(policy_path) if policy_path else None,
        "policy_sha256": sha256_path(policy_path) if policy_path else None,
        "no_refetch_admission_path": str(no_refetch_admission) if no_refetch_admission else None,
        "no_refetch_admission_sha256": (
            sha256_path(no_refetch_admission)
            if no_refetch_admission and no_refetch_admission.exists()
            else None
        ),
        "no_refetch_sidecar_materialization": no_refetch_sidecar_materialization,
        "non_claims": [
            "This prompt is evidence-only and does not change production behavior.",
            "This metadata binds the stdout/no-tools candidate prompt only.",
        ],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json_dumps(payload), encoding="utf-8")


def is_sha256(value: Any) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(char in "0123456789abcdef" for char in value.lower())


def source_contains_competitive_choice(text: str) -> bool:
    return any(pattern.search(text or "") for pattern in COMPETITIVE_CHOICE_PATTERNS)


def resolve_no_refetch_sidecar_source(
    source_text: str,
    *,
    admission_path: Path,
    target_repo: Path,
    filename: str,
    expected_sha: str,
) -> Path:
    raw_path = Path(source_text).expanduser()
    candidates: list[Path] = []
    candidates.append((admission_path.parent / "workspace" / filename).resolve())
    if raw_path.is_absolute():
        candidates.append(raw_path)
    else:
        candidates.append((target_repo / raw_path).resolve())
        candidates.append((admission_path.parent / raw_path).resolve())

    seen: set[str] = set()
    mismatches: list[str] = []
    for candidate in candidates:
        key = str(candidate)
        if key in seen:
            continue
        seen.add(key)
        if not candidate.exists():
            continue
        actual_sha = sha256_path(candidate)
        if actual_sha == expected_sha:
            return candidate
        mismatches.append(f"{candidate} sha256={actual_sha}")
    die(
        "No-refetch sidecar source not found with matching hash for "
        f"{filename}; expected {expected_sha}; tried: "
        f"{', '.join(str(candidate) for candidate in candidates)}"
        + (f"; mismatches: {', '.join(mismatches)}" if mismatches else "")
    )


def materialize_no_refetch_sidecars(admission_path: Path, target_repo: Path, end: str, log_file: Path) -> dict[str, Any]:
    """Copy no-refetch sidecars named by an admission receipt into the candidate repo."""
    admission = load_json(admission_path)
    if admission.get("admission_verdict") != "admit_no_refetch":
        die(f"No-refetch admission receipt verdict is not admit_no_refetch: {admission_path}")
    if admission.get("no_refetch_compliance") != "pass":
        die(f"No-refetch admission receipt compliance is not pass: {admission_path}")
    if admission.get("blockers") not in (None, []):
        die(f"No-refetch admission receipt has blockers: {admission_path}")
    generated = admission.get("generated_artifacts")
    if not isinstance(generated, dict):
        die(f"No-refetch admission receipt lacks generated_artifacts: {admission_path}")

    workspace = target_repo / "workspace"
    workspace.mkdir(parents=True, exist_ok=True)
    copied: dict[str, Any] = {}
    materialized_at = dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    for artifact_name, filename_template in NO_REFETCH_SIDECAR_FILENAMES.items():
        filename = filename_template.format(end=end)
        artifact = generated.get(artifact_name)
        if not isinstance(artifact, dict):
            die(f"No-refetch admission receipt lacks {artifact_name}: {admission_path}")
        source_text = str(artifact.get("path") or "").strip()
        if not source_text:
            die(f"No-refetch admission artifact lacks path for {artifact_name}: {admission_path}")

        expected_sha = artifact.get("sha256")
        if not is_sha256(expected_sha):
            die(f"No-refetch admission artifact lacks valid sha256 for {artifact_name}: {admission_path}")
        source_path = resolve_no_refetch_sidecar_source(
            source_text,
            admission_path=admission_path,
            target_repo=target_repo,
            filename=filename,
            expected_sha=expected_sha,
        )
        actual_source_sha = sha256_path(source_path)

        destination = workspace / filename
        shutil.copy2(source_path, destination)
        actual_destination_sha = sha256_path(destination)
        if actual_destination_sha != expected_sha:
            die(
                f"No-refetch sidecar destination hash mismatch for {artifact_name}: "
                f"expected {expected_sha}, got {actual_destination_sha}"
            )
        copied[artifact_name] = {
            "source_path": str(source_path),
            "source_sha256": actual_source_sha,
            "destination_path": str(destination),
            "sha256": actual_destination_sha,
        }
    result = {
        "materialized_at_utc": materialized_at,
        "admission_path": str(admission_path),
        "admission_sha256": sha256_path(admission_path),
        "sidecars": copied,
    }
    append_log(log_file, "Materialized no-refetch sidecars: " + json.dumps(result, sort_keys=True))
    return result


def strip_outer_code_fence(text: str) -> str:
    lines = text.strip().splitlines()
    if len(lines) >= 2 and lines[0].strip().startswith("```") and lines[-1].strip() == "```":
        return "\n".join(lines[1:-1]).strip() + "\n"
    return text.rstrip() + "\n"


def extract_candidate_stdout(raw_text: str) -> str:
    """Extract raw assistant content from Copilot JSONL output when available."""
    messages: list[str] = []
    for line in raw_text.splitlines():
        if not line.strip():
            continue
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        if payload.get("type") != "assistant.message":
            continue
        data = payload.get("data")
        if not isinstance(data, dict):
            continue
        content = data.get("content")
        if isinstance(content, str) and content.strip():
            messages.append(content)
    if messages:
        return strip_outer_code_fence(messages[-1])
    return strip_outer_code_fence(raw_text)


def run_phase3_stdout(args: argparse.Namespace) -> int:
    target_repo = Path(args.target_repo).expanduser().resolve()
    if not target_repo.exists():
        die(f"Target repo not found: {target_repo}")
    if args.phase_timeout_seconds > 900:
        die("phase timeout must be <= 900 seconds")
    if not args.available_tool and not args.excluded_tool:
        die("stdout/no-tools artifact-reuse runner requires explicit Copilot tool filters")

    manifest = load_manifest(args.manifest)
    start = str(manifest.get("start") or "")
    end = str(manifest.get("end") or "")
    mode = str(manifest.get("mode") or "")
    if not start or not end:
        die("Fixture manifest must include start and end")
    if not args.skip_materialize:
        materialize_surface(manifest, args.surface_id, str(target_repo))

    env = os.environ.copy()
    env["COPILOT_BIN"] = resolve_copilot_bin(args.copilot_bin)
    env["MODEL"] = args.model
    if args.benchmark_mode:
        env["BENCHMARK_MODE"] = args.benchmark_mode

    run_id = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    run_dir = (
        Path(args.run_dir_override).expanduser()
        if args.run_dir_override
        else target_repo / "runs" / "phase3-stdout-no-tools" / f"{run_id}_{start}_to_{end}"
    )
    if not run_dir.is_absolute():
        run_dir = target_repo / run_dir
    run_dir = run_dir.resolve()
    prompt_dir = run_dir / "prompts"
    log_dir = run_dir / "logs"
    stdout_dir = run_dir / "stdout"
    session_dir = run_dir / "session"
    validation_dir = run_dir / "validation"
    for directory in (prompt_dir, log_dir, stdout_dir, session_dir, validation_dir):
        directory.mkdir(parents=True, exist_ok=True)

    log_file = log_dir / "phase3_stdout_no_tools.log"
    if args.preserve_existing_provenance:
        append_log(
            log_file,
            "Preserving existing full-run provenance; stdout/no-tools wrapper will not refresh the cycle marker.\n",
        )
    else:
        refresh_phase_experiment_provenance(target_repo, start, end, run_id, args.model, log_file)

    working_set = target_repo / "workspace" / f"newsletter_phase3_working_set_{end}.md"
    curated = target_repo / "workspace" / f"newsletter_phase3_curated_sections_{end}.md"
    build_cmd = ["python3", "tools/build_phase3_working_set.py", start, end]
    init_cmd = ["python3", "tools/init_phase3_curated_sections.py", start, end]
    if args.benchmark_mode:
        build_cmd.extend(["--benchmark-mode", args.benchmark_mode])
        init_cmd.extend(["--benchmark-mode", args.benchmark_mode])

    build_rc = run_logged(build_cmd, cwd=target_repo, env=env, log_file=log_file)
    if build_rc != 0:
        write_summary(run_dir, run_id, start, end, mode, args.model, build_rc, None, None, None, None, None, None, log_file)
        return build_rc
    receipt_working_rc = run_logged(
        ["bash", "tools/record_phase_receipt.sh", start, end, "phase3_working_set", str(working_set.relative_to(target_repo))],
        cwd=target_repo,
        env=env,
        log_file=log_file,
    )
    if receipt_working_rc != 0:
        write_summary(run_dir, run_id, start, end, mode, args.model, build_rc, receipt_working_rc, None, None, None, None, None, log_file)
        return receipt_working_rc
    init_rc = run_logged(init_cmd, cwd=target_repo, env=env, log_file=log_file)
    if init_rc != 0:
        write_summary(run_dir, run_id, start, end, mode, args.model, build_rc, receipt_working_rc, init_rc, None, None, None, None, log_file)
        return init_rc
    if not working_set.exists() or not curated.exists():
        die("Phase 3 working set or scaffold was not materialized")

    source_pruning_policy_path = (
        resolve_repo_path(args.source_pruning_policy, target_repo)
        if args.source_pruning_policy
        else None
    )
    source_pruning_context = None
    source_pruning_receipt = None
    if source_pruning_policy_path:
        if not source_pruning_policy_path.exists():
            die(f"Source pruning policy not found: {source_pruning_policy_path}")
        source_pruning_rc = run_logged(
            [
                "python3",
                "tools/apply_newsletter_source_pruning_policy.py",
                start,
                end,
                "--policy",
                str(source_pruning_policy_path),
                "--source-root",
                ".",
                "--output-root",
                ".",
                "--require-admission",
            ],
            cwd=target_repo,
            env=env,
            log_file=log_file,
        )
        if source_pruning_rc != 0:
            write_summary(run_dir, run_id, start, end, mode, args.model, build_rc, receipt_working_rc, init_rc, None, source_pruning_rc, None, None, log_file)
            return source_pruning_rc
        source_pruning_context = target_repo / "workspace" / f"newsletter_source_pruning_context_{end}.md"
        source_pruning_receipt = target_repo / "workspace" / f"newsletter_source_pruning_receipt_{end}.json"
        if not source_pruning_context.exists() or not source_pruning_receipt.exists():
            die("Source pruning policy did not materialize context and receipt artifacts")

    policy, policy_path = load_phase3_prompt_policy(args.phase3_prompt_policy, target_repo)
    policy_append = prompt_policy_text(policy)
    no_refetch_path = (
        resolve_repo_path(args.no_refetch_admission, target_repo)
        if args.no_refetch_admission
        else None
    )
    if no_refetch_path and not no_refetch_path.exists():
        die(f"No-refetch admission receipt not found: {no_refetch_path}")
    no_refetch_sidecar_materialization = None
    if no_refetch_path:
        no_refetch_sidecar_materialization = materialize_no_refetch_sidecars(no_refetch_path, target_repo, end, log_file)

    context_heading = "Phase 3 Working Set"
    context_body = working_set.read_text(encoding="utf-8")
    if source_pruning_context:
        context_heading = "Compact Phase 3 Source Context"
        context_body = source_pruning_context.read_text(encoding="utf-8")

    base_prompt = f"""You are running an evidence-only Phase 3 curation experiment for DATE_RANGE {start} to {end}.

No tools are allowed or needed. Do not read files, write files, run commands, fetch URLs, call tools, or ask for help.
Use only the scaffold and source/context text embedded in this prompt.
Return only the complete Markdown contents for workspace/newsletter_phase3_curated_sections_{end}.md.
Do not wrap the answer in code fences. Do not include explanations outside the artifact.

The wrapper will validate your stdout with:
python3 tools/validate_phase3_curated.py {start} {end} <stdout-artifact> --working-set workspace/newsletter_phase3_working_set_{end}.md

The validation working set remains the canonical quality floor even when this prompt embeds compact source context.
When this prompt embeds compact source context, preserve the V2-critical editorial scaffolding:
- Compress model availability and model update content into one curated bullet.
- Do not create separate main bullets for model availability, provider availability, BYOK,
  reasoning controls, token visibility, or usage-based billing when those signals can be
  represented as one model-governance/platform-choice bullet.
- Include platform-choice or competitive framing language when the source context contains agent/provider/customer-choice signals.
- Keep source links close to each main bullet; aim for at least one official source URL per main bullet and enough links for later final-output density.
- Preserve every explicit VS Code release version signal from the source context as a separate version token, even when several versions are summarized together.
- Prefer official, recurring newsletter domains: github.blog, github.com, docs.github.com, code.visualstudio.com, learn.microsoft.com, developer.microsoft.com, devblogs.microsoft.com, plugins.jetbrains.com, resources.github.com, www.youtube.com, github.registration.goldcast.io, luma.com, and learn.github.com.

## Existing Scaffold

{curated.read_text(encoding="utf-8")}

## {context_heading}

{context_body}
"""
    full_prompt = base_prompt
    if policy_append:
        full_prompt += f"\n## Evidence-Only Prompt Policy ({policy['policy_id']})\n\n{policy_append}\n"
    prompt_file = prompt_dir / "phase3_stdout_no_tools.prompt.md"
    prompt_file.write_text(full_prompt, encoding="utf-8")
    prompt_metadata_path = run_dir / "prompt-metadata" / "phase3_stdout_no_tools_prompt_metadata.json"
    write_prompt_metadata(
        path=prompt_metadata_path,
        base_prompt=base_prompt,
        full_prompt=full_prompt,
        policy=policy,
        policy_path=policy_path,
        working_set=working_set,
        scaffold=curated,
        source_pruning_policy=source_pruning_policy_path,
        source_pruning_context=source_pruning_context,
        source_pruning_receipt=source_pruning_receipt,
        no_refetch_admission=no_refetch_path,
        no_refetch_sidecar_materialization=no_refetch_sidecar_materialization,
    )

    raw_stdout = stdout_dir / "phase3_stdout_raw.md"
    candidate_stdout = stdout_dir / "phase3_curated_candidate.md"
    copilot_log = log_dir / "phase3_stdout_no_tools_copilot.log"
    phase_cmd = [
        "python3",
        "tools/run_copilot_phase.py",
        "--model",
        args.model,
        "--copilot-bin",
        env["COPILOT_BIN"],
        "--prompt-file",
        str(prompt_file),
        "--log",
        str(copilot_log),
        "--stdout-out",
        str(raw_stdout),
        "--timeout",
        str(args.phase_timeout_seconds),
        "--cwd",
        str(target_repo),
        "--phase-id",
        "phase3_stdout_no_tools_artifact_reuse",
        "--session-out",
        str(session_dir / "events.jsonl"),
        "--metrics-out",
        str(session_dir / "phase-session-metrics.jsonl"),
        "--artifact-path",
        str(raw_stdout),
        "--receipt-id",
        "phase3_stdout_no_tools",
        "--require-session-log",
        "--require-direct-token-fields",
        "--output-format",
        "json",
    ]
    if args.agent:
        phase_cmd[2:2] = ["--agent", args.agent]
    for tool in args.available_tool:
        phase_cmd.extend(["--available-tool", tool])
    for tool in args.excluded_tool:
        phase_cmd.extend(["--excluded-tool", tool])

    phase_rc = run_logged(phase_cmd, cwd=target_repo, env=env, log_file=log_file)
    if phase_rc != 0:
        write_summary(run_dir, run_id, start, end, mode, args.model, build_rc, receipt_working_rc, init_rc, phase_rc, None, None, None, log_file)
        return phase_rc
    if not raw_stdout.exists() or not raw_stdout.read_text(encoding="utf-8").strip():
        write_summary(run_dir, run_id, start, end, mode, args.model, build_rc, receipt_working_rc, init_rc, phase_rc, 2, None, None, log_file)
        append_log(log_file, "Missing or empty stdout candidate; refusing materialization.")
        return 2
    raw_text = raw_stdout.read_text(encoding="utf-8")
    if "Unknown tool name in the tool excludedlist" in raw_text:
        write_summary(run_dir, run_id, start, end, mode, args.model, build_rc, receipt_working_rc, init_rc, phase_rc, 3, None, None, log_file)
        append_log(log_file, "Copilot reported an unknown excluded tool; refusing stdout materialization.")
        return 3
    candidate_stdout.write_text(extract_candidate_stdout(raw_text), encoding="utf-8")

    validate_output = validation_dir / "phase3_stdout_validation.txt"
    validate_cmd = [
        "python3",
        "tools/validate_phase3_curated.py",
        start,
        end,
        str(candidate_stdout),
        "--working-set",
        str(working_set),
    ]
    if args.benchmark_mode:
        validate_cmd.extend(["--benchmark-mode", args.benchmark_mode])
    validation_rc = run_logged(validate_cmd, cwd=target_repo, env=env, log_file=log_file)
    validate_output.write_text(
        json_dumps(
            {
                "schema_version": 1,
                "validator_command": validate_cmd,
                "exit_code": validation_rc,
                "validated_artifact_path": str(candidate_stdout),
                "validated_artifact_sha256": sha256_path(candidate_stdout),
                "working_set_path": str(working_set),
                "working_set_sha256": sha256_path(working_set),
            }
        ),
        encoding="utf-8",
    )
    if validation_rc != 0:
        write_summary(run_dir, run_id, start, end, mode, args.model, build_rc, receipt_working_rc, init_rc, phase_rc, validation_rc, None, None, log_file)
        return validation_rc
    if args.require_v2_readiness:
        v2_readiness_output = validation_dir / "phase3_v2_readiness.json"
        readiness_source_text = (
            source_pruning_context.read_text(encoding="utf-8", errors="ignore")
            if source_pruning_context
            else working_set.read_text(encoding="utf-8", errors="ignore")
        )
        competitive_signal_floor = "1" if source_contains_competitive_choice(readiness_source_text) else "0"
        v2_readiness_cmd = [
            "python3",
            "tools/validate_phase3_v2_readiness.py",
            str(candidate_stdout),
            "--working-set",
            str(working_set),
            "--write-receipt",
            str(v2_readiness_output),
            "--min-competitive-signal-groups",
            competitive_signal_floor,
            "--min-main-bullet-link-ratio",
            "70",
            "--min-link-density-times10",
            "10",
            "--min-valid-domain-ratio",
            "75",
        ]
        if source_pruning_context:
            v2_readiness_cmd.extend(
                [
                    "--source-context",
                    str(source_pruning_context),
                    "--require-vscode-version-coverage",
                ]
            )
        v2_readiness_rc = run_logged(v2_readiness_cmd, cwd=target_repo, env=env, log_file=log_file)
        if v2_readiness_rc != 0:
            write_summary(run_dir, run_id, start, end, mode, args.model, build_rc, receipt_working_rc, init_rc, phase_rc, v2_readiness_rc, None, None, log_file)
            return v2_readiness_rc

    curated.parent.mkdir(parents=True, exist_ok=True)
    curated.write_text(candidate_stdout.read_text(encoding="utf-8"), encoding="utf-8")
    receipt_rc = run_logged(
        ["bash", "tools/record_phase_receipt.sh", start, end, "phase3_curated", str(curated.relative_to(target_repo))],
        cwd=target_repo,
        env=env,
        log_file=log_file,
    )
    write_run_metadata(
        run_dir=run_dir,
        run_id=run_id,
        start=start,
        end=end,
        mode=mode,
        model=args.model,
        manifest=manifest,
        manifest_path=Path(args.manifest).expanduser().resolve(),
        prompt_metadata_path=prompt_metadata_path,
        raw_stdout=raw_stdout,
        candidate_stdout=candidate_stdout,
        materialized_artifact=curated,
        validation_result=validate_output,
        tool_filters={"available_tools": args.available_tool, "excluded_tools": args.excluded_tool},
        source_pruning_policy=source_pruning_policy_path,
        source_pruning_context=source_pruning_context,
        source_pruning_receipt=source_pruning_receipt,
        no_refetch_path=no_refetch_path,
        no_refetch_sidecar_materialization=no_refetch_sidecar_materialization,
        preserve_existing_provenance=args.preserve_existing_provenance,
    )
    write_summary(run_dir, run_id, start, end, mode, args.model, build_rc, receipt_working_rc, init_rc, phase_rc, validation_rc, receipt_rc, 0, log_file)
    return receipt_rc


def write_run_metadata(
    *,
    run_dir: Path,
    run_id: str,
    start: str,
    end: str,
    mode: str,
    model: str,
    manifest: dict[str, Any],
    manifest_path: Path,
    prompt_metadata_path: Path,
    raw_stdout: Path,
    candidate_stdout: Path,
    materialized_artifact: Path,
    validation_result: Path,
    tool_filters: dict[str, list[str]],
    source_pruning_policy: Path | None,
    source_pruning_context: Path | None,
    source_pruning_receipt: Path | None,
    no_refetch_path: Path | None,
    no_refetch_sidecar_materialization: dict[str, Any] | None,
    preserve_existing_provenance: bool,
) -> None:
    payload = {
        "schema_version": 1,
        "receipt_type": "phase3_stdout_no_tools_artifact_reuse_run_metadata",
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "run_id": run_id,
        "start": start,
        "end": end,
        "mode": mode,
        "model": model,
        "run_dir": str(run_dir),
        "fixture_manifest_path": str(manifest_path),
        "fixture_manifest_sha256": sha256_path(manifest_path),
        "fixture_manifest_id": manifest.get("manifest_id"),
        "source_run_id": manifest.get("run_id"),
        "preserve_existing_provenance": preserve_existing_provenance,
        "prompt_metadata_path": str(prompt_metadata_path),
        "prompt_metadata_sha256": sha256_path(prompt_metadata_path),
        "raw_stdout_path": str(raw_stdout),
        "raw_stdout_sha256": sha256_path(raw_stdout),
        "stdout_artifact_path": str(candidate_stdout),
        "stdout_artifact_sha256": sha256_path(candidate_stdout),
        "materialized_artifact_path": str(materialized_artifact),
        "materialized_artifact_sha256": sha256_path(materialized_artifact),
        "validation_result_path": str(validation_result),
        "validation_result_sha256": sha256_path(validation_result),
        "tool_filters": tool_filters,
        "source_pruning_applied": source_pruning_context is not None,
        "source_pruning_policy_path": str(source_pruning_policy) if source_pruning_policy else None,
        "source_pruning_policy_sha256": sha256_path(source_pruning_policy) if source_pruning_policy else None,
        "source_pruning_context_path": str(source_pruning_context) if source_pruning_context else None,
        "source_pruning_context_sha256": sha256_path(source_pruning_context) if source_pruning_context else None,
        "source_pruning_receipt_path": str(source_pruning_receipt) if source_pruning_receipt else None,
        "source_pruning_receipt_sha256": sha256_path(source_pruning_receipt) if source_pruning_receipt else None,
        "no_refetch_admission_path": str(no_refetch_path) if no_refetch_path else None,
        "no_refetch_admission_sha256": sha256_path(no_refetch_path) if no_refetch_path else None,
        "no_refetch_sidecar_materialization": no_refetch_sidecar_materialization,
        "non_claims": [
            "This is disabled-by-default evidence tooling.",
            "This run metadata is not production behavior and not a durable savings claim.",
        ],
    }
    (run_dir / "run-metadata.json").write_text(json_dumps(payload), encoding="utf-8")


def write_summary(
    run_dir: Path,
    run_id: str,
    start: str,
    end: str,
    mode: str,
    model: str,
    build_rc: int | None,
    receipt_working_rc: int | None,
    init_rc: int | None,
    phase_rc: int | None,
    validation_rc: int | None,
    receipt_rc: int | None,
    materialization_rc: int | None,
    log_file: Path,
) -> None:
    codes = [build_rc, receipt_working_rc, init_rc, phase_rc, validation_rc, receipt_rc]
    known = [code for code in codes if code is not None]
    overall = next((code for code in known if code != 0), 0 if known and all(code == 0 for code in known) else None)
    status = "pass" if overall == 0 else "fail"
    (run_dir / "summary.md").write_text(
        f"""# Phase 3 Stdout/No-Tools Artifact-Reuse Summary
- Run ID: {run_id}
- Date Range: {start} to {end}
- Mode: {mode}
- Model: {model}
- Build Return Code: {build_rc}
- Working Set Receipt Return Code: {receipt_working_rc}
- Init Return Code: {init_rc}
- Phase Return Code: {phase_rc}
- Validation Return Code: {validation_rc}
- Curated Receipt Return Code: {receipt_rc}
- Materialization Return Code: {materialization_rc}
- Overall Return Code: {overall}
- Final Status: {status}
- Log: {log_file}
""",
        encoding="utf-8",
    )


def main() -> int:
    return run_phase3_stdout(parse_args())


if __name__ == "__main__":
    raise SystemExit(main())

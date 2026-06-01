#!/usr/bin/env python3
"""Materialize retained fixture packs and run bounded phase experiments."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any

from newsletter_experiment_common import load_json


ROOT = Path(__file__).resolve().parent.parent
HOMEBREW_COPILOT = Path("/opt/homebrew/bin/copilot")


def die(message: str) -> None:
    raise SystemExit(message)


def resolve_copilot_bin(env: dict[str, str]) -> str:
    configured = str(env.get("COPILOT_BIN") or "copilot").strip() or "copilot"
    path = Path(configured).expanduser()
    if path.is_absolute() or "/" in configured:
        if path.exists():
            return str(path.resolve())
        return configured
    resolved = shutil.which(configured, path=env.get("PATH"))
    if resolved:
        return str(Path(resolved).resolve())
    if configured == "copilot" and HOMEBREW_COPILOT.exists():
        return str(HOMEBREW_COPILOT.resolve())
    return configured


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    inventory = subparsers.add_parser("inventory", help="List surfaces in a fixture manifest")
    inventory.add_argument("--manifest", required=True)

    materialize = subparsers.add_parser("materialize", help="Copy one surface into a target repo")
    materialize.add_argument("--manifest", required=True)
    materialize.add_argument("--surface-id", required=True)
    materialize.add_argument("--target-repo", required=True)

    phase4 = subparsers.add_parser("phase4-fast", help="Materialize a surface, then run the fast Phase 4 path")
    phase4.add_argument("--manifest", required=True)
    phase4.add_argument("--surface-id", default="phase4_fast_surface")
    phase4.add_argument("--target-repo", required=True)
    phase4.add_argument("--model", default="gpt-5.5")
    phase4.add_argument("--benchmark-mode", default="")
    phase4.add_argument("--run-dir-override", default="")

    phase3 = subparsers.add_parser("phase3-curation", help="Materialize a surface, then run bounded Phase 3 curation")
    phase3.add_argument("--manifest", required=True)
    phase3.add_argument("--surface-id", default="phase2_entry_surface")
    phase3.add_argument("--target-repo", required=True)
    phase3.add_argument("--model", default="gpt-5.5")
    phase3.add_argument("--benchmark-mode", default="")
    phase3.add_argument("--run-dir-override", default="")
    phase3.add_argument("--phase-timeout-seconds", type=int, default=900)
    phase3.add_argument(
        "--copilot-agent-mode",
        choices=["agent-flag", "prompt-mention-only"],
        default="agent-flag",
        help=(
            "Use the Copilot --agent flag, or rely only on the @customer_newsletter "
            "prompt mention so model binding can be tested without agent flag fallback."
        ),
    )
    phase3.add_argument(
        "--skip-materialize",
        action="store_true",
        help="Run Phase 3 against an already materialized target repo surface",
    )
    phase3.add_argument(
        "--phase3-prompt-policy",
        default="",
        help=(
            "Optional evidence-only Phase 3 prompt policy JSON to append to the "
            "base curation prompt. Used for bounded experiments, not production behavior."
        ),
    )

    return parser.parse_args()


def load_manifest(path_text: str) -> dict[str, Any]:
    path = Path(path_text).expanduser().resolve()
    payload = load_json(path)
    if not payload:
        die(f"Fixture manifest not found or unreadable: {path}")
    payload["_manifest_path"] = str(path)
    return payload


def resolve_manifest_repo_root(manifest: dict[str, Any]) -> Path:
    manifest_path = Path(str(manifest.get("_manifest_path"))).resolve()
    probe_paths = []
    for key in ("source_run_dir", "source_artifact_root"):
        value = str(manifest.get(key) or "").strip()
        if value:
            probe_paths.append(Path(value))
    if not probe_paths:
        return manifest_path.parent
    for candidate in (manifest_path.parent, *manifest_path.parents):
        if any((candidate / probe).exists() for probe in probe_paths):
            return candidate
    return manifest_path.parent


def materialize_surface(manifest: dict[str, Any], surface_id: str, target_repo_text: str) -> list[str]:
    target_repo = Path(target_repo_text).expanduser().resolve()
    if not target_repo.exists():
        die(f"Target repo not found: {target_repo}")
    manifest_repo_root = resolve_manifest_repo_root(manifest)
    surface = (manifest.get("surfaces") or {}).get(surface_id)
    if not isinstance(surface, list) or not surface:
        die(f"Surface missing or empty: {surface_id}")
    backup_root = target_repo / "workspace" / "archived" / "phase-experiments" / f"{manifest['run_id']}_{surface_id}"
    copied_paths = []
    for artifact in surface:
        source_path = Path(str(artifact.get("source_path") or ""))
        if not source_path.is_absolute():
            source_path = manifest_repo_root / source_path
        logical_path = artifact.get("logical_path")
        if artifact.get("exists") and not source_path.exists():
            die(f"Fixture artifact missing on disk: {source_path}")
        if not source_path.exists() or not logical_path:
            continue
        target_path = target_repo / logical_path
        if target_path.exists():
            backup_path = backup_root / logical_path
            backup_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target_path, backup_path)
        target_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_path, target_path)
        copied_paths.append(str(target_path))
    return copied_paths


def append_log(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(text)
        if text and not text.endswith("\n"):
            handle.write("\n")


def run_logged(cmd: list[str], *, cwd: Path, env: dict[str, str], log_file: Path) -> int:
    append_log(log_file, f"$ {' '.join(cmd)}\n")
    completed = subprocess.run(cmd, cwd=cwd, env=env, text=True, capture_output=True, check=False)
    append_log(log_file, completed.stdout)
    append_log(log_file, completed.stderr)
    return completed.returncode


def run_phase3_signature_scan(*, target_repo: Path, log_paths: list[Path], env: dict[str, str], log_file: Path) -> int:
    rel_paths = [path_for_copilot_phase(path, target_repo) for path in log_paths]
    cmd = ["python3", "tools/scan_phase3_log_signatures.py", *rel_paths]
    append_log(log_file, f"$ {' '.join(cmd)}\n")
    completed = subprocess.run(cmd, cwd=target_repo, env=env, text=True, capture_output=True, check=False)
    append_log(log_file, completed.stdout)
    append_log(log_file, completed.stderr)
    if completed.returncode != 0:
        append_log(log_file, f"Phase 3 log signature scan failed with return code {completed.returncode}\n")
        return completed.returncode
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError:
        append_log(log_file, "Phase 3 log signature scan produced invalid JSON\n")
        return 2
    if payload.get("has_intermediate_scaffold_validator_failure"):
        append_log(log_file, "Phase 3 log signature scan found an intermediate scaffold validator failure; stopping before final validation.\n")
        return 65
    return 0


def path_for_copilot_phase(path: Path, target_repo: Path) -> str:
    """Use repo-relative paths when possible, otherwise pass absolute paths."""
    resolved = path.resolve()
    try:
        return str(resolved.relative_to(target_repo))
    except ValueError:
        return str(resolved)


def env_flag_enabled(env: dict[str, str], key: str) -> bool:
    return str(env.get(key) or "").strip().lower() in {"1", "true", "yes", "on"}


def prune_phase3_and_later_receipts(target_repo: Path, end: str, log_file: Path) -> int:
    receipts_path = target_repo / "workspace" / f"newsletter_phase_receipts_{end}.json"
    if not receipts_path.exists():
        append_log(log_file, f"No receipts file to prune: {receipts_path}\n")
        return 0
    payload = load_json(receipts_path)
    receipts = payload.get("receipts") if isinstance(payload, dict) else None
    if not isinstance(receipts, list):
        die(f"Invalid receipts file: {receipts_path}")
    pruned_prefixes = ("phase3", "phase4", "phase5")
    kept = [
        row
        for row in receipts
        if not str(row.get("phase_id") or "").startswith(pruned_prefixes)
    ]
    removed = len(receipts) - len(kept)
    if not removed:
        append_log(log_file, f"Pruned 0 phase3+ receipts from {receipts_path}\n")
        return 0
    for index, row in enumerate(sorted(kept, key=lambda item: int(item.get("receipt_order", 0) or 0)), start=1):
        row["receipt_order"] = index
    payload["receipts"] = kept
    payload["updated_at_utc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    receipts_path.write_text(json_dumps(payload), encoding="utf-8")
    append_log(log_file, f"Pruned {removed} phase3+ receipts from {receipts_path}\n")
    return removed


def refresh_phase_experiment_provenance(target_repo: Path, start: str, end: str, run_id: str, model: str, log_file: Path) -> None:
    workspace = target_repo / "workspace"
    marker_path = workspace / f"newsletter_run_marker_{start}_to_{end}.json"
    receipts_path = workspace / f"newsletter_phase_receipts_{end}.json"
    now = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    source_run_id = ""
    if marker_path.exists():
        marker_payload = load_json(marker_path)
        if isinstance(marker_payload, dict):
            source_run_id = str(marker_payload.get("run_id") or "")
    marker_payload = {
        "marker_version": 2,
        "run_id": run_id,
        "start": start,
        "end": end,
        "prepared_at_utc": now,
        "prepared_at_epoch": int(time.time()),
        "phase_experiment": "phase3-curation",
        "model": model,
    }
    if source_run_id and source_run_id != run_id:
        marker_payload["source_fixture_run_id"] = source_run_id
    marker_path.parent.mkdir(parents=True, exist_ok=True)
    marker_path.write_text(json_dumps(marker_payload), encoding="utf-8")
    append_log(log_file, f"Refreshed Phase 3 experiment run marker: {marker_path} run_id={run_id}\n")

    if not receipts_path.exists():
        return
    receipts_payload = load_json(receipts_path)
    if not isinstance(receipts_payload, dict):
        die(f"Invalid receipts file: {receipts_path}")
    previous_receipts_run_id = str(receipts_payload.get("run_id") or "")
    if previous_receipts_run_id and previous_receipts_run_id != run_id:
        receipts_payload["source_fixture_run_id"] = previous_receipts_run_id
    receipts_payload["run_id"] = run_id
    receipts_payload["start"] = start
    receipts_payload["end"] = end
    for receipt in receipts_payload.get("receipts", []) or []:
        if not isinstance(receipt, dict):
            continue
        previous = str(receipt.get("run_id") or "")
        if previous and previous != run_id:
            receipt["source_fixture_run_id"] = previous
        receipt["run_id"] = run_id
    receipts_payload["updated_at_utc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    receipts_path.write_text(json_dumps(receipts_payload), encoding="utf-8")
    append_log(log_file, f"Rebound copied Phase 3 receipts to run_id={run_id}: {receipts_path}\n")


def json_dumps(payload: Any) -> str:
    import json

    return json.dumps(payload, indent=2) + "\n"


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def resolve_repo_path(path_text: str, target_repo: Path) -> Path:
    path = Path(path_text).expanduser()
    if path.is_absolute():
        return path.resolve()
    return (target_repo / path).resolve()


def load_phase3_prompt_policy(path_text: str, target_repo: Path) -> tuple[dict[str, Any], Path] | tuple[None, None]:
    if not path_text:
        return None, None
    policy_path = resolve_repo_path(path_text, target_repo)
    if not policy_path.is_file():
        die(f"Phase 3 prompt policy not found: {policy_path}")
    payload = load_json(policy_path)
    if not isinstance(payload, dict):
        die(f"Invalid Phase 3 prompt policy JSON: {policy_path}")
    policy_id = str(payload.get("policy_id") or "").strip()
    prompt_append = payload.get("prompt_append")
    if not policy_id:
        die(f"Phase 3 prompt policy missing policy_id: {policy_path}")
    if not isinstance(prompt_append, (str, list)):
        die(f"Phase 3 prompt policy missing prompt_append string/list: {policy_path}")
    if isinstance(prompt_append, list) and not all(isinstance(item, str) for item in prompt_append):
        die(f"Phase 3 prompt policy prompt_append list must contain strings only: {policy_path}")
    if not prompt_policy_text(payload):
        die(f"Phase 3 prompt policy prompt_append is empty after normalization: {policy_path}")
    return payload, policy_path


def prompt_policy_text(policy: dict[str, Any] | None) -> str:
    if not policy:
        return ""
    prompt_append = policy.get("prompt_append")
    if isinstance(prompt_append, list):
        return "\n".join(item.rstrip() for item in prompt_append).strip()
    return str(prompt_append or "").strip()


def write_phase3_prompt_metadata(
    *,
    run_dir: Path,
    base_prompt: str,
    full_prompt: str,
    policy: dict[str, Any] | None,
    policy_path: Path | None,
) -> Path:
    metadata_path = run_dir / "prompt-metadata" / "phase3_prompt_metadata.json"
    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema_version": "1.0.0",
        "receipt_type": "phase3_prompt_policy_metadata",
        "base_prompt_sha256": sha256_text(base_prompt),
        "full_prompt_sha256": sha256_text(full_prompt),
        "policy_enabled": policy is not None,
        "policy_id": policy.get("policy_id") if policy else None,
        "policy_path": str(policy_path) if policy_path else None,
        "policy_sha256": sha256_file(policy_path) if policy_path else None,
        "non_claims": [
            "This prompt policy is evidence-only and does not change production behavior.",
            "This metadata admits prompt-policy binding only; it is not a savings claim.",
        ],
    }
    metadata_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return metadata_path


def backup_and_remove(path: Path, backup_root: Path) -> None:
    if not path.exists():
        return
    try:
        relative = path.relative_to(path.parents[1])
    except ValueError:
        relative = Path(path.name)
    backup_path = backup_root / relative
    backup_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, backup_path)
    path.unlink()


def run_phase3_curation(args: argparse.Namespace, manifest: dict[str, Any]) -> int:
    target_repo = Path(args.target_repo).expanduser().resolve()
    if args.phase_timeout_seconds > 900:
        die("phase3-curation timeout must be <= 900 seconds")
    env = os.environ.copy()
    env["COPILOT_BIN"] = resolve_copilot_bin(env)
    if not Path(env["COPILOT_BIN"]).exists():
        die(f"copilot CLI not found: {env['COPILOT_BIN']}")
    if not args.skip_materialize:
        materialize_surface(manifest, args.surface_id, str(target_repo))
    start = str(manifest["start"])
    end = str(manifest["end"])
    mode = str(manifest.get("mode") or "")
    env["MODEL"] = args.model
    if args.benchmark_mode:
        env["BENCHMARK_MODE"] = args.benchmark_mode

    run_id = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    run_dir = Path(args.run_dir_override).expanduser() if args.run_dir_override else target_repo / "runs" / "phase3-experiments" / f"{run_id}_{start}_to_{end}"
    if not run_dir.is_absolute():
        run_dir = target_repo / run_dir
    run_dir = run_dir.resolve()
    prompt_dir = run_dir / "prompts"
    log_dir = run_dir / "logs"
    session_dir = run_dir / "session"
    prompt_dir.mkdir(parents=True, exist_ok=True)
    log_dir.mkdir(parents=True, exist_ok=True)
    session_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / "phase3_curation.log"
    refresh_phase_experiment_provenance(target_repo, start, end, run_id, args.model, log_file)
    prune_phase3_and_later_receipts(target_repo, end, log_file)

    working_set = target_repo / "workspace" / f"newsletter_phase3_working_set_{end}.md"
    curated = target_repo / "workspace" / f"newsletter_phase3_curated_sections_{end}.md"
    backup_root = run_dir / "backups"
    backup_and_remove(working_set, backup_root)
    backup_and_remove(curated, backup_root)

    build_cmd = ["python3", "tools/build_phase3_working_set.py", start, end]
    init_cmd = ["python3", "tools/init_phase3_curated_sections.py", start, end]
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
        build_cmd.extend(["--benchmark-mode", args.benchmark_mode])
        init_cmd.extend(["--benchmark-mode", args.benchmark_mode])
        validate_cmd.extend(["--benchmark-mode", args.benchmark_mode])

    build_rc = run_logged(build_cmd, cwd=target_repo, env=env, log_file=log_file)
    if build_rc != 0:
        write_phase3_summary(
            run_dir,
            run_id,
            start,
            end,
            args.model,
            build_rc,
            None,
            None,
            None,
            None,
            None,
            None,
            log_file,
            copilot_agent_mode=args.copilot_agent_mode,
            mode=mode,
        )
        return build_rc

    receipt_working_rc = run_logged(
        ["bash", "tools/record_phase_receipt.sh", start, end, "phase3_working_set", str(working_set.relative_to(target_repo))],
        cwd=target_repo,
        env=env,
        log_file=log_file,
    )
    if receipt_working_rc != 0:
        write_phase3_summary(
            run_dir,
            run_id,
            start,
            end,
            args.model,
            build_rc,
            receipt_working_rc,
            None,
            None,
            None,
            None,
            None,
            log_file,
            copilot_agent_mode=args.copilot_agent_mode,
            mode=mode,
        )
        return receipt_working_rc

    init_rc = run_logged(init_cmd, cwd=target_repo, env=env, log_file=log_file)
    if init_rc != 0:
        write_phase3_summary(
            run_dir,
            run_id,
            start,
            end,
            args.model,
            build_rc,
            receipt_working_rc,
            init_rc,
            None,
            None,
            None,
            None,
            log_file,
            copilot_agent_mode=args.copilot_agent_mode,
            mode=mode,
        )
        return init_rc

    prompt_file = prompt_dir / "phase3_curation.prompt.md"
    base_prompt = f"""@customer_newsletter
Run only bounded Phase 3 curation for DATE_RANGE {start} to {end}.

Inputs:
- workspace/newsletter_phase3_working_set_{end}.md
- workspace/newsletter_phase3_curated_sections_{end}.md

Do not run phases 0-2 or Phase 4. Do not run the product proof wrapper. Do not edit receipts manually.
Treat the working set as read-only after reading it. Edit only the curated sections artifact unless a source line explicitly contains [MISSING_DATA].
Read the working set first, then edit the curated sections artifact in place until it has no TODO markers and satisfies the Phase 3 validator.
Do not run the validator against the scaffold or known-placeholder content as a baseline; an intermediate validator failure is a lane-stop signal.
Run this validator before stopping:
{' '.join(validate_cmd)}

Stop after the curated artifact is valid. The wrapper will record the phase3_curated receipt after validation.
"""
    policy, policy_path = load_phase3_prompt_policy(args.phase3_prompt_policy, target_repo)
    policy_append = prompt_policy_text(policy)
    full_prompt = base_prompt
    if policy_append:
        full_prompt += (
            "\nEvidence-only model-routing request/tool budget policy "
            f"({policy['policy_id']}):\n{policy_append}\n"
        )
    prompt_metadata_path = write_phase3_prompt_metadata(
        run_dir=run_dir,
        base_prompt=base_prompt,
        full_prompt=full_prompt,
        policy=policy,
        policy_path=policy_path,
    )
    append_log(log_file, f"Phase 3 prompt metadata: {prompt_metadata_path}\n")
    prompt_file.write_text(full_prompt, encoding="utf-8")

    copilot_log_file = log_dir / "phase3_copilot.log"
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
        path_for_copilot_phase(copilot_log_file, target_repo),
        "--timeout",
        str(args.phase_timeout_seconds),
        "--cwd",
        str(target_repo),
        "--phase-id",
        "phase3_curation",
        "--session-out",
        path_for_copilot_phase(session_dir / "events.jsonl", target_repo),
        "--metrics-out",
        path_for_copilot_phase(session_dir / "phase-session-metrics.jsonl", target_repo),
        "--artifact-path",
        str(curated.relative_to(target_repo)),
        "--receipt-id",
        "phase3_curated",
    ]
    if args.copilot_agent_mode == "agent-flag":
        phase_cmd[2:2] = ["--agent", "customer_newsletter"]
    if env_flag_enabled(env, "PHASE_REQUIRE_SESSION_LOG"):
        phase_cmd.append("--require-session-log")
    if env_flag_enabled(env, "PHASE_REQUIRE_DIRECT_TOKEN_FIELDS"):
        phase_cmd.append("--require-direct-token-fields")
    phase_rc = run_logged(phase_cmd, cwd=target_repo, env=env, log_file=log_file)
    if phase_rc != 0:
        write_phase3_summary(
            run_dir,
            run_id,
            start,
            end,
            args.model,
            build_rc,
            receipt_working_rc,
            init_rc,
            phase_rc,
            None,
            None,
            None,
            log_file,
            copilot_agent_mode=args.copilot_agent_mode,
            mode=mode,
        )
        return phase_rc

    signature_scan_rc = run_phase3_signature_scan(target_repo=target_repo, log_paths=[copilot_log_file], env=env, log_file=log_file)
    if signature_scan_rc != 0:
        write_phase3_summary(
            run_dir,
            run_id,
            start,
            end,
            args.model,
            build_rc,
            receipt_working_rc,
            init_rc,
            phase_rc,
            signature_scan_rc,
            None,
            None,
            log_file,
            copilot_agent_mode=args.copilot_agent_mode,
            mode=mode,
        )
        return signature_scan_rc

    validate_rc = run_logged(validate_cmd, cwd=target_repo, env=env, log_file=log_file)
    if validate_rc != 0:
        write_phase3_summary(
            run_dir,
            run_id,
            start,
            end,
            args.model,
            build_rc,
            receipt_working_rc,
            init_rc,
            phase_rc,
            signature_scan_rc,
            validate_rc,
            None,
            log_file,
            copilot_agent_mode=args.copilot_agent_mode,
            mode=mode,
        )
        return validate_rc

    receipt_curated_rc = run_logged(
        ["bash", "tools/record_phase_receipt.sh", start, end, "phase3_curated", str(curated.relative_to(target_repo))],
        cwd=target_repo,
        env=env,
        log_file=log_file,
    )
    write_phase3_summary(
        run_dir,
        run_id,
        start,
        end,
        args.model,
        build_rc,
        receipt_working_rc,
        init_rc,
        phase_rc,
        signature_scan_rc,
        validate_rc,
        receipt_curated_rc,
        log_file,
        copilot_agent_mode=args.copilot_agent_mode,
        mode=mode,
    )
    return receipt_curated_rc


def write_phase3_summary(
    run_dir: Path,
    run_id: str,
    start: str,
    end: str,
    model: str,
    build_rc: int | None,
    receipt_working_rc: int | None,
    init_rc: int | None,
    phase_rc: int | None,
    signature_scan_rc: int | None,
    validate_rc: int | None,
    receipt_curated_rc: int | None,
    log_file: Path,
    *,
    copilot_agent_mode: str = "unknown",
    mode: str = "",
) -> None:
    codes = [build_rc, receipt_working_rc, init_rc, phase_rc, signature_scan_rc, validate_rc, receipt_curated_rc]
    known_codes = [code for code in codes if code is not None]
    overall_return_code = next((code for code in known_codes if code != 0), 0 if all(code == 0 for code in codes) else None)
    final_status = "pass" if overall_return_code == 0 else "fail"
    summary = run_dir / "summary.md"
    summary.parent.mkdir(parents=True, exist_ok=True)
    summary.write_text(
        f"""# Phase 3 Curation Experiment Summary
- Run ID: {run_id}
- Date Range: {start} to {end}
- Mode: {mode}
- Model: {model}
- Copilot Agent Mode: {copilot_agent_mode}
- Build Return Code: {build_rc}
- Working Set Receipt Return Code: {receipt_working_rc}
- Init Return Code: {init_rc}
- Phase Return Code: {phase_rc}
- Signature Scan Return Code: {signature_scan_rc}
- Validation Return Code: {validate_rc}
- Curated Receipt Return Code: {receipt_curated_rc}
- Overall Return Code: {overall_return_code}
- Final Status: {final_status}
- Log: {log_file}
""",
        encoding="utf-8",
    )


def main() -> int:
    args = parse_args()
    manifest = load_manifest(args.manifest)

    if args.command == "inventory":
        for surface_id, artifacts in sorted((manifest.get("surfaces") or {}).items()):
            print(f"{surface_id}: {len(artifacts)} artifacts")
        return 0

    if args.command == "materialize":
        copied = materialize_surface(manifest, args.surface_id, args.target_repo)
        for path in copied:
            print(path)
        return 0

    if args.command == "phase4-fast":
        materialize_surface(manifest, args.surface_id, args.target_repo)
        env = os.environ.copy()
        env["COPILOT_BIN"] = resolve_copilot_bin(env)
        env["MODEL"] = args.model
        if args.benchmark_mode:
            env["BENCHMARK_MODE"] = args.benchmark_mode
        if args.run_dir_override:
            env["RUN_DIR_OVERRIDE"] = args.run_dir_override
        completed = subprocess.run(
            ["bash", "tools/run_newsletter_phase4_fast.sh", manifest["start"], manifest["end"]],
            cwd=Path(args.target_repo).expanduser().resolve(),
            env=env,
            check=False,
        )
        return completed.returncode

    if args.command == "phase3-curation":
        return run_phase3_curation(args, manifest)

    die(f"Unsupported command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())

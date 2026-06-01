#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

python3 -m py_compile \
  tools/run_copilot_phase.py \
  tools/run_phase3_stdout_no_tools_artifact_reuse.py \
  tools/build_artifact_reuse_stdout_no_tools_receipt.py

python3 - "$tmpdir" <<'PY'
import hashlib
import json
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1])
END = "2026-02-13"
PROMPT_SHA = "a" * 64
POLICY_SHA = "b" * 64
SOURCE_PACK_SHA = "c" * 64
ARTIFACT = "# Copilot\n\n## Latest Releases\n\n- Item 1\n"
FIELDS = ["inputTokens", "outputTokens", "cacheReadTokens", "cacheWriteTokens", "reasoningTokens"]


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metric(run_dir, phase_id, request_count, tool_calls=0, status="bound_candidate", missing_fields=None):
    session_dir = run_dir / "session"
    session_dir.mkdir(parents=True, exist_ok=True)
    events = session_dir / "events.jsonl"
    rows = []
    if tool_calls:
        rows.append({"type": "tool.execution_start", "data": {"toolName": "bash"}})
    rows.append({"type": "session.shutdown", "data": {"currentModel": "gpt-5.5"}})
    events.write_text("\n".join(json.dumps(row) for row in rows) + "\n", encoding="utf-8")
    missing = missing_fields or []
    present = [field for field in FIELDS if field not in missing]
    row = {
        "phase_id": phase_id,
        "model": "gpt-5.5",
        "exit_code": 0,
        "original_prompt_sha256": PROMPT_SHA,
        "prompt_sha256": "d" * 64,
        "session_log_path": str(events),
        "session_log_detection": {
            "status": status,
            "bound_candidate_count": 1 if status == "bound_candidate" else 0,
            "candidate_count": 1 if status != "ambiguous_candidates" else 2,
        },
        "direct_provider_token_fields_present": present,
        "missing_direct_provider_token_fields": missing,
        "tool_filters": {"available_tools": [], "excluded_tools": ["bash", "web_fetch"]},
        "artifact_paths": ["stdout/phase3_curated_candidate.md"],
        "receipt_ids": ["phase3_stdout_no_tools"],
        "token_usage": {
            "source": "session.shutdown.modelMetrics",
            "input_tokens": 800 if phase_id.startswith("phase3_stdout") else 1000,
            "output_tokens": 90,
            "cache_read_tokens": 0,
            "cache_write_tokens": 0,
            "reasoning_tokens": 10,
            "request_count": request_count,
            "tool_calls": tool_calls,
        },
    }
    (session_dir / "phase-session-metrics.jsonl").write_text(json.dumps(row, sort_keys=True) + "\n", encoding="utf-8")


def mutate_metric_model(run_dir, model):
    path = run_dir / "session" / "phase-session-metrics.jsonl"
    row = json.loads(path.read_text(encoding="utf-8").splitlines()[-1])
    row["model"] = model
    row["token_usage"]["primary_model"] = model
    path.write_text(json.dumps(row, sort_keys=True) + "\n", encoding="utf-8")


def mutate_metric_input_tokens(run_dir, input_tokens):
    path = run_dir / "session" / "phase-session-metrics.jsonl"
    row = json.loads(path.read_text(encoding="utf-8").splitlines()[-1])
    row["token_usage"]["input_tokens"] = input_tokens
    if "model_breakdown" in row["token_usage"]:
        row["token_usage"]["model_breakdown"]["gpt-5.5"]["input_tokens"] = input_tokens
    path.write_text(json.dumps(row, sort_keys=True) + "\n", encoding="utf-8")


def summary(run_dir, title, mode="benchmark"):
    run_dir.mkdir(parents=True, exist_ok=True)
    (run_dir / "summary.md").write_text(
        f"""# {title}
- Run ID: fixture
- Date Range: 2025-12-05 to {END}
- Mode: {mode}
- Model: gpt-5.5
- Phase Return Code: 0
- Validation Return Code: 0
- Curated Receipt Return Code: 0
- Materialization Return Code: 0
- Overall Return Code: 0
- Final Status: pass
""",
        encoding="utf-8",
    )


def no_refetch(repo, admission_path, tamper=False):
    workspace = repo / "workspace"
    workspace.mkdir(parents=True, exist_ok=True)
    selected = {
        "selected_source_ids": [{"source_id": "https://example.test/event-a"}],
        "source_pack_sha256": SOURCE_PACK_SHA,
        "selection_manifest_sha256": "s" * 64,
        "event_sources_sha256": "e" * 64,
    }
    fetch = {
        "network_access_permitted": False,
        "fetch_attempt_count": 1 if tamper else 0,
        "fetch_attempts": [{"url": "https://example.test/refetch"}] if tamper else [],
        "source_pack_sha256": SOURCE_PACK_SHA,
        "selection_manifest_sha256": "s" * 64,
        "event_sources_sha256": "e" * 64,
    }
    selected_path = workspace / f"newsletter_phase2_selected_source_ids_{END}.json"
    fetch_path = workspace / f"newsletter_phase2_fetch_attempt_ledger_{END}.json"
    write_json(selected_path, selected)
    write_json(fetch_path, fetch)
    compliance = {
        "compliance": "pass",
        "network_access_permitted": False,
        "fetch_attempt_count": 0,
        "source_pack_sha256": SOURCE_PACK_SHA,
        "selection_manifest_sha256": "s" * 64,
        "event_sources_sha256": "e" * 64,
        "selected_source_ids_sha256": sha(selected_path),
        "fetch_attempt_ledger_sha256": sha(fetch_path),
    }
    write_json(workspace / f"newsletter_phase2_no_refetch_compliance_{END}.json", compliance)
    write_json(
        admission_path,
        {
            "admission_verdict": "admit_no_refetch",
            "no_refetch_compliance": "pass",
            "blockers": [],
            "selected_source_count": 1,
            "selected_source_ids": selected["selected_source_ids"],
            "source_pack_sha256": SOURCE_PACK_SHA,
            "renderer_or_prompt_hash": "r" * 64,
            "selection_manifest_sha256": "s" * 64,
            "event_sources_sha256": "e" * 64,
            "generated_artifacts": {
                "phase2_selected_source_ids": {"sha256": sha(selected_path)},
                "phase2_fetch_attempt_ledger": {"sha256": sha(fetch_path)},
                "phase2_no_refetch_compliance": {
                    "sha256": sha(workspace / f"newsletter_phase2_no_refetch_compliance_{END}.json")
                },
            },
        },
    )


def case(name, mutate=None):
    base = root / name
    control_run = base / "control-run"
    candidate_run = base / "candidate-run"
    control_repo = base / "control-repo"
    candidate_repo = base / "candidate-repo"
    summary(control_run, "Phase 3 Curation Experiment Summary")
    summary(candidate_run, "Phase 3 Stdout/No-Tools Artifact-Reuse Summary")
    metric(control_run, "phase3_curation", 5, tool_calls=2)
    metric(candidate_run, "phase3_stdout_no_tools_artifact_reuse", 4)

    stdout = candidate_run / "stdout" / "phase3_curated_candidate.md"
    stdout.parent.mkdir(parents=True, exist_ok=True)
    stdout.write_text(ARTIFACT, encoding="utf-8")
    materialized = candidate_repo / "workspace" / f"newsletter_phase3_curated_sections_{END}.md"
    materialized.parent.mkdir(parents=True, exist_ok=True)
    materialized.write_text(ARTIFACT, encoding="utf-8")
    validation = candidate_run / "validation" / "phase3_stdout_validation.txt"
    write_json(
        validation,
        {
            "exit_code": 0,
            "validated_artifact_path": str(stdout),
            "validated_artifact_sha256": sha(stdout),
        },
    )
    prompt_metadata = candidate_run / "prompt-metadata" / "phase3_stdout_no_tools_prompt_metadata.json"
    write_json(prompt_metadata, {"policy_sha256": POLICY_SHA})
    admission = base / "admission.json"
    no_refetch(candidate_repo, admission)
    materialization_sidecars = {}
    for name in [
        "phase2_selected_source_ids",
        "phase2_fetch_attempt_ledger",
        "phase2_no_refetch_compliance",
    ]:
        filename = {
            "phase2_selected_source_ids": f"newsletter_phase2_selected_source_ids_{END}.json",
            "phase2_fetch_attempt_ledger": f"newsletter_phase2_fetch_attempt_ledger_{END}.json",
            "phase2_no_refetch_compliance": f"newsletter_phase2_no_refetch_compliance_{END}.json",
        }[name]
        path = candidate_repo / "workspace" / filename
        materialization_sidecars[name] = {
            "source_path": str(path),
            "source_sha256": sha(path),
            "destination_path": str(path),
            "sha256": sha(path),
        }
    run_metadata = {
        "run_id": "fixture",
        "start": "2025-12-05",
        "end": END,
        "mode": "benchmark",
        "model": "gpt-5.5",
        "prompt_metadata_path": str(prompt_metadata),
        "prompt_metadata_sha256": sha(prompt_metadata),
        "stdout_artifact_path": str(stdout),
        "stdout_artifact_sha256": sha(stdout),
        "materialized_artifact_path": str(materialized),
        "materialized_artifact_sha256": sha(materialized),
        "validation_result_path": str(validation),
        "validation_result_sha256": sha(validation),
        "no_refetch_sidecar_materialization": {
            "materialized_at_utc": "2026-05-08T00:00:00Z",
            "admission_path": str(admission),
            "admission_sha256": sha(admission),
            "sidecars": materialization_sidecars,
        },
    }
    write_json(candidate_run / "run-metadata.json", run_metadata)
    write_json(base / "manifest.json", {"manifest_id": "fixture-pack", "start": "2025-12-05", "end": END, "mode": "benchmark"})

    if mutate == "missing_stdout":
        stdout.unlink()
    elif mutate == "tool_call":
        metric(candidate_run, "phase3_stdout_no_tools_artifact_reuse", 4, tool_calls=1)
    elif mutate == "ambiguous_session":
        metric(candidate_run, "phase3_stdout_no_tools_artifact_reuse", 4, status="ambiguous_candidates")
    elif mutate == "missing_session":
        metric(candidate_run, "phase3_stdout_no_tools_artifact_reuse", 4, status="no_candidates")
    elif mutate == "missing_direct_fields":
        metric(candidate_run, "phase3_stdout_no_tools_artifact_reuse", 4, missing_fields=["inputTokens"])
    elif mutate == "wrong_candidate_phase":
        metric(candidate_run, "phase3_curation", 4)
    elif mutate == "wrong_control_phase":
        metric(control_run, "phase3_stdout_no_tools_artifact_reuse", 5, tool_calls=2)
    elif mutate == "missing_candidate_summary":
        (candidate_run / "summary.md").unlink()
    elif mutate == "missing_control_summary":
        (control_run / "summary.md").unlink()
    elif mutate == "no_refetch_tamper":
        no_refetch(candidate_repo, admission, tamper=True)
    elif mutate == "sidecar_hash_gap":
        payload = json.loads(admission.read_text(encoding="utf-8"))
        del payload["generated_artifacts"]["phase2_selected_source_ids"]["sha256"]
        write_json(admission, payload)
    elif mutate == "sidecar_hash_mismatch":
        payload = json.loads(admission.read_text(encoding="utf-8"))
        payload["generated_artifacts"]["phase2_selected_source_ids"]["sha256"] = "0" * 64
        write_json(admission, payload)
    elif mutate == "mode_mismatch":
        summary(control_run, "Phase 3 Curation Experiment Summary", mode="production")
    elif mutate == "date_mismatch":
        text = (candidate_run / "summary.md").read_text(encoding="utf-8")
        (candidate_run / "summary.md").write_text(text.replace("2025-12-05 to 2026-02-13", "2025-12-06 to 2026-02-13"), encoding="utf-8")
    elif mutate == "model_mismatch":
        mutate_metric_model(candidate_run, "gpt-5.4")
    elif mutate == "token_amplification":
        mutate_metric_input_tokens(candidate_run, 2000)
    elif mutate == "artifact_mismatch":
        materialized.write_text(ARTIFACT + "\n- Different materialization\n", encoding="utf-8")
    elif mutate == "validator_gap":
        payload = json.loads(validation.read_text(encoding="utf-8"))
        payload["validated_artifact_sha256"] = "0" * 64
        write_json(validation, payload)
    elif mutate == "missing_sidecar_materialization":
        payload = json.loads((candidate_run / "run-metadata.json").read_text(encoding="utf-8"))
        del payload["no_refetch_sidecar_materialization"]
        write_json(candidate_run / "run-metadata.json", payload)
    elif mutate == "control_contamination":
        (control_repo / "workspace").mkdir(parents=True, exist_ok=True)
        shutil.copy2(candidate_repo / "workspace" / f"newsletter_phase2_selected_source_ids_{END}.json", control_repo / "workspace" / f"newsletter_phase2_selected_source_ids_{END}.json")


for name in [
    "pass",
    "missing_stdout",
    "tool_call",
    "ambiguous_session",
    "missing_session",
    "missing_direct_fields",
    "wrong_candidate_phase",
    "wrong_control_phase",
    "missing_candidate_summary",
    "missing_control_summary",
    "wrong_prompt",
    "wrong_policy",
    "wrong_source",
    "no_refetch_tamper",
    "sidecar_hash_gap",
    "sidecar_hash_mismatch",
    "mode_mismatch",
    "date_mismatch",
    "model_mismatch",
    "token_amplification",
    "artifact_mismatch",
    "validator_gap",
    "missing_sidecar_materialization",
    "control_contamination",
]:
    case(name, None if name in {"pass", "wrong_prompt", "wrong_policy", "wrong_source"} else name)

write_json(root / "constants.json", {"prompt": PROMPT_SHA, "policy": POLICY_SHA, "source": SOURCE_PACK_SHA})
PY

python3 - "$tmpdir" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, "tools")
from run_phase3_stdout_no_tools_artifact_reuse import extract_candidate_stdout, materialize_no_refetch_sidecars

raw = """
{"type":"session.skills_loaded","data":{"skills":[]}}
{"type":"assistant.message","data":{"content":"# Copilot\\n\\n## Latest Releases\\n\\n- Item\\n"}}
{"type":"result","exitCode":0}
"""
assert extract_candidate_stdout(raw).startswith("# Copilot")
assert "session.skills_loaded" not in extract_candidate_stdout(raw)
assert extract_candidate_stdout("```markdown\n# Copilot\n```") == "# Copilot\n"

root = Path(sys.argv[1])
sidecar_src = root / "sidecar-src"
sidecar_src.mkdir(parents=True, exist_ok=True)
target_repo = root / "sidecar-target"
log_file = root / "sidecar.log"
end = "2026-02-13"
filenames = {
    "phase2_selected_source_ids": f"newsletter_phase2_selected_source_ids_{end}.json",
    "phase2_fetch_attempt_ledger": f"newsletter_phase2_fetch_attempt_ledger_{end}.json",
    "phase2_no_refetch_compliance": f"newsletter_phase2_no_refetch_compliance_{end}.json",
}

generated = {}
for name, filename in filenames.items():
    path = sidecar_src / filename
    path.write_text(json.dumps({"artifact_kind": name}, sort_keys=True) + "\n", encoding="utf-8")
    generated[name] = {
        "path": str(path),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }
admission = root / "no-refetch-admission.json"
admission.write_text(json.dumps({"generated_artifacts": generated}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
admission_payload = json.loads(admission.read_text(encoding="utf-8"))
admission_payload["admission_verdict"] = "admit_no_refetch"
admission_payload["no_refetch_compliance"] = "pass"
admission_payload["blockers"] = []
admission.write_text(json.dumps(admission_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
copied = materialize_no_refetch_sidecars(admission, target_repo, end, log_file)
assert set(copied["sidecars"]) == set(filenames)
for name, filename in filenames.items():
    dest = target_repo / "workspace" / filename
    assert dest.exists()
    assert hashlib.sha256(dest.read_bytes()).hexdigest() == generated[name]["sha256"]

missing_hash = json.loads(admission.read_text(encoding="utf-8"))
del missing_hash["generated_artifacts"]["phase2_selected_source_ids"]["sha256"]
admission.write_text(json.dumps(missing_hash, indent=2, sort_keys=True) + "\n", encoding="utf-8")
try:
    materialize_no_refetch_sidecars(admission, target_repo, end, log_file)
except SystemExit as exc:
    assert "lacks valid sha256" in str(exc)
else:
    raise AssertionError("expected missing sidecar sha256 to fail closed")

blocked = json.loads(admission.read_text(encoding="utf-8"))
blocked["generated_artifacts"]["phase2_selected_source_ids"]["sha256"] = generated["phase2_selected_source_ids"]["sha256"]
blocked["admission_verdict"] = "blocked"
admission.write_text(json.dumps(blocked, indent=2, sort_keys=True) + "\n", encoding="utf-8")
try:
    materialize_no_refetch_sidecars(admission, target_repo, end, log_file)
except SystemExit as exc:
    assert "verdict is not admit_no_refetch" in str(exc)
else:
    raise AssertionError("expected blocked no-refetch admission to fail closed")
PY

if python3 tools/run_phase3_stdout_no_tools_artifact_reuse.py \
    --manifest "$tmpdir/pass/manifest.json" \
    --target-repo "$tmpdir/pass/candidate-repo" \
    --skip-materialize \
    --run-dir-override "$tmpdir/no-filter-run" 2>"$tmpdir/no-filter.err"; then
  echo "Expected stdout/no-tools runner to require explicit tool filters"
  exit 1
fi
grep -q "requires explicit Copilot tool filters" "$tmpdir/no-filter.err"

run_receipt() {
  local name="$1"
  shift || true
  local base="$tmpdir/$name"
  python3 tools/build_artifact_reuse_stdout_no_tools_receipt.py \
    --control-run-dir "$base/control-run" \
    --control-repo "$base/control-repo" \
    --candidate-run-dir "$base/candidate-run" \
    --candidate-repo "$base/candidate-repo" \
    --no-refetch-admission "$base/admission.json" \
    --manifest "$base/manifest.json" \
    --expected-prompt-sha256 "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["prompt"])' "$tmpdir/constants.json")" \
    --expected-prompt-policy-sha256 "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["policy"])' "$tmpdir/constants.json")" \
    --expected-source-pack-sha256 "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["source"])' "$tmpdir/constants.json")" \
    --output "$base/receipt.json" \
    "$@"
}

run_receipt pass

python3 - "$tmpdir/pass/receipt.json" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["admission"]["verdict"] == "admit_single_pair_stdout_no_tools_evidence"
assert payload["admission"]["admitted_for_single_live_phase3_pair"] is True
assert payload["candidate"]["metrics"]["tool_calls"] == 0
assert payload["deltas"]["candidate_request_count_not_higher"] is True
PY

expect_fail() {
  local name="$1"
  shift || true
  if run_receipt "$name" "$@"; then
    echo "Expected $name to fail closed"
    exit 1
  fi
  python3 - "$tmpdir/$name/receipt.json" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["admission"]["verdict"] == "blocked_incomplete_evidence"
assert payload["admission"]["blockers"]
PY
}

expect_fail missing_stdout
expect_fail tool_call
expect_fail ambiguous_session
expect_fail missing_session
expect_fail missing_direct_fields
expect_fail wrong_candidate_phase
expect_fail wrong_control_phase
expect_fail missing_candidate_summary
expect_fail missing_control_summary
expect_fail wrong_prompt --expected-prompt-sha256 "$(printf '0%.0s' {1..64})"
expect_fail wrong_policy --expected-prompt-policy-sha256 "$(printf '0%.0s' {1..64})"
expect_fail wrong_source --expected-source-pack-sha256 "$(printf '0%.0s' {1..64})"
expect_fail no_refetch_tamper
expect_fail sidecar_hash_gap
expect_fail sidecar_hash_mismatch
expect_fail mode_mismatch
expect_fail date_mismatch
expect_fail model_mismatch
expect_fail token_amplification
expect_fail artifact_mismatch
expect_fail validator_gap
expect_fail missing_sidecar_materialization
expect_fail control_contamination

echo "PASS: artifact reuse stdout/no-tools receipt"

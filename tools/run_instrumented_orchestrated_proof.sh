#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

usage() {
  cat <<'USAGE'
Usage: bash tools/run_instrumented_orchestrated_proof.sh <START> <END> <benchmark|production> [--run-dir DIR]

Runs the diagnostic phase-by-phase Copilot workflow with per-phase telemetry
enabled, then packages the result as a retained product proof run.
USAGE
}

if [ "$#" -lt 3 ]; then
  usage
  exit 1
fi

START="$1"
END="$2"
MODE="$3"
shift 3

RUN_DIR=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --run-dir)
      if [ "$#" -lt 2 ]; then
        echo "Error: --run-dir requires a directory"
        exit 1
      fi
      RUN_DIR="$2"
      shift 2
      ;;
    *)
      echo "Error: unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if ! [[ "$START" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: START must be YYYY-MM-DD, got: $START"
  exit 1
fi
if ! [[ "$END" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: END must be YYYY-MM-DD, got: $END"
  exit 1
fi
case "$MODE" in
  benchmark|production) ;;
  *)
    echo "Error: MODE must be benchmark or production, got: $MODE"
    exit 1
    ;;
esac

MODEL="${MODEL:-gpt-5.5}"
EXPERIMENT_ID="${EXPERIMENT_ID:-}"
RUN_CLASS="${RUN_CLASS:-instrumented_orchestrated_proof}"
FIXTURE_PACK="${FIXTURE_PACK:-}"
PRICING_SNAPSHOT="${PRICING_SNAPSHOT:-}"
PHASE_TIMEOUT_SECONDS="${PHASE_TIMEOUT_SECONDS:-1800}"
PHASE_REQUIRE_SESSION_LOG="${PHASE_REQUIRE_SESSION_LOG:-0}"
MAX_RETRIES="${MAX_RETRIES:-1}"
NEWSLETTER_COST_OPT_STACK="${NEWSLETTER_COST_OPT_STACK:-0}"
PHASE3_STDOUT_NO_TOOLS="${PHASE3_STDOUT_NO_TOOLS:-0}"
PHASE3_STDOUT_NO_TOOLS_MANIFEST="${PHASE3_STDOUT_NO_TOOLS_MANIFEST:-}"
PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION="${PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION:-}"
PHASE3_STDOUT_NO_TOOLS_RUN_DIR="${PHASE3_STDOUT_NO_TOOLS_RUN_DIR:-}"
PHASE3_STDOUT_NO_TOOLS_TIMEOUT_SECONDS="${PHASE3_STDOUT_NO_TOOLS_TIMEOUT_SECONDS:-}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
default_run_dir="runs/product_runs/${timestamp}_${MODE}_orchestrated_proof"
RUN_DIR="${RUN_DIR:-$default_run_dir}"
RUN_DIR="$(python3 - "$ROOT" "$RUN_DIR" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
if not run_dir.is_absolute():
    run_dir = root / run_dir
print(run_dir.resolve())
PY
)"

mkdir -p "$RUN_DIR/audit" "$RUN_DIR/session"
orchestrated_dir="$RUN_DIR/orchestrated"
source_snapshot="$RUN_DIR/audit/proof-source-snapshot.before.json"
source_drift_receipt="$RUN_DIR/audit/proof-source-drift-receipt.json"
python3 tools/validate_proof_source_drift.py \
  --repo-root "$ROOT" \
  snapshot \
  --output "$source_snapshot"
prompt_cmd="bash tools/render_product_run_prompt.sh $START $END $MODE"
prompt_path="$RUN_DIR/prompt.txt"
bash tools/render_product_run_prompt.sh "$START" "$END" "$MODE" > "$prompt_path"
prompt_sha256="$(python3 - "$prompt_path" <<'PY'
import hashlib
import sys
from pathlib import Path

print(hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"

benchmark_mode=""
if [ "$MODE" = "benchmark" ] && [ "$START" = "2025-12-05" ] && [ "$END" = "2026-02-13" ]; then
  benchmark_mode="feb2026_consistency"
fi

start_epoch="$(date +%s)"
started_at_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
command_string="NEWSLETTER_COST_OPT_STACK=$NEWSLETTER_COST_OPT_STACK PHASE_TELEMETRY=1 PHASE_REQUIRE_SESSION_LOG=$PHASE_REQUIRE_SESSION_LOG PROOF_SOURCE_GUARD=1 RUN_DIR_OVERRIDE=$orchestrated_dir MODEL=$MODEL MAX_RETRIES=$MAX_RETRIES PHASE_TIMEOUT_SECONDS=$PHASE_TIMEOUT_SECONDS bash tools/run_newsletter_orchestrated.sh $START $END"
if [ -n "$benchmark_mode" ]; then
  command_string="BENCHMARK_MODE=$benchmark_mode $command_string"
fi
if [ "$PHASE3_STDOUT_NO_TOOLS" = "1" ]; then
  phase3_stdout_run_dir="${PHASE3_STDOUT_NO_TOOLS_RUN_DIR:-$orchestrated_dir/phase3-stdout-no-tools}"
  command_string="PHASE3_STDOUT_NO_TOOLS=1 PHASE3_STDOUT_NO_TOOLS_MANIFEST=$PHASE3_STDOUT_NO_TOOLS_MANIFEST PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION=$PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION PHASE3_STDOUT_NO_TOOLS_RUN_DIR=$phase3_stdout_run_dir PHASE3_STDOUT_NO_TOOLS_TIMEOUT_SECONDS=${PHASE3_STDOUT_NO_TOOLS_TIMEOUT_SECONDS:-900} $command_string"
fi

python3 - "$ROOT" "$RUN_DIR/run-metadata.json" "$START" "$END" "$MODE" "$start_epoch" "$started_at_utc" "$command_string" "$MODEL" "$EXPERIMENT_ID" "$RUN_CLASS" "$FIXTURE_PACK" "$prompt_sha256" "$prompt_path" "$prompt_cmd" "$orchestrated_dir" "$PHASE3_STDOUT_NO_TOOLS" "$PHASE3_STDOUT_NO_TOOLS_MANIFEST" "$PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION" "${PHASE3_STDOUT_NO_TOOLS_RUN_DIR:-$orchestrated_dir/phase3-stdout-no-tools}" "${PHASE3_STDOUT_NO_TOOLS_TIMEOUT_SECONDS:-900}" <<'PY'
import json
import shutil
import subprocess
import sys
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
path = Path(sys.argv[2])
start, end, mode = sys.argv[3], sys.argv[4], sys.argv[5]
start_epoch, started_at_utc, command = int(sys.argv[6]), sys.argv[7], sys.argv[8]
model, experiment_id, run_class, fixture_pack = sys.argv[9], sys.argv[10] or None, sys.argv[11], sys.argv[12] or None
prompt_sha256, prompt_path, prompt_cmd, orchestrated_dir = sys.argv[13], sys.argv[14], sys.argv[15], sys.argv[16]
phase3_stdout_enabled = sys.argv[17] == "1"
phase3_stdout_manifest = sys.argv[18] or None
phase3_stdout_no_refetch = sys.argv[19] or None
phase3_stdout_run_dir = sys.argv[20] or None
phase3_stdout_timeout_seconds = int(sys.argv[21])

def run_text(cmd):
    completed = subprocess.run(cmd, cwd=repo_root, text=True, capture_output=True, check=False)
    return completed.stdout.strip() or completed.stderr.strip() or None

def version(binary):
    resolved = shutil.which(binary)
    if not resolved:
        return {"path": None, "version": None}
    output = run_text([resolved, "--version"])
    return {"path": resolved, "version": output.splitlines()[0] if output else None}

git_status = run_text(["git", "status", "--short"]) or ""
payload = {
    "schema_version": 1,
    "start": start,
    "end": end,
    "mode": mode,
    "model": model,
    "start_epoch": start_epoch,
    "started_at_utc": started_at_utc,
    "command": command,
    "command_surface": "copilot_cli_orchestrated_phase_by_phase",
    "experiment_id": experiment_id,
    "run_class": run_class,
    "fixture_pack": fixture_pack,
    "prompt_sha256": prompt_sha256,
    "prompt_source": "prompt_snapshot",
    "prompt_path": str(Path(prompt_path).resolve()),
    "prompt_renderer_command": prompt_cmd,
    "artifact_root": str((path.parent / "artifacts").resolve()),
    "orchestrated_run_dir": str(Path(orchestrated_dir).resolve()),
    "phase_session_metrics_path": str((path.parent / "session" / "phase-session-metrics.jsonl").resolve()),
    "phase3_stdout_no_tools_enabled": phase3_stdout_enabled,
    "phase3_stdout_no_tools_manifest": str(Path(phase3_stdout_manifest).resolve()) if phase3_stdout_manifest else None,
    "phase3_stdout_no_tools_no_refetch_admission": str(Path(phase3_stdout_no_refetch).resolve()) if phase3_stdout_no_refetch else None,
    "phase3_stdout_no_tools_run_dir": str(Path(phase3_stdout_run_dir).resolve()) if phase3_stdout_run_dir else None,
    "phase3_stdout_no_tools_timeout_seconds": phase3_stdout_timeout_seconds if phase3_stdout_enabled else None,
    "git_sha": run_text(["git", "rev-parse", "HEAD"]),
    "git_branch": run_text(["git", "rev-parse", "--abbrev-ref", "HEAD"]),
    "git_dirty": bool(git_status.strip()),
    "dirty_files": [line for line in git_status.splitlines() if line.strip()],
    "copilot": version("copilot"),
    "timeout": version("timeout") if shutil.which("timeout") else version("gtimeout"),
    "python": sys.version.split()[0],
}
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

echo "Preparing instrumented orchestrated proof run in $RUN_DIR"
copilot_log="$RUN_DIR/copilot.log"
set +e
if [ -n "$benchmark_mode" ]; then
	  BENCHMARK_MODE="$benchmark_mode" NEWSLETTER_COST_OPT_STACK="$NEWSLETTER_COST_OPT_STACK" PHASE_TELEMETRY=1 PHASE_REQUIRE_SESSION_LOG="$PHASE_REQUIRE_SESSION_LOG" PROOF_SOURCE_GUARD=1 RUN_DIR_OVERRIDE="$orchestrated_dir" MODEL="$MODEL" MAX_RETRIES="$MAX_RETRIES" PHASE_TIMEOUT_SECONDS="$PHASE_TIMEOUT_SECONDS" \
	    PHASE3_STDOUT_NO_TOOLS="$PHASE3_STDOUT_NO_TOOLS" PHASE3_STDOUT_NO_TOOLS_MANIFEST="$PHASE3_STDOUT_NO_TOOLS_MANIFEST" PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION="$PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION" PHASE3_STDOUT_NO_TOOLS_RUN_DIR="${PHASE3_STDOUT_NO_TOOLS_RUN_DIR:-$orchestrated_dir/phase3-stdout-no-tools}" PHASE3_STDOUT_NO_TOOLS_TIMEOUT_SECONDS="${PHASE3_STDOUT_NO_TOOLS_TIMEOUT_SECONDS:-900}" \
	    bash tools/run_newsletter_orchestrated.sh "$START" "$END" >"$copilot_log" 2>&1
else
	  NEWSLETTER_COST_OPT_STACK="$NEWSLETTER_COST_OPT_STACK" PHASE_TELEMETRY=1 PHASE_REQUIRE_SESSION_LOG="$PHASE_REQUIRE_SESSION_LOG" PROOF_SOURCE_GUARD=1 RUN_DIR_OVERRIDE="$orchestrated_dir" MODEL="$MODEL" MAX_RETRIES="$MAX_RETRIES" PHASE_TIMEOUT_SECONDS="$PHASE_TIMEOUT_SECONDS" \
	    PHASE3_STDOUT_NO_TOOLS="$PHASE3_STDOUT_NO_TOOLS" PHASE3_STDOUT_NO_TOOLS_MANIFEST="$PHASE3_STDOUT_NO_TOOLS_MANIFEST" PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION="$PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION" PHASE3_STDOUT_NO_TOOLS_RUN_DIR="${PHASE3_STDOUT_NO_TOOLS_RUN_DIR:-$orchestrated_dir/phase3-stdout-no-tools}" PHASE3_STDOUT_NO_TOOLS_TIMEOUT_SECONDS="${PHASE3_STDOUT_NO_TOOLS_TIMEOUT_SECONDS:-900}" \
	    bash tools/run_newsletter_orchestrated.sh "$START" "$END" >"$copilot_log" 2>&1
fi
copilot_rc=$?
set -e
printf '%s\n' "$copilot_rc" > "$RUN_DIR/copilot_exit_code.txt"

if [ -f "$orchestrated_dir/session/phase-session-metrics.jsonl" ]; then
  cp "$orchestrated_dir/session/phase-session-metrics.jsonl" "$RUN_DIR/session/phase-session-metrics.jsonl"
fi

set +e
python3 tools/validate_proof_source_drift.py \
  --repo-root "$ROOT" \
  validate \
  --before "$source_snapshot" \
  --output "$source_drift_receipt"
source_drift_rc=$?
set -e

python3 - "$RUN_DIR/session/phase-session-metrics.jsonl" "$RUN_DIR/session/events.jsonl" "$MODEL" <<'PY'
import datetime as dt
import json
import sys
from pathlib import Path

metrics_path = Path(sys.argv[1])
events_path = Path(sys.argv[2])
fallback_model = sys.argv[3]
events_path.parent.mkdir(parents=True, exist_ok=True)
model_rows: dict[str, dict[str, int]] = {}
request_rows: dict[str, int] = {}
phase_rows = []
real_event_lines: list[str] = []
if metrics_path.exists():
    for raw in metrics_path.read_text(encoding="utf-8").splitlines():
        if not raw.strip():
            continue
        row = json.loads(raw)
        phase_rows.append(row)
        session_log_path = row.get("session_log_path")
        if session_log_path:
            path = Path(str(session_log_path))
            if path.exists():
                real_event_lines.extend(
                    line
                    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines()
                    if line.strip()
                )
        usage = row.get("token_usage") if isinstance(row.get("token_usage"), dict) else {}
        breakdown = usage.get("model_breakdown") if isinstance(usage.get("model_breakdown"), dict) else {}
        if not breakdown and usage:
            breakdown = {
                usage.get("primary_model") or row.get("model") or fallback_model: usage,
            }
        for model, payload in breakdown.items():
            if not isinstance(payload, dict):
                continue
            target = model_rows.setdefault(
                str(model),
                {
                    "inputTokens": 0,
                    "outputTokens": 0,
                    "cacheReadTokens": 0,
                    "cacheWriteTokens": 0,
                    "reasoningTokens": 0,
                },
            )
            target["inputTokens"] += int(payload.get("input_tokens", 0) or 0)
            target["outputTokens"] += int(payload.get("output_tokens", 0) or 0)
            target["cacheReadTokens"] += int(payload.get("cache_read_tokens", 0) or 0)
            target["cacheWriteTokens"] += int(payload.get("cache_write_tokens", 0) or 0)
            target["reasoningTokens"] += int(payload.get("reasoning_tokens", 0) or 0)
            request_rows[str(model)] = request_rows.get(str(model), 0) + int(payload.get("request_count", 0) or 0)

if not model_rows:
    model_rows[fallback_model] = {
        "inputTokens": 0,
        "outputTokens": 0,
        "cacheReadTokens": 0,
        "cacheWriteTokens": 0,
        "reasoningTokens": 0,
    }
    request_rows[fallback_model] = 0

model_metrics = {
    model: {
        "requests": {"count": request_rows.get(model, 0)},
        "usage": usage,
    }
    for model, usage in model_rows.items()
}
now = dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
rows = [
    {
        "type": "phase.telemetry_summary",
        "timestamp": now,
        "data": {
            "aggregate_from_phase_session_metrics": True,
            "phase_count": len(phase_rows),
            "phase_ids": [row.get("phase_id") for row in phase_rows],
            "merged_real_event_line_count": len(real_event_lines),
        },
    },
    {
        "type": "session.shutdown",
        "timestamp": now,
        "data": {
            "aggregate_from_phase_session_metrics": True,
            "reason": "completed",
            "currentModel": fallback_model,
            "totalPremiumRequests": sum(request_rows.values()),
            "modelMetrics": model_metrics,
        },
    },
]
synthetic_lines = [json.dumps(row, sort_keys=True) for row in rows]
events_path.write_text(
    "\n".join(real_event_lines + synthetic_lines) + "\n",
    encoding="utf-8",
)
PY

snapshot_rc=99
audit_rc=99
scorecard_rc=99
if [ "$source_drift_rc" -eq 0 ]; then
  set +e
  python3 tools/snapshot_product_run_artifacts.py \
    "$START" \
    "$END" \
    --dest-root "$RUN_DIR/artifacts"
  snapshot_rc=$?
  set -e

  if [ "$snapshot_rc" -eq 0 ]; then
    audit_cmd=(
      python3
      tools/collect_product_run_audit.py
      "$START"
      "$END"
      --mode
      "$MODE"
      --run-dir
      "$RUN_DIR/audit"
      --require-fresh
      --session-log
      "$RUN_DIR/session/events.jsonl"
    )
    set +e
    "${audit_cmd[@]}"
    audit_rc=$?
    set -e
  else
    echo "Instrumented orchestrated proof run skipped audit: snapshot exited with $snapshot_rc"
  fi
else
  echo "Instrumented orchestrated proof run skipped snapshot/audit: protected source drift detected"
fi

ended_at_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
python3 - "$RUN_DIR/run-result.json" "$copilot_rc" "$source_drift_rc" "$snapshot_rc" "$audit_rc" "$scorecard_rc" "$ended_at_utc" "$RUN_DIR/session/events.jsonl" "$source_drift_receipt" <<'PY'
import json
import sys
from pathlib import Path

payload = {
    "copilot_exit_code": int(sys.argv[2]),
    "source_drift_exit_code": int(sys.argv[3]),
    "snapshot_exit_code": int(sys.argv[4]),
    "audit_exit_code": int(sys.argv[5]),
    "scorecard_exit_code": int(sys.argv[6]),
    "ended_at_utc": sys.argv[7],
    "session_log_path": sys.argv[8],
    "source_drift_receipt": sys.argv[9],
}
Path(sys.argv[1]).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

if [ "$source_drift_rc" -eq 0 ] && [ "$snapshot_rc" -eq 0 ]; then
  scorecard_cmd=(python3 tools/build_run_experiment_scorecard.py --run-dir "$RUN_DIR")
  if [ -n "$PRICING_SNAPSHOT" ]; then
    scorecard_cmd+=(--pricing-snapshot "$PRICING_SNAPSHOT")
  fi
  set +e
  "${scorecard_cmd[@]}" >/dev/null
  scorecard_rc=$?
  set -e
  python3 - "$RUN_DIR/run-result.json" "$scorecard_rc" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["scorecard_exit_code"] = int(sys.argv[2])
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
fi

if [ "$source_drift_rc" -eq 0 ]; then
  set +e
  python3 tools/validate_proof_source_drift.py \
    --repo-root "$ROOT" \
    validate \
    --before "$source_snapshot" \
    --output "$source_drift_receipt"
  source_drift_rc=$?
  set -e
  python3 - "$RUN_DIR/run-result.json" "$source_drift_rc" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["source_drift_exit_code"] = int(sys.argv[2])
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
fi

if [ "$source_drift_rc" -ne 0 ]; then
  echo "Instrumented orchestrated proof run failed: protected source drift detected"
  exit "$source_drift_rc"
fi
if [ "$copilot_rc" -ne 0 ]; then
  echo "Instrumented orchestrated proof run failed: orchestrator exited with $copilot_rc"
  exit "$copilot_rc"
fi
if [ "$snapshot_rc" -ne 0 ]; then
  echo "Instrumented orchestrated proof run failed: snapshot exited with $snapshot_rc"
  exit "$snapshot_rc"
fi
if [ "$audit_rc" -ne 0 ]; then
  echo "Instrumented orchestrated proof run failed: audit exited with $audit_rc"
  exit "$audit_rc"
fi
if [ "$scorecard_rc" -ne 0 ]; then
  echo "Instrumented orchestrated proof run failed: scorecard exited with $scorecard_rc"
  exit "$scorecard_rc"
fi

echo "Instrumented orchestrated proof run complete: $RUN_DIR"

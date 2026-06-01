#!/usr/bin/env bash
# Controlled phase-by-phase newsletter generation orchestration.
# Uses explicit agent delegation boundaries, timeout/retry, and artifact/receipt checks.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

START="${1:-}"
END="${2:-}"

if [ -z "$START" ] || [ -z "$END" ]; then
  echo "Usage: bash tools/run_newsletter_orchestrated.sh <START_DATE> <END_DATE>"
  exit 1
fi
if ! [[ "$START" =~ ^[0-9]{4}-(0[1-9]|1[0-2])-[0-9]{2}$ ]]; then
  echo "ERROR: START_DATE must be YYYY-MM-DD, got: $START"
  exit 1
fi
if ! [[ "$END" =~ ^[0-9]{4}-(0[1-9]|1[0-2])-[0-9]{2}$ ]]; then
  echo "ERROR: END_DATE must be YYYY-MM-DD, got: $END"
  exit 1
fi

MODEL="${MODEL:-gpt-5.5}"
COPILOT_BIN="${COPILOT_BIN:-copilot}"
NO_REUSE="${NO_REUSE:-1}"
MAX_RETRIES="${MAX_RETRIES:-2}"
PHASE_TIMEOUT_SECONDS="${PHASE_TIMEOUT_SECONDS:-1800}"
BENCHMARK_MODE="${BENCHMARK_MODE:-}"
RENDER_ONLY="${RENDER_ONLY:-0}"
RUN_DIR_OVERRIDE="${RUN_DIR_OVERRIDE:-}"
NEWSLETTER_COST_OPT_STACK_USER_SET="${NEWSLETTER_COST_OPT_STACK+x}"
NEWSLETTER_COST_OPT_STACK="${NEWSLETTER_COST_OPT_STACK:-0}"
NEWSLETTER_COST_OPT_STACK_DISABLE_DEFAULT="${NEWSLETTER_COST_OPT_STACK_DISABLE_DEFAULT:-0}"
NEWSLETTER_COST_OPT_STACK_FEATURE_CONFIG="${NEWSLETTER_COST_OPT_STACK_FEATURE_CONFIG:-config/production_feature_flags/newsletter_cost_opt_stack_default.json}"
NEWSLETTER_COST_OPT_STACK_DEFAULT_SOURCE="${NEWSLETTER_COST_OPT_STACK_DEFAULT_SOURCE:-}"
NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUT_BINDING="${NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUT_BINDING:-0}"
NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUT_OUTPUT_SUBDIR="${NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUT_OUTPUT_SUBDIR:-cost-stack-inputs}"
NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUT_MANIFEST_ID_PREFIX="${NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUT_MANIFEST_ID_PREFIX:-cost_stack}"
NEWSLETTER_COST_OPT_STACK_INPUT_BINDING_DIR="${NEWSLETTER_COST_OPT_STACK_INPUT_BINDING_DIR:-}"
NEWSLETTER_COST_OPT_STACK_INPUT_MANIFEST_ID="${NEWSLETTER_COST_OPT_STACK_INPUT_MANIFEST_ID:-}"
NEWSLETTER_COST_OPT_STACK_FIXED_START="${NEWSLETTER_COST_OPT_STACK_FIXED_START:-2026-02-14}"
NEWSLETTER_COST_OPT_STACK_FIXED_END="${NEWSLETTER_COST_OPT_STACK_FIXED_END:-2026-04-16}"
NEWSLETTER_COST_OPT_STACK_SOURCE_PRUNING_POLICY="${NEWSLETTER_COST_OPT_STACK_SOURCE_PRUNING_POLICY:-config/experiment_pruning_policies/burst21-production-source-candidate-v1.json}"
NEWSLETTER_COST_OPT_STACK_STDOUT_MANIFEST="${NEWSLETTER_COST_OPT_STACK_STDOUT_MANIFEST:-config/experiment_fixture_packs/production-anchor-2026-02-14_2026-04-16.json}"
NEWSLETTER_COST_OPT_STACK_NO_REFETCH_ADMISSION="${NEWSLETTER_COST_OPT_STACK_NO_REFETCH_ADMISSION:-planning/stdout-no-tools-artifact-reuse-burst-39-2026-05-08/production-admission/no-refetch-admission.json}"
NEWSLETTER_COST_OPT_STACK_PHASE1B_REASONING_EFFORT="${NEWSLETTER_COST_OPT_STACK_PHASE1B_REASONING_EFFORT:-low}"
PHASE1B_REASONING_EFFORT="${PHASE1B_REASONING_EFFORT:-}"
PHASE3_COMPACT_WORKING_SET="${PHASE3_COMPACT_WORKING_SET:-0}"
PHASE3_COMPACT_WORKING_SET_POLICY="${PHASE3_COMPACT_WORKING_SET_POLICY:-}"
PHASE3_STDOUT_NO_TOOLS="${PHASE3_STDOUT_NO_TOOLS:-0}"
PHASE3_STDOUT_NO_TOOLS_MANIFEST="${PHASE3_STDOUT_NO_TOOLS_MANIFEST:-}"
PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION="${PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION:-}"
PHASE3_STDOUT_NO_TOOLS_RUN_DIR="${PHASE3_STDOUT_NO_TOOLS_RUN_DIR:-}"
PHASE3_STDOUT_NO_TOOLS_AGENT="${PHASE3_STDOUT_NO_TOOLS_AGENT:-customer_newsletter}"
PHASE3_STDOUT_NO_TOOLS_V2_FALLBACK_USER_SET="${PHASE3_STDOUT_NO_TOOLS_V2_FALLBACK+x}"
PHASE3_STDOUT_NO_TOOLS_V2_FALLBACK="${PHASE3_STDOUT_NO_TOOLS_V2_FALLBACK:-0}"
PHASE3_STDOUT_NO_TOOLS_FALLBACK_USED=0
PHASE3_STDOUT_NO_TOOLS_DISABLE_DEFAULT="${PHASE3_STDOUT_NO_TOOLS_DISABLE_DEFAULT:-0}"
PHASE3_STDOUT_NO_TOOLS_FEATURE_CONFIG="${PHASE3_STDOUT_NO_TOOLS_FEATURE_CONFIG:-config/production_feature_flags/phase3_stdout_no_tools_artifact_reuse.json}"

if ! [[ "$MAX_RETRIES" =~ ^[0-9]+$ ]]; then
  echo "ERROR: MAX_RETRIES must be a non-negative integer, got: $MAX_RETRIES"
  exit 1
fi
MAX_ATTEMPTS=$((MAX_RETRIES + 1))

if [ -z "$NEWSLETTER_COST_OPT_STACK_USER_SET" ] \
  && [ "$NEWSLETTER_COST_OPT_STACK_DISABLE_DEFAULT" != "1" ] \
  && [ -f "$NEWSLETTER_COST_OPT_STACK_FEATURE_CONFIG" ]; then
  if ! cost_stack_flag_shell="$(python3 tools/resolve_newsletter_cost_opt_stack_default.py \
    --feature-config "$NEWSLETTER_COST_OPT_STACK_FEATURE_CONFIG" \
    --shell)"; then
    echo "[orchestrator] cost optimization stack default resolution failed"
    exit 1
  fi
  if [ -n "$cost_stack_flag_shell" ]; then
    eval "$cost_stack_flag_shell"
  fi
fi

NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUTS_NEEDED=0
NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUTS_BUILT=0
if [ "$NEWSLETTER_COST_OPT_STACK" = "1" ]; then
  PHASE_TELEMETRY=1
  PHASE_REQUIRE_SESSION_LOG=1
  PHASE_REQUIRE_DIRECT_TOKEN_FIELDS=1
  cost_stack_stdout_enabled=1
  if [ "$PHASE3_STDOUT_NO_TOOLS_DISABLE_DEFAULT" = "1" ]; then
    cost_stack_stdout_enabled=0
  fi
  if [ "$START" != "$NEWSLETTER_COST_OPT_STACK_FIXED_START" ] || [ "$END" != "$NEWSLETTER_COST_OPT_STACK_FIXED_END" ]; then
    if [ "$cost_stack_stdout_enabled" = "1" ] && { [ -z "${PHASE3_STDOUT_NO_TOOLS_MANIFEST:-}" ] || [ -z "${PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION:-}" ]; }; then
      if [ "$NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUT_BINDING" = "1" ]; then
        NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUTS_NEEDED=1
      else
        echo "ERROR: NEWSLETTER_COST_OPT_STACK=1 defaults are locked to ${NEWSLETTER_COST_OPT_STACK_FIXED_START} to ${NEWSLETTER_COST_OPT_STACK_FIXED_END}."
        echo "Set PHASE3_STDOUT_NO_TOOLS_MANIFEST and PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION explicitly for another corpus."
        exit 1
      fi
    fi
  fi
  PHASE1B_REASONING_EFFORT="${PHASE1B_REASONING_EFFORT:-$NEWSLETTER_COST_OPT_STACK_PHASE1B_REASONING_EFFORT}"
  PHASE3_COMPACT_WORKING_SET="1"
  PHASE3_COMPACT_WORKING_SET_POLICY="${PHASE3_COMPACT_WORKING_SET_POLICY:-$NEWSLETTER_COST_OPT_STACK_SOURCE_PRUNING_POLICY}"
  if [ "$cost_stack_stdout_enabled" = "1" ]; then
    PHASE3_STDOUT_NO_TOOLS="1"
    if [ -z "$PHASE3_STDOUT_NO_TOOLS_V2_FALLBACK_USER_SET" ]; then
      PHASE3_STDOUT_NO_TOOLS_V2_FALLBACK=1
    fi
    if [ "$NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUTS_NEEDED" != "1" ]; then
      PHASE3_STDOUT_NO_TOOLS_MANIFEST="${PHASE3_STDOUT_NO_TOOLS_MANIFEST:-$NEWSLETTER_COST_OPT_STACK_STDOUT_MANIFEST}"
      PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION="${PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION:-$NEWSLETTER_COST_OPT_STACK_NO_REFETCH_ADMISSION}"
    fi
  fi
fi

if [ "$PHASE3_STDOUT_NO_TOOLS" != "1" ] \
  && [ "$PHASE3_STDOUT_NO_TOOLS_DISABLE_DEFAULT" != "1" ] \
  && [ -f "$PHASE3_STDOUT_NO_TOOLS_FEATURE_CONFIG" ]; then
  if ! stdout_flag_shell="$(python3 tools/resolve_stdout_no_tools_feature_flag.py \
    --feature-config "$PHASE3_STDOUT_NO_TOOLS_FEATURE_CONFIG" \
    --shell)"; then
    echo "[orchestrator] phase3 stdout/no-tools feature flag resolution failed"
    exit 1
  fi
  if [ -n "$stdout_flag_shell" ]; then
    eval "$stdout_flag_shell"
  fi
fi

if [ -z "$BENCHMARK_MODE" ] && [ "$START" = "2025-12-05" ] && [ "$END" = "2026-02-13" ]; then
  BENCHMARK_MODE="feb2026_consistency"
fi

resolve_copilot_bin() {
  local candidate="${1:-copilot}"
  case "$candidate" in
    /*|*/*)
      if [ -e "$candidate" ]; then
        (cd "$(dirname "$candidate")" && printf '%s/%s\n' "$(pwd -P)" "$(basename "$candidate")")
      else
        printf '%s\n' "$candidate"
      fi
      ;;
    *)
      command -v "$candidate" || {
        if [ "$candidate" = "copilot" ] && [ -x /opt/homebrew/bin/copilot ]; then
          printf '%s\n' /opt/homebrew/bin/copilot
        else
          printf '%s\n' "$candidate"
        fi
      }
      ;;
  esac
}

COPILOT_BIN="$(resolve_copilot_bin "$COPILOT_BIN")"
export COPILOT_BIN
if [ ! -x "$COPILOT_BIN" ]; then
  echo "ERROR: copilot CLI not found or not executable: $COPILOT_BIN"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found"
  exit 1
fi

run_id="$(date -u +%Y%m%dT%H%M%SZ)"
if [ -n "$RUN_DIR_OVERRIDE" ]; then
  run_dir="$RUN_DIR_OVERRIDE"
else
  run_dir="runs/orchestrated/${run_id}_${START}_to_${END}"
fi
prompt_dir="$run_dir/prompts"
log_dir="$run_dir/logs"
session_dir="$run_dir/session"
phase_metrics_file="$session_dir/phase-session-metrics.jsonl"
receipt_guard_baseline="$session_dir/receipt-baseline.prior-success.json"
PHASE_TELEMETRY="${PHASE_TELEMETRY:-0}"
PHASE_REQUIRE_SESSION_LOG="${PHASE_REQUIRE_SESSION_LOG:-0}"
PROOF_SOURCE_GUARD="${PROOF_SOURCE_GUARD:-0}"
mkdir -p "$prompt_dir" "$log_dir"
if [ "$PHASE_TELEMETRY" = "1" ]; then
  mkdir -p "$session_dir"
  : > "$phase_metrics_file"
fi

manifest="workspace/newsletter_phase1a_url_manifest_${START}_to_${END}.md"
discoveries="workspace/newsletter_phase1a_discoveries_${START}_to_${END}.md"
phase1b_github="workspace/newsletter_phase1b_interim_github_${START}_to_${END}.md"
phase1b_vscode="workspace/newsletter_phase1b_interim_vscode_${START}_to_${END}.md"
phase1b_visualstudio="workspace/newsletter_phase1b_interim_visualstudio_${START}_to_${END}.md"
phase1b_jetbrains="workspace/newsletter_phase1b_interim_jetbrains_${START}_to_${END}.md"
phase1b_xcode="workspace/newsletter_phase1b_interim_xcode_${START}_to_${END}.md"
phase2_event_sources="workspace/newsletter_phase2_event_sources_${END}.json"
phase2_events="workspace/newsletter_phase2_events_${END}.md"
phase3_curated="workspace/newsletter_phase3_curated_sections_${END}.md"
phase3_working_set="workspace/newsletter_phase3_working_set_${END}.md"
scope_contract="workspace/newsletter_scope_contract_${END}.json"
scope_results="workspace/newsletter_scope_results_${END}.md"
receipt_file="workspace/newsletter_phase_receipts_${END}.json"
cycle_ym="$(echo "$END" | cut -d- -f1-2)"
editorial_review="workspace/${cycle_ym}_editorial_review.md"
phase45_polishing_report="workspace/newsletter_phase4_5_polishing_${END}.md"
phase46_video_report="workspace/newsletter_phase4_6_video_matches_${END}.md"
CHECK_FAILURES=0

year="${END%%-*}"
month="$(echo "$END" | cut -d- -f2)"
case "$month" in
  01) month_name="january" ;;
  02) month_name="february" ;;
  03) month_name="march" ;;
  04) month_name="april" ;;
  05) month_name="may" ;;
  06) month_name="june" ;;
  07) month_name="july" ;;
  08) month_name="august" ;;
  09) month_name="september" ;;
  10) month_name="october" ;;
  11) month_name="november" ;;
  12) month_name="december" ;;
  *) month_name="unknown" ;;
esac
output_file="output/${year}-${month}_${month_name}_newsletter.md"

has_receipt() {
  local phase_id="$1"
  python3 - "$receipt_file" "$phase_id" <<'PY' >/dev/null 2>&1
import json
import sys
from pathlib import Path

receipt_path = Path(sys.argv[1])
phase_id = sys.argv[2]
if not receipt_path.exists():
    raise SystemExit(1)

try:
    payload = json.loads(receipt_path.read_text(encoding="utf-8"))
except Exception:
    raise SystemExit(1)

for r in payload.get("receipts", []):
    if r.get("phase_id") == phase_id:
        raise SystemExit(0)
raise SystemExit(1)
PY
}

receipt_has_required_fields() {
  local phase_id="$1"
  python3 - "$receipt_file" "$phase_id" <<'PY' >/dev/null 2>&1
import json
import sys
from pathlib import Path

receipt_path = Path(sys.argv[1])
phase_id = sys.argv[2]
if not receipt_path.exists():
    raise SystemExit(1)

try:
    payload = json.loads(receipt_path.read_text(encoding="utf-8"))
except Exception:
    raise SystemExit(1)

required = {"artifact_sha256", "artifact_mtime_epoch", "recorded_at_epoch", "receipt_order"}
for r in payload.get("receipts", []):
    if r.get("phase_id") != phase_id:
        continue
    if all(k in r and r.get(k) not in (None, "") for k in required):
        raise SystemExit(0)
    raise SystemExit(1)
raise SystemExit(1)
PY
}

check_receipt_drift() {
  local phase_name="$1"
  local -a drift_args=(--require-mtime)
  if [ ! -f "$receipt_file" ]; then
    return 0
  fi
  if [ -f "$receipt_guard_baseline" ]; then
    drift_args+=(--baseline-receipts "$receipt_guard_baseline")
  fi
  if ! python3 tools/validate_phase_receipt_drift.py "$START" "$END" "${drift_args[@]}"; then
    echo "[orchestrator] $phase_name prior receipt-bound artifact drift detected"
    return 1
  fi
}

refresh_receipt_baseline() {
  if [ ! -f "$receipt_file" ]; then
    return 0
  fi
  mkdir -p "$session_dir"
  cp "$receipt_file" "$receipt_guard_baseline"
}

normalize_receipts() {
  local phase_name="$1"
  local artifacts_csv="$2"
  local receipts_csv="$3"
  local -a artifacts receipts

  IFS=';' read -r -a artifacts <<< "$artifacts_csv"
  IFS=';' read -r -a receipts <<< "$receipts_csv"
  if [ "${#artifacts[@]}" -ne "${#receipts[@]}" ]; then
    echo "[orchestrator] $phase_name bug: artifact/receipt count mismatch (${#artifacts[@]} != ${#receipts[@]})"
    return 1
  fi

  local count="${#receipts[@]}"
  local i=0
  while [ "$i" -lt "$count" ]; do
    local rid="${receipts[$i]}"
    local artifact="${artifacts[$i]:-}"
    i=$((i + 1))

    [ -n "$rid" ] || continue
    [ -n "$artifact" ] || continue
    [ -s "$artifact" ] || continue

    echo "[orchestrator] $phase_name normalizing receipt: $rid ($artifact)"
    if ! bash tools/record_phase_receipt.sh "$START" "$END" "$rid" "$artifact" >/dev/null; then
      echo "[orchestrator] $phase_name warning: receipt normalization failed for $rid"
    fi
  done
}

check_artifacts_and_receipts() {
  local phase_name="$1"
  local artifacts_csv="$2"
  local receipts_csv="$3"
  local failed=0
  local -a artifacts receipts

  IFS=';' read -r -a artifacts <<< "$artifacts_csv"
  for f in "${artifacts[@]}"; do
    [ -n "$f" ] || continue
    if [ ! -s "$f" ]; then
      echo "[orchestrator] $phase_name missing/empty artifact: $f"
      failed=1
    fi
  done

  IFS=';' read -r -a receipts <<< "$receipts_csv"
  for rid in "${receipts[@]}"; do
    [ -n "$rid" ] || continue
    if ! has_receipt "$rid"; then
      echo "[orchestrator] $phase_name missing receipt: $rid"
      failed=1
      continue
    fi
    if ! receipt_has_required_fields "$rid"; then
      echo "[orchestrator] $phase_name receipt missing required provenance fields: $rid"
      failed=1
    fi
  done

  return "$failed"
}

phase3_stdout_v2_fallback_allowed() {
  local readiness_receipt="$1"
  if [ "$PHASE3_STDOUT_NO_TOOLS_V2_FALLBACK" != "1" ]; then
    return 1
  fi
  if [ ! -f "$readiness_receipt" ]; then
    return 1
  fi
  python3 - "$readiness_receipt" <<'PY' >/dev/null 2>&1
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
if payload.get("artifact") != "phase3-v2-readiness-receipt":
    raise SystemExit(1)
if payload.get("pass") is not False:
    raise SystemExit(1)
failures = payload.get("failures")
if not isinstance(failures, list) or not failures:
    raise SystemExit(1)
raise SystemExit(0)
PY
}

write_phase3_stdout_fallback_receipt() {
  local fallback_receipt="$1"
  local readiness_receipt="$2"
  local stdout_run_dir="$3"
  local stdout_rc="$4"
  mkdir -p "$(dirname "$fallback_receipt")"
  python3 - "$fallback_receipt" "$readiness_receipt" "$stdout_run_dir" "$stdout_rc" "$START" "$END" "$MODEL" <<'PY'
import datetime as dt
import json
import sys
from pathlib import Path

fallback_receipt = Path(sys.argv[1])
readiness_receipt = Path(sys.argv[2])
stdout_run_dir = sys.argv[3]
stdout_rc = int(sys.argv[4])
start = sys.argv[5]
end = sys.argv[6]
model = sys.argv[7]
readiness = json.loads(readiness_receipt.read_text(encoding="utf-8"))
payload = {
    "schema_version": 1,
    "receipt_type": "phase3_stdout_no_tools_v2_fallback",
    "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "date_range": {"start": start, "end": end},
    "model": model,
    "stdout_no_tools_run_dir": stdout_run_dir,
    "stdout_no_tools_exit_code": stdout_rc,
    "readiness_receipt_path": str(readiness_receipt),
    "readiness_failures": readiness.get("failures", []),
    "fallback_route": "phase3_curation_fuller_route",
    "decision": "fallback_to_fuller_phase3",
    "non_claims": [
        "This fallback preserves quality safety; it is not a savings claim.",
        "The fallback route may spend more than the stdout/no-tools path.",
    ],
}
fallback_receipt.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
}

check_phase_specific_contracts() {
  local phase_name="$1"

  case "$phase_name" in
    phase1a_manifest)
      mkdir -p "$session_dir"
      if ! python3 tools/validate_phase1a_scope_alignment.py "$START" "$END" \
        --prompt-file "$phase1a_prompt" \
        --write-receipt "$session_dir/phase1a-scope-alignment-preflight.json"; then
        echo "[orchestrator] $phase_name URL manifest failed scope alignment"
        return 1
      fi
      ;;
    phase3_curation)
      local -a validate_cmd
      if [ ! -f "$phase3_working_set" ]; then
        echo "[orchestrator] $phase_name missing working set artifact: $phase3_working_set"
        return 1
      fi
      validate_cmd=(python3 tools/validate_phase3_curated.py "$START" "$END" "$phase3_curated")
      validate_cmd+=(--working-set "$phase3_working_set")
      if [ -n "$BENCHMARK_MODE" ]; then
        validate_cmd+=(--benchmark-mode "$BENCHMARK_MODE")
      fi
      if ! "${validate_cmd[@]}"; then
        echo "[orchestrator] $phase_name curated artifact failed contract validation"
        return 1
      fi
      ;;
  esac

  return 0
}

has_curator_notes() {
  python3 - <<'PY' >/dev/null 2>&1
from pathlib import Path
import re

workspace = Path("workspace")
if not workspace.exists():
    raise SystemExit(1)

candidates = set()
for p in workspace.glob("curator_notes_*.md"):
    name = p.name
    if name.startswith("curator_notes_processed_") or name.startswith("curator_notes_editorial_signals_"):
        continue
    if name.startswith("newsletter_"):
        continue
    candidates.add(p)

for p in workspace.glob("*.md"):
    name = p.name
    if not re.fullmatch(r"[A-Za-z].*\.md", name):
        continue
    if name.startswith("curator_notes_processed_") or name.startswith("curator_notes_editorial_signals_"):
        continue
    if name.startswith("newsletter_"):
        continue
    candidates.add(p)

raise SystemExit(0 if candidates else 1)
PY
}

run_phase() {
  local phase_name="$1"
  local agent_name="$2"
  local timeout_s="$3"
  local prompt_file="$4"
  local artifacts_csv="$5"
  local receipts_csv="$6"
  local -a artifacts receipts telemetry_args phase_copilot_args
  local boundary_receipt=""

  IFS=';' read -r -a artifacts <<< "$artifacts_csv"
  IFS=';' read -r -a receipts <<< "$receipts_csv"
  for rid in "${receipts[@]}"; do
    if [ -n "$rid" ]; then
      boundary_receipt="$rid"
    fi
  done

  local attempt=1
  while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
    local log_file="$log_dir/${phase_name}.attempt${attempt}.log"
    local source_snapshot_file="$session_dir/${phase_name}.attempt${attempt}.source.before.json"
    local source_drift_receipt="$session_dir/${phase_name}.attempt${attempt}.source-drift.json"
    local copilot_rc=0
    echo
    echo "[orchestrator] phase=$phase_name agent=$agent_name attempt=$attempt timeout=${timeout_s}s"
    if ! check_receipt_drift "${phase_name}.pre"; then
      echo "[orchestrator] phase=$phase_name failed before execution because prior receipts drifted"
      return 1
    fi
    if [ "$PROOF_SOURCE_GUARD" = "1" ]; then
      mkdir -p "$session_dir"
      python3 tools/validate_proof_source_drift.py \
        --repo-root "$ROOT" \
        snapshot \
        --output "$source_snapshot_file"
    fi

    phase_copilot_args=()
    if [ "$phase_name" = "phase1b_retrieval" ] && [ -n "$PHASE1B_REASONING_EFFORT" ]; then
      case "$PHASE1B_REASONING_EFFORT" in
        low|medium|high|xhigh)
          phase_copilot_args+=(--reasoning-effort "$PHASE1B_REASONING_EFFORT")
          ;;
        *)
          echo "[orchestrator] invalid PHASE1B_REASONING_EFFORT: $PHASE1B_REASONING_EFFORT"
          return 1
          ;;
      esac
    fi

    telemetry_args=()
    if [ "$PHASE_TELEMETRY" = "1" ]; then
      telemetry_args+=(
        --phase-id "${boundary_receipt:-$phase_name}"
        --metrics-out "$phase_metrics_file"
        --session-out "$session_dir/${phase_name}.attempt${attempt}.events.jsonl"
      )
      if [ "$PHASE_REQUIRE_SESSION_LOG" = "1" ]; then
        telemetry_args+=(--require-session-log)
      fi
      if [ "${PHASE_REQUIRE_DIRECT_TOKEN_FIELDS:-0}" = "1" ]; then
        telemetry_args+=(--require-direct-token-fields)
      fi
      for artifact in "${artifacts[@]}"; do
        if [ -n "$artifact" ]; then
          telemetry_args+=(--artifact-path "$artifact")
        fi
      done
      for rid in "${receipts[@]}"; do
        if [ -n "$rid" ]; then
          telemetry_args+=(--receipt-id "$rid")
        fi
      done
    fi

    local -a copilot_phase_cmd
    copilot_phase_cmd=(
      python3 tools/run_copilot_phase.py
      --agent "$agent_name"
      --model "$MODEL"
      --copilot-bin "$COPILOT_BIN"
      --prompt-file "$prompt_file"
      --log "$log_file"
      --timeout "$timeout_s"
      --cwd "$ROOT"
    )
    if [ "${#phase_copilot_args[@]}" -gt 0 ]; then
      copilot_phase_cmd+=("${phase_copilot_args[@]}")
    fi
    if [ "${#telemetry_args[@]}" -gt 0 ]; then
      copilot_phase_cmd+=("${telemetry_args[@]}")
    fi

    if "${copilot_phase_cmd[@]}"; then
      copilot_rc=0
    else
      copilot_rc=$?
      echo "[orchestrator] phase=$phase_name copilot execution failed (see $log_file)"
    fi

    if [ "$PROOF_SOURCE_GUARD" = "1" ]; then
      if ! python3 tools/validate_proof_source_drift.py \
        --repo-root "$ROOT" \
        validate \
        --before "$source_snapshot_file" \
        --output "$source_drift_receipt"; then
        echo "[orchestrator] phase=$phase_name protected source drift detected"
        return 1
      fi
    fi

    if [ "$copilot_rc" -eq 0 ]; then
      normalize_receipts "$phase_name" "$artifacts_csv" "$receipts_csv"
      if check_artifacts_and_receipts "$phase_name" "$artifacts_csv" "$receipts_csv" && \
        check_receipt_drift "${phase_name}.post" && \
        check_phase_specific_contracts "$phase_name"; then
        refresh_receipt_baseline
        echo "[orchestrator] phase=$phase_name PASS"
        return 0
      else
        echo "[orchestrator] phase=$phase_name artifact/receipt or contract check failed"
      fi
    fi

    attempt=$((attempt + 1))
    if [ "$attempt" -le "$MAX_ATTEMPTS" ]; then
      echo "[orchestrator] phase=$phase_name retrying..."
      sleep 3
    fi
  done

  echo "[orchestrator] phase=$phase_name FAILED after ${MAX_ATTEMPTS} attempts"
  return 1
}

run_check() {
  local check_name="$1"
  shift
  local log_file="$log_dir/${check_name}.log"
  local cmd_rc=0
  echo
  echo "[orchestrator] check=$check_name"
  if "$@" 2>&1 | tee "$log_file"; then
    cmd_rc=0
  else
    cmd_rc="${PIPESTATUS[0]}"
  fi
  if [ "$cmd_rc" -ne 0 ]; then
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
    echo "[orchestrator] check=$check_name FAIL (exit $cmd_rc)"
  else
    echo "[orchestrator] check=$check_name PASS"
  fi
  return 0
}

check_default_event_corpus_guard() {
  local guard_log="$log_dir/default_cost_stack_phase2_event_guard.log"
  local guard_rc=0
  echo
  echo "[orchestrator] check=default_cost_stack_phase2_event_guard"
  set +e
  NEWSLETTER_PHASE2_CORPUS_AWARE_EVENT_FLOOR="${NEWSLETTER_PHASE2_CORPUS_AWARE_EVENT_FLOOR:-0}" \
    python3 tools/validate_phase2_event_quality.py \
      "$phase2_events" \
      "$START" \
      "$END" \
      1 \
      "$phase2_event_sources" \
      1 \
      "${BENCHMARK_MODE:-}" 2>&1 | tee "$guard_log"
  guard_rc="${PIPESTATUS[0]}"
  set -e
  if [ "$guard_rc" -ne 0 ] || grep -q '^FAIL:' "$guard_log"; then
    echo "[orchestrator] default cost-stack Phase 2 event corpus guard failed"
    return 1
  fi
  echo "[orchestrator] check=default_cost_stack_phase2_event_guard PASS"
}

check_default_amplification_fields() {
  if [ "$NEWSLETTER_COST_OPT_STACK" != "1" ]; then
    return 0
  fi
  if [ "$PHASE_TELEMETRY" != "1" ]; then
    echo "[orchestrator] default cost-stack requires PHASE_TELEMETRY=1"
    return 1
  fi
  if [ "${PHASE_REQUIRE_DIRECT_TOKEN_FIELDS:-0}" != "1" ]; then
    echo "[orchestrator] default cost-stack requires PHASE_REQUIRE_DIRECT_TOKEN_FIELDS=1"
    return 1
  fi
  if [ ! -s "$phase_metrics_file" ]; then
    echo "[orchestrator] default cost-stack phase telemetry missing: $phase_metrics_file"
    return 1
  fi
  python3 - "$phase_metrics_file" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
missing = []
for line_number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
    if not raw.strip():
        continue
    row = json.loads(raw)
    usage = row.get("token_usage") if isinstance(row.get("token_usage"), dict) else {}
    for field in ("request_count", "tool_calls"):
        if usage.get(field) is None:
            missing.append(f"line {line_number} phase {row.get('phase_id')}: token_usage.{field}")
if missing:
    print("missing request/tool amplification fields: " + "; ".join(missing), file=sys.stderr)
    raise SystemExit(1)
PY
}

write_prompt() {
  local file="$1"
  shift
  cat > "$file" <<EOF
$*
EOF
}

phase_runtime_guard="Do not use apply_patch for phase artifacts. Do not inspect, monitor, wait on, or coordinate with the outer run_copilot_phase.py, copilot, or orchestrator process IDs. You are the active phase runner: write the requested artifact directly, record its receipt, and stop."

echo "[orchestrator] run_id=$run_id"
echo "[orchestrator] date_range=$START to $END"
echo "[orchestrator] model=$MODEL"
echo "[orchestrator] copilot_bin=$COPILOT_BIN"
echo "[orchestrator] benchmark_mode=${BENCHMARK_MODE:-<none>}"
echo "[orchestrator] render_only=$RENDER_ONLY"
echo "[orchestrator] phase_telemetry=$PHASE_TELEMETRY"
echo "[orchestrator] phase_require_session_log=$PHASE_REQUIRE_SESSION_LOG"
echo "[orchestrator] proof_source_guard=$PROOF_SOURCE_GUARD"
echo "[orchestrator] max_retries=$MAX_RETRIES"
echo "[orchestrator] max_attempts=$MAX_ATTEMPTS"
echo "[orchestrator] newsletter_cost_opt_stack=$NEWSLETTER_COST_OPT_STACK"
echo "[orchestrator] newsletter_cost_opt_stack_default_source=${NEWSLETTER_COST_OPT_STACK_DEFAULT_SOURCE:-<none>}"
echo "[orchestrator] newsletter_cost_opt_stack_dynamic_input_binding=$NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUT_BINDING"
echo "[orchestrator] newsletter_cost_opt_stack_dynamic_inputs_needed=$NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUTS_NEEDED"
echo "[orchestrator] phase1b_reasoning_effort=${PHASE1B_REASONING_EFFORT:-<default>}"
echo "[orchestrator] phase3_compact_working_set=$PHASE3_COMPACT_WORKING_SET"
echo "[orchestrator] phase3_compact_working_set_policy=${PHASE3_COMPACT_WORKING_SET_POLICY:-<unset>}"
echo "[orchestrator] phase3_stdout_no_tools=$PHASE3_STDOUT_NO_TOOLS"

if [ "$RENDER_ONLY" != "1" ] && [ "$NO_REUSE" = "1" ]; then
  echo
  echo "[orchestrator] check=prepare_cycle (fail-fast)"
  bash tools/prepare_newsletter_cycle.sh "$START" "$END" --no-reuse 2>&1 | tee "$log_dir/prepare_cycle.log"
fi
if [ "$RENDER_ONLY" != "1" ]; then
  refresh_receipt_baseline
fi

CURATOR_REQUIRED=0
# Curator detection runs after prepare_cycle. Prep must retain raw note inputs.
if has_curator_notes; then
  CURATOR_REQUIRED=1
  echo "[orchestrator] curator-notes detected: phase1_5_curator enabled"
else
  echo "[orchestrator] curator-notes not detected: phase1_5_curator will be skipped"
fi

phase0_prompt="$prompt_dir/phase0_scope.prompt.md"
write_prompt "$phase0_prompt" "@customer_newsletter
Run only Phase 0 for DATE_RANGE $START to $END.
Use .github/skills/scope-contract/SKILL.md.
Do not edit repository source, tests, prompts, skills, config, kb, or planning files during this proof phase.
$phase_runtime_guard
First run: python3 tools/generate_scope_contract.py $START $END
If that helper succeeds, use its output as the Phase 0 artifact and do not spend time on broad manual archive or SOURCES discovery.
Only inspect additional sources if the helper reports missing required fields.
Do not edit workspace/newsletter_phase_receipts_${END}.json manually. Use tools/record_phase_receipt.sh only.
Create $scope_contract.
Record receipt phase0_scope_contract.
Stop immediately after Phase 0." 

phase1a_prompt="$prompt_dir/phase1a_manifest.prompt.md"
write_prompt "$phase1a_prompt" "@customer_newsletter
Run only Phase 1A for DATE_RANGE $START to $END.
Use .github/skills/url-manifest/SKILL.md.
Do not edit repository source, tests, prompts, skills, config, kb, or planning files during this proof phase.
$phase_runtime_guard
Treat $scope_contract as immutable; do not edit, rewrite, touch, or refresh any prior Phase 0 artifact.
Before writing $manifest, read $scope_contract and copy every expected_versions.vscode entry into the VS Code Release Notes Manifest.
If $scope_contract contains expected_versions.vscode_details, include each listed VS Code URL exactly, even when the live updates page sidebar or navigation omits a just-published version.
The scope contract is Phase 0 authority for Phase 1A; do not rely on the updates index sidebar alone when it disagrees with expected_versions.vscode_details.
Do not edit workspace/newsletter_phase_receipts_${END}.json manually. Use tools/record_phase_receipt.sh only.
Create $manifest.
Before recording the phase1a_manifest receipt, run: python3 tools/validate_phase1a_scope_alignment.py $START $END --prompt-file $phase1a_prompt
If that validator fails, repair $manifest so it includes every scope-contract VS Code version, then rerun the validator before recording the receipt.
Record receipt phase1a_manifest.
Stop immediately after Phase 1A." 

phase1b_prompt="$prompt_dir/phase1b_retrieval.prompt.md"
write_prompt "$phase1b_prompt" "@customer_newsletter
Run only Phase 1B for DATE_RANGE $START to $END.
Use .github/skills/content-retrieval/SKILL.md and input manifest $manifest.
Controlled delegation only: no generic or general-purpose subagents.
Do not edit repository source, tests, prompts, skills, config, kb, or planning files during this proof phase.
$phase_runtime_guard
Treat $scope_contract and $manifest as immutable; do not edit, rewrite, touch, or refresh prior Phase 0/1A artifacts.
Do not edit workspace/newsletter_phase_receipts_${END}.json manually. Use tools/record_phase_receipt.sh only.
Create all 5 canonical interim files:
- $phase1b_github
- $phase1b_vscode
- $phase1b_visualstudio
- $phase1b_jetbrains
- $phase1b_xcode
For the VS Code interim, read the scope contract's expected_versions.vscode array and explicitly preserve every version signal that appears in the manifest. If a version has no newsletter-worthy item, keep the version signal with a short no-material-change note rather than dropping it.
For the GitHub interim, preserve Copilot CLI release-tag URLs when they appear in the manifest or source retrieval; do not collapse all Copilot CLI coverage to only the releases index URL.
Record receipts phase1b_github, phase1b_vscode, phase1b_visualstudio, phase1b_jetbrains, phase1b_xcode.
Stop immediately after Phase 1B." 

phase1c_prompt="$prompt_dir/phase1c_consolidation.prompt.md"
write_prompt "$phase1c_prompt" "@customer_newsletter
Run only Phase 1C for DATE_RANGE $START to $END.
Use .github/skills/content-consolidation/SKILL.md and Phase 1B interim files.
Do not edit repository source, tests, prompts, skills, config, kb, or planning files during this proof phase.
$phase_runtime_guard
Treat all Phase 0, Phase 1A, and Phase 1B artifacts as immutable inputs; do not edit, rewrite, touch, or refresh them.
Preserve the scope contract's expected_versions.vscode values in the discoveries artifact when those version signals appear in Phase 1B. If a version is excluded from final selection, say why without dropping the version signal entirely.
Do not edit workspace/newsletter_phase_receipts_${END}.json manually. Use tools/record_phase_receipt.sh only.
Create $discoveries.
Record receipt phase1c_discoveries.
Stop immediately after Phase 1C." 

phase15_prompt="$prompt_dir/phase1_5_curator.prompt.md"
if [ "$CURATOR_REQUIRED" = "1" ]; then
  write_prompt "$phase15_prompt" "@editorial-analyst
Run only Phase 1.5 for DATE_RANGE $START to $END.
Use .github/skills/curator-notes/SKILL.md.
Discover notes from workspace/curator_notes_*.md and workspace/[A-Za-z]*.md (including workspace/Jan.md), excluding generated files.
Do not edit repository source, tests, prompts, skills, config, kb, or planning files during this proof phase.
$phase_runtime_guard
Treat all prior phase artifacts as immutable inputs; do not edit, rewrite, touch, or refresh them.
Do not edit workspace/newsletter_phase_receipts_${END}.json manually. Use tools/record_phase_receipt.sh only.
Create workspace/curator_notes_processed_${cycle_ym}.md and workspace/curator_notes_editorial_signals_${cycle_ym}.md.
Record receipts phase1_5_curator_processed and phase1_5_curator_signals.
Stop immediately after Phase 1.5." 
fi

phase2_prompt="$prompt_dir/phase2_events.prompt.md"
write_prompt "$phase2_prompt" "@customer_newsletter
Run only Phase 2 for DATE_RANGE $START to $END.
Use .github/skills/events-extraction/SKILL.md.
Do not edit repository source, tests, prompts, skills, config, kb, or planning files during this proof phase.
$phase_runtime_guard
First run: python3 tools/extract_event_sources.py $START $END
Treat all Phase 0, Phase 1A, Phase 1B, Phase 1C, and optional Phase 1.5 artifacts as immutable inputs; do not edit, rewrite, touch, or refresh them.
Do not edit workspace/newsletter_phase_receipts_${END}.json manually. Use tools/record_phase_receipt.sh only.
Create $phase2_event_sources and record receipt phase2_event_sources.
Then create $phase2_events with canonical headings and structure:
- ## Virtual Events
- ## In-Person Events
- ## Behind the scenes
Use deep-link event URLs only (no generic landing/search links).
Record receipt phase2_events.
Stop immediately after Phase 2." 

phase3_prompt="$prompt_dir/phase3_curation.prompt.md"
phase3_build_cmd="python3 tools/build_phase3_working_set.py $START $END"
phase3_init_cmd="python3 tools/init_phase3_curated_sections.py $START $END"
phase3_validate_cmd="python3 tools/validate_phase3_curated.py $START $END $phase3_curated --working-set $phase3_working_set"
if [ -n "$BENCHMARK_MODE" ]; then
  phase3_build_cmd="$phase3_build_cmd --benchmark-mode $BENCHMARK_MODE"
  phase3_init_cmd="$phase3_init_cmd --benchmark-mode $BENCHMARK_MODE"
  phase3_validate_cmd="$phase3_validate_cmd --benchmark-mode $BENCHMARK_MODE"
fi
if [ "$CURATOR_REQUIRED" = "1" ]; then
  write_prompt "$phase3_prompt" "@customer_newsletter
Run only Phase 3 for DATE_RANGE $START to $END.
Do not edit repository source, tests, prompts, skills, config, kb, or planning files during this proof phase.
$phase_runtime_guard
First run $phase3_build_cmd.
Run $phase3_init_cmd before writing if $phase3_curated does not exist.
Treat $phase3_working_set as the canonical compiled Phase 3 working state for this run.
Treat all Phase 0 through Phase 2 artifacts as immutable inputs; do not edit, rewrite, touch, or refresh them.
Read only:
- $phase3_working_set
- $phase3_curated
Only if $phase3_working_set contains [MISSING_DATA], read the exact missing file paths named there and then return to writing.
Do not open .github/skills/content-curation/*, raw discoveries, interim IDE files, curator notes, or reference/editorial-intelligence.md unless $phase3_working_set explicitly flags missing data.
Do not edit $phase3_working_set manually.
Do not edit workspace/newsletter_phase_receipts_${END}.json manually. Use tools/record_phase_receipt.sh only.
Record receipt phase3_working_set immediately after $phase3_build_cmd writes $phase3_working_set and before you read or edit $phase3_curated.
Edit $phase3_curated in place until all TODO markers are removed and the file contains real curated section content.
Run $phase3_validate_cmd before recording the receipt.
Record receipt phase3_curated only after the validator passes.
Stop immediately after Phase 3." 
else
  write_prompt "$phase3_prompt" "@customer_newsletter
Run only Phase 3 for DATE_RANGE $START to $END.
Do not edit repository source, tests, prompts, skills, config, kb, or planning files during this proof phase.
$phase_runtime_guard
First run $phase3_build_cmd.
Run $phase3_init_cmd before writing if $phase3_curated does not exist.
Treat $phase3_working_set as the canonical compiled Phase 3 working state for this run.
Treat all Phase 0 through Phase 2 artifacts as immutable inputs; do not edit, rewrite, touch, or refresh them.
Read only:
- $phase3_working_set
- $phase3_curated
Only if $phase3_working_set contains [MISSING_DATA], read the exact missing file paths named there and then return to writing.
Do not open .github/skills/content-curation/*, raw discoveries, interim IDE files, curator notes, or reference/editorial-intelligence.md unless $phase3_working_set explicitly flags missing data.
Do not edit $phase3_working_set manually.
Do not edit workspace/newsletter_phase_receipts_${END}.json manually. Use tools/record_phase_receipt.sh only.
Record receipt phase3_working_set immediately after $phase3_build_cmd writes $phase3_working_set and before you read or edit $phase3_curated.
Edit $phase3_curated in place until all TODO markers are removed and the file contains real curated section content.
Run $phase3_validate_cmd before recording the receipt.
Record receipt phase3_curated only after the validator passes.
Stop immediately after Phase 3." 
fi

phase4_prompt="$prompt_dir/phase4_assembly.prompt.md"
write_prompt "$phase4_prompt" "@customer_newsletter
Run only Phase 4 and post-assembly validation steps for DATE_RANGE $START to $END.
Use .github/skills/newsletter-assembly/SKILL.md, .github/skills/newsletter-polishing/SKILL.md, and .github/skills/video-matching/SKILL.md.
Do not edit repository source, tests, prompts, skills, config, kb, or planning files during this proof phase.
$phase_runtime_guard
Inputs: $phase3_curated and $phase2_events.
Treat all Phase 0 through Phase 3 artifacts as immutable inputs; do not rerun Phase 0/1A helpers, and do not edit, rewrite, touch, or refresh $scope_contract, $manifest, Phase 1B interims, $discoveries, $phase2_event_sources, $phase2_events, $phase3_working_set, or $phase3_curated.
Do not edit workspace/newsletter_phase_receipts_${END}.json manually. Use tools/record_phase_receipt.sh only.
Create $output_file.
If the GitHub interim includes Copilot CLI release-tag URLs, the final newsletter must include at least one concrete Copilot CLI release-tag URL in addition to any releases index URL.
Before treating the newsletter as final, apply this V2 quality checklist:
- Model availability/model update items are compressed to one main bullet.
- The lead or Copilot section includes at least one competitive/platform-choice signal when source material contains agent/provider choice.
- Main bullets retain nearby official source URLs; avoid linkless bold bullets.
- Preserve explicit VS Code release version signals from prior artifacts instead of collapsing them into a range that drops version tokens.
- Treat developer.microsoft.com, devblogs.microsoft.com, luma.com, and learn.github.com as legitimate recurring newsletter source domains, but do not use that domain correction to relax link density or source coverage.
Run a material Phase 4.5 polishing pass and produce a short report at $phase45_polishing_report.
Run a material Phase 4.6 video-matching pass using the video-matching skill and produce a short report at $phase46_video_report.
Only record receipt phase4_6_video after the final newsletter has been checked for real official video links or a truthful no-match result is documented in the report.
Record or refresh receipt phase4_output only after the newsletter content is final.
Record receipt phase4_5_polishing against $phase45_polishing_report.
Record receipt phase4_6_video against $phase46_video_report.
Run scope-contract post-validation by reading the existing immutable scope contract and final output, and create only $scope_results.
Record receipt phase4_scope_results.
Create editorial review artifact $editorial_review.
Record receipt phase4_editorial_review against $editorial_review.
Run validate_newsletter.sh on $output_file.
Stop after these outputs and receipts are complete." 

if [ "$RENDER_ONLY" = "1" ]; then
  cat > "$run_dir/summary.md" <<EOF
# Orchestrated Prompt Render Summary
- Run ID: $run_id
- Date Range: $START to $END
- Model: $MODEL
- Benchmark Mode: ${BENCHMARK_MODE:-none}
- Curator Required: $CURATOR_REQUIRED
- Prompts: $prompt_dir
- Phase Telemetry: $PHASE_TELEMETRY
- Proof Source Guard: $PROOF_SOURCE_GUARD
- Max Retries: $MAX_RETRIES
- Max Attempts: $MAX_ATTEMPTS
- Newsletter Cost Opt Stack: $NEWSLETTER_COST_OPT_STACK
- Newsletter Cost Opt Stack Default Source: ${NEWSLETTER_COST_OPT_STACK_DEFAULT_SOURCE:-none}
- Newsletter Cost Opt Stack Dynamic Input Binding: $NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUT_BINDING
- Newsletter Cost Opt Stack Dynamic Inputs Needed: $NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUTS_NEEDED
- Newsletter Cost Opt Stack Dynamic Inputs Built: $NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUTS_BUILT
- Phase 1B Reasoning Effort: ${PHASE1B_REASONING_EFFORT:-default}
- Phase 3 Compact Working Set: $PHASE3_COMPACT_WORKING_SET
- Phase 3 Compact Working Set Policy: ${PHASE3_COMPACT_WORKING_SET_POLICY:-none}
- Phase 3 Stdout/No-Tools: $PHASE3_STDOUT_NO_TOOLS
- Phase 3 Stdout/No-Tools V2 Fallback: $PHASE3_STDOUT_NO_TOOLS_V2_FALLBACK
- Phase 3 Stdout/No-Tools Fallback Used: $PHASE3_STDOUT_NO_TOOLS_FALLBACK_USED
EOF
  echo "[orchestrator] RENDER ONLY COMPLETE: prompts written to $prompt_dir"
  exit 0
fi

run_phase phase0_scope customer_newsletter "$PHASE_TIMEOUT_SECONDS" "$phase0_prompt" \
  "$scope_contract" "phase0_scope_contract"

run_phase phase1a_manifest customer_newsletter "$PHASE_TIMEOUT_SECONDS" "$phase1a_prompt" \
  "$manifest" "phase1a_manifest"

run_phase phase1b_retrieval customer_newsletter "$PHASE_TIMEOUT_SECONDS" "$phase1b_prompt" \
  "$phase1b_github;$phase1b_vscode;$phase1b_visualstudio;$phase1b_jetbrains;$phase1b_xcode" \
  "phase1b_github;phase1b_vscode;phase1b_visualstudio;phase1b_jetbrains;phase1b_xcode"

run_phase phase1c_consolidation customer_newsletter "$PHASE_TIMEOUT_SECONDS" "$phase1c_prompt" \
  "$discoveries" "phase1c_discoveries"

if [ "$CURATOR_REQUIRED" = "1" ]; then
  run_phase phase1_5_curator editorial-analyst "$PHASE_TIMEOUT_SECONDS" "$phase15_prompt" \
    "workspace/curator_notes_processed_${cycle_ym}.md;workspace/curator_notes_editorial_signals_${cycle_ym}.md" \
    "phase1_5_curator_processed;phase1_5_curator_signals"
else
  echo "[orchestrator] phase=phase1_5_curator skipped (no curator notes detected)"
fi

run_phase phase2_events customer_newsletter "$PHASE_TIMEOUT_SECONDS" "$phase2_prompt" \
  "$phase2_event_sources;$phase2_events" "phase2_event_sources;phase2_events"

if [ "$NEWSLETTER_COST_OPT_STACK" = "1" ]; then
  check_default_event_corpus_guard
fi

if [ "$NEWSLETTER_COST_OPT_STACK" = "1" ] && [ "$NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUTS_NEEDED" = "1" ]; then
  cost_stack_inputs_dir="${NEWSLETTER_COST_OPT_STACK_INPUT_BINDING_DIR:-$run_dir/$NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUT_OUTPUT_SUBDIR}"
  cost_stack_manifest_id="${NEWSLETTER_COST_OPT_STACK_INPUT_MANIFEST_ID:-${NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUT_MANIFEST_ID_PREFIX}_${START}_to_${END}}"
  echo
  echo "[orchestrator] building dynamic cost-stack inputs: $cost_stack_inputs_dir"
  if ! cost_stack_inputs_json="$(python3 tools/build_current_cycle_cost_stack_inputs.py \
    --start "$START" \
    --end "$END" \
    --source-root "$ROOT" \
    --output-dir "$cost_stack_inputs_dir" \
    --manifest-id "$cost_stack_manifest_id")"; then
    echo "[orchestrator] dynamic cost-stack input binding failed"
    exit 1
  fi
  if ! PHASE3_STDOUT_NO_TOOLS_MANIFEST="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["manifest"])' "$cost_stack_inputs_json")"; then
    echo "[orchestrator] dynamic cost-stack manifest parsing failed"
    exit 1
  fi
  if ! PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["admission"])' "$cost_stack_inputs_json")"; then
    echo "[orchestrator] dynamic cost-stack admission parsing failed"
    exit 1
  fi
  if [ ! -f "$PHASE3_STDOUT_NO_TOOLS_MANIFEST" ]; then
    echo "[orchestrator] dynamic cost-stack manifest missing after build: $PHASE3_STDOUT_NO_TOOLS_MANIFEST"
    exit 1
  fi
  if [ ! -f "$PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION" ]; then
    echo "[orchestrator] dynamic cost-stack no-refetch admission missing after build: $PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION"
    exit 1
  fi
  NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUTS_BUILT=1
fi

if [ "$PHASE3_STDOUT_NO_TOOLS" = "1" ]; then
  stdout_phase_timeout_seconds="${PHASE3_STDOUT_NO_TOOLS_TIMEOUT_SECONDS:-900}"
  if ! [[ "$stdout_phase_timeout_seconds" =~ ^[0-9]+$ ]]; then
    echo "[orchestrator] phase3 stdout/no-tools timeout must be numeric: $stdout_phase_timeout_seconds"
    exit 1
  fi
  if [ "$stdout_phase_timeout_seconds" -gt 900 ]; then
    echo "[orchestrator] phase3 stdout/no-tools timeout must be <= 900 seconds"
    exit 1
  fi
  echo
  echo "[orchestrator] phase=phase3_stdout_no_tools_artifact_reuse agent=$PHASE3_STDOUT_NO_TOOLS_AGENT timeout=${stdout_phase_timeout_seconds}s"
  if [ -z "$PHASE3_STDOUT_NO_TOOLS_MANIFEST" ] || [ ! -f "$PHASE3_STDOUT_NO_TOOLS_MANIFEST" ]; then
    echo "[orchestrator] phase3 stdout/no-tools manifest missing: ${PHASE3_STDOUT_NO_TOOLS_MANIFEST:-<unset>}"
    exit 1
  fi
  if [ -z "$PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION" ] || [ ! -f "$PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION" ]; then
    echo "[orchestrator] phase3 stdout/no-tools no-refetch admission missing: ${PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION:-<unset>}"
    exit 1
  fi
  if [ "$PHASE3_COMPACT_WORKING_SET" = "1" ]; then
    if [ -z "$PHASE3_COMPACT_WORKING_SET_POLICY" ] || [ ! -f "$PHASE3_COMPACT_WORKING_SET_POLICY" ]; then
      echo "[orchestrator] phase3 compact working-set policy missing: ${PHASE3_COMPACT_WORKING_SET_POLICY:-<unset>}"
      exit 1
    fi
  fi
  if ! check_receipt_drift "phase3_stdout_no_tools.pre"; then
    echo "[orchestrator] phase3 stdout/no-tools failed before execution because prior receipts drifted"
    exit 1
  fi
  phase3_stdout_compact_args=()
  if [ "$PHASE3_COMPACT_WORKING_SET" = "1" ]; then
    phase3_stdout_compact_args+=(--source-pruning-policy "$PHASE3_COMPACT_WORKING_SET_POLICY")
  fi
  stdout_run_dir="${PHASE3_STDOUT_NO_TOOLS_RUN_DIR:-$run_dir/phase3-stdout-no-tools}"
  stdout_v2_readiness_receipt="$stdout_run_dir/validation/phase3_v2_readiness.json"
  stdout_fallback_receipt="$stdout_run_dir/validation/phase3_stdout_no_tools_fallback_receipt.json"
  rm -f "$stdout_v2_readiness_receipt" "$stdout_fallback_receipt"
  phase3_stdout_rc=0
  if python3 tools/run_phase3_stdout_no_tools_artifact_reuse.py \
    --manifest "$PHASE3_STDOUT_NO_TOOLS_MANIFEST" \
    --surface-id phase2_entry_surface \
	    --target-repo "$ROOT" \
	    --model "$MODEL" \
	    --run-dir-override "$stdout_run_dir" \
	    --phase-timeout-seconds "$stdout_phase_timeout_seconds" \
    --agent "$PHASE3_STDOUT_NO_TOOLS_AGENT" \
    --available-tool "" \
    --no-refetch-admission "$PHASE3_STDOUT_NO_TOOLS_NO_REFETCH_ADMISSION" \
    --require-v2-readiness \
    --preserve-existing-provenance \
    "${phase3_stdout_compact_args[@]}" \
    --skip-materialize; then
    phase3_stdout_rc=0
  else
    phase3_stdout_rc=$?
  fi
  if [ "$PHASE_TELEMETRY" = "1" ] && [ -f "$stdout_run_dir/session/phase-session-metrics.jsonl" ]; then
    cat "$stdout_run_dir/session/phase-session-metrics.jsonl" >> "$phase_metrics_file"
  fi
  if [ "$phase3_stdout_rc" -ne 0 ]; then
    if phase3_stdout_v2_fallback_allowed "$stdout_v2_readiness_receipt"; then
      PHASE3_STDOUT_NO_TOOLS_FALLBACK_USED=1
      write_phase3_stdout_fallback_receipt "$stdout_fallback_receipt" "$stdout_v2_readiness_receipt" "$stdout_run_dir" "$phase3_stdout_rc"
      echo "[orchestrator] phase=phase3_stdout_no_tools_artifact_reuse V2 readiness failed; falling back to fuller Phase 3"
      refresh_receipt_baseline
      if ! run_phase phase3_curation customer_newsletter "$PHASE_TIMEOUT_SECONDS" "$phase3_prompt" \
        "$phase3_working_set;$phase3_curated" "phase3_working_set;phase3_curated"; then
        echo "[orchestrator] phase=phase3_curation fallback FAILED"
        exit 1
      fi
    else
      echo "[orchestrator] phase=phase3_stdout_no_tools_artifact_reuse FAILED"
      exit 1
    fi
  else
    if ! check_artifacts_and_receipts "phase3_stdout_no_tools_artifact_reuse" \
      "$phase3_working_set;$phase3_curated" "phase3_working_set;phase3_curated"; then
      echo "[orchestrator] phase3 stdout/no-tools artifact/receipt check failed"
      exit 1
    fi
    if ! check_receipt_drift "phase3_stdout_no_tools.post"; then
      echo "[orchestrator] phase3 stdout/no-tools post-receipt drift detected"
      exit 1
    fi
    if ! check_phase_specific_contracts "phase3_curation"; then
      echo "[orchestrator] phase3 stdout/no-tools curated artifact failed contract validation"
      exit 1
    fi
    refresh_receipt_baseline
    echo "[orchestrator] phase=phase3_stdout_no_tools_artifact_reuse PASS"
  fi
else
  run_phase phase3_curation customer_newsletter "$PHASE_TIMEOUT_SECONDS" "$phase3_prompt" \
    "$phase3_working_set;$phase3_curated" "phase3_working_set;phase3_curated"
fi

run_phase phase4_assembly customer_newsletter "$PHASE_TIMEOUT_SECONDS" "$phase4_prompt" \
  "$output_file;$phase45_polishing_report;$phase46_video_report;$scope_results;$editorial_review" "phase4_output;phase4_5_polishing;phase4_6_video;phase4_scope_results;phase4_editorial_review"

run_check validate_newsletter bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh "$output_file"
run_check score_structural bash tools/score-structural.sh
run_check score_heuristic bash tools/score-heuristic.sh
run_check score_v2_rubric bash tools/score-v2-rubric.sh --mode auto "$output_file"

strict_cmd=(bash tools/validate_pipeline_strict.sh "$START" "$END")
strict_cmd+=(--production-artifacts)
if [ "$NO_REUSE" = "1" ]; then
  strict_cmd+=(--require-fresh)
fi
if [ -n "$BENCHMARK_MODE" ]; then
  strict_cmd+=(--benchmark-mode "$BENCHMARK_MODE")
fi
run_check validate_pipeline_strict "${strict_cmd[@]}"
if ! check_default_amplification_fields; then
  CHECK_FAILURES=$((CHECK_FAILURES + 1))
  echo "[orchestrator] check=default_cost_stack_request_tool_amplification_fields FAIL"
else
  echo "[orchestrator] check=default_cost_stack_request_tool_amplification_fields PASS"
fi

echo
cat > "$run_dir/summary.md" <<EOF
# Orchestrated Run Summary
- Run ID: $run_id
- Date Range: $START to $END
- Model: $MODEL
- Benchmark Mode: ${BENCHMARK_MODE:-none}
- Output: $output_file
- Receipts: $receipt_file
- Logs: $log_dir
- Prompts: $prompt_dir
- Phase Telemetry: $PHASE_TELEMETRY
- Phase Session Metrics: $phase_metrics_file
- Proof Source Guard: $PROOF_SOURCE_GUARD
- Max Retries: $MAX_RETRIES
- Max Attempts: $MAX_ATTEMPTS
- Newsletter Cost Opt Stack: $NEWSLETTER_COST_OPT_STACK
- Newsletter Cost Opt Stack Default Source: ${NEWSLETTER_COST_OPT_STACK_DEFAULT_SOURCE:-none}
- Newsletter Cost Opt Stack Dynamic Input Binding: $NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUT_BINDING
- Newsletter Cost Opt Stack Dynamic Inputs Needed: $NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUTS_NEEDED
- Newsletter Cost Opt Stack Dynamic Inputs Built: $NEWSLETTER_COST_OPT_STACK_DYNAMIC_INPUTS_BUILT
- Phase 1B Reasoning Effort: ${PHASE1B_REASONING_EFFORT:-default}
- Phase 3 Compact Working Set: $PHASE3_COMPACT_WORKING_SET
- Phase 3 Compact Working Set Policy: ${PHASE3_COMPACT_WORKING_SET_POLICY:-none}
- Phase 3 Stdout/No-Tools: $PHASE3_STDOUT_NO_TOOLS
- Phase 3 Stdout/No-Tools V2 Fallback: $PHASE3_STDOUT_NO_TOOLS_V2_FALLBACK
- Phase 3 Stdout/No-Tools Fallback Used: $PHASE3_STDOUT_NO_TOOLS_FALLBACK_USED
- Check Failures: $CHECK_FAILURES
EOF

if [ "$CHECK_FAILURES" -ne 0 ]; then
  echo "[orchestrator] COMPLETE WITH FAILURES ($CHECK_FAILURES checks failed): see $run_dir/summary.md"
  exit 1
fi

echo "[orchestrator] COMPLETE: see $run_dir/summary.md"

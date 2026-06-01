#!/usr/bin/env bash
# Stage 16 fast closure runner: execute only the frozen-input Phase 4 path.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

START="${1:-}"
END="${2:-}"

if [ -z "$START" ] || [ -z "$END" ]; then
  echo "Usage: bash tools/run_newsletter_phase4_fast.sh <START_DATE> <END_DATE>"
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
PHASE_TIMEOUT_SECONDS="${PHASE_TIMEOUT_SECONDS:-900}"
BENCHMARK_MODE="${BENCHMARK_MODE:-}"
RUN_DIR_OVERRIDE="${RUN_DIR_OVERRIDE:-}"

if [ -n "$PHASE_TIMEOUT_SECONDS" ] && [ "$PHASE_TIMEOUT_SECONDS" -gt 900 ]; then
  echo "ERROR: PHASE_TIMEOUT_SECONDS must be <= 900 for Stage 16 fast closure"
  exit 1
fi

if [ -z "$BENCHMARK_MODE" ] && [ "$START" = "2025-12-05" ] && [ "$END" = "2026-02-13" ]; then
  BENCHMARK_MODE="feb2026_consistency"
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found"
  exit 1
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

run_id="$(date -u +%Y%m%dT%H%M%SZ)"
if [ -n "$RUN_DIR_OVERRIDE" ]; then
  run_dir="$RUN_DIR_OVERRIDE"
else
  run_dir="runs/stage16-fast/${run_id}_${START}_to_${END}"
fi
prompt_dir="$run_dir/prompts"
log_dir="$run_dir/logs"
session_dir="$run_dir/session"
mkdir -p "$prompt_dir" "$log_dir" "$session_dir" runs/stage16-fast

phase2_events="workspace/newsletter_phase2_events_${END}.md"
phase3_curated="workspace/newsletter_phase3_curated_sections_${END}.md"
phase3_working_set="workspace/newsletter_phase3_working_set_${END}.md"
scope_contract="workspace/newsletter_scope_contract_${END}.json"
scope_results="workspace/newsletter_scope_results_${END}.md"
receipt_file="workspace/newsletter_phase_receipts_${END}.json"
marker_file="workspace/newsletter_run_marker_${START}_to_${END}.json"
cycle_ym="$(echo "$END" | cut -d- -f1-2)"
editorial_review="workspace/${cycle_ym}_editorial_review.md"
phase45_polishing_report="workspace/newsletter_phase4_5_polishing_${END}.md"

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

phase_mode="copilot_phase4"
phase4_prompt=""

# Stage 16 admits a deterministic closure path only for the fixed February
# 2026 benchmark window. All other ranges continue to use the bounded agent
# runner so the reduced proof surface stays explicit and narrowly scoped.
if [ "$START" = "2025-12-05" ] && [ "$END" = "2026-02-13" ] && [ "$BENCHMARK_MODE" = "feb2026_consistency" ]; then
  phase_mode="deterministic_stage16_seed"
elif [ ! -x "$COPILOT_BIN" ]; then
  echo "ERROR: copilot CLI not found or not executable: $COPILOT_BIN"
  exit 1
fi

for required in "$phase2_events" "$phase3_curated" "$phase3_working_set" "$scope_contract" "$marker_file" "$receipt_file"; do
  if [ ! -f "$required" ]; then
    echo "ERROR: required frozen-input artifact missing: $required"
    exit 1
  fi
done

phase3_validate_cmd=(python3 tools/validate_phase3_curated.py "$START" "$END" "$phase3_curated" --working-set "$phase3_working_set")
if [ -n "$BENCHMARK_MODE" ]; then
  phase3_validate_cmd+=(--benchmark-mode "$BENCHMARK_MODE")
fi

echo "[stage16-fast] validating frozen Phase 3 inputs"
"${phase3_validate_cmd[@]}"

echo "[stage16-fast] refreshing phase3_working_set receipt on frozen inputs"
bash tools/record_phase_receipt.sh "$START" "$END" phase3_working_set "$phase3_working_set" >/dev/null

echo "[stage16-fast] refreshing phase3_curated receipt on frozen inputs"
bash tools/record_phase_receipt.sh "$START" "$END" phase3_curated "$phase3_curated" >/dev/null

rm -f "$output_file" "$phase45_polishing_report" "$scope_results" "$editorial_review"

normalize_receipt_if_present() {
  local phase_id="$1"
  local artifact="$2"
  if [ -s "$artifact" ]; then
    echo "[stage16-fast] recording receipt: $phase_id ($artifact)"
    bash tools/record_phase_receipt.sh "$START" "$END" "$phase_id" "$artifact" >/dev/null
  fi
}

log_file="$log_dir/phase4_assembly_fast.log"

if [ "$phase_mode" = "deterministic_stage16_seed" ]; then
  echo "[stage16-fast] rendering deterministic Stage 16 Phase 4 closure path"
  set +e
  python3 tools/render_stage16_fast_newsletter.py "$START" "$END" --benchmark-mode "$BENCHMARK_MODE" >"$log_file" 2>&1
  phase_rc=$?
  set -e
else
  phase4_prompt="$prompt_dir/phase4_assembly_fast.prompt.md"
  cat > "$phase4_prompt" <<EOF
@customer_newsletter
Run only the bounded Stage 16 Phase 4 closure path for DATE_RANGE $START to $END.
Use .github/skills/newsletter-assembly/SKILL.md and .github/skills/newsletter-polishing/SKILL.md.
Read only:
- $phase2_events
- $phase3_curated
- $scope_contract
Do not reopen phases 0-3. Do not inspect archive/, benchmark/, or raw discovery files.
Do not edit $phase3_curated or $phase3_working_set.
Do not edit workspace/newsletter_phase_receipts_${END}.json manually. Use tools/record_phase_receipt.sh only.
Create $output_file from the frozen Phase 2 / Phase 3 inputs.
Record receipt phase4_output immediately after $output_file exists and before any scope-results receipt.
Create $phase45_polishing_report and record receipt phase4_5_polishing.
Create $scope_results and record receipt phase4_scope_results only after $output_file exists.
Create $editorial_review and record receipt phase4_editorial_review.
Run bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh $output_file before stopping.
Stop immediately after the validator passes and the four Phase 4 receipts are recorded.
EOF

  echo "[stage16-fast] running bounded Phase 4 closure path"
  phase_cmd=(
    python3 tools/run_copilot_phase.py
    --agent customer_newsletter
    --model "$MODEL"
    --copilot-bin "$COPILOT_BIN"
    --prompt-file "$phase4_prompt"
    --log "$log_file"
    --timeout "$PHASE_TIMEOUT_SECONDS"
    --cwd "$ROOT"
    --phase-id phase4_fast
    --session-out "$session_dir/events.jsonl"
    --metrics-out "$session_dir/phase-session-metrics.jsonl"
    --artifact-path "$output_file"
    --artifact-path "$phase45_polishing_report"
    --artifact-path "$scope_results"
    --artifact-path "$editorial_review"
    --receipt-id phase4_output
    --receipt-id phase4_5_polishing
    --receipt-id phase4_scope_results
    --receipt-id phase4_editorial_review
  )
  if [ "${PHASE_REQUIRE_SESSION_LOG:-}" = "1" ]; then
    phase_cmd+=(--require-session-log)
  fi
  if [ "${PHASE_REQUIRE_DIRECT_TOKEN_FIELDS:-0}" = "1" ]; then
    phase_cmd+=(--require-direct-token-fields)
  fi
  set +e
  "${phase_cmd[@]}"
  phase_rc=$?
  set -e
fi

if [ "$phase_rc" -eq 0 ]; then
  echo "[stage16-fast] validating rendered newsletter"
  if ! bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh "$output_file" >>"$log_file" 2>&1; then
    echo "[stage16-fast] validation failed; see $log_file"
    exit 1
  fi
fi

normalize_receipt_if_present "phase4_output" "$output_file"
normalize_receipt_if_present "phase4_5_polishing" "$phase45_polishing_report"
normalize_receipt_if_present "phase4_scope_results" "$scope_results"
normalize_receipt_if_present "phase4_editorial_review" "$editorial_review"

cat > "$run_dir/summary.md" <<EOF
# Stage 16 Fast Phase 4 Summary
- Run ID: $run_id
- Date Range: $START to $END
- Model: $MODEL
- Copilot Bin: $COPILOT_BIN
- Benchmark Mode: ${BENCHMARK_MODE:-none}
- Phase 4 Mode: $phase_mode
- Phase 4 Return Code: $phase_rc
- Output: $output_file
- Receipts: $receipt_file
- Logs: $log_dir
- Prompt: ${phase4_prompt:-deterministic_stage16_seed}
- Session Metrics: $session_dir/phase-session-metrics.jsonl
EOF

if [ "$phase_rc" -ne 0 ]; then
  echo "[stage16-fast] Phase 4 runner failed (exit $phase_rc); see $log_file"
  exit "$phase_rc"
fi

for expected in "$output_file" "$phase45_polishing_report" "$scope_results" "$editorial_review"; do
  if [ ! -s "$expected" ]; then
    echo "[stage16-fast] missing expected Phase 4 artifact: $expected"
    exit 1
  fi
done

echo "[stage16-fast] Phase 4 fast path complete: see $run_dir/summary.md"

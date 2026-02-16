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

MODEL="${MODEL:-claude-opus-4.6}"
NO_REUSE="${NO_REUSE:-1}"
MAX_RETRIES="${MAX_RETRIES:-2}"
PHASE_TIMEOUT_SECONDS="${PHASE_TIMEOUT_SECONDS:-1800}"
BENCHMARK_MODE="${BENCHMARK_MODE:-}"

if [ -z "$BENCHMARK_MODE" ] && [ "$START" = "2025-12-05" ] && [ "$END" = "2026-02-13" ]; then
  BENCHMARK_MODE="feb2026_consistency"
fi

if ! command -v copilot >/dev/null 2>&1; then
  echo "ERROR: copilot CLI not found"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found"
  exit 1
fi

run_id="$(date -u +%Y%m%dT%H%M%SZ)"
run_dir="runs/orchestrated/${run_id}_${START}_to_${END}"
prompt_dir="$run_dir/prompts"
log_dir="$run_dir/logs"
mkdir -p "$prompt_dir" "$log_dir"

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
scope_contract="workspace/newsletter_scope_contract_${END}.json"
scope_results="workspace/newsletter_scope_results_${END}.md"
receipt_file="workspace/newsletter_phase_receipts_${END}.json"
cycle_ym="$(echo "$END" | cut -d- -f1-2)"
editorial_review="workspace/${cycle_ym}_editorial_review.md"
phase45_polishing_report="workspace/newsletter_phase4_5_polishing_${END}.md"
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

required = {"artifact_sha256", "artifact_mtime_epoch", "recorded_at_epoch"}
for r in payload.get("receipts", []):
    if r.get("phase_id") != phase_id:
        continue
    if all(k in r and r.get(k) not in (None, "") for k in required):
        raise SystemExit(0)
    raise SystemExit(1)
raise SystemExit(1)
PY
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

  local attempt=1
  while [ "$attempt" -le "$MAX_RETRIES" ]; do
    local log_file="$log_dir/${phase_name}.attempt${attempt}.log"
    echo
    echo "[orchestrator] phase=$phase_name agent=$agent_name attempt=$attempt timeout=${timeout_s}s"

    if python3 tools/run_copilot_phase.py \
      --agent "$agent_name" \
      --model "$MODEL" \
      --prompt-file "$prompt_file" \
      --log "$log_file" \
      --timeout "$timeout_s" \
      --cwd "$ROOT"; then
      normalize_receipts "$phase_name" "$artifacts_csv" "$receipts_csv"
      if check_artifacts_and_receipts "$phase_name" "$artifacts_csv" "$receipts_csv"; then
        echo "[orchestrator] phase=$phase_name PASS"
        return 0
      else
        echo "[orchestrator] phase=$phase_name artifact/receipt check failed"
      fi
    else
      echo "[orchestrator] phase=$phase_name copilot execution failed (see $log_file)"
    fi

    attempt=$((attempt + 1))
    if [ "$attempt" -le "$MAX_RETRIES" ]; then
      echo "[orchestrator] phase=$phase_name retrying..."
      sleep 3
    fi
  done

  echo "[orchestrator] phase=$phase_name FAILED after ${MAX_RETRIES} attempts"
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

write_prompt() {
  local file="$1"
  shift
  cat > "$file" <<EOF
$*
EOF
}

echo "[orchestrator] run_id=$run_id"
echo "[orchestrator] date_range=$START to $END"
echo "[orchestrator] model=$MODEL"
echo "[orchestrator] benchmark_mode=${BENCHMARK_MODE:-<none>}"

if [ "$NO_REUSE" = "1" ]; then
  echo
  echo "[orchestrator] check=prepare_cycle (fail-fast)"
  bash tools/prepare_newsletter_cycle.sh "$START" "$END" --no-reuse 2>&1 | tee "$log_dir/prepare_cycle.log"
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
Do not edit workspace/newsletter_phase_receipts_${END}.json manually. Use tools/record_phase_receipt.sh only.
Create $scope_contract.
Record receipt phase0_scope_contract.
Stop immediately after Phase 0." 

phase1a_prompt="$prompt_dir/phase1a_manifest.prompt.md"
write_prompt "$phase1a_prompt" "@customer_newsletter
Run only Phase 1A for DATE_RANGE $START to $END.
Use .github/skills/url-manifest/SKILL.md.
Do not edit workspace/newsletter_phase_receipts_${END}.json manually. Use tools/record_phase_receipt.sh only.
Create $manifest.
Record receipt phase1a_manifest.
Stop immediately after Phase 1A." 

phase1b_prompt="$prompt_dir/phase1b_retrieval.prompt.md"
write_prompt "$phase1b_prompt" "@customer_newsletter
Run only Phase 1B for DATE_RANGE $START to $END.
Use .github/skills/content-retrieval/SKILL.md and input manifest $manifest.
Controlled delegation only: no generic or general-purpose subagents.
Do not edit workspace/newsletter_phase_receipts_${END}.json manually. Use tools/record_phase_receipt.sh only.
Create all 5 canonical interim files:
- $phase1b_github
- $phase1b_vscode
- $phase1b_visualstudio
- $phase1b_jetbrains
- $phase1b_xcode
Record receipts phase1b_github, phase1b_vscode, phase1b_visualstudio, phase1b_jetbrains, phase1b_xcode.
Stop immediately after Phase 1B." 

phase1c_prompt="$prompt_dir/phase1c_consolidation.prompt.md"
write_prompt "$phase1c_prompt" "@editorial-analyst
Run only Phase 1C for DATE_RANGE $START to $END.
Use .github/skills/content-consolidation/SKILL.md and Phase 1B interim files.
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
Do not edit workspace/newsletter_phase_receipts_${END}.json manually. Use tools/record_phase_receipt.sh only.
Create workspace/curator_notes_processed_${cycle_ym}.md and workspace/curator_notes_editorial_signals_${cycle_ym}.md.
Record receipts phase1_5_curator_processed and phase1_5_curator_signals.
Stop immediately after Phase 1.5." 
fi

phase2_prompt="$prompt_dir/phase2_events.prompt.md"
write_prompt "$phase2_prompt" "@customer_newsletter
Run only Phase 2 for DATE_RANGE $START to $END.
Use .github/skills/events-extraction/SKILL.md.
First run: python3 tools/extract_event_sources.py $START $END
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
if [ "$CURATOR_REQUIRED" = "1" ]; then
  write_prompt "$phase3_prompt" "@editorial-analyst
Run only Phase 3 for DATE_RANGE $START to $END.
Use .github/skills/content-curation/SKILL.md, input $discoveries, and curator signals from workspace/curator_notes_editorial_signals_${cycle_ym}.md.
Do not edit workspace/newsletter_phase_receipts_${END}.json manually. Use tools/record_phase_receipt.sh only.
Create $phase3_curated.
Record receipt phase3_curated.
Stop immediately after Phase 3." 
else
  write_prompt "$phase3_prompt" "@editorial-analyst
Run only Phase 3 for DATE_RANGE $START to $END.
Use .github/skills/content-curation/SKILL.md and input $discoveries.
Do not edit workspace/newsletter_phase_receipts_${END}.json manually. Use tools/record_phase_receipt.sh only.
Create $phase3_curated.
Record receipt phase3_curated.
Stop immediately after Phase 3." 
fi

phase4_prompt="$prompt_dir/phase4_assembly.prompt.md"
write_prompt "$phase4_prompt" "@customer_newsletter
Run only Phase 4 and post-assembly validation steps for DATE_RANGE $START to $END.
Use .github/skills/newsletter-assembly/SKILL.md and .github/skills/newsletter-polishing/SKILL.md.
Inputs: $phase3_curated and $phase2_events.
Do not edit workspace/newsletter_phase_receipts_${END}.json manually. Use tools/record_phase_receipt.sh only.
Create $output_file.
Record receipt phase4_output.
Run a material Phase 4.5 polishing pass and produce a short report at $phase45_polishing_report.
Record receipt phase4_5_polishing against $phase45_polishing_report.
Run scope-contract post-validation and create $scope_results.
Record receipt phase4_scope_results.
Create editorial review artifact $editorial_review.
Record receipt phase4_editorial_review against $editorial_review.
Run validate_newsletter.sh on $output_file.
Stop after these outputs and receipts are complete." 

run_phase phase0_scope customer_newsletter "$PHASE_TIMEOUT_SECONDS" "$phase0_prompt" \
  "$scope_contract" "phase0_scope_contract"

run_phase phase1a_manifest customer_newsletter "$PHASE_TIMEOUT_SECONDS" "$phase1a_prompt" \
  "$manifest" "phase1a_manifest"

run_phase phase1b_retrieval customer_newsletter "$PHASE_TIMEOUT_SECONDS" "$phase1b_prompt" \
  "$phase1b_github;$phase1b_vscode;$phase1b_visualstudio;$phase1b_jetbrains;$phase1b_xcode" \
  "phase1b_github;phase1b_vscode;phase1b_visualstudio;phase1b_jetbrains;phase1b_xcode"

run_phase phase1c_consolidation editorial-analyst "$PHASE_TIMEOUT_SECONDS" "$phase1c_prompt" \
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

run_phase phase3_curation editorial-analyst "$PHASE_TIMEOUT_SECONDS" "$phase3_prompt" \
  "$phase3_curated" "phase3_curated"

run_phase phase4_assembly customer_newsletter "$PHASE_TIMEOUT_SECONDS" "$phase4_prompt" \
  "$output_file;$phase45_polishing_report;$scope_results;$editorial_review" "phase4_output;phase4_5_polishing;phase4_scope_results;phase4_editorial_review"

run_check validate_newsletter bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh "$output_file"
run_check score_structural bash tools/score-structural.sh
run_check score_heuristic bash tools/score-heuristic.sh
run_check score_v2_rubric bash tools/score-v2-rubric.sh "$output_file"

strict_cmd=(bash tools/validate_pipeline_strict.sh "$START" "$END")
if [ "$NO_REUSE" = "1" ]; then
  strict_cmd+=(--require-fresh)
fi
if [ -n "$BENCHMARK_MODE" ]; then
  strict_cmd+=(--benchmark-mode "$BENCHMARK_MODE")
fi
run_check validate_pipeline_strict "${strict_cmd[@]}"

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
- Check Failures: $CHECK_FAILURES
EOF

if [ "$CHECK_FAILURES" -ne 0 ]; then
  echo "[orchestrator] COMPLETE WITH FAILURES ($CHECK_FAILURES checks failed): see $run_dir/summary.md"
  exit 1
fi

echo "[orchestrator] COMPLETE: see $run_dir/summary.md"

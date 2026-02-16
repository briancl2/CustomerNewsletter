#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

usage() {
  cat <<'USAGE'
Usage: bash tools/prepare_newsletter_cycle.sh <START_DATE> <END_DATE> [--no-reuse]

Prepares a cycle run marker and optionally archives existing cycle artifacts so the
next run is clean-from-scratch.

Examples:
  bash tools/prepare_newsletter_cycle.sh 2025-12-05 2026-02-13
  bash tools/prepare_newsletter_cycle.sh 2025-12-05 2026-02-13 --no-reuse
USAGE
}

if [ "$#" -lt 2 ]; then
  usage
  exit 1
fi

START="$1"
END="$2"
NO_REUSE=0

if [ "${3:-}" = "--no-reuse" ]; then
  NO_REUSE=1
fi

if ! [[ "$START" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: START_DATE must be YYYY-MM-DD, got: $START"
  exit 1
fi
if ! [[ "$END" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: END_DATE must be YYYY-MM-DD, got: $END"
  exit 1
fi

month_name_from_end() {
  local month
  month="$(echo "$END" | cut -d- -f2)"
  case "$month" in
    01) echo "january" ;;
    02) echo "february" ;;
    03) echo "march" ;;
    04) echo "april" ;;
    05) echo "may" ;;
    06) echo "june" ;;
    07) echo "july" ;;
    08) echo "august" ;;
    09) echo "september" ;;
    10) echo "october" ;;
    11) echo "november" ;;
    12) echo "december" ;;
    *) echo "unknown" ;;
  esac
}

year="$(echo "$END" | cut -d- -f1)"
month="$(echo "$END" | cut -d- -f2)"
cycle_ym="${year}-${month}"
month_name="$(month_name_from_end)"
output_file="output/${year}-${month}_${month_name}_newsletter.md"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
run_id="${timestamp}-$$"
prepared_epoch="$(date +%s)"
cycle="${START}_to_${END}"
marker="workspace/newsletter_run_marker_${cycle}.json"

mkdir -p workspace workspace/archived/preflight

if [ "$NO_REUSE" -eq 1 ]; then
  archive_dir="workspace/archived/preflight/${cycle}_${timestamp}"
  mkdir -p "$archive_dir"

  echo "Preparing clean cycle (no-reuse): $cycle"
  echo "Archive dir: $archive_dir"

  patterns=(
    "workspace/newsletter_phase1a_url_manifest_${START}_to_${END}.md"
    "workspace/newsletter_phase1a_discoveries_${START}_to_${END}.md"
    "workspace/newsletter_phase1b_interim_github_${START}_to_${END}.md"
    "workspace/newsletter_phase1b_interim_vscode_${START}_to_${END}.md"
    "workspace/newsletter_phase1b_interim_visualstudio_${START}_to_${END}.md"
    "workspace/newsletter_phase1b_interim_jetbrains_${START}_to_${END}.md"
    "workspace/newsletter_phase1b_interim_xcode_${START}_to_${END}.md"
    "workspace/newsletter_phase2_event_sources_${END}.json"
    "workspace/newsletter_phase2_events_${END}.md"
    "workspace/newsletter_phase3_curated_sections_${END}.md"
    "workspace/curator_notes_processed_${year}-${month}.md"
    "workspace/curator_notes_editorial_signals_${year}-${month}.md"
    "workspace/newsletter_scope_contract_${END}.json"
    "workspace/newsletter_scope_results_${END}.md"
    "workspace/newsletter_pipeline_contract_${END}.md"
    "workspace/newsletter_phase_receipts_${END}.json"
    "workspace/fresh_phase1a_url_manifest_${START}_to_${END}.md"
    "workspace/fresh_phase1c_discoveries_${START}_to_${END}.md"
    "workspace/${cycle_ym}_editorial_review.md"
    "workspace/${cycle_ym}_editorial_corrections.md"
  )

  moved=0
  for pattern in "${patterns[@]}"; do
    while IFS= read -r file; do
      [ -z "$file" ] && continue
      mv "$file" "$archive_dir/"
      moved=$((moved + 1))
    done < <(compgen -G "$pattern" || true)
  done

  if [ -f "$output_file" ]; then
    mv "$output_file" "$archive_dir/$(basename "$output_file" .md)_preflight_prev.md"
    moved=$((moved + 1))
  fi

  echo "Archived ${moved} cycle artifact(s)."
else
  echo "Preparing cycle marker only (reuse allowed): $cycle"
fi

cat > "$marker" <<EOF
{
  "marker_version": 2,
  "run_id": "$run_id",
  "start": "$START",
  "end": "$END",
  "prepared_at_utc": "$timestamp",
  "prepared_at_epoch": $prepared_epoch,
  "no_reuse": $NO_REUSE
}
EOF

echo "Run marker written: $marker"
echo "Run ID: $run_id"
echo "Next: run the pipeline prompt for ${START} to ${END}, then enforce strict validation:"
echo "  bash tools/validate_pipeline_strict.sh ${START} ${END} $([ "$NO_REUSE" -eq 1 ] && echo "--require-fresh")"
echo "Done."

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

is_current_cycle_workspace_file() {
  local name="$1"
  case "$name" in
    "newsletter_phase1a_url_manifest_${START}_to_${END}.md"|\
    "newsletter_phase1a_discoveries_${START}_to_${END}.md"|\
    "newsletter_phase1b_interim_github_${START}_to_${END}.md"|\
    "newsletter_phase1b_interim_vscode_${START}_to_${END}.md"|\
    "newsletter_phase1b_vscode_theme_summary_${START}_to_${END}.md"|\
    "newsletter_phase1b_interim_visualstudio_${START}_to_${END}.md"|\
    "newsletter_phase1b_interim_jetbrains_${START}_to_${END}.md"|\
    "newsletter_phase1b_interim_xcode_${START}_to_${END}.md"|\
    "newsletter_phase2_event_sources_${END}.json"|\
    "newsletter_phase2_events_${END}.md"|\
    "newsletter_phase2_selected_source_ids_${END}.json"|\
    "newsletter_phase2_fetch_attempt_ledger_${END}.json"|\
    "newsletter_phase2_no_refetch_compliance_${END}.json"|\
    "newsletter_phase3_curated_sections_${END}.md"|\
    "newsletter_phase3_working_set_${END}.md"|\
    "newsletter_phase3_capability_map_${START}_to_${END}.json"|\
    "copilot_cli_release_inventory_${START}_to_${END}.md"|\
    "copilot_app_release_inventory_${START}_to_${END}.md"|\
    "${cycle_ym}_cli_release_inventory.md"|\
    "${cycle_ym}_copilot_app_release_inventory.md"|\
    "${cycle_ym}_cli_app_capability_map.md"|\
    "newsletter_scope_contract_${END}.json"|\
    "newsletter_scope_results_${END}.md"|\
    "newsletter_pipeline_contract_${END}.md"|\
    "newsletter_phase_receipts_${END}.json"|\
    "newsletter_phase4_5_polishing_${END}.md"|\
    "newsletter_phase4_6_video_matches_${END}.md"|\
    "newsletter_run_marker_${START}_to_${END}.json"|\
    "${cycle_ym}_editorial_review.md"|\
    "${cycle_ym}_editorial_corrections.md"|\
    "curator_notes_processed_${year}-${month}.md"|\
    "curator_notes_editorial_signals_${year}-${month}.md")
      return 0
      ;;
  esac
  return 1
}

is_cycle_scoped_workspace_file() {
  local name="$1"
  case "$name" in
    newsletter_phase1a_url_manifest_*_to_*.md|\
    newsletter_phase1a_discoveries_*_to_*.md|\
    newsletter_phase1b_interim_*.md|\
    newsletter_phase1b_vscode_theme_summary_*_to_*.md|\
    newsletter_phase2_event_sources_*.json|\
    newsletter_phase2_events_*.md|\
    newsletter_phase2_selected_source_ids_*.json|\
    newsletter_phase2_fetch_attempt_ledger_*.json|\
    newsletter_phase2_no_refetch_compliance_*.json|\
    newsletter_phase3_curated_sections_*.md|\
    newsletter_phase3_working_set_*.md|\
    newsletter_phase3_capability_map_*_to_*.json|\
    copilot_cli_release_inventory_*_to_*.md|\
    copilot_app_release_inventory_*_to_*.md|\
    [0-9][0-9][0-9][0-9]-[0-9][0-9]_cli_release_inventory.md|\
    [0-9][0-9][0-9][0-9]-[0-9][0-9]_copilot_app_release_inventory.md|\
    [0-9][0-9][0-9][0-9]-[0-9][0-9]_cli_app_capability_map.md|\
    newsletter_scope_contract_*.json|\
    newsletter_scope_results_*.md|\
    newsletter_pipeline_contract_*.md|\
    newsletter_phase_receipts_*.json|\
    newsletter_phase4_5_polishing_*.md|\
    newsletter_phase4_6_video_matches_*.md|\
    newsletter_run_marker_*_to_*.json|\
    [0-9][0-9][0-9][0-9]-[0-9][0-9]_editorial_review.md|\
    [0-9][0-9][0-9][0-9]-[0-9][0-9]_editorial_corrections.md|\
    curator_notes_processed_*.md|\
    curator_notes_editorial_signals_*.md)
      return 0
      ;;
  esac
  return 1
}

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
    "workspace/newsletter_phase1b_vscode_theme_summary_${START}_to_${END}.md"
    "workspace/newsletter_phase1b_interim_visualstudio_${START}_to_${END}.md"
    "workspace/newsletter_phase1b_interim_jetbrains_${START}_to_${END}.md"
    "workspace/newsletter_phase1b_interim_xcode_${START}_to_${END}.md"
    "workspace/newsletter_phase2_event_sources_${END}.json"
    "workspace/newsletter_phase2_events_${END}.md"
    "workspace/newsletter_phase2_selected_source_ids_${END}.json"
    "workspace/newsletter_phase2_fetch_attempt_ledger_${END}.json"
    "workspace/newsletter_phase2_no_refetch_compliance_${END}.json"
    "workspace/newsletter_phase3_curated_sections_${END}.md"
    "workspace/newsletter_phase3_working_set_${END}.md"
    "workspace/newsletter_phase3_capability_map_${START}_to_${END}.json"
    "workspace/copilot_cli_release_inventory_${START}_to_${END}.md"
    "workspace/copilot_app_release_inventory_${START}_to_${END}.md"
    "workspace/${cycle_ym}_cli_release_inventory.md"
    "workspace/${cycle_ym}_copilot_app_release_inventory.md"
    "workspace/${cycle_ym}_cli_app_capability_map.md"
    "workspace/curator_notes_processed_${year}-${month}.md"
    "workspace/curator_notes_editorial_signals_${year}-${month}.md"
    "workspace/newsletter_scope_contract_${END}.json"
    "workspace/newsletter_scope_results_${END}.md"
    "workspace/newsletter_pipeline_contract_${END}.md"
    "workspace/newsletter_phase_receipts_${END}.json"
    "workspace/newsletter_phase4_5_polishing_${END}.md"
    "workspace/newsletter_phase4_6_video_matches_${END}.md"
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

  foreign_dir="${archive_dir}/foreign_range_workspace"
  foreign=0
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    base="$(basename "$file")"
    if is_cycle_scoped_workspace_file "$base" && ! is_current_cycle_workspace_file "$base"; then
      mkdir -p "$foreign_dir"
      mv "$file" "$foreign_dir/"
      foreign=$((foreign + 1))
    fi
  done < <(find workspace -maxdepth 1 -type f | sort)

  if [ "$foreign" -gt 0 ]; then
    echo "Quarantined ${foreign} foreign-range workspace artifact(s)."
  else
    echo "No foreign-range workspace artifacts found."
  fi
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

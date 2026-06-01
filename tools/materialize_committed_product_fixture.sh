#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: bash tools/materialize_committed_product_fixture.sh START END DEST_ROOT"
  echo "Optional env: NEWSLETTER_PRODUCT_FIXTURE_SOURCE_REF=<git-ref> (default: HEAD)"
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

START="$1"
END="$2"
DEST_ROOT="$3"
SOURCE_REF="${NEWSLETTER_PRODUCT_FIXTURE_SOURCE_REF:-HEAD}"

if ! git rev-parse --verify --quiet "$SOURCE_REF^{tree}" >/dev/null; then
  echo "ERROR: fixture source ref is not a tree: $SOURCE_REF"
  exit 1
fi

year="$(echo "$END" | cut -d- -f1)"
month="$(echo "$END" | cut -d- -f2)"
cycle_ym="${year}-${month}"

month_name_from_num() {
  case "$1" in
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

month_name="$(month_name_from_num "$month")"
workspace_dest="$DEST_ROOT/workspace"
output_dest="$DEST_ROOT/output"

mkdir -p "$workspace_dest" "$output_dest"

copy_from_ref() {
  local source_path="$1"
  local dest_dir="$2"
  local dest_path="$dest_dir/$(basename "$source_path")"
  if ! git cat-file -e "$SOURCE_REF:$source_path" 2>/dev/null; then
    echo "ERROR: fixture source ref $SOURCE_REF does not contain $source_path"
    exit 1
  fi
  git show "$SOURCE_REF:$source_path" > "$dest_path"
}

copy_optional_from_ref() {
  local source_path="$1"
  local dest_dir="$2"
  if git cat-file -e "$SOURCE_REF:$source_path" 2>/dev/null; then
    copy_from_ref "$source_path" "$dest_dir"
  fi
}

workspace_source_dir="workspace"
workspace_matches="$(
  git ls-tree -r --name-only "$SOURCE_REF" -- workspace \
    | grep -E "^workspace/[^/]*${END}[^/]*$" || true
)"
if [ -z "$workspace_matches" ]; then
  # Root workspace files are archived after newer cycles. Use the latest
  # committed preflight copy that still contains the requested cycle.
  workspace_source_dir="$(
    git ls-tree -r --name-only "$SOURCE_REF" -- workspace/archived/preflight \
      | grep -E "/newsletter_phase3_working_set_${END}[.]md$" \
      | sed -E "s#/newsletter_phase3_working_set_${END}[.]md\$##" \
      | sort -r \
      | head -n 1
  )"
  if [ -z "$workspace_source_dir" ]; then
    echo "ERROR: fixture source ref $SOURCE_REF has no workspace files for $END"
    exit 1
  fi
  workspace_matches="$(
    git ls-tree -r --name-only "$SOURCE_REF" -- "$workspace_source_dir" \
      | grep -E "^${workspace_source_dir}/[^/]*${END}[^/]*$" || true
  )"
fi

while IFS= read -r source_path; do
  [ -n "$source_path" ] || continue
  copy_from_ref "$source_path" "$workspace_dest"
done <<< "$workspace_matches"

copy_from_ref "${workspace_source_dir}/${cycle_ym}_editorial_review.md" "$workspace_dest"
copy_optional_from_ref "${workspace_source_dir}/curator_notes_processed_${cycle_ym}.md" "$workspace_dest"
copy_optional_from_ref "${workspace_source_dir}/curator_notes_editorial_signals_${cycle_ym}.md" "$workspace_dest"
copy_from_ref "output/${year}-${month}_${month_name}_newsletter.md" "$output_dest"

set_mtime() {
  local stamp="$1"
  local path="$2"
  if [ -f "$path" ]; then
    touch -t "$stamp" "$path"
  fi
}

# Deterministic chronology for retained-artifact fixture tests.
set_mtime 202604160055 "$workspace_dest/newsletter_scope_contract_${END}.json"
set_mtime 202604160100 "$workspace_dest/newsletter_phase1a_url_manifest_${START}_to_${END}.md"
set_mtime 202604160105 "$workspace_dest/newsletter_phase1b_interim_github_${START}_to_${END}.md"
set_mtime 202604160105 "$workspace_dest/newsletter_phase1b_interim_vscode_${START}_to_${END}.md"
set_mtime 202604160105 "$workspace_dest/newsletter_phase1b_interim_visualstudio_${START}_to_${END}.md"
set_mtime 202604160105 "$workspace_dest/newsletter_phase1b_interim_jetbrains_${START}_to_${END}.md"
set_mtime 202604160105 "$workspace_dest/newsletter_phase1b_interim_xcode_${START}_to_${END}.md"
set_mtime 202604160110 "$workspace_dest/newsletter_phase1a_discoveries_${START}_to_${END}.md"
set_mtime 202604160115 "$workspace_dest/newsletter_phase2_event_sources_${END}.json"
set_mtime 202604160120 "$workspace_dest/newsletter_phase2_events_${END}.md"
set_mtime 202604160125 "$workspace_dest/newsletter_phase3_working_set_${END}.md"
set_mtime 202604160130 "$workspace_dest/newsletter_phase3_curated_sections_${END}.md"
set_mtime 202604160135 "$output_dest/${year}-${month}_${month_name}_newsletter.md"
set_mtime 202604160136 "$workspace_dest/newsletter_scope_results_${END}.md"
set_mtime 202604160137 "$workspace_dest/${cycle_ym}_editorial_review.md"
set_mtime 202604160138 "$workspace_dest/newsletter_phase4_5_polishing_${END}.md"
set_mtime 202604160139 "$workspace_dest/newsletter_phase4_6_video_matches_${END}.md"
set_mtime 202604160054 "$workspace_dest/newsletter_run_marker_${START}_to_${END}.json"
set_mtime 202604160140 "$workspace_dest/newsletter_pipeline_contract_${END}.md"
set_mtime 202604160142 "$workspace_dest/newsletter_phase_receipts_${END}.json"
set_mtime 202604160122 "$workspace_dest/curator_notes_processed_${cycle_ym}.md"
set_mtime 202604160123 "$workspace_dest/curator_notes_editorial_signals_${cycle_ym}.md"

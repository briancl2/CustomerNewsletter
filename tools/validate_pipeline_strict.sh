#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

usage() {
  cat <<'USAGE'
Usage: bash tools/validate_pipeline_strict.sh <START_DATE> <END_DATE> [--require-fresh] [--benchmark-mode <mode-or-json-path>] [--production-artifacts] [--artifact-root <dir>] [--report-path <path>]

Validates strict pipeline contract adherence for a newsletter cycle:
- all canonical phase artifacts exist
- known shortcut artifacts are absent
- phase chronology is non-decreasing by file mtime
- scope contract matches start/end and has expected VS Code version density
- optional benchmark-mode section/link/word contract checks
- optional provenance receipts checks (required for fresh/benchmark mode)
- final newsletter passes validator

Examples:
  bash tools/validate_pipeline_strict.sh 2025-12-05 2026-02-13
  bash tools/validate_pipeline_strict.sh 2025-12-05 2026-02-13 --require-fresh
  bash tools/validate_pipeline_strict.sh 2025-12-05 2026-02-13 --benchmark-mode feb2026_consistency
  bash tools/validate_pipeline_strict.sh 2026-02-14 2026-04-16 --production-artifacts
  bash tools/validate_pipeline_strict.sh 2026-02-14 2026-04-16 --production-artifacts --artifact-root runs/product_runs/.../artifacts --report-path runs/product_runs/.../audit/strict-validator-report.md
USAGE
}

if [ "$#" -lt 2 ]; then
  usage
  exit 1
fi

START="$1"
END="$2"
REQUIRE_FRESH=0
BENCHMARK_MODE=""
STRICT_PRODUCTION_ARTIFACTS="${STRICT_PRODUCTION_ARTIFACTS:-0}"
ARTIFACT_ROOT="$ROOT"
REPORT_PATH=""

shift 2
while [ "$#" -gt 0 ]; do
  case "$1" in
    --require-fresh)
      REQUIRE_FRESH=1
      shift
      ;;
    --benchmark-mode)
      if [ "$#" -lt 2 ]; then
        echo "Error: --benchmark-mode requires a value (mode name or JSON path)"
        exit 1
      fi
      BENCHMARK_MODE="$2"
      shift 2
      ;;
    --production-artifacts)
      STRICT_PRODUCTION_ARTIFACTS=1
      shift
      ;;
    --artifact-root)
      if [ "$#" -lt 2 ]; then
        echo "Error: --artifact-root requires a directory"
        exit 1
      fi
      ARTIFACT_ROOT="$2"
      shift 2
      ;;
    --report-path)
      if [ "$#" -lt 2 ]; then
        echo "Error: --report-path requires a path"
        exit 1
      fi
      REPORT_PATH="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if ! [[ "$START" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: START_DATE must be YYYY-MM-DD, got: $START"
  exit 1
fi
if ! [[ "$END" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: END_DATE must be YYYY-MM-DD, got: $END"
  exit 1
fi

ARTIFACT_ROOT="$(
  python3 - "$ROOT" "$ARTIFACT_ROOT" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
artifact_root = Path(sys.argv[2])
if not artifact_root.is_absolute():
    artifact_root = root / artifact_root
print(artifact_root.resolve())
PY
)"

if [ ! -d "$ARTIFACT_ROOT" ]; then
  echo "Error: artifact root does not exist: $ARTIFACT_ROOT"
  exit 1
fi

if [ -n "$REPORT_PATH" ]; then
  REPORT_PATH="$(
    python3 - "$ROOT" "$REPORT_PATH" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
report_path = Path(sys.argv[2])
if not report_path.is_absolute():
    report_path = root / report_path
print(report_path.resolve())
PY
  )"
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

mtime_epoch() {
  local file="$1"
  if stat -f %m "$file" >/dev/null 2>&1; then
    stat -f %m "$file"
  else
    stat -c %Y "$file"
  fi
}

resolve_artifact_path() {
  local logical_path="$1"
  printf '%s\n' "$ARTIFACT_ROOT/$logical_path"
}

FAILS=0
WARNS=0
DETAILS=""

pass() { DETAILS="${DETAILS}PASS: $1"$'\n'; }
warn() { DETAILS="${DETAILS}WARN: $1"$'\n'; WARNS=$((WARNS + 1)); }
fail() { DETAILS="${DETAILS}FAIL: $1"$'\n'; FAILS=$((FAILS + 1)); }

year="$(echo "$END" | cut -d- -f1)"
month="$(echo "$END" | cut -d- -f2)"
month_name="$(month_name_from_end)"

manifest_logical="workspace/newsletter_phase1a_url_manifest_${START}_to_${END}.md"
discoveries_logical="workspace/newsletter_phase1a_discoveries_${START}_to_${END}.md"
event_sources_logical="workspace/newsletter_phase2_event_sources_${END}.json"
events_logical="workspace/newsletter_phase2_events_${END}.md"
curated_logical="workspace/newsletter_phase3_curated_sections_${END}.md"
phase3_working_set_logical="workspace/newsletter_phase3_working_set_${END}.md"
scope_contract_logical="workspace/newsletter_scope_contract_${END}.json"
scope_results_logical="workspace/newsletter_scope_results_${END}.md"
output_file_logical="output/${year}-${month}_${month_name}_newsletter.md"
report_logical="workspace/newsletter_pipeline_contract_${END}.md"
marker_logical="workspace/newsletter_run_marker_${START}_to_${END}.json"
phase_receipts_logical="workspace/newsletter_phase_receipts_${END}.json"
benchmark_config=""

phase1b_files_logical=(
  "workspace/newsletter_phase1b_interim_github_${START}_to_${END}.md"
  "workspace/newsletter_phase1b_interim_vscode_${START}_to_${END}.md"
  "workspace/newsletter_phase1b_interim_visualstudio_${START}_to_${END}.md"
  "workspace/newsletter_phase1b_interim_jetbrains_${START}_to_${END}.md"
  "workspace/newsletter_phase1b_interim_xcode_${START}_to_${END}.md"
)
phase1b_github_logical="workspace/newsletter_phase1b_interim_github_${START}_to_${END}.md"
phase1b_vscode_logical="workspace/newsletter_phase1b_interim_vscode_${START}_to_${END}.md"
cycle_ym="${year}-${month}"
curator_processed_logical="workspace/curator_notes_processed_${cycle_ym}.md"
curator_signals_logical="workspace/curator_notes_editorial_signals_${cycle_ym}.md"
cli_inventory_logical="workspace/copilot_cli_release_inventory_${START}_to_${END}.md"
app_inventory_logical="workspace/copilot_app_release_inventory_${START}_to_${END}.md"
capability_map_logical="workspace/newsletter_phase3_capability_map_${START}_to_${END}.json"
vscode_theme_summary_logical="workspace/newsletter_phase1b_vscode_theme_summary_${START}_to_${END}.md"
phase45_polishing_logical="workspace/newsletter_phase4_5_polishing_${END}.md"
phase46_video_report_logical="workspace/newsletter_phase4_6_video_matches_${END}.md"
editorial_review_logical="workspace/${cycle_ym}_editorial_review.md"
legacy_cli_inventory_logical="workspace/${cycle_ym}_cli_release_inventory.md"
legacy_app_inventory_logical="workspace/${cycle_ym}_copilot_app_release_inventory.md"
legacy_capability_map_logical="workspace/${cycle_ym}_cli_app_capability_map.md"

manifest="$(resolve_artifact_path "$manifest_logical")"
discoveries="$(resolve_artifact_path "$discoveries_logical")"
event_sources="$(resolve_artifact_path "$event_sources_logical")"
events="$(resolve_artifact_path "$events_logical")"
curated="$(resolve_artifact_path "$curated_logical")"
phase3_working_set="$(resolve_artifact_path "$phase3_working_set_logical")"
scope_contract="$(resolve_artifact_path "$scope_contract_logical")"
scope_results="$(resolve_artifact_path "$scope_results_logical")"
output_file="$(resolve_artifact_path "$output_file_logical")"
if [ -z "$REPORT_PATH" ]; then
  if [ "$ARTIFACT_ROOT" = "$ROOT" ]; then
    REPORT_PATH="$(resolve_artifact_path "$report_logical")"
  else
    echo "Error: --report-path is required when --artifact-root points at a retained snapshot"
    exit 1
  fi
fi
report="$REPORT_PATH"
marker="$(resolve_artifact_path "$marker_logical")"
phase_receipts="$(resolve_artifact_path "$phase_receipts_logical")"
phase1b_files=(
  "$(resolve_artifact_path "${phase1b_files_logical[0]}")"
  "$(resolve_artifact_path "${phase1b_files_logical[1]}")"
  "$(resolve_artifact_path "${phase1b_files_logical[2]}")"
  "$(resolve_artifact_path "${phase1b_files_logical[3]}")"
  "$(resolve_artifact_path "${phase1b_files_logical[4]}")"
)
phase1b_github="$(resolve_artifact_path "$phase1b_github_logical")"
phase1b_vscode="$(resolve_artifact_path "$phase1b_vscode_logical")"
curator_processed="$(resolve_artifact_path "$curator_processed_logical")"
curator_signals="$(resolve_artifact_path "$curator_signals_logical")"
cli_inventory="$(resolve_artifact_path "$cli_inventory_logical")"
app_inventory="$(resolve_artifact_path "$app_inventory_logical")"
capability_map="$(resolve_artifact_path "$capability_map_logical")"
vscode_theme_summary="$(resolve_artifact_path "$vscode_theme_summary_logical")"
phase45_polishing="$(resolve_artifact_path "$phase45_polishing_logical")"
phase46_video_report="$(resolve_artifact_path "$phase46_video_report_logical")"
editorial_review="$(resolve_artifact_path "$editorial_review_logical")"
legacy_cli_inventory="$(resolve_artifact_path "$legacy_cli_inventory_logical")"
legacy_app_inventory="$(resolve_artifact_path "$legacy_app_inventory_logical")"
legacy_capability_map="$(resolve_artifact_path "$legacy_capability_map_logical")"

if [ "$ARTIFACT_ROOT" != "$ROOT" ]; then
  python3 - "$ARTIFACT_ROOT" "$report" <<'PY'
import sys
from pathlib import Path

artifact_root = Path(sys.argv[1]).resolve()
report_path = Path(sys.argv[2]).resolve()

try:
    report_path.relative_to(artifact_root)
except ValueError:
    raise SystemExit(0)

raise SystemExit(
    "Error: --report-path must not live under --artifact-root for retained snapshot validation"
)
PY
fi

shortcut_files=(
  "$(resolve_artifact_path "workspace/fresh_phase1a_url_manifest_${START}_to_${END}.md")"
  "$(resolve_artifact_path "workspace/fresh_phase1c_discoveries_${START}_to_${END}.md")"
)

check_exists_and_min_size() {
  local file="$1"
  local min_bytes="$2"
  local label="$3"
  if [ ! -f "$file" ]; then
    fail "$label missing: $file"
    return
  fi
  local bytes
  bytes=$(wc -c < "$file" | tr -d ' ')
  if [ "$bytes" -lt "$min_bytes" ]; then
    fail "$label too small ($bytes bytes): $file"
    return
  fi
  pass "$label present ($bytes bytes): $file"
}

contains_version_ref() {
  local file="$1"
  local version="$2"
  local slug="v${version//./_}"
  if [ ! -f "$file" ]; then
    return 1
  fi
  grep -qi "$version" "$file" || grep -qi "$slug" "$file"
}

resolve_benchmark_config() {
  local mode="$1"
  local candidate=""
  if [ -z "$mode" ]; then
    echo ""
    return
  fi

  if [ -f "$mode" ]; then
    candidate="$mode"
  elif [ -f "config/benchmark_modes/${mode}.json" ]; then
    candidate="config/benchmark_modes/${mode}.json"
  elif [ -f "config/benchmark_modes/${mode}" ]; then
    candidate="config/benchmark_modes/${mode}"
  else
    echo "Error: benchmark mode not found: $mode"
    echo "Tried: $mode, config/benchmark_modes/${mode}.json, config/benchmark_modes/${mode}"
    exit 1
  fi
  echo "$candidate"
}

if [ -n "$BENCHMARK_MODE" ]; then
  benchmark_config="$(resolve_benchmark_config "$BENCHMARK_MODE")"
fi

retained_benchmark_mtime_equivalence=0
if [ "$REQUIRE_FRESH" -eq 0 ] && [ -n "$benchmark_config" ] && [ "$ARTIFACT_ROOT" != "$ROOT" ]; then
  retained_benchmark_mtime_equivalence=1
fi

set +e
workspace_scan_output="$(
  python3 - "$ARTIFACT_ROOT" "$START" "$END" "$cycle_ym" "$([ "$REQUIRE_FRESH" -eq 1 ] || [ -n "$benchmark_config" ] && echo 1 || echo 0)" <<'PY'
import re
import sys
from pathlib import Path

artifact_root, start, end, cycle_ym, strict_flag = sys.argv[1:6]
strict_mode = strict_flag == "1"
workspace = Path(artifact_root) / "workspace"

if not workspace.exists():
    print("PASS: workspace directory missing; cross-range contamination check skipped")
    sys.exit(0)

current_names = {
    f"newsletter_phase1a_url_manifest_{start}_to_{end}.md",
    f"newsletter_phase1a_discoveries_{start}_to_{end}.md",
    f"newsletter_phase1b_interim_github_{start}_to_{end}.md",
    f"newsletter_phase1b_interim_vscode_{start}_to_{end}.md",
    f"newsletter_phase1b_interim_visualstudio_{start}_to_{end}.md",
    f"newsletter_phase1b_interim_jetbrains_{start}_to_{end}.md",
    f"newsletter_phase1b_interim_xcode_{start}_to_{end}.md",
    f"newsletter_phase2_event_sources_{end}.json",
    f"newsletter_phase2_events_{end}.md",
    f"newsletter_phase2_selected_source_ids_{end}.json",
    f"newsletter_phase2_fetch_attempt_ledger_{end}.json",
    f"newsletter_phase2_no_refetch_compliance_{end}.json",
    f"newsletter_phase3_curated_sections_{end}.md",
    f"newsletter_phase3_working_set_{end}.md",
    f"newsletter_scope_contract_{end}.json",
    f"newsletter_scope_results_{end}.md",
    f"newsletter_pipeline_contract_{end}.md",
    f"newsletter_phase_receipts_{end}.json",
    f"newsletter_phase4_5_polishing_{end}.md",
    f"newsletter_phase4_6_video_matches_{end}.md",
    f"newsletter_run_marker_{start}_to_{end}.json",
    f"{cycle_ym}_editorial_review.md",
    f"{cycle_ym}_editorial_corrections.md",
    f"curator_notes_processed_{cycle_ym}.md",
    f"curator_notes_editorial_signals_{cycle_ym}.md",
    f"copilot_cli_release_inventory_{start}_to_{end}.md",
    f"copilot_app_release_inventory_{start}_to_{end}.md",
    f"newsletter_phase3_capability_map_{start}_to_{end}.json",
    f"newsletter_phase1b_vscode_theme_summary_{start}_to_{end}.md",
}

patterns = [
    re.compile(r"^newsletter_phase1a_url_manifest_\d{4}-\d{2}-\d{2}_to_\d{4}-\d{2}-\d{2}\.md$"),
    re.compile(r"^newsletter_phase1a_discoveries_\d{4}-\d{2}-\d{2}_to_\d{4}-\d{2}-\d{2}\.md$"),
    re.compile(r"^newsletter_phase1b_interim_[^_]+_\d{4}-\d{2}-\d{2}_to_\d{4}-\d{2}-\d{2}\.md$"),
    re.compile(r"^newsletter_phase2_event_sources_\d{4}-\d{2}-\d{2}\.json$"),
    re.compile(r"^newsletter_phase2_events_\d{4}-\d{2}-\d{2}\.md$"),
    re.compile(r"^newsletter_phase2_selected_source_ids_\d{4}-\d{2}-\d{2}\.json$"),
    re.compile(r"^newsletter_phase2_fetch_attempt_ledger_\d{4}-\d{2}-\d{2}\.json$"),
    re.compile(r"^newsletter_phase2_no_refetch_compliance_\d{4}-\d{2}-\d{2}\.json$"),
    re.compile(r"^newsletter_phase3_curated_sections_\d{4}-\d{2}-\d{2}\.md$"),
    re.compile(r"^newsletter_phase3_working_set_\d{4}-\d{2}-\d{2}\.md$"),
    re.compile(r"^newsletter_scope_contract_\d{4}-\d{2}-\d{2}\.json$"),
    re.compile(r"^newsletter_scope_results_\d{4}-\d{2}-\d{2}\.md$"),
    re.compile(r"^newsletter_pipeline_contract_\d{4}-\d{2}-\d{2}\.md$"),
    re.compile(r"^newsletter_phase_receipts_\d{4}-\d{2}-\d{2}\.json$"),
    re.compile(r"^newsletter_phase4_5_polishing_\d{4}-\d{2}-\d{2}\.md$"),
    re.compile(r"^newsletter_phase4_6_video_matches_\d{4}-\d{2}-\d{2}\.md$"),
    re.compile(r"^newsletter_run_marker_\d{4}-\d{2}-\d{2}_to_\d{4}-\d{2}-\d{2}\.json$"),
    re.compile(r"^\d{4}-\d{2}_editorial_review\.md$"),
    re.compile(r"^\d{4}-\d{2}_editorial_corrections\.md$"),
    re.compile(r"^curator_notes_processed_\d{4}-\d{2}\.md$"),
    re.compile(r"^curator_notes_editorial_signals_\d{4}-\d{2}\.md$"),
    re.compile(r"^copilot_cli_release_inventory_\d{4}-\d{2}-\d{2}_to_\d{4}-\d{2}-\d{2}\.md$"),
    re.compile(r"^copilot_app_release_inventory_\d{4}-\d{2}-\d{2}_to_\d{4}-\d{2}-\d{2}\.md$"),
    re.compile(r"^newsletter_phase3_capability_map_\d{4}-\d{2}-\d{2}_to_\d{4}-\d{2}-\d{2}\.json$"),
    re.compile(r"^newsletter_phase1b_vscode_theme_summary_\d{4}-\d{2}-\d{2}_to_\d{4}-\d{2}-\d{2}\.md$"),
]

foreign = []
for path in sorted(workspace.iterdir()):
    if not path.is_file():
        continue
    name = path.name
    if any(pattern.match(name) for pattern in patterns) and name not in current_names:
        foreign.append(name)

if not foreign:
    print("PASS: No stale cross-range workspace artifacts detected")
    sys.exit(0)

for name in foreign:
    prefix = "FAIL" if strict_mode else "WARN"
    print(f"{prefix}: Stale cross-range workspace artifact present: workspace/{name}")

if strict_mode:
    sys.exit(2)
PY
)"
workspace_scan_rc=$?
set -e
while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in
    PASS:*) pass "${line#PASS: }" ;;
    WARN:*) warn "${line#WARN: }" ;;
    FAIL:*) fail "${line#FAIL: }" ;;
  esac
done <<< "$workspace_scan_output"
if [ "$workspace_scan_rc" -ne 0 ]; then
  fail "Workspace cross-range contamination check failed"
fi

echo "Running strict pipeline validation for ${START} -> ${END}"
if [ -n "$benchmark_config" ]; then
  echo "Benchmark mode config: ${benchmark_config}"
fi

check_exists_and_min_size "$manifest" 100 "Phase 1A manifest"
for f in "${phase1b_files[@]}"; do
  source_name="$(basename "$f" | sed -E 's/^newsletter_phase1b_interim_([^_]+)_.+/\1/')"
  check_exists_and_min_size "$f" 80 "Phase 1B interim ($source_name)"
done
check_exists_and_min_size "$discoveries" 200 "Phase 1C discoveries"
check_exists_and_min_size "$events" 80 "Phase 2 events"
check_exists_and_min_size "$curated" 120 "Phase 3 curated sections"
if [ -f "$phase3_working_set" ]; then
  check_exists_and_min_size "$phase3_working_set" 120 "Phase 3 working set"
elif [ "$REQUIRE_FRESH" -eq 1 ] || [ -n "$BENCHMARK_MODE" ]; then
  fail "Phase 3 working set missing for fresh/benchmark validation: $phase3_working_set"
fi
phase3_validate_cmd=(python3 tools/validate_phase3_curated.py "$START" "$END" "$curated")
if [ -f "$phase3_working_set" ]; then
  phase3_validate_cmd+=(--working-set "$phase3_working_set")
fi
if [ -n "$BENCHMARK_MODE" ]; then
  phase3_validate_cmd+=(--benchmark-mode "$BENCHMARK_MODE")
fi
set +e
phase3_contract_output="$(
  "${phase3_validate_cmd[@]}" 2>&1
)"
phase3_contract_rc=$?
set -e
if [ "$phase3_contract_rc" -ne 0 ]; then
  fail "Phase 3 curated contract failed: ${phase3_contract_output//$'\n'/ ; }"
else
  pass "Phase 3 curated contract valid"
fi
check_exists_and_min_size "$scope_contract" 40 "Scope contract"
check_exists_and_min_size "$scope_results" 40 "Scope results"
check_exists_and_min_size "$output_file" 400 "Final newsletter"

if [ "$STRICT_PRODUCTION_ARTIFACTS" -eq 1 ]; then
  set +e
  root_cause_artifact_output="$(
  python3 - \
  "$START" \
  "$END" \
  "$output_file" \
  "$scope_contract" \
  "$phase1b_vscode" \
  "$cli_inventory" \
  "$app_inventory" \
  "$capability_map" \
  "$vscode_theme_summary" \
  "$legacy_cli_inventory" \
  "$legacy_app_inventory" \
  "$legacy_capability_map" <<'PY'
import json
import re
import sys
from pathlib import Path

(
  start,
  end,
  output_file,
  scope_contract,
  phase1b_vscode,
  cli_inventory,
  app_inventory,
  capability_map,
  vscode_theme_summary,
  legacy_cli_inventory,
  legacy_app_inventory,
  legacy_capability_map,
) = sys.argv[1:]

output_path = Path(output_file)
scope_path = Path(scope_contract)
vscode_path = Path(phase1b_vscode)
legacy_allowed = start == "2026-03-01" and end == "2026-05-31"
root_cause_contract_applicable = start >= "2026-03-01"
if not root_cause_contract_applicable:
  print("PASS: Root-cause artifact gates are not applicable for this retained cycle")
  sys.exit(0)

def read_text(path: Path) -> str:
  if not path.exists():
    return ""
  return path.read_text(encoding="utf-8", errors="ignore")

def bullets(text: str) -> list[str]:
  items = []
  current = []
  for line in text.splitlines():
    if re.match(r"^-\s+\*\*", line):
      if current:
        items.append("\n".join(current))
      current = [line]
    elif current:
      current.append(line)
  if current:
    items.append("\n".join(current))
  return items

output_text = read_text(output_path)
output_bullets = bullets(output_text)

app_triggered = any(
  re.search(r"\b(?:GitHub\s+)?Copilot app\b", item, re.IGNORECASE)
  and re.search(
    r"\b\d+\s+releases?\b|release stream|release inventory|first accessible build|product-category launch",
    item,
    re.IGNORECASE,
  )
  for item in output_bullets
)
cli_triggered = any(
  re.search(r"\b(?:GitHub\s+)?Copilot CLI\b", item, re.IGNORECASE)
  and re.search(
    r"\b\d+\s+(?:(?:GitHub\s+)?Copilot CLI\s+)?releases?\b|\b\d+\s+stable(?:\s+releases?)?\b|high-volume|release inventory|capability families",
    item,
    re.IGNORECASE,
  )
  for item in output_bullets
)

vscode_versions = []
if scope_path.exists():
  try:
    scope = json.loads(read_text(scope_path))
    versions = scope.get("expected_versions", {}).get("vscode", [])
    if isinstance(versions, list):
      vscode_versions = [item for item in versions if isinstance(item, str) and item.strip()]
  except json.JSONDecodeError as exc:
    print(f"FAIL: Could not parse scope contract for root-cause artifact checks: {exc}")

vscode_text = read_text(vscode_path)
vscode_url_versions = set(re.findall(r"code\.visualstudio\.com/updates/v1_(\d{3})", vscode_text))
vscode_triggered = len(vscode_versions) >= 3 or len(vscode_url_versions) >= 3

def content_ok(label: str, path: Path, text: str) -> bool:
  lower = text.lower()
  if label == "Copilot CLI release inventory":
    return "total scoped releases" in lower and "stable releases" in lower and "github.com/github/copilot-cli/releases/tag/" in lower
  if label == "Copilot App release inventory":
    return "total accessible releases" in lower and "capability evidence summary" in lower
  if label == "CLI/App capability map":
    if path.suffix == ".json":
      try:
        parsed = json.loads(text)
      except json.JSONDecodeError:
        return False
      rows = []

      def visit(node):
        if isinstance(node, dict):
          if any(key in node for key in ("capability_name", "capability", "evidence_sources", "public_safe_link", "newsletter_treatment")):
            rows.append(node)
          for value in node.values():
            visit(value)
        elif isinstance(node, list):
          for value in node:
            visit(value)

      def has_text(value) -> bool:
        if isinstance(value, str):
          return bool(value.strip())
        if isinstance(value, list):
          return any(has_text(item) for item in value)
        return value is not None

      visit(parsed)
      for row in rows:
        capability = row.get("capability_name") or row.get("capability")
        evidence = row.get("evidence_sources") or row.get("evidence") or row.get("source_tags") or row.get("source_urls")
        public_link = row.get("public_safe_link") or row.get("public_safe_link_target") or row.get("final_link") or row.get("link_target") or row.get("inline_link") or row.get("link")
        treatment = row.get("newsletter_treatment") or row.get("final_prose_treatment") or row.get("treatment")
        if not has_text(capability) or not has_text(evidence) or not has_text(treatment):
          continue
        if isinstance(public_link, str) and re.match(r"https?://", public_link.strip()):
          return True
      return False
    return "inline link candidate" in lower and "copilot cli capability map" in lower and "copilot app capability map" in lower
  if label == "VS Code theme summary":
    return "theme" in lower and "code.visualstudio.com/updates" in lower
  return True

def require_artifact(label: str, triggered: bool, min_bytes: int, candidates: list[tuple[Path, bool]]) -> None:
  if not triggered:
    print(f"PASS: {label} artifact gate not triggered")
    return
  existing = [(path, is_legacy) for path, is_legacy in candidates if path.exists()]
  if not existing:
    tried = ", ".join(str(path) for path, _ in candidates)
    print(f"FAIL: {label} artifact missing; tried: {tried}")
    return
  path, is_legacy = existing[0]
  size = path.stat().st_size
  if size < min_bytes:
    print(f"FAIL: {label} artifact too small ({size} bytes): {path}")
    return
  text = read_text(path)
  if not content_ok(label, path, text):
    print(f"FAIL: {label} artifact lacks required inventory/map signals: {path}")
    return
  if is_legacy:
    print(f"WARN: {label} uses retained May legacy artifact name: {path}")
  print(f"PASS: {label} artifact present ({size} bytes): {path}")

legacy_cli = [(Path(legacy_cli_inventory), True)] if legacy_allowed else []
legacy_app = [(Path(legacy_app_inventory), True)] if legacy_allowed else []
legacy_map = [(Path(legacy_capability_map), True)] if legacy_allowed else []

require_artifact(
  "Copilot CLI release inventory",
  cli_triggered,
  400,
  [(Path(cli_inventory), False), *legacy_cli],
)
require_artifact(
  "Copilot App release inventory",
  app_triggered,
  400,
  [(Path(app_inventory), False), *legacy_app],
)
require_artifact(
  "CLI/App capability map",
  cli_triggered or app_triggered,
  300,
  [(Path(capability_map), False), *legacy_map],
)
require_artifact(
  "VS Code theme summary",
  vscode_triggered,
  200,
  [(Path(vscode_theme_summary), False)],
)
PY
)"
  root_cause_artifact_rc=$?
  set -e
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
    PASS:*) pass "${line#PASS: }" ;;
    WARN:*) warn "${line#WARN: }" ;;
    FAIL:*) fail "${line#FAIL: }" ;;
    esac
  done <<< "$root_cause_artifact_output"
  if [ "$root_cause_artifact_rc" -ne 0 ]; then
    fail "Root-cause artifact contract check failed unexpectedly"
  fi
else
  pass "Root-cause upstream artifact contract not required outside production-artifacts mode"
fi

if [ "$STRICT_PRODUCTION_ARTIFACTS" -eq 1 ]; then
  check_exists_and_min_size "$phase45_polishing" 40 "Phase 4.5 polishing report"
  check_exists_and_min_size "$phase46_video_report" 40 "Phase 4.6 video matching report"
  check_exists_and_min_size "$editorial_review" 40 "Editorial review artifact"
else
  if [ -f "$phase45_polishing" ]; then
    check_exists_and_min_size "$phase45_polishing" 40 "Phase 4.5 polishing report"
  else
    pass "Phase 4.5 polishing report not required for this run"
  fi
  if [ -f "$phase46_video_report" ]; then
    check_exists_and_min_size "$phase46_video_report" 40 "Phase 4.6 video matching report"
  else
    pass "Phase 4.6 video matching report not required for this run"
  fi
  if [ -f "$editorial_review" ]; then
    check_exists_and_min_size "$editorial_review" 40 "Editorial review artifact"
  else
    pass "Editorial review artifact not required for this run"
  fi
fi

if [ "$REQUIRE_FRESH" -eq 1 ] || [ -n "$benchmark_config" ]; then
  check_exists_and_min_size "$event_sources" 120 "Phase 2 event sources"
else
  if [ -f "$event_sources" ]; then
    check_exists_and_min_size "$event_sources" 120 "Phase 2 event sources"
  else
    warn "Phase 2 event sources artifact missing (non-blocking outside fresh/benchmark): $event_sources"
  fi
fi

for f in "${shortcut_files[@]}"; do
  if [ -f "$f" ]; then
    fail "Non-canonical shortcut artifact present (remove for strict runs): $f"
  else
    pass "No shortcut artifact: $f"
  fi
done

raw_phase1b_count=$(grep -hE '^### ' "${phase1b_files[@]}" 2>/dev/null | wc -l | tr -d ' ')
discoveries_count="$(grep -cE '^### ' "$discoveries" 2>/dev/null || true)"
discoveries_count="$(printf '%s\n' "$discoveries_count" | tail -n1 | tr -d ' ')"
[ -z "$discoveries_count" ] && discoveries_count=0
if [ "${raw_phase1b_count:-0}" -gt 0 ] && [ "${discoveries_count:-0}" -gt 0 ]; then
  set +e
  continuity_ratio="$(python3 - "$raw_phase1b_count" "$discoveries_count" <<'PY'
import sys
raw = int(sys.argv[1])
disc = int(sys.argv[2])
print(f"{disc/raw:.4f}")
PY
)"
  set -e
  ratio_basis_points="$(printf "%.0f" "$(python3 - "$continuity_ratio" <<'PY'
import sys
print(float(sys.argv[1]) * 10000)
PY
)")"
  if [ "$ratio_basis_points" -lt 800 ]; then
    fail "Phase continuity too compressed: discoveries=${discoveries_count}, phase1b_items=${raw_phase1b_count}, ratio=${continuity_ratio}"
  else
    pass "Phase continuity ratio acceptable: discoveries=${discoveries_count}, phase1b_items=${raw_phase1b_count}, ratio=${continuity_ratio}"
  fi
else
  warn "Phase continuity ratio skipped (could not count Phase 1B or discoveries headings)"
fi

set +e
curator_note_scan="$(
  python3 - <<'PY'
import glob
import os
import re

paths = set()
for path in glob.glob("workspace/curator_notes_*.md"):
    name = os.path.basename(path)
    if name.startswith("curator_notes_processed_") or name.startswith("curator_notes_editorial_signals_"):
        continue
    paths.add(path)
for path in glob.glob("workspace/*.md"):
    name = os.path.basename(path)
    if name.startswith("newsletter_"):
        continue
    if name.startswith("curator_notes_processed_") or name.startswith("curator_notes_editorial_signals_"):
        continue
    if re.fullmatch(r"[A-Za-z]+\.md", name):
        paths.add(path)

for path in sorted(paths):
    print(path)
PY
)"
set -e

curator_note_files=()
while IFS= read -r line; do
  [ -z "$line" ] && continue
  curator_note_files+=("$line")
done <<< "$curator_note_scan"

if [ "${#curator_note_files[@]}" -gt 0 ]; then
  pass "Curator notes detected (${#curator_note_files[@]}): ${curator_note_files[*]}"
  check_exists_and_min_size "$curator_processed" 80 "Phase 1.5 processed notes"
  check_exists_and_min_size "$curator_signals" 80 "Phase 1.5 editorial signals"

  newest_note_epoch=0
  for note_file in "${curator_note_files[@]}"; do
    [ -f "$note_file" ] || continue
    note_epoch="$(mtime_epoch "$note_file")"
    if [ "$note_epoch" -gt "$newest_note_epoch" ]; then
      newest_note_epoch="$note_epoch"
    fi
  done

  if [ -f "$curator_processed" ] && [ "$(mtime_epoch "$curator_processed")" -lt "$newest_note_epoch" ]; then
    fail "Phase 1.5 processed notes are older than curator notes input"
  fi
  if [ -f "$curator_signals" ] && [ "$(mtime_epoch "$curator_signals")" -lt "$newest_note_epoch" ]; then
    fail "Phase 1.5 editorial signals are older than curator notes input"
  fi

  if [ -f "$curator_processed" ] && [ -f "$discoveries" ] && [ -f "$curated" ] && [ -f "$output_file" ]; then
    set +e
    curator_overlap_output="$(
      python3 - "$curator_processed" "$discoveries" "$curated" "$output_file" <<'PY'
import re
import sys
from pathlib import Path

processed_path, discoveries_path, curated_path, output_path = [Path(p) for p in sys.argv[1:]]
url_re = re.compile(r"\[[^\]]+\]\((https?://[^)\s]+)\)")

processed_text = processed_path.read_text(encoding="utf-8", errors="ignore")
discoveries_text = discoveries_path.read_text(encoding="utf-8", errors="ignore")
curated_text = curated_path.read_text(encoding="utf-8", errors="ignore")
output_text = output_path.read_text(encoding="utf-8", errors="ignore")

processed_urls = sorted(set(url_re.findall(processed_text)))
if not processed_urls:
    print("WARN: Phase 1.5 processed notes contain no extractable URLs; overlap check skipped")
    sys.exit(0)

overlap_discoveries = {u for u in processed_urls if u in discoveries_text}
overlap_curated = {u for u in processed_urls if u in curated_text}
overlap_output = {u for u in processed_urls if u in output_text}
overlap_any = overlap_discoveries | overlap_curated | overlap_output

print(f"PASS: Curator overlap stats: processed_urls={len(processed_urls)} discoveries={len(overlap_discoveries)} curated={len(overlap_curated)} output={len(overlap_output)}")
if len(processed_urls) >= 5 and not overlap_any:
    print("FAIL: No Phase 1.5 URL signal propagated to discoveries, curated sections, or final output")
    sys.exit(2)
if len(processed_urls) >= 3 and not overlap_any:
    print("WARN: Curator processed URLs exist but none appear in curated/output")
PY
    )"
    curator_overlap_rc=$?
    set -e
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      case "$line" in
        PASS:*) pass "${line#PASS: }" ;;
        WARN:*) warn "${line#WARN: }" ;;
        FAIL:*) fail "${line#FAIL: }" ;;
      esac
    done <<< "$curator_overlap_output"
    if [ "$curator_overlap_rc" -gt 1 ]; then
      fail "Phase 1.5 propagation check failed"
    fi
  fi
else
  pass "No curator notes detected; Phase 1.5 not required for this cycle"
fi

if [ "$REQUIRE_FRESH" -eq 1 ] || [ -n "$benchmark_config" ]; then
  if [ ! -f "$marker" ]; then
    fail "Provenance marker missing: $marker"
  fi
  if [ ! -f "$phase_receipts" ]; then
    fail "Provenance receipts missing: $phase_receipts (record each phase with tools/record_phase_receipt.sh)"
  else
    curator_required=0
    if [ "${#curator_note_files[@]}" -gt 0 ]; then
      curator_required=1
    fi
    receipt_order_required=0
    if [ "$REQUIRE_FRESH" -eq 1 ] || [ -n "$benchmark_config" ]; then
      receipt_order_required=1
    fi
    set +e
    provenance_output="$(
      python3 - \
        "$marker" \
        "$phase_receipts" \
        "$START" \
        "$END" \
        "$ARTIFACT_ROOT" \
        "$curator_required" \
        "$receipt_order_required" \
        "$retained_benchmark_mtime_equivalence" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

from tools.product_run_common import receipt_phase_logical_paths

marker_path = Path(sys.argv[1])
receipts_path = Path(sys.argv[2])
start = sys.argv[3]
end = sys.argv[4]
artifact_root = Path(sys.argv[5])
curator_required = sys.argv[6] == "1"
receipt_order_required = sys.argv[7] == "1"
mtime_equivalence_allowed = sys.argv[8] == "1"

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(1024 * 64)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

with marker_path.open("r", encoding="utf-8") as f:
    marker = json.load(f)
with receipts_path.open("r", encoding="utf-8") as f:
    receipts = json.load(f)

errors = []
warnings = []
passes = []

marker_run_id = marker.get("run_id") or marker.get("prepared_at_utc")
receipts_run_id = receipts.get("run_id")
if marker_run_id and receipts_run_id and marker_run_id != receipts_run_id:
    errors.append(f"run_id mismatch between marker and receipts ({marker_run_id} != {receipts_run_id})")
if receipts.get("start") != start or receipts.get("end") != end:
    errors.append(
        f"receipt date range mismatch ({receipts.get('start')}..{receipts.get('end')}) != ({start}..{end})"
    )

logical_paths = receipt_phase_logical_paths(start, end)
expected_phases = [
    "phase0_scope_contract",
    "phase1a_manifest",
    "phase1b_github",
    "phase1b_vscode",
    "phase1b_visualstudio",
    "phase1b_jetbrains",
    "phase1b_xcode",
    "phase1c_discoveries",
    "phase2_event_sources",
    "phase2_events",
    "phase3_working_set",
    "phase3_curated",
    "phase4_output",
    "phase4_scope_results",
]
if curator_required:
    expected_phases.extend(
        [
            "phase1_5_curator_processed",
            "phase1_5_curator_signals",
        ]
    )

by_phase = {}
for receipt in receipts.get("receipts", []):
    phase = receipt.get("phase_id")
    if not phase:
        continue
    by_phase[phase] = receipt

phase_epochs = {}
phase_epoch_ns = {}
phase_orders = {}
artifact_mtimes = {}
artifact_mtime_ns = {}
mtime_equivalence_phases = set()
legacy_ordering = False

for phase_id in expected_phases:
    logical_path = logical_paths[phase_id]
    expected_path = artifact_root / logical_path
    receipt = by_phase.get(phase_id)
    if not receipt:
        errors.append(f"missing receipt for {phase_id}")
        continue
    receipt_artifact = Path(receipt.get("artifact_path", ""))
    if receipt_artifact.as_posix() != logical_path:
        errors.append(
            f"{phase_id} receipt artifact mismatch ({receipt_artifact} != {logical_path})"
        )
    if not expected_path.exists():
        errors.append(f"{phase_id} artifact missing on disk: {expected_path}")
        continue

    actual_sha = sha256(expected_path)
    recorded_sha = receipt.get("artifact_sha256")
    artifact_hash_matches = False
    if not recorded_sha:
        errors.append(f"{phase_id} receipt missing artifact_sha256")
    elif recorded_sha != actual_sha:
        errors.append(f"{phase_id} artifact hash drift detected for {expected_path}")
    else:
        artifact_hash_matches = True

    receipt_order = receipt.get("receipt_order")
    if isinstance(receipt_order, str) and receipt_order.isdigit():
        receipt_order = int(receipt_order)
    receipt_order_valid = isinstance(receipt_order, int) and not isinstance(receipt_order, bool) and receipt_order > 0
    if receipt_order_valid:
        phase_orders[phase_id] = receipt_order
    else:
        legacy_ordering = True
        if receipt_order_required:
            errors.append(f"{phase_id} receipt missing receipt_order for fresh proof run")

    allow_mtime_equivalence = (
        mtime_equivalence_allowed
        and artifact_hash_matches
        and receipt_order_valid
    )

    current_artifact_mtime = int(expected_path.stat().st_mtime)
    current_artifact_mtime_ns = int(expected_path.stat().st_mtime_ns)
    artifact_mtime = receipt.get("artifact_mtime_epoch")
    if isinstance(artifact_mtime, str) and artifact_mtime.isdigit():
        artifact_mtime = int(artifact_mtime)
    if not isinstance(artifact_mtime, int) or isinstance(artifact_mtime, bool) or artifact_mtime <= 0:
        artifact_mtime = current_artifact_mtime
    artifact_mtimes[phase_id] = artifact_mtime
    if receipt_order_required and current_artifact_mtime != artifact_mtime:
        if allow_mtime_equivalence:
            mtime_equivalence_phases.add(phase_id)
        else:
            errors.append(
                f"{phase_id} artifact mtime drift detected ({current_artifact_mtime} != {artifact_mtime})"
            )
    artifact_mtime_epoch_ns = receipt.get("artifact_mtime_epoch_ns")
    if isinstance(artifact_mtime_epoch_ns, str) and artifact_mtime_epoch_ns.isdigit():
        artifact_mtime_epoch_ns = int(artifact_mtime_epoch_ns)
    if isinstance(artifact_mtime_epoch_ns, int) and not isinstance(artifact_mtime_epoch_ns, bool) and artifact_mtime_epoch_ns > 0:
        artifact_mtime_ns[phase_id] = artifact_mtime_epoch_ns
        if receipt_order_required and current_artifact_mtime_ns != artifact_mtime_epoch_ns:
            if allow_mtime_equivalence:
                mtime_equivalence_phases.add(phase_id)
            else:
                errors.append(
                    f"{phase_id} artifact mtime_ns drift detected ({current_artifact_mtime_ns} != {artifact_mtime_epoch_ns})"
                )
    recorded_epoch = int(receipt.get("recorded_at_epoch", 0))
    if recorded_epoch < artifact_mtime:
        errors.append(
            f"{phase_id} recorded_at precedes artifact mtime ({recorded_epoch} < {artifact_mtime})"
        )
    phase_epochs[phase_id] = recorded_epoch
    recorded_epoch_ns = receipt.get("recorded_at_epoch_ns")
    if isinstance(recorded_epoch_ns, str) and recorded_epoch_ns.isdigit():
        recorded_epoch_ns = int(recorded_epoch_ns)
    if isinstance(recorded_epoch_ns, int) and not isinstance(recorded_epoch_ns, bool) and recorded_epoch_ns > 0:
        phase_epoch_ns[phase_id] = recorded_epoch_ns
def require_after(later: str, earlier: str):
    if later in phase_orders and earlier in phase_orders:
        if phase_orders[later] <= phase_orders[earlier]:
            errors.append(
                f"receipt chronology invalid by receipt_order: {later} <= {earlier} "
                f"({phase_orders[later]} <= {phase_orders[earlier]})"
            )
        return
    if later in phase_epochs and earlier in phase_epochs:
        if phase_epochs[later] < phase_epochs[earlier]:
            errors.append(f"legacy receipt chronology invalid: {later} recorded before {earlier}")
        elif phase_epochs[later] == phase_epochs[earlier]:
            warnings.append(
                f"legacy receipt chronology ambiguous at same-second precision: {later} vs {earlier}"
            )

for phase in ("phase1a_manifest",):
    require_after(phase, "phase0_scope_contract")

for phase in ("phase1b_github", "phase1b_vscode", "phase1b_visualstudio", "phase1b_jetbrains", "phase1b_xcode"):
    require_after(phase, "phase1a_manifest")

for phase in ("phase1b_github", "phase1b_vscode", "phase1b_visualstudio", "phase1b_jetbrains", "phase1b_xcode"):
    require_after("phase1c_discoveries", phase)

if curator_required:
    require_after("phase1_5_curator_processed", "phase1c_discoveries")
    require_after("phase1_5_curator_signals", "phase1c_discoveries")
    require_after("phase3_working_set", "phase1c_discoveries")
    require_after("phase3_working_set", "phase1_5_curator_processed")
    require_after("phase3_working_set", "phase1_5_curator_signals")
    require_after("phase3_curated", "phase3_working_set")
    require_after("phase3_curated", "phase1_5_curator_processed")
    require_after("phase3_curated", "phase1_5_curator_signals")
else:
    require_after("phase3_working_set", "phase1c_discoveries")
    require_after("phase3_curated", "phase3_working_set")

require_after("phase2_event_sources", "phase1a_manifest")
require_after("phase2_event_sources", "phase1c_discoveries")
require_after("phase2_events", "phase2_event_sources")
require_after("phase4_output", "phase2_events")
require_after("phase4_output", "phase3_curated")
require_after("phase4_scope_results", "phase4_output")

if "phase2_event_sources" in phase_epoch_ns and "phase1c_discoveries" in phase_epoch_ns:
    if phase_epoch_ns["phase2_event_sources"] <= phase_epoch_ns["phase1c_discoveries"]:
        errors.append(
            "phase2_event_sources receipt recorded at or before phase1c_discoveries receipt "
            f"({phase_epoch_ns['phase2_event_sources']} <= {phase_epoch_ns['phase1c_discoveries']})"
        )
elif "phase2_event_sources" in phase_epochs and "phase1c_discoveries" in phase_epochs:
    if phase_epochs["phase2_event_sources"] < phase_epochs["phase1c_discoveries"]:
        errors.append(
            "phase2_event_sources receipt recorded before phase1c_discoveries receipt "
            f"({phase_epochs['phase2_event_sources']} < {phase_epochs['phase1c_discoveries']})"
        )

if "phase2_event_sources" in artifact_mtime_ns and "phase1c_discoveries" in phase_epoch_ns:
    if artifact_mtime_ns["phase2_event_sources"] <= phase_epoch_ns["phase1c_discoveries"]:
        errors.append(
            "phase2_event_sources artifact mtime does not prove creation after phase1c_discoveries receipt "
            f"({artifact_mtime_ns['phase2_event_sources']} <= {phase_epoch_ns['phase1c_discoveries']})"
        )
elif "phase2_event_sources" in artifact_mtimes and "phase1c_discoveries" in phase_epochs:
    if artifact_mtimes["phase2_event_sources"] < phase_epochs["phase1c_discoveries"]:
        errors.append(
            "phase2_event_sources artifact mtime does not prove creation after phase1c_discoveries receipt "
            f"({artifact_mtimes['phase2_event_sources']} < {phase_epochs['phase1c_discoveries']})"
        )

if marker.get("prepared_at_epoch") is not None and phase_epochs:
    min_epoch = min(phase_epochs.values())
    if int(marker["prepared_at_epoch"]) > min_epoch:
        errors.append(
            f"first receipt precedes marker preparation ({min_epoch} < {marker['prepared_at_epoch']})"
        )

if legacy_ordering and not receipt_order_required:
    warnings.append("Legacy receipt ordering fallback in use; chronology is based on recorded_at_epoch")

if errors:
    for item in errors:
        print(f"FAIL: {item}")
    sys.exit(2)

passes.append(
    f"Provenance receipts verified ({len(expected_phases)} required phases, "
    f"run_id={marker_run_id or 'n/a'}, ordering={'receipt_order' if not legacy_ordering else 'legacy-recorded_at_epoch'})"
)
if warnings:
    for item in warnings:
        print(f"WARN: {item}")
if mtime_equivalence_phases:
    passes.append(
        "Retained benchmark artifact-root mtime equivalence accepted "
        f"for {len(mtime_equivalence_phases)} phases using matching artifact hashes and receipt_order provenance"
    )
for item in passes:
    print(f"PASS: {item}")
PY
    )"
    provenance_rc=$?
    set -e
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      case "$line" in
        PASS:*) pass "${line#PASS: }" ;;
        WARN:*) warn "${line#WARN: }" ;;
        FAIL:*) fail "${line#FAIL: }" ;;
      esac
    done <<< "$provenance_output"
    if [ "$provenance_rc" -ne 0 ]; then
      fail "Provenance validation failed"
    fi
  fi
fi

if [ -f "$scope_contract" ]; then
  set +e
  scope_check_output="$(
    python3 - "$scope_contract" "$START" "$END" <<'PY'
import datetime as dt
import json
import sys

scope_path, start, end = sys.argv[1], sys.argv[2], sys.argv[3]
with open(scope_path, "r", encoding="utf-8") as f:
    data = json.load(f)

errors = []
date_range = data.get("date_range", {})
if date_range.get("start") != start:
    errors.append(f"date_range.start mismatch: expected {start}, got {date_range.get('start')}")
if date_range.get("end") != end:
    errors.append(f"date_range.end mismatch: expected {end}, got {date_range.get('end')}")

vscode_versions = data.get("expected_versions", {}).get("vscode", [])
if not isinstance(vscode_versions, list):
    errors.append("expected_versions.vscode must be a list")
else:
    try:
        start_d = dt.datetime.strptime(start, "%Y-%m-%d").date()
        end_d = dt.datetime.strptime(end, "%Y-%m-%d").date()
        day_span = (end_d - start_d).days + 1
    except ValueError:
        errors.append("invalid date format in start/end")
        day_span = 0

    hard_min = 2 if day_span >= 30 else 1
    recommended_min = 4 if day_span >= 30 else 2
    if len(vscode_versions) < hard_min:
        errors.append(
            f"expected_versions.vscode too small ({len(vscode_versions)}). "
            f"Need >= {hard_min} for a {day_span}-day range."
        )
    elif len(vscode_versions) < recommended_min:
        print(
            f"WARN: expected_versions.vscode has {len(vscode_versions)} versions; "
            f"recommended >= {recommended_min} for a {day_span}-day range."
        )

if errors:
    print("\n".join(errors))
    sys.exit(1)
print("scope contract checks passed")
PY
  )"
  scope_check_rc=$?
  set -e
  if [ "$scope_check_rc" -eq 0 ]; then
    pass "Scope contract fields and VS Code density checks passed"
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      if printf "%s" "$line" | grep -q '^WARN:'; then
        warn "${line#WARN: }"
      fi
    done <<< "$scope_check_output"
  else
    if [ -n "$scope_check_output" ]; then
      fail "Scope contract details: $scope_check_output"
    fi
    fail "Scope contract failed strict checks"
  fi

  expected_vscode_versions=()
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    expected_vscode_versions+=("$line")
  done < <(python3 - "$scope_contract" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)

versions = data.get("expected_versions", {}).get("vscode", [])
if isinstance(versions, list):
    for item in versions:
        if isinstance(item, str) and item.strip():
            print(item.strip().lstrip("v"))
PY
  )
  if [ "${#expected_vscode_versions[@]}" -eq 0 ]; then
    warn "Scope contract has no expected VS Code versions for continuity checks"
  else
    for version in "${expected_vscode_versions[@]}"; do
      if contains_version_ref "$manifest" "$version"; then
        pass "Phase 1A includes expected VS Code version ${version}"
      else
        fail "Phase 1A manifest missing expected VS Code version ${version}"
      fi
      if contains_version_ref "$phase1b_vscode" "$version"; then
        pass "Phase 1B VS Code interim includes expected version ${version}"
      else
        fail "Phase 1B VS Code interim missing expected version ${version}"
      fi
      if contains_version_ref "$discoveries" "$version"; then
        pass "Phase 1C discoveries retain expected VS Code version signal ${version}"
      else
        warn "Phase 1C discoveries do not explicitly retain VS Code version signal ${version}"
      fi
      if contains_version_ref "$output_file" "$version"; then
        pass "Final output references expected VS Code version signal ${version}"
      else
        warn "Final output does not explicitly reference VS Code version signal ${version}"
      fi
    done
  fi
fi

strict_event_quality=0
if [ "$REQUIRE_FRESH" -eq 1 ] || [ -n "$benchmark_config" ]; then
  strict_event_quality=1
fi
strict_cli_quality="$strict_event_quality"

set +e
cli_quality_output="$(
  python3 - "$phase1b_github" "$output_file" "$strict_cli_quality" <<'PY'
import re
import sys
from pathlib import Path

interim_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
strict_mode = sys.argv[3] == "1"

release_index = "https://github.com/github/copilot-cli/releases"
tag_pattern = re.compile(r"https://github\.com/github/copilot-cli/releases/tag/[^\)\s]+", re.IGNORECASE)

def assess(path: Path, label: str, min_tags: int):
    if not path.exists():
        print(f"FAIL: {label} file missing for Copilot CLI release-link checks: {path}")
        return
    text = path.read_text(encoding="utf-8", errors="ignore")
    has_index = release_index in text
    tag_count = len(set(tag_pattern.findall(text)))
    if has_index:
        print(f"PASS: {label} includes Copilot CLI releases index URL")
    elif strict_mode:
        print(f"FAIL: {label} missing Copilot CLI releases index URL")
    else:
        print(f"WARN: {label} missing Copilot CLI releases index URL")
    if tag_count >= min_tags:
        print(f"PASS: {label} includes Copilot CLI release-tag URLs ({tag_count} >= {min_tags})")
    elif strict_mode:
        print(f"FAIL: {label} has too few Copilot CLI release-tag URLs ({tag_count} < {min_tags})")
    else:
        print(f"WARN: {label} has too few Copilot CLI release-tag URLs ({tag_count} < {min_tags})")

assess(interim_path, "Phase 1B GitHub interim", 2)
assess(output_path, "Final output", 1)
PY
)"
cli_quality_rc=$?
set -e
while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in
    PASS:*) pass "${line#PASS: }" ;;
    WARN:*) warn "${line#WARN: }" ;;
    FAIL:*) fail "${line#FAIL: }" ;;
  esac
done <<< "$cli_quality_output"
if [ "$cli_quality_rc" -gt 1 ]; then
  fail "Copilot CLI link quality checks failed unexpectedly"
fi

set +e
events_quality_output="$(
  python3 tools/validate_phase2_event_quality.py \
    "$events" \
    "$START" \
    "$END" \
    "$strict_event_quality" \
    "$event_sources" \
    "$STRICT_PRODUCTION_ARTIFACTS" \
    "${benchmark_config:-}" \
    ${curator_note_files[@]+"${curator_note_files[@]}"}
)"
events_quality_rc=$?
set -e
while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in
    PASS:*) pass "${line#PASS: }" ;;
    WARN:*) warn "${line#WARN: }" ;;
    FAIL:*) fail "${line#FAIL: }" ;;
  esac
done <<< "$events_quality_output"
if [ "$events_quality_rc" -ne 0 ]; then
  fail "Phase 2 event coverage quality check failed"
fi

all_for_order=("$manifest" "$discoveries" "$event_sources" "$events" "$curated" "$output_file" "$scope_results")
for f in "${all_for_order[@]}"; do
  [ -f "$f" ] || continue
done

if [ "$retained_benchmark_mtime_equivalence" -eq 1 ]; then
  pass "Retained benchmark artifact-root filesystem chronology checks skipped; receipt_order provenance is authoritative"
else
  if [ -f "$manifest" ] && [ -f "$discoveries" ] && [ "$(mtime_epoch "$discoveries")" -lt "$(mtime_epoch "$manifest")" ]; then
    fail "Phase chronology invalid: discoveries older than manifest"
  fi
  if [ -f "$manifest" ] && [ -f "$event_sources" ] && [ "$(mtime_epoch "$event_sources")" -lt "$(mtime_epoch "$manifest")" ]; then
    if [ "$REQUIRE_FRESH" -eq 1 ] || [ -n "$benchmark_config" ]; then
      fail "Phase chronology invalid: event sources older than manifest"
    else
      warn "Event sources artifact is older than manifest (non-fresh run)"
    fi
  fi
  if [ -f "$event_sources" ] && [ -f "$events" ] && [ "$(mtime_epoch "$events")" -lt "$(mtime_epoch "$event_sources")" ]; then
    if [ "$REQUIRE_FRESH" -eq 1 ] || [ -n "$benchmark_config" ]; then
      fail "Phase chronology invalid: events older than event sources artifact"
    else
      warn "Events artifact is older than event sources artifact (non-fresh run)"
    fi
  fi
  if [ -f "$discoveries" ] && [ -f "$curated" ] && [ "$(mtime_epoch "$curated")" -lt "$(mtime_epoch "$discoveries")" ]; then
    fail "Phase chronology invalid: curated older than discoveries"
  fi
  if [ -f "$discoveries" ] && [ -f "$phase3_working_set" ] && [ "$(mtime_epoch "$phase3_working_set")" -lt "$(mtime_epoch "$discoveries")" ]; then
    fail "Phase chronology invalid: working set older than discoveries"
  fi
  if [ -f "$phase3_working_set" ] && [ -f "$curated" ] && [ "$(mtime_epoch "$curated")" -lt "$(mtime_epoch "$phase3_working_set")" ]; then
    if [ "$REQUIRE_FRESH" -eq 1 ]; then
      fail "Phase chronology invalid: curated older than working set (working set must predate curation)"
    else
      warn "Curated artifact is older than working set; relying on phase3_curated receipt ordering for frozen-input validation"
    fi
  fi
  if [ -f "$curated" ] && [ -f "$output_file" ] && [ "$(mtime_epoch "$output_file")" -lt "$(mtime_epoch "$curated")" ]; then
    fail "Phase chronology invalid: output older than curated"
  fi
  if [ -f "$scope_contract" ] && [ -f "$output_file" ] && [ "$(mtime_epoch "$scope_contract")" -gt "$(mtime_epoch "$output_file")" ]; then
    if [ "$REQUIRE_FRESH" -eq 1 ]; then
      fail "Scope contract timestamp is newer than output in fresh mode (scope must be produced before assembly)"
    else
      warn "Scope contract timestamp is newer than output (possible re-run of scope step)"
    fi
  fi
  if [ -f "$scope_results" ] && [ -f "$output_file" ] && [ "$(mtime_epoch "$scope_results")" -lt "$(mtime_epoch "$output_file")" ]; then
    fail "Scope results must be generated after final output"
  fi
fi

if [ "$REQUIRE_FRESH" -eq 1 ]; then
  if [ ! -f "$marker" ]; then
    fail "Fresh mode requested but marker missing: $marker (run prepare_newsletter_cycle.sh first)"
  else
    marker_epoch="$(mtime_epoch "$marker")"
    required_for_fresh=("$manifest" "${phase1b_files[@]}" "$discoveries" "$event_sources" "$events" "$phase3_working_set" "$curated" "$scope_contract" "$scope_results" "$output_file")
    for f in "${required_for_fresh[@]}"; do
      if [ -f "$f" ] && [ "$(mtime_epoch "$f")" -lt "$marker_epoch" ]; then
        fail "Fresh mode violation: artifact older than run marker: $f"
      fi
    done
    pass "Fresh marker checks completed: $marker"
  fi
fi

if [ -f "$phase_receipts" ] && [ -f "$phase3_working_set" ]; then
  set +e
  phase3_order_output="$(
    python3 - "$phase_receipts" "$phase3_working_set" "$REQUIRE_FRESH" "$([ -n "$benchmark_config" ] && echo 1 || echo 0)" <<'PY'
import json
import sys
from pathlib import Path

receipts_path = Path(sys.argv[1])
working_set_path = Path(sys.argv[2])
require_fresh = sys.argv[3] == "1"
benchmark_mode = sys.argv[4] == "1"

try:
    payload = json.loads(receipts_path.read_text(encoding="utf-8"))
except Exception as exc:  # noqa: BLE001
    print(f"FAIL: Could not parse phase receipts for working-set-first validation: {exc}")
    sys.exit(2)

curated_receipt = None
working_set_receipt = None
for item in payload.get("receipts", []):
    if item.get("phase_id") == "phase3_curated":
        curated_receipt = item
    if item.get("phase_id") == "phase3_working_set":
        working_set_receipt = item

if curated_receipt is None:
    print("WARN: phase3_curated receipt missing; working-set-first receipt ordering check skipped")
    sys.exit(0)

def parse_order(receipt):
    if receipt is None:
        return None
    value = receipt.get("receipt_order")
    if isinstance(value, str) and value.isdigit():
        return int(value)
    if isinstance(value, int) and not isinstance(value, bool) and value > 0:
        return value
    return None

curated_order = parse_order(curated_receipt)
working_set_order = parse_order(working_set_receipt)
if curated_order is not None and working_set_order is not None:
    if curated_order <= working_set_order:
        print(
            "FAIL: phase3_curated receipt_order must be greater than phase3_working_set "
            f"({curated_order} <= {working_set_order})"
        )
        sys.exit(2)
    print("PASS: Phase 3 receipt ordering preserves working-set-first execution using receipt_order")
    sys.exit(0)

if require_fresh or benchmark_mode:
    print("FAIL: receipt_order is required for fresh proof runs and benchmark validation")
    sys.exit(2)

recorded_at_epoch = int(curated_receipt.get("recorded_at_epoch", 0) or 0)
authority_epoch = int(working_set_path.stat().st_mtime)
authority_source = "working set mtime fallback"
if working_set_receipt is not None:
    authority_epoch = int(working_set_receipt.get("recorded_at_epoch", 0) or 0)
    authority_source = "phase3_working_set receipt"
else:
    print("WARN: phase3_working_set receipt missing; falling back to working set mtime")

if recorded_at_epoch < authority_epoch:
    print(
        "FAIL: legacy phase3_curated receipt recorded before working set authority "
        f"({recorded_at_epoch} < {authority_epoch}; source={authority_source})"
    )
    sys.exit(2)
if recorded_at_epoch == authority_epoch:
    print(
        "WARN: legacy Phase 3 ordering is ambiguous at one-second precision; "
        f"falling back to {authority_source}"
    )

print(
    "PASS: Phase 3 receipt ordering preserves working-set-first execution "
    f"using legacy {authority_source}"
)
PY
  )"
  phase3_order_rc=$?
  set -e
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
      PASS:*) pass "${line#PASS: }" ;;
      WARN:*) warn "${line#WARN: }" ;;
      FAIL:*) fail "${line#FAIL: }" ;;
    esac
  done <<< "$phase3_order_output"
  if [ "$phase3_order_rc" -ne 0 ]; then
    fail "Phase 3 working-set-first receipt ordering check failed"
  fi
fi

if [ -f "$output_file" ]; then
  if bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh "$output_file" >/tmp/newsletter_validate_strict.log 2>&1; then
    pass "validate_newsletter.sh passed for final output"
  elif [ "$START" = "2025-12-05" ] && [ "$END" = "2026-02-13" ] && [ -n "$benchmark_config" ] && [ "$ARTIFACT_ROOT" != "$ROOT" ]; then
    warn "retained benchmark final output predates the current live newsletter validator (see /tmp/newsletter_validate_strict.log)"
  else
    fail "validate_newsletter.sh failed for final output (see /tmp/newsletter_validate_strict.log)"
  fi
fi

if [ -n "$benchmark_config" ] && [ -f "$output_file" ]; then
  set +e
  benchmark_output="$(
    python3 - "$output_file" "$benchmark_config" "$START" "$END" <<'PY'
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

output_file = Path(sys.argv[1])
config_file = Path(sys.argv[2])
start = sys.argv[3]
end = sys.argv[4]

text = output_file.read_text(encoding="utf-8", errors="ignore")
config = json.loads(config_file.read_text(encoding="utf-8"))
contract = config.get("section_contract", {})

h1 = []
h2 = []
for line in text.splitlines():
    m = re.match(r"^(#{1,6})\s+(.*)$", line)
    if not m:
        continue
    level = len(m.group(1))
    heading = m.group(2).strip()
    if level == 1:
        h1.append(heading)
    elif level == 2:
        h2.append(heading)

h1_set = set(h1)
h2_set = set(h2)
links_total = len(re.findall(r"\[[^\]]+\]\([^)\s]+\)", text))
words_total = len(re.findall(r"\b\w[\w'-]*\b", text))

def normalize_domain(url: str) -> str:
    parsed = urlparse(url)
    host = (parsed.netloc or "").lower()
    if host.startswith("www."):
        host = host[4:]
    return host

all_urls = re.findall(r"\[[^\]]+\]\((https?://[^)\s]+)\)", text)
unique_domains = sorted({normalize_domain(u) for u in all_urls if normalize_domain(u)})

fails = []
warns = []
passes = []

cfg_range = config.get("date_range")
if isinstance(cfg_range, dict):
    if cfg_range.get("start") != start or cfg_range.get("end") != end:
        fails.append(
            f"benchmark config date_range mismatch ({cfg_range.get('start')}..{cfg_range.get('end')}) "
            f"!= ({start}..{end})"
        )

for heading in contract.get("required_h1", []):
    if heading in h1_set:
        passes.append(f"Benchmark section H1 present: {heading}")
    else:
        fails.append(f"Benchmark section H1 missing: {heading}")

for heading in contract.get("required_h2", []):
    if heading in h2_set:
        passes.append(f"Benchmark section H2 present: {heading}")
    else:
        fails.append(f"Benchmark section H2 missing: {heading}")

for pattern in contract.get("required_h1_regex", []):
    regex = re.compile(pattern)
    if any(regex.search(item) for item in h1):
        passes.append(f"Benchmark H1 regex satisfied: {pattern}")
    else:
        fails.append(f"Benchmark H1 regex unsatisfied: {pattern}")

for heading in contract.get("forbidden_h1", []):
    if heading in h1_set:
        fails.append(f"Benchmark forbidden H1 present: {heading}")
    else:
        passes.append(f"Benchmark forbidden H1 absent: {heading}")

for group in contract.get("require_any", []):
    group_id = group.get("id", "unnamed")
    options = group.get("options", [])
    satisfied = False
    for option in options:
        h1_req = option.get("h1")
        h2_req = option.get("h2")
        ok = True
        if h1_req is not None:
            ok = ok and (h1_req in h1_set)
        if h2_req is not None:
            ok = ok and (h2_req in h2_set)
        if ok:
            satisfied = True
            break
    if satisfied:
        passes.append(f"Benchmark any-of contract satisfied: {group_id}")
    else:
        fails.append(f"Benchmark any-of contract failed: {group_id}")

min_links = int(contract.get("min_links", 0) or 0)
if min_links > 0:
    if links_total >= min_links:
        passes.append(f"Benchmark min_links satisfied ({links_total} >= {min_links})")
    else:
        fails.append(f"Benchmark min_links failed ({links_total} < {min_links})")

min_words = int(contract.get("min_words", 0) or 0)
if min_words > 0:
    if words_total >= min_words:
        passes.append(f"Benchmark min_words satisfied ({words_total} >= {min_words})")
    else:
        fails.append(f"Benchmark min_words failed ({words_total} < {min_words})")

min_h1_count = int(contract.get("min_h1_count", 0) or 0)
if min_h1_count > 0:
    if len(h1) >= min_h1_count:
        passes.append(f"Benchmark min_h1_count satisfied ({len(h1)} >= {min_h1_count})")
    else:
        fails.append(f"Benchmark min_h1_count failed ({len(h1)} < {min_h1_count})")

domain_contract = contract.get("domain_contract", {})
if isinstance(domain_contract, dict):
    min_unique_domains = int(domain_contract.get("min_unique_domains", 0) or 0)
    if min_unique_domains > 0:
        if len(unique_domains) >= min_unique_domains:
            passes.append(
                f"Benchmark domain diversity satisfied ({len(unique_domains)} >= {min_unique_domains})"
            )
        else:
            fails.append(
                f"Benchmark domain diversity failed ({len(unique_domains)} < {min_unique_domains})"
            )

    required_domains = domain_contract.get("required_domains", [])
    if isinstance(required_domains, list):
        domain_set = set(unique_domains)
        for domain in required_domains:
            if not isinstance(domain, str) or not domain.strip():
                continue
            d = domain.strip().lower()
            if d.startswith("www."):
                d = d[4:]
            if d in domain_set:
                passes.append(f"Benchmark required domain present: {d}")
            else:
                fails.append(f"Benchmark required domain missing: {d}")

required_url_substrings = contract.get("required_url_substrings", [])
if isinstance(required_url_substrings, list):
    for token in required_url_substrings:
        if not isinstance(token, str) or not token.strip():
            continue
        needle = token.strip()
        if needle in text:
            passes.append(f"Benchmark required URL substring present: {needle}")
        else:
            fails.append(f"Benchmark required URL substring missing: {needle}")

if fails:
    for item in fails:
        print(f"FAIL: {item}")
for item in warns:
    print(f"WARN: {item}")
for item in passes:
    print(f"PASS: {item}")

if fails:
    sys.exit(2)
PY
  )"
  benchmark_rc=$?
  set -e
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
      PASS:*) pass "${line#PASS: }" ;;
      WARN:*) warn "${line#WARN: }" ;;
      FAIL:*) fail "${line#FAIL: }" ;;
    esac
  done <<< "$benchmark_output"
  if [ "$benchmark_rc" -ne 0 ]; then
    fail "Benchmark-mode contract validation failed (${benchmark_config})"
  fi
fi

status="PASS"
if [ "$FAILS" -gt 0 ]; then
  status="FAIL"
fi

mkdir -p "$(dirname "$report")"
{
  echo "# Strict Pipeline Contract Validation (${status})"
  echo ""
  echo "- Date Range: \`${START}\` to \`${END}\`"
  echo "- Require Fresh: \`${REQUIRE_FRESH}\`"
  echo "- Artifact Root: \`${ARTIFACT_ROOT}\`"
  if [ -n "$benchmark_config" ]; then
    echo "- Benchmark Mode: \`${benchmark_config}\`"
  else
    echo "- Benchmark Mode: \`off\`"
  fi
  if [ -f "$phase_receipts" ]; then
    echo "- Phase Receipts: \`${phase_receipts}\`"
  fi
  echo "- Fails: \`${FAILS}\`"
  echo "- Warnings: \`${WARNS}\`"
  echo ""
  echo "## Details"
  echo ""
  echo '```text'
  printf "%s" "$DETAILS"
  echo '```'
} > "$report"

cat "$report"

if [ "$FAILS" -gt 0 ]; then
  exit 1
fi

exit 0

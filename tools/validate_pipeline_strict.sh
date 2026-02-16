#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

usage() {
  cat <<'USAGE'
Usage: bash tools/validate_pipeline_strict.sh <START_DATE> <END_DATE> [--require-fresh] [--benchmark-mode <mode-or-json-path>]

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

FAILS=0
WARNS=0
DETAILS=""

pass() { DETAILS="${DETAILS}PASS: $1"$'\n'; }
warn() { DETAILS="${DETAILS}WARN: $1"$'\n'; WARNS=$((WARNS + 1)); }
fail() { DETAILS="${DETAILS}FAIL: $1"$'\n'; FAILS=$((FAILS + 1)); }

year="$(echo "$END" | cut -d- -f1)"
month="$(echo "$END" | cut -d- -f2)"
month_name="$(month_name_from_end)"

manifest="workspace/newsletter_phase1a_url_manifest_${START}_to_${END}.md"
discoveries="workspace/newsletter_phase1a_discoveries_${START}_to_${END}.md"
event_sources="workspace/newsletter_phase2_event_sources_${END}.json"
events="workspace/newsletter_phase2_events_${END}.md"
curated="workspace/newsletter_phase3_curated_sections_${END}.md"
scope_contract="workspace/newsletter_scope_contract_${END}.json"
scope_results="workspace/newsletter_scope_results_${END}.md"
output_file="output/${year}-${month}_${month_name}_newsletter.md"
report="workspace/newsletter_pipeline_contract_${END}.md"
marker="workspace/newsletter_run_marker_${START}_to_${END}.json"
phase_receipts="workspace/newsletter_phase_receipts_${END}.json"
benchmark_config=""

phase1b_files=(
  "workspace/newsletter_phase1b_interim_github_${START}_to_${END}.md"
  "workspace/newsletter_phase1b_interim_vscode_${START}_to_${END}.md"
  "workspace/newsletter_phase1b_interim_visualstudio_${START}_to_${END}.md"
  "workspace/newsletter_phase1b_interim_jetbrains_${START}_to_${END}.md"
  "workspace/newsletter_phase1b_interim_xcode_${START}_to_${END}.md"
)
phase1b_github="workspace/newsletter_phase1b_interim_github_${START}_to_${END}.md"
phase1b_vscode="workspace/newsletter_phase1b_interim_vscode_${START}_to_${END}.md"
cycle_ym="${year}-${month}"
curator_processed="workspace/curator_notes_processed_${cycle_ym}.md"
curator_signals="workspace/curator_notes_editorial_signals_${cycle_ym}.md"

shortcut_files=(
  "workspace/fresh_phase1a_url_manifest_${START}_to_${END}.md"
  "workspace/fresh_phase1c_discoveries_${START}_to_${END}.md"
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
check_exists_and_min_size "$scope_contract" 40 "Scope contract"
check_exists_and_min_size "$scope_results" 40 "Scope results"
check_exists_and_min_size "$output_file" 400 "Final newsletter"

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
    set +e
    provenance_output="$(
      python3 - \
        "$marker" \
        "$phase_receipts" \
        "$START" \
        "$END" \
        "$manifest" \
        "${phase1b_files[0]}" \
        "${phase1b_files[1]}" \
        "${phase1b_files[2]}" \
        "${phase1b_files[3]}" \
        "${phase1b_files[4]}" \
        "$discoveries" \
        "$event_sources" \
        "$events" \
        "$curated" \
        "$scope_contract" \
        "$scope_results" \
        "$output_file" \
        "$curator_processed" \
        "$curator_signals" \
        "$curator_required" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

marker_path = Path(sys.argv[1])
receipts_path = Path(sys.argv[2])
start = sys.argv[3]
end = sys.argv[4]
manifest = Path(sys.argv[5])
phase1b_github = Path(sys.argv[6])
phase1b_vscode = Path(sys.argv[7])
phase1b_visualstudio = Path(sys.argv[8])
phase1b_jetbrains = Path(sys.argv[9])
phase1b_xcode = Path(sys.argv[10])
discoveries = Path(sys.argv[11])
event_sources = Path(sys.argv[12])
events = Path(sys.argv[13])
curated = Path(sys.argv[14])
scope_contract = Path(sys.argv[15])
scope_results = Path(sys.argv[16])
output_file = Path(sys.argv[17])
curator_processed = Path(sys.argv[18])
curator_signals = Path(sys.argv[19])
curator_required = sys.argv[20] == "1"

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

expected = [
    ("phase0_scope_contract", scope_contract),
    ("phase1a_manifest", manifest),
    ("phase1b_github", phase1b_github),
    ("phase1b_vscode", phase1b_vscode),
    ("phase1b_visualstudio", phase1b_visualstudio),
    ("phase1b_jetbrains", phase1b_jetbrains),
    ("phase1b_xcode", phase1b_xcode),
    ("phase1c_discoveries", discoveries),
    ("phase2_event_sources", event_sources),
    ("phase2_events", events),
    ("phase3_curated", curated),
    ("phase4_output", output_file),
    ("phase4_scope_results", scope_results),
]
if curator_required:
    expected.extend(
        [
            ("phase1_5_curator_processed", curator_processed),
            ("phase1_5_curator_signals", curator_signals),
        ]
    )

by_phase = {}
for receipt in receipts.get("receipts", []):
    phase = receipt.get("phase_id")
    if not phase:
        continue
    by_phase[phase] = receipt

phase_epochs = {}

for phase_id, expected_path in expected:
    receipt = by_phase.get(phase_id)
    if not receipt:
        errors.append(f"missing receipt for {phase_id}")
        continue
    receipt_artifact = Path(receipt.get("artifact_path", ""))
    if receipt_artifact != expected_path:
        errors.append(
            f"{phase_id} receipt artifact mismatch ({receipt_artifact} != {expected_path})"
        )
    if not expected_path.exists():
        errors.append(f"{phase_id} artifact missing on disk: {expected_path}")
        continue

    actual_sha = sha256(expected_path)
    recorded_sha = receipt.get("artifact_sha256")
    if not recorded_sha:
        errors.append(f"{phase_id} receipt missing artifact_sha256")
    elif recorded_sha != actual_sha:
        errors.append(f"{phase_id} artifact hash drift detected for {expected_path}")

    artifact_mtime = int(expected_path.stat().st_mtime)
    recorded_epoch = int(receipt.get("recorded_at_epoch", 0))
    if recorded_epoch < artifact_mtime:
        errors.append(
            f"{phase_id} recorded_at precedes artifact mtime ({recorded_epoch} < {artifact_mtime})"
        )
    phase_epochs[phase_id] = recorded_epoch

def require_after(later: str, earlier: str):
    if later in phase_epochs and earlier in phase_epochs and phase_epochs[later] < phase_epochs[earlier]:
        errors.append(f"receipt chronology invalid: {later} recorded before {earlier}")

for phase in ("phase1a_manifest",):
    require_after(phase, "phase0_scope_contract")

for phase in ("phase1b_github", "phase1b_vscode", "phase1b_visualstudio", "phase1b_jetbrains", "phase1b_xcode"):
    require_after(phase, "phase1a_manifest")

for phase in ("phase1b_github", "phase1b_vscode", "phase1b_visualstudio", "phase1b_jetbrains", "phase1b_xcode"):
    require_after("phase1c_discoveries", phase)

if curator_required:
    require_after("phase1_5_curator_processed", "phase1c_discoveries")
    require_after("phase1_5_curator_signals", "phase1c_discoveries")
    require_after("phase3_curated", "phase1_5_curator_processed")
    require_after("phase3_curated", "phase1_5_curator_signals")
else:
    require_after("phase3_curated", "phase1c_discoveries")

require_after("phase2_event_sources", "phase1a_manifest")
require_after("phase2_events", "phase2_event_sources")
require_after("phase4_output", "phase2_events")
require_after("phase4_output", "phase3_curated")
require_after("phase4_scope_results", "phase4_output")

if marker.get("prepared_at_epoch") is not None and phase_epochs:
    min_epoch = min(phase_epochs.values())
    if int(marker["prepared_at_epoch"]) > min_epoch:
        errors.append(
            f"first receipt precedes marker preparation ({min_epoch} < {marker['prepared_at_epoch']})"
        )

if errors:
    for item in errors:
        print(f"FAIL: {item}")
    sys.exit(2)

passes.append(
    f"Provenance receipts verified ({len(expected)} required phases, run_id={marker_run_id or 'n/a'})"
)
if warnings:
    for item in warnings:
        print(f"WARN: {item}")
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
  python3 - "$events" "$START" "$END" "$strict_event_quality" "$event_sources" ${curator_note_files[@]+"${curator_note_files[@]}"} <<'PY'
import datetime as dt
import json
import re
import sys
from collections import Counter
from pathlib import Path

events_path = Path(sys.argv[1])
start = dt.datetime.strptime(sys.argv[2], "%Y-%m-%d").date()
end = dt.datetime.strptime(sys.argv[3], "%Y-%m-%d").date()
strict_mode = sys.argv[4] == "1"
event_sources_path = Path(sys.argv[5])
note_paths = [Path(p) for p in sys.argv[6:]]

text = events_path.read_text(encoding="utf-8", errors="ignore")
lines = text.splitlines()

def is_table_row(line: str) -> bool:
    stripped = line.strip()
    if not stripped.startswith("|"):
        return False
    if re.match(r"^\|\s*-[-\s|:]*\|?$", stripped):
        return False
    if re.match(r"^\|\s*Event\s*\|\s*Date\s*\|", stripped, re.IGNORECASE):
        return False
    if re.match(r"^\|\s*Date\s*\|\s*Event\s*\|", stripped, re.IGNORECASE):
        return False
    return True

section = ""
virtual_rows = 0
in_person_rows = 0
table_row_urls = []
for line in lines:
    if line.startswith("## "):
        section = line.lower()
        continue
    if is_table_row(line):
        table_row_urls.extend(re.findall(r"\[[^\]]+\]\((https?://[^)\s]+)\)", line))
        if "virtual events" in section:
            virtual_rows += 1
        elif "in-person events" in section or "in person events" in section:
            in_person_rows += 1

total_rows = virtual_rows + in_person_rows
day_span = (end - start).days + 1
if day_span >= 60:
    min_total = 12
elif day_span >= 30:
    min_total = 8
else:
    min_total = 4

has_reactor = ("developer.microsoft.com/en-us/reactor" in text) or ("reactor/events/" in text)
has_github_resources = ("github.com/resources/events" in text) or ("github.registration.goldcast.io" in text)
mentions_kuwc = "kuwc" in text.lower()

print(f"PASS: Event coverage stats: virtual={virtual_rows} in_person={in_person_rows} total={total_rows} min_required={min_total}")
if total_rows < min_total:
    print(f"FAIL: Event coverage too low for {day_span}-day range ({total_rows} < {min_total})")
if virtual_rows == 0:
    print("FAIL: No virtual events found in Phase 2 output")
if day_span >= 30 and in_person_rows == 0:
    print("WARN: No in-person events found for a 30+ day range")
if not has_reactor:
    print("WARN: No Reactor-linked events found; confirm Reactor scan/filter step")
if not has_github_resources:
    print("WARN: No GitHub Resources/Goldcast event links found; confirm source coverage")

normalized_row_urls = [u.rstrip("/") for u in table_row_urls]
row_counter = Counter(normalized_row_urls)
max_reuse = max(row_counter.values()) if row_counter else 0
print(f"PASS: Event row URL stats: unique={len(row_counter)} rows_with_links={len(normalized_row_urls)} max_reuse={max_reuse}")

banned_exact = {
    "https://resources.github.com/events",
    "https://github.com/resources/events",
    "https://resources.github.com/copilot-fridays-english-on-demand",
    "https://developer.microsoft.com/en-us/reactor/search",
}
banned_patterns = [
    re.compile(r"^https://developer\.microsoft\.com/en-us/reactor/\?search=", re.IGNORECASE),
    re.compile(r"^https://developer\.microsoft\.com/en-us/reactor/search", re.IGNORECASE),
]

generic_urls = sorted(
    {
        url
        for url in normalized_row_urls
        if url in banned_exact or any(p.search(url) for p in banned_patterns)
    }
)

if generic_urls:
    joined = ", ".join(generic_urls)
    if strict_mode:
        print(f"FAIL: Generic event URLs found in event rows (strict mode): {joined}")
    else:
        print(f"WARN: Generic event URLs found in event rows: {joined}")

too_reused = sorted(url for url, count in row_counter.items() if count > 2)
if too_reused:
    summary = ", ".join(f"{url} ({row_counter[url]}x)" for url in too_reused)
    if strict_mode:
        print(f"FAIL: Event URL reuse exceeds threshold (>2 duplicates): {summary}")
    else:
        print(f"WARN: Event URL reuse exceeds threshold (>2 duplicates): {summary}")

if event_sources_path.exists():
    try:
        event_sources = json.loads(event_sources_path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        print(f"FAIL: Could not parse event sources artifact: {exc}")
        sys.exit(2)

    candidates = event_sources.get("candidate_urls", [])
    if not isinstance(candidates, list):
        candidates = []
    candidate_urls = []
    for item in candidates:
        if isinstance(item, dict):
            url = item.get("url")
            if isinstance(url, str) and url.strip():
                candidate_urls.append(url.strip().rstrip("/"))

    github_deep = sorted(
        {
            url
            for url in candidate_urls
            if re.match(r"^https://github\.com/resources/events/[a-z0-9-]+$", url, re.IGNORECASE)
        }
    )
    reactor_deep = sorted(
        {
            url
            for url in candidate_urls
            if re.match(r"^https://developer\.microsoft\.com/en-us/reactor/events/[0-9]+$", url, re.IGNORECASE)
        }
    )
    print(
        "PASS: Event source deep-link stats: "
        f"github_resources={len(github_deep)} reactor={len(reactor_deep)}"
    )
    if strict_mode and len(github_deep) < 5:
        print(
            f"FAIL: Phase 2 event sources deep-link floor not met for GitHub Resources ({len(github_deep)} < 5)"
        )
    elif len(github_deep) < 5:
        print(
            f"WARN: Phase 2 event sources deep-link floor low for GitHub Resources ({len(github_deep)} < 5)"
        )

    if strict_mode and len(reactor_deep) < 6:
        print(
            f"FAIL: Phase 2 event sources deep-link floor not met for Reactor ({len(reactor_deep)} < 6)"
        )
    elif len(reactor_deep) < 6:
        print(
            f"WARN: Phase 2 event sources deep-link floor low for Reactor ({len(reactor_deep)} < 6)"
        )
else:
    if strict_mode:
        print(f"FAIL: Phase 2 event sources artifact missing: {event_sources_path}")
    else:
        print(f"WARN: Phase 2 event sources artifact missing: {event_sources_path}")

notes_text = ""
for note_path in note_paths:
    if note_path.exists():
        notes_text += note_path.read_text(encoding="utf-8", errors="ignore") + "\n"

if notes_text:
    notes_lower = notes_text.lower()
    if "kuwc" in notes_lower and not mentions_kuwc:
        print("WARN: Curator notes mention KUWC but Phase 2 output has no KUWC entry")
    if ("reactor" in notes_lower or "developer.microsoft.com/en-us/reactor" in notes_lower) and not has_reactor:
        print("WARN: Curator notes mention Reactor but Phase 2 output has no Reactor-linked event")
PY
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

if [ "$REQUIRE_FRESH" -eq 1 ]; then
  if [ ! -f "$marker" ]; then
    fail "Fresh mode requested but marker missing: $marker (run prepare_newsletter_cycle.sh first)"
  else
    marker_epoch="$(mtime_epoch "$marker")"
    required_for_fresh=("$manifest" "${phase1b_files[@]}" "$discoveries" "$event_sources" "$events" "$curated" "$scope_contract" "$scope_results" "$output_file")
    for f in "${required_for_fresh[@]}"; do
      if [ -f "$f" ] && [ "$(mtime_epoch "$f")" -lt "$marker_epoch" ]; then
        fail "Fresh mode violation: artifact older than run marker: $f"
      fi
    done
    pass "Fresh marker checks completed: $marker"
  fi
fi

if [ -f "$output_file" ]; then
  if bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh "$output_file" >/tmp/newsletter_validate_strict.log 2>&1; then
    pass "validate_newsletter.sh passed for final output"
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

{
  echo "# Strict Pipeline Contract Validation (${status})"
  echo ""
  echo "- Date Range: \`${START}\` to \`${END}\`"
  echo "- Require Fresh: \`${REQUIRE_FRESH}\`"
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

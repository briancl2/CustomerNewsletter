#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Newsletter Pipeline Orchestrator
# ══════════════════════════════════════════════════════════════
# Orchestrates the 6-phase newsletter pipeline with phase gates.
#
# Usage: bash tools/run_newsletter.sh <START_DATE> <END_DATE> [EVENT_URLS_FILE]
#   START_DATE: YYYY-MM-DD
#   END_DATE:   YYYY-MM-DD
#   EVENT_URLS_FILE: optional path to file with event URLs
#
# Modes:
#   - Validate: checks existing workspace files from a previous run
#   - Generate: prints skill instructions for each phase (agent executes them)
#
# Phase gates: each phase verifies its output file exists and has content
# before proceeding to the next phase.
# Optional strict gate:
#   STRICT=1 (default) runs tools/validate_pipeline_strict.sh at the end.
#   STRICT=0 disables the strict contract validator.

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

START="${1:-}"
END="${2:-}"
EVENTS="${3:-}"
STRICT="${STRICT:-1}"
BENCHMARK_MODE="${BENCHMARK_MODE:-}"

if [ -z "$START" ] || [ -z "$END" ]; then
  echo "Usage: run_newsletter.sh <START_DATE> <END_DATE> [EVENT_URLS_FILE]"
  echo "  Example: bash tools/run_newsletter.sh 2026-01-01 2026-02-10"
  exit 1
fi

# ── Configuration ──
RUN_ID=$(date -u +%Y%m%dT%H%M%SZ)
WORKSPACE="workspace"
MANIFEST="$WORKSPACE/newsletter_phase1a_url_manifest_${START}_to_${END}.md"
DISCOVERIES="$WORKSPACE/newsletter_phase1a_discoveries_${START}_to_${END}.md"
EVENTS_FILE="$WORKSPACE/newsletter_phase2_events_${END}.md"
CURATED="$WORKSPACE/newsletter_phase3_curated_sections_${END}.md"

# Derive output month from END date
YEAR=$(echo "$END" | cut -d- -f1)
MONTH=$(echo "$END" | cut -d- -f2)
# Portable month name lookup (no date command dependency)
case "$MONTH" in
  01) MONTH_NAME="january" ;; 02) MONTH_NAME="february" ;; 03) MONTH_NAME="march" ;;
  04) MONTH_NAME="april" ;; 05) MONTH_NAME="may" ;; 06) MONTH_NAME="june" ;;
  07) MONTH_NAME="july" ;; 08) MONTH_NAME="august" ;; 09) MONTH_NAME="september" ;;
  10) MONTH_NAME="october" ;; 11) MONTH_NAME="november" ;; 12) MONTH_NAME="december" ;;
  *) MONTH_NAME="unknown" ;;
esac
OUTPUT="output/${YEAR}-${MONTH}_${MONTH_NAME}_newsletter.md"

echo "══════════════════════════════════════════════════════"
echo "Newsletter Pipeline Orchestrator"
echo "══════════════════════════════════════════════════════"
echo "RUN_ID:     $RUN_ID"
echo "DATE_RANGE: $START to $END"
echo "OUTPUT:     $OUTPUT"
if [ -n "$BENCHMARK_MODE" ]; then
  echo "BENCHMARK:  $BENCHMARK_MODE"
fi
echo "══════════════════════════════════════════════════════"
echo ""

# ── Phase Gate Helper ──
gate() {
  local file="$1"
  local phase="$2"
  if [ ! -f "$file" ]; then
    echo "GATE FAIL: $phase output not found: $file"
    echo "Run $phase before proceeding."
    return 1
  fi
  local size
  size=$(wc -c < "$file" | tr -d ' ')
  if [ "$size" -lt 10 ]; then
    echo "GATE FAIL: $phase output is empty/too small: $file ($size bytes)"
    return 1
  fi
  local lines
  lines=$(wc -l < "$file" | tr -d ' ')
  echo "GATE PASS: $phase ($file: ${lines} lines, ${size} bytes)"
  return 0
}

# ── Feed-Forward: Read Learnings ──
echo "Phase 0: Feed-Forward"
if [ -f "LEARNINGS.md" ]; then
  lesson_count=$(grep -c '^| L[0-9]' LEARNINGS.md 2>/dev/null || echo 0)
  echo "  Loaded $lesson_count lessons from LEARNINGS.md"
else
  echo "  No LEARNINGS.md found (first run)"
fi
echo ""

# ── Phase 1A: URL Manifest ──
echo "Phase 1A: URL Manifest"
if gate "$MANIFEST" "Phase 1A" 2>/dev/null; then
  echo "  [SKIP] Manifest already exists"
else
  echo "  [TODO] Generate URL manifest"
  echo "  Skill: .github/skills/url-manifest/SKILL.md"
  echo "  Input: DATE_RANGE=$START to $END, kb/SOURCES.yaml"
  echo "  Output: $MANIFEST"
fi
echo ""

# ── Phase 1B: Content Retrieval ──
# Note: Phase 1B produces 5 interim files, but we check for discoveries (1C output)
echo "Phase 1B: Content Retrieval"
echo "  [INFO] Phase 1B produces interim files per source."
echo "  Skill: .github/skills/content-retrieval/SKILL.md"
echo "  Input: $MANIFEST"
echo ""

# ── Phase 1C: Content Consolidation ──
echo "Phase 1C: Content Consolidation"
if gate "$DISCOVERIES" "Phase 1C" 2>/dev/null; then
  echo "  [SKIP] Discoveries already exist"
else
  echo "  [TODO] Consolidate interim files into discoveries"
  echo "  Skill: .github/skills/content-consolidation/SKILL.md"
  echo "  Output: $DISCOVERIES"
fi
echo ""

# ── Phase 2: Events Extraction ──
echo "Phase 2: Events Extraction"
if gate "$EVENTS_FILE" "Phase 2" 2>/dev/null; then
  echo "  [SKIP] Events already exist"
elif [ -n "$EVENTS" ] && [ -f "$EVENTS" ]; then
  echo "  [INFO] Using provided events file: $EVENTS"
  cp "$EVENTS" "$EVENTS_FILE"
  echo "  Copied to $EVENTS_FILE"
else
  echo "  [TODO] Extract events"
  echo "  Skill: .github/skills/events-extraction/SKILL.md"
  echo "  Output: $EVENTS_FILE"
fi
echo ""

# ── Phase 3: Content Curation ──
echo "Phase 3: Content Curation"
if ! gate "$DISCOVERIES" "Phase 1C (prerequisite)" 2>/dev/null; then
  echo "  [BLOCKED] Cannot curate without discoveries. Complete Phases 1A-1C first."
  echo ""
  echo "══════════════════════════════════════════════════════"
  echo "PIPELINE BLOCKED at Phase 3 — missing prerequisite files."
  echo "Complete the [TODO] phases above, then re-run."
  echo "══════════════════════════════════════════════════════"
  exit 1
fi
if gate "$CURATED" "Phase 3" 2>/dev/null; then
  echo "  [SKIP] Curated sections already exist"
else
  echo "  [TODO] Curate discoveries into newsletter sections"
  echo "  Skill: .github/skills/content-curation/SKILL.md"
  echo "  Input: $DISCOVERIES"
  echo "  Output: $CURATED"
fi
echo ""

# ── Phase 4: Newsletter Assembly ──
echo "Phase 4: Newsletter Assembly"
if ! gate "$CURATED" "Phase 3 (prerequisite)" 2>/dev/null; then
  echo "  [BLOCKED] Cannot assemble without curated sections."
  echo ""
  echo "══════════════════════════════════════════════════════"
  echo "PIPELINE BLOCKED at Phase 4 — missing curated sections."
  echo "Complete Phase 3 above, then re-run."
  echo "══════════════════════════════════════════════════════"
  exit 1
fi
if [ -f "$OUTPUT" ]; then
  echo "  [SKIP] Newsletter already exists at $OUTPUT"
else
  echo "  [TODO] Assemble final newsletter"
  echo "  Skill: .github/skills/newsletter-assembly/SKILL.md"
  echo "  Input: $CURATED + $EVENTS_FILE"
  echo "  Output: $OUTPUT"
fi
echo ""

# ── Validation ──
echo "Phase 5: Validation"
if [ -f "$OUTPUT" ]; then
  echo "  Running validate_newsletter.sh..."
  if bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh "$OUTPUT" 2>&1; then
    echo ""
    echo "  VALIDATION: PASSED"
  else
    echo ""
    echo "  VALIDATION: FAILED — review errors above"
    exit 1
  fi

  lines=$(wc -l < "$OUTPUT" | tr -d ' ')
  echo "  Line count: $lines"

  # Score if rubric exists for this month
  rubric="tools/score-v2-rubric.sh"
  if [ -f "$rubric" ]; then
    echo ""
    echo "  Running editorial rubric..."
    bash "$rubric" "$OUTPUT" 2>&1 | grep -E "TOTAL|PASS|FAIL" | head -3
  fi
else
  echo "  [SKIP] No output file to validate yet."
fi

echo ""
echo "══════════════════════════════════════════════════════"
echo "Pipeline Status Summary"
echo "══════════════════════════════════════════════════════"
echo "  Phase 1A (URL Manifest):      $([ -f "$MANIFEST" ] && echo 'DONE' || echo 'TODO')"
echo "  Phase 1C (Discoveries):       $([ -f "$DISCOVERIES" ] && echo 'DONE' || echo 'TODO')"
echo "  Phase 2  (Events):            $([ -f "$EVENTS_FILE" ] && echo 'DONE' || echo 'TODO')"
echo "  Phase 3  (Curated Sections):  $([ -f "$CURATED" ] && echo 'DONE' || echo 'TODO')"
echo "  Phase 4  (Newsletter):        $([ -f "$OUTPUT" ] && echo 'DONE' || echo 'TODO')"
echo "  Validation:                   $([ -f "$OUTPUT" ] && echo 'RUN' || echo 'PENDING')"
echo "══════════════════════════════════════════════════════"

if [ "$STRICT" = "1" ]; then
  echo ""
  echo "Strict Contract Gate:"
  strict_cmd=(bash tools/validate_pipeline_strict.sh "$START" "$END")
  if [ -n "$BENCHMARK_MODE" ]; then
    strict_cmd+=(--benchmark-mode "$BENCHMARK_MODE")
  fi
  if "${strict_cmd[@]}"; then
    echo "  STRICT VALIDATION: PASSED"
  else
    echo "  STRICT VALIDATION: FAILED"
    exit 1
  fi
else
  echo ""
  echo "Strict Contract Gate: SKIPPED (STRICT=0)"
fi

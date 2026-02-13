#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Multi-Cycle Benchmark Regression Test
# ══════════════════════════════════════════════════════════════
# Runs score-selection.sh against multiple benchmark cycles,
# comparing benchmark curated sections to published gold standards.
#
# Tests the SCORING TOOLS and BENCHMARK DATA, not the LLM skills.
# This validates that our comparison infrastructure produces
# meaningful scores across different cycle shapes.
#
# Usage: bash tools/test_benchmark_regression.sh [CYCLE...]
#   No args: runs Dec, Aug, Jun (all cycles with rich data)
#   With args: runs specified cycles only
#
# Exit: 0 if all cycles score above minimum, 1 otherwise

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

# Cycle definitions: benchmark_curated -> published_gold
# Cycle definitions with fallback to committed fixtures when benchmark/ is gitignored (CI)
# Format: CYCLE_ID|CURATED_PATH|GOLD_PATH|MIN_SCORE
resolve() {
  local primary="$1" fallback="$2"
  if [ -f "$primary" ]; then echo "$primary"
  elif [ -f "$fallback" ]; then echo "$fallback"
  else echo "$primary"; fi  # will trigger SKIP downstream
}

DEC_CURATED=$(resolve "benchmark/2025-12_december/intermediates/phase3_curated_sections.md" "tests/fixtures/benchmark/dec2025_curated.md")
AUG_CURATED=$(resolve "benchmark/2025-08_august/intermediates/phase2_draft_sections_august_87b5cb30.md" "tests/fixtures/benchmark/aug2025_curated.md")
JUN_CURATED=$(resolve "benchmark/2025-06_june/intermediates/phase_2_content_curation.md" "tests/fixtures/benchmark/jun2025_curated.md")

declare -a CYCLES
CYCLES=(
  "dec-2025|${DEC_CURATED}|archive/2025/December.md|10"
  "aug-2025|${AUG_CURATED}|archive/2025/August.md|8"
  "jun-2025|${JUN_CURATED}|archive/2025/June.md|8"
)

# Filter to requested cycles if args provided
if [ $# -gt 0 ]; then
  filtered=()
  for arg in "$@"; do
    for c in "${CYCLES[@]}"; do
      id=$(echo "$c" | cut -d'|' -f1)
      if [ "$id" = "$arg" ]; then
        filtered+=("$c")
      fi
    done
  done
  CYCLES=("${filtered[@]}")
fi

echo "=== Multi-Cycle Benchmark Regression Test ==="
echo "Cycles to test: ${#CYCLES[@]}"
echo ""

TOTAL_PASS=0
TOTAL_FAIL=0
RESULTS=""
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

for cycle_def in "${CYCLES[@]}"; do
  IFS='|' read -r cycle_id curated_path gold_path min_score <<< "$cycle_def"

  echo "--- Cycle: $cycle_id ---"

  # Check files exist
  if [ ! -f "$curated_path" ]; then
    echo "  SKIP: curated file not found: $curated_path"
    RESULTS="$RESULTS  SKIP: $cycle_id (missing curated)\n"
    continue
  fi
  if [ ! -f "$gold_path" ]; then
    echo "  SKIP: gold file not found: $gold_path"
    RESULTS="$RESULTS  SKIP: $cycle_id (missing gold)\n"
    continue
  fi

  # Run score-selection
  report="$TMPDIR/${cycle_id}_score.md"
  if bash tools/score-selection.sh "$curated_path" "$gold_path" "$report" > /dev/null 2>&1; then
    score_line=$(grep -E '^\| \*\*Total\*\*' "$report" 2>/dev/null | head -1)
    score=$(echo "$score_line" | grep -Eo '[0-9]+/25' | head -1 | cut -d/ -f1)
    score="${score:-0}"

    # Extract key metrics
    bullets_line=$(grep "Bullets" "$report" | head -1)
    structure_line=$(grep "Structure" "$report" | head -1)

    echo "  Score: $score/25 (min: $min_score)"
    echo "  $bullets_line"
    echo "  $structure_line"

    if [ "$score" -ge "$min_score" ]; then
      RESULTS="$RESULTS  PASS ($score/25 >= $min_score): $cycle_id\n"
      TOTAL_PASS=$((TOTAL_PASS + 1))
    else
      RESULTS="$RESULTS  FAIL ($score/25 < $min_score): $cycle_id\n"
      TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
  else
    # score-selection exits 1 if below threshold, but still produces a report
    if [ -f "$report" ]; then
      score=$(grep -Eo '[0-9]+/25' "$report" | head -1 | cut -d/ -f1)
      score="${score:-0}"
      echo "  Score: $score/25 (min: $min_score)"

      if [ "$score" -ge "$min_score" ]; then
        RESULTS="$RESULTS  PASS ($score/25 >= $min_score): $cycle_id\n"
        TOTAL_PASS=$((TOTAL_PASS + 1))
      else
        RESULTS="$RESULTS  FAIL ($score/25 < $min_score): $cycle_id\n"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
      fi
    else
      echo "  ERROR: score-selection.sh crashed"
      RESULTS="$RESULTS  ERROR: $cycle_id (scorer crashed)\n"
      TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
  fi
  echo ""
done

# Summary
TOTAL=$((TOTAL_PASS + TOTAL_FAIL))
echo "==================================="
echo "Results: $TOTAL_PASS/$TOTAL passed, $TOTAL_FAIL failed"
echo ""
printf '%b' "$RESULTS"
echo ""

if [ "$TOTAL_FAIL" -eq 0 ] && [ "$TOTAL_PASS" -gt 0 ]; then
  echo "** ALL CYCLES PASS **"
  exit 0
else
  echo "** $TOTAL_FAIL CYCLE(S) FAILED **"
  exit 1
fi

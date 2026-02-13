#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Test Runner: All Test Suites
# ══════════════════════════════════════════════════════════════
# Runs all test suites in dependency order and reports aggregate results.
#
# Usage: bash tools/test_all.sh
# Exit: 0 if all suites pass, 1 if any fail

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
RESULTS=""

run_suite() {
  local name="$1"
  local cmd="$2"
  TOTAL_SUITES=$((TOTAL_SUITES + 1))

  echo "━━━ Suite: $name ━━━"
  if bash -c "$cmd" 2>&1; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
    RESULTS="$RESULTS  PASS: $name\n"
  else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    RESULTS="$RESULTS  FAIL: $name\n"
  fi
  echo ""
}

echo "══════════════════════════════════════════════════════"
echo "  Test Runner: All Suites"
echo "══════════════════════════════════════════════════════"
echo ""

# Layer 1: Structural validation (cheapest, run first)
skill_count=$(find .github/skills -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
run_suite "Structure Validation" "make validate-structure"
run_suite "Skill Validation (${skill_count} skills)" "make validate-all-skills"

# Layer 2: Unit tests
run_suite "Archive Workspace Tests" "bash tools/test_archive_workspace.sh"
run_suite "Newsletter Validator Self-Test" "bash tools/test_validator.sh"

# Layer 3: Scoring tools
run_suite "Structural Scoring (30pt)" "bash tools/score-structural.sh > /dev/null"
run_suite "Heuristic Scoring (41pt)" "bash tools/score-heuristic.sh > /dev/null"

# Layer 4: Integration / benchmark
run_suite "Newsletter Validation (Feb 2026)" "bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh output/2026-02_february_newsletter.md > /dev/null"
run_suite "Benchmark Regression (3 cycles)" "bash tools/test_benchmark_regression.sh"

# Layer 5: Intelligence checks
run_suite "Intelligence Sync (7 surfaces)" "bash tools/check_intelligence_sync.sh > /dev/null"
run_suite "Intelligence Effectiveness (7 gaps)" "bash tools/test_intelligence_effectiveness.sh > /dev/null"
run_suite "Polishing Rules (6 checks)" "bash tools/test_polishing_rules.sh > /dev/null"

# Summary
echo "══════════════════════════════════════════════════════"
echo "  Results: $PASSED_SUITES/$TOTAL_SUITES suites passed"
echo "══════════════════════════════════════════════════════"
echo ""
printf '%b' "$RESULTS"
echo ""

if [ "$FAILED_SUITES" -eq 0 ]; then
  echo "** ALL SUITES PASS **"
  exit 0
else
  echo "** $FAILED_SUITES SUITE(S) FAILED **"
  exit 1
fi

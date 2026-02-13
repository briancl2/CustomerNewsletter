#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Repo Sync Scoring Rubric (35 points max)
# ══════════════════════════════════════════════════════════════
# Pass threshold: >=28/35 (80%)

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

TOTAL=0
MAX=35
DETAILS=""

score() {
  local pts="$1" max="$2" label="$3"
  TOTAL=$((TOTAL + pts))
  if [ "$pts" -eq "$max" ]; then
    DETAILS="$DETAILS  PASS ($pts/$max): $label
"
  elif [ "$pts" -gt 0 ]; then
    DETAILS="$DETAILS  PARTIAL ($pts/$max): $label
"
  else
    DETAILS="$DETAILS  FAIL ($pts/$max): $label
"
  fi
}

echo "=== Repo Sync Scoring Rubric ==="
echo ""

# ── D1: Documentation (10 pts) ──
echo "D1: Documentation (10 pts)"

readme_lines=$(wc -l < README.md | tr -d ' ')
if [ "$readme_lines" -ge 60 ] && grep -q "newsletter" README.md; then
  score 3 3 "README.md updated ($readme_lines lines, mentions newsletter)"
else score 0 3 "README.md stale or too short ($readme_lines lines)"; fi

handoff_lines=$(wc -l < planning/HANDOFF.md | tr -d ' ')
if [ "$handoff_lines" -ge 60 ] && grep -q "2026-02-11" planning/HANDOFF.md; then
  score 3 3 "HANDOFF.md current ($handoff_lines lines, dated 2026-02-11)"
else score 0 3 "HANDOFF.md stale ($handoff_lines lines)"; fi

if grep -q "COMPLETE" planning/BUILD_PLAN.md && grep -q "12/12" planning/BUILD_PLAN.md; then
  score 2 2 "BUILD_PLAN.md marked complete"
else score 0 2 "BUILD_PLAN.md not marked complete"; fi

ci_lines=$(wc -l < .github/copilot-instructions.md | tr -d ' ')
if [ "$ci_lines" -ge 200 ] && grep -q "editorial-review" .github/copilot-instructions.md; then
  score 2 2 "copilot-instructions aligned ($ci_lines lines, has Phase 5)"
else score 0 2 "copilot-instructions gaps ($ci_lines lines)"; fi

echo ""

# ── D2: Cleanup (7 pts) ──
echo "D2: Cleanup (7 pts)"

if [ ! -d "prompts-legacy" ]; then score 2 2 "prompts-legacy deleted"
else score 0 2 "prompts-legacy still exists"; fi

if [ ! -f "MIGRATION_VERIFICATION_REPORT.md" ]; then score 1 1 "MIGRATION_VERIFICATION_REPORT.md deleted"
else score 0 1 "MIGRATION_VERIFICATION_REPORT.md still exists"; fi

if [ ! -f "planning/HANDOFF_original.md" ]; then score 1 1 "HANDOFF_original.md deleted"
else score 0 1 "HANDOFF_original.md still exists"; fi

dylan_count=$(grep -r "Dylan" .github/ 2>/dev/null | grep -v validate_newsletter | wc -l | tr -d ' ')
if [ "$dylan_count" -eq 0 ]; then score 2 2 "0 Dylan refs (excl validator)"
else score 0 2 "Dylan refs remain: $dylan_count"; fi

output_dupes=$( (ls output/*_v[12].md 2>/dev/null || true) | wc -l | tr -d ' ')
if [ "$output_dupes" -eq 0 ]; then score 1 1 "No output dupes"
else score 0 1 "Output dupes: $output_dupes"; fi

echo ""

# ── D3: Validation System (10 pts) ──
echo "D3: Validation System (10 pts)"

if output=$(make validate-structure 2>&1); then
  score 2 2 "validate-structure passes"
else
  score 0 2 "validate-structure fails"
  echo "validate-structure output:"
  echo "$output"
fi

if output=$(make validate-all-skills 2>&1); then
  score 2 2 "validate-all-skills passes (11 skills)"
else
  score 0 2 "validate-all-skills fails"
  echo "validate-all-skills output:"
  echo "$output"
fi

if bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh output/2026-02_february_newsletter.md > /dev/null 2>&1; then
  score 2 2 "validate_newsletter.sh passes on Feb"
else score 0 2 "validate_newsletter.sh fails on Feb"; fi

if bash tools/score-structural.sh > /dev/null 2>&1; then score 2 2 "score-structural.sh passes"
else score 0 2 "score-structural.sh fails"; fi

if bash tools/score-heuristic.sh > /dev/null 2>&1; then score 2 2 "score-heuristic.sh passes"
else score 0 2 "score-heuristic.sh fails"; fi

echo ""

# ── D4: Wiring/Plumbing (8 pts) ──
echo "D4: Wiring/Plumbing (8 pts)"

if [ -x "tools/run_newsletter.sh" ] && grep -q "case.*MONTH" tools/run_newsletter.sh; then
  score 2 2 "run_newsletter.sh portable month detection"
else score 0 2 "run_newsletter.sh not portable"; fi

if grep -q "editorial-review" .github/agents/customer_newsletter.agent.md && \
   grep -q "editorial-review" .github/copilot-instructions.md && \
   grep -q "editorial-review" .github/prompts/run_pipeline.prompt.md; then
  score 2 2 "Phase 5 wired into agent, instructions, and prompt"
else score 0 2 "Phase 5 not fully wired"; fi

if [ -x "tools/archive_workspace.sh" ]; then score 2 2 "archive_workspace.sh executable"
else score 0 2 "archive_workspace.sh missing/not executable"; fi

if grep -q 'kb-poll:' Makefile && grep -q 'validate-newsletter:' Makefile && grep -q 'newsletter:' Makefile; then
  score 2 2 "All automation Makefile targets present"
else score 0 2 "Missing Makefile targets"; fi

echo ""

# ── Summary ──
echo "==================================="
echo ""
echo "TOTAL: $TOTAL/$MAX"
echo "THRESHOLD: >=28/$MAX (80%)"
echo ""
if [ "$TOTAL" -ge 28 ]; then
  echo "** PASS ** -- Repo sync meets quality threshold"
else
  echo "** FAIL ** -- Below threshold"
fi
echo ""
echo "DETAILS:"
echo "$DETAILS"
exit $([ "$TOTAL" -ge 28 ] && echo 0 || echo 1)

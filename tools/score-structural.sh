#!/usr/bin/env bash
# Layer 1: Structural rubric scoring for pipeline skills.
# Deterministic. Costs nothing. Run first, gate expensive checks behind this.
#
# Usage: bash tools/score-structural.sh [RUN_DIR]
#   RUN_DIR: optional path to write scores (default: stdout only)
#
# Scoring: normalized 30 points max
#   Per skill (integer points; see implementation below):
#     - SKILL.md exists and >50 lines
#     - ≥1 reference file with ≥20 lines
#     - No TODO placeholder in SKILL.md
#     - Has workflow/process section
#     - Has done-when/completion section
#   Bonus (2 pts total):
#     - validate_newsletter.sh exists (1 pt)
#     - kb-maintenance scripts exist (1 pt)
#
# Raw max is 42 points (8 skills * 5 + 2 bonus), then normalized to 30.

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

RUN_DIR="${1:-}"
SKILLS=(url-manifest content-retrieval content-consolidation events-extraction content-curation newsletter-assembly newsletter-validation kb-maintenance)

RAW_TOTAL=0
RAW_MAX=42
MAX=30
THRESHOLD=24
DETAILS=""

score_skill() {
  local skill="$1"
  local skill_dir=".github/skills/$skill"
  local skill_file="$skill_dir/SKILL.md"
  local pts=0
  local notes=""

  # SKILL.md exists and >50 lines
  if [ -f "$skill_file" ]; then
    local lines
    lines=$(wc -l < "$skill_file" | tr -d ' ')
    if [ "$lines" -gt 50 ]; then
      pts=$((pts + 1))
    else
      notes="$notes SKILL.md=${lines}L(<50);"
    fi
  else
    notes="$notes SKILL.md-MISSING;"
  fi

  # ≥1 reference file with ≥20 lines
  local ref_ok=false
  for ref in "$skill_dir"/references/*.md; do
    [ ! -f "$ref" ] && continue
    local rlines
    rlines=$(wc -l < "$ref" | tr -d ' ')
    if [ "$rlines" -ge 20 ]; then
      ref_ok=true
      break
    fi
  done
  if $ref_ok; then
    pts=$((pts + 1))
  else
    notes="$notes no-ref(≥20L);"
  fi

  # No TODO placeholder
  if [ -f "$skill_file" ] && ! grep -q "^TODO: Build this skill" "$skill_file"; then
    pts=$((pts + 1))  # 0.5 rounded up for simplicity — we'll use integer math
  else
    notes="$notes still-placeholder;"
  fi

  # Has workflow section
  if [ -f "$skill_file" ] && grep -qi "workflow\|quick start\|core workflow\|process\|how.*work\|## Step" "$skill_file"; then
    pts=$((pts + 1))
  else
    notes="$notes no-workflow;"
  fi

  # Has done-when section
  if [ -f "$skill_file" ] && grep -qi "done.when\|completion\|exit.criteria\|success.criteria\|## Done" "$skill_file"; then
    pts=$((pts + 1))
  else
    notes="$notes no-done-when;"
  fi

  [ -z "$notes" ] && notes=" CLEAN"
  DETAILS="${DETAILS}${skill}: ${pts}/5${notes}
"
  RAW_TOTAL=$((RAW_TOTAL + pts))
}

# Score each skill
for skill in "${SKILLS[@]}"; do
  score_skill "$skill"
done

# Bonus: validate_newsletter.sh
if [ -f ".github/skills/newsletter-validation/scripts/validate_newsletter.sh" ]; then
  RAW_TOTAL=$((RAW_TOTAL + 1))
  DETAILS="${DETAILS}BONUS: validate_newsletter.sh exists (+1)
"
else
  DETAILS="${DETAILS}BONUS: validate_newsletter.sh MISSING (+0)
"
fi

# Bonus: kb-maintenance scripts
kb_bonus=0
[ -f ".github/skills/kb-maintenance/scripts/poll_sources.py" ] && kb_bonus=$((kb_bonus + 1))
[ -f ".github/skills/kb-maintenance/scripts/check_link_health.py" ] && kb_bonus=$((kb_bonus + 1))
if [ "$kb_bonus" -eq 2 ]; then
  RAW_TOTAL=$((RAW_TOTAL + 1))
  DETAILS="${DETAILS}BONUS: kb-maintenance scripts exist (+1)
"
else
  DETAILS="${DETAILS}BONUS: kb-maintenance scripts (${kb_bonus}/2) (+0)
"
fi

NORMALIZED_TOTAL=$(( (RAW_TOTAL * MAX + RAW_MAX / 2) / RAW_MAX ))

# Output
REPORT="# Structural Rubric Score: ${NORMALIZED_TOTAL}/${MAX}

## Threshold: ≥${THRESHOLD}/${MAX} to proceed

$(if [ "$NORMALIZED_TOTAL" -ge "$THRESHOLD" ]; then echo "**PASS**"; else echo "**FAIL** — fix structural issues before running heuristic scoring"; fi)

## Per-Skill Breakdown

\`\`\`
${DETAILS}\`\`\`

## Raw Score

${RAW_TOTAL}/${RAW_MAX}

## Gate Decision

$(if [ "$NORMALIZED_TOTAL" -ge "$THRESHOLD" ]; then echo "Proceed to heuristic scoring (Layer 2)"; else echo "Fix structural issues. Do not run Layer 2 until this passes."; fi)
"

echo "$REPORT"

if [ -n "$RUN_DIR" ]; then
  mkdir -p "$RUN_DIR/scores"
  echo "$REPORT" > "$RUN_DIR/scores/structural-rubric.md"
  echo "(Written to $RUN_DIR/scores/structural-rubric.md)"
fi

# Exit code reflects pass/fail
[ "$NORMALIZED_TOTAL" -ge "$THRESHOLD" ] && exit 0 || exit 1

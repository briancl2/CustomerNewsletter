#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Automation Sprint Scoring Rubric (40 points max)
# ══════════════════════════════════════════════════════════════
# Pass threshold: >=32/40 (80%)

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

TOTAL=0
MAX=40
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

echo "=== Automation Sprint Scoring Rubric ==="
echo ""

# ── D1: Cleanup (6 pts) ──
echo "D1: Cleanup (6 pts)"

dylan_count=$(grep -r "Dylan" .github/ 2>/dev/null | grep -v validate_newsletter | wc -l | tr -d ' ')
if [ "$dylan_count" -eq 0 ]; then score 2 2 "0 Dylan refs (excl validate_newsletter.sh)"
else score 0 2 "Dylan refs remain: $dylan_count"; fi

ci_lines=$(wc -l < .github/copilot-instructions.md | tr -d ' ')
if [ "$ci_lines" -ge 200 ]; then score 2 2 "copilot-instructions >= 200 lines ($ci_lines)"
else score 0 2 "copilot-instructions < 200 lines ($ci_lines)"; fi

output_count=$( (ls output/*_v[12].md 2>/dev/null || true) | wc -l | tr -d ' ')
if [ "$output_count" -eq 0 ]; then score 1 1 "No _v1/_v2 dupes in output/"
else score 0 1 "Output dupes remain: $output_count"; fi

if bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh output/2026-02_february_newsletter.md > /dev/null 2>&1; then
  score 1 1 "validate_newsletter.sh still passes"
else score 0 1 "validate_newsletter.sh fails"; fi

echo ""

# ── D2: Auto-Archive (6 pts) ──
echo "D2: Auto-Archive (6 pts)"

if [ -x "tools/archive_workspace.sh" ]; then score 2 2 "archive_workspace.sh exists and is executable"
else score 0 2 "archive_workspace.sh missing or not executable"; fi

archived_feb=$( (ls workspace/archived/2026-02_* 2>/dev/null || true) | wc -l | tr -d ' ')
if [ "$archived_feb" -ge 5 ]; then score 2 2 "Feb files archived ($archived_feb files)"
else score 0 2 "Feb files not archived ($archived_feb files)"; fi

remaining_ws=$( (ls workspace/newsletter_phase*.md 2>/dev/null || true) | wc -l | tr -d ' ')
if [ "$remaining_ws" -eq 0 ]; then score 2 2 "No pipeline intermediates in workspace/"
else score 0 2 "Intermediates remain in workspace/ ($remaining_ws)"; fi

echo ""

# ── D3: Editorial Review Loop (12 pts) ──
echo "D3: Editorial Review Loop (12 pts)"

if python3 tools/validate_skill.py .github/skills/editorial-review > /dev/null 2>&1; then
  score 3 3 "editorial-review skill validates"
else score 0 3 "editorial-review skill fails validation"; fi

if [ -f ".github/skills/editorial-review/references/correction-format.md" ]; then
  ref_lines=$(wc -l < .github/skills/editorial-review/references/correction-format.md | tr -d ' ')
  if [ "$ref_lines" -ge 20 ]; then score 2 2 "Correction format spec exists ($ref_lines lines)"
  else score 1 2 "Correction format spec too short ($ref_lines lines)"; fi
else score 0 2 "Correction format spec missing"; fi

if grep -q "corrections" .github/skills/editorial-review/SKILL.md 2>/dev/null && \
   grep -q "newsletter" .github/skills/editorial-review/SKILL.md 2>/dev/null && \
   grep -q "validate" .github/skills/editorial-review/SKILL.md 2>/dev/null; then
  score 3 3 "Skill workflow: corrections -> newsletter -> validate"
else score 0 3 "Skill workflow incomplete"; fi

if grep -q "editorial-review" .github/agents/customer_newsletter.agent.md 2>/dev/null; then
  score 2 2 "Agent pipeline table includes Phase 5"
else score 0 2 "Agent missing Phase 5"; fi

if grep -q "editorial-review" .github/copilot-instructions.md 2>/dev/null; then
  score 2 2 "copilot-instructions mentions Phase 5"
else score 0 2 "copilot-instructions missing Phase 5"; fi

echo ""

# ── D4: Pipeline Orchestration (10 pts) ──
echo "D4: Pipeline Orchestration (10 pts)"

if [ -f ".github/prompts/run_pipeline.prompt.md" ]; then
  score 3 3 "Pipeline prompt file exists"
else score 0 3 "Pipeline prompt file missing"; fi

skill_refs=0
for skill in url-manifest content-retrieval content-consolidation events-extraction content-curation newsletter-assembly; do
  grep -q "$skill" .github/prompts/run_pipeline.prompt.md 2>/dev/null && skill_refs=$((skill_refs + 1))
done
if [ "$skill_refs" -ge 6 ]; then score 3 3 "Prompt references all 6 phase skills ($skill_refs/6)"
else score 1 3 "Prompt references $skill_refs/6 phase skills"; fi

if grep -qi "gate\|verify\|exists" .github/prompts/run_pipeline.prompt.md 2>/dev/null; then
  score 2 2 "Prompt includes phase gates"
else score 0 2 "Prompt missing phase gates"; fi

if grep -qi "editorial-review\|Phase 5" .github/prompts/run_pipeline.prompt.md 2>/dev/null; then
  score 2 2 "Prompt includes Phase 5 editorial loop"
else score 0 2 "Prompt missing Phase 5"; fi

echo ""

# ── D5: KB Polling (6 pts) ──
echo "D5: KB Polling (6 pts)"

if grep -q '^kb-poll:' Makefile; then score 2 2 "kb-poll target exists"
else score 0 2 "kb-poll target missing"; fi

poll_output=$(timeout 15 python3 .github/skills/kb-maintenance/scripts/poll_sources.py --dry-run 2>&1 || echo "error")
if echo "$poll_output" | grep -qi "pollable\|source\|feed"; then
  score 2 2 "kb-poll runs with output"
else score 0 2 "kb-poll fails or no output"; fi

if echo "$poll_output" | grep -qi "poll\|source"; then
  score 2 2 "kb-poll mentions sources"
else score 0 2 "kb-poll output missing source info"; fi

echo ""

# ── Summary ──
echo "═══════════════════════════════════════════"
echo ""
echo "TOTAL: $TOTAL/$MAX"
echo "THRESHOLD: >=32/$MAX (80%)"
echo ""
if [ "$TOTAL" -ge 32 ]; then
  echo "** PASS ** -- Automation sprint meets quality threshold"
else
  echo "** FAIL ** -- Below threshold, rework needed"
fi
echo ""
echo "DETAILS:"
echo "$DETAILS"
exit $([ "$TOTAL" -ge 32 ] && echo 0 || echo 1)

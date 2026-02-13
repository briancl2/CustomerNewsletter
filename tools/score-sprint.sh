#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Sprint Scoring Rubric: Pipeline Hardening & Source Expansion
# ══════════════════════════════════════════════════════════════
# 30 points max. Pass threshold: >=24/30 (80%)
#
# Usage: bash tools/score-sprint.sh

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

TOTAL=0
MAX=30
DETAILS=""

score() {
  local pts="$1"
  local max="$2"
  local label="$3"
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

echo "=== Sprint Scoring Rubric: Pipeline Hardening ==="
echo ""

# ── D1: Makefile Targets (6 pts) ──
echo "D1: Makefile Targets (6 pts)"

# validate-newsletter passes on Dec archive (2 pts)
if make validate-newsletter FILE=archive/2025/December.md > /dev/null 2>&1; then
  score 2 2 "validate-newsletter passes on Dec archive"
else
  score 0 2 "validate-newsletter passes on Dec archive"
fi

# validate-newsletter fails on empty file (1 pt)
echo "" > /tmp/sprint_test_empty.md
if ! make validate-newsletter FILE=/tmp/sprint_test_empty.md > /dev/null 2>&1; then
  score 1 1 "validate-newsletter fails on empty file"
else
  score 0 1 "validate-newsletter fails on empty file"
fi
rm -f /tmp/sprint_test_empty.md

# validate-kb runs without error (2 pts)
kb_output=$(timeout 10 make validate-kb 2>&1 || echo "timeout_or_error")
if echo "$kb_output" | grep -qi "link\|health\|URL\|check"; then
  score 2 2 "validate-kb runs and produces output"
else
  score 0 2 "validate-kb runs and produces output"
fi

# newsletter target exists (1 pt)
if grep -q '^newsletter:' Makefile; then
  score 1 1 "newsletter target exists in Makefile"
else
  score 0 1 "newsletter target exists in Makefile"
fi

echo ""

# ── D2: Orchestration (8 pts) ──
echo "D2: Orchestration (8 pts)"

# run_newsletter.sh exists and is executable (2 pts)
if [ -x "tools/run_newsletter.sh" ]; then
  score 2 2 "run_newsletter.sh exists and is executable"
else
  score 0 2 "run_newsletter.sh exists and is executable"
fi

# Orchestrator produces output for Feb 2026 (existing files) (3 pts)
orchestrator_output=$(bash tools/run_newsletter.sh 2026-01-01 2026-02-10 2>&1)
if echo "$orchestrator_output" | grep -q "VALIDATION: PASSED"; then
  score 3 3 "Orchestrator validates existing Feb newsletter"
else
  score 0 3 "Orchestrator validates existing Feb newsletter"
fi

# Orchestrator correctly blocks on missing files (3 pts)
block_output=$(bash tools/run_newsletter.sh 2025-03-01 2025-03-31 2>&1 || true)
if echo "$block_output" | grep -q "PIPELINE BLOCKED"; then
  score 3 3 "Orchestrator correctly blocks on missing prerequisites"
else
  score 0 3 "Orchestrator correctly blocks on missing prerequisites"
fi

echo ""

# ── D3: Benchmark Test (10 pts) ──
echo "D3: Benchmark Test (10 pts)"

# Benchmark run directory exists with scored output (3 pts)
if [ -f "runs/benchmark-dec2025/curated_output.md" ] && [ -f "runs/benchmark-dec2025/scores/selection-score.md" ]; then
  score 3 3 "Benchmark run completed with scored output"
else
  score 0 3 "Benchmark run completed with scored output"
fi

# Section overlap >=60% (3 pts)
if [ -f "runs/benchmark-dec2025/scores/selection-score.md" ]; then
  section_overlap=$(grep "Section overlap" runs/benchmark-dec2025/scores/selection-score.md | grep -Eo '[0-9]+%' | head -1 | tr -d '%')
  if [ "${section_overlap:-0}" -ge 60 ]; then
    score 3 3 "Section overlap >=60% (${section_overlap}%)"
  else
    score 0 3 "Section overlap <60% (${section_overlap:-0}%)"
  fi
else
  score 0 3 "Section overlap (no score file)"
fi

# Bullet count within 30% of benchmark (2 pts)
if [ -f "runs/benchmark-dec2025/curated_output.md" ]; then
  my_bullets=$( (grep -Ec "^-   \*\*|^- \*\*" runs/benchmark-dec2025/curated_output.md || true) )
  bench_bullets=37  # known Dec benchmark curated bullet count
  if [ "$my_bullets" -ge 26 ] && [ "$my_bullets" -le 48 ]; then
    score 2 2 "Bullet count within 30% ($my_bullets vs $bench_bullets benchmark)"
  else
    score 0 2 "Bullet count out of range ($my_bullets vs $bench_bullets benchmark)"
  fi
else
  score 0 2 "Bullet count (no output file)"
fi

# Selection score >=18/25 (2 pts)
if [ -f "runs/benchmark-dec2025/scores/selection-score.md" ]; then
  sel_score=$(grep -E '^\| \*\*Total\*\*' runs/benchmark-dec2025/scores/selection-score.md | grep -Eo '[0-9]+/25' | head -1 | cut -d/ -f1)
  if [ "${sel_score:-0}" -ge 18 ]; then
    score 2 2 "Selection score >=18/25 (${sel_score}/25)"
  else
    score 0 2 "Selection score <18/25 (${sel_score:-0}/25)"
  fi
else
  score 0 2 "Selection score (no score file)"
fi

echo ""

# ── D4: Sources Expansion (6 pts) ──
echo "D4: Sources Expansion (6 pts)"

# 3 new sources in SOURCES.yaml (2 pts)
new_sources=0
grep -q "devblogs.microsoft.com/visualstudio" kb/SOURCES.yaml && new_sources=$((new_sources + 1))
grep -q "devblogs.microsoft.com/devops" kb/SOURCES.yaml && new_sources=$((new_sources + 1))
grep -q "github.blog/news-insights" kb/SOURCES.yaml && new_sources=$((new_sources + 1))
if [ "$new_sources" -eq 3 ]; then
  score 2 2 "3 new sources in SOURCES.yaml"
else
  score 0 2 "Only $new_sources/3 new sources in SOURCES.yaml"
fi

# SOURCES.yaml is valid YAML (2 pts)
if python3 -c "import yaml; yaml.safe_load(open('kb/SOURCES.yaml'))" 2>/dev/null; then
  score 2 2 "SOURCES.yaml is valid YAML"
else
  score 0 2 "SOURCES.yaml is invalid YAML"
fi

# url-manifest skill references new sources (2 pts)
ref_count=0
grep -q "devblogs.microsoft.com/visualstudio" .github/skills/url-manifest/SKILL.md && ref_count=$((ref_count + 1))
grep -q "devblogs.microsoft.com/devops" .github/skills/url-manifest/SKILL.md && ref_count=$((ref_count + 1))
grep -q "github.blog/news-insights" .github/skills/url-manifest/SKILL.md && ref_count=$((ref_count + 1))
if [ "$ref_count" -ge 3 ]; then
  score 2 2 "url-manifest skill references all 3 new sources"
else
  score 0 2 "url-manifest skill references only $ref_count/3 new sources"
fi

echo ""

# ── Summary ──
echo "═══════════════════════════════════════════"
echo ""
echo "TOTAL: $TOTAL/$MAX"
echo "THRESHOLD: >=24/$MAX (80%)"
echo ""
if [ "$TOTAL" -ge 24 ]; then
  echo "** PASS ** -- Sprint meets quality threshold"
else
  echo "** FAIL ** -- Sprint below threshold, rework needed"
fi
echo ""
echo "DETAILS:"
echo "$DETAILS"

exit $([ "$TOTAL" -ge 24 ] && echo 0 || echo 1)

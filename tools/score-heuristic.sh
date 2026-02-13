#!/usr/bin/env bash
# Layer 2: Heuristic quality scoring for pipeline skills.
# Costs ~5 seconds. Runs content-level checks that structural can't catch.
# Gate: structural rubric must pass first.
#
# Usage: bash tools/score-heuristic.sh [RUN_DIR]
#
# Scoring: 41 points max
#   Tier 1 (26 pts): Structural content — sections, fields, format
#   Tier 2 (10 pts): Content depth — specificity, actionability, domain coverage
#   Tier 3 (5 pts):  Semantic — cross-references, no hallucination, path validity

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

RUN_DIR="${1:-}"
SKILLS=(url-manifest content-retrieval content-consolidation events-extraction content-curation newsletter-assembly newsletter-validation kb-maintenance)

T1=0; T1_MAX=26
T2=0; T2_MAX=10
T3=0; T3_MAX=5
DETAILS=""

add_detail() { DETAILS="$DETAILS$1
"; }

# ── Tier 1: Structural Content (26 pts) ──

# T1.1: Each skill SKILL.md has valid YAML frontmatter (8 pts, 1/skill)
for skill in "${SKILLS[@]}"; do
  f=".github/skills/$skill/SKILL.md"
  if [ -f "$f" ] && head -1 "$f" | grep -q "^---"; then
    T1=$((T1 + 1))
  else
    add_detail "T1.1 FAIL: $skill missing frontmatter"
  fi
done

# T1.2: Each skill references at least one input and one output file path (8 pts, 1/skill)
for skill in "${SKILLS[@]}"; do
  f=".github/skills/$skill/SKILL.md"
  if [ -f "$f" ]; then
    has_input=false; has_output=false
    grep -Eqi 'input|reads|receives|source.*file' "$f" 2>/dev/null && has_input=true
    grep -Eqi 'output|produces|writes|deliverable' "$f" 2>/dev/null && has_output=true
    if $has_input && $has_output; then
      T1=$((T1 + 1))
    else
      add_detail "T1.2 FAIL: $skill missing input/output spec (in=$has_input out=$has_output)"
    fi
  fi
done

# T1.3: No forbidden patterns across all skills (5 pts)
# Exclude examples/ (benchmark data) and scripts/ (rule enforcers) via --exclude-dir
# to avoid false negatives when line content happens to contain "examples/" or "scripts/"
forbidden_patterns=("Dylan" "Copilot Free" "Copilot Individual" "Copilot Pro+")
for pattern in "${forbidden_patterns[@]}"; do
  count=$( (grep -ri --exclude-dir=examples --exclude-dir=scripts "$pattern" .github/skills/ 2>/dev/null || true) | wc -l | tr -d ' ')
  if [ "$count" -eq 0 ]; then
    T1=$((T1 + 1))
  else
    add_detail "T1.3 FAIL: Found '$pattern' ${count}x in skills (excl. examples/scripts)"
  fi
done
# Check double-bracket wikilinks separately (needs escaping)
wikilink_count=$( (grep -r --exclude-dir=examples --exclude-dir=scripts '\[\[' .github/skills/ 2>/dev/null || true) | wc -l | tr -d ' ')
if [ "$wikilink_count" -eq 0 ]; then
  T1=$((T1 + 1))
else
  add_detail "T1.3 FAIL: Found '[[' wikilinks ${wikilink_count}x in skills"
fi

# T1.4: All skill descriptions include keywords (5 pts = 0.625/skill, rounded)
kw_count=0
for skill in "${SKILLS[@]}"; do
  f=".github/skills/$skill/SKILL.md"
  if [ -f "$f" ] && grep -Eqi "keywords|keyword" "$f" 2>/dev/null; then
    kw_count=$((kw_count + 1))
  fi
done
if [ "$kw_count" -ge 6 ]; then T1=$((T1 + 5))
elif [ "$kw_count" -ge 4 ]; then T1=$((T1 + 3)); add_detail "T1.4 PARTIAL: ${kw_count}/8 skills have keywords"
else add_detail "T1.4 FAIL: Only ${kw_count}/8 skills have keywords in description"
fi
add_detail "── Tier 1: ${T1}/${T1_MAX} ──"

# ── Tier 2: Content Depth (10 pts) ──

# T2.1: Reference files have substantive content (4 pts)
ref_with_content=0
total_refs=0
for skill in "${SKILLS[@]}"; do
  for ref in ".github/skills/$skill/references/"*.md; do
    [ ! -f "$ref" ] && continue
    total_refs=$((total_refs + 1))
    rlines=$(wc -l < "$ref" | tr -d ' ')
    if [ "$rlines" -ge 30 ]; then
      ref_with_content=$((ref_with_content + 1))
    fi
  done
done
if [ "$total_refs" -gt 0 ]; then
  ratio=$((ref_with_content * 100 / total_refs))
  if [ "$ratio" -ge 75 ]; then T2=$((T2 + 4))
  elif [ "$ratio" -ge 50 ]; then T2=$((T2 + 2)); add_detail "T2.1 PARTIAL: ${ref_with_content}/${total_refs} refs ≥30 lines"
  else add_detail "T2.1 FAIL: Only ${ref_with_content}/${total_refs} refs ≥30 lines"
  fi
else
  add_detail "T2.1 FAIL: No reference files found"
fi

# T2.2: Skills cover domain-specific terminology (3 pts)
domain_terms=("enterprise" "GA" "IDE")
for term in "${domain_terms[@]}"; do
  if grep -rqi "$term" .github/skills/*/SKILL.md 2>/dev/null; then
    T2=$((T2 + 1))
  else
    add_detail "T2.2 FAIL: Domain term '$term' not found in any skill"
  fi
done

# T2.3: Content curation has selection criteria (1 pt)
if grep -Eqi "(priorit|hierarchy|selection)" .github/skills/content-curation/SKILL.md 2>/dev/null || \
   grep -Eqi "(priorit|hierarchy|selection)" .github/skills/content-curation/references/*.md 2>/dev/null; then
  T2=$((T2 + 1))
else
  add_detail "T2.3 FAIL: content-curation missing selection priority"
fi

# T2.4: Events extraction has category taxonomy (1 pt)
if grep -Eqi "(Copilot.*GitHub Platform|category.*taxonomy|canonical.*categor)" .github/skills/events-extraction/SKILL.md 2>/dev/null || \
   grep -Eqi "(Copilot.*GitHub Platform|category.*taxonomy|canonical.*categor)" .github/skills/events-extraction/references/*.md 2>/dev/null; then
  T2=$((T2 + 1))
else
  add_detail "T2.4 FAIL: events-extraction missing category taxonomy"
fi

# T2.5: newsletter-assembly has section ordering (1 pt)
if grep -Eqi "(section.*order|mandatory.*section|Introduction.*Copilot.*Event)" .github/skills/newsletter-assembly/SKILL.md 2>/dev/null || \
   grep -Eqi "(section.*order|mandatory.*section)" .github/skills/newsletter-assembly/references/*.md 2>/dev/null; then
  T2=$((T2 + 1))
else
  add_detail "T2.5 FAIL: newsletter-assembly missing section ordering"
fi
add_detail "── Tier 2: ${T2}/${T2_MAX} ──"

# ── Tier 3: Semantic (5 pts) ──

# T3.1: Referenced file paths actually exist (2 pts)
bad_refs=0
for skill in "${SKILLS[@]}"; do
  f=".github/skills/$skill/SKILL.md"
  [ ! -f "$f" ] && continue
  # Extract relative paths from markdown links using grep -o (portable)
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    resolved=".github/skills/$skill/$path"
    if [ ! -f "$resolved" ] && [ ! -d "$resolved" ]; then
      bad_refs=$((bad_refs + 1))
    fi
  done < <(grep -Eo '\]\((references|scripts|examples)/[^)]+' "$f" 2>/dev/null | cut -c3- || true)
done
if [ "$bad_refs" -eq 0 ]; then
  T3=$((T3 + 2))
else
  add_detail "T3.1 FAIL: ${bad_refs} broken internal references"
fi

# T3.2: No em dashes in skill content (1 pt)
emdash_count=$( (grep -r "—" .github/skills/ 2>/dev/null || true) | (grep -v "examples/" || true) | wc -l | tr -d ' ')
if [ "$emdash_count" -eq 0 ]; then
  T3=$((T3 + 1))
else
  add_detail "T3.2 FAIL: ${emdash_count} em dashes found"
fi

# T3.3: validate_newsletter.sh is syntactically valid bash (1 pt)
script=".github/skills/newsletter-validation/scripts/validate_newsletter.sh"
if [ -f "$script" ] && bash -n "$script" 2>/dev/null; then
  T3=$((T3 + 1))
else
  add_detail "T3.3 FAIL: validate_newsletter.sh missing or invalid syntax"
fi

# T3.4: Python scripts parse without syntax errors (1 pt)
py_ok=true
for py in .github/skills/kb-maintenance/scripts/*.py; do
  [ ! -f "$py" ] && continue
  if ! python3 -c "import ast; ast.parse(open('$py').read())" 2>/dev/null; then
    py_ok=false
    add_detail "T3.4 FAIL: $py has syntax errors"
  fi
done
if $py_ok && [ -f ".github/skills/kb-maintenance/scripts/poll_sources.py" ]; then
  T3=$((T3 + 1))
else
  [ ! -f ".github/skills/kb-maintenance/scripts/poll_sources.py" ] && add_detail "T3.4 FAIL: poll_sources.py missing"
fi
add_detail "── Tier 3: ${T3}/${T3_MAX} ──"

# ── Report ──
TOTAL=$((T1 + T2 + T3))
TOTAL_MAX=$((T1_MAX + T2_MAX + T3_MAX))

REPORT="# Heuristic Quality Score: ${TOTAL}/${TOTAL_MAX}

## Tier Breakdown

| Tier | Score | Max | Focus |
|------|-------|-----|-------|
| Tier 1 (Structural content) | ${T1} | ${T1_MAX} | Sections, fields, format |
| Tier 2 (Content depth) | ${T2} | ${T2_MAX} | Specificity, domain coverage |
| Tier 3 (Semantic) | ${T3} | ${T3_MAX} | Path validity, no hallucination |
| **Total** | **${TOTAL}** | **${TOTAL_MAX}** | |

## Thresholds

| Tier | Required | Actual | Status |
|------|----------|--------|--------|
| Tier 1 | ≥22/26 | ${T1}/26 | $([ "$T1" -ge 22 ] && echo PASS || echo FAIL) |
| Tier 2 | ≥6/10 | ${T2}/10 | $([ "$T2" -ge 6 ] && echo PASS || echo FAIL) |
| Tier 3 | ≥3/5 | ${T3}/5 | $([ "$T3" -ge 3 ] && echo PASS || echo FAIL) |

## Details

\`\`\`
${DETAILS}\`\`\`

## Weakest Dimension

$(if [ "$T1" -lt 22 ]; then echo "**Tier 1** — fix structural content issues first (cheapest)";
elif [ "$T2" -lt 6 ]; then echo "**Tier 2** — deepen reference content and domain coverage";
elif [ "$T3" -lt 3 ]; then echo "**Tier 3** — fix broken references, syntax errors, or forbidden patterns";
else echo "All tiers pass. Proceed to benchmark testing."; fi)
"

echo "$REPORT"

if [ -n "$RUN_DIR" ]; then
  mkdir -p "$RUN_DIR/scores"
  echo "$REPORT" > "$RUN_DIR/scores/heuristic-scores.md"
  echo "(Written to $RUN_DIR/scores/heuristic-scores.md)"
fi

# Exit: all three tiers must pass
[ "$T1" -ge 22 ] && [ "$T2" -ge 6 ] && [ "$T3" -ge 3 ] && exit 0 || exit 1

#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Intelligence Effectiveness Test
# ══════════════════════════════════════════════════════════════
# Lists 7 intelligence gaps (G1-G7), checks which are encoded as rules,
# and computes projected editorial effectiveness.
#
# Formula: encoded_gaps/7 * (1 - baseline) + baseline
# Baseline: 10.7% (human judgment calls that no rule captures, per EH-10)
# Target: >=30% projected effectiveness
#
# Usage: bash tools/test_intelligence_effectiveness.sh
# Exit: 0 if >=30%, 1 if below

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

TOTAL_GAPS=7
ENCODED=0

echo "══════════════════════════════════════════════════════"
echo "  Intelligence Effectiveness Test"
echo "══════════════════════════════════════════════════════"
echo ""
echo "Checking 7 intelligence gaps for encoded rules..."
echo ""

count_matches() {
  local pattern="$1"
  local file="$2"
  local count
  count=$(grep -Ec "$pattern" "$file" 2>/dev/null || true)
  count=$(printf '%s' "$count" | tr -d '[:space:]')
  [ -n "$count" ] || count=0
  echo "$count"
}

# G1: Evergreen training resources included every month
g1=$(count_matches "Include ONLY when new resources published|Q4=B" ".github/skills/content-curation/references/selection-criteria.md")
if [ "$g1" -ge 1 ]; then
  echo "  ENCODED: G1 - Evergreen training resource rule (Q4=B)"
  ENCODED=$((ENCODED + 1))
else
  echo "  MISSING: G1 - Evergreen training resource rule"
fi

# G2: New product categories get own sections
g2=$(count_matches "New product category.*section|new product category" "reference/editorial-intelligence.md")
if [ "$g2" -ge 1 ]; then
  echo "  ENCODED: G2 - New product categories get own sections"
  ENCODED=$((ENCODED + 1))
else
  echo "  MISSING: G2 - New product categories get own sections"
fi

# G3: Legal changes always expanded
g3=$(count_matches "Legal.*always expand|legal.*always expand|indemnity.*always" ".github/skills/content-curation/references/selection-criteria.md")
if [ "$g3" -ge 1 ]; then
  echo "  ENCODED: G3 - Legal changes always expanded"
  ENCODED=$((ENCODED + 1))
else
  echo "  MISSING: G3 - Legal changes always expanded"
fi

# G4: IDE monthly update deep-read
g4=$(count_matches "IDE Monthly Update Deep-Read|deep-read the full release notes" ".github/skills/content-retrieval/SKILL.md")
if [ "$g4" -ge 1 ]; then
  echo "  ENCODED: G4 - IDE monthly update deep-read"
  ENCODED=$((ENCODED + 1))
else
  echo "  MISSING: G4 - IDE monthly update deep-read"
fi

# G5: Cross-category governance bundling
g5=$(count_matches "Cross-Category Governance Bundling|cross-category governance" "reference/editorial-intelligence.md")
if [ "$g5" -ge 1 ]; then
  echo "  ENCODED: G5 - Cross-category governance bundling"
  ENCODED=$((ENCODED + 1))
else
  echo "  MISSING: G5 - Cross-category governance bundling"
fi

# G6: Context-dependent exclusion
g6=$(count_matches "Context-Dependent Exclusion|context-dependent exclusion" "reference/editorial-intelligence.md")
if [ "$g6" -ge 1 ]; then
  echo "  ENCODED: G6 - Context-dependent exclusion"
  ENCODED=$((ENCODED + 1))
else
  echo "  MISSING: G6 - Context-dependent exclusion"
fi

# G7: Same-type group compression (was Same-capability pair)
g7=$(count_matches "Same-type group" "reference/editorial-intelligence.md")
if [ "$g7" -ge 1 ]; then
  echo "  ENCODED: G7 - Same-type group compression"
  ENCODED=$((ENCODED + 1))
else
  echo "  MISSING: G7 - Same-type group compression (still 'Same-capability pair')"
fi

# Compute effectiveness
# baseline = 0.107 (EH-10: 7 judgment calls no rule captures, ~10.7% of editorial decisions)
# formula: encoded/7 * (1 - 0.107) + 0.107
echo ""

# Use awk for floating point
effectiveness=$(echo "$ENCODED $TOTAL_GAPS" | awk '{printf "%.1f", ($1/$2) * (1 - 0.107) + 0.107}')
pct=$(echo "$ENCODED $TOTAL_GAPS" | awk '{printf "%.0f", (($1/$2) * (1 - 0.107) + 0.107) * 100}')

echo "══════════════════════════════════════════════════════"
echo "  Results: $ENCODED/$TOTAL_GAPS gaps encoded"
echo "  Projected effectiveness: ${pct}% (${effectiveness})"
echo "  Target: >=30%"
echo "══════════════════════════════════════════════════════"
echo ""

if [ "$pct" -ge 30 ]; then
  echo "** PASS — effectiveness >= 30% **"
  exit 0
else
  echo "** FAIL — effectiveness < 30% (need more gaps encoded) **"
  exit 1
fi

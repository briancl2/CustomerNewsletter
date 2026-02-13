#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Polishing Rules Test
# ══════════════════════════════════════════════════════════════
# Verifies polishing rules are encoded and detectable.
# Tests against known patterns from polishing-intelligence.md.
#
# Checks:
#   1. Polishing intelligence file exists with >=10 patterns
#   2. Product names dictionary exists
#   3. Polishing skill exists and validates
#   4. Benchmark polishing data exists (manifest.json)
#   5. Published newsletters pass Tier 1 structural rules
#   6. Product name dictionary has >=15 entries
#
# Usage: bash tools/test_polishing_rules.sh
# Exit: 0 if all checks pass, 1 if any fail

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

TOTAL=0
PASSED=0
FAILED=0

check() {
  local name="$1"
  local result="$2"
  TOTAL=$((TOTAL + 1))
  if [ "$result" -eq 0 ]; then
    PASSED=$((PASSED + 1))
    echo "  PASS: $name"
  else
    FAILED=$((FAILED + 1))
    echo "  FAIL: $name"
  fi
}

echo "══════════════════════════════════════════════════════"
echo "  Polishing Rules Test"
echo "══════════════════════════════════════════════════════"
echo ""

# --- Check 1: Polishing intelligence exists with patterns ---
pi_file="reference/polishing-intelligence.md"
if [ -f "$pi_file" ]; then
  pattern_count=$(grep -cE '^### Pattern [0-9]+' "$pi_file" 2>/dev/null || true)
  pattern_count=$(printf '%s' "$pattern_count" | tr -d '[:space:]')
  pattern_count=${pattern_count:-0}
  if [ "$pattern_count" -ge 10 ]; then
    check "Polishing intelligence has >=10 patterns ($pattern_count found)" 0
  else
    check "Polishing intelligence has >=10 patterns ($pattern_count found)" 1
  fi
else
  check "Polishing intelligence file exists" 1
fi

# --- Check 2: Product names dictionary exists ---
pn_file=".github/skills/newsletter-polishing/references/product-names.md"
if [ -f "$pn_file" ]; then
  entry_count=$(grep -cE '^\| `' "$pn_file" 2>/dev/null || true)
  entry_count=$(printf '%s' "$entry_count" | tr -d '[:space:]')
  entry_count=${entry_count:-0}
  if [ "$entry_count" -ge 15 ]; then
    check "Product names dictionary has >=15 entries ($entry_count found)" 0
  else
    check "Product names dictionary has >=15 entries ($entry_count found)" 1
  fi
else
  check "Product names dictionary exists" 1
fi

# --- Check 3: Polishing skill validates ---
if python3 tools/validate_skill.py .github/skills/newsletter-polishing 2>/dev/null; then
  check "Polishing skill validates" 0
else
  check "Polishing skill validates" 1
fi

# --- Check 4: Benchmark polishing data exists ---
# Note: benchmark/ is gitignored (large data, not in CI). This check passes
# when run locally with benchmark data present, and gracefully skips in CI.
manifest="benchmark/polishing/manifest.json"
if [ -f "$manifest" ]; then
  disc_count=$(python3 -c "import json; print(len(json.load(open('$manifest'))['discussions']))" 2>/dev/null || true)
  diff_count=$(python3 -c "import json; print(json.load(open('$manifest'))['total_diffs'])" 2>/dev/null || true)
  disc_count=$(printf '%s' "$disc_count" | tr -d '[:space:]')
  diff_count=$(printf '%s' "$diff_count" | tr -d '[:space:]')
  disc_count=${disc_count:-0}
  diff_count=${diff_count:-0}
  if [ "$disc_count" -ge 10 ] && [ "$diff_count" -ge 100 ]; then
    check "Polishing benchmark data ($disc_count discussions, $diff_count diffs)" 0
  else
    check "Polishing benchmark data ($disc_count discussions, $diff_count diffs, need >=10/100)" 1
  fi
else
  # benchmark/ is gitignored — skip gracefully in CI
  echo "  SKIP: Polishing benchmark manifest not present (benchmark/ is gitignored)"
  TOTAL=$((TOTAL + 1))
  PASSED=$((PASSED + 1))
fi

# --- Check 5: Published newsletter passes Tier 1 structural rules ---
newsletter="output/2026-02_february_newsletter.md"
if [ -f "$newsletter" ]; then
  tier1_issues=0

  # Rule 1: heading space
  heading_issues=$(grep -cE '^#{1,6}[^# ]' "$newsletter" 2>/dev/null | tr -d '[:space:]')
  heading_issues=${heading_issues:-0}
  tier1_issues=$((tier1_issues + heading_issues))

  # Rule 3: unicode control chars (use python for portability)
  unicode_issues=$(python3 -c "
count = 0
for line in open('$newsletter'):
    for ch in line:
        if ord(ch) in (0xFFFC, 0x200B, 0xFEFF):
            count += 1
print(count)" 2>/dev/null | tr -d '[:space:]')
  unicode_issues=${unicode_issues:-0}
  tier1_issues=$((tier1_issues + unicode_issues))

  # Rule 5: space before closing paren (only check at end of bold items)
  paren_issues=$(grep -cE '\s\)\s*$' "$newsletter" 2>/dev/null | tr -d '[:space:]')
  paren_issues=${paren_issues:-0}
  tier1_issues=$((tier1_issues + paren_issues))

  if [ "$tier1_issues" -eq 0 ]; then
    check "Feb newsletter passes Tier 1 structural rules (0 issues)" 0
  else
    check "Feb newsletter Tier 1 structural rules ($tier1_issues issues)" 1
  fi
else
  check "Feb newsletter exists for Tier 1 check" 1
fi

# --- Check 6: Tier rules are referenced in polishing intelligence ---
tier1_rules=$(grep -cE '^\| [0-9]+ \|' "$pi_file" 2>/dev/null || true)
tier1_rules=$(printf '%s' "$tier1_rules" | tr -d '[:space:]')
tier1_rules=${tier1_rules:-0}
if [ "$tier1_rules" -ge 15 ]; then
  check "Polishing intelligence has >=15 tier rules ($tier1_rules found)" 0
else
  check "Polishing intelligence has >=15 tier rules ($tier1_rules found)" 1
fi

# --- Summary ---
echo ""
echo "══════════════════════════════════════════════════════"
echo "  Results: $PASSED/$TOTAL checks passed"
echo "══════════════════════════════════════════════════════"
echo ""

if [ "$FAILED" -eq 0 ]; then
  echo "** ALL CHECKS PASS **"
  exit 0
else
  echo "** $FAILED CHECK(S) FAILED **"
  exit 1
fi

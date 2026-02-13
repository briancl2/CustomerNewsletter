#!/usr/bin/env bash
# Validates that fleet skill building produced complete, high-quality SKILL.md files.
# Run after fleet completes: ./tools/validate_fleet_output.sh

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SKILLS=(url-manifest content-retrieval content-consolidation events-extraction content-curation newsletter-assembly newsletter-validation kb-maintenance)
ERRORS=0
WARNINGS=0

echo "═══════════════════════════════════════════════════"
echo "  Fleet Output Validation"
echo "═══════════════════════════════════════════════════"
echo ""

# 1. Structural validation via make
echo "── Step 1: Structural validation ──"
if make validate-all-skills 2>&1; then
  echo -e "${GREEN}✓ All skills pass structural validation${NC}"
else
  echo -e "${RED}✗ Structural validation failed${NC}"
  ERRORS=$((ERRORS + 1))
fi
echo ""

# 2. Content completeness checks
echo "── Step 2: Content completeness ──"
for skill in "${SKILLS[@]}"; do
  skill_dir=".github/skills/$skill"
  skill_file="$skill_dir/SKILL.md"
  
  # Check SKILL.md line count
  if [ -f "$skill_file" ]; then
    lines=$(wc -l < "$skill_file" | tr -d ' ')
    if [ "$lines" -lt 50 ]; then
      echo -e "${RED}✗ $skill: SKILL.md only ${lines} lines (need >50 — likely still placeholder)${NC}"
      ERRORS=$((ERRORS + 1))
    elif [ "$lines" -lt 100 ]; then
      echo -e "${YELLOW}⚠ $skill: SKILL.md ${lines} lines (thin — consider expanding)${NC}"
      WARNINGS=$((WARNINGS + 1))
    else
      echo -e "${GREEN}✓ $skill: SKILL.md ${lines} lines${NC}"
    fi
  else
    echo -e "${RED}✗ $skill: SKILL.md missing!${NC}"
    ERRORS=$((ERRORS + 1))
  fi
  
  # Check reference files
  ref_count=$(find "$skill_dir/references" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$ref_count" -eq 0 ]; then
    echo -e "${RED}  ✗ No reference files in $skill/references/${NC}"
    ERRORS=$((ERRORS + 1))
  else
    echo -e "${GREEN}  ✓ ${ref_count} reference file(s)${NC}"
  fi
  
  # Check example files
  ex_count=$(find "$skill_dir/examples" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$ex_count" -eq 0 ] && [ "$skill" != "kb-maintenance" ]; then
    echo -e "${YELLOW}  ⚠ No example files (expected for most pipeline skills)${NC}"
    WARNINGS=$((WARNINGS + 1))
  else
    echo -e "${GREEN}  ✓ ${ex_count} example file(s)${NC}"
  fi
done
echo ""

# 3. Script existence checks
echo "── Step 3: Required scripts ──"
if [ -f ".github/skills/newsletter-validation/scripts/validate_newsletter.sh" ]; then
  echo -e "${GREEN}✓ newsletter-validation/scripts/validate_newsletter.sh exists${NC}"
  if [ -x ".github/skills/newsletter-validation/scripts/validate_newsletter.sh" ]; then
    echo -e "${GREEN}  ✓ Is executable${NC}"
  else
    echo -e "${YELLOW}  ⚠ Not executable (chmod +x needed)${NC}"
    WARNINGS=$((WARNINGS + 1))
  fi
else
  echo -e "${RED}✗ newsletter-validation/scripts/validate_newsletter.sh missing${NC}"
  ERRORS=$((ERRORS + 1))
fi

for script in poll_sources.py check_link_health.py; do
  if [ -f ".github/skills/kb-maintenance/scripts/$script" ]; then
    echo -e "${GREEN}✓ kb-maintenance/scripts/$script exists${NC}"
  else
    echo -e "${RED}✗ kb-maintenance/scripts/$script missing${NC}"
    ERRORS=$((ERRORS + 1))
  fi
done
echo ""

# 4. Content quality spot checks
echo "── Step 4: Content quality spot checks ──"
for skill in "${SKILLS[@]}"; do
  skill_file=".github/skills/$skill/SKILL.md"
  [ ! -f "$skill_file" ] && continue
  
  # Check for TODO placeholder (skill wasn't actually built)
  if grep -q "^TODO: Build this skill" "$skill_file"; then
    echo -e "${RED}✗ $skill: Still contains placeholder TODO${NC}"
    ERRORS=$((ERRORS + 1))
    continue
  fi
  
  # Check for key sections
  has_workflow=false
  has_done_when=false
  if grep -qi "workflow\|quick start\|core workflow\|how.*work" "$skill_file"; then
    has_workflow=true
  fi
  if grep -qi "done.when\|completion\|exit.criteria\|success" "$skill_file"; then
    has_done_when=true
  fi
  
  if $has_workflow && $has_done_when; then
    echo -e "${GREEN}✓ $skill: Has workflow + completion criteria${NC}"
  else
    [ "$has_workflow" = false ] && echo -e "${YELLOW}  ⚠ $skill: Missing workflow/process section${NC}" && WARNINGS=$((WARNINGS + 1))
    [ "$has_done_when" = false ] && echo -e "${YELLOW}  ⚠ $skill: Missing done-when/completion criteria${NC}" && WARNINGS=$((WARNINGS + 1))
  fi
done

# 5. Forbidden content check
echo ""
echo "── Step 5: Forbidden content ──"
dylan_count=$(grep -ri "Dylan" .github/skills/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$dylan_count" -gt 0 ]; then
  echo -e "${RED}✗ Found ${dylan_count} Dylan's Corner reference(s) in skills${NC}"
  grep -ri "Dylan" .github/skills/ 2>/dev/null
  ERRORS=$((ERRORS + 1))
else
  echo -e "${GREEN}✓ No Dylan's Corner references${NC}"
fi

# Summary
echo ""
echo "═══════════════════════════════════════════════════"
if [ "$ERRORS" -eq 0 ]; then
  echo -e "${GREEN}  PASSED — ${WARNINGS} warning(s)${NC}"
  echo "  Ready for Phase 1B: sequential benchmark testing"
else
  echo -e "${RED}  FAILED — ${ERRORS} error(s), ${WARNINGS} warning(s)${NC}"
  echo "  Fix errors before proceeding"
fi
echo "═══════════════════════════════════════════════════"

exit "$ERRORS"

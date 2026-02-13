#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Intelligence Sync Check
# ══════════════════════════════════════════════════════════════
# Verifies editorial intelligence is properly propagated across
# all consuming surfaces: skills, agent, prompts, references.
#
# Checks:
#   1. editorial-intelligence weights match selection-criteria weights
#   2. agent reads LEARNINGS.md
#   3. content-curation references editorial-intelligence
#   4. content-consolidation references editorial-intelligence
#   5. newsletter-assembly references editorial-intelligence
#   6. content-retrieval references source-intelligence
#   7. newsletter-polishing references polishing-intelligence
#   8. run_pipeline.prompt.md references Phase 4.5
#
# Usage: bash tools/check_intelligence_sync.sh
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
echo "  Intelligence Sync Check"
echo "══════════════════════════════════════════════════════"
echo ""

# --- Check 1: editorial-intelligence weights match selection-criteria weights ---
# Both files should have all 10 weight priorities
ei_file="reference/editorial-intelligence.md"
sc_file=".github/skills/content-curation/references/selection-criteria.md"

ei_weights=$(grep -cE '\*\*[0-9]+\.[0-9]+x\*\*' "$ei_file" 2>/dev/null || echo 0)
sc_weights=$(grep -cE '\*\*[0-9]+\.[0-9]+x\*\*' "$sc_file" 2>/dev/null || echo 0)

# Check that selection-criteria has all 10 weights
if [ "$sc_weights" -ge 10 ]; then
  check "Selection-criteria has all 10 weights ($sc_weights found)" 0
else
  check "Selection-criteria has all 10 weights ($sc_weights found, need >=10)" 1
fi

# Check that 3.5x and 2.0x (Platform Openness) both present in selection-criteria
has_35x=$(grep -c "3\.5x" "$sc_file" 2>/dev/null || echo 0)
has_20x_platform=$(grep -c "Platform Openness" "$sc_file" 2>/dev/null || echo 0)
if [ "$has_35x" -ge 1 ] && [ "$has_20x_platform" -ge 1 ]; then
  check "Competitive Positioning (3.5x) and Platform Openness present" 0
else
  check "Competitive Positioning (3.5x=$has_35x) and Platform Openness ($has_20x_platform) present" 1
fi

# --- Check 2: Agent reads LEARNINGS.md ---
agent_file=".github/agents/customer_newsletter.agent.md"
agent_learnings=$(grep -c "LEARNINGS.md" "$agent_file" 2>/dev/null || echo 0)
if [ "$agent_learnings" -ge 1 ]; then
  check "Agent reads LEARNINGS.md ($agent_learnings refs)" 0
else
  check "Agent reads LEARNINGS.md ($agent_learnings refs)" 1
fi

# --- Check 3: content-curation references editorial-intelligence ---
curation_skill=".github/skills/content-curation/SKILL.md"
curation_refs=$(grep -c "editorial-intelligence" "$curation_skill" 2>/dev/null || echo 0)
if [ "$curation_refs" -ge 1 ]; then
  check "content-curation refs editorial-intelligence ($curation_refs refs)" 0
else
  check "content-curation refs editorial-intelligence ($curation_refs refs)" 1
fi

# --- Check 4: content-consolidation references editorial-intelligence ---
consolidation_skill=".github/skills/content-consolidation/SKILL.md"
consolidation_refs=$(grep -c "editorial-intelligence" "$consolidation_skill" 2>/dev/null || echo 0)
if [ "$consolidation_refs" -ge 1 ]; then
  check "content-consolidation refs editorial-intelligence ($consolidation_refs refs)" 0
else
  check "content-consolidation refs editorial-intelligence ($consolidation_refs refs)" 1
fi

# --- Check 5: newsletter-assembly references editorial-intelligence ---
assembly_skill=".github/skills/newsletter-assembly/SKILL.md"
assembly_refs=$(grep -c "editorial-intelligence" "$assembly_skill" 2>/dev/null || echo 0)
if [ "$assembly_refs" -ge 1 ]; then
  check "newsletter-assembly refs editorial-intelligence ($assembly_refs refs)" 0
else
  check "newsletter-assembly refs editorial-intelligence ($assembly_refs refs)" 1
fi

# --- Check 6: content-retrieval references source-intelligence ---
retrieval_skill=".github/skills/content-retrieval/SKILL.md"
retrieval_refs=$(grep -c "source-intelligence" "$retrieval_skill" 2>/dev/null || echo 0)
if [ "$retrieval_refs" -ge 1 ]; then
  check "content-retrieval refs source-intelligence ($retrieval_refs refs)" 0
else
  check "content-retrieval refs source-intelligence ($retrieval_refs refs)" 1
fi

# --- Check 7: newsletter-polishing references polishing-intelligence ---
polishing_skill=".github/skills/newsletter-polishing/SKILL.md"
polishing_refs=$(grep -c "polishing-intelligence" "$polishing_skill" 2>/dev/null || echo 0)
if [ "$polishing_refs" -ge 1 ]; then
  check "newsletter-polishing refs polishing-intelligence ($polishing_refs refs)" 0
else
  check "newsletter-polishing refs polishing-intelligence ($polishing_refs refs)" 1
fi

# --- Check 8: run_pipeline.prompt.md references Phase 4.5 ---
pipeline_prompt=".github/prompts/run_pipeline.prompt.md"
phase45_refs=$(grep -c "Phase 4.5\|newsletter-polishing" "$pipeline_prompt" 2>/dev/null || echo 0)
if [ "$phase45_refs" -ge 1 ]; then
  check "Pipeline prompt references Phase 4.5 polishing ($phase45_refs refs)" 0
else
  check "Pipeline prompt references Phase 4.5 polishing ($phase45_refs refs)" 1
fi

# --- Summary ---
echo ""
echo "══════════════════════════════════════════════════════"
echo "  Results: $PASSED/$TOTAL checks passed"
echo "  Surfaces verified: $TOTAL"
echo "══════════════════════════════════════════════════════"
echo ""

if [ "$FAILED" -eq 0 ]; then
  echo "** ALL CHECKS PASS **"
  exit 0
else
  echo "** $FAILED CHECK(S) FAILED **"
  exit 1
fi

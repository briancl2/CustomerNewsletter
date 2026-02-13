#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# V2 Newsletter Scoring Rubric (50 points max)
# ══════════════════════════════════════════════════════════════
# Scores the February V2 newsletter against specific editorial hypotheses.
# Pass threshold: >=40/50 (80%)
#
# Usage: bash tools/score-v2-rubric.sh <newsletter_file>

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

FILE="${1:-output/2026-02_february_newsletter.md}"

if [ ! -f "$FILE" ]; then
  echo "Error: $FILE not found"
  exit 1
fi

BODY=$(cat "$FILE")
BODY_LC=$(echo "$BODY" | tr 'A-Z' 'a-z')

TOTAL=0
MAX=50
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

echo "═══ V2 Newsletter Scoring Rubric ═══"
echo "File: $FILE"
echo ""

# ── Dimension 1: Theme Correctness (10 pts) ──
echo "Dimension 1: Theme Correctness (10 pts)"
D1=0

# Lead section has competitive/platform-openness theme (not "Platform Maturation")
if echo "$BODY" | head -20 | grep -Eqi "everywhere|platform.*open|open.*platform|competitive|your.*agent|pick.*agent|choice"; then
  score 2 2 "Lead theme is platform-openness/competitive (not abstract maturation)"
  D1=$((D1 + 2))
else
  score 0 2 "Lead theme is platform-openness/competitive (not abstract maturation)"
fi

# Lead includes Agent HQ 3P
if echo "$BODY_LC" | grep -q "agent hq\|claude.*codex.*agent\|third.party.*agent\|3p.*agent\|codex.*claude"; then
  score 2 2 "Lead includes Agent HQ 3P (Claude + Codex)"
  D1=$((D1 + 2))
else
  score 0 2 "Lead includes Agent HQ 3P (Claude + Codex)"
fi

# Lead includes CLI competitive angle
if echo "$BODY_LC" | grep -q "copilot cli\|cli.*agent\|copilot.*cli"; then
  score 2 2 "Lead includes Copilot CLI"
  D1=$((D1 + 2))
else
  score 0 2 "Lead includes Copilot CLI"
fi

# Lead includes OpenCode
if echo "$BODY_LC" | grep -q "opencode"; then
  score 2 2 "Lead includes OpenCode support"
  D1=$((D1 + 2))
else
  score 0 2 "Lead includes OpenCode support"
fi

# Lead includes BYOK
if echo "$BODY_LC" | grep -q "byok\|bring your own"; then
  score 2 2 "Lead includes BYOK platform choice"
  D1=$((D1 + 2))
else
  score 0 2 "Lead includes BYOK platform choice"
fi

echo ""

# ── Dimension 2: Content Completeness (15 pts) ──
echo "Dimension 2: Content Completeness (15 pts)"
D2=0

# Agent HQ 3P with meaningful detail (3 pts)
hq_detail=0
echo "$BODY_LC" | grep -q "agent hq\|claude.*codex\|codex.*claude" && hq_detail=$((hq_detail + 1))
echo "$BODY_LC" | grep -q "assign.*agent\|compare.*agent\|multiple.*agent\|issue.*agent\|pull.*request.*agent" && hq_detail=$((hq_detail + 1))
echo "$BODY_LC" | grep -q "news-insights\|pick-your-agent\|claude-and-codex" && hq_detail=$((hq_detail + 1))
score $hq_detail 3 "Agent HQ 3P with meaningful detail ($hq_detail/3 signals)"
D2=$((D2 + hq_detail))

# OpenCode support mentioned (2 pts)
if echo "$BODY_LC" | grep -q "opencode"; then
  score 2 2 "OpenCode support mentioned"
  D2=$((D2 + 2))
else
  score 0 2 "OpenCode support mentioned"
fi

# VS Code v1.109 with >=5 features (3 pts)
vsc_features=0
echo "$BODY_LC" | grep -q "agent skills\|skills.*ga\|skills.*generally" && vsc_features=$((vsc_features + 1))
echo "$BODY_LC" | grep -q "claude agent" && vsc_features=$((vsc_features + 1))
echo "$BODY_LC" | grep -q "copilot memory\|memory.*preview" && vsc_features=$((vsc_features + 1))
echo "$BODY_LC" | grep -q "subagent\|sub-agent\|parallel.*agent" && vsc_features=$((vsc_features + 1))
echo "$BODY_LC" | grep -q "terminal sandbox\|sandbox.*terminal" && vsc_features=$((vsc_features + 1))
echo "$BODY_LC" | grep -q "organization.wide.*instruction\|org.wide.*instruction\|org.*level.*instruction" && vsc_features=$((vsc_features + 1))
echo "$BODY_LC" | grep -q "mcp app" && vsc_features=$((vsc_features + 1))
if [ "$vsc_features" -ge 5 ]; then
  score 3 3 "VS Code v1.109 with >=5 features ($vsc_features found)"
elif [ "$vsc_features" -ge 3 ]; then
  score 2 3 "VS Code v1.109 with 3-4 features ($vsc_features found)"
else
  score 0 3 "VS Code v1.109 with <3 features ($vsc_features found)"
fi
D2=$((D2 + (vsc_features >= 5 ? 3 : (vsc_features >= 3 ? 2 : 0))))

# CLI expanded with deeper features (2 pts)
cli_depth=0
echo "$BODY_LC" | grep -q "plan.*mode\|plan.*first\|plan.*before\|plan.*build" && cli_depth=$((cli_depth + 1))
echo "$BODY_LC" | grep -q "acp\|agent context protocol" && cli_depth=$((cli_depth + 1))
if [ "$cli_depth" -ge 2 ]; then score 2 2 "CLI expanded with deeper features"; D2=$((D2 + 2))
elif [ "$cli_depth" -ge 1 ]; then score 1 2 "CLI partially expanded ($cli_depth/2 features)"; D2=$((D2 + 1))
else score 0 2 "CLI not expanded"; fi

# Governance bundle (2 pts)
gov_bundle=0
echo "$BODY_LC" | grep -q "supply chain\|slsa\|traceability\|artifact" && gov_bundle=$((gov_bundle + 1))
echo "$BODY_LC" | grep -q "custom propert\|org.*propert" && gov_bundle=$((gov_bundle + 1))
echo "$BODY_LC" | grep -q "dependabot.*oidc\|oidc.*dependabot\|oidc.*auth" && gov_bundle=$((gov_bundle + 1))
if [ "$gov_bundle" -ge 3 ]; then score 2 2 "Governance bundle (3/3 items present)"; D2=$((D2 + 2))
elif [ "$gov_bundle" -ge 2 ]; then score 1 2 "Governance bundle partial ($gov_bundle/3)"; D2=$((D2 + 1))
else score 0 2 "Governance bundle missing ($gov_bundle/3)"; fi

# Deprecation bundle (1 pt)
if echo "$BODY_LC" | grep -q "deprecat\|migration.*notice\|closing down"; then
  score 1 1 "Deprecation/migration notices present"
  D2=$((D2 + 1))
else
  score 0 1 "Deprecation notices missing"
fi

# CodeQL removed (1 pt) - should NOT be a standalone item
codeql_standalone=0
# Look for CodeQL as a bold standalone bullet
if echo "$BODY" | grep -E '^\-\s+\*\*CodeQL' | grep -qv "bundle\|governance\|consolidat"; then
  score 0 1 "CodeQL still standalone (should be removed)"
else
  score 1 1 "CodeQL removed or not standalone"
  D2=$((D2 + 1))
fi

# Standalone Dependabot OIDC removed (1 pt) - should be bundled, not standalone
if echo "$BODY" | grep -E '^\-\s+\*\*Dependabot OIDC' | grep -qv "bundle\|governance\|consolidat"; then
  score 0 1 "Dependabot OIDC still standalone (should be bundled)"
else
  score 1 1 "Dependabot OIDC bundled or removed"
  D2=$((D2 + 1))
fi

echo ""

# ── Dimension 3: Structure & Format (10 pts) ──
echo "Dimension 3: Structure & Format (10 pts)"
D3=0

# Passes validate_newsletter.sh (5 pts)
if bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh "$FILE" > /dev/null 2>&1; then
  score 5 5 "validate_newsletter.sh passes"
  D3=$((D3 + 5))
else
  score 0 5 "validate_newsletter.sh FAILS"
fi

# Line count 120-150 (3 pts)
lines=$(wc -l < "$FILE" | tr -d ' ')
if [ "$lines" -ge 120 ] && [ "$lines" -le 150 ]; then
  score 3 3 "Line count in target range ($lines lines)"
  D3=$((D3 + 3))
elif [ "$lines" -ge 100 ] && [ "$lines" -le 170 ]; then
  score 1 3 "Line count near target ($lines lines, target 120-150)"
  D3=$((D3 + 1))
else
  score 0 3 "Line count out of range ($lines lines, target 120-150)"
fi

# GA/PREVIEW labels (2 pts) — check both plain and backtick format
ga_count=$( (grep -Ec '\(GA\)|\(`GA`\)' "$FILE" || true) | tr -d ' ')
preview_count=$( (grep -Ec '\(PREVIEW\)|\(`PREVIEW`\)' "$FILE" || true) | tr -d ' ')
if [ "$ga_count" -ge 1 ] && [ "$preview_count" -ge 1 ]; then
  score 2 2 "GA/PREVIEW labels present (GA=$ga_count, PREVIEW=$preview_count)"
  D3=$((D3 + 2))
elif [ "$ga_count" -ge 1 ] || [ "$preview_count" -ge 1 ]; then
  score 1 2 "Only partial labels (GA=$ga_count, PREVIEW=$preview_count)"
  D3=$((D3 + 1))
else
  score 0 2 "No GA/PREVIEW labels"
fi

echo ""

# ── Dimension 4: Editorial Alignment (10 pts) ──
echo "Dimension 4: Editorial Alignment (10 pts)"
D4=0

# Model availability compressed to 1 bullet (2 pts)
# Only match bullets whose bold title contains model availability terms
model_bullets=$( (grep -Ec '^\-\s+\*\*[^*]*(Model availability|model.*update|GPT-[0-9]|Gemini [0-9])' "$FILE" || true) )
if [ "$model_bullets" -le 1 ]; then
  score 2 2 "Models compressed to <=1 bullet ($model_bullets)"
  D4=$((D4 + 2))
else
  score 0 2 "Models NOT compressed ($model_bullets bullets)"
fi

# Competitive positioning frames lead (3 pts)
comp_signals=0
echo "$BODY_LC" | grep -q "competitive\|rival\|claude code\|alternative\|market\|ecosystem\|platform choice\|customer choice" && comp_signals=$((comp_signals + 1))
echo "$BODY_LC" | grep -q "bring.*subscription\|take.*subscription\|anywhere\|platform.*open" && comp_signals=$((comp_signals + 1))
echo "$BODY_LC" | grep -q "agent.*choice\|pick.*agent\|choose.*agent\|multiple.*provider" && comp_signals=$((comp_signals + 1))
score $comp_signals 3 "Competitive positioning signals ($comp_signals/3)"
D4=$((D4 + comp_signals))

# Audience-appropriate tone (3 pts)
tone_signals=0
echo "$BODY_LC" | grep -q "enterprise\|organization\|admin\|governance\|compliance" && tone_signals=$((tone_signals + 1))
echo "$BODY_LC" | grep -q "engineering manager\|devops\|it leadership\|regulated\|healthcare\|manufacturing\|financial" && tone_signals=$((tone_signals + 1))
echo "$BODY_LC" | grep -q "policy\|security\|risk\|trust\|control" && tone_signals=$((tone_signals + 1))
score $tone_signals 3 "Enterprise audience tone ($tone_signals/3)"
D4=$((D4 + tone_signals))

# IDE parity pattern if applicable (2 pts)
if echo "$BODY_LC" | grep -q "ide.*parity\|cross.ide\|vs code.*visual studio.*jetbrains\|all ides\|across.*ide"; then
  score 2 2 "IDE parity pattern present"
  D4=$((D4 + 2))
else
  score 1 2 "IDE parity pattern partial/missing"
  D4=$((D4 + 1))
fi

echo ""

# ── Dimension 5: Link Quality (5 pts) ──
echo "Dimension 5: Link Quality (5 pts)"
D5=0

# All items have source URLs (2 pts) — check main bullets and their sub-bullets
bullet_count=$( (grep -Ec '^\-\s+\*\*' "$FILE" || true) )
# Count bullets that have links either inline or in their sub-bullets (next 10 lines)
bullets_with_links=0
while IFS= read -r line_num; do
  # Check the bullet line itself and the next 10 lines for a URL
  chunk=$(sed -n "${line_num},$((line_num + 10))p" "$FILE" | head -11)
  if echo "$chunk" | grep -q 'https://'; then
    bullets_with_links=$((bullets_with_links + 1))
  fi
done < <(grep -En '^-\s+\*\*' "$FILE" | cut -d: -f1)
if [ "$bullet_count" -gt 0 ]; then
  link_ratio=$((bullets_with_links * 100 / bullet_count))
else
  link_ratio=0
fi
if [ "$link_ratio" -ge 90 ]; then
  score 2 2 "Source URLs on bullets ($bullets_with_links/$bullet_count, ${link_ratio}%)"
  D5=$((D5 + 2))
elif [ "$link_ratio" -ge 70 ]; then
  score 1 2 "Partial source URLs ($bullets_with_links/$bullet_count, ${link_ratio}%)"
  D5=$((D5 + 1))
else
  score 0 2 "Missing source URLs ($bullets_with_links/$bullet_count, ${link_ratio}%)"
fi

# No hallucinated links — check for known valid domains (2 pts)
total_links=$( (grep -Eoc '\]\(https?://' "$FILE" || true) )
valid_domains=$( (grep -Eoc '\]\(https?://(github\.blog|github\.com|docs\.github|code\.visualstudio\.com|learn\.microsoft|plugins\.jetbrains|marketplace\.eclipse|resources\.github|www\.youtube|aitour\.microsoft|github\.registration)' "$FILE" || true) )
if [ "$total_links" -gt 0 ]; then
  valid_ratio=$((valid_domains * 100 / total_links))
else
  valid_ratio=100
fi
if [ "$valid_ratio" -ge 95 ]; then
  score 2 2 "Links from known valid domains ($valid_domains/$total_links, ${valid_ratio}%)"
  D5=$((D5 + 2))
elif [ "$valid_ratio" -ge 80 ]; then
  score 1 2 "Mostly valid domains ($valid_domains/$total_links, ${valid_ratio}%)"
  D5=$((D5 + 1))
else
  score 0 2 "Too many unrecognized domains ($valid_domains/$total_links, ${valid_ratio}%)"
fi

# Link density 1.3-3.0 per bullet (1 pt)
if [ "$bullet_count" -gt 0 ]; then
  # Use bc for float division, fall back to integer
  if command -v bc > /dev/null 2>&1; then
    density=$(echo "scale=1; $total_links / $bullet_count" | bc)
  else
    density=$((total_links / bullet_count))
  fi
  density_int=$((total_links * 10 / bullet_count))  # 10x for comparison
  if [ "$density_int" -ge 13 ] && [ "$density_int" -le 30 ]; then
    score 1 1 "Link density $density per bullet (target: 1.3-3.0)"
    D5=$((D5 + 1))
  else
    score 0 1 "Link density $density per bullet (target: 1.3-3.0)"
  fi
else
  score 0 1 "No bullets to measure link density"
fi

echo ""

# ── Summary ──
echo "═══════════════════════════════════"
echo ""
echo "DIMENSION SCORES:"
echo "  D1 Theme Correctness:   $D1/10"
echo "  D2 Content Completeness: $D2/15"
echo "  D3 Structure & Format:  $D3/10"
echo "  D4 Editorial Alignment: $D4/10"
echo "  D5 Link Quality:        $D5/5"
echo ""
echo "TOTAL: $TOTAL/$MAX"
echo "THRESHOLD: >=40/$MAX (80%)"
echo ""

if [ "$TOTAL" -ge 40 ]; then
  echo "** PASS ** — V2 meets editorial quality threshold"
  echo ""
  echo "DETAILS:"
  echo "$DETAILS"
  exit 0
else
  echo "** FAIL ** — V2 below threshold, rework needed"
  echo ""
  echo "DETAILS:"
  echo "$DETAILS"
  echo ""
  echo "REWORK PRIORITIES (lowest-scoring dimensions first):"
  # Sort dimensions by score to prioritize rework
  for dim_info in "D1:$D1:10:Theme Correctness" "D2:$D2:15:Content Completeness" "D3:$D3:10:Structure Format" "D4:$D4:10:Editorial Alignment" "D5:$D5:5:Link Quality"; do
    IFS=':' read -r name pts max label <<< "$dim_info"
    pct=$((pts * 100 / max))
    if [ "$pct" -lt 80 ]; then
      echo "  FIX: $label ($pts/$max = ${pct}%)"
    fi
  done
  exit 1
fi

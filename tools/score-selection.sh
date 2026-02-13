#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Score Selection Quality: compare skill output against human benchmark
# ══════════════════════════════════════════════════════════════
# Compares a skill-generated curated output against a known-good benchmark
# to measure editorial alignment.
#
# Usage: bash tools/score-selection.sh <skill_output> <benchmark_output> [report_path]

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

SKILL_OUT="${1:-}"
BENCH_OUT="${2:-}"
REPORT="${3:-}"

if [ -z "$REPORT" ]; then
  REPORT="$(mktemp)"
fi
if [ -z "$SKILL_OUT" ] || [ -z "$BENCH_OUT" ]; then
  echo "Usage: score-selection.sh <skill_output> <benchmark_output> [report_path]"
  exit 1
fi

if [ ! -f "$SKILL_OUT" ] || [ ! -f "$BENCH_OUT" ]; then
  echo "Error: file(s) not found"
  exit 1
fi

# Extract section headers
skill_headers=$(grep -E '^#{1,3} ' "$SKILL_OUT" 2>/dev/null | sort -u || true)
bench_headers=$(grep -E '^#{1,3} ' "$BENCH_OUT" 2>/dev/null | sort -u || true)

# Count sections (avoid inflated counts when there are zero headers)
skill_section_count=$(printf '%s\n' "$skill_headers" | grep -c '^#' || true)
bench_section_count=$(printf '%s\n' "$bench_headers" | grep -c '^#' || true)

# Section overlap (count only non-empty common header lines)
common_headers=$(comm -12 <(printf '%s\n' "$skill_headers") <(printf '%s\n' "$bench_headers") | grep -c '.' || true)

# Section overlap percentage
if [ "$bench_section_count" -gt 0 ]; then
  section_overlap_pct=$((common_headers * 100 / bench_section_count))
else
  section_overlap_pct=0
fi

# Count bullets
skill_bullets=$( (grep -Ec "^-   \*\*|^- \*\*" "$SKILL_OUT" || true) )
bench_bullets=$( (grep -Ec "^-   \*\*|^- \*\*" "$BENCH_OUT" || true) )

# Volume comparison
if [ "$bench_bullets" -gt 0 ]; then
  volume_ratio=$((skill_bullets * 100 / bench_bullets))
else
  volume_ratio=0
fi

# Count links
skill_links=$( (grep -Eoc '\]\(https?://' "$SKILL_OUT" || true) )
bench_links=$( (grep -Eoc '\]\(https?://' "$BENCH_OUT" || true) )

# Key features: extract bold items as proxies for "what was selected"
skill_features=$(grep -Eo '\*\*[^*]{5,60}\*\*' "$SKILL_OUT" 2>/dev/null | sort -u)
bench_features=$(grep -Eo '\*\*[^*]{5,60}\*\*' "$BENCH_OUT" 2>/dev/null | sort -u)

skill_feature_count=$(echo "$skill_features" | grep -c '.' 2>/dev/null || echo 0)
bench_feature_count=$(echo "$bench_features" | grep -c '.' 2>/dev/null || echo 0)

# Lowercase the full skill output once for case-insensitive matching
skill_body_lc=$(tr 'A-Z' 'a-z' < "$SKILL_OUT")

feature_hits=0
while IFS= read -r feat; do
  [ -z "$feat" ] && continue
  # Strip ** markers and lowercase for comparison
  clean=$(echo "$feat" | tr -d '*')
  clean_lc=$(echo "$clean" | tr 'A-Z' 'a-z')
  if [[ "$skill_body_lc" == *"$clean_lc"* ]]; then
    feature_hits=$((feature_hits + 1))
  fi
done <<< "$bench_features"

if [ "$bench_feature_count" -gt 0 ]; then
  feature_overlap_pct=$((feature_hits * 100 / bench_feature_count))
else
  feature_overlap_pct=0
fi

# Format compliance
emdashes=$( (grep -c '—' "$SKILL_OUT" || true) )
wikilinks=$( (grep -c '\[\[' "$SKILL_OUT" || true) )
format_violations=$((emdashes + wikilinks))

# Scoring: 5 dimensions, 5 pts each = 25 max
s_structure=1; s_volume=1; s_format=1; s_fidelity=1; s_downstream=1

# Structure (section overlap)
if [ "$section_overlap_pct" -ge 80 ]; then s_structure=5
elif [ "$section_overlap_pct" -ge 60 ]; then s_structure=3
fi

# Volume (bullet count ratio)
if [ "$volume_ratio" -ge 70 ] && [ "$volume_ratio" -le 130 ]; then s_volume=5
elif [ "$volume_ratio" -ge 50 ] && [ "$volume_ratio" -le 150 ]; then s_volume=3
fi

# Format
if [ "$format_violations" -eq 0 ]; then s_format=5
elif [ "$format_violations" -le 3 ]; then s_format=3
fi

# Content fidelity (feature overlap)
if [ "$feature_overlap_pct" -ge 80 ]; then s_fidelity=5
elif [ "$feature_overlap_pct" -ge 60 ]; then s_fidelity=3
fi

# Downstream readiness (has key structural elements)
has_copilot=false; has_scale=false; has_changelogs=false
grep -qi "copilot" "$SKILL_OUT" 2>/dev/null && has_copilot=true
grep -qi "at Scale" "$SKILL_OUT" 2>/dev/null && has_scale=true
grep -qi "Changelog" "$SKILL_OUT" 2>/dev/null && has_changelogs=true
if $has_copilot && $has_scale && $has_changelogs; then s_downstream=5
elif $has_copilot && $has_scale; then s_downstream=3
fi

total=$((s_structure + s_volume + s_format + s_fidelity + s_downstream))

# Report
{
echo "# Selection Quality Score: $total/25"
echo ""
echo "## Comparison"
echo "| Metric | Skill Output | Benchmark | Ratio/Overlap |"
echo "|--------|-------------|-----------|---------------|"
echo "| Sections | $skill_section_count | $bench_section_count | ${section_overlap_pct}% overlap |"
echo "| Bullets | $skill_bullets | $bench_bullets | ${volume_ratio}% ratio |"
echo "| Links | $skill_links | $bench_links | — |"
echo "| Features (bold) | $skill_feature_count | $bench_feature_count | ${feature_overlap_pct}% overlap |"
echo "| Format violations | $format_violations | 0 | — |"
echo ""
echo "## Rubric"
echo "| Dimension | Score | Reasoning |"
echo "|-----------|-------|-----------|"
echo "| Structure | $s_structure/5 | Section overlap: ${section_overlap_pct}% |"
echo "| Volume | $s_volume/5 | Bullet ratio: ${volume_ratio}% (target: 70-130%) |"
echo "| Format | $s_format/5 | Violations: $format_violations |"
echo "| Content Fidelity | $s_fidelity/5 | Feature overlap: ${feature_overlap_pct}% |"
echo "| Downstream Ready | $s_downstream/5 | Copilot=$has_copilot Scale=$has_scale Changelogs=$has_changelogs |"
echo "| **Total** | **$total/25** | Threshold: >=18 |"
echo ""
if [ "$total" -ge 18 ]; then
  echo "**PASS** — selection quality meets threshold"
else
  echo "**FAIL** — selection quality below threshold, rework needed"
fi
} > "$REPORT"

cat "$REPORT"
[ "$total" -ge 18 ] && exit 0 || exit 1

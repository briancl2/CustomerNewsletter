#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Phase A: Structural Analysis of All Published Newsletters
# ══════════════════════════════════════════════════════════════
# Deterministic. Zero LLM cost. Produces quantified editorial patterns.
#
# Usage: bash tools/analyze-newsletters.sh [output_dir]
# Default output: runs/editorial-intelligence/phase-a/

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

OUT_DIR="${1:-runs/editorial-intelligence/phase-a}"
mkdir -p "$OUT_DIR"

NEWSLETTERS=()
for f in archive/2024/*.md archive/2025/*.md; do
  [ -f "$f" ] && NEWSLETTERS+=("$f")
done

echo "# Phase A: Structural Newsletter Analysis" > "$OUT_DIR/analysis.md"
echo "Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$OUT_DIR/analysis.md"
echo "Newsletters analyzed: ${#NEWSLETTERS[@]}" >> "$OUT_DIR/analysis.md"
echo "" >> "$OUT_DIR/analysis.md"

# ── Per-Newsletter Metrics ──
echo "## Per-Newsletter Metrics" >> "$OUT_DIR/analysis.md"
echo "" >> "$OUT_DIR/analysis.md"
echo "| Newsletter | Lines | Sections | Bullets | Links | GA Labels | PREVIEW Labels | Events Table | Lead Section | Has Intro | Has Closing |" >> "$OUT_DIR/analysis.md"
echo "|-----------|-------|----------|---------|-------|-----------|----------------|-------------|-------------|-----------|-------------|" >> "$OUT_DIR/analysis.md"

# Also build CSV for downstream analysis
echo "file,year,month,lines,sections,h1,h2,h3,bullets,links,ga_labels,preview_labels,em_dashes,wikilinks,has_events_table,has_lead_section,has_intro,has_closing,has_changelogs,has_playlists,has_ide_parity,has_copilot_scale" > "$OUT_DIR/metrics.csv"

for f in "${NEWSLETTERS[@]}"; do
  name=$(basename "$(dirname "$f")")/$(basename "$f" .md)
  year=$(basename "$(dirname "$f")")
  month=$(basename "$f" .md)

  lines=$(wc -l < "$f" | tr -d ' ')
  sections=$(grep -c "^#" "$f" 2>/dev/null || echo 0)
  h1=$(grep -c "^# " "$f" 2>/dev/null || echo 0)
  h2=$(grep -c "^## " "$f" 2>/dev/null || echo 0)
  h3=$(grep -c "^### " "$f" 2>/dev/null || echo 0)
  bullets=$( (grep -Ec "^-   \*\*|^- \*\*|^\*   \*\*|^  - \*\*|^    - \*\*" "$f" || true) )
  links=$( (grep -Eoc '\]\(https?://' "$f" || true) )
  ga_labels=$( (grep -c "(GA)" "$f" || true) )
  preview_labels=$( (grep -Ec "\(PREVIEW\)|\(\`PREVIEW\`\)" "$f" || true) )
  em_dashes=$( (grep -c '—' "$f" || true) )
  wikilinks=$( (grep -c '\[\[' "$f" || true) )

  has_events_table="N"
  grep -Eq '^\|.*Event' "$f" 2>/dev/null && has_events_table="Y"

  has_lead_section="N"
  first_h1=$(grep -m1 "^# " "$f" 2>/dev/null || echo "")
  if [ -n "$first_h1" ]; then
    if ! echo "$first_h1" | grep -Eqi "copilot|webinar|event|dylan|newsletter"; then
      has_lead_section="Y"
    fi
  fi

  has_intro="N"
  grep -qi "personally curated\|archive of past" "$f" 2>/dev/null && has_intro="Y"

  has_closing="N"
  grep -qi "reach out\|feel free\|here to help" "$f" 2>/dev/null && has_closing="Y"

  has_changelogs="N"
  changelog_count=$( (grep -c "Changelog" "$f" || true) )
  [ "$changelog_count" -ge 4 ] && has_changelogs="Y"

  has_playlists="N"
  playlist_count=$( (grep -c "youtube.com/playlist" "$f" || true) )
  [ "$playlist_count" -ge 2 ] && has_playlists="Y"

  has_ide_parity="N"
  grep -qi "IDE.*Parity\|IDE.*Feature\|parity" "$f" 2>/dev/null && has_ide_parity="Y"

  has_copilot_scale="N"
  grep -qi "Copilot at Scale\|at Scale" "$f" 2>/dev/null && has_copilot_scale="Y"

  echo "| $name | $lines | $sections | $bullets | $links | $ga_labels | $preview_labels | $has_events_table | $has_lead_section | $has_intro | $has_closing |" >> "$OUT_DIR/analysis.md"
  echo "$f,$year,$month,$lines,$sections,$h1,$h2,$h3,$bullets,$links,$ga_labels,$preview_labels,$em_dashes,$wikilinks,$has_events_table,$has_lead_section,$has_intro,$has_closing,$has_changelogs,$has_playlists,$has_ide_parity,$has_copilot_scale" >> "$OUT_DIR/metrics.csv"
done

echo "" >> "$OUT_DIR/analysis.md"

# ── Section Taxonomy Evolution ──
echo "## Section Taxonomy by Newsletter" >> "$OUT_DIR/analysis.md"
echo "" >> "$OUT_DIR/analysis.md"

for f in "${NEWSLETTERS[@]}"; do
  name=$(basename "$(dirname "$f")")/$(basename "$f" .md)
  echo "### $name" >> "$OUT_DIR/analysis.md"
  echo '```' >> "$OUT_DIR/analysis.md"
  grep "^#" "$f" >> "$OUT_DIR/analysis.md" 2>/dev/null || echo "(no headers)" >> "$OUT_DIR/analysis.md"
  echo '```' >> "$OUT_DIR/analysis.md"
  echo "" >> "$OUT_DIR/analysis.md"
done

# ── Expansion Patterns: multi-line bullets ──
echo "## Expansion Patterns (bullets with sub-bullets)" >> "$OUT_DIR/analysis.md"
echo "" >> "$OUT_DIR/analysis.md"

for f in "${NEWSLETTERS[@]}"; do
  name=$(basename "$(dirname "$f")" )/$(basename "$f" .md)
  # Count bullets that have indented sub-bullets following them
  expanded=$( (grep -Ec "^    -|^      -|^  -   " "$f" || true) )
  total_bullets=$( (grep -Ec "^-   \*\*|^- \*\*|^\*   \*\*" "$f" || true) )
  echo "- **$name**: $expanded sub-bullets under $total_bullets top-level bullets" >> "$OUT_DIR/analysis.md"
done
echo "" >> "$OUT_DIR/analysis.md"

# ── Link Density Patterns ──
echo "## Link Density" >> "$OUT_DIR/analysis.md"
echo "" >> "$OUT_DIR/analysis.md"
echo "| Newsletter | Total Links | Bullets | Links/Bullet |" >> "$OUT_DIR/analysis.md"
echo "|-----------|-------------|---------|-------------|" >> "$OUT_DIR/analysis.md"

for f in "${NEWSLETTERS[@]}"; do
  name=$(basename "$(dirname "$f")")/$(basename "$f" .md)
  links=$( (grep -Eoc '\]\(https?://' "$f" || true) )
  bullets=$( (grep -Ec "^-   \*\*|^- \*\*|^\*   \*\*" "$f" || true) )
  if [ "$bullets" -gt 0 ]; then
    # Use shell arithmetic (integer) to avoid bc dependency
    density_int=$((links * 10 / bullets))
    density_whole=$((density_int / 10))
    density_frac=$((density_int % 10))
    density="${density_whole}.${density_frac}"
  else
    density="N/A"
  fi
  echo "| $name | $links | $bullets | $density |" >> "$OUT_DIR/analysis.md"
done
echo "" >> "$OUT_DIR/analysis.md"

# ── Feature Type Signals ──
echo "## Feature Type Signals Across All Newsletters" >> "$OUT_DIR/analysis.md"
echo "" >> "$OUT_DIR/analysis.md"

total_ga=0; total_preview=0; total_security=0; total_actions=0; total_copilot=0; total_ghas=0
for f in "${NEWSLETTERS[@]}"; do
  total_ga=$((total_ga + $(grep -c "(GA)" "$f" 2>/dev/null || echo 0)))
  total_preview=$((total_preview + $(grep -Ec "\(PREVIEW\)|\(\`PREVIEW\`\)" "$f" 2>/dev/null || echo 0)))
  total_security=$((total_security + $(grep -ic "security\|secret.scan\|dependabot\|CVE" "$f" 2>/dev/null || echo 0)))
  total_actions=$((total_actions + $(grep -ic "actions\|workflow\|runner" "$f" 2>/dev/null || echo 0)))
  total_copilot=$((total_copilot + $(grep -ic "copilot" "$f" 2>/dev/null || echo 0)))
  total_ghas=$((total_ghas + $(grep -ic "advanced security\|GHAS\|code scanning" "$f" 2>/dev/null || echo 0)))
done

echo "| Signal | Total Mentions Across 14 Newsletters |" >> "$OUT_DIR/analysis.md"
echo "|--------|--------------------------------------|" >> "$OUT_DIR/analysis.md"
echo "| Copilot | $total_copilot |" >> "$OUT_DIR/analysis.md"
echo "| (GA) labels | $total_ga |" >> "$OUT_DIR/analysis.md"
echo "| (PREVIEW) labels | $total_preview |" >> "$OUT_DIR/analysis.md"
echo "| Security/scanning | $total_security |" >> "$OUT_DIR/analysis.md"
echo "| Actions/workflows | $total_actions |" >> "$OUT_DIR/analysis.md"
echo "| GHAS/code scanning | $total_ghas |" >> "$OUT_DIR/analysis.md"
echo "" >> "$OUT_DIR/analysis.md"

# ── Format Quality Signals ──
echo "## Format Quality Over Time" >> "$OUT_DIR/analysis.md"
echo "" >> "$OUT_DIR/analysis.md"
echo "| Newsletter | Em Dashes | Wikilinks | Raw URLs (est) |" >> "$OUT_DIR/analysis.md"
echo "|-----------|-----------|-----------|---------------|" >> "$OUT_DIR/analysis.md"
for f in "${NEWSLETTERS[@]}"; do
  name=$(basename "$(dirname "$f")")/$(basename "$f" .md)
  em=$( (grep -c '—' "$f" || true) )
  wl=$( (grep -c '\[\[' "$f" || true) )
  ru=$( (grep -Ec 'https?://[^ )]+' "$f" || true) )
  ml=$( (grep -Ec '\]\(https?://' "$f" || true) )
  bare=$((ru - ml))
  [ "$bare" -lt 0 ] && bare=0
  echo "| $name | $em | $wl | $bare |" >> "$OUT_DIR/analysis.md"
done

echo "" >> "$OUT_DIR/analysis.md"
echo "---" >> "$OUT_DIR/analysis.md"
echo "Phase A complete. $(wc -l < "$OUT_DIR/analysis.md" | tr -d ' ') lines of analysis." >> "$OUT_DIR/analysis.md"
echo "CSV data: $OUT_DIR/metrics.csv" >> "$OUT_DIR/analysis.md"

echo "Phase A complete:"
echo "  Analysis: $OUT_DIR/analysis.md"
echo "  CSV: $OUT_DIR/metrics.csv"
echo "  Lines: $(wc -l < "$OUT_DIR/analysis.md" | tr -d ' ')"

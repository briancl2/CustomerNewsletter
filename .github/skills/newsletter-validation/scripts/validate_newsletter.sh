#!/usr/bin/env bash
# Validates a newsletter markdown file against quality standards.
# Usage: bash validate_newsletter.sh <newsletter_file>
# Exit 0 = pass, Exit 1 = fail
#
# All patterns use grep -E (ERE) for portability across macOS/Linux.

set -euo pipefail

FILE="${1:-}"
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo "Usage: validate_newsletter.sh <newsletter_file>"
  echo "Error: File not found: $FILE"
  exit 1
fi

ERRORS=0
WARNINGS=0

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo "  WARN: $1"; WARNINGS=$((WARNINGS + 1)); }

echo "Validating: $FILE"
echo ""

# ── Required Sections ──
echo "Required Sections:"
grep -Eqi "personally curated|archive of past" "$FILE" && pass "Introduction" || fail "Introduction missing"
grep -Eqi "^#{1,3} .*[Cc]opilot" "$FILE" && pass "Copilot section" || fail "Copilot section missing"
# Copilot at Scale is now typically a links-only footer paragraph (no dedicated section heading).
grep -Eqi "Copilot at Scale|Stay current with the latest changes:|Stay up to date on the latest releases" "$FILE" && pass "Copilot at Scale (footer links)" || warn "Copilot at Scale footer not detected (ensure changelog links footer exists)"
grep -Eqi "Events|Webinars" "$FILE" && pass "Events section" || fail "Events section missing"
grep -Eqi "reach out|feel free|here to help" "$FILE" && pass "Closing" || fail "Closing missing"
echo ""

# ── Required Content Blocks ──
echo "Required Content:"

# Changelog links: match known changelog URLs rather than the word "Changelog"
changelog_urls=(
  "github.blog/changelog/label/copilot"
  "code.visualstudio.com/updates"
  "learn.microsoft.com/en-us/visualstudio/releases"
  "plugins.jetbrains.com/plugin/17718"
  "CopilotForXcode"
  "marketplace.eclipse.org/content/github-copilot"
)
changelog_total=${#changelog_urls[@]}
changelog_hits=0
for url_frag in "${changelog_urls[@]}"; do
  if grep -q "$url_frag" "$FILE" 2>/dev/null; then
    changelog_hits=$((changelog_hits + 1))
  fi
done
if [ "$changelog_hits" -ge 4 ]; then
  pass "Changelog links ($changelog_hits/$changelog_total known URLs found)"
else
  fail "Changelog links (only $changelog_hits/$changelog_total known URLs, need >=4)"
fi

# YouTube playlists: match known playlist IDs
playlist_ids=(
  "PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D"
  "PLCiDM8_DsPQ3wk4atKpN-yOW1FtyxN48W"
  "PLCiDM8_DsPQ1nWhqxi-UQF_O-gYWo5jpG"
)
playlist_total=${#playlist_ids[@]}
playlist_hits=0
for pid in "${playlist_ids[@]}"; do
  if grep -q "$pid" "$FILE" 2>/dev/null; then
    playlist_hits=$((playlist_hits + 1))
  fi
done
if [ "$playlist_hits" -ge 2 ]; then
  pass "YouTube playlists ($playlist_hits/$playlist_total found)"
else
  warn "YouTube playlists ($playlist_hits/$playlist_total found, want >=2)"
fi

grep -Eqi "CustomerNewsletter|archive.*newsletter" "$FILE" && pass "Archive link" || fail "Archive link missing"
echo ""

# ── Forbidden Patterns ──
echo "Forbidden Patterns:"

# Migration Notices should be consolidated into Enterprise & Security, not a standalone section.
# Match any heading level likely used in this repo (#, ##, ###).
migration_section=$( (grep -Ec '^#{1,3}[[:space:]]+Migration Notices[[:space:]]*$' "$FILE" || true) )
if [ "$migration_section" -eq 0 ]; then
  pass "No standalone Migration Notices section"
else
  fail "Standalone Migration Notices section found ($migration_section)"
fi

# Em dashes (Unicode U+2014)
emdash=$( (grep -c '—' "$FILE" 2>/dev/null || true) )
if [ "$emdash" -eq 0 ]; then
  pass "No em dashes"
else
  fail "Em dashes found ($emdash occurrences)"
fi

# Double-bracket wikilinks
doublebracket=$( (grep -c '\[\[' "$FILE" || true) )
if [ "$doublebracket" -eq 0 ]; then
  pass "No double-bracket links"
else
  fail "Double-bracket links found ($doublebracket)"
fi

# Consumer plan mentions: match "Copilot Free", "Copilot Individual",
# "Copilot Pro" when followed by whitespace/punctuation or end-of-line
# (to avoid "Professional"/"Profiler"), and "Copilot Pro+" explicitly.
consumer=$( (grep -Eic 'Copilot Free|Copilot Individual|Copilot Pro\+|Copilot Pro($|[[:space:][:punct:]])' "$FILE" || true) )
if [ "$consumer" -eq 0 ]; then
  pass "No consumer plan mentions"
else
  fail "Consumer plan mentions found ($consumer)"
fi

# Dylan's Corner (removed per D11)
dylan=$( (grep -ic "Dylan" "$FILE" || true) )
if [ "$dylan" -eq 0 ]; then
  pass "No Dylan references"
else
  fail "Dylan references found ($dylan)"
fi

# Placeholder text
placeholder=$( (grep -Eic 'TODO|PLACEHOLDER|\[TBD\]|\[INSERT\]' "$FILE" || true) )
if [ "$placeholder" -eq 0 ]; then
  pass "No placeholder text"
else
  warn "Placeholder text found ($placeholder)"
fi

# Deprecations should be consolidated into a single Enterprise & Security bullet.
deprecation_signals=$( (grep -Eic 'deprecat|sunset|closing down|revok|minimum version enforcement|migration notice' "$FILE" || true) )
has_bundle=$( (grep -Eic 'Deprecations and Migration Notices|Deprecation Notices' "$FILE" || true) )
if [ "$deprecation_signals" -gt 0 ] && [ "$has_bundle" -eq 0 ]; then
  warn "Deprecation/migration signals found but no consolidated 'Deprecations and Migration Notices' bullet detected"
fi

# Raw URLs outside markdown links: match http(s):// not preceded by "(" or "]("
# This catches bare URLs that aren't inside [text](url) markdown syntax.
raw_urls=$( (grep -Ec 'https?://[^ )]+' "$FILE" || true) )
md_links=$( (grep -Ec '\]\(https?://' "$FILE" || true) )
bare_url_estimate=$((raw_urls - md_links))
if [ "$bare_url_estimate" -le 0 ]; then
  pass "No raw URLs outside markdown links"
else
  warn "Possible raw URLs ($bare_url_estimate lines with URLs not in markdown links)"
fi

# Superlative platform claims
superlatives=$( (grep -Eic 'any agent|any model|any surface|every agent|every model' "$FILE" || true) )
if [ "$superlatives" -eq 0 ]; then
  pass "No superlative platform claims"
else
  warn "Superlative platform claims found ($superlatives); use 'more' or specific counts"
fi

# Link label mismatches: [Announcement] on changelog URLs
announcement_on_changelog=$( (grep -c '\[Announcement\](https://github.blog/changelog/' "$FILE" || true) )
if [ "$announcement_on_changelog" -eq 0 ]; then
  pass "No [Announcement] labels on changelog URLs"
else
  warn "Found $announcement_on_changelog [Announcement] labels on changelog URLs (should be [Changelog])"
fi

# Internal role titles in link labels
role_labels=$( (grep -Eic '\[CPO |CEO |VP ' "$FILE" || true) )
if [ "$role_labels" -eq 0 ]; then
  pass "No internal role titles in link labels"
else
  warn "Internal role titles in link labels ($role_labels); use [GitHub Blog] instead"
fi
echo ""

# ── Format Checks ──
echo "Format Checks:"
line_count=$(wc -l < "$FILE" | tr -d ' ')
if [ "$line_count" -ge 100 ]; then
  pass "File length ($line_count lines)"
else
  fail "File too short ($line_count lines, need >=100)"
fi

# GA/PREVIEW labels should appear and be uppercase (check both plain and backtick format)
ga_check=$( (grep -Ec '\(GA\)|\(`GA`\)' "$FILE" || true) )
preview_check=$( (grep -Ec '\(PREVIEW\)|\(`PREVIEW`\)' "$FILE" || true) )
if [ "$ga_check" -ge 1 ] || [ "$preview_check" -ge 1 ]; then
  pass "GA/PREVIEW labels present (GA=$ga_check, PREVIEW=$preview_check)"
else
  warn "No (GA) or (PREVIEW) labels found"
fi

# Check for lowercase variants that should be uppercase
lowercase_labels=$( (grep -Ec '\(ga\)|\(preview\)|\(Ga\)|\(Preview\)' "$FILE" || true) )
if [ "$lowercase_labels" -eq 0 ]; then
  pass "No lowercase ga/preview labels"
else
  warn "Lowercase ga/preview labels found ($lowercase_labels); should be uppercase"
fi

# Virtual events table should not contain times (date-only rule)
if grep -Eq '^\|.*Event.*Categories' "$FILE" 2>/dev/null; then
  time_in_virtual=$( (grep -E '^\|.*[0-9]{1,2}:[0-9]{2}.*\|.*\|' "$FILE" || true) | (grep -Eiv 'Time \(CT\)|keynote|session' || true) | wc -l | tr -d ' ')
  if [ "$time_in_virtual" -eq 0 ]; then
    pass "Virtual events use date-only format"
  else
    warn "Virtual events table may contain times ($time_in_virtual rows)"
  fi
fi
echo ""

# ── Summary ──
echo "========================"
if [ "$ERRORS" -eq 0 ]; then
  echo "PASSED ($WARNINGS warnings)"
  exit 0
else
  echo "FAILED: $ERRORS error(s), $WARNINGS warning(s)"
  exit 1
fi

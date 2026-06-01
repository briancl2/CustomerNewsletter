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

# Customer-facing process leakage from authenticated/internal release discovery.
app_process_leaks="$(
  python3 - "$FILE" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore")
patterns = [
    r"github/github-app",
    r"github\.com/github/github-app/releases",
    r"private tag",
    r"anonymous fetch",
    r"authenticated release",
    r"\[truncated\]",
    r"returned\s+404",
    r"HTTP\s+404",
    r"404\s+(?:for|from|on)\s+github",
]
hits = []
for pattern in patterns:
    if re.search(pattern, text, re.IGNORECASE):
        hits.append(pattern)
print("|".join(hits))
PY
)"
app_process_leaks="${app_process_leaks# }"
if [ -z "$app_process_leaks" ]; then
  pass "No Copilot App release-process leakage"
else
  fail "Copilot App release-process leakage found ($app_process_leaks)"
fi

# Legal protection content belongs in Enterprise and Security unless the issue is explicitly legal-led.
legal_venue_lines="$(
  python3 - "$FILE" <<'PY'
import re
import sys
from pathlib import Path

lines = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore").splitlines()
first_h1 = next((line for line in lines if re.match(r"^#\s+", line)), "")
legal_lead = bool(re.search(r"legal|copyright|commitment|indemnity|dpa|terms|compliance", first_h1, re.IGNORECASE))
legal_pattern = re.compile(r"\b(Customer Copyright(?: Commitment)?|CCC|Duplicate Detection|IP indemnity|indemnification)\b", re.IGNORECASE)
allowed_heading = re.compile(r"enterprise|security|governance|legal|compliance", re.IGNORECASE)
bad_lines = []
heading_stack = []
if not legal_lead:
    for idx, line in enumerate(lines):
        heading_match = re.match(r"^(#{1,6})\s+(.+?)\s*$", line)
        if heading_match:
            level = len(heading_match.group(1))
            heading_stack = heading_stack[: level - 1]
            heading_stack.append(heading_match.group(2))
        active_path = " > ".join(heading_stack)
        if legal_pattern.search(line) and not allowed_heading.search(active_path):
            bad_lines.append(str(idx + 1))
print(",".join(bad_lines))
PY
)"
legal_venue_lines="${legal_venue_lines# }"
if [ -z "$legal_venue_lines" ]; then
  pass "Legal/CCC content routed to Enterprise and Security"
else
  fail "Legal/CCC content appears before Enterprise and Security (lines $legal_venue_lines)"
fi

# VS Code version coverage must stay in URLs/scope artifacts, not customer-facing prose sequences.
vscode_version_sequences="$(
  python3 - "$FILE" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore")
text_without_urls = re.sub(r"https?://\S+", "", text)
hits = []
for line_no, line in enumerate(text_without_urls.splitlines(), 1):
  versions = re.findall(r"\b1\.\d{3}\b", line)
  if len(versions) >= 3:
    hits.append(f"line {line_no}: {', '.join(versions[:5])}")
print("|".join(hits[:5]))
PY
)"
vscode_version_sequences="${vscode_version_sequences# }"
if [ -z "$vscode_version_sequences" ]; then
  pass "No VS Code version sequences in body prose"
else
  fail "VS Code version sequence found in body prose ($vscode_version_sequences)"
fi

# Release-inventory-backed App prose must preserve inline capability links.
app_link_count="$(
  python3 - "$FILE" <<'PY'
import re
import sys
from pathlib import Path

lines = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore").splitlines()
triggered = []
current = []

GENERIC_LABELS = {
    "announcement", "article", "blog", "changelog", "docs", "documentation",
    "feature matrix", "github blog", "github previews", "preview terms",
    "preview terms changelog", "release notes", "releases", "supported models",
    "terms", "dpa", "january", "february", "march", "april", "may", "june",
    "july", "august", "september", "october", "november", "december",
}

def inline_capability_link_count(bullet):
  trailing_sources = re.search(
      r"\s+-\s+\[[^\]]+\]\([^)]+\)(?:\s*\|\s*\[[^\]]+\]\([^)]+\))*\s*$",
      bullet,
      re.DOTALL,
  )
  body = bullet[:trailing_sources.start()] if trailing_sources else bullet
  count = 0
  for label, _url in re.findall(r"\[([^\]]+)\]\(([^)]+)\)", body):
    clean = re.sub(r"[*_]", "", label.replace(chr(96), "")).strip().lower()
    clean = re.sub(r"\s+", " ", clean)
    if clean in GENERIC_LABELS:
      continue
    if re.search(r"[a-z0-9/+.-]", clean):
      count += 1
  return count

def flush():
  if not current:
    return
  bullet = "\n".join(current)
  if re.search(r"\b(?:GitHub\s+)?Copilot app\b", bullet, re.IGNORECASE) and re.search(r"\b\d+\s+releases?\b|release stream|release inventory|first accessible build|product-category launch", bullet, re.IGNORECASE):
    triggered.append(inline_capability_link_count(bullet))

for line in lines:
  if re.match(r"^-\s+\*\*", line):
    flush()
    current = [line]
    continue
  if current:
    current.append(line)
flush()

if not triggered:
  print("SKIP")
else:
  print(str(min(triggered)))
PY
)"
app_link_count="${app_link_count# }"
if [ "$app_link_count" = "SKIP" ]; then
  pass "Copilot App release-inventory link gate not triggered"
elif [ "$app_link_count" -ge 5 ] 2>/dev/null; then
  pass "Copilot App release-inventory inline capability links ($app_link_count >= 5)"
else
  fail "Copilot App release-inventory bullet under-linked ($app_link_count inline capability links < 5)"
fi

# High-volume CLI release summaries need enough representative inline links to stay inspectable.
cli_link_count="$(
  python3 - "$FILE" <<'PY'
import re
import sys
from pathlib import Path

lines = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore").splitlines()
triggered = []
current = []

GENERIC_LABELS = {
    "announcement", "article", "blog", "changelog", "docs", "documentation",
    "feature matrix", "github blog", "github previews", "preview terms",
    "preview terms changelog", "release notes", "releases", "supported models",
    "terms", "dpa", "january", "february", "march", "april", "may", "june",
    "july", "august", "september", "october", "november", "december",
}

def inline_capability_link_count(bullet):
  trailing_sources = re.search(
      r"\s+-\s+\[[^\]]+\]\([^)]+\)(?:\s*\|\s*\[[^\]]+\]\([^)]+\))*\s*$",
      bullet,
      re.DOTALL,
  )
  body = bullet[:trailing_sources.start()] if trailing_sources else bullet
  count = 0
  for label, _url in re.findall(r"\[([^\]]+)\]\(([^)]+)\)", body):
    clean = re.sub(r"[*_]", "", label.replace(chr(96), "")).strip().lower()
    clean = re.sub(r"\s+", " ", clean)
    if clean in GENERIC_LABELS:
      continue
    if re.search(r"[a-z0-9/+.-]", clean):
      count += 1
  return count

def flush():
  if not current:
    return
  bullet = "\n".join(current)
  if re.search(r"\b(?:GitHub\s+)?Copilot CLI\b", bullet, re.IGNORECASE) and re.search(r"\b\d+\s+(?:(?:GitHub\s+)?Copilot CLI\s+)?releases?\b|\b\d+\s+stable(?:\s+releases?)?\b|high-volume|release inventory|capability families", bullet, re.IGNORECASE):
    triggered.append(inline_capability_link_count(bullet))

for line in lines:
  if re.match(r"^-\s+\*\*", line):
    flush()
    current = [line]
    continue
  if current:
    current.append(line)
flush()

if not triggered:
  print("SKIP")
else:
  print(str(min(triggered)))
PY
)"
cli_link_count="${cli_link_count# }"
if [ "$cli_link_count" = "SKIP" ]; then
  pass "Copilot CLI high-volume link gate not triggered"
elif [ "$cli_link_count" -ge 6 ] 2>/dev/null; then
  pass "Copilot CLI high-volume inline capability links ($cli_link_count >= 6)"
else
  fail "Copilot CLI high-volume bullet under-linked ($cli_link_count inline capability links < 6)"
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

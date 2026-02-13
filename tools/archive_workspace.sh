#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Archive Workspace Intermediates
# ══════════════════════════════════════════════════════════════
# Moves workspace intermediate files to workspace/archived/ with cycle prefix.
#
# Usage: bash tools/archive_workspace.sh [CYCLE_PREFIX]
#   CYCLE_PREFIX: e.g., "2026-02" (auto-detected from workspace files if omitted)

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

PREFIX="${1:-}"

# Auto-detect cycle prefix from workspace files if not provided
if [ -z "$PREFIX" ]; then
  # Look for the most recent newsletter_phase* file and extract the date
  latest=$(ls -t workspace/newsletter_phase* 2>/dev/null | head -1 || true)
  if [ -n "$latest" ]; then
    # Extract YYYY-MM from filename patterns like newsletter_phase1a_..._2026-02-10.md
    PREFIX=$(echo "$latest" | grep -Eo '[0-9]{4}-[0-9]{2}' | head -1)
    # Trim to YYYY-MM
    PREFIX="${PREFIX:0:7}"
  fi
fi

if [ -z "$PREFIX" ]; then
  echo "Error: Could not detect cycle prefix. Provide one: bash tools/archive_workspace.sh 2026-02"
  exit 1
fi

ARCHIVE_DIR="workspace/archived"
mkdir -p "$ARCHIVE_DIR"

echo "Archiving workspace files for cycle: $PREFIX"
echo ""

MOVED=0
SKIPPED=0

# Archive pipeline intermediate files (newsletter_phase*)
for f in workspace/newsletter_phase*.md; do
  [ ! -f "$f" ] && continue
  base=$(basename "$f")
  dest="$ARCHIVE_DIR/${PREFIX}_${base}"
  if [ -f "$dest" ]; then
    echo "  SKIP (exists): $base -> $dest"
    SKIPPED=$((SKIPPED + 1))
  else
    mv "$f" "$dest"
    echo "  MOVED: $base -> $dest"
    MOVED=$((MOVED + 1))
  fi
done

# Archive editorial artifacts (editorial_corrections, editorial_review, v2_handoff)
for f in workspace/${PREFIX}*.md; do
  [ ! -f "$f" ] && continue
  base=$(basename "$f")
  dest="$ARCHIVE_DIR/${base}"
  if [ -f "$dest" ]; then
    echo "  SKIP (exists): $base -> $dest"
    SKIPPED=$((SKIPPED + 1))
  else
    mv "$f" "$dest"
    echo "  MOVED: $base -> $dest"
    MOVED=$((MOVED + 1))
  fi
done

echo ""
echo "Archive complete: $MOVED moved, $SKIPPED skipped"
echo "Destination: $ARCHIVE_DIR/"

# Verify
remaining=$(ls workspace/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$remaining" -eq 0 ]; then
  echo "Workspace clean: 0 .md files remaining"
else
  echo "Note: $remaining .md files still in workspace/ (may be from other cycles)"
fi

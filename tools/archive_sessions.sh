#!/usr/bin/env bash
# archive_sessions.sh — Copy VS Code + CLI session logs to runs/sessions/
# Run: make archive-sessions (or bash tools/archive_sessions.sh)
# Idempotent: skips files already archived. Safe to run repeatedly.

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

DEST="runs/sessions"
mkdir -p "$DEST"

DATE=$(date +%Y-%m-%d)
COPIED=0
SKIPPED=0

echo "Archiving session logs to $DEST/ ..."

# --- VS Code Insiders sessions ---
INSIDERS_BASE="$HOME/Library/Application Support/Code - Insiders/User/workspaceStorage"
if [ -d "$INSIDERS_BASE" ]; then
  while IFS= read -r src; do
    fname=$(basename "$src")
    dest_file="$DEST/vscode-insiders_${fname}"
    if [ ! -f "$dest_file" ]; then
      cp "$src" "$dest_file"
      COPIED=$((COPIED + 1))
    else
      SKIPPED=$((SKIPPED + 1))
    fi
  done < <(find "$INSIDERS_BASE" -path "*/chatSessions/*.jsonl" -maxdepth 4 2>/dev/null)
fi

# --- VS Code Stable sessions ---
STABLE_BASE="$HOME/Library/Application Support/Code/User/workspaceStorage"
if [ -d "$STABLE_BASE" ]; then
  while IFS= read -r src; do
    fname=$(basename "$src")
    dest_file="$DEST/vscode-stable_${fname}"
    if [ ! -f "$dest_file" ]; then
      cp "$src" "$dest_file"
      COPIED=$((COPIED + 1))
    else
      SKIPPED=$((SKIPPED + 1))
    fi
  done < <(find "$STABLE_BASE" -path "*/chatSessions/*.jsonl" -maxdepth 4 2>/dev/null)
fi

# --- Copilot CLI sessions ---
CLI_BASE="$HOME/.copilot/session-state"
if [ -d "$CLI_BASE" ]; then
  while IFS= read -r src; do
    uuid=$(basename "$(dirname "$src")")
    dest_file="$DEST/cli_${uuid}_events.jsonl"
    if [ ! -f "$dest_file" ]; then
      cp "$src" "$dest_file"
      COPIED=$((COPIED + 1))
    else
      SKIPPED=$((SKIPPED + 1))
    fi
  done < <(find "$CLI_BASE" -name "events.jsonl" -maxdepth 2 2>/dev/null)
fi

TOTAL=$((COPIED + SKIPPED))
echo "  Copied: $COPIED new sessions"
echo "  Skipped: $SKIPPED already archived"
echo "  Total on disk: $TOTAL"
echo "  Archive: $DEST/ ($(du -sh "$DEST" 2>/dev/null | cut -f1))"

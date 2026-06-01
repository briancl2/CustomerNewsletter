#!/usr/bin/env bash
# Render the exact orchestrated phase prompts without running phases or mutating workspace state.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

START="${1:-}"
END="${2:-}"
OUT_DIR="${3:-}"

if [ -z "$START" ] || [ -z "$END" ]; then
  echo "Usage: bash tools/render_orchestrated_phase_prompts.sh <START_DATE> <END_DATE> [OUTPUT_DIR]"
  exit 1
fi

if [ -z "$OUT_DIR" ]; then
  render_id="$(date -u +%Y%m%dT%H%M%SZ)"
  OUT_DIR="runs/rendered_prompts/${render_id}_${START}_to_${END}"
fi

mkdir -p "$OUT_DIR"

RENDER_ONLY=1 RUN_DIR_OVERRIDE="$OUT_DIR" bash tools/run_newsletter_orchestrated.sh "$START" "$END"

echo "Rendered prompts: $OUT_DIR/prompts"
echo "Summary: $OUT_DIR/summary.md"

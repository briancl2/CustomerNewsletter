#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

START="${1:-2026-02-14}"
END="${2:-2026-04-16}"
RENDER_ONLY="${RENDER_ONLY:-0}"
MODEL="${MODEL:-gpt-5.5}"

echo "Running April newsletter production flow"
echo "  START: $START"
echo "  END:   $END"
echo "  MODEL: $MODEL"
today_utc="$(date -u +%F)"
if [[ "$today_utc" < "$END" ]]; then
  echo "  NOTE:  today is $today_utc, so this is still a pre-close run for the $END window"
fi
if [ "$RENDER_ONLY" = "1" ]; then
  echo "  MODE:  prompt render only"
else
  echo "  MODE:  canonical prompt-rendered copilot run"
fi
echo

if [ "$RENDER_ONLY" = "1" ]; then
  bash tools/render_product_run_prompt.sh "$START" "$END" production
  exit 0
fi

MODEL="$MODEL" bash tools/run_product_newsletter.sh "$START" "$END" production

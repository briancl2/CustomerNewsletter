#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

usage() {
  cat <<'USAGE'
Usage: bash tools/run_closed_bundle_source_pruning_proof.sh <START> <END> <benchmark|production> [--run-dir DIR] [--policy PATH] [--session-log PATH] [--dry-run]

Evidence-only wrapper for Burst-27 closed-bundle source-pruning proof rows. It
fails before live spend unless the policy declares closed_bundle_required=true
and the rendered prompt binds the no-rediscovery boundary.
USAGE
}

if [ "$#" -lt 3 ]; then
  usage
  exit 1
fi

START="$1"
END="$2"
MODE="$3"
shift 3

POLICY="config/experiment_pruning_policies/burst27-closed-bundle-v1.json"
RUN_DIR=""
SESSION_LOG=""
DRY_RUN="0"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --policy)
      if [ "$#" -lt 2 ]; then
        echo "ERROR: --policy requires a path" >&2
        exit 1
      fi
      POLICY="$2"
      shift 2
      ;;
    --run-dir)
      if [ "$#" -lt 2 ]; then
        echo "ERROR: --run-dir requires a path" >&2
        exit 1
      fi
      RUN_DIR="$2"
      shift 2
      ;;
    --session-log)
      if [ "$#" -lt 2 ]; then
        echo "ERROR: --session-log requires a path" >&2
        exit 1
      fi
      SESSION_LOG="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="1"
      shift
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

policy_rel="$(python3 - "$ROOT" "$POLICY" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
path = Path(sys.argv[2]).expanduser().resolve()
if not path.exists():
    raise SystemExit(f"Closed-bundle policy not found: {path}")
try:
    rel = path.relative_to(root)
except ValueError:
    raise SystemExit(f"Closed-bundle policy must be inside repo: {path}")
payload = json.loads(path.read_text(encoding="utf-8"))
if payload.get("schema_version") != 1:
    raise SystemExit("Closed-bundle policy schema_version must be 1")
if payload.get("closed_bundle_required") is not True:
    raise SystemExit("Closed-bundle proof rows require policy closed_bundle_required=true")
if not payload.get("policy_id"):
    raise SystemExit("Closed-bundle policy must include policy_id")
print(rel)
PY
)"

prompt="$(bash tools/render_product_run_prompt.sh "$START" "$END" "$MODE" --source-pruning-policy "$policy_rel")"
python3 - "$prompt" <<'PY'
import sys

prompt = sys.argv[1]
required = [
    "Closed source bundle required: `true`",
    "After the closed bundle receipt passes, do not perform broad repo/source search expansion",
    "closed_bundle_missing_detail",
    "The run is invalid as a closed-bundle proof row if final drafting depends on broad search expansion",
    "apply_newsletter_source_pruning_policy.py",
    "newsletter_source_pruning_context_",
]
missing = [needle for needle in required if needle not in prompt]
if missing:
    raise SystemExit("Rendered closed-bundle prompt is missing required boundaries: " + ", ".join(missing))
PY

if [ "$DRY_RUN" = "1" ]; then
  echo "Closed-bundle proof wrapper admission passed for $MODE $START to $END using $policy_rel"
  exit 0
fi

args=("$START" "$END" "$MODE" --source-pruning-policy "$policy_rel")
if [ -n "$RUN_DIR" ]; then
  args+=(--run-dir "$RUN_DIR")
fi
if [ -n "$SESSION_LOG" ]; then
  args+=(--session-log "$SESSION_LOG")
fi

RUN_CLASS=source_pruning_candidate bash tools/run_product_newsletter.sh "${args[@]}"

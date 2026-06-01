#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

usage() {
  cat <<'USAGE'
Usage: bash tools/run_product_newsletter.sh <START> <END> <benchmark|production> [--run-dir DIR] [--session-log PATH] [--source-pruning-policy PATH] [--output-shape-policy PATH]

Runs the canonical single-shot product newsletter command, snapshots canonical
artifacts into a retained proof-run directory, generates the audit bundle, and
writes a per-run experiment scorecard.
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

RUN_DIR=""
SESSION_LOG=""
SOURCE_PRUNING_POLICY=""
OUTPUT_SHAPE_POLICY=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --run-dir)
      if [ "$#" -lt 2 ]; then
        echo "Error: --run-dir requires a directory"
        exit 1
      fi
      RUN_DIR="$2"
      shift 2
      ;;
    --session-log)
      if [ "$#" -lt 2 ]; then
        echo "Error: --session-log requires a path"
        exit 1
      fi
      SESSION_LOG="$2"
      shift 2
      ;;
    --source-pruning-policy)
      if [ "$#" -lt 2 ]; then
        echo "Error: --source-pruning-policy requires a path"
        exit 1
      fi
      SOURCE_PRUNING_POLICY="$2"
      shift 2
      ;;
    --output-shape-policy)
      if [ "$#" -lt 2 ]; then
        echo "Error: --output-shape-policy requires a path"
        exit 1
      fi
      OUTPUT_SHAPE_POLICY="$2"
      shift 2
      ;;
    *)
      echo "Error: unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if ! [[ "$START" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: START must be YYYY-MM-DD, got: $START"
  exit 1
fi
if ! [[ "$END" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: END must be YYYY-MM-DD, got: $END"
  exit 1
fi
case "$MODE" in
  benchmark|production) ;;
  *)
    echo "Error: MODE must be benchmark or production, got: $MODE"
    exit 1
    ;;
esac

MODEL="${MODEL:-gpt-5.5}"
COPILOT_BIN="${COPILOT_BIN:-copilot}"
EXPERIMENT_ID="${EXPERIMENT_ID:-}"
RUN_CLASS="${RUN_CLASS:-ordinary_proof}"
FIXTURE_PACK="${FIXTURE_PACK:-}"
if [ -n "$SOURCE_PRUNING_POLICY" ] && [ -n "$OUTPUT_SHAPE_POLICY" ]; then
  echo "Error: --source-pruning-policy and --output-shape-policy are mutually exclusive evidence hooks" >&2
  exit 1
fi
if [ -n "$SOURCE_PRUNING_POLICY" ] && [ "$RUN_CLASS" = "ordinary_proof" ]; then
  RUN_CLASS="source_pruning_candidate"
fi
if [ -n "$OUTPUT_SHAPE_POLICY" ] && [ "$RUN_CLASS" = "ordinary_proof" ]; then
  RUN_CLASS="output_shape_candidate"
fi
NEWSLETTER_REQUIRE_UNCACHED_CONTROL="${NEWSLETTER_REQUIRE_UNCACHED_CONTROL:-0}"

resolve_copilot_bin() {
  local candidate="${1:-copilot}"
  case "$candidate" in
    /*|*/*)
      if [ -e "$candidate" ]; then
        (cd "$(dirname "$candidate")" && printf '%s/%s\n' "$(pwd -P)" "$(basename "$candidate")")
      else
        printf '%s\n' "$candidate"
      fi
      ;;
    *)
      command -v "$candidate" || {
        if [ "$candidate" = "copilot" ] && [ -x /opt/homebrew/bin/copilot ]; then
          printf '%s\n' /opt/homebrew/bin/copilot
        else
          printf '%s\n' "$candidate"
        fi
      }
      ;;
  esac
}

COPILOT_BIN="$(resolve_copilot_bin "$COPILOT_BIN")"
export COPILOT_BIN

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
default_run_dir="runs/product_runs/${timestamp}_${MODE}_proof"
RUN_DIR="${RUN_DIR:-$default_run_dir}"
RUN_DIR="$(python3 - "$ROOT" "$RUN_DIR" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
if not run_dir.is_absolute():
    run_dir = root / run_dir
print(run_dir.resolve())
PY
)"
if [ "$NEWSLETTER_REQUIRE_UNCACHED_CONTROL" = "1" ] && [ -d "$RUN_DIR" ]; then
  if find "$RUN_DIR" -mindepth 1 -print -quit | grep -q .; then
    echo "Proof run blocked: uncached-control run dir already contains artifacts: $RUN_DIR" >&2
    exit 2
  fi
fi
mkdir -p "$RUN_DIR/audit" "$RUN_DIR/session"

uncached_copilot_args=()
if [ "$NEWSLETTER_REQUIRE_UNCACHED_CONTROL" = "1" ]; then
  no_cache_receipt="${NO_CACHE_CONTROL_RECEIPT:-$RUN_DIR/no-cache-control-receipt.json}"
  no_cache_args_file="$RUN_DIR/no-cache-control-args.txt"
  if ! python3 tools/admit_newsletter_no_cache_control.py \
    --copilot-bin "$COPILOT_BIN" \
    --model "$MODEL" \
    --output "$no_cache_receipt" \
    --args-output "$no_cache_args_file" \
    --require-admitted; then
    echo "Proof run blocked: no admitted no-cache/uncached Copilot CLI mechanism"
    exit 2
  fi
  while IFS= read -r arg; do
    if [ -n "$arg" ]; then
      uncached_copilot_args+=("$arg")
    fi
  done < "$no_cache_args_file"
fi

start_epoch="$(date +%s)"
start_epoch_precise="$(python3 -c 'import time; print(time.time())')"
started_at_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '%s\n' "$start_epoch" > "$RUN_DIR/start_epoch.txt"

source_pruning_policy_rel=""
source_pruning_policy_sha=""
output_shape_policy_rel=""
output_shape_policy_sha=""
if [ -n "$SOURCE_PRUNING_POLICY" ]; then
  source_pruning_policy_rel="$(python3 - "$ROOT" "$SOURCE_PRUNING_POLICY" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
path = Path(sys.argv[2]).expanduser().resolve()
if not path.exists():
    raise SystemExit(f"Source pruning policy not found: {path}")
try:
    print(path.relative_to(root))
except ValueError:
    raise SystemExit(f"Source pruning policy must be inside repo: {path}")
PY
)"
  source_pruning_policy_sha="$(python3 - "$source_pruning_policy_rel" <<'PY'
import hashlib
import sys
from pathlib import Path

print(hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
fi
if [ -n "$OUTPUT_SHAPE_POLICY" ]; then
  output_shape_policy_rel="$(python3 - "$ROOT" "$OUTPUT_SHAPE_POLICY" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
path = Path(sys.argv[2]).expanduser().resolve()
if not path.exists():
    raise SystemExit(f"Output shape policy not found: {path}")
try:
    print(path.relative_to(root))
except ValueError:
    raise SystemExit(f"Output shape policy must be inside repo: {path}")
PY
)"
  output_shape_policy_sha="$(python3 - "$output_shape_policy_rel" <<'PY'
import hashlib
import sys
from pathlib import Path

print(hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
fi

prompt_cmd="bash tools/render_product_run_prompt.sh $START $END $MODE"
if [ -n "$source_pruning_policy_rel" ]; then
  prompt_cmd="$prompt_cmd --source-pruning-policy $source_pruning_policy_rel"
fi
if [ -n "$output_shape_policy_rel" ]; then
  prompt_cmd="$prompt_cmd --output-shape-policy $output_shape_policy_rel"
fi
prompt_path="$RUN_DIR/prompt.txt"
render_args=("$START" "$END" "$MODE")
if [ -n "$source_pruning_policy_rel" ]; then
  render_args+=(--source-pruning-policy "$source_pruning_policy_rel")
fi
if [ -n "$output_shape_policy_rel" ]; then
  render_args+=(--output-shape-policy "$output_shape_policy_rel")
fi
bash tools/render_product_run_prompt.sh "${render_args[@]}" > "$prompt_path"
prompt_sha256="$(python3 - "$prompt_path" <<'PY'
import hashlib
import sys
from pathlib import Path

path = Path(sys.argv[1])
print(hashlib.sha256(path.read_bytes()).hexdigest())
PY
)"
uncached_display=""
if [ "${#uncached_copilot_args[@]}" -gt 0 ]; then
  for arg in "${uncached_copilot_args[@]}"; do
    uncached_display="$uncached_display $arg"
  done
fi
command_string="$COPILOT_BIN --model $MODEL$uncached_display --allow-all --deny-tool agent --no-ask-user --stream off -p @${prompt_path##$ROOT/}"

python3 - "$ROOT" "$RUN_DIR/run-metadata.json" "$START" "$END" "$MODE" "$start_epoch" "$started_at_utc" "$command_string" "$MODEL" "$EXPERIMENT_ID" "$RUN_CLASS" "$FIXTURE_PACK" "$prompt_sha256" "$prompt_path" "$prompt_cmd" "$source_pruning_policy_rel" "$source_pruning_policy_sha" "$output_shape_policy_rel" "$output_shape_policy_sha" "$COPILOT_BIN" <<'PY'
import json
import shutil
import subprocess
import sys
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
path = Path(sys.argv[2])
start, end, mode = sys.argv[3], sys.argv[4], sys.argv[5]
start_epoch, started_at_utc, command = int(sys.argv[6]), sys.argv[7], sys.argv[8]
model, experiment_id, run_class, fixture_pack = sys.argv[9], sys.argv[10] or None, sys.argv[11], sys.argv[12] or None
prompt_sha256, prompt_path, prompt_cmd = sys.argv[13], sys.argv[14], sys.argv[15]
source_pruning_policy_path = sys.argv[16] or None
source_pruning_policy_sha256 = sys.argv[17] or None
output_shape_policy_path = sys.argv[18] or None
output_shape_policy_sha256 = sys.argv[19] or None
copilot_bin = sys.argv[20]

def run_text(cmd):
    completed = subprocess.run(cmd, cwd=repo_root, text=True, capture_output=True, check=False)
    return completed.stdout.strip() or completed.stderr.strip() or None

def version(binary):
    resolved = shutil.which(binary)
    if not resolved:
        return {"path": None, "version": None}
    output = run_text([resolved, "--version"])
    version_line = output.splitlines()[0] if output else None
    return {"path": resolved, "version": version_line}

git_status = run_text(["git", "status", "--short"]) or ""
payload = {
    "schema_version": 1,
    "start": start,
    "end": end,
    "mode": mode,
    "model": model,
    "start_epoch": start_epoch,
    "started_at_utc": started_at_utc,
    "command": command,
    "command_surface": "copilot_cli_single_shot",
    "experiment_id": experiment_id,
    "run_class": run_class,
    "fixture_pack": fixture_pack,
    "prompt_sha256": prompt_sha256,
    "prompt_source": "prompt_snapshot",
    "prompt_path": str(Path(prompt_path).resolve()),
    "prompt_renderer_command": prompt_cmd,
    "source_pruning_policy_path": source_pruning_policy_path,
    "source_pruning_policy_sha256": source_pruning_policy_sha256,
    "output_shape_policy_path": output_shape_policy_path,
    "output_shape_policy_sha256": output_shape_policy_sha256,
    "artifact_root": str((path.parent / "artifacts").resolve()),
    "git_sha": run_text(["git", "rev-parse", "HEAD"]),
    "git_branch": run_text(["git", "rev-parse", "--abbrev-ref", "HEAD"]),
    "git_dirty": bool(git_status.strip()),
    "dirty_files": [line for line in git_status.splitlines() if line.strip()],
    "copilot": version(copilot_bin),
    "timeout": version("timeout") if shutil.which("timeout") else version("gtimeout"),
    "python": sys.version.split()[0],
}
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

echo "Preparing proof run in $RUN_DIR"
bash tools/prepare_newsletter_cycle.sh "$START" "$END" --no-reuse
rm -f \
  "workspace/newsletter_source_pruning_context_${END}.md" \
  "workspace/newsletter_source_pruning_receipt_${END}.json" \
  "workspace/newsletter_output_shape_context_${END}.md" \
  "workspace/newsletter_output_shape_receipt_${END}.json"

copilot_log="$RUN_DIR/copilot.log"
set +e
if [ "${#uncached_copilot_args[@]}" -gt 0 ]; then
  copilot_args=("$COPILOT_BIN" --model "$MODEL" "${uncached_copilot_args[@]}" --allow-all --deny-tool agent --no-ask-user --stream off)
else
  copilot_args=("$COPILOT_BIN" --model "$MODEL" --allow-all --deny-tool agent --no-ask-user --stream off)
fi
"${copilot_args[@]}" \
  -p "$(cat "$prompt_path")" \
  >"$copilot_log" 2>&1
copilot_rc=$?
set -e
end_epoch_precise="$(python3 -c 'import time; print(time.time())')"
printf '%s\n' "$copilot_rc" > "$RUN_DIR/copilot_exit_code.txt"

detect_session_log() {
  python3 - "$1" "$2" <<'PY'
import sys
from pathlib import Path

start_epoch = float(sys.argv[1])
end_epoch = float(sys.argv[2])
base = Path.home() / ".copilot" / "session-state"
candidates = []
for path in base.glob("*/events.jsonl"):
    try:
        stat = path.stat()
    except FileNotFoundError:
        continue
    if stat.st_mtime > start_epoch and stat.st_mtime <= end_epoch + 5:
        candidates.append((stat.st_mtime, str(path.resolve())))

if not candidates:
    raise SystemExit(1)

candidates.sort()
print(candidates[-1][1])
PY
}

resolved_session_log=""
if [ -n "$SESSION_LOG" ] && [ -f "$SESSION_LOG" ]; then
  resolved_session_log="$(python3 - "$SESSION_LOG" <<'PY'
import sys
from pathlib import Path
print(Path(sys.argv[1]).resolve())
PY
)"
else
  if detected="$(detect_session_log "$start_epoch_precise" "$end_epoch_precise" 2>/dev/null)"; then
    resolved_session_log="$detected"
  fi
fi

if [ -n "$resolved_session_log" ]; then
  printf '%s\n' "$resolved_session_log" > "$RUN_DIR/session_log_path.txt"
  cp "$resolved_session_log" "$RUN_DIR/session/events.jsonl"
fi

rm -f \
  "$RUN_DIR/artifacts/workspace/newsletter_source_pruning_context_${END}.md" \
  "$RUN_DIR/artifacts/workspace/newsletter_source_pruning_receipt_${END}.json" \
  "$RUN_DIR/artifacts/workspace/newsletter_output_shape_context_${END}.md" \
  "$RUN_DIR/artifacts/workspace/newsletter_output_shape_receipt_${END}.json"

python3 tools/snapshot_product_run_artifacts.py \
  "$START" \
  "$END" \
  --dest-root "$RUN_DIR/artifacts"

audit_cmd=(
  python3
  tools/collect_product_run_audit.py
  "$START"
  "$END"
  --mode
  "$MODE"
  --run-dir
  "$RUN_DIR/audit"
  --require-fresh
)
if [ -n "$resolved_session_log" ]; then
  audit_cmd+=(--session-log "$RUN_DIR/session/events.jsonl")
fi

set +e
"${audit_cmd[@]}"
audit_rc=$?
set -e

ended_at_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
python3 - "$RUN_DIR/run-result.json" "$copilot_rc" "$audit_rc" "$ended_at_utc" "$resolved_session_log" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = {
    "copilot_exit_code": int(sys.argv[2]),
    "audit_exit_code": int(sys.argv[3]),
    "ended_at_utc": sys.argv[4],
    "session_log_path": sys.argv[5] or None,
}
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

python3 tools/build_run_experiment_scorecard.py \
  --run-dir "$RUN_DIR" \
  >/dev/null

if [ "$copilot_rc" -ne 0 ]; then
  echo "Proof run failed: copilot exited with $copilot_rc"
  exit "$copilot_rc"
fi
if [ "$audit_rc" -ne 0 ]; then
  echo "Proof run failed: audit exited with $audit_rc"
  exit "$audit_rc"
fi

echo "Proof run complete: $RUN_DIR"

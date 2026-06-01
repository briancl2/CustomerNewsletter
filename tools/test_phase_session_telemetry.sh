#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

require_tracked_path() {
  local path="$1"
  if ! git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
    echo "missing tracked retained-run fixture: $path" >&2
    exit 1
  fi
}

run_src="runs/product_runs/20260430T165856Z_production_proof"
require_tracked_path "$run_src/run-metadata.json"
require_tracked_path "$run_src/run-scorecard.json"
require_tracked_path "$run_src/session/events.jsonl"
run_dir="$tmpdir/20260430T165856Z_production_proof"
cp -R "$run_src" "$run_dir"
prompt_path="$run_dir/prompt.txt"
bash tools/render_product_run_prompt.sh 2026-02-14 2026-04-16 production > "$prompt_path"
python3 - "$run_dir/run-metadata.json" "$prompt_path" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

metadata_path = Path(sys.argv[1])
prompt_path = Path(sys.argv[2]).resolve()
payload = json.loads(metadata_path.read_text(encoding="utf-8"))
payload["prompt_sha256"] = hashlib.sha256(prompt_path.read_bytes()).hexdigest()
payload["prompt_path"] = str(prompt_path)
payload["prompt_renderer_command"] = (
    "bash tools/render_product_run_prompt.sh 2026-02-14 2026-04-16 production"
)
metadata_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

python3 tools/build_run_experiment_scorecard.py \
  --run-dir "$run_dir" \
  --output "$run_dir/run-scorecard.json" >/dev/null

python3 - "$run_dir/session/phase-session-metrics.jsonl" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
path.parent.mkdir(parents=True, exist_ok=True)
phases = [
    "phase0_scope_contract",
    "phase1a_manifest",
    "phase1b_xcode",
    "phase1c_discoveries",
    "phase2_events",
    "phase3_curated",
    "phase4_editorial_review",
]
rows = []
for index, phase_id in enumerate(phases, start=1):
    rows.append({
        "schema_version": 1,
        "phase_id": phase_id,
        "exit_code": 0,
        "session_log_path": f"/tmp/{phase_id}.events.jsonl",
        "session_log_sha256": f"{index:064x}"[-64:],
        "token_usage": {
            "source": "session.shutdown.modelMetrics",
            "primary_model": "gpt-5.5",
            "request_count": 1,
            "input_tokens": 1000 * index,
            "output_tokens": 100 * index,
            "cache_read_tokens": 500 * index,
            "cache_write_tokens": 0,
            "reasoning_tokens": 10 * index,
            "direct_provider_token_fields_present": [
                "inputTokens",
                "outputTokens",
                "cacheReadTokens",
                "cacheWriteTokens",
                "reasoningTokens",
            ],
            "missing_direct_provider_token_fields": [],
            "model_breakdown": {
                "gpt-5.5": {
                    "model": "gpt-5.5",
                    "request_count": 1,
                    "input_tokens": 1000 * index,
                    "output_tokens": 100 * index,
                    "cache_read_tokens": 500 * index,
                    "cache_write_tokens": 0,
                    "reasoning_tokens": 10 * index,
                    "direct_provider_token_fields_present": [
                        "inputTokens",
                        "outputTokens",
                        "cacheReadTokens",
                        "cacheWriteTokens",
                        "reasoningTokens",
                    ],
                    "missing_direct_provider_token_fields": [],
                }
            },
        },
    })
path.write_text("\n".join(json.dumps(row, sort_keys=True) for row in rows) + "\n", encoding="utf-8")
PY

python3 tools/build_phase_token_telemetry_receipt.py \
  --run-dir "$run_dir" \
  --phase-session-metrics "$run_dir/session/phase-session-metrics.jsonl" \
  --output "$tmpdir/phase-token-qualified.json" >/dev/null

python3 - "$tmpdir/phase-token-qualified.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["runs"][0]["direct_phase_token_telemetry_available"] is not True:
    raise SystemExit("expected per-phase metrics to qualify direct phase telemetry")
if payload["runs"][0]["phase_token_delta_method"] != "direct_provider_per_phase_session_shutdown":
    raise SystemExit("expected per-phase session shutdown delta method")
if not payload["runs"][0]["phase_transition_token_deltas"]:
    raise SystemExit("expected retained phase transition deltas")
PY

python3 - "$run_dir/session/phase-session-metrics.jsonl" "$tmpdir/retry-metrics.jsonl" <<'PY'
import json
import sys
from pathlib import Path

rows = [json.loads(raw) for raw in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines() if raw.strip()]
retry = dict(rows[2])
retry["exit_code"] = 1
retry["ended_at_utc"] = "2026-05-04T00:00:00Z"
retry["token_usage"] = dict(retry["token_usage"])
retry["token_usage"]["input_tokens"] = 1
rows.insert(2, retry)
Path(sys.argv[2]).write_text("\n".join(json.dumps(row, sort_keys=True) for row in rows) + "\n", encoding="utf-8")
PY

python3 tools/build_phase_token_telemetry_receipt.py \
  --run-dir "$run_dir" \
  --phase-session-metrics "$tmpdir/retry-metrics.jsonl" \
  --output "$tmpdir/phase-token-retry-qualified.json" >/dev/null

python3 - "$tmpdir/phase-token-retry-qualified.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
run = payload["runs"][0]
if run["direct_phase_token_telemetry_available"] is not True:
    raise SystemExit("expected final successful retry rows to qualify")
for delta in run["phase_transition_token_deltas"]:
    if delta["from_phase_id"] == delta["to_phase_id"]:
        raise SystemExit("retry rows must not create same-phase synthetic transitions")
if not any(row.get("superseded_metric_row_count") for row in run["phase_boundary_snapshot_coverage"]):
    raise SystemExit("expected retry coverage to record superseded metric rows")
PY

python3 - "$run_dir/session/phase-session-metrics.jsonl" "$tmpdir/missing-fields-metrics.jsonl" <<'PY'
import json
import sys
from pathlib import Path

rows = []
for raw in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    row = json.loads(raw)
    usage = row["token_usage"]
    usage["direct_provider_token_fields_present"] = ["inputTokens", "outputTokens"]
    usage["missing_direct_provider_token_fields"] = [
        "cacheReadTokens",
        "cacheWriteTokens",
        "reasoningTokens",
    ]
    for payload in usage["model_breakdown"].values():
        payload["direct_provider_token_fields_present"] = ["inputTokens", "outputTokens"]
        payload["missing_direct_provider_token_fields"] = [
            "cacheReadTokens",
            "cacheWriteTokens",
            "reasoningTokens",
        ]
    rows.append(row)
Path(sys.argv[2]).write_text("\n".join(json.dumps(row, sort_keys=True) for row in rows) + "\n", encoding="utf-8")
PY

python3 tools/build_phase_token_telemetry_receipt.py \
  --run-dir "$run_dir" \
  --phase-session-metrics "$tmpdir/missing-fields-metrics.jsonl" \
  --output "$tmpdir/phase-token-missing-fields.json" >/dev/null

python3 - "$tmpdir/phase-token-missing-fields.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
run = payload["runs"][0]
if run["direct_phase_token_telemetry_available"] is not False:
    raise SystemExit("expected missing direct fields to fail phase telemetry qualification")
if payload["receipt_result"] != "fail_closed_no_phase_boundary_provider_snapshots":
    raise SystemExit("expected fail-closed receipt result for incomplete direct fields")
PY

failed_src="runs/product_runs/20260501T024928Z_benchmark_proof"
passing_src="runs/product_runs/20260430T115004Z_production_proof"
require_tracked_path "$failed_src/run-metadata.json"
require_tracked_path "$failed_src/run-scorecard.json"
require_tracked_path "$failed_src/session/events.jsonl"
require_tracked_path "$passing_src/run-metadata.json"
require_tracked_path "$passing_src/run-scorecard.json"
require_tracked_path "$passing_src/session/events.jsonl"
failed_dir="$tmpdir/20260501T024928Z_benchmark_proof"
passing_dir="$tmpdir/20260430T115004Z_production_proof"
cp -R "$failed_src" "$failed_dir"
cp -R "$passing_src" "$passing_dir"

python3 tools/build_run_experiment_scorecard.py \
  --run-dir "$failed_dir" \
  --output "$failed_dir/run-scorecard.json" >/dev/null
python3 tools/build_run_experiment_scorecard.py \
  --run-dir "$passing_dir" \
  --output "$passing_dir/run-scorecard.json" >/dev/null

python3 - "$failed_dir" "$failed_dir/session/phase-session-metrics.jsonl" <<'PY'
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
output = Path(sys.argv[2])
receipts = json.loads(next((run_dir / "artifacts" / "workspace").glob("newsletter_phase_receipts_*.json")).read_text(encoding="utf-8"))["receipts"]
rows = []
for index, receipt in enumerate(receipts, start=1):
    phase_id = receipt["phase_id"]
    rows.append({
        "schema_version": 1,
        "phase_id": phase_id,
        "exit_code": 0,
        "session_log_path": str(output.parent / f"{phase_id}.events.jsonl"),
        "session_log_sha256": f"{index:064x}"[-64:],
        "token_usage": {
            "source": "session.shutdown.modelMetrics",
            "primary_model": "gpt-5.5",
            "request_count": 1,
            "input_tokens": 1000 * index,
            "output_tokens": 100 * index,
            "cache_read_tokens": 500 * index,
            "cache_write_tokens": 0,
            "reasoning_tokens": 10 * index,
            "direct_provider_token_fields_present": [
                "inputTokens",
                "outputTokens",
                "cacheReadTokens",
                "cacheWriteTokens",
                "reasoningTokens",
            ],
            "missing_direct_provider_token_fields": [],
            "model_breakdown": {
                "gpt-5.5": {
                    "model": "gpt-5.5",
                    "request_count": 1,
                    "input_tokens": 1000 * index,
                    "output_tokens": 100 * index,
                    "cache_read_tokens": 500 * index,
                    "cache_write_tokens": 0,
                    "reasoning_tokens": 10 * index,
                    "direct_provider_token_fields_present": [
                        "inputTokens",
                        "outputTokens",
                        "cacheReadTokens",
                        "cacheWriteTokens",
                        "reasoningTokens",
                    ],
                    "missing_direct_provider_token_fields": [],
                }
            },
        },
    })
output.write_text("\n".join(json.dumps(row, sort_keys=True) for row in rows) + "\n", encoding="utf-8")
PY

python3 tools/build_phase_token_telemetry_receipt.py \
  --run-dir "$failed_dir" \
  --phase-session-metrics "$failed_dir/session/phase-session-metrics.jsonl" \
  --output "$tmpdir/failed-phase-token-qualified.json" >/dev/null

python3 - "$failed_dir/session/phase-session-metrics.jsonl" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(path.read_text(encoding="utf-8").replace('"input_tokens": 2000', '"input_tokens": 2001', 1), encoding="utf-8")
PY

if python3 tools/prove_newsletter_stop_gates.py \
  --failed-run "$failed_dir" \
  --passing-run "$passing_dir" \
  --failed-scorecard "$failed_dir/run-scorecard.json" \
  --passing-scorecard "$passing_dir/run-scorecard.json" \
  --phase-token-telemetry "$tmpdir/failed-phase-token-qualified.json" \
  --output "$tmpdir/tampered-stop-gate.json" >/dev/null 2>&1; then
  echo "expected tampered phase metrics to fail stop-gate binding" >&2
  exit 1
fi

fake_bin="$tmpdir/fake-bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/copilot" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

mode="${FAKE_COPILOT_SESSION_MODE:-single}"
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
prompt=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -p)
      prompt="${2:-}"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
write_events() {
  local dir="$1"
  local prompt_payload="${2:-$prompt}"
  mkdir -p "$HOME/.copilot/session-state/$dir"
  PROMPT_PAYLOAD="$prompt_payload" SESSION_TIMESTAMP="$timestamp" python3 - "$HOME/.copilot/session-state/$dir/events.jsonl" <<'PY'
import json
import os
import sys
from pathlib import Path

path = Path(sys.argv[1])
timestamp = os.environ["SESSION_TIMESTAMP"]
prompt = os.environ.get("PROMPT_PAYLOAD", "")
rows = [
    {
        "timestamp": timestamp,
        "type": "session.start",
        "data": {
            "selectedModel": "gpt-5.5",
            "context": {"cwd": os.getcwd(), "gitRoot": os.getcwd()},
        },
    },
    {"timestamp": timestamp, "type": "subagent.selected", "data": {"agentName": "customer_newsletter"}},
    {"timestamp": timestamp, "type": "user.message", "data": {"content": prompt}},
    {
        "timestamp": timestamp,
        "type": "session.shutdown",
        "data": {
            "currentModel": "gpt-5.5",
            "totalPremiumRequests": 1,
            "totalApiDurationMs": 1,
            "modelMetrics": {
                "gpt-5.5": {
                    "requests": {"count": 1},
                    "usage": {
                        "inputTokens": 10,
                        "outputTokens": 2,
                        "cacheReadTokens": 3,
                        "cacheWriteTokens": 0,
                        "reasoningTokens": 1,
                    },
                }
            },
        },
    },
]
path.write_text("\n".join(json.dumps(row, sort_keys=True) for row in rows) + "\n", encoding="utf-8")
PY
}

case "$mode" in
  single)
    write_events "single"
    ;;
  ambiguous)
    write_events "first"
    write_events "second"
    ;;
  unrelated)
    write_events "unrelated" "unrelated prompt without invocation marker"
    ;;
  none)
    ;;
esac
echo "fake copilot completed"
EOF
chmod +x "$fake_bin/copilot"

prompt_file="$tmpdir/prompt.md"
printf 'test prompt\n' > "$prompt_file"

HOME="$tmpdir/home-single" PATH="$fake_bin:$PATH" python3 tools/run_copilot_phase.py \
  --agent customer_newsletter \
  --model gpt-5.5 \
  --prompt-file "$prompt_file" \
  --log "$tmpdir/single.log" \
  --timeout 30 \
  --cwd "$(pwd)" \
  --phase-id phase0_scope_contract \
  --session-out "$tmpdir/single.events.jsonl" \
  --metrics-out "$tmpdir/single.metrics.jsonl" \
  --require-session-log >/dev/null

python3 - "$tmpdir/single.events.jsonl" "$tmpdir/single.metrics.jsonl" <<'PY'
import json
import sys
from pathlib import Path

if not Path(sys.argv[1]).exists():
    raise SystemExit("expected copied single session log")
rows = [json.loads(raw) for raw in Path(sys.argv[2]).read_text(encoding="utf-8").splitlines() if raw.strip()]
if len(rows) != 1:
    raise SystemExit("expected one metrics row for single session")
row = rows[0]
if row["exit_code"] != 0:
    raise SystemExit("expected single-session phase to pass")
if row["session_log_detection"]["status"] != "bound_candidate":
    raise SystemExit("expected bound candidate detection status")
if row["session_log_detection"]["bound_candidate_count"] != 1:
    raise SystemExit("expected one bound candidate")
if row["token_usage"]["missing_direct_provider_token_fields"]:
    raise SystemExit("expected complete direct token fields")
if row["prompt_path"] == row["original_prompt_path"]:
    raise SystemExit("session-bound prompt path must point at the exact augmented prompt snapshot")
prompt_text = Path(row["prompt_path"]).read_text(encoding="utf-8")
if "newsletter_phase_invocation_id:" not in prompt_text:
    raise SystemExit("effective prompt snapshot must retain the invocation marker sent to Copilot")
if row["prompt_sha256"] == row["original_prompt_sha256"]:
    raise SystemExit("augmented prompt hash must differ from original prompt hash")
PY

set +e
HOME="$tmpdir/home-ambiguous" PATH="$fake_bin:$PATH" FAKE_COPILOT_SESSION_MODE=ambiguous \
  python3 tools/run_copilot_phase.py \
    --agent customer_newsletter \
    --model gpt-5.5 \
    --prompt-file "$prompt_file" \
    --log "$tmpdir/ambiguous.log" \
    --timeout 30 \
    --cwd "$(pwd)" \
    --phase-id phase0_scope_contract \
    --session-out "$tmpdir/ambiguous.events.jsonl" \
    --metrics-out "$tmpdir/ambiguous.metrics.jsonl" \
    --require-session-log >/dev/null
ambiguous_rc=$?
set -e
if [ "$ambiguous_rc" -eq 0 ]; then
  echo "expected ambiguous session attribution to fail closed" >&2
  exit 1
fi

python3 - "$tmpdir/ambiguous.events.jsonl" "$tmpdir/ambiguous.metrics.jsonl" <<'PY'
import json
import sys
from pathlib import Path

if Path(sys.argv[1]).exists():
    raise SystemExit("ambiguous session attribution must not copy one candidate")
rows = [json.loads(raw) for raw in Path(sys.argv[2]).read_text(encoding="utf-8").splitlines() if raw.strip()]
if len(rows) != 1:
    raise SystemExit("expected one metrics row for ambiguous session")
row = rows[0]
if row["exit_code"] != 2:
    raise SystemExit(f"expected fail-closed exit code 2, got {row['exit_code']}")
if row["session_log_detection"]["status"] != "ambiguous_bound_candidates":
    raise SystemExit("expected ambiguous bound candidate detection status")
if row["session_log_path"] is not None:
    raise SystemExit("expected no selected session log path")
PY

set +e
HOME="$tmpdir/home-unrelated" PATH="$fake_bin:$PATH" FAKE_COPILOT_SESSION_MODE=unrelated \
  python3 tools/run_copilot_phase.py \
    --agent customer_newsletter \
    --model gpt-5.5 \
    --prompt-file "$prompt_file" \
    --log "$tmpdir/unrelated.log" \
    --timeout 30 \
    --cwd "$(pwd)" \
    --phase-id phase0_scope_contract \
    --session-out "$tmpdir/unrelated.events.jsonl" \
    --metrics-out "$tmpdir/unrelated.metrics.jsonl" \
    --require-session-log >/dev/null
unrelated_rc=$?
set -e
if [ "$unrelated_rc" -eq 0 ]; then
  echo "expected unbound single-candidate attribution to fail closed" >&2
  exit 1
fi

python3 - "$tmpdir/unrelated.events.jsonl" "$tmpdir/unrelated.metrics.jsonl" <<'PY'
import json
import sys
from pathlib import Path

if Path(sys.argv[1]).exists():
    raise SystemExit("unbound session attribution must not copy one candidate")
rows = [json.loads(raw) for raw in Path(sys.argv[2]).read_text(encoding="utf-8").splitlines() if raw.strip()]
if len(rows) != 1:
    raise SystemExit("expected one metrics row for unbound session")
row = rows[0]
if row["exit_code"] != 2:
    raise SystemExit(f"expected fail-closed exit code 2, got {row['exit_code']}")
if row["session_log_detection"]["status"] != "binding_failed":
    raise SystemExit("expected binding_failed detection status")
if row["session_log_detection"]["bound_candidate_count"] != 0:
    raise SystemExit("expected zero bound candidates")
PY

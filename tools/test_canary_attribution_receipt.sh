#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

make_row() {
  local path="$1"
  local phase="$2"
  local input="$3"
  local output="$4"
  local reasoning="$5"
  local cache="$6"
  local requests="$7"
  local tools="$8"
  mkdir -p "$(dirname "$path")"
  python3 - "$path" "$phase" "$input" "$output" "$reasoning" "$cache" "$requests" "$tools" <<'PY'
import json
import sys

path, phase, input_tokens, output_tokens, reasoning_tokens, cache_read, requests, tools = sys.argv[1:]
row = {
    "phase_id": phase,
    "model": "gpt-5.5",
    "input_tokens": int(input_tokens),
    "output_tokens": int(output_tokens),
    "reasoning_tokens": int(reasoning_tokens),
    "cache_read_tokens": int(cache_read),
    "cache_write_tokens": 0,
    "request_count": int(requests),
    "tool_calls": int(tools),
    "duration_seconds": 1.0,
    "direct_token_missing_fields": [],
    "session_status": "bound_candidate",
}
with open(path, "a") as handle:
    handle.write(json.dumps(row) + "\n")
PY
}

mkdir -p "$TMPDIR/control/orchestrated/session" "$TMPDIR/optin/orchestrated/session" "$TMPDIR/canary/orchestrated/session"
CONTROL="$TMPDIR/control/orchestrated/session/phase-session-metrics.jsonl"
OPTIN="$TMPDIR/optin/orchestrated/session/phase-session-metrics.jsonl"
CANARY="$TMPDIR/canary/orchestrated/session/phase-session-metrics.jsonl"
make_row "$CONTROL" phase1b_xcode 100 10 1 10 1 0
make_row "$CONTROL" phase3_curated 100 10 1 10 1 0
make_row "$OPTIN" phase1b_xcode 80 10 1 10 1 0
make_row "$OPTIN" phase3_stdout_no_tools_artifact_reuse 20 5 0 0 1 0
make_row "$CANARY" phase1b_xcode 300 10 1 50 1 0
make_row "$CANARY" phase3_stdout_no_tools_artifact_reuse 20 5 0 0 1 0

printf '{"qualified": true}\n' > "$TMPDIR/control-receipt.json"
printf '{"verdict": "rolled_back"}\n' > "$TMPDIR/canary-receipt.json"
printf '{"verdict": "rollback_pass"}\n' > "$TMPDIR/rollback-receipt.json"

python3 "$ROOT/tools/build_canary_attribution_receipt.py" \
  --control-run-dir "$TMPDIR/control" \
  --opt-in-run-dir "$TMPDIR/optin" \
  --canary-run-dir "$TMPDIR/canary" \
  --control-receipt "$TMPDIR/control-receipt.json" \
  --canary-receipt "$TMPDIR/canary-receipt.json" \
  --rollback-receipt "$TMPDIR/rollback-receipt.json" \
  --output "$TMPDIR/receipt.json"

python3 - "$TMPDIR/receipt.json" <<'PY'
import json
import sys

receipt = json.load(open(sys.argv[1]))
assert receipt["verdict"] == "attribution_pass_named_source", receipt
assert receipt["cause_classification"] == "pre_phase_context_or_source_delta", receipt
assert receipt["stdout_no_tools_default_disposition"] == "opt_in_only", receipt
assert receipt["comparisons"]["canary_minus_retained_control"]["largest_positive_phase_delta"]["phase_id"] == "phase1b_xcode"
PY

python3 - "$CANARY" <<'PY'
import json
import sys

path = sys.argv[1]
rows = [json.loads(line) for line in open(path)]
rows[0]["input_tokens"] = None
rows[0]["direct_token_missing_fields"] = ["input_tokens"]
open(path, "w").write("\n".join(json.dumps(row) for row in rows) + "\n")
PY

if python3 "$ROOT/tools/build_canary_attribution_receipt.py" \
  --control-run-dir "$TMPDIR/control" \
  --opt-in-run-dir "$TMPDIR/optin" \
  --canary-run-dir "$TMPDIR/canary" \
  --control-receipt "$TMPDIR/control-receipt.json" \
  --canary-receipt "$TMPDIR/canary-receipt.json" \
  --rollback-receipt "$TMPDIR/rollback-receipt.json" \
  --output "$TMPDIR/receipt-negative.json"; then
  echo "expected missing direct fields to fail" >&2
  exit 1
fi

python3 - "$TMPDIR/receipt-negative.json" <<'PY'
import json
import sys

receipt = json.load(open(sys.argv[1]))
assert receipt["verdict"] == "attribution_fail_closed", receipt
assert receipt["cause_classification"] == "receipt_or_metric_binding_gap", receipt
PY

echo "canary attribution receipt tests passed"

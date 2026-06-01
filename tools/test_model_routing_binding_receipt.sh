#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

write_case() {
  local dir="$1"
  local requested="$2"
  local selected="$3"
  local current="$4"
  local metrics_model="$5"
  local exit_code="${6:-0}"
  mkdir -p "$dir"
  cat > "$dir/events.jsonl" <<EOF
{"type":"session.start","data":{"selectedModel":"$selected","context":{"cwd":"$(pwd)","gitRoot":"$(pwd)"}}}
{"type":"session.shutdown","data":{"currentModel":"$current","modelMetrics":{"$metrics_model":{"requests":{"count":1},"usage":{"inputTokens":10,"outputTokens":2,"cacheReadTokens":0,"cacheWriteTokens":0,"reasoningTokens":1}}}}}
EOF
  printf 'OK\n' > "$dir/copilot.log"
  local session_sha
  local log_sha
  session_sha="$(shasum -a 256 "$dir/events.jsonl" | awk '{print $1}')"
  log_sha="$(shasum -a 256 "$dir/copilot.log" | awk '{print $1}')"
  cat > "$dir/metrics.jsonl" <<EOF
{"phase_id":"model_binding_smoke","model":"$requested","command_argv":["/opt/homebrew/bin/copilot","--model","$requested","-p","<prompt>"],"exit_code":$exit_code,"log_sha256":"$log_sha","session_log_sha256":"$session_sha","session_log_detection":{"status":"bound_candidate","bound_candidate_count":1},"direct_provider_token_fields_present":["inputTokens","outputTokens","cacheReadTokens","cacheWriteTokens","reasoningTokens"],"missing_direct_provider_token_fields":[],"token_usage":{"source":"session.shutdown.modelMetrics","primary_model":"$current","requested_models":["$metrics_model"],"model_breakdown":{"$metrics_model":{"request_count":1,"input_tokens":10,"output_tokens":2,"cache_read_tokens":0,"cache_write_tokens":0,"reasoning_tokens":1,"direct_provider_token_fields_present":["inputTokens","outputTokens","cacheWriteTokens","reasoningTokens","cacheReadTokens"],"missing_direct_provider_token_fields":[]}}}}
EOF
}

write_case "$tmpdir/pass" "gpt-5.4" "gpt-5.4" "gpt-5.4" "gpt-5.4"
python3 tools/build_model_routing_binding_receipt.py \
  --model gpt-5.4 \
  --metrics "$tmpdir/pass/metrics.jsonl" \
  --session-log "$tmpdir/pass/events.jsonl" \
  --log "$tmpdir/pass/copilot.log" \
  --output "$tmpdir/pass/receipt.json"

python3 - "$tmpdir/pass/receipt.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["verdict"] == "model_binding_admitted"
assert payload["admitted"] is True
assert payload["checks"]["selected_model_match"] is True
assert payload["checks"]["current_model_match"] is True
assert payload["checks"]["model_metrics_key_match"] is True
PY

write_case "$tmpdir/mismatch" "gpt-5.4" "gpt-5.4" "gpt-5.5" "gpt-5.5"
if python3 tools/build_model_routing_binding_receipt.py \
  --model gpt-5.4 \
  --metrics "$tmpdir/mismatch/metrics.jsonl" \
  --session-log "$tmpdir/mismatch/events.jsonl" \
  --log "$tmpdir/mismatch/copilot.log" \
  --output "$tmpdir/mismatch/receipt.json"; then
  echo "expected model mismatch to fail closed"
  exit 1
fi

python3 - "$tmpdir/mismatch/receipt.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["verdict"] == "model_binding_mismatch"
assert payload["admitted"] is False
assert payload["checks"]["selected_model_match"] is True
assert payload["checks"]["current_model_match"] is False
assert payload["checks"]["model_metrics_key_match"] is False
assert any("currentModel" in item or "modelMetrics" in item for item in payload["blockers"])
PY

write_case "$tmpdir/missing-direct" "gpt-5.4" "gpt-5.4" "gpt-5.4" "gpt-5.4"
python3 - "$tmpdir/missing-direct/metrics.jsonl" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
row = json.loads(path.read_text(encoding="utf-8"))
row["direct_provider_token_fields_present"] = ["inputTokens", "outputTokens"]
row["missing_direct_provider_token_fields"] = ["cacheReadTokens", "cacheWriteTokens", "reasoningTokens"]
path.write_text(json.dumps(row) + "\n", encoding="utf-8")
PY
if python3 tools/build_model_routing_binding_receipt.py \
  --model gpt-5.4 \
  --metrics "$tmpdir/missing-direct/metrics.jsonl" \
  --session-log "$tmpdir/missing-direct/events.jsonl" \
  --log "$tmpdir/missing-direct/copilot.log" \
  --output "$tmpdir/missing-direct/receipt.json"; then
  echo "expected missing direct fields to fail closed"
  exit 1
fi

python3 - "$tmpdir/missing-direct/receipt.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["verdict"] == "model_binding_blocked_incomplete_evidence"
assert payload["checks"]["direct_fields_complete"] is False
PY

write_case "$tmpdir/mismatched-hash" "gpt-5.4" "gpt-5.4" "gpt-5.4" "gpt-5.4"
printf 'different output\n' > "$tmpdir/mismatched-hash/copilot.log"
if python3 tools/build_model_routing_binding_receipt.py \
  --model gpt-5.4 \
  --metrics "$tmpdir/mismatched-hash/metrics.jsonl" \
  --session-log "$tmpdir/mismatched-hash/events.jsonl" \
  --log "$tmpdir/mismatched-hash/copilot.log" \
  --output "$tmpdir/mismatched-hash/receipt.json"; then
  echo "expected mismatched log hash to fail closed"
  exit 1
fi

python3 - "$tmpdir/mismatched-hash/receipt.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["verdict"] == "model_binding_blocked_incomplete_evidence"
assert payload["checks"]["log_hash_match"] is False
assert any("log_sha256" in item for item in payload["blockers"])
PY

write_case "$tmpdir/metrics-model-mismatch" "gpt-5.4" "gpt-5.4" "gpt-5.4" "gpt-5.4"
python3 - "$tmpdir/metrics-model-mismatch/metrics.jsonl" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
row = json.loads(path.read_text(encoding="utf-8"))
row["model"] = "gpt-5.5"
row["command_argv"][2] = "gpt-5.5"
path.write_text(json.dumps(row) + "\n", encoding="utf-8")
PY
if python3 tools/build_model_routing_binding_receipt.py \
  --model gpt-5.4 \
  --metrics "$tmpdir/metrics-model-mismatch/metrics.jsonl" \
  --session-log "$tmpdir/metrics-model-mismatch/events.jsonl" \
  --log "$tmpdir/metrics-model-mismatch/copilot.log" \
  --output "$tmpdir/metrics-model-mismatch/receipt.json"; then
  echo "expected metrics requested-model mismatch to fail closed"
  exit 1
fi

python3 - "$tmpdir/metrics-model-mismatch/receipt.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["verdict"] == "model_binding_mismatch"
assert payload["checks"]["metrics_row_model_match"] is False
assert payload["checks"]["command_argv_model_match"] is False
assert any("metrics row model" in item for item in payload["blockers"])
PY

echo "PASS model routing binding receipt tests"

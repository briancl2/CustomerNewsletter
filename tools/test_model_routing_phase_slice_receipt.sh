#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/pricing.json" <<'JSON'
{
  "generated_at": "2026-05-08T00:00:00Z",
  "models": [
    {
      "model": "gpt-5.5",
      "aliases": ["copilot/gpt-5.5"],
      "input_price": 5.0,
      "output_price": 30.0,
      "reasoning_price": 30.0,
      "cache_price": {"read": 0.5, "write": 0.5}
    },
    {
      "model": "gpt-5.4-mini",
      "aliases": ["copilot/gpt-5.4-mini"],
      "input_price": 0.75,
      "output_price": 4.5,
      "reasoning_price": 4.5,
      "cache_price": {"read": 0.075, "write": 0.075}
    }
  ]
}
JSON

write_row() {
  local name="$1"
  local model="$2"
  local prompt_sha="$3"
  local requests="$4"
  local tools="$5"
  local input="$6"
  local output="$7"
  local cache_read="$8"
  local reasoning="$9"
  local status="${10:-pass}"
  local dir="$tmpdir/$name"
  mkdir -p "$dir"
  cat > "$dir/metrics.jsonl" <<JSON
{"phase_id":"phase3_curation","original_prompt_sha256":"$prompt_sha","prompt_sha256":"bound-$name","artifact_paths":["workspace/newsletter_phase3_curated_sections_2026-02-13.md"],"token_usage":{"source":"session.shutdown.modelMetrics","primary_model":"$model","requested_models":["$model"],"input_tokens":$input,"output_tokens":$output,"cache_read_tokens":$cache_read,"cache_write_tokens":0,"cached_tokens_total":$cache_read,"reasoning_tokens":$reasoning,"request_count":$requests,"tool_calls":$tools,"model_breakdown":{"$model":{"model":"$model","request_count":$requests,"input_tokens":$input,"output_tokens":$output,"cache_read_tokens":$cache_read,"cache_write_tokens":0,"cached_tokens_total":$cache_read,"reasoning_tokens":$reasoning,"direct_provider_token_fields_present":["inputTokens","outputTokens","cacheReadTokens","cacheWriteTokens","reasoningTokens"],"missing_direct_provider_token_fields":[]}}}}
JSON
  local metrics_sha
  metrics_sha="$(shasum -a 256 "$dir/metrics.jsonl" | awk '{print $1}')"
  cat > "$dir/binding.json" <<JSON
{"receipt_type":"model_routing_binding","admitted":true,"verdict":"model_binding_admitted","checks":{"exit_zero":true,"response_present":true,"session_log_hash_match":true,"log_hash_match":true,"bound_session":true,"direct_fields_complete":true,"session_log_direct_fields_complete":true,"metrics_row_model_match":true,"command_argv_model_match":true,"selected_model_match":true,"current_model_match":true,"model_metrics_key_match":true,"primary_model_match":true,"parsed_model_metrics_key_match":true},"requested_model":"$model","metrics_path":"$dir/metrics.jsonl","metrics_sha256":"$metrics_sha","token_usage":{"source":"session.shutdown.modelMetrics","primary_model":"$model","requested_models":["$model"],"input_tokens":$input,"output_tokens":$output,"cache_read_tokens":$cache_read,"cache_write_tokens":0,"cached_tokens_total":$cache_read,"reasoning_tokens":$reasoning,"request_count":$requests,"tool_calls":$tools,"model_breakdown":{"$model":{"model":"$model","request_count":$requests,"input_tokens":$input,"output_tokens":$output,"cache_read_tokens":$cache_read,"cache_write_tokens":0,"cached_tokens_total":$cache_read,"reasoning_tokens":$reasoning,"direct_provider_token_fields_present":["inputTokens","outputTokens","cacheReadTokens","cacheWriteTokens","reasoningTokens"],"missing_direct_provider_token_fields":[]}}}}
JSON
  cat > "$dir/summary.md" <<EOF
# Summary
- Final Status: $status
EOF
}

write_row control gpt-5.5 same-prompt 10 8 100000 10000 50000 3000 pass
write_row candidate gpt-5.4-mini same-prompt 10 8 100000 10000 50000 3000 pass

python3 tools/build_model_routing_phase_slice_receipt.py \
  --pair-id pair-pass \
  --mode benchmark \
  --control-binding "$tmpdir/control/binding.json" \
  --candidate-binding "$tmpdir/candidate/binding.json" \
  --control-summary "$tmpdir/control/summary.md" \
  --candidate-summary "$tmpdir/candidate/summary.md" \
  --pricing-snapshot "$tmpdir/pricing.json" \
  --output "$tmpdir/pass.json"

python3 - "$tmpdir/pass.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["qualified"] is True
assert payload["checks"]["candidate_api_equivalent_cost_lower"] is True
assert payload["checks"]["candidate_request_count_not_higher"] is True
PY

python3 - "$tmpdir/control/metrics.jsonl" "$tmpdir/control/binding.json" "$tmpdir/candidate/metrics.jsonl" "$tmpdir/candidate/binding.json" <<'PY'
import hashlib, json, sys
from pathlib import Path
for metrics_text, binding_text in ((sys.argv[1], sys.argv[2]), (sys.argv[3], sys.argv[4])):
    metrics_path = Path(metrics_text)
    binding_path = Path(binding_text)
    row = json.loads(metrics_path.read_text(encoding="utf-8"))
    row["phase_id"] = "phase3_section_subtask"
    metrics_path.write_text(json.dumps(row) + "\n", encoding="utf-8")
    binding = json.loads(binding_path.read_text(encoding="utf-8"))
    binding["metrics_sha256"] = hashlib.sha256(metrics_path.read_bytes()).hexdigest()
    binding_path.write_text(json.dumps(binding) + "\n", encoding="utf-8")
PY

python3 tools/build_model_routing_phase_slice_receipt.py \
  --pair-id pair-subtask-pass \
  --mode benchmark \
  --expected-phase-id phase3_section_subtask \
  --control-binding "$tmpdir/control/binding.json" \
  --candidate-binding "$tmpdir/candidate/binding.json" \
  --control-summary "$tmpdir/control/summary.md" \
  --candidate-summary "$tmpdir/candidate/summary.md" \
  --pricing-snapshot "$tmpdir/pricing.json" \
  --output "$tmpdir/subtask-pass.json"

python3 - "$tmpdir/subtask-pass.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["qualified"] is True
assert payload["expected_phase_id"] == "phase3_section_subtask"
assert payload["checks"]["control_phase_matches_expected"] is True
assert payload["checks"]["candidate_phase_matches_expected"] is True
PY

write_row control gpt-5.5 same-prompt 10 8 100000 10000 50000 3000 pass
write_row candidate gpt-5.4-mini same-prompt 10 8 100000 10000 50000 3000 pass

write_row policy_candidate gpt-5.4-mini policy-full-prompt 10 8 100000 10000 50000 3000 pass
printf '{"policy_id":"test-policy","prompt_append":["Budget guard."]}\n' > "$tmpdir/policy.json"
policy_sha="$(shasum -a 256 "$tmpdir/policy.json" | awk '{print $1}')"
cat > "$tmpdir/control/prompt.md" <<'EOF'
base prompt
EOF
cat > "$tmpdir/policy_candidate/prompt.md" <<'EOF'
base prompt

Evidence-only model-routing request/tool budget policy (test-policy):
Budget guard.
EOF
control_prompt_sha="$(shasum -a 256 "$tmpdir/control/prompt.md" | awk '{print $1}')"
candidate_prompt_sha="$(shasum -a 256 "$tmpdir/policy_candidate/prompt.md" | awk '{print $1}')"
python3 - "$tmpdir/control/metrics.jsonl" "$tmpdir/control/binding.json" "$control_prompt_sha" <<'PY'
import hashlib, json, sys
from pathlib import Path
metrics_path = Path(sys.argv[1])
binding_path = Path(sys.argv[2])
prompt_sha = sys.argv[3]
row = json.loads(metrics_path.read_text(encoding="utf-8"))
row["original_prompt_sha256"] = prompt_sha
metrics_path.write_text(json.dumps(row) + "\n", encoding="utf-8")
binding = json.loads(binding_path.read_text(encoding="utf-8"))
binding["metrics_sha256"] = hashlib.sha256(metrics_path.read_bytes()).hexdigest()
binding["token_usage"] = row["token_usage"]
binding_path.write_text(json.dumps(binding) + "\n", encoding="utf-8")
PY
python3 - "$tmpdir/policy_candidate/metrics.jsonl" "$tmpdir/policy_candidate/binding.json" "$candidate_prompt_sha" <<'PY'
import hashlib, json, sys
from pathlib import Path
metrics_path = Path(sys.argv[1])
binding_path = Path(sys.argv[2])
prompt_sha = sys.argv[3]
row = json.loads(metrics_path.read_text(encoding="utf-8"))
row["original_prompt_sha256"] = prompt_sha
metrics_path.write_text(json.dumps(row) + "\n", encoding="utf-8")
binding = json.loads(binding_path.read_text(encoding="utf-8"))
binding["metrics_sha256"] = hashlib.sha256(metrics_path.read_bytes()).hexdigest()
binding["token_usage"] = row["token_usage"]
binding_path.write_text(json.dumps(binding) + "\n", encoding="utf-8")
PY
cat > "$tmpdir/control/prompt-metadata.json" <<JSON
{"receipt_type":"phase3_prompt_policy_metadata","base_prompt_sha256":"$control_prompt_sha","full_prompt_sha256":"$control_prompt_sha","policy_enabled":false}
JSON
cat > "$tmpdir/policy_candidate/prompt-metadata.json" <<JSON
{"receipt_type":"phase3_prompt_policy_metadata","base_prompt_sha256":"$control_prompt_sha","full_prompt_sha256":"$candidate_prompt_sha","policy_enabled":true,"policy_id":"test-policy","policy_sha256":"$policy_sha"}
JSON
python3 tools/build_model_routing_phase_slice_receipt.py \
  --pair-id pair-policy-variant \
  --mode benchmark \
  --control-binding "$tmpdir/control/binding.json" \
  --candidate-binding "$tmpdir/policy_candidate/binding.json" \
  --control-summary "$tmpdir/control/summary.md" \
  --candidate-summary "$tmpdir/policy_candidate/summary.md" \
  --control-prompt-metadata "$tmpdir/control/prompt-metadata.json" \
  --candidate-prompt-metadata "$tmpdir/policy_candidate/prompt-metadata.json" \
  --candidate-prompt-policy "$tmpdir/policy.json" \
  --control-prompt-file "$tmpdir/control/prompt.md" \
  --candidate-prompt-file "$tmpdir/policy_candidate/prompt.md" \
  --pricing-snapshot "$tmpdir/pricing.json" \
  --output "$tmpdir/policy-variant.json"

python3 - "$tmpdir/policy-variant.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["qualified"] is True
assert payload["checks"]["same_original_prompt_hash"] is False
assert payload["checks"]["same_base_prompt_hash"] is True
assert payload["checks"]["candidate_prompt_policy_hash_matches_config"] is True
assert payload["checks"]["candidate_prompt_equals_control_plus_policy"] is True
assert "same_original_prompt_hash" not in payload["blockers"]
PY

write_row metadata_candidate gpt-5.4-mini "$control_prompt_sha" 10 8 100000 10000 50000 3000 pass
cat > "$tmpdir/metadata_candidate/prompt-metadata.json" <<JSON
{"receipt_type":"phase3_prompt_policy_metadata","base_prompt_sha256":"$control_prompt_sha","full_prompt_sha256":"$control_prompt_sha","policy_enabled":false}
JSON
python3 tools/build_model_routing_phase_slice_receipt.py \
  --pair-id pair-same-prompt-metadata \
  --mode benchmark \
  --control-binding "$tmpdir/control/binding.json" \
  --candidate-binding "$tmpdir/metadata_candidate/binding.json" \
  --control-summary "$tmpdir/control/summary.md" \
  --candidate-summary "$tmpdir/metadata_candidate/summary.md" \
  --control-prompt-metadata "$tmpdir/control/prompt-metadata.json" \
  --candidate-prompt-metadata "$tmpdir/metadata_candidate/prompt-metadata.json" \
  --pricing-snapshot "$tmpdir/pricing.json" \
  --output "$tmpdir/same-prompt-metadata.json"

python3 - "$tmpdir/same-prompt-metadata.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["qualified"] is True
assert payload["checks"]["same_original_prompt_hash"] is True
assert "candidate_prompt_policy_enabled" not in payload["qualification_checks"]
PY

write_row request_amp gpt-5.4-mini same-prompt 11 8 100000 10000 50000 3000 pass
if python3 tools/build_model_routing_phase_slice_receipt.py \
  --pair-id pair-request-amp \
  --mode benchmark \
  --control-binding "$tmpdir/control/binding.json" \
  --candidate-binding "$tmpdir/request_amp/binding.json" \
  --control-summary "$tmpdir/control/summary.md" \
  --candidate-summary "$tmpdir/request_amp/summary.md" \
  --pricing-snapshot "$tmpdir/pricing.json" \
  --output "$tmpdir/request-amp.json"; then
  echo "expected request amplification to fail closed" >&2
  exit 1
fi

python3 - "$tmpdir/request-amp.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["qualified"] is False
assert "candidate_request_count_not_higher" in payload["blockers"]
PY

write_row prompt_mismatch gpt-5.4-mini different-prompt 10 8 100000 10000 50000 3000 pass
if python3 tools/build_model_routing_phase_slice_receipt.py \
  --pair-id pair-prompt-mismatch \
  --mode benchmark \
  --control-binding "$tmpdir/control/binding.json" \
  --candidate-binding "$tmpdir/prompt_mismatch/binding.json" \
  --control-summary "$tmpdir/control/summary.md" \
  --candidate-summary "$tmpdir/prompt_mismatch/summary.md" \
  --pricing-snapshot "$tmpdir/pricing.json" \
  --output "$tmpdir/prompt-mismatch.json"; then
  echo "expected prompt mismatch to fail closed" >&2
  exit 1
fi

python3 - "$tmpdir/prompt-mismatch.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["qualified"] is False
assert "same_original_prompt_hash" in payload["blockers"]
PY

write_row quality_fail gpt-5.4-mini same-prompt 10 8 100000 10000 50000 3000 fail
if python3 tools/build_model_routing_phase_slice_receipt.py \
  --pair-id pair-quality-fail \
  --mode benchmark \
  --control-binding "$tmpdir/control/binding.json" \
  --candidate-binding "$tmpdir/quality_fail/binding.json" \
  --control-summary "$tmpdir/control/summary.md" \
  --candidate-summary "$tmpdir/quality_fail/summary.md" \
  --pricing-snapshot "$tmpdir/pricing.json" \
  --output "$tmpdir/quality-fail.json"; then
  echo "expected quality failure to fail closed" >&2
  exit 1
fi

python3 - "$tmpdir/quality-fail.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["qualified"] is False
assert "candidate_quality_pass" in payload["blockers"]
PY

write_row missing_prompt gpt-5.4-mini same-prompt 10 8 100000 10000 50000 3000 pass
python3 - "$tmpdir/missing_prompt/metrics.jsonl" "$tmpdir/missing_prompt/binding.json" <<'PY'
import json, sys, hashlib
from pathlib import Path
metrics_path = Path(sys.argv[1])
binding_path = Path(sys.argv[2])
row = json.loads(metrics_path.read_text(encoding="utf-8"))
row.pop("original_prompt_sha256", None)
metrics_path.write_text(json.dumps(row) + "\n", encoding="utf-8")
binding = json.loads(binding_path.read_text(encoding="utf-8"))
binding["metrics_sha256"] = hashlib.sha256(metrics_path.read_bytes()).hexdigest()
binding["token_usage"] = row["token_usage"]
binding_path.write_text(json.dumps(binding) + "\n", encoding="utf-8")
PY
if python3 tools/build_model_routing_phase_slice_receipt.py \
  --pair-id pair-missing-prompt \
  --mode benchmark \
  --control-binding "$tmpdir/control/binding.json" \
  --candidate-binding "$tmpdir/missing_prompt/binding.json" \
  --control-summary "$tmpdir/control/summary.md" \
  --candidate-summary "$tmpdir/missing_prompt/summary.md" \
  --pricing-snapshot "$tmpdir/pricing.json" \
  --output "$tmpdir/missing-prompt.json"; then
  echo "expected missing prompt hash to fail closed" >&2
  exit 1
fi

python3 - "$tmpdir/missing-prompt.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["qualified"] is False
assert "candidate_original_prompt_hash_present" in payload["blockers"]
PY

write_row stale_metrics gpt-5.4-mini same-prompt 10 8 100000 10000 50000 3000 pass
python3 - "$tmpdir/stale_metrics/metrics.jsonl" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
row = json.loads(path.read_text(encoding="utf-8"))
row["token_usage"]["request_count"] = 12
path.write_text(json.dumps(row) + "\n", encoding="utf-8")
PY
if python3 tools/build_model_routing_phase_slice_receipt.py \
  --pair-id pair-stale-metrics \
  --mode benchmark \
  --control-binding "$tmpdir/control/binding.json" \
  --candidate-binding "$tmpdir/stale_metrics/binding.json" \
  --control-summary "$tmpdir/control/summary.md" \
  --candidate-summary "$tmpdir/stale_metrics/summary.md" \
  --pricing-snapshot "$tmpdir/pricing.json" \
  --output "$tmpdir/stale-metrics.json"; then
  echo "expected stale/tampered metrics to fail closed" >&2
  exit 1
fi

python3 - "$tmpdir/stale-metrics.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["qualified"] is False
assert "candidate_metrics_hash_matches_binding" in payload["blockers"]
assert "candidate_binding_token_usage_matches_metrics" in payload["blockers"]
PY

write_row inconsistent_binding gpt-5.4-mini same-prompt 10 8 100000 10000 50000 3000 pass
python3 - "$tmpdir/inconsistent_binding/binding.json" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
binding = json.loads(path.read_text(encoding="utf-8"))
binding["verdict"] = "model_binding_mismatch"
binding["checks"]["current_model_match"] = False
path.write_text(json.dumps(binding) + "\n", encoding="utf-8")
PY
if python3 tools/build_model_routing_phase_slice_receipt.py \
  --pair-id pair-inconsistent-binding \
  --mode benchmark \
  --control-binding "$tmpdir/control/binding.json" \
  --candidate-binding "$tmpdir/inconsistent_binding/binding.json" \
  --control-summary "$tmpdir/control/summary.md" \
  --candidate-summary "$tmpdir/inconsistent_binding/summary.md" \
  --pricing-snapshot "$tmpdir/pricing.json" \
  --output "$tmpdir/inconsistent-binding.json"; then
  echo "expected inconsistent binding to fail closed" >&2
  exit 1
fi

python3 - "$tmpdir/inconsistent-binding.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["qualified"] is False
assert "candidate_binding_verdict_admitted" in payload["blockers"]
assert "candidate_binding_checks_all_pass" in payload["blockers"]
PY

write_row missing_metrics gpt-5.4-mini same-prompt 10 8 100000 10000 50000 3000 pass
python3 - "$tmpdir/missing_metrics/binding.json" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
binding = json.loads(path.read_text(encoding="utf-8"))
binding["metrics_path"] = ""
path.write_text(json.dumps(binding) + "\n", encoding="utf-8")
PY
if python3 tools/build_model_routing_phase_slice_receipt.py \
  --pair-id pair-missing-metrics \
  --mode benchmark \
  --control-binding "$tmpdir/control/binding.json" \
  --candidate-binding "$tmpdir/missing_metrics/binding.json" \
  --control-summary "$tmpdir/control/summary.md" \
  --candidate-summary "$tmpdir/missing_metrics/summary.md" \
  --pricing-snapshot "$tmpdir/pricing.json" \
  --output "$tmpdir/missing-metrics.json"; then
  echo "expected missing metrics path to fail closed" >&2
  exit 1
fi

python3 - "$tmpdir/missing-metrics.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["qualified"] is False
assert "candidate_metrics_hash_matches_binding" in payload["blockers"]
assert payload["candidate"]["row_errors"]
PY

echo "PASS model routing phase-slice receipt tests"

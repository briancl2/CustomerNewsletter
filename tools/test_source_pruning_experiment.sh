#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

policy="config/experiment_pruning_policies/burst18-source-candidate-v1.json"
prod_root="runs/product_runs/20260430T115004Z_production_proof/artifacts"
bench_root="runs/product_runs/20260430T163723Z_benchmark_proof/artifacts"

prod_hash_before="$(python3 - "$prod_root/workspace/newsletter_phase3_working_set_2026-04-16.md" <<'PY'
import hashlib
import sys
from pathlib import Path
print(hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"

python3 tools/apply_newsletter_source_pruning_policy.py \
  2026-02-14 \
  2026-04-16 \
  --policy "$policy" \
  --source-root "$prod_root" \
  --output-root "$tmpdir/prod" \
  --require-admission >/dev/null

python3 tools/apply_newsletter_source_pruning_policy.py \
  2025-12-05 \
  2026-02-13 \
  --policy "$policy" \
  --source-root "$bench_root" \
  --output-root "$tmpdir/bench" \
  --require-admission >/dev/null

prod_hash_after="$(python3 - "$prod_root/workspace/newsletter_phase3_working_set_2026-04-16.md" <<'PY'
import hashlib
import sys
from pathlib import Path
print(hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"

if [ "$prod_hash_before" != "$prod_hash_after" ]; then
  echo "ASSERTION FAILED: pruning tool mutated retained source artifact"
  exit 1
fi

python3 - "$tmpdir/prod/workspace/newsletter_source_pruning_receipt_2026-04-16.json" "$tmpdir/bench/workspace/newsletter_source_pruning_receipt_2026-02-13.json" <<'PY'
import json
import sys
from pathlib import Path

for raw in sys.argv[1:]:
    payload = json.loads(Path(raw).read_text(encoding="utf-8"))
    if payload["admission"]["pass"] is not True:
        raise SystemExit(f"admission failed unexpectedly for {raw}")
    if payload["selected_context_reduction_words"] < 500:
        raise SystemExit("expected at least 500 words of selected-context reduction")
    if payload["selected_context_reduction_fraction"] < 0.1:
        raise SystemExit("expected at least 10 percent selected-context reduction")
    if payload["required_source_classes_preserved"] is not True:
        raise SystemExit("expected required source classes to be preserved")
    if "No durable token or dollar savings claim" not in payload["non_claims"]:
        raise SystemExit("expected explicit non-claim boundary")
PY

if python3 tools/apply_newsletter_source_pruning_policy.py \
  2026-02-14 \
  2026-04-16 \
  --policy "$policy" \
  --source-root "$tmpdir/missing-source-root" \
  --output-root "$tmpdir/missing-out" \
  --require-admission >/dev/null 2>&1; then
  echo "ASSERTION FAILED: missing source classes should fail closed"
  exit 1
fi

prompt="$(bash tools/render_product_run_prompt.sh 2026-02-14 2026-04-16 production --source-pruning-policy "$policy")"
if ! grep -Fq "Source-pruning experiment:" <<<"$prompt"; then
  echo "ASSERTION FAILED: pruned prompt missing experiment block"
  exit 1
fi
if ! grep -Fq "apply_newsletter_source_pruning_policy.py 2026-02-14 2026-04-16" <<<"$prompt"; then
  echo "ASSERTION FAILED: pruned prompt missing exact tool command"
  exit 1
fi
if ! grep -Fq "newsletter_source_pruning_context_2026-04-16.md" <<<"$prompt"; then
  echo "ASSERTION FAILED: pruned prompt missing context artifact"
  exit 1
fi
if ! grep -Fq "do not perform broad repo/source search expansion" <<<"$prompt"; then
  echo "ASSERTION FAILED: pruned prompt missing search-expansion guard"
  exit 1
fi

mkdir -p "$tmpdir/control-run" "$tmpdir/pruned-run/artifacts/workspace"
cat > "$tmpdir/pruned-run/artifacts/workspace/newsletter_source_pruning_receipt_2026-04-16.json" <<'JSON'
{
  "schema_version": 1,
  "policy_id": "burst18-source-candidate-v1",
  "policy_sha256": "policy-hash",
  "admission": {
    "pass": true
  }
}
JSON

python3 - "$tmpdir/control-scorecard.json" "$tmpdir/pruned-scorecard.json" "$tmpdir/control-run" "$tmpdir/pruned-run" <<'PY'
import json
import sys
from pathlib import Path

control_path = Path(sys.argv[1])
pruned_path = Path(sys.argv[2])
control_run = Path(sys.argv[3])
pruned_run = Path(sys.argv[4])
base = {
    "schema_version": 1,
    "start": "2026-02-14",
    "end": "2026-04-16",
    "mode": "production",
    "primary_model": "gpt-5.5",
    "experiment": {
        "run_class": "ordinary_proof",
        "prompt_equality": {
            "available": True,
            "matches_current_renderer": True
        }
    },
    "token_usage": {
        "source": "session.shutdown.modelMetrics",
        "requested_models": ["gpt-5.5"],
        "input_tokens": 10000,
        "output_tokens": 1000,
        "cache_read_tokens": 0,
        "cache_write_tokens": 0,
        "reasoning_tokens": 500,
        "request_count": 1,
        "direct_provider_token_fields_present": [
            "inputTokens",
            "outputTokens",
            "cacheReadTokens",
            "cacheWriteTokens",
            "reasoningTokens"
        ],
        "missing_direct_provider_token_fields": [],
        "model_direct_provider_token_fields": {
            "gpt-5.5": {
                "direct_provider_token_fields_present": [
                    "reasoningTokens",
                    "cacheWriteTokens",
                    "cacheReadTokens",
                    "outputTokens",
                    "inputTokens"
                ],
                "missing_direct_provider_token_fields": []
            }
        }
    },
    "quality": {
        "strict_pass": True,
        "newsletter_pass": True,
        "rubric_pass": True,
        "warning_taxonomy_classes": []
    },
    "cost_estimate": {
        "total_usd": 1.0,
        "unpriced_models": []
    }
}
control = dict(base)
control["run_id"] = "control"
control["run_dir"] = str(control_run)
pruned = json.loads(json.dumps(base))
pruned["run_id"] = "pruned"
pruned["run_dir"] = str(pruned_run)
pruned["experiment"]["run_class"] = "source_pruning_candidate"
pruned["experiment"]["source_pruning_policy"] = {
    "enabled": True,
    "policy_id": "burst18-source-candidate-v1",
    "policy_sha256": "policy-hash"
}
pruned["token_usage"]["input_tokens"] = 9000
pruned["cost_estimate"]["total_usd"] = 0.9
control_path.write_text(json.dumps(control, indent=2) + "\n", encoding="utf-8")
pruned_path.write_text(json.dumps(pruned, indent=2) + "\n", encoding="utf-8")
PY

python3 tools/build_source_pruning_experiment_receipt.py \
  --control-scorecard "$tmpdir/control-scorecard.json" \
  --pruned-scorecard "$tmpdir/pruned-scorecard.json" \
  --output "$tmpdir/pair-receipt.json" >/dev/null

python3 - "$tmpdir/pair-receipt.json" "$tmpdir/pruned-scorecard.json" <<'PY'
import json
import sys
from pathlib import Path

receipt = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if receipt["pair_pass"] is not True:
    raise SystemExit("expected synthetic matched pair receipt to pass")
if receipt["deltas"]["input_tokens"] != 1000:
    raise SystemExit("expected input token delta to be retained")
PY

python3 - "$tmpdir/pruned-scorecard.json" "$tmpdir/pruned-scorecard-policy-mismatch.json" <<'PY'
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
payload = json.loads(source.read_text(encoding="utf-8"))
payload["experiment"]["source_pruning_policy"]["policy_sha256"] = "mismatched-policy-hash"
target.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

if python3 tools/build_source_pruning_experiment_receipt.py \
  --control-scorecard "$tmpdir/control-scorecard.json" \
  --pruned-scorecard "$tmpdir/pruned-scorecard-policy-mismatch.json" \
  --output "$tmpdir/policy-mismatch-pair-receipt.json" >/dev/null; then
  echo "ASSERTION FAILED: mismatched source-pruning policy hash should fail the receipt command"
  exit 1
fi

python3 - "$tmpdir/policy-mismatch-pair-receipt.json" <<'PY'
import json
import sys
from pathlib import Path

receipt = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if receipt["pair_pass"] is not False:
    raise SystemExit("mismatched policy hash must block pair pass")
if receipt["checks"]["policy_hash_bound"] is not False:
    raise SystemExit("expected policy hash binding check to fail")
PY

mkdir -p "$tmpdir/control-run/artifacts/workspace"
cp "$tmpdir/pruned-run/artifacts/workspace/newsletter_source_pruning_receipt_2026-04-16.json" \
  "$tmpdir/control-run/artifacts/workspace/newsletter_source_pruning_receipt_2026-04-16.json"
printf 'stale pruning context\n' > "$tmpdir/control-run/artifacts/workspace/newsletter_source_pruning_context_2026-04-16.md"

if python3 tools/build_source_pruning_experiment_receipt.py \
  --control-scorecard "$tmpdir/control-scorecard.json" \
  --pruned-scorecard "$tmpdir/pruned-scorecard.json" \
  --output "$tmpdir/stale-control-pair-receipt.json" >/dev/null; then
  echo "ASSERTION FAILED: stale control pruning artifacts should fail the receipt command"
  exit 1
fi

python3 - "$tmpdir/stale-control-pair-receipt.json" <<'PY'
import json
import sys
from pathlib import Path

receipt = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if receipt["pair_pass"] is not False:
    raise SystemExit("stale control pruning artifacts must block pair pass")
if receipt["checks"]["control_pruning_artifacts_absent"] is not False:
    raise SystemExit("expected control pruning artifact absence check to fail")
PY

rm -f "$tmpdir/control-run/artifacts/workspace/newsletter_source_pruning_receipt_2026-04-16.json" \
  "$tmpdir/control-run/artifacts/workspace/newsletter_source_pruning_context_2026-04-16.md"

python3 - "$tmpdir/pruned-scorecard.json" <<'PY'
import json
import sys
from pathlib import Path

pruned_path = Path(sys.argv[1])
payload = json.loads(pruned_path.read_text(encoding="utf-8"))
payload["token_usage"]["missing_direct_provider_token_fields"] = ["inputTokens"]
payload["token_usage"]["direct_provider_token_fields_present"] = [
    "outputTokens",
    "cacheReadTokens",
    "cacheWriteTokens",
    "reasoningTokens"
]
payload["token_usage"]["model_direct_provider_token_fields"]["gpt-5.5"][
    "missing_direct_provider_token_fields"
] = ["inputTokens"]
payload["token_usage"]["model_direct_provider_token_fields"]["gpt-5.5"][
    "direct_provider_token_fields_present"
] = [
    "outputTokens",
    "cacheReadTokens",
    "cacheWriteTokens",
    "reasoningTokens",
]
pruned_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

if python3 tools/build_source_pruning_experiment_receipt.py \
  --control-scorecard "$tmpdir/control-scorecard.json" \
  --pruned-scorecard "$tmpdir/pruned-scorecard.json" \
  --output "$tmpdir/missing-field-pair-receipt.json" >/dev/null; then
  echo "ASSERTION FAILED: missing direct token fields should fail the receipt command"
  exit 1
fi

python3 - "$tmpdir/missing-field-pair-receipt.json" <<'PY'
import json
import sys
from pathlib import Path

receipt = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if receipt["pair_pass"] is not False:
    raise SystemExit("missing direct token fields must block pair pass")
if receipt["checks"]["pruned_direct_token_fields_pass"] is not False:
    raise SystemExit("expected pruned direct-field check to fail")
PY

echo "PASS: source pruning experiment tests passed"

#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

policy="config/experiment_output_shape_policies/burst22-output-shape-v1.json"

prod_receipt="$tmpdir/prod-output-shape-receipt.json"
python3 tools/apply_newsletter_output_shape_policy.py \
  2026-02-14 \
  2026-04-16 \
  --policy "$policy" \
  --output-root "$tmpdir/prod" \
  --require-admission \
  >"$tmpdir/prod-receipt-path.txt"

python3 - "$tmpdir/prod/workspace/newsletter_output_shape_receipt_2026-04-16.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["pass"] is not True:
    raise SystemExit("expected production output-shape admission to pass")
if payload["checks"]["materiality_pass"] is not False:
    raise SystemExit("production retained output should not clear 500-word materiality")
if payload["checks"]["retained_output_present"] is not True:
    raise SystemExit("expected retained production output baseline")
if payload["checks"]["retained_heading_budget_pass"] is not True:
    raise SystemExit("expected retained production headings to fit policy budget")
if payload["non_claims"]["production_adoption"] is not False:
    raise SystemExit("expected production adoption non-claim")
if payload["non_claims"]["durable_token_savings"] is not False:
    raise SystemExit("expected durable token savings non-claim")
if not payload.get("context_sha256"):
    raise SystemExit("expected context hash")
PY

bench_receipt="$tmpdir/bench/workspace/newsletter_output_shape_receipt_2026-02-13.json"
python3 tools/apply_newsletter_output_shape_policy.py \
  2025-12-05 \
  2026-02-13 \
  --policy "$policy" \
  --output-root "$tmpdir/bench" \
  --require-admission \
  --require-materiality \
  >/dev/null

python3 - "$bench_receipt" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["pass"] is not True:
    raise SystemExit("expected benchmark output-shape admission to pass")
if payload["checks"]["materiality_pass"] is not True:
    raise SystemExit("expected benchmark retained output to clear materiality")
if payload["potential_reduction_words"] < 500:
    raise SystemExit("expected material benchmark word reduction")
PY

mutated_root="$tmpdir/mutated-root"
mkdir -p "$mutated_root/config/experiment_output_shape_policies" "$mutated_root/output"
cp output/2026-02_february_newsletter.md "$mutated_root/output/2026-02_february_newsletter.md"
mutated_policy="$mutated_root/config/experiment_output_shape_policies/mutated-policy.json"
python3 - "$policy" "$mutated_policy" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["production_adoption"] = True
Path(sys.argv[2]).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

if python3 tools/apply_newsletter_output_shape_policy.py \
  2025-12-05 \
  2026-02-13 \
  --policy config/experiment_output_shape_policies/mutated-policy.json \
  --source-root "$mutated_root" \
  --output-root "$tmpdir/mutated" \
  --require-admission >/dev/null 2>&1; then
  echo "ASSERTION FAILED: production-adoption policy must not admit"
  exit 1
fi

if python3 tools/apply_newsletter_output_shape_policy.py \
  2026-01-01 \
  2026-02-01 \
  --policy "$policy" \
  --output-root "$tmpdir/bad-range" \
  --require-admission >/dev/null 2>&1; then
  echo "ASSERTION FAILED: unsupported date range must fail"
  exit 1
fi

missing_root="$tmpdir/missing-root"
mkdir -p "$missing_root/config/experiment_output_shape_policies"
cp "$policy" "$missing_root/config/experiment_output_shape_policies/burst22-output-shape-v1.json"
if python3 tools/apply_newsletter_output_shape_policy.py \
  2025-12-05 \
  2026-02-13 \
  --source-root "$missing_root" \
  --policy config/experiment_output_shape_policies/burst22-output-shape-v1.json \
  --output-root "$tmpdir/missing-baseline" \
  --require-admission >/dev/null 2>&1; then
  echo "ASSERTION FAILED: missing retained baseline must not admit"
  exit 1
fi

preflight_root="$tmpdir/preflight-root"
mkdir -p "$preflight_root/config/experiment_output_shape_policies" \
  "$preflight_root/workspace/archived/preflight/2026-02-14_to_2026-04-16_20260506T000000Z"
cp "$policy" "$preflight_root/config/experiment_output_shape_policies/burst22-output-shape-v1.json"
cp output/2026-04_april_newsletter.md \
  "$preflight_root/workspace/archived/preflight/2026-02-14_to_2026-04-16_20260506T000000Z/2026-04_april_newsletter_preflight_prev.md"
python3 tools/apply_newsletter_output_shape_policy.py \
  2026-02-14 \
  2026-04-16 \
  --source-root "$preflight_root" \
  --policy config/experiment_output_shape_policies/burst22-output-shape-v1.json \
  --output-root "$tmpdir/preflight-output" \
  --require-admission >/dev/null
python3 - "$tmpdir/preflight-output/workspace/newsletter_output_shape_receipt_2026-04-16.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["retained_output_source"] != "preflight_archive":
    raise SystemExit("expected retained baseline to resolve from preflight archive")
if payload["checks"]["retained_output_present"] is not True:
    raise SystemExit("expected preflight baseline to count as retained output")
PY

heading_root="$tmpdir/heading-root"
mkdir -p "$heading_root/config/experiment_output_shape_policies" "$heading_root/output"
cp output/2026-04_april_newsletter.md "$heading_root/output/2026-04_april_newsletter.md"
heading_policy="$heading_root/config/experiment_output_shape_policies/heading-budget-policy.json"
python3 - "$policy" "$heading_policy" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["mode_targets"]["production"]["max_h1_count"] = 1
Path(sys.argv[2]).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

if python3 tools/apply_newsletter_output_shape_policy.py \
  2026-02-14 \
  2026-04-16 \
  --source-root "$heading_root" \
  --policy config/experiment_output_shape_policies/heading-budget-policy.json \
  --output-root "$tmpdir/bad-heading-budget" \
  --require-admission >/dev/null 2>&1; then
  echo "ASSERTION FAILED: retained heading budget mismatch must not admit"
  exit 1
fi

benchmark_prompt="$(bash tools/render_product_run_prompt.sh 2025-12-05 2026-02-13 benchmark --output-shape-policy "$policy")"
if ! grep -Fq "Output-shape budget experiment:" <<<"$benchmark_prompt"; then
  echo "ASSERTION FAILED: prompt missing output-shape block"
  exit 1
fi
if ! grep -Fq "Policy SHA256:" <<<"$benchmark_prompt"; then
  echo "ASSERTION FAILED: prompt missing output-shape policy hash"
  exit 1
fi
if ! grep -Fq "tools/apply_newsletter_output_shape_policy.py 2025-12-05 2026-02-13" <<<"$benchmark_prompt"; then
  echo "ASSERTION FAILED: prompt missing output-shape apply command"
  exit 1
fi

if bash tools/run_product_newsletter.sh \
  2025-12-05 \
  2026-02-13 \
  benchmark \
  --source-pruning-policy config/experiment_pruning_policies/burst18-source-candidate-v1.json \
  --output-shape-policy "$policy" >/dev/null 2>&1; then
  echo "ASSERTION FAILED: source-pruning and output-shape hooks must be mutually exclusive"
  exit 1
fi
if bash tools/render_product_run_prompt.sh \
  2025-12-05 \
  2026-02-13 \
  benchmark \
  --source-pruning-policy config/experiment_pruning_policies/burst18-source-candidate-v1.json \
  --output-shape-policy "$policy" >/dev/null 2>&1; then
  echo "ASSERTION FAILED: renderer must reject mixed source-pruning and output-shape hooks"
  exit 1
fi

mkdir -p "$tmpdir/run/control/artifacts/workspace" "$tmpdir/run/variant/artifacts/workspace"
cp "$bench_receipt" "$tmpdir/run/variant/artifacts/workspace/newsletter_output_shape_receipt_2026-02-13.json"
cp "$tmpdir/bench/workspace/newsletter_output_shape_context_2026-02-13.md" \
  "$tmpdir/run/variant/artifacts/workspace/newsletter_output_shape_context_2026-02-13.md"

policy_sha="$(python3 - "$policy" <<'PY'
import hashlib
import sys
from pathlib import Path
print(hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
control_prompt="$tmpdir/run/control/prompt.txt"
variant_prompt="$tmpdir/run/variant/prompt.txt"
bash tools/render_product_run_prompt.sh 2025-12-05 2026-02-13 benchmark > "$control_prompt"
bash tools/render_product_run_prompt.sh 2025-12-05 2026-02-13 benchmark \
  --output-shape-policy "$policy" > "$variant_prompt"
control_prompt_sha="$(python3 - "$control_prompt" <<'PY'
import hashlib
import sys
from pathlib import Path
print(hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
variant_prompt_sha="$(python3 - "$variant_prompt" <<'PY'
import hashlib
import sys
from pathlib import Path
print(hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"

cat > "$tmpdir/run/control/run-scorecard.json" <<JSON
{
  "run_id": "control",
  "run_dir": "$tmpdir/run/control",
  "start": "2025-12-05",
  "end": "2026-02-13",
  "mode": "benchmark",
  "primary_model": "gpt-5.5",
  "experiment": {
    "run_class": "anchor_control",
    "prompt_sha256": "$control_prompt_sha",
    "prompt_path": "$control_prompt",
    "prompt_equality": {
      "available": true,
      "retained_prompt_sha256": "$control_prompt_sha",
      "current_renderer_sha256": "$control_prompt_sha",
      "matches_current_renderer": true
    },
    "output_shape_policy": {"enabled": false, "policy_path": null, "policy_sha256": null, "policy_id": null}
  },
  "token_usage": {
    "source": "session.shutdown.modelMetrics",
    "input_tokens": 1000,
    "output_tokens": 6000,
    "cache_read_tokens": 0,
    "cache_write_tokens": 0,
    "reasoning_tokens": 0,
    "request_count": 5,
    "direct_provider_token_fields_present": ["inputTokens", "outputTokens", "cacheReadTokens", "cacheWriteTokens", "reasoningTokens"],
    "missing_direct_provider_token_fields": [],
    "requested_models": ["gpt-5.5"],
    "model_direct_provider_token_fields": {
      "gpt-5.5": {
        "request_count": 5,
        "direct_provider_token_fields_present": ["inputTokens", "outputTokens", "cacheReadTokens", "cacheWriteTokens", "reasoningTokens"],
        "missing_direct_provider_token_fields": []
      }
    }
  },
  "quality": {
    "strict_pass": true,
    "newsletter_pass": true,
    "rubric_pass": true,
    "strict_warning_count": 0,
    "newsletter_warning_count": 0,
    "warning_taxonomy_classes": []
  },
  "cost_estimate": {"total_usd": 10, "unpriced_models": []}
}
JSON

cat > "$tmpdir/run/variant/run-scorecard.json" <<JSON
{
  "run_id": "variant",
  "run_dir": "$tmpdir/run/variant",
  "start": "2025-12-05",
  "end": "2026-02-13",
  "mode": "benchmark",
  "primary_model": "gpt-5.5",
  "experiment": {
    "run_class": "output_shape_candidate",
    "prompt_sha256": "$variant_prompt_sha",
    "prompt_path": "$variant_prompt",
    "prompt_equality": {
      "available": true,
      "retained_prompt_sha256": "$variant_prompt_sha",
      "current_renderer_sha256": "$variant_prompt_sha",
      "matches_current_renderer": true
    },
    "output_shape_policy": {"enabled": true, "policy_path": "$policy", "policy_sha256": "$policy_sha", "policy_id": "burst22-output-shape-v1"}
  },
  "token_usage": {
    "source": "session.shutdown.modelMetrics",
    "input_tokens": 950,
    "output_tokens": 5200,
    "cache_read_tokens": 0,
    "cache_write_tokens": 0,
    "reasoning_tokens": 0,
    "request_count": 5,
    "direct_provider_token_fields_present": ["inputTokens", "outputTokens", "cacheReadTokens", "cacheWriteTokens", "reasoningTokens"],
    "missing_direct_provider_token_fields": [],
    "requested_models": ["gpt-5.5"],
    "model_direct_provider_token_fields": {
      "gpt-5.5": {
        "request_count": 5,
        "direct_provider_token_fields_present": ["inputTokens", "outputTokens", "cacheReadTokens", "cacheWriteTokens", "reasoningTokens"],
        "missing_direct_provider_token_fields": []
      }
    }
  },
  "quality": {
    "strict_pass": true,
    "newsletter_pass": true,
    "rubric_pass": true,
    "strict_warning_count": 0,
    "newsletter_warning_count": 0,
    "warning_taxonomy_classes": []
  },
  "cost_estimate": {"total_usd": 8, "unpriced_models": []}
}
JSON

python3 tools/build_output_shape_experiment_receipt.py \
  --control-scorecard "$tmpdir/run/control/run-scorecard.json" \
  --variant-scorecard "$tmpdir/run/variant/run-scorecard.json" \
  --output "$tmpdir/output-shape-comparison.json" \
  >/dev/null

python3 - "$tmpdir/output-shape-comparison.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["pair_pass"] is not True:
    raise SystemExit(f"expected output-shape comparison to pass: {payload['checks']}")
if payload["deltas"]["output_tokens"] != 800:
    raise SystemExit("expected output-token delta")
if payload["checks"]["live_output_tokens_reduction_at_least_10_percent"] is not True:
    raise SystemExit("expected 10 percent output-token reduction check")
if payload["checks"]["live_output_tokens_reduction_at_least_500"] is not True:
    raise SystemExit("expected 500 output-token reduction check")
if payload["policy_admission"]["materiality_pass"] is not True:
    raise SystemExit("expected output-shape policy materiality admission")
if payload["checks"]["total_direct_provider_tokens_lower"] is not True:
    raise SystemExit("expected total direct provider tokens to be lower")
if payload["checks"]["api_equivalent_cost_not_higher"] is not True:
    raise SystemExit("expected API-equivalent cost to be not higher")
if payload["checks"]["control_output_shape_artifacts_absent"] is not True:
    raise SystemExit("expected control artifact absence")
PY

if ! python3 tools/build_scorecard_telemetry_receipt.py \
  --scorecard "$tmpdir/run/control/run-scorecard.json" \
  --scorecard "$tmpdir/run/variant/run-scorecard.json" \
  --output "$tmpdir/output-shape-telemetry-receipt.json" \
  >/dev/null; then
  python3 -m json.tool "$tmpdir/output-shape-telemetry-receipt.json" >&2 || true
  exit 1
fi

python3 - "$tmpdir/output-shape-telemetry-receipt.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["pass"] is not True:
    raise SystemExit(f"expected output-shape scorecard telemetry to pass: {payload}")
PY

mkdir -p "$tmpdir/run/control/artifacts/workspace"
printf 'stale control shape context\n' > "$tmpdir/run/control/artifacts/workspace/newsletter_output_shape_context_2026-02-13.md"
if python3 tools/build_output_shape_experiment_receipt.py \
  --control-scorecard "$tmpdir/run/control/run-scorecard.json" \
  --variant-scorecard "$tmpdir/run/variant/run-scorecard.json" \
  --output "$tmpdir/output-shape-stale-control.json" >/dev/null 2>&1; then
  echo "ASSERTION FAILED: stale control output-shape artifacts must fail comparison"
  exit 1
fi

rm -f "$tmpdir/run/variant/artifacts/workspace/newsletter_output_shape_receipt_2026-02-13.json"
if python3 tools/build_output_shape_experiment_receipt.py \
  --control-scorecard "$tmpdir/run/control/run-scorecard.json" \
  --variant-scorecard "$tmpdir/run/variant/run-scorecard.json" \
  --output "$tmpdir/output-shape-missing-receipt.json" >/dev/null 2>&1; then
  echo "ASSERTION FAILED: missing variant receipt must fail comparison"
  exit 1
fi
python3 - "$tmpdir/output-shape-missing-receipt.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["checks"]["output_shape_receipt_present"] is not False:
    raise SystemExit("expected missing receipt to be recorded")
if payload["output_shape_receipt_sha256"] is not None:
    raise SystemExit("missing receipt must not have a sha")
PY

echo "PASS: output-shape experiment tests passed"

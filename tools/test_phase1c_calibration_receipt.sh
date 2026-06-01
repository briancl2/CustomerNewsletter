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

failed_run="runs/product_runs/20260501T024928Z_benchmark_proof"
passing_prod_a="runs/product_runs/20260430T115004Z_production_proof"
passing_prod_b="runs/product_runs/20260430T165856Z_production_proof"
passing_benchmark="runs/product_runs/20260430T163723Z_benchmark_proof"
fresh_false_stop="runs/product_runs/20260504T143053Z_production_orchestrated_proof"
failed_scorecard="planning/phase-boundary-pricing-burst-09-2026-05-04/failed-retained-scorecard.json"
passing_prod_a_scorecard="planning/phase-token-telemetry-burst-08-2026-05-04/passing-20260430T115004Z-scorecard.json"
passing_prod_b_scorecard="planning/phase-token-telemetry-burst-08-2026-05-04/passing-20260430T165856Z-scorecard.json"
passing_benchmark_scorecard="planning/phase-token-telemetry-burst-08-2026-05-04/passing-20260430T163723Z-scorecard.json"

for run in "$failed_run" "$passing_prod_a" "$passing_prod_b" "$passing_benchmark" "$fresh_false_stop"; do
  require_tracked_path "$run/run-metadata.json"
  require_tracked_path "$run/run-scorecard.json"
  require_tracked_path "$run/audit/RUN_AUDIT.json"
done
for scorecard in "$failed_scorecard" "$passing_prod_a_scorecard" "$passing_prod_b_scorecard" "$passing_benchmark_scorecard"; do
  require_tracked_path "$scorecard"
done

generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > "$tmpdir/pricing.json" <<JSON
{
  "generated_at": "$generated_at",
  "models": [
    {
      "provider": "openai",
      "model": "gpt-5.5",
      "aliases": ["copilot/gpt-5.5"],
      "price_basis": "per_1m_tokens",
      "input_price": 5.0,
      "output_price": 30.0,
      "cache_price": {"read": 0.5, "write": 0.5},
      "reasoning_price": 30.0
    }
  ]
}
JSON

python3 -m py_compile tools/build_phase1c_calibration_receipt.py
python3 -m py_compile tools/build_phase1c_positive_control_probe.py

python3 tools/build_phase1c_calibration_receipt.py \
  --known-stop "$failed_run" \
  --no-stop "$passing_prod_a" \
  --no-stop "$passing_prod_b" \
  --no-stop "$passing_benchmark" \
  --fresh-no-stop "$fresh_false_stop" \
  --scorecard "$failed_run" "$failed_scorecard" \
  --scorecard "$passing_prod_a" "$passing_prod_a_scorecard" \
  --scorecard "$passing_prod_b" "$passing_prod_b_scorecard" \
  --scorecard "$passing_benchmark" "$passing_benchmark_scorecard" \
  --pricing-snapshot "$tmpdir/pricing.json" \
  --min-fresh-no-stop-count 1 \
  --min-model-window-combinations 1 \
  --output "$tmpdir/phase1c-calibration.json" >/dev/null

python3 - "$tmpdir/phase1c-calibration.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["receipt_type"] != "newsletter_phase1c_calibration":
    raise SystemExit("unexpected receipt type")
if payload["pass"] is not True:
    raise SystemExit("expected complete calibration set")
if payload["calibration_set"]["known_no_stop_count"] != 4:
    raise SystemExit("expected four no-stop controls")
if payload["calibration_set"]["fresh_known_no_stop_count"] != 1:
    raise SystemExit("expected one fresh no-stop control")
if payload["fresh_no_stop_run_ids"] != ["20260504T143053Z_production_orchestrated_proof"]:
    raise SystemExit("expected fresh no-stop run id")
if payload["calibration_set"]["model_window_combination_count"] < 2:
    raise SystemExit("expected at least two model/window combinations")
if payload["calibration_set"]["fresh_model_window_combination_count"] < 1:
    raise SystemExit("expected at least one fresh model/window combination")
if payload["confusion_matrix"]["true_positive"] != 1:
    raise SystemExit("expected failed run to be a true positive")
if payload["confusion_matrix"]["false_positive"] < 1:
    raise SystemExit("expected fresh Burst-09 row to remain a false positive")
if payload["confusion_matrix"]["gate_meets_target"] is not False:
    raise SystemExit("expected current gate to be blocked by false positive")
if "20260504T143053Z_production_orchestrated_proof" not in payload["false_positive_run_ids"]:
    raise SystemExit("expected Burst-09 fresh production row in false-positive list")
if payload["pricing_snapshot"]["fresh"] is not True:
    raise SystemExit("expected pricing snapshot to be fresh")
if payload["confidence_interval_method"] != "wilson_score_95":
    raise SystemExit("expected Wilson confidence interval method")
if "true_positive_rate_interval" not in payload["confusion_matrix"]:
    raise SystemExit("expected confidence intervals in confusion matrix")
candidate = payload["holdout_safe_evaluation"]["combined_diagnostic"]["evidence_only_candidate_gate"]
if candidate["false_positive"] != 0:
    raise SystemExit("expected candidate gate to clear the known false-positive rows")
if payload["candidate_gate_repair"]["production_policy_adoption"] is not False:
    raise SystemExit("candidate repair must remain evidence-only")
PY

if python3 tools/build_phase1c_calibration_receipt.py \
  --tuning-known-stop "$failed_run" \
  --tuning-no-stop "$passing_prod_a" \
  --tuning-no-stop "$passing_prod_b" \
  --holdout-no-stop "$passing_benchmark" \
  --fresh-post-repair-acceptance "$fresh_false_stop" \
  --scorecard "$failed_run" "$failed_scorecard" \
  --scorecard "$passing_prod_a" "$passing_prod_a_scorecard" \
  --scorecard "$passing_prod_b" "$passing_prod_b_scorecard" \
  --scorecard "$passing_benchmark" "$passing_benchmark_scorecard" \
  --pricing-snapshot "$tmpdir/pricing.json" \
  --min-known-stop-count 3 \
  --min-no-stop-count 4 \
  --min-fresh-post-repair-acceptance-count 1 \
  --min-model-window-combinations 1 \
  --require-fresh-pricing \
  --require-prompt-equality \
  --require-direct-provider-token-fields \
  --output "$tmpdir/phase1c-holdout-insufficient-positive.json" >/dev/null; then
  echo "expected positive-class insufficiency to exit non-zero" >&2
  exit 1
fi

python3 - "$tmpdir/phase1c-holdout-insufficient-positive.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["candidate_gate_repair"]["status"] != "candidate_blocked_positive_class_insufficient":
    raise SystemExit("expected candidate to be blocked by positive-class insufficiency")
if payload["calibration_set"]["known_stop_count"] != 1:
    raise SystemExit("expected one known-stop positive")
if payload["target"]["min_known_stop_count"] != 3:
    raise SystemExit("expected min known-stop target to be retained")
if payload["pass"] is not False:
    raise SystemExit("expected pass=false when known-stop target is unmet")
PY

python3 tools/build_phase1c_positive_control_probe.py \
  --source-run "$failed_run" \
  --source-scorecard "$failed_scorecard" \
  --output-dir "$tmpdir/positive-control-probe" \
  --output "$tmpdir/positive-control-probe/positive-control-probe-receipt.json" >/dev/null

python3 - "$tmpdir/positive-control-probe/positive-control-probe-receipt.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["pass"] is not True:
    raise SystemExit("expected positive-control probe to pass")
if payload["positive_control_count"] != 2:
    raise SystemExit("expected two positive-control fixtures")
for row in payload["positive_controls"]:
    if row["phase1c_available_only"] is not True:
        raise SystemExit("expected Phase-1C-available positive-control evidence")
    if row["observed_phase1c_stop"] is not True:
        raise SystemExit("expected strict Phase 1C stop")
    if row["candidate_observed_phase1c_stop"] is not True:
        raise SystemExit("expected candidate Phase 1C stop")
    if row["adoption_grade"] is not False:
        raise SystemExit("fixtures must not be adoption-grade controls")
    if row.get("phase3_artifacts_copied_for_legacy_evaluator_binding_only") is not True:
        raise SystemExit("expected Phase 3 artifacts to be binding-only support")
PY

fixture_a="$tmpdir/positive-control-probe/positive-control-runs/phase1c_positive_control_low_continuity"
fixture_b="$tmpdir/positive-control-probe/positive-control-runs/phase1c_positive_control_severe_version_loss"

python3 tools/build_phase1c_calibration_receipt.py \
  --known-stop "$failed_run" \
  --positive-control-known-stop "$fixture_a" \
  --positive-control-known-stop "$fixture_b" \
  --no-stop "$passing_prod_a" \
  --no-stop "$passing_prod_b" \
  --no-stop "$passing_benchmark" \
  --fresh-post-repair-acceptance "$fresh_false_stop" \
  --scorecard "$failed_run" "$failed_scorecard" \
  --scorecard "$passing_prod_a" "$passing_prod_a_scorecard" \
  --scorecard "$passing_prod_b" "$passing_prod_b_scorecard" \
  --scorecard "$passing_benchmark" "$passing_benchmark_scorecard" \
  --pricing-snapshot "$tmpdir/pricing.json" \
  --min-known-stop-count 3 \
  --min-no-stop-count 4 \
  --min-fresh-post-repair-acceptance-count 1 \
  --min-model-window-combinations 1 \
  --require-fresh-pricing \
  --require-direct-provider-token-fields \
  --output "$tmpdir/positive-control-calibration.json" >/dev/null

python3 - "$tmpdir/positive-control-calibration.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["pass"] is not True:
    raise SystemExit("expected positive-control calibration data acquisition to pass")
if payload["receipt_result"] != "calibration_complete_positive_control_probe_non_adoption_grade":
    raise SystemExit("expected non-adoption-grade positive-control receipt result")
if payload["calibration_set"]["known_stop_count"] != 3:
    raise SystemExit("expected three known-stop rows including fixtures")
if payload["calibration_set"]["positive_control_known_stop_count"] != 2:
    raise SystemExit("expected two positive-control known stops")
if payload["calibration_set"]["adoption_grade_known_stop_count"] != 1:
    raise SystemExit("expected only one adoption-grade known stop")
if payload["calibration_set"]["known_stop_positive_class_sufficient_for_adoption"] is not False:
    raise SystemExit("fixtures must not satisfy adoption-grade known-stop sufficiency")
if payload["candidate_gate_repair"]["status"] != "candidate_positive_control_probe_only_corroboration_required":
    raise SystemExit("expected candidate to require fresh or non-synthetic corroboration")
if payload["candidate_gate_repair"]["preregistered_wilson_target_met"] is not False:
    raise SystemExit("expected small fixture test set to stay below preregistered Wilson threshold")
if "preregistered_candidate_gate_wilson_thresholds" not in payload["target"]:
    raise SystemExit("expected preregistered Wilson thresholds in target")
if payload["positive_control_adoption_boundary"]["corroboration_required"] is not True:
    raise SystemExit("expected positive-control corroboration boundary")
if len(payload["positive_control_run_ids"]) != 2:
    raise SystemExit("expected two positive-control run ids")
if payload["target"]["min_model_window_combinations"] != 1:
    raise SystemExit("expected total model/window combination target")
if payload["target"]["min_fresh_model_window_combinations"] != 0:
    raise SystemExit("expected default fresh model/window combination target")
for row in payload["runs"]:
    if row.get("synthetic_positive_control") is True:
        if row["direct_provider_token_fields_present"] != []:
            raise SystemExit("synthetic fixtures must not inherit direct token fields")
        if row["missing_direct_provider_token_fields"] != [
            "inputTokens",
            "outputTokens",
            "cacheReadTokens",
            "cacheWriteTokens",
            "reasoningTokens",
        ]:
            raise SystemExit("synthetic fixtures should report missing direct token fields")
PY

python3 - "$fixture_a" "$fixture_b" <<'PY'
import json
import sys
from pathlib import Path

for raw in sys.argv[1:]:
    run_dir = Path(raw)
    receipts = json.loads(
        (run_dir / "artifacts" / "workspace" / "newsletter_phase_receipts_2026-02-13.json")
        .read_text(encoding="utf-8")
    )
    if receipts["run_id"] != run_dir.name:
        raise SystemExit("expected fixture-specific receipt run_id")
PY

stale_generated_at="2026-01-01T00:00:00Z"
cat > "$tmpdir/stale-pricing.json" <<JSON
{
  "generated_at": "$stale_generated_at",
  "models": [
    {
      "provider": "openai",
      "model": "gpt-5.5",
      "aliases": ["copilot/gpt-5.5"],
      "price_basis": "per_1m_tokens",
      "input_price": 5.0,
      "output_price": 30.0,
      "cache_price": {"read": 0.5, "write": 0.5},
      "reasoning_price": 30.0
    }
  ]
}
JSON

if python3 tools/build_phase1c_calibration_receipt.py \
  --known-stop "$failed_run" \
  --no-stop "$passing_prod_a" \
  --no-stop "$passing_prod_b" \
  --no-stop "$passing_benchmark" \
  --scorecard "$failed_run" "$failed_scorecard" \
  --scorecard "$passing_prod_a" "$passing_prod_a_scorecard" \
  --scorecard "$passing_prod_b" "$passing_prod_b_scorecard" \
  --scorecard "$passing_benchmark" "$passing_benchmark_scorecard" \
  --pricing-snapshot "$tmpdir/stale-pricing.json" \
  --require-fresh-pricing \
  --min-model-window-combinations 1 \
  --output "$tmpdir/stale-pricing-calibration.json" >/dev/null; then
  echo "expected stale pricing to fail when fresh pricing is required" >&2
  exit 1
fi

python3 - "$tmpdir/stale-pricing-calibration.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["pricing_snapshot"]["fresh"] is not False:
    raise SystemExit("expected stale pricing to be marked not fresh")
if payload["pass"] is not False:
    raise SystemExit("expected pass=false for stale pricing when required")
PY

if python3 tools/build_phase1c_calibration_receipt.py \
  --known-stop "$failed_run" \
  --no-stop "$passing_prod_a" \
  --scorecard "$failed_run" "$failed_scorecard" \
  --scorecard "$passing_prod_a" "$passing_prod_a_scorecard" \
  --pricing-snapshot "$tmpdir/pricing.json" \
  --output "$tmpdir/incomplete-calibration.json" >/dev/null; then
  echo "expected incomplete calibration set to exit non-zero" >&2
  exit 1
fi

python3 - "$tmpdir/incomplete-calibration.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["pass"] is not False:
    raise SystemExit("expected incomplete receipt pass=false")
if payload["receipt_result"] != "incomplete_calibration_set":
    raise SystemExit("expected incomplete calibration-set result")
PY

echo "PASS: Phase 1C calibration receipt tests passed"

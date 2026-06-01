#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

python3 - "$tmpdir" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])


def write_receipt(path, *, control_total, candidate_total, request_delta, complete=True):
    checks = {
        "base_pair_comparable": complete,
        "policy_declares_closed_bundle": complete,
        "pruning_receipt_declares_closed_bundle": complete,
        "prompt_boundary_bound": complete,
        "control_prompt_state_disabled": complete,
        "candidate_prompt_state_enabled": complete,
        "candidate_prompt_apply_policy_command_present": complete,
        "candidate_prompt_context_artifact_reference_present": complete,
    }
    pair_checks = {
        "same_mode": True,
        "same_date_range": True,
        "same_primary_model": True,
        "control_prompt_equality_pass": True,
        "pruned_prompt_equality_pass": True,
        "control_direct_token_fields_pass": True,
        "pruned_direct_token_fields_pass": True,
        "control_quality_pass": True,
        "pruned_quality_pass": True,
        "control_pricing_pass": True,
        "pruned_pricing_pass": True,
        "control_source_pruning_artifacts_absent": True,
        "pruned_source_pruning_artifacts_complete": True,
        "policy_hash_bound": True,
        "control_session_trace_qualified": True,
        "pruned_session_trace_qualified": True,
        "no_new_warning_taxonomy": True,
    }
    payload = {
        "schema_version": 1,
        "classification": "qualified_closed_bundle_source_pruning_signal",
        "checks": checks,
        "pair": {
            "pair_name": path.stem,
            "mode": "benchmark",
            "primary_model": "gpt-5.5",
            "control_run_id": f"{path.stem}_control",
            "pruned_run_id": f"{path.stem}_candidate",
            "checks": pair_checks,
            "control": {
                "tokens": {
                    "input_tokens": control_total,
                    "output_tokens": 0,
                    "cache_read_tokens": 0,
                    "cache_write_tokens": 0,
                    "reasoning_tokens": 0,
                }
            },
            "pruned": {
                "tokens": {
                    "input_tokens": candidate_total,
                    "output_tokens": 0,
                    "cache_read_tokens": 0,
                    "cache_write_tokens": 0,
                    "reasoning_tokens": 0,
                }
            },
            "deltas": {
                "request_count_control_minus_pruned": request_delta,
                "api_equivalent_usd_control_minus_pruned": (control_total - candidate_total) / 1000,
            },
        },
    }
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


write_receipt(root / "prior_negative.json", control_total=1000, candidate_total=2000, request_delta=-1)
write_receipt(root / "fresh_negative_1.json", control_total=1000, candidate_total=2500, request_delta=-2)
write_receipt(root / "fresh_negative_2.json", control_total=1000, candidate_total=1500, request_delta=0)
write_receipt(root / "prior_positive.json", control_total=1000, candidate_total=800, request_delta=0)
write_receipt(root / "fresh_positive_1.json", control_total=1000, candidate_total=850, request_delta=1)
write_receipt(root / "fresh_positive_2.json", control_total=1000, candidate_total=900, request_delta=0)
write_receipt(root / "fresh_incomplete.json", control_total=1000, candidate_total=800, request_delta=0, complete=False)
write_receipt(root / "fresh_zero_total.json", control_total=0, candidate_total=0, request_delta=0)
write_receipt(root / "fresh_missing_request.json", control_total=1000, candidate_total=800, request_delta=None)
write_receipt(root / "fresh_request_regression.json", control_total=1000, candidate_total=800, request_delta=-1)
write_receipt(root / "fresh_flat.json", control_total=1000, candidate_total=1000, request_delta=0)
write_receipt(root / "prior_flat.json", control_total=1000, candidate_total=1000, request_delta=0)
write_receipt(root / "fresh_flat_2.json", control_total=1000, candidate_total=1000, request_delta=0)
write_receipt(root / "prior_zero_control_amplification.json", control_total=0, candidate_total=1000, request_delta=0)
write_receipt(root / "fresh_zero_control_amplification_1.json", control_total=0, candidate_total=500, request_delta=0)
write_receipt(root / "fresh_zero_control_amplification_2.json", control_total=0, candidate_total=700, request_delta=0)

missing_fields = root / "fresh_missing_direct_fields.json"
write_receipt(missing_fields, control_total=1000, candidate_total=800, request_delta=0)
payload = json.loads(missing_fields.read_text())
payload["pair"]["checks"]["pruned_direct_token_fields_pass"] = False
payload["pair"]["pruned"]["tokens"].pop("output_tokens")
missing_fields.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

bad_binding = root / "fresh_negative_bad_binding.json"
write_receipt(bad_binding, control_total=1000, candidate_total=2000, request_delta=-1)
payload = json.loads(bad_binding.read_text())
payload["pair"]["checks"]["policy_hash_bound"] = False
bad_binding.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

logical_duplicate = root / "fresh_positive_1_logical_duplicate.json"
payload = json.loads((root / "fresh_positive_1.json").read_text())
payload["classification"] = "same_logical_pair_different_bytes"
logical_duplicate.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

if python3 tools/build_closed_bundle_source_pruning_replication_receipt.py \
  --prior-pair-receipt "$tmpdir/prior_negative.json" \
  --fresh-pair-receipt "$tmpdir/fresh_negative_1.json" \
  --fresh-pair-receipt "$tmpdir/fresh_negative_2.json" \
  --output "$tmpdir/negative-aggregate.json" >/dev/null; then
  echo "ASSERTION FAILED: repeated negative aggregate should not pass"
  exit 1
fi

python3 - "$tmpdir/negative-aggregate.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1]))
if data["result"] != "fail_closed_repeated_closed_bundle_amplification":
    raise SystemExit(data["result"])
if data["counts"]["evidence_complete_pairs"] != 3:
    raise SystemExit(data["counts"])
if data["counts"]["prior_evidence_complete_pairs"] != 1:
    raise SystemExit(data["counts"])
if data["counts"]["metrics_complete_pairs"] != 3:
    raise SystemExit(data["counts"])
PY

if python3 tools/build_closed_bundle_source_pruning_replication_receipt.py \
  --prior-pair-receipt "$tmpdir/prior_negative.json" \
  --fresh-pair-receipt "$tmpdir/fresh_negative_1.json" \
  --fresh-pair-receipt "$tmpdir/fresh_negative_bad_binding.json" \
  --output "$tmpdir/metrics-amplification-incomplete-evidence.json" >/dev/null; then
  echo "ASSERTION FAILED: metrics-complete repeated amplification with incomplete binding should not pass"
  exit 1
fi

python3 - "$tmpdir/metrics-amplification-incomplete-evidence.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1]))
if data["result"] != "fail_closed_repeated_closed_bundle_amplification_incomplete_evidence":
    raise SystemExit(data["result"])
if data["counts"]["metrics_complete_pairs"] != 3:
    raise SystemExit(data["counts"])
if data["counts"]["evidence_complete_pairs"] != 2:
    raise SystemExit(data["counts"])
PY

python3 tools/build_closed_bundle_source_pruning_replication_receipt.py \
  --prior-pair-receipt "$tmpdir/prior_positive.json" \
  --fresh-pair-receipt "$tmpdir/fresh_positive_1.json" \
  --fresh-pair-receipt "$tmpdir/fresh_positive_2.json" \
  --output "$tmpdir/positive-aggregate.json" >/dev/null

python3 - "$tmpdir/positive-aggregate.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1]))
if data["result"] != "qualified_closed_bundle_positive_signal":
    raise SystemExit(data["result"])
if data["counts"]["positive_pairs"] != 3:
    raise SystemExit(data["counts"])
if data["checks"]["all_evidence_complete_pairs_positive"] is not True:
    raise SystemExit(data["checks"])
PY

if python3 tools/build_closed_bundle_source_pruning_replication_receipt.py \
  --prior-pair-receipt "$tmpdir/prior_positive.json" \
  --fresh-pair-receipt "$tmpdir/fresh_positive_1.json" \
  --fresh-pair-receipt "$tmpdir/fresh_request_regression.json" \
  --output "$tmpdir/median-positive-with-regression.json" >/dev/null; then
  echo "ASSERTION FAILED: aggregate with a regressing evidence pair should not pass"
  exit 1
fi

python3 - "$tmpdir/median-positive-with-regression.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1]))
if data["result"] != "partial_mixed_closed_bundle_evidence":
    raise SystemExit(data["result"])
if data["checks"]["median_total_direct_token_reduction_met"] is not True:
    raise SystemExit(data["checks"])
if data["checks"]["median_request_count_not_higher"] is not True:
    raise SystemExit(data["checks"])
if data["checks"]["all_evidence_complete_pairs_positive"] is not False:
    raise SystemExit(data["checks"])
PY

if python3 tools/build_closed_bundle_source_pruning_replication_receipt.py \
  --prior-pair-receipt "$tmpdir/prior_flat.json" \
  --fresh-pair-receipt "$tmpdir/fresh_flat.json" \
  --fresh-pair-receipt "$tmpdir/fresh_flat_2.json" \
  --output "$tmpdir/no-positive-no-amplification.json" >/dev/null; then
  echo "ASSERTION FAILED: no-positive/no-amplification aggregate should not pass"
  exit 1
fi

python3 - "$tmpdir/no-positive-no-amplification.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1]))
if data["result"] != "fail_closed_no_signal_flat_evidence":
    raise SystemExit(data["result"])
if data["counts"]["positive_pairs"] != 0:
    raise SystemExit(data["counts"])
if data["counts"]["amplification_pairs"] != 0:
    raise SystemExit(data["counts"])
PY

if python3 tools/build_closed_bundle_source_pruning_replication_receipt.py \
  --prior-pair-receipt "$tmpdir/prior_zero_control_amplification.json" \
  --fresh-pair-receipt "$tmpdir/fresh_zero_control_amplification_1.json" \
  --fresh-pair-receipt "$tmpdir/fresh_zero_control_amplification_2.json" \
  --output "$tmpdir/zero-control-amplification.json" >/dev/null; then
  echo "ASSERTION FAILED: zero-control amplification should not pass"
  exit 1
fi

python3 - "$tmpdir/zero-control-amplification.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1]))
if data["result"] != "fail_closed_repeated_closed_bundle_amplification_incomplete_evidence":
    raise SystemExit(data["result"])
if data["counts"]["amplification_signal_complete_pairs"] != 3:
    raise SystemExit(data["counts"])
if any(pair["amplification_signal_pair"] is not True for pair in data["pairs"]):
    raise SystemExit(data["pairs"])
PY

if python3 tools/build_closed_bundle_source_pruning_replication_receipt.py \
  --prior-pair-receipt "$tmpdir/prior_positive.json" \
  --fresh-pair-receipt "$tmpdir/fresh_positive_1.json" \
  --fresh-pair-receipt "$tmpdir/fresh_flat.json" \
  --output "$tmpdir/mixed-aggregate.json" >/dev/null; then
  echo "ASSERTION FAILED: mixed aggregate should not pass"
  exit 1
fi

python3 - "$tmpdir/mixed-aggregate.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1]))
if data["result"] != "partial_mixed_closed_bundle_evidence":
    raise SystemExit(data["result"])
if data["counts"]["positive_pairs"] != 2:
    raise SystemExit(data["counts"])
PY

if python3 tools/build_closed_bundle_source_pruning_replication_receipt.py \
  --prior-pair-receipt "$tmpdir/prior_positive.json" \
  --fresh-pair-receipt "$tmpdir/fresh_incomplete.json" \
  --output "$tmpdir/incomplete-aggregate.json" >/dev/null; then
  echo "ASSERTION FAILED: incomplete aggregate should not pass"
  exit 1
fi

python3 - "$tmpdir/incomplete-aggregate.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1]))
if data["result"] != "blocked_insufficient_evidence_complete_pairs":
    raise SystemExit(data["result"])
PY

if python3 tools/build_closed_bundle_source_pruning_replication_receipt.py \
  --fresh-pair-receipt "$tmpdir/fresh_positive_1.json" \
  --fresh-pair-receipt "$tmpdir/fresh_positive_2.json" \
  --fresh-pair-receipt "$tmpdir/fresh_positive_1.json" \
  --output "$tmpdir/no-prior-aggregate.json" >/dev/null; then
  echo "ASSERTION FAILED: aggregate without a prior pair should not pass"
  exit 1
fi

python3 - "$tmpdir/no-prior-aggregate.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1]))
if data["checks"]["min_prior_evidence_complete_pairs_met"] is not False:
    raise SystemExit(data["checks"])
PY

if python3 tools/build_closed_bundle_source_pruning_replication_receipt.py \
  --prior-pair-receipt "$tmpdir/prior_positive.json" \
  --fresh-pair-receipt "$tmpdir/fresh_positive_1.json" \
  --fresh-pair-receipt "$tmpdir/fresh_positive_1.json" \
  --output "$tmpdir/duplicate-fresh-aggregate.json" >/dev/null; then
  echo "ASSERTION FAILED: duplicate fresh receipt should not satisfy fresh floor"
  exit 1
fi

python3 - "$tmpdir/duplicate-fresh-aggregate.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1]))
if data["counts"]["duplicate_pair_receipts"] != 1:
    raise SystemExit(data["counts"])
if data["counts"]["fresh_evidence_complete_pairs"] != 1:
    raise SystemExit(data["counts"])
if data["checks"]["no_duplicate_pair_inputs"] is not False:
    raise SystemExit(data["checks"])
PY

if python3 tools/build_closed_bundle_source_pruning_replication_receipt.py \
  --prior-pair-receipt "$tmpdir/prior_positive.json" \
  --fresh-pair-receipt "$tmpdir/fresh_positive_1.json" \
  --fresh-pair-receipt "$tmpdir/fresh_positive_1_logical_duplicate.json" \
  --output "$tmpdir/logical-duplicate-fresh-aggregate.json" >/dev/null; then
  echo "ASSERTION FAILED: logical duplicate fresh receipt should not satisfy fresh floor"
  exit 1
fi

python3 - "$tmpdir/logical-duplicate-fresh-aggregate.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1]))
if data["counts"]["duplicate_pair_receipts"] != 1:
    raise SystemExit(data["counts"])
if data["duplicate_pair_inputs"][0]["path"].endswith("fresh_positive_1_logical_duplicate.json") is not True:
    raise SystemExit(data["duplicate_pair_inputs"])
if data["checks"]["no_duplicate_pair_inputs"] is not False:
    raise SystemExit(data["checks"])
PY

if python3 tools/build_closed_bundle_source_pruning_replication_receipt.py \
  --prior-pair-receipt "$tmpdir/prior_positive.json" \
  --fresh-pair-receipt "$tmpdir/fresh_zero_total.json" \
  --fresh-pair-receipt "$tmpdir/fresh_missing_request.json" \
  --output "$tmpdir/metrics-incomplete-aggregate.json" >/dev/null; then
  echo "ASSERTION FAILED: metrics-incomplete aggregate should not pass"
  exit 1
fi

python3 - "$tmpdir/metrics-incomplete-aggregate.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1]))
if data["counts"]["fresh_evidence_complete_pairs"] != 0:
    raise SystemExit(data["counts"])
PY

if python3 tools/build_closed_bundle_source_pruning_replication_receipt.py \
  --prior-pair-receipt "$tmpdir/prior_positive.json" \
  --fresh-pair-receipt "$tmpdir/fresh_missing_direct_fields.json" \
  --fresh-pair-receipt "$tmpdir/fresh_positive_2.json" \
  --output "$tmpdir/missing-direct-fields-aggregate.json" >/dev/null; then
  echo "ASSERTION FAILED: missing direct token fields should not satisfy evidence floor"
  exit 1
fi

python3 - "$tmpdir/missing-direct-fields-aggregate.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1]))
if data["counts"]["fresh_evidence_complete_pairs"] != 1:
    raise SystemExit(data["counts"])
missing = [pair for pair in data["pairs"] if pair["path"].endswith("fresh_missing_direct_fields.json")][0]
if missing["evidence_complete_pair"] is not False:
    raise SystemExit(missing)
if missing["token_values_present"]["candidate_all_direct_token_values_present"] is not False:
    raise SystemExit(missing)
PY

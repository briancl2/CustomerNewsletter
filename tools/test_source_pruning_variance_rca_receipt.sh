#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

python3 - "$tmpdir/amplification.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])


def pair(name, qualified, input_delta, cache_delta, request_delta, search_delta, uncached_delta):
    control_input = 100000
    control_cache = 80000
    control_uncached = control_input - control_cache
    pruned_input = control_input - input_delta
    pruned_cache = control_cache - cache_delta
    pruned_uncached = control_uncached - uncached_delta
    return {
        "pair_name": name,
        "classification": "qualified_mode_specific_source_pruning_signal" if qualified else "amplification_detected",
        "admitted_for_mode_specific_follow_on": qualified,
        "control_run_id": f"{name}_control",
        "pruned_run_id": f"{name}_pruned",
        "control": {"tokens": {"input_tokens": control_input, "cache_read_tokens": control_cache, "cache_write_tokens": 0}},
        "pruned": {"tokens": {"input_tokens": pruned_input, "cache_read_tokens": pruned_cache, "cache_write_tokens": 0}},
        "deltas": {
            "input_tokens_control_minus_pruned": input_delta,
            "cache_read_tokens_control_minus_pruned": cache_delta,
            "request_count_control_minus_pruned": request_delta,
            "api_equivalent_usd_control_minus_pruned": round(input_delta / 100000, 4),
            "trace_control_minus_pruned": {
                "command_category_counts": {
                    "search_or_inspection": search_delta,
                    "materialization_or_builder": 0,
                }
            },
        },
        "blockers": [] if qualified else ["input_token_amplification_detected"],
    }


payload = {
    "schema_version": 1,
    "pairs": [
        pair("winner_with_uncached_amp", True, 25000, 30000, 4, -1, -5000),
        pair("winner_clean", True, 20000, 15000, 3, 2, 5000),
        pair("loser_request_search", False, -30000, -28000, -5, -8, -2000),
        pair("loser_cache_with_uncached_savings", False, -25000, -27000, -1, -4, 2000),
    ],
}
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

python3 tools/build_source_pruning_variance_rca_receipt.py \
  --amplification-receipt "$tmpdir/amplification.json" \
  --repair-policy config/experiment_pruning_policies/burst26-source-candidate-v2.json \
  --output "$tmpdir/rca.json" >/dev/null

python3 - "$tmpdir/rca.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["pass"] is not True:
    raise SystemExit("expected RCA repair admission to pass")
if payload["result"] != "repair_candidate_admitted_for_bounded_probe":
    raise SystemExit("expected bounded probe admission result")
checks = payload["checks"]
for key in (
    "has_winning_and_losing_pairs",
    "failed_pairs_show_request_or_search_amplification",
    "failed_input_amplification_cache_read_dominated",
    "uncached_input_not_sufficient_predictor",
    "repair_policy_probe_guard_admitted",
):
    if checks.get(key) is not True:
        raise SystemExit(f"expected check to pass: {key}")
PY

cat > "$tmpdir/loose-policy.json" <<'JSON'
{
  "schema_version": 1,
  "policy_id": "loose-policy",
  "selected_context_artifacts": ["manifest"],
  "required_source_classes": ["manifest"],
  "usage_boundary_extra_rules": [
    "Broad search and Phase 1 materialization are discussed here, but this is not a prohibition."
  ]
}
JSON

if python3 tools/build_source_pruning_variance_rca_receipt.py \
  --amplification-receipt "$tmpdir/amplification.json" \
  --repair-policy "$tmpdir/loose-policy.json" \
  --output "$tmpdir/loose-policy-rca.json" >/dev/null; then
  echo "ASSERTION FAILED: loose policy wording should not admit a bounded probe"
  exit 1
fi

python3 - "$tmpdir/loose-policy-rca.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["checks"]["repair_policy_probe_guard_admitted"] is not False:
    raise SystemExit("loose wording must not satisfy the repair-policy guard")
PY

python3 - "$tmpdir/weak-cache-amplification.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])


def pair(name, input_delta, cache_delta):
    return {
        "pair_name": name,
        "classification": "amplification_detected",
        "admitted_for_mode_specific_follow_on": False,
        "control_run_id": f"{name}_control",
        "pruned_run_id": f"{name}_pruned",
        "control": {"tokens": {"input_tokens": 100000, "cache_read_tokens": 80000, "cache_write_tokens": 0}},
        "pruned": {"tokens": {"input_tokens": 100000 - input_delta, "cache_read_tokens": 80000 - cache_delta, "cache_write_tokens": 0}},
        "deltas": {
            "input_tokens_control_minus_pruned": input_delta,
            "cache_read_tokens_control_minus_pruned": cache_delta,
            "request_count_control_minus_pruned": -2,
            "trace_control_minus_pruned": {"command_category_counts": {"search_or_inspection": -2}},
        },
    }


payload = {
    "schema_version": 1,
    "pairs": [
        {
            "pair_name": "winner",
            "classification": "qualified_mode_specific_source_pruning_signal",
            "admitted_for_mode_specific_follow_on": True,
            "control_run_id": "winner_control",
            "pruned_run_id": "winner_pruned",
            "control": {"tokens": {"input_tokens": 100000, "cache_read_tokens": 80000, "cache_write_tokens": 0}},
            "pruned": {"tokens": {"input_tokens": 80000, "cache_read_tokens": 60000, "cache_write_tokens": 0}},
            "deltas": {
                "input_tokens_control_minus_pruned": 20000,
                "cache_read_tokens_control_minus_pruned": 20000,
                "request_count_control_minus_pruned": 2,
                "trace_control_minus_pruned": {"command_category_counts": {"search_or_inspection": 1}},
            },
        },
        pair("loser_cache_dominated", -30000, -28000),
        pair("loser_not_cache_dominated_1", -30000, -1000),
        pair("loser_not_cache_dominated_2", -30000, -1000),
    ],
}
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

if python3 tools/build_source_pruning_variance_rca_receipt.py \
  --amplification-receipt "$tmpdir/weak-cache-amplification.json" \
  --repair-policy config/experiment_pruning_policies/burst26-source-candidate-v2.json \
  --output "$tmpdir/weak-cache-rca.json" >/dev/null; then
  echo "ASSERTION FAILED: one cache-dominated failed row out of three must not admit repair"
  exit 1
fi

python3 - "$tmpdir/weak-cache-rca.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["checks"]["failed_input_amplification_cache_read_dominated"] is not False:
    raise SystemExit("expected strict cache-dominance majority check to fail")
PY

if python3 tools/build_source_pruning_variance_rca_receipt.py \
  --amplification-receipt "$tmpdir/amplification.json" \
  --output "$tmpdir/no-policy.json" >/dev/null; then
  echo "ASSERTION FAILED: missing repair policy should fail closed"
  exit 1
fi

python3 - "$tmpdir/no-policy.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["result"] != "fail_closed_repair_policy_not_admitted":
    raise SystemExit("expected repair-policy admission failure")
if payload["checks"]["repair_policy_probe_guard_admitted"] is not False:
    raise SystemExit("expected repair policy guard check to fail")
PY

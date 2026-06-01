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


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_session(run_dir, requests):
    rows = [
        {"type": "session.start", "data": {"sessionId": run_dir.name}},
        {"type": "tool.execution_start", "data": {"toolName": "rg", "arguments": {"pattern": "newsletter"}}},
        {
            "type": "session.shutdown",
            "data": {
                "modelMetrics": {
                    "gpt-5.5": {
                        "requests": {"count": requests},
                        "usage": {
                            "inputTokens": 1000,
                            "outputTokens": 100,
                            "cacheReadTokens": 0,
                            "cacheWriteTokens": 0,
                            "reasoningTokens": 50,
                        },
                    }
                }
            },
        },
    ]
    path = run_dir / "session" / "events.jsonl"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(json.dumps(row) for row in rows) + "\n", encoding="utf-8")


def make_run(name, run_class, input_tokens, requests, pruned=False, mode="benchmark"):
    run_dir = root / name
    (run_dir / "artifacts" / "workspace").mkdir(parents=True)
    (run_dir / "prompt.txt").write_text(
        "Benchmark newsletter prompt\n"
        + (
            "Source-pruning experiment:\n"
            "- Enabled with policy: `config/experiment_pruning_policies/burst18-source-candidate-v1.json`\n"
            "- Read `workspace/newsletter_source_pruning_context_2026-02-13.md`.\n"
            if pruned
            else "Source-pruning experiment:\n- Disabled. Use the canonical source/candidate artifacts directly.\n"
        ),
        encoding="utf-8",
    )
    copied = []
    if pruned:
        for logical in (
            "workspace/newsletter_source_pruning_context_2026-02-13.md",
            "workspace/newsletter_source_pruning_receipt_2026-02-13.json",
        ):
            target = run_dir / "artifacts" / logical
            if target.suffix == ".json":
                write_json(target, {"policy_sha256": "policy-hash", "admission": {"pass": True}})
            else:
                target.write_text("compact benchmark source context\n", encoding="utf-8")
            copied.append({"logical_path": logical, "size_bytes": target.stat().st_size})
    write_json(run_dir / "artifacts" / "snapshot-manifest.json", {"copied_files": copied})
    write_session(run_dir, requests)
    token_fields = ["inputTokens", "outputTokens", "cacheReadTokens", "cacheWriteTokens", "reasoningTokens"]
    write_json(
        run_dir / "run-scorecard.json",
        {
            "schema_version": 1,
            "run_id": name,
            "run_dir": str(run_dir),
            "start": "2025-12-05",
            "end": "2026-02-13",
            "mode": mode,
            "primary_model": "gpt-5.5",
            "experiment": {
                "run_class": run_class,
                "prompt_path": str(run_dir / "prompt.txt"),
                "prompt_equality": {"available": True, "matches_current_renderer": True},
                "source_pruning_policy": (
                    {
                        "enabled": True,
                        "policy_id": "burst18-source-candidate-v1",
                        "policy_sha256": "policy-hash",
                    }
                    if pruned
                    else {"enabled": False}
                ),
            },
            "token_usage": {
                "source": "session.shutdown.modelMetrics",
                "requested_models": ["gpt-5.5"],
                "request_count": requests,
                "input_tokens": input_tokens,
                "output_tokens": 100,
                "cache_read_tokens": 0,
                "cache_write_tokens": 0,
                "reasoning_tokens": 50,
                "direct_provider_token_fields_present": token_fields,
                "missing_direct_provider_token_fields": [],
                "model_direct_provider_token_fields": {
                    "gpt-5.5": {
                        "request_count": requests,
                        "direct_provider_token_fields_present": token_fields,
                        "missing_direct_provider_token_fields": [],
                    }
                },
            },
            "cost_estimate": {"total_usd": input_tokens / 1000, "unpriced_models": []},
            "quality": {
                "strict_pass": True,
                "newsletter_pass": True,
                "rubric_pass": True,
                "warning_taxonomy_classes": [],
            },
            "artifact_completeness": {
                "optional_missing": [] if pruned else ["source_pruning_context", "source_pruning_receipt"],
                "optional_present": ["source_pruning_context", "source_pruning_receipt"] if pruned else [],
                "required_missing": [],
            },
        },
    )
    return run_dir


for idx in range(1, 6):
    make_run(f"control_{idx}", "source_pruning_control", 10000, 5)
    make_run(f"pruned_{idx}", "source_pruning_candidate", 9000 - idx, 4, pruned=True)

make_run("control_bad", "source_pruning_control", 10000, 5)
make_run("pruned_bad", "source_pruning_candidate", 30000, 8, pruned=True)
make_run("control_production", "source_pruning_control", 10000, 5, mode="production")
make_run("pruned_production", "source_pruning_candidate", 9000, 4, pruned=True, mode="production")
make_run("control_missing_id", "source_pruning_control", 10000, 5)
make_run("pruned_missing_id", "source_pruning_candidate", 9000, 4, pruned=True)
for path in root.glob("*_missing_id/run-scorecard.json"):
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["run_id"] = None
    write_json(path, payload)
PY

pairs=()
for idx in 1 2 3 4 5; do
  pairs+=(--pair "pair_${idx}:$tmpdir/control_${idx}:$tmpdir/pruned_${idx}")
done

python3 tools/build_source_pruning_variance_receipt.py \
  "${pairs[@]}" \
  --attempted-live-rows 10 \
  --output "$tmpdir/pass.json" >/dev/null

python3 - "$tmpdir/pass.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["pass"] is not True:
    raise SystemExit("expected variance receipt to pass")
if payload["qualified_pair_count"] != 5:
    raise SystemExit("expected five qualified pairs")
if payload["checks"]["median_input_reduction_met"] is not True:
    raise SystemExit("expected median input reduction check to pass")
PY

if python3 tools/build_source_pruning_variance_receipt.py \
  --pair "pair_1:$tmpdir/control_1:$tmpdir/pruned_1" \
  --attempted-live-rows 2 \
  --output "$tmpdir/fail.json" >/dev/null; then
  echo "ASSERTION FAILED: insufficient pair floor should fail"
  exit 1
fi

python3 - "$tmpdir/fail.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["result"] != "fail_closed_insufficient_qualified_pairs":
    raise SystemExit("expected insufficient-pair failure result")
if payload["checks"]["qualified_pair_floor_met"] is not False:
    raise SystemExit("expected pair floor check to fail")
PY

if python3 tools/build_source_pruning_variance_receipt.py \
  --pair "pair_1:$tmpdir/control_1:$tmpdir/pruned_1" \
  --pair "pair_bad:$tmpdir/control_bad:$tmpdir/pruned_bad" \
  --min-qualified-pairs 1 \
  --attempted-live-rows 4 \
  --output "$tmpdir/mixed.json" >/dev/null; then
  echo "ASSERTION FAILED: mixed amplification should fail all-pair variance checks"
  exit 1
fi

python3 - "$tmpdir/mixed.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["result"] != "fail_closed_source_pruning_variance_unbounded":
    raise SystemExit("expected all-pair variance failure result")
if payload["checks"]["qualified_pair_floor_met"] is not True:
    raise SystemExit("expected pair floor check to pass for mixed fixture")
if payload["checks"]["median_input_reduction_met"] is not False:
    raise SystemExit("expected all-pair median input reduction check to fail")
if payload["checks"]["median_request_count_not_amplified"] is not False:
    raise SystemExit("expected all-pair request-count median check to fail")
PY

duplicate_pairs=()
for idx in 1 2 3 4 5; do
  duplicate_pairs+=(--pair "duplicate_${idx}:$tmpdir/control_1:$tmpdir/pruned_1")
done

if python3 tools/build_source_pruning_variance_receipt.py \
  "${duplicate_pairs[@]}" \
  --attempted-live-rows 10 \
  --output "$tmpdir/duplicate.json" >/dev/null; then
  echo "ASSERTION FAILED: duplicate run evidence should fail"
  exit 1
fi

python3 - "$tmpdir/duplicate.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["result"] != "fail_closed_duplicate_pair_evidence":
    raise SystemExit("expected duplicate-pair failure result")
if payload["checks"]["control_run_ids_unique"] is not False:
    raise SystemExit("expected duplicate control run id check to fail")
if payload["checks"]["pruned_run_ids_unique"] is not False:
    raise SystemExit("expected duplicate pruned run id check to fail")
PY

if python3 tools/build_source_pruning_variance_receipt.py \
  "${pairs[@]}" \
  --attempted-live-rows 8 \
  --output "$tmpdir/underreported.json" >/dev/null; then
  echo "ASSERTION FAILED: underreported attempted rows should fail"
  exit 1
fi

python3 - "$tmpdir/underreported.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["result"] != "fail_closed_attempt_count_underreported":
    raise SystemExit("expected underreported-attempt failure result")
if payload["checks"]["attempted_live_rows_covers_pair_count"] is not False:
    raise SystemExit("expected attempted row coverage check to fail")
PY

if python3 tools/build_source_pruning_variance_receipt.py \
  --pair "production_pair:$tmpdir/control_production:$tmpdir/pruned_production" \
  --min-qualified-pairs 1 \
  --attempted-live-rows 2 \
  --output "$tmpdir/production.json" >/dev/null; then
  echo "ASSERTION FAILED: production input should fail benchmark-only receipt"
  exit 1
fi

python3 - "$tmpdir/production.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["result"] != "fail_closed_non_benchmark_input":
    raise SystemExit("expected non-benchmark failure result")
if payload["checks"]["benchmark_only"] is not False:
    raise SystemExit("expected benchmark-only check to fail")
PY

if python3 tools/build_source_pruning_variance_receipt.py \
  "${pairs[@]}" \
  --attempted-live-rows 10 \
  --max-live-row-attempts 8 \
  --output "$tmpdir/overbudget.json" >/dev/null; then
  echo "ASSERTION FAILED: over-budget attempt count should fail"
  exit 1
fi

python3 - "$tmpdir/overbudget.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["result"] != "fail_closed_attempt_budget_exceeded":
    raise SystemExit("expected attempt-budget failure result")
if payload["checks"]["attempt_budget_observed"] is not False:
    raise SystemExit("expected attempt budget check to fail")
PY

if python3 tools/build_source_pruning_variance_receipt.py \
  --pair "missing_id_pair:$tmpdir/control_missing_id:$tmpdir/pruned_missing_id" \
  --min-qualified-pairs 1 \
  --attempted-live-rows 2 \
  --output "$tmpdir/missing-id.json" >/dev/null; then
  echo "ASSERTION FAILED: missing run identifiers should fail"
  exit 1
fi

python3 - "$tmpdir/missing-id.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["result"] != "fail_closed_missing_pair_identifier":
    raise SystemExit("expected missing-identifier failure result")
if payload["checks"]["control_run_ids_present"] is not False:
    raise SystemExit("expected control run id presence check to fail")
if payload["checks"]["pruned_run_ids_present"] is not False:
    raise SystemExit("expected pruned run id presence check to fail")
PY

#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

policy="config/experiment_pruning_policies/burst27-closed-bundle-v1.json"
legacy_policy="config/experiment_pruning_policies/burst26-source-candidate-v2.json"
bench_root="runs/product_runs/20260430T163723Z_benchmark_proof/artifacts"

python3 tools/apply_newsletter_source_pruning_policy.py \
  2025-12-05 \
  2026-02-13 \
  --policy "$policy" \
  --source-root "$bench_root" \
  --output-root "$tmpdir/bench" \
  --require-admission >/dev/null

python3 - "$tmpdir/bench/workspace/newsletter_source_pruning_receipt_2026-02-13.json" "$tmpdir/bench/workspace/newsletter_source_pruning_context_2026-02-13.md" <<'PY'
import json
import sys
from pathlib import Path

receipt = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
context = Path(sys.argv[2]).read_text(encoding="utf-8")
if receipt["closed_bundle_required"] is not True:
    raise SystemExit("closed-bundle receipt must retain closed_bundle_required=true")
if receipt["admission"]["pass"] is not True:
    raise SystemExit("closed-bundle retained admission unexpectedly failed")
for needle in (
    "# Closed Source Bundle",
    "closed_bundle_missing_detail",
    "do not perform broad repo/source search expansion",
):
    if needle not in context:
        raise SystemExit(f"closed-bundle context missing boundary phrase: {needle}")
PY

bash tools/run_closed_bundle_source_pruning_proof.sh \
  2025-12-05 \
  2026-02-13 \
  benchmark \
  --policy "$policy" \
  --dry-run >/dev/null

if bash tools/run_closed_bundle_source_pruning_proof.sh \
  2025-12-05 \
  2026-02-13 \
  benchmark \
  --policy "$legacy_policy" \
  --dry-run >/dev/null 2>&1; then
  echo "ASSERTION FAILED: legacy non-closed policy should not admit through closed-bundle wrapper"
  exit 1
fi

python3 - "$tmpdir" "$policy" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
policy_path = Path(sys.argv[2]).resolve()
policy_sha = hashlib.sha256(policy_path.read_bytes()).hexdigest()


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def write_session(run_dir, requests, search_count):
    rows = [{"type": "session.start", "data": {"sessionId": run_dir.name}}]
    for idx in range(search_count):
        rows.append(
            {
                "type": "tool.execution_start",
                "data": {"toolName": "rg", "arguments": {"command": f"rg source-{idx} workspace"}},
            }
        )
    rows.append(
        {
            "type": "tool.execution_start",
            "data": {
                "toolName": "bash",
                "arguments": {"command": "python3 tools/build_phase3_working_set.py 2025-12-05 2026-02-13"},
            },
        }
    )
    rows.append(
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
        }
    )
    path = run_dir / "session" / "events.jsonl"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(json.dumps(row) for row in rows) + "\n", encoding="utf-8")


def make_run(name, input_tokens, requests, search_count, pruned=False, boundary=True, receipt_closed=True):
    run_dir = root / name
    (run_dir / "artifacts" / "workspace").mkdir(parents=True)
    prompt_lines = ["Canonical newsletter prompt"]
    if pruned:
        prompt_lines.extend(
            [
                "Source-pruning experiment:",
                "- Enabled with policy: `config/experiment_pruning_policies/burst27-closed-bundle-v1.json`",
                "Closed source bundle required: `true`" if boundary else "Closed source bundle required: `false`",
                "After the closed bundle receipt passes, do not perform broad repo/source search expansion",
                "If detail is missing, report `closed_bundle_missing_detail`.",
                "The run is invalid as a closed-bundle proof row if final drafting depends on broad search expansion.",
                "  `python3 tools/apply_newsletter_source_pruning_policy.py 2025-12-05 2026-02-13 --policy config/experiment_pruning_policies/burst27-closed-bundle-v1.json --source-root . --output-root . --require-admission`",
                "Read `workspace/newsletter_source_pruning_context_2026-02-13.md` as the closed source bundle.",
            ]
        )
    else:
        prompt_lines.extend(
            [
                "Source-pruning experiment:",
                "- Disabled. Use the canonical source/candidate artifacts directly.",
            ]
        )
    (run_dir / "prompt.txt").write_text("\n".join(prompt_lines) + "\n", encoding="utf-8")
    copied = []
    if pruned:
        context = run_dir / "artifacts" / "workspace" / "newsletter_source_pruning_context_2026-02-13.md"
        context.write_text("# Closed Source Bundle\n", encoding="utf-8")
        receipt = run_dir / "artifacts" / "workspace" / "newsletter_source_pruning_receipt_2026-02-13.json"
        write_json(
            receipt,
            {
                "policy_sha256": policy_sha,
                "closed_bundle_required": receipt_closed,
                "admission": {"pass": True},
            },
        )
        copied.extend(
            [
                {
                    "logical_path": "workspace/newsletter_source_pruning_context_2026-02-13.md",
                    "size_bytes": context.stat().st_size,
                },
                {
                    "logical_path": "workspace/newsletter_source_pruning_receipt_2026-02-13.json",
                    "size_bytes": receipt.stat().st_size,
                },
            ]
        )
    write_json(run_dir / "artifacts" / "snapshot-manifest.json", {"copied_files": copied})
    write_session(run_dir, requests, search_count)
    token_fields = [
        "inputTokens",
        "outputTokens",
        "cacheReadTokens",
        "cacheWriteTokens",
        "reasoningTokens",
    ]
    write_json(
        run_dir / "run-scorecard.json",
        {
            "schema_version": 1,
            "run_id": name,
            "run_dir": str(run_dir),
            "start": "2025-12-05",
            "end": "2026-02-13",
            "mode": "benchmark",
            "primary_model": "gpt-5.5",
            "experiment": {
                "run_class": "source_pruning_candidate" if pruned else "source_pruning_control",
                "prompt_path": str(run_dir / "prompt.txt"),
                "prompt_equality": {"available": True, "matches_current_renderer": True},
                "source_pruning_policy": {
                    "enabled": pruned,
                    "policy_path": str(policy_path),
                    "policy_id": "burst27-closed-bundle-v1" if pruned else None,
                    "policy_sha256": policy_sha if pruned else None,
                },
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
                "required_missing": [],
                "optional_missing": [] if pruned else ["source_pruning_context", "source_pruning_receipt"],
                "optional_present": ["source_pruning_context", "source_pruning_receipt"] if pruned else [],
            },
        },
    )


make_run("control", 10000, 5, 3)
make_run("candidate", 8000, 4, 2, pruned=True)
make_run("candidate-amplified", 12000, 6, 4, pruned=True)
make_run("candidate-missing-boundary", 8000, 4, 2, pruned=True, boundary=False)
make_run("candidate-receipt-not-closed", 8000, 4, 2, pruned=True, receipt_closed=False)
PY

python3 tools/build_closed_bundle_source_pruning_receipt.py \
  --control-run-dir "$tmpdir/control" \
  --candidate-run-dir "$tmpdir/candidate" \
  --output "$tmpdir/closed-bundle-pass.json" >/dev/null

if python3 tools/build_closed_bundle_source_pruning_receipt.py \
  --control-run-dir "$tmpdir/control" \
  --candidate-run-dir "$tmpdir/candidate-amplified" \
  --output "$tmpdir/closed-bundle-amplified.json" >/dev/null; then
  echo "ASSERTION FAILED: amplified closed-bundle pair should fail"
  exit 1
fi

if python3 tools/build_closed_bundle_source_pruning_receipt.py \
  --control-run-dir "$tmpdir/control" \
  --candidate-run-dir "$tmpdir/candidate-missing-boundary" \
  --output "$tmpdir/closed-bundle-missing-boundary.json" >/dev/null; then
  echo "ASSERTION FAILED: missing prompt boundary should fail"
  exit 1
fi

if python3 tools/build_closed_bundle_source_pruning_receipt.py \
  --control-run-dir "$tmpdir/control" \
  --candidate-run-dir "$tmpdir/candidate-receipt-not-closed" \
  --output "$tmpdir/closed-bundle-receipt-not-closed.json" >/dev/null; then
  echo "ASSERTION FAILED: receipt without closed-bundle declaration should fail"
  exit 1
fi

python3 - "$tmpdir/closed-bundle-pass.json" "$tmpdir/closed-bundle-amplified.json" "$tmpdir/closed-bundle-missing-boundary.json" "$tmpdir/closed-bundle-receipt-not-closed.json" <<'PY'
import json
import sys
from pathlib import Path

passed = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
amplified = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
missing_boundary = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8"))
receipt_not_closed = json.loads(Path(sys.argv[4]).read_text(encoding="utf-8"))
if passed["classification"] != "qualified_closed_bundle_source_pruning_signal":
    raise SystemExit("expected qualified closed-bundle synthetic pair")
if amplified["classification"] != "closed_bundle_input_amplification":
    raise SystemExit("expected input amplification classification")
if missing_boundary["classification"] != "closed_bundle_boundary_not_admitted":
    raise SystemExit("expected boundary-not-admitted classification")
if receipt_not_closed["classification"] != "closed_bundle_boundary_not_admitted":
    raise SystemExit("expected non-closed pruning receipt to be classified as boundary-not-admitted")
PY

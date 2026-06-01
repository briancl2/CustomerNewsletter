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
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def write_session(run_dir, requests, search_count, materialization_count=0):
    rows = [{"type": "session.start", "data": {"sessionId": run_dir.name}}]
    rows.extend(
        {
            "type": "tool.execution_start",
            "data": {"toolName": "rg", "arguments": {"command": "rg source"}},
        }
        for _ in range(search_count)
    )
    rows.extend(
        {
            "type": "tool.execution_start",
            "data": {
                "toolName": "bash",
                "arguments": {"command": "python3 tools/build_phase3_working_set.py 2026-02-14 2026-04-16"},
            },
        }
        for _ in range(materialization_count)
    )
    rows.append(
        {
            "type": "tool.execution_start",
            "data": {
                "toolName": "bash",
                "arguments": {"command": "python3 tools/apply_newsletter_source_pruning_policy.py 2026-02-14 2026-04-16"},
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


def make_run(
    name,
    run_class,
    input_tokens,
    requests,
    *,
    pruned=False,
    search_count=2,
    materialization_count=0,
    warning_classes=None,
):
    warning_classes = warning_classes or []
    run_dir = root / name
    (run_dir / "artifacts" / "workspace").mkdir(parents=True)
    if pruned:
        prompt = """Canonical newsletter prompt
Source-pruning experiment:
- Enabled with policy: `config/experiment_pruning_policies/test.json`
- Policy SHA256: `abc`
- After Phase 3 working set and curated sections exist and before final newsletter drafting, run:
  `python3 tools/apply_newsletter_source_pruning_policy.py 2026-02-14 2026-04-16 --policy config/experiment_pruning_policies/test.json --source-root . --output-root . --require-admission`
- Read `workspace/newsletter_source_pruning_context_2026-04-16.md` as the compact source/candidate context for final drafting.
"""
    else:
        prompt = """Canonical newsletter prompt
Source-pruning experiment:
- Disabled. Use the canonical source/candidate artifacts directly.
"""
    (run_dir / "prompt.txt").write_text(prompt, encoding="utf-8")
    copied = []
    if pruned:
        for logical in (
            "workspace/newsletter_source_pruning_context_2026-04-16.md",
            "workspace/newsletter_source_pruning_receipt_2026-04-16.json",
        ):
            target = run_dir / "artifacts" / logical
            if target.suffix == ".json":
                write_json(target, {"policy_sha256": "abc", "admission": {"pass": True}})
            else:
                target.write_text("compact source context\n", encoding="utf-8")
            copied.append({"logical_path": logical, "size_bytes": target.stat().st_size})
    write_json(run_dir / "artifacts" / "snapshot-manifest.json", {"copied_files": copied})
    write_session(run_dir, requests, search_count, materialization_count)
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
            "start": "2026-02-14",
            "end": "2026-04-16",
            "mode": "production",
            "primary_model": "gpt-5.5",
            "experiment": {
                "run_class": run_class,
                "prompt_path": str(run_dir / "prompt.txt"),
                "prompt_equality": {"available": True, "matches_current_renderer": True},
                "source_pruning_policy": (
                    {"enabled": True, "policy_id": "test", "policy_sha256": "abc"} if pruned else None
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
                "warning_taxonomy_classes": warning_classes,
            },
            "artifact_completeness": {
                "optional_missing": (
                    [] if pruned else ["source_pruning_context", "source_pruning_receipt"]
                ),
                "optional_present": (
                    ["source_pruning_context", "source_pruning_receipt"] if pruned else []
                ),
                "required_missing": [],
            },
        },
    )
    return run_dir


make_run("control", "source_pruning_control", 10000, 5, search_count=2)
make_run("pruned", "source_pruning_candidate", 14000, 9, pruned=True, search_count=7)
make_run("repair", "source_pruning_candidate", 8000, 4, pruned=True, search_count=2)
make_run("warning", "source_pruning_candidate", 8000, 4, pruned=True, search_count=2, warning_classes=["new_warning"])
make_run("searchy", "source_pruning_candidate", 8000, 4, pruned=True, search_count=8)
make_run("builder", "source_pruning_candidate", 8000, 4, pruned=True, search_count=2, materialization_count=3)
PY

if python3 tools/build_production_source_pruning_amplification_receipt.py \
  --pair "amplified:$tmpdir/control:$tmpdir/pruned" \
  --output "$tmpdir/amplified.json" >/dev/null; then
  echo "ASSERTION FAILED: amplification-only receipt should fail the command"
  exit 1
fi

python3 - "$tmpdir/amplified.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
row = payload["classifications"][0]
if row["classification"] != "production_input_and_request_amplification":
    raise SystemExit("expected production amplification classification")
if row["control_prompt_state"] != "source_pruning_disabled_block":
    raise SystemExit("expected disabled control prompt state")
if row["pruned_prompt_state"] != "source_pruning_enabled_block":
    raise SystemExit("expected enabled pruned prompt state")
if row["root_cause_evidence_pass"] is not True:
    raise SystemExit("expected root-cause evidence checks to pass")
if payload["evidence_complete"] is not True:
    raise SystemExit("expected amplification evidence to be complete")
if payload["pass"] is not False:
    raise SystemExit("amplification evidence is not a qualified repair pass")
if row["amplification_flags"]["search_or_inspection_amplification"] is not True:
    raise SystemExit("expected search amplification flag")
PY

python3 tools/build_production_source_pruning_amplification_receipt.py \
  --pair "repair:$tmpdir/control:$tmpdir/repair" \
  --output "$tmpdir/repair.json" >/dev/null

python3 - "$tmpdir/repair.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
row = payload["classifications"][0]
if row["classification"] != "qualified_production_repair_signal":
    raise SystemExit("expected qualified repair signal")
if payload["qualified_production_repair_pair_count"] != 1:
    raise SystemExit("expected qualified repair count")
PY

if python3 tools/build_production_source_pruning_amplification_receipt.py \
  --pair "searchy:$tmpdir/control:$tmpdir/searchy" \
  --output "$tmpdir/searchy.json" >/dev/null; then
  echo "ASSERTION FAILED: command-work amplification should fail the repair command"
  exit 1
fi

python3 - "$tmpdir/searchy.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
row = payload["classifications"][0]
if row["classification"] != "production_command_work_amplification":
    raise SystemExit("expected command-work amplification classification")
if payload["production_amplification_pair_count"] != 1:
    raise SystemExit("expected command-work amplification to count as amplification")
if payload["pass"] is not False:
    raise SystemExit("command-work amplification is not a qualified repair pass")
PY

if python3 tools/build_production_source_pruning_amplification_receipt.py \
  --pair "builder:$tmpdir/control:$tmpdir/builder" \
  --output "$tmpdir/builder.json" >/dev/null; then
  echo "ASSERTION FAILED: materialization amplification should fail the repair command"
  exit 1
fi

python3 - "$tmpdir/builder.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
row = payload["classifications"][0]
if row["classification"] != "production_command_work_amplification":
    raise SystemExit("expected materialization to classify as command-work amplification")
if row["amplification_flags"]["materialization_or_builder_amplification"] is not True:
    raise SystemExit("expected materialization amplification flag")
PY

python3 - "$tmpdir/repair/run-scorecard.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["experiment"]["source_pruning_policy"]["policy_sha256"] = "mismatch"
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

if python3 tools/build_production_source_pruning_amplification_receipt.py \
  --pair "policy_mismatch:$tmpdir/control:$tmpdir/repair" \
  --output "$tmpdir/policy-mismatch.json" >/dev/null; then
  echo "ASSERTION FAILED: policy hash mismatch should fail production root-cause receipt"
  exit 1
fi

python3 - "$tmpdir/policy-mismatch.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
checks = payload["classifications"][0]["root_cause_checks"]
if checks["policy_hash_bound"] is not False:
    raise SystemExit("expected policy_hash_bound root-cause check to fail")
if payload["classifications"][0]["classification"] != "fail_closed_incomplete_production_root_cause_evidence":
    raise SystemExit("expected incomplete-evidence classification")
PY

python3 - "$tmpdir/repair/run-scorecard.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["experiment"]["source_pruning_policy"]["policy_sha256"] = "abc"
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

if python3 tools/build_production_source_pruning_amplification_receipt.py \
  --pair "warning:$tmpdir/control:$tmpdir/warning" \
  --output "$tmpdir/warning.json" >/dev/null; then
  echo "ASSERTION FAILED: fail-closed non-repair receipt should fail the command"
  exit 1
fi

python3 - "$tmpdir/warning.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
row = payload["classifications"][0]
if row["classification"] != "production_not_qualified_without_amplification":
    raise SystemExit("expected non-amplified non-qualified classification")
if payload["production_amplification_pair_count"] != 0:
    raise SystemExit("non-amplified classification must not increment amplification count")
if payload["result"] != "fail_closed_no_production_amplification_or_repair_signal":
    raise SystemExit("expected fail-closed result when there is neither amplification nor repair")
if payload["evidence_complete"] is not True:
    raise SystemExit("expected non-repair evidence to be complete")
if payload["pass"] is not False:
    raise SystemExit("fail-closed result must not pass")
PY

python3 - "$tmpdir/repair/run-scorecard.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["mode"] = "benchmark"
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

if python3 tools/build_production_source_pruning_amplification_receipt.py \
  --pair "wrong_mode:$tmpdir/control:$tmpdir/repair" \
  --output "$tmpdir/wrong-mode.json" >/dev/null; then
  echo "ASSERTION FAILED: mismatched mode should fail production root-cause receipt"
  exit 1
fi

python3 - "$tmpdir/wrong-mode.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
checks = payload["classifications"][0]["root_cause_checks"]
if checks["same_mode"] is not False:
    raise SystemExit("expected same_mode root-cause check to fail")
if checks["mode_is_production"] is not True:
    raise SystemExit("control side should still identify the pair as production-scoped")
PY

python3 - "$tmpdir/repair/run-scorecard.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["mode"] = "production"
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

rm "$tmpdir/repair/session/events.jsonl"
if python3 tools/build_production_source_pruning_amplification_receipt.py \
  --pair "missing_trace:$tmpdir/control:$tmpdir/repair" \
  --output "$tmpdir/missing-trace.json" >/dev/null; then
  echo "ASSERTION FAILED: missing session trace should fail production root-cause receipt"
  exit 1
fi

python3 - "$tmpdir/missing-trace.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["classifications"][0]["root_cause_checks"]["pruned_trace_qualified"] is not False:
    raise SystemExit("expected missing pruned trace to fail")
PY

echo "PASS: production source pruning amplification receipt tests passed"

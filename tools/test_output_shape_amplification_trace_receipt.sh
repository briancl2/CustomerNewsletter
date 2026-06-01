#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

python3 - "$tmpdir" <<'PY'
import json
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1])
policy_sha = "a" * 64
direct_fields = [
    "inputTokens",
    "outputTokens",
    "cacheReadTokens",
    "cacheWriteTokens",
    "reasoningTokens",
]


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def write_session(run_dir, request_count):
    session = run_dir / "session" / "events.jsonl"
    session.parent.mkdir(parents=True, exist_ok=True)
    rows = [
        {"type": "session.start", "data": {"sessionId": run_dir.name}},
        {
            "type": "tool.execution_start",
            "data": {"toolName": "bash", "arguments": {"command": "rg output_shape"}},
        },
        {
            "type": "session.shutdown",
            "data": {
                "modelMetrics": {
                    "gpt-5.5": {
                        "requests": {"count": request_count},
                        "usage": {
                            "inputTokens": 100,
                            "outputTokens": 100,
                            "cacheReadTokens": 0,
                            "cacheWriteTokens": 0,
                            "reasoningTokens": 0,
                        },
                    }
                }
            },
        },
    ]
    session.write_text("\n".join(json.dumps(row) for row in rows) + "\n", encoding="utf-8")


def scorecard(run_dir, run_class, enabled, prompt_sha, request_count, output_tokens, total_usd):
    token_usage = {
        "source": "session.shutdown.modelMetrics",
        "input_tokens": 1000,
        "output_tokens": output_tokens,
        "cache_read_tokens": 0,
        "cache_write_tokens": 0,
        "reasoning_tokens": 0,
        "request_count": request_count,
        "direct_provider_token_fields_present": direct_fields,
        "missing_direct_provider_token_fields": [],
        "requested_models": ["gpt-5.5"],
        "model_direct_provider_token_fields": {
            "gpt-5.5": {
                "request_count": request_count,
                "direct_provider_token_fields_present": direct_fields,
                "missing_direct_provider_token_fields": [],
            }
        },
    }
    return {
        "run_id": run_dir.name,
        "run_dir": str(run_dir),
        "start": "2025-12-05",
        "end": "2026-02-13",
        "mode": "benchmark",
        "primary_model": "gpt-5.5",
        "experiment": {
            "run_class": run_class,
            "prompt_path": str(run_dir / "prompt.txt"),
            "prompt_equality": {
                "available": True,
                "retained_prompt_sha256": prompt_sha,
                "current_renderer_sha256": prompt_sha,
                "matches_current_renderer": True,
            },
            "output_shape_policy": {
                "enabled": enabled,
                "policy_path": "config/experiment_output_shape_policies/burst22-output-shape-v1.json" if enabled else None,
                "policy_sha256": policy_sha if enabled else None,
                "policy_id": "burst22-output-shape-v1" if enabled else None,
            },
        },
        "token_usage": token_usage,
        "quality": {
            "strict_pass": True,
            "newsletter_pass": True,
            "rubric_pass": True,
            "strict_warning_count": 0,
            "newsletter_warning_count": 0,
            "warning_taxonomy_classes": [],
        },
        "cost_estimate": {"total_usd": total_usd, "unpriced_models": []},
        "artifact_completeness": {
            "required_missing": [],
            "optional_missing": [] if enabled else ["output_shape_context", "output_shape_receipt"],
        },
    }


def make_run(name, enabled, request_count, output_tokens, total_usd):
    run_dir = root / name
    (run_dir / "artifacts" / "workspace").mkdir(parents=True)
    prompt = run_dir / "prompt.txt"
    if enabled:
        prompt.write_text(
            "Output-shape budget experiment:\n"
            "- Enabled with policy: `config/experiment_output_shape_policies/burst22-output-shape-v1.json`\n"
            "python3 tools/apply_newsletter_output_shape_policy.py 2025-12-05 2026-02-13\n"
            "workspace/newsletter_output_shape_context_2026-02-13.md\n",
            encoding="utf-8",
        )
        context = run_dir / "artifacts" / "workspace" / "newsletter_output_shape_context_2026-02-13.md"
        receipt = run_dir / "artifacts" / "workspace" / "newsletter_output_shape_receipt_2026-02-13.json"
        context.write_text("shape context\n", encoding="utf-8")
        write_json(receipt, {"pass": True, "policy_sha256": policy_sha})
        copied_files = [
            {"logical_path": "workspace/newsletter_output_shape_context_2026-02-13.md", "size_bytes": 14},
            {"logical_path": "workspace/newsletter_output_shape_receipt_2026-02-13.json", "size_bytes": 90},
        ]
        run_class = "output_shape_candidate"
    else:
        prompt.write_text(
            "Output-shape budget experiment:\n"
            "- Disabled. Use the canonical output shape and quality bar.\n",
            encoding="utf-8",
        )
        copied_files = []
        run_class = "output_shape_control"
    import hashlib

    prompt_sha = hashlib.sha256(prompt.read_bytes()).hexdigest()
    write_json(run_dir / "artifacts" / "snapshot-manifest.json", {"copied_files": copied_files})
    write_session(run_dir, request_count)
    write_json(run_dir / "run-scorecard.json", scorecard(run_dir, run_class, enabled, prompt_sha, request_count, output_tokens, total_usd))
    return run_dir


control = make_run("control", False, 5, 6000, 10.0)
variant = make_run("variant", True, 5, 5200, 8.0)
shutil.copytree(control, root / "stale_control")
(root / "stale_control" / "artifacts" / "workspace" / "newsletter_output_shape_context_2026-02-13.md").write_text("stale\n", encoding="utf-8")
missing_trace = root / "missing_trace_variant"
shutil.copytree(variant, missing_trace)
shutil.rmtree(missing_trace / "session")
bad_policy = root / "bad_policy_variant"
shutil.copytree(variant, bad_policy)
payload = json.loads((bad_policy / "run-scorecard.json").read_text(encoding="utf-8"))
payload["experiment"]["output_shape_policy"]["policy_sha256"] = "b" * 64
write_json(bad_policy / "run-scorecard.json", payload)
bad_control_class = root / "bad_control_class"
shutil.copytree(control, bad_control_class)
payload = json.loads((bad_control_class / "run-scorecard.json").read_text(encoding="utf-8"))
payload["experiment"]["run_class"] = "ordinary_proof"
write_json(bad_control_class / "run-scorecard.json", payload)

contaminated_control_prompt = root / "contaminated_control_prompt"
shutil.copytree(control, contaminated_control_prompt)
(contaminated_control_prompt / "prompt.txt").write_text(
    "Output-shape budget experiment:\n"
    "- Disabled. Use the canonical output shape and quality bar.\n"
    "python3 tools/apply_newsletter_output_shape_policy.py 2025-12-05 2026-02-13\n",
    encoding="utf-8",
)

malformed_variant_prompt = root / "malformed_variant_prompt"
shutil.copytree(variant, malformed_variant_prompt)
(malformed_variant_prompt / "prompt.txt").write_text(
    "Output-shape budget experiment:\n"
    "- Enabled with policy: `config/experiment_output_shape_policies/burst22-output-shape-v1.json`\n",
    encoding="utf-8",
)

external_prompt_control = root / "external_prompt_control"
shutil.copytree(control, external_prompt_control)
(root / "external-prompt.txt").write_text(
    "Output-shape budget experiment:\n"
    "- Enabled with policy: `config/experiment_output_shape_policies/burst22-output-shape-v1.json`\n"
    "python3 tools/apply_newsletter_output_shape_policy.py 2025-12-05 2026-02-13\n"
    "workspace/newsletter_output_shape_context_2026-02-13.md\n",
    encoding="utf-8",
)
payload = json.loads((external_prompt_control / "run-scorecard.json").read_text(encoding="utf-8"))
payload["experiment"]["prompt_path"] = str(root / "external-prompt.txt")
write_json(external_prompt_control / "run-scorecard.json", payload)

production_control = root / "production_control"
production_variant = root / "production_variant"
shutil.copytree(control, production_control)
shutil.copytree(variant, production_variant)
for run_dir in (production_control, production_variant):
    payload = json.loads((run_dir / "run-scorecard.json").read_text(encoding="utf-8"))
    payload["mode"] = "production"
    payload["start"] = "2026-02-14"
    payload["end"] = "2026-04-16"
    if run_dir == production_variant:
        payload["token_usage"]["output_tokens"] = 7000
        payload["cost_estimate"]["total_usd"] = 12.0
    write_json(run_dir / "run-scorecard.json", payload)
PY

python3 tools/build_output_shape_amplification_trace_receipt.py \
  --pair qualified:"$tmpdir/control":"$tmpdir/variant" \
  --output "$tmpdir/qualified.json" >/dev/null
python3 - "$tmpdir/qualified.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
pair = payload["pairs"][0]
if payload["pass"] is not True or pair["classification"] != "qualified_repair_signal":
    raise SystemExit(f"expected qualified repair signal: {payload}")
PY

python3 tools/build_output_shape_amplification_trace_receipt.py \
  --pair self-contained-prompt:"$tmpdir/external_prompt_control":"$tmpdir/variant" \
  --output "$tmpdir/self-contained-prompt.json" >/dev/null
python3 - "$tmpdir/self-contained-prompt.json" <<'PY'
import json
import sys
from pathlib import Path

pair = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["pairs"][0]
if pair["control"]["prompt"]["path"].endswith("external-prompt.txt"):
    raise SystemExit("expected retained run prompt snapshot, not embedded external prompt path")
if pair["classification"] != "qualified_repair_signal":
    raise SystemExit(f"expected self-contained prompt evidence to qualify: {pair['classification']}")
PY

if python3 tools/build_output_shape_amplification_trace_receipt.py \
  --pair benchmark:"$tmpdir/control":"$tmpdir/variant" \
  --pair production:"$tmpdir/production_control":"$tmpdir/production_variant" \
  --output "$tmpdir/mixed-mode.json" >/dev/null 2>&1; then
  echo "ASSERTION FAILED: mixed-mode receipt must not pass globally when a mode amplifies"
  exit 1
fi
python3 - "$tmpdir/mixed-mode.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["result"] != "mode_specific_output_shape_repair_signal_observed":
    raise SystemExit(f"expected mode-specific result: {payload['result']}")
if payload["mode_summaries"]["benchmark"]["qualified_pair_count"] != 1:
    raise SystemExit("expected benchmark mode to retain the qualified signal")
if payload["mode_summaries"]["production"]["qualified_pair_count"] != 0:
    raise SystemExit("expected production mode to remain non-qualified")
PY

if python3 tools/build_output_shape_amplification_trace_receipt.py \
  --pair stale:"$tmpdir/stale_control":"$tmpdir/variant" \
  --output "$tmpdir/stale.json" >/dev/null 2>&1; then
  echo "ASSERTION FAILED: stale control artifact must fail evidence completeness"
  exit 1
fi
python3 - "$tmpdir/stale.json" <<'PY'
import json
import sys
from pathlib import Path

pair = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["pairs"][0]
if pair["classification"] != "control_artifact_contamination":
    raise SystemExit(f"expected control artifact contamination: {pair['classification']}")
PY

if python3 tools/build_output_shape_amplification_trace_receipt.py \
  --pair missing:"$tmpdir/control":"$tmpdir/missing_trace_variant" \
  --output "$tmpdir/missing-trace.json" >/dev/null 2>&1; then
  echo "ASSERTION FAILED: missing variant trace must fail evidence completeness"
  exit 1
fi
python3 - "$tmpdir/missing-trace.json" <<'PY'
import json
import sys
from pathlib import Path

pair = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["pairs"][0]
if pair["classification"] != "trace_incomplete_fail_closed":
    raise SystemExit(f"expected trace incomplete fail closed: {pair['classification']}")
PY

if python3 tools/build_output_shape_amplification_trace_receipt.py \
  --pair bad-policy:"$tmpdir/control":"$tmpdir/bad_policy_variant" \
  --output "$tmpdir/bad-policy.json" >/dev/null 2>&1; then
  echo "ASSERTION FAILED: policy hash mismatch must fail evidence completeness"
  exit 1
fi
python3 - "$tmpdir/bad-policy.json" <<'PY'
import json
import sys
from pathlib import Path

pair = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["pairs"][0]
if pair["classification"] != "variant_artifact_or_policy_binding_defect":
    raise SystemExit(f"expected variant binding defect: {pair['classification']}")
PY

if python3 tools/build_output_shape_amplification_trace_receipt.py \
  --pair bad-control-class:"$tmpdir/bad_control_class":"$tmpdir/variant" \
  --output "$tmpdir/bad-control-class.json" >/dev/null 2>&1; then
  echo "ASSERTION FAILED: bad control run_class must fail evidence completeness"
  exit 1
fi
python3 - "$tmpdir/bad-control-class.json" <<'PY'
import json
import sys
from pathlib import Path

pair = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["pairs"][0]
if pair["classification"] != "prompt_renderer_or_scorecard_binding_defect":
    raise SystemExit(f"expected prompt/scorecard binding defect: {pair['classification']}")
PY

if python3 tools/build_output_shape_amplification_trace_receipt.py \
  --pair contaminated-control-prompt:"$tmpdir/contaminated_control_prompt":"$tmpdir/variant" \
  --output "$tmpdir/contaminated-control-prompt.json" >/dev/null 2>&1; then
  echo "ASSERTION FAILED: contaminated disabled control prompt must fail evidence completeness"
  exit 1
fi
python3 - "$tmpdir/contaminated-control-prompt.json" <<'PY'
import json
import sys
from pathlib import Path

pair = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["pairs"][0]
if pair["classification"] != "prompt_renderer_or_scorecard_binding_defect":
    raise SystemExit(f"expected prompt/scorecard binding defect: {pair['classification']}")
PY

if python3 tools/build_output_shape_amplification_trace_receipt.py \
  --pair malformed-prompt:"$tmpdir/control":"$tmpdir/malformed_variant_prompt" \
  --output "$tmpdir/malformed-prompt.json" >/dev/null 2>&1; then
  echo "ASSERTION FAILED: malformed enabled prompt surface must fail evidence completeness"
  exit 1
fi
python3 - "$tmpdir/malformed-prompt.json" <<'PY'
import json
import sys
from pathlib import Path

pair = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["pairs"][0]
if pair["classification"] != "prompt_renderer_or_scorecard_binding_defect":
    raise SystemExit(f"expected prompt/scorecard binding defect: {pair['classification']}")
PY

echo "PASS: output-shape amplification trace receipt tests passed"

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


def write_session(run_dir, requests):
    rows = [
        {
            "type": "session.start",
            "data": {"sessionId": run_dir.name},
        },
        {
            "type": "tool.execution_start",
            "data": {"toolName": "rg", "arguments": {"pattern": "newsletter"}},
        },
        {
            "type": "tool.execution_start",
            "data": {
                "toolName": "bash",
                "arguments": {"command": "python3 tools/build_phase3_working_set.py 2026-02-14 2026-04-16"},
            },
        },
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


def make_run(name, run_class, input_tokens, requests, pruned=False):
    run_dir = root / name
    (run_dir / "artifacts" / "workspace").mkdir(parents=True)
    (run_dir / "prompt.txt").write_text(
        (
            "Canonical newsletter prompt\n"
            + ("Source-pruning experiment:\nUse compact context.\n" if pruned else "")
        ),
        encoding="utf-8",
    )
    copied = []
    if pruned:
        for logical in (
            "workspace/newsletter_source_pruning_context_2026-04-16.md",
            "workspace/newsletter_source_pruning_receipt_2026-04-16.json",
        ):
            target = run_dir / "artifacts" / logical
            if target.suffix == ".json":
                write_json(target, {"admission": {"pass": True}})
            else:
                target.write_text("compact source context\n", encoding="utf-8")
            copied.append({"logical_path": logical, "size_bytes": target.stat().st_size})
    write_json(run_dir / "artifacts" / "snapshot-manifest.json", {"copied_files": copied})
    write_session(run_dir, requests)
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
                "optional_missing": (
                    [] if pruned else ["source_pruning_context", "source_pruning_receipt"]
                ),
                "optional_present": (
                    ["source_pruning_context", "source_pruning_receipt"] if pruned else []
                ),
            },
        },
    )
    return run_dir


make_run("control", "source_pruning_control", 10000, 5)
make_run("pruned", "source_pruning_candidate", 8000, 4, pruned=True)
PY

python3 tools/build_source_pruning_amplification_receipt.py \
  --pair "clean:$tmpdir/control:$tmpdir/pruned" \
  --output "$tmpdir/qualified.json" >/dev/null

python3 tools/build_source_pruning_amplification_receipt.py \
  --fresh-live-spend-used \
  --pair "clean:$tmpdir/control:$tmpdir/pruned" \
  --output "$tmpdir/live-qualified.json" >/dev/null

python3 - "$tmpdir/qualified.json" "$tmpdir/live-qualified.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
pair = payload["pairs"][0]
if pair["admitted_for_mode_specific_follow_on"] is not True:
    raise SystemExit("expected clean synthetic pair to admit a mode-specific follow-on")
if pair["checks"]["control_source_pruning_artifacts_absent"] is not True:
    raise SystemExit("expected control stale-artifact absence to pass")
if pair["pruned"]["source_pruning_artifact_presence"]["stale_or_unexpected_artifacts"]:
    raise SystemExit("expected admitted pruned artifacts not to be labeled stale or unexpected")
if pair["pruned"]["source_pruning_artifact_presence"]["absent_from_filesystem_manifest_and_scorecard"] is not False:
    raise SystemExit("expected admitted pruned artifacts not to be summarized as absent")
if pair["deltas"]["trace_control_minus_pruned"]["command_category_counts"]["materialization_or_builder"] != 0:
    raise SystemExit("expected materialization trace delta to be present")
live_payload = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
if live_payload["fresh_live_spend_used"] is not True:
    raise SystemExit("expected explicit live-spend flag to be retained")
if live_payload["receipt_type"] != "source_pruning_amplification_live_probe":
    raise SystemExit("expected live probe receipt type")
PY

cp -R "$tmpdir/pruned" "$tmpdir/pruned-stale-control"

cp -R "$tmpdir/pruned" "$tmpdir/pruned-partial"
rm "$tmpdir/pruned-partial/artifacts/workspace/newsletter_source_pruning_receipt_2026-04-16.json"
python3 - "$tmpdir/pruned-partial/artifacts/snapshot-manifest.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["copied_files"] = [
    row for row in payload["copied_files"] if not row["logical_path"].endswith(".json")
]
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

if python3 tools/build_source_pruning_amplification_receipt.py \
  --pair "partial_pruned:$tmpdir/control:$tmpdir/pruned-partial" \
  --output "$tmpdir/partial-pruned.json" >/dev/null; then
  echo "ASSERTION FAILED: pruned run missing pruning receipt should block admission"
  exit 1
fi

python3 - "$tmpdir/partial-pruned.json" <<'PY'
import json
import sys
from pathlib import Path

pair = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["pairs"][0]
if pair["checks"]["pruned_source_pruning_artifacts_complete"] is not False:
    raise SystemExit("expected incomplete pruned source-pruning artifacts to fail")
PY

rm "$tmpdir/pruned/session/events.jsonl"
if python3 tools/build_source_pruning_amplification_receipt.py \
  --pair "missing_trace:$tmpdir/control:$tmpdir/pruned" \
  --output "$tmpdir/missing-trace.json" >/dev/null; then
  echo "ASSERTION FAILED: missing retained session trace should block admission"
  exit 1
fi

python3 - "$tmpdir/missing-trace.json" <<'PY'
import json
import sys
from pathlib import Path

pair = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["pairs"][0]
if "missing_retained_session_trace_variance_evidence" not in pair["blockers"]:
    raise SystemExit("expected missing session trace to block variance evidence")
PY

mkdir -p "$tmpdir/control/artifacts/workspace"
printf 'stale context\n' > "$tmpdir/control/artifacts/workspace/newsletter_source_pruning_context_2026-04-16.md"

if python3 tools/build_source_pruning_amplification_receipt.py \
  --pair "stale:$tmpdir/control:$tmpdir/pruned-stale-control" \
  --output "$tmpdir/stale.json" >/dev/null; then
  echo "ASSERTION FAILED: stale control artifacts should block admission"
  exit 1
fi

python3 - "$tmpdir/stale.json" <<'PY'
import json
import sys
from pathlib import Path

pair = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["pairs"][0]
if pair["classification"] != "blocked_by_stale_control_pruning_artifacts":
    raise SystemExit("expected stale control source-pruning artifacts to block the pair")
PY

echo "PASS: source pruning amplification receipt tests passed"

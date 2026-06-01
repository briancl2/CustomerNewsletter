#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0

check() {
  local desc="$1"
  shift
  if "$@"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

make_case() {
  local case_dir="$1"
  python3 - "$case_dir" <<'PY'
import json
import sys
from pathlib import Path

case = Path(sys.argv[1])
case.mkdir(parents=True, exist_ok=True)

def write(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

feature = {
    "feature_id": "phase3_stdout_no_tools_artifact_reuse",
    "configured_mode": "off",
    "default_mode": "off",
    "production_default_enabled": False,
    "public_customernewsletter_in_scope": False,
}
switch = {
    "verdict": "pass_disabled_switch_dry_run",
    "ready_for_private_default_enablement": False,
    "blockers": [],
}
no_refetch = {
    "admission_verdict": "admit_no_refetch",
    "no_refetch_compliance": "pass",
    "blockers": [],
}
write(case / "feature.json", feature)
write(case / "switch.json", switch)
write(case / "no-refetch.json", no_refetch)

direct_fields = [
    "inputTokens",
    "outputTokens",
    "cacheReadTokens",
    "cacheWriteTokens",
    "reasoningTokens",
]

def scorecard(run_dir, *, request_count, total_input, total_output, total_reasoning):
    write(
        run_dir / "run-scorecard.json",
        {
            "run_id": run_dir.name,
            "start": "2026-02-14",
            "end": "2026-04-16",
            "mode": "production",
            "primary_model": "gpt-5.5",
            "token_usage": {
                "source": "session.shutdown.modelMetrics",
                "primary_model": "gpt-5.5",
                "request_count": request_count,
                "input_tokens": total_input,
                "output_tokens": total_output,
                "cache_read_tokens": 0,
                "cache_write_tokens": 0,
                "cached_tokens_total": 0,
                "reasoning_tokens": total_reasoning,
            },
            "quality": {
                "strict_pass": True,
                "newsletter_pass": True,
                "rubric_pass": True,
                "rubric_score": 46,
                "warning_taxonomy_classes": [],
            },
            "experiment": {
                "experiment_id": "fixture",
                "run_class": run_dir.name,
            },
        },
    )
    write(
        run_dir / "run-result.json",
        {
            "copilot_exit_code": 0,
            "source_drift_exit_code": 0,
            "snapshot_exit_code": 0,
            "audit_exit_code": 0,
            "scorecard_exit_code": 0,
        },
    )

def metrics(run_dir, *, phase_id, tool_calls):
    path = run_dir / "session" / "phase-session-metrics.jsonl"
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "phase_id": phase_id,
        "exit_code": 0,
        "direct_provider_token_fields_present": direct_fields,
        "missing_direct_provider_token_fields": [],
        "token_usage": {
            "request_count": 1,
            "input_tokens": 100,
            "output_tokens": 20,
            "cache_read_tokens": 0,
            "cache_write_tokens": 0,
            "reasoning_tokens": 10,
            "tool_calls": tool_calls,
        },
    }
    path.write_text(json.dumps(payload, sort_keys=True) + "\n", encoding="utf-8")

control = case / "control"
candidate = case / "candidate"
scorecard(control, request_count=8, total_input=1000, total_output=100, total_reasoning=100)
scorecard(candidate, request_count=7, total_input=700, total_output=80, total_reasoning=50)
metrics(control, phase_id="phase3_curated", tool_calls=5)
metrics(candidate, phase_id="phase3_stdout_no_tools_artifact_reuse", tool_calls=0)
write(control / "run-metadata.json", {"phase3_stdout_no_tools_enabled": False})
write(
    candidate / "run-metadata.json",
    {
        "phase3_stdout_no_tools_enabled": True,
        "phase3_stdout_no_tools_no_refetch_admission": str((case / "no-refetch.json").resolve()),
    },
)
PY
}

run_builder() {
  local case_dir="$1"
  local output="$case_dir/receipt.json"
  python3 tools/build_stdout_no_tools_full_private_dry_run_receipt.py \
    --control-run-dir "$case_dir/control" \
    --candidate-run-dir "$case_dir/candidate" \
    --feature-config "$case_dir/feature.json" \
    --disabled-switch-receipt "$case_dir/switch.json" \
    --no-refetch-admission "$case_dir/no-refetch.json" \
    --output "$output"
}

assert_json() {
  local path="$1"
  local expr="$2"
  python3 - "$path" "$expr" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1]))
expr = sys.argv[2]
if not eval(expr, {}, {"payload": payload}):
    raise SystemExit(f"assertion failed: {expr}")
PY
}

echo "=== stdout/no-tools full private dry-run receipt ==="

GOOD="$TMPDIR/good"
make_case "$GOOD"
check "positive receipt exits zero" run_builder "$GOOD"
check "positive receipt qualifies" assert_json "$GOOD/receipt.json" "payload['verdict'] == 'pass_full_private_dry_run' and payload['qualifies'] is True"

DEFAULT_ON="$TMPDIR/default-on"
make_case "$DEFAULT_ON"
python3 - "$DEFAULT_ON/feature.json" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
payload = json.loads(path.read_text())
payload["production_default_enabled"] = True
path.write_text(json.dumps(payload, indent=2) + "\n")
PY
if run_builder "$DEFAULT_ON" >/dev/null 2>&1; then
  false
else
  true
fi
check "default-enabled config fails closed" assert_json "$DEFAULT_ON/receipt.json" "'production_default_enabled must be false' in '\\n'.join(payload['blockers'])"

MISSING_DIRECT="$TMPDIR/missing-direct"
make_case "$MISSING_DIRECT"
python3 - "$MISSING_DIRECT/candidate/session/phase-session-metrics.jsonl" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
payload = json.loads(path.read_text())
payload["missing_direct_provider_token_fields"] = ["inputTokens"]
payload["direct_provider_token_fields_present"] = []
path.write_text(json.dumps(payload) + "\n")
PY
if run_builder "$MISSING_DIRECT" >/dev/null 2>&1; then
  false
else
  true
fi
check "missing direct fields fail closed" assert_json "$MISSING_DIRECT/receipt.json" "'candidate has phases without exit 0 plus direct token fields' in '\\n'.join(payload['blockers'])"

TOOL_CALLS="$TMPDIR/tool-calls"
make_case "$TOOL_CALLS"
python3 - "$TOOL_CALLS/candidate/session/phase-session-metrics.jsonl" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
payload = json.loads(path.read_text())
payload["token_usage"]["tool_calls"] = 1
path.write_text(json.dumps(payload) + "\n")
PY
if run_builder "$TOOL_CALLS" >/dev/null 2>&1; then
  false
else
  true
fi
check "candidate tool call fails closed" assert_json "$TOOL_CALLS/receipt.json" "'candidate phase3 stdout/no-tools row must have zero tool calls' in payload['blockers']"

REQUEST_AMP="$TMPDIR/request-amp"
make_case "$REQUEST_AMP"
python3 - "$REQUEST_AMP/candidate/run-scorecard.json" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
payload = json.loads(path.read_text())
payload["token_usage"]["request_count"] = 9
path.write_text(json.dumps(payload, indent=2) + "\n")
PY
if run_builder "$REQUEST_AMP" >/dev/null 2>&1; then
  false
else
  true
fi
check "request amplification fails closed" assert_json "$REQUEST_AMP/receipt.json" "'candidate request_count is higher than control' in payload['blockers']"

check "orchestrator uses bounded stdout/no-tools timeout" bash -c \
  'rg -F -q '\''stdout_phase_timeout_seconds="${PHASE3_STDOUT_NO_TOOLS_TIMEOUT_SECONDS:-900}"'\'' tools/run_newsletter_orchestrated.sh && rg -F -q -- '\''--phase-timeout-seconds "$stdout_phase_timeout_seconds"'\'' tools/run_newsletter_orchestrated.sh'
check "instrumented metadata records stdout/no-tools timeout" bash -c \
  "rg -q 'PHASE3_STDOUT_NO_TOOLS_TIMEOUT_SECONDS' tools/run_instrumented_orchestrated_proof.sh && rg -q 'phase3_stdout_no_tools_timeout_seconds' tools/run_instrumented_orchestrated_proof.sh"
check "full orchestrator preserves full-run marker during stdout/no-tools phase" bash -c \
  "rg -q -- '--preserve-existing-provenance' tools/run_newsletter_orchestrated.sh"

echo ""
echo "=== test_stdout_no_tools_full_private_dry_run_receipt.sh: $PASS pass, $FAIL fail ==="
[ "$FAIL" -eq 0 ]

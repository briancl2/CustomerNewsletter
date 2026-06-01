#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fake_bin="$tmpdir/fake-copilot"
cat > "$fake_bin" <<'PY'
#!/usr/bin/env python3
import json
import os
import sys
import uuid
from pathlib import Path

args = sys.argv[1:]
model = "gpt-5.5"
agent = ""
prompt = ""
cwd = os.getcwd()
for index, arg in enumerate(args):
    if arg == "--model" and index + 1 < len(args):
        model = args[index + 1]
    if arg == "--agent" and index + 1 < len(args):
        agent = args[index + 1]
    if arg == "-p" and index + 1 < len(args):
        prompt = args[index + 1]
    if arg == "-C" and index + 1 < len(args):
        cwd = str(Path(args[index + 1]).resolve())

if os.environ.get("FAKE_COPILOT_EXIT_EMPTY") == "1":
    raise SystemExit(1)

base = Path(os.environ["FAKE_COPILOT_SESSION_STATE_BASE"])
session_count = 2 if os.environ.get("FAKE_COPILOT_TWO_SESSIONS") == "1" else 1
if os.environ.get("FAKE_COPILOT_NO_SESSION") != "1":
    for _ in range(session_count):
        session_id = str(uuid.uuid4())
        path = base / session_id / "events.jsonl"
        path.parent.mkdir(parents=True, exist_ok=True)
        event_model = "gpt-wrong" if os.environ.get("FAKE_COPILOT_WRONG_MODEL") == "1" else model
        event_cwd = "/tmp/wrong-cwd" if os.environ.get("FAKE_COPILOT_WRONG_CWD") == "1" else cwd
        marker_content = "" if os.environ.get("FAKE_COPILOT_MISSING_MARKER") == "1" else prompt
        usage = {"inputTokens": 10, "outputTokens": 2}
        if os.environ.get("FAKE_COPILOT_MISSING_DIRECT_FIELDS") != "1":
            usage.update({"cacheReadTokens": 3, "cacheWriteTokens": 0, "reasoningTokens": 1})
        rows = [
            {
                "type": "session.start",
                "data": {
                    "sessionId": session_id,
                    "selectedModel": event_model,
                    "context": {"cwd": event_cwd, "gitRoot": event_cwd},
                },
            },
            {"type": "system.message", "data": {"content": marker_content}},
        ]
        if agent:
            rows.append({"type": "subagent.selected", "data": {"agentName": agent}})
        rows.append(
            {
                "type": "session.shutdown",
                "data": {
                    "currentModel": event_model,
                    "totalPremiumRequests": 1,
                    "totalApiDurationMs": 1,
                    "modelMetrics": {
                        event_model: {
                            "requests": {"count": 1, "cost": 1},
                            "usage": usage,
                        }
                    },
                },
            }
        )
        path.write_text("\n".join(json.dumps(row, sort_keys=True) for row in rows) + "\n", encoding="utf-8")

print("OK")
PY
chmod +x "$fake_bin"

write_prompt() {
  local path="$1"
  printf 'Return only OK\n' > "$path"
}

run_phase() {
  local label="$1"
  shift
  mkdir -p "$tmpdir/$label/session-state" "$tmpdir/$label/out"
  write_prompt "$tmpdir/$label/prompt.md"
  FAKE_COPILOT_SESSION_STATE_BASE="$tmpdir/$label/session-state" \
    python3 tools/run_copilot_phase.py \
      --copilot-bin "$fake_bin" \
      --agent customer_newsletter \
      --model gpt-5.5 \
      --prompt-file "$tmpdir/$label/prompt.md" \
      --log "$tmpdir/$label/out/copilot.log" \
      --cwd "$(pwd)" \
      --phase-id "$label" \
      --session-out "$tmpdir/$label/out/events.jsonl" \
      --metrics-out "$tmpdir/$label/out/metrics.jsonl" \
      --session-state-base "$tmpdir/$label/session-state" \
      --require-session-log \
      --require-direct-token-fields \
      "$@" >/dev/null
}

run_phase positive
python3 - "$tmpdir/positive/out/metrics.jsonl" <<'PY'
import json
import sys
from pathlib import Path

row = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()[-1])
if row["exit_code"] != 0:
    raise SystemExit("positive row should exit 0")
if row["session_log_detection"]["status"] != "bound_candidate":
    raise SystemExit("expected bound session")
if row["missing_direct_provider_token_fields"]:
    raise SystemExit("expected all direct fields")
if row["command_argv"][-1] != "<prompt>":
    raise SystemExit("prompt body should be redacted from command argv")
PY

mkdir -p "$tmpdir/direct-fields-implies-binding/session-state" "$tmpdir/direct-fields-implies-binding/out"
write_prompt "$tmpdir/direct-fields-implies-binding/prompt.md"
set +e
FAKE_COPILOT_SESSION_STATE_BASE="$tmpdir/direct-fields-implies-binding/session-state" \
FAKE_COPILOT_MISSING_MARKER=1 \
  python3 tools/run_copilot_phase.py \
    --copilot-bin "$fake_bin" \
    --agent customer_newsletter \
    --model gpt-5.5 \
    --prompt-file "$tmpdir/direct-fields-implies-binding/prompt.md" \
    --log "$tmpdir/direct-fields-implies-binding/out/copilot.log" \
    --cwd "$(pwd)" \
    --phase-id direct_fields_implies_binding \
    --metrics-out "$tmpdir/direct-fields-implies-binding/out/metrics.jsonl" \
    --session-state-base "$tmpdir/direct-fields-implies-binding/session-state" \
    --require-direct-token-fields >/dev/null
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  echo "ASSERTION FAILED: --require-direct-token-fields must also require session binding"
  exit 1
fi

for scenario in no_session two_sessions wrong_cwd wrong_model missing_marker missing_direct_fields exit_empty; do
  export FAKE_COPILOT_NO_SESSION=0
  export FAKE_COPILOT_TWO_SESSIONS=0
  export FAKE_COPILOT_WRONG_CWD=0
  export FAKE_COPILOT_WRONG_MODEL=0
  export FAKE_COPILOT_MISSING_MARKER=0
  export FAKE_COPILOT_MISSING_DIRECT_FIELDS=0
  export FAKE_COPILOT_EXIT_EMPTY=0
  case "$scenario" in
    no_session) export FAKE_COPILOT_NO_SESSION=1 ;;
    two_sessions) export FAKE_COPILOT_TWO_SESSIONS=1 ;;
    wrong_cwd) export FAKE_COPILOT_WRONG_CWD=1 ;;
    wrong_model) export FAKE_COPILOT_WRONG_MODEL=1 ;;
    missing_marker) export FAKE_COPILOT_MISSING_MARKER=1 ;;
    missing_direct_fields) export FAKE_COPILOT_MISSING_DIRECT_FIELDS=1 ;;
    exit_empty) export FAKE_COPILOT_EXIT_EMPTY=1 ;;
  esac
  set +e
  run_phase "$scenario"
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "ASSERTION FAILED: $scenario should fail closed"
    exit 1
  fi
done

unset FAKE_COPILOT_NO_SESSION FAKE_COPILOT_TWO_SESSIONS FAKE_COPILOT_WRONG_CWD
unset FAKE_COPILOT_WRONG_MODEL FAKE_COPILOT_MISSING_MARKER
unset FAKE_COPILOT_MISSING_DIRECT_FIELDS FAKE_COPILOT_EXIT_EMPTY

mkdir -p "$tmpdir/diagnostic/session-state"
FAKE_COPILOT_SESSION_STATE_BASE="$tmpdir/diagnostic/session-state" \
  python3 tools/run_copilot_runtime_repair_diagnostic.py \
    --run-dir "$tmpdir/diagnostic/run" \
    --output "$tmpdir/diagnostic/receipt.json" \
    --copilot-bin "$fake_bin" \
    --session-state-base "$tmpdir/diagnostic/session-state" \
    --cwd "$(pwd)" >/dev/null

python3 - "$tmpdir/diagnostic/receipt.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["verdict"] != "runtime_repaired_with_direct_token_telemetry":
    raise SystemExit("expected diagnostic admission")
if payload["selected_variant"]["variant_id"] != "current_wrapper":
    raise SystemExit("expected current wrapper to qualify under fake copilot")
PY

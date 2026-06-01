#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

METRICS="$TMPDIR/metrics.jsonl"
python3 - "$METRICS" <<'PY'
import json
import sys

path = sys.argv[1]
phases = [
    ("json_output_smoke", ["--output-format", "json"], None),
    ("reasoning_effort_low_smoke", ["--reasoning-effort", "low"], "low"),
    ("reasoning_effort_medium_smoke", ["--reasoning-effort", "medium"], "medium"),
    ("reasoning_effort_high_smoke", ["--reasoning-effort", "high"], "high"),
    ("reasoning_summaries_smoke", ["--enable-reasoning-summaries"], None),
    ("log_dir_name_smoke", ["--log-dir", "logs", "--name", "burst46"], None),
    ("otel_file_export_smoke", [], None),
]
with open(path, "w") as handle:
    for phase, flags, effort in phases:
        row = {
            "phase_id": phase,
            "exit_code": 0,
            "session_status": "bound_candidate",
            "model": "gpt-5.5",
            "reasoning_effort": effort,
            "input_tokens": 10,
            "output_tokens": 1,
            "reasoning_tokens": 0,
            "cache_read_tokens": 0,
            "cache_write_tokens": 0,
            "request_count": 1,
            "tool_calls": 0,
            "direct_token_missing_fields": [],
            "command_argv": ["/opt/homebrew/bin/copilot", "--model", "gpt-5.5", *flags, "-p", "Return only OK"],
        }
        handle.write(json.dumps(row) + "\n")
PY

cat > "$TMPDIR/copilot-version.txt" <<'EOF'
GitHub Copilot CLI 1.0.44
EOF
cat > "$TMPDIR/copilot-help.txt" <<'EOF'
--output-format <text|json>
--reasoning-effort <level>
--enable-reasoning-summaries
--log-dir <dir>
--name <name>
EOF
cat > "$TMPDIR/update-help.txt" <<'EOF'
Usage: copilot update [options]
EOF
printf '{"name":"span"}\n' > "$TMPDIR/otel.jsonl"

python3 "$ROOT/tools/build_copilot_reporting_baseline_receipt.py" \
  --metrics "$METRICS" \
  --copilot-bin /opt/homebrew/bin/copilot \
  --version-output "$TMPDIR/copilot-version.txt" \
  --help-output "$TMPDIR/copilot-help.txt" \
  --update-help-output "$TMPDIR/update-help.txt" \
  --otel-file "$TMPDIR/otel.jsonl" \
  --output "$TMPDIR/reporting-receipt.json"

python3 - "$TMPDIR/reporting-receipt.json" <<'PY'
import json
import sys

receipt = json.load(open(sys.argv[1]))
assert receipt["verdict"] == "reporting_baseline_pass", receipt
assert receipt["flag_support"]["reasoning_effort"] is True, receipt
assert receipt["observable_fields"]["direct_tokens"] is True, receipt
PY

python3 - "$METRICS" <<'PY'
import json
import sys

path = sys.argv[1]
rows = [json.loads(line) for line in open(path)]
rows[1]["command_argv"] = [item for item in rows[1]["command_argv"] if item != "--reasoning-effort"]
open(path, "w").write("\n".join(json.dumps(row) for row in rows) + "\n")
PY

if python3 "$ROOT/tools/build_copilot_reporting_baseline_receipt.py" \
  --metrics "$METRICS" \
  --copilot-bin /opt/homebrew/bin/copilot \
  --version-output "$TMPDIR/copilot-version.txt" \
  --help-output "$TMPDIR/copilot-help.txt" \
  --update-help-output "$TMPDIR/update-help.txt" \
  --otel-file "$TMPDIR/otel.jsonl" \
  --output "$TMPDIR/reporting-negative.json"; then
  echo "expected missing reasoning flag binding to fail" >&2
  exit 1
fi

python3 - "$TMPDIR/reporting-negative.json" <<'PY'
import json
import sys

receipt = json.load(open(sys.argv[1]))
assert receipt["verdict"] == "reporting_baseline_fail_closed", receipt
assert any("reasoning_effort_low_smoke" in blocker for blocker in receipt["blockers"]), receipt
PY

echo "copilot reporting baseline receipt tests passed"

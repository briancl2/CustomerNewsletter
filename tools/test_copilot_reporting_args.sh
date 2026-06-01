#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT" <<'PY'
from pathlib import Path
from types import SimpleNamespace
import sys

sys.path.insert(0, sys.argv[1] + "/tools")
from run_copilot_phase import copilot_command

args = SimpleNamespace(
    copilot_bin=Path("/opt/homebrew/bin/copilot"),
    use_copilot_cwd_flag=True,
    cwd=Path("/tmp/example"),
    agent="customer_newsletter",
    available_tool=[""],
    excluded_tool=[],
    model="gpt-5.5",
    silent=True,
    output_format="json",
    log_level="debug",
    log_dir="/tmp/copilot-logs",
    name="burst46-test",
    reasoning_effort="low",
    enable_reasoning_summaries=True,
)
cmd = copilot_command(args, "Return only OK")
assert cmd[0].endswith("/copilot"), cmd
for flag in (
    "--reasoning-effort",
    "low",
    "--enable-reasoning-summaries",
    "--output-format",
    "json",
    "--log-dir",
    "/tmp/copilot-logs",
    "--name",
    "burst46-test",
):
    assert flag in cmd, cmd
assert cmd[-2:] == ["-p", "Return only OK"], cmd
PY

echo "copilot reporting args tests passed"

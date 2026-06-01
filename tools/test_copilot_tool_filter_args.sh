#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

python3 - <<'PY'
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path("tools").resolve()))
from run_copilot_phase import copilot_command

args = argparse.Namespace(
    agent="",
    model="gpt-5.5",
    copilot_bin="/opt/homebrew/bin/copilot",
    use_copilot_cwd_flag=False,
    cwd=".",
    available_tool=["write"],
    excluded_tool=["shell", "github"],
    silent=False,
    output_format=None,
    log_level=None,
    log_dir=None,
    name=None,
    reasoning_effort=None,
    enable_reasoning_summaries=False,
)

cmd = copilot_command(args, "Return only OK")
if "--available-tools" not in cmd:
    raise SystemExit("expected --available-tools in command")
if "--excluded-tools" not in cmd:
    raise SystemExit("expected --excluded-tools in command")
if cmd.index("--available-tools") > cmd.index("--allow-all"):
    raise SystemExit("expected tool visibility filters before permission grants")
if cmd[cmd.index("--available-tools") + 1] != "write":
    raise SystemExit("expected available tool filter to be preserved")
excluded = [
    cmd[index + 1]
    for index, value in enumerate(cmd)
    if value == "--excluded-tools"
]
if excluded != ["shell", "github"]:
    raise SystemExit(f"unexpected excluded tools: {excluded}")
print("PASS copilot tool filter args")
PY

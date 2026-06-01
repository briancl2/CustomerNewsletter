#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/policy.json" <<'JSON'
{
  "policy_id": "fixture-policy",
  "prompt_append": [
    "Use only the listed inputs.",
    "Run the validator at most twice."
  ]
}
JSON

python3 - "$tmpdir" <<'PY'
import json
import sys
from pathlib import Path

sys.path.insert(0, "tools")
import newsletter_phase_experimenter as exp

root = Path(sys.argv[1])
policy, policy_path = exp.load_phase3_prompt_policy(str(root / "policy.json"), Path.cwd())
assert policy["policy_id"] == "fixture-policy"
assert policy_path == (root / "policy.json").resolve()
assert exp.prompt_policy_text(policy) == "Use only the listed inputs.\nRun the validator at most twice."

base = "base prompt\n"
full = base + "policy append\n"
metadata_path = exp.write_phase3_prompt_metadata(
    run_dir=root / "run",
    base_prompt=base,
    full_prompt=full,
    policy=policy,
    policy_path=policy_path,
)
payload = json.loads(metadata_path.read_text(encoding="utf-8"))
assert payload["receipt_type"] == "phase3_prompt_policy_metadata"
assert payload["policy_enabled"] is True
assert payload["policy_id"] == "fixture-policy"
assert payload["base_prompt_sha256"] != payload["full_prompt_sha256"]
assert payload["policy_sha256"]

no_policy_path = exp.write_phase3_prompt_metadata(
    run_dir=root / "control",
    base_prompt=base,
    full_prompt=base,
    policy=None,
    policy_path=None,
)
control = json.loads(no_policy_path.read_text(encoding="utf-8"))
assert control["policy_enabled"] is False
assert control["policy_id"] is None
assert control["base_prompt_sha256"] == control["full_prompt_sha256"]
PY

cat > "$tmpdir/bad.json" <<'JSON'
{"prompt_append": "missing policy id"}
JSON
if python3 - "$tmpdir/bad.json" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, "tools")
import newsletter_phase_experimenter as exp
exp.load_phase3_prompt_policy(sys.argv[1], Path.cwd())
PY
then
  echo "expected missing policy_id to fail closed" >&2
  exit 1
fi

echo "PASS model routing prompt policy tests"

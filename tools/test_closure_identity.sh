#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

CLOSURE_IDENTITY_RECEIPT_PATH="$tmpdir/local.json" \
  python3 tools/emit_closure_identity.py \
    --phase check \
    --parent-command "make check" >"$tmpdir/local.out"

python3 - "$tmpdir/local.json" <<'PY'
import json
import re
import sys

payload = json.loads(open(sys.argv[1], encoding="utf-8").read())
required = {
    "closure_run_id",
    "closure_phase",
    "closure_trigger",
    "evidence_reuse_key",
    "parent_command",
    "github_run_id",
    "github_run_attempt",
}
missing = sorted(required - set(payload))
assert not missing, missing
assert re.match(r"^local-\d{8}T\d{6}Z-\d+$", payload["closure_run_id"]), payload
assert payload["closure_phase"] == "check", payload
assert payload["closure_trigger"] == "manual", payload
assert payload["parent_command"] == "make check", payload
assert payload["github_run_id"] is None, payload
assert payload["github_run_attempt"] is None, payload
assert payload["evidence_reuse_key"].startswith("check:make check:"), payload
PY

GITHUB_RUN_ID=12345 \
GITHUB_RUN_ATTEMPT=2 \
GITHUB_EVENT_NAME=pull_request \
PARENT_COMMAND="github-actions:ci" \
EVIDENCE_REUSE_KEY="CI Tests:refs/pull/1/merge:abcdef" \
  python3 tools/emit_closure_identity.py \
    --phase ci-validation \
    --parent-command "fallback" >"$tmpdir/ci.out"

python3 - "$tmpdir/ci.out" <<'PY'
import json
import sys

payload = json.loads(open(sys.argv[1], encoding="utf-8").read())
assert payload["closure_run_id"] == "12345-2", payload
assert payload["closure_phase"] == "ci-validation", payload
assert payload["closure_trigger"] == "pull_request", payload
assert payload["evidence_reuse_key"] == "CI Tests:refs/pull/1/merge:abcdef", payload
assert payload["parent_command"] == "github-actions:ci", payload
assert payload["github_run_id"] == "12345", payload
assert payload["github_run_attempt"] == "2", payload
PY

grep -q "closure_run_id" tools/emit_closure_identity.py
grep -q "evidence_reuse_key" tools/emit_closure_identity.py
grep -q "parent_command" tools/emit_closure_identity.py
grep -q "closure-identity" Makefile
grep -q "GITHUB_RUN_ID" .github/workflows/ci.yml
grep -q "GITHUB_RUN_ATTEMPT" .github/workflows/pages.yml

echo "PASS: closure identity emits local and GitHub correlation fields"

#!/usr/bin/env bash
# tests the shared external-critique calibration path on the newsletter proving ground
# requires sibling repo-agent-core, repo-upgrade-advisor, and repo-optimizer repos

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIBLING_ROOT="$(cd "$REPO_ROOT/.." && pwd)"
CORE_DIR="${REPO_AGENT_CORE:-$SIBLING_ROOT/repo-agent-core}"
ADVISOR_DIR="${REPO_UPGRADE_ADVISOR:-$SIBLING_ROOT/repo-upgrade-advisor}"
OPT_DIR="${REPO_OPTIMIZER:-$SIBLING_ROOT/repo-optimizer}"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/external_critique_proving_ground"
TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/newsletter-external-critique.XXXXXX")"
trap 'rm -rf "$TEST_TMPDIR"' EXIT INT TERM

for repo in "$CORE_DIR" "$ADVISOR_DIR" "$OPT_DIR"; do
  if [ ! -d "$repo" ]; then
    echo "SKIP: required sibling repo not found: $repo"
    exit 0
  fi
done

for script_path in \
  "$CORE_DIR/scripts/validate-artifacts.sh" \
  "$ADVISOR_DIR/scripts/build-advisory-decisions.py" \
  "$OPT_DIR/scripts/evaluate-advisory-transfer.py"; do
  if [ ! -f "$script_path" ]; then
    echo "SKIP: required sibling script not found: $script_path"
    exit 0
  fi
done

PASS=0
FAIL=0

check_cmd() {
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

echo "=== External Critique Proving Ground ==="

ADVISORY_OUT="$TEST_TMPDIR/ADVISORY_DECISIONS.json"
echo "  Building bounded advisory decisions..."
if ! python3 "$ADVISOR_DIR/scripts/build-advisory-decisions.py" \
  --briefs "$FIXTURE_DIR/agentic-root-cause-briefs.json" \
  --responses "$FIXTURE_DIR/consumer-responses.json" \
  --output "$ADVISORY_OUT"; then
  echo "ERROR: failed to build newsletter external-critique advisory decisions"
  exit 1
fi

RECEIPT_OUT="$TEST_TMPDIR/TRANSFER_ORACLE_RECEIPT.json"
echo "  Evaluating optimizer transfer receipt..."
if ! python3 "$OPT_DIR/scripts/evaluate-advisory-transfer.py" \
  --decisions "$ADVISORY_OUT" \
  --capability-family external_critique \
  --output "$RECEIPT_OUT"; then
  echo "ERROR: failed to evaluate newsletter external-critique transfer receipt"
  exit 1
fi

check_cmd "shared critique result fixture validates against repo-agent-core schema" \
  bash "$CORE_DIR/scripts/validate-artifacts.sh" "$FIXTURE_DIR/CRITIQUE_RESULT.json" CRITIQUE_RESULT
check_cmd "newsletter proving-ground transfer receipt validates against repo-agent-core schema" \
  bash "$CORE_DIR/scripts/validate-artifacts.sh" "$RECEIPT_OUT" TRANSFER_ORACLE_RECEIPT

check_cmd "advisor output preserves helper-only and bounded calibration rows" python3 - "$ADVISORY_OUT" <<'PY'
import json
import sys


def require_row(rows, key):
    row = rows.get(key)
    assert row is not None, f"missing decision row: {key}"
    return row


with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
rows = {row["hotspot_id"]: row for row in payload["decisions"]}
helper_only = require_row(rows, "prompt_family:external_critique")
bounded = require_row(rows, "prompt_family:external_critique_health")
assert helper_only.get("capability_state") == "helper_only", "helper-only row should stay helper_only"
assert helper_only.get("downstream_admission") == "blocked", "helper-only row should stay blocked"
assert bounded.get("capability_state") == "bounded_calibrated", "bounded anchor row should stay bounded_calibrated"
assert bounded.get("downstream_admission") == "bounded", "bounded anchor row should stay bounded"
assert helper_only.get("calibration_basis") == "external_critique_mixed_gate_v1", "helper-only row should carry the mixed gate basis"
assert bounded.get("calibration_basis") == "external_critique_mixed_gate_v1", "bounded row should carry the mixed gate basis"
PY

check_cmd "newsletter proving-ground receipt stays fail-closed and calibrated" python3 - "$RECEIPT_OUT" <<'PY'
import json
import sys


def require_row(rows, key):
    row = rows.get(key)
    assert row is not None, f"missing consumer guidance row: {key}"
    return row


with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
assert payload["transfer_state"] == "partial", "receipt should stay partial"
assert payload["verdict"] == "fail", "receipt should stay fail-closed"
assert payload["capability_state"] == "bounded_calibrated", "receipt should summarize the mixed gate as bounded_calibrated"
assert payload["downstream_admission"] == "bounded", "receipt should keep downstream admission bounded"
assert payload["calibration_basis"] == "external_critique_mixed_gate_v1", "receipt should carry the mixed gate basis"
rows = {row["hotspot_id"]: row for row in payload["consumer_guidance"]}
helper_only = require_row(rows, "prompt_family:external_critique")
bounded = require_row(rows, "prompt_family:external_critique_health")
assert helper_only.get("consumer_state") == "blocked", "helper-only row must stay blocked"
assert helper_only.get("capability_state") == "helper_only", "helper-only row must stay helper_only"
assert helper_only.get("downstream_admission") == "blocked", "helper-only row must keep blocked admission"
assert bounded.get("consumer_state") == "partial", "bounded row must stay partial"
assert bounded.get("capability_state") == "bounded_calibrated", "bounded row must stay bounded_calibrated"
assert bounded.get("downstream_admission") == "bounded", "bounded row must keep bounded admission"
PY

echo ""
echo "=== test_external_critique_proving_ground.sh: $PASS pass, $FAIL fail ==="
[ "$FAIL" -eq 0 ] || exit 1

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
start = "2026-02-14"
end = "2026-04-16"

def write(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

for label in ("control", "candidate"):
    run_dir = case / label
    write(
        run_dir / "run-metadata.json",
        {
            "start": start,
            "end": end,
            "dirty_files": [],
        },
    )
    marker_epoch = 100 if label == "control" else 200
    marker = {
        "marker_version": 2,
        "run_id": f"{label}-run",
        "start": start,
        "end": end,
        "prepared_at_epoch": marker_epoch,
    }
    if label == "candidate":
        marker["phase_experiment"] = "phase3-curation"
        marker["source_fixture_run_id"] = "full-run"
    write(run_dir / "artifacts" / "workspace" / f"newsletter_run_marker_{start}_to_{end}.json", marker)
    write(
        run_dir / "artifacts" / "workspace" / f"newsletter_phase_receipts_{end}.json",
        {
            "schema_version": 2,
            "run_id": f"{label}-run",
            "start": start,
            "end": end,
            "receipts": [
                {
                    "phase_id": "phase0_scope_contract",
                    "artifact_path": "workspace/newsletter_scope_contract_2026-04-16.json",
                    "artifact_mtime_epoch": 120,
                    "recorded_at_epoch": 120,
                    "receipt_order": 1,
                    "run_id": f"{label}-run",
                }
            ],
        },
    )
PY
}

run_builder() {
  local case_dir="$1"
  python3 tools/build_artifact_staleness_origin_receipt.py \
    --control-run-dir "$case_dir/control" \
    --candidate-run-dir "$case_dir/candidate" \
    --output "$case_dir/receipt.json"
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

echo "=== artifact staleness origin receipt ==="

BUG="$TMPDIR/wrapper-marker-bug"
make_case "$BUG"
check "wrapper marker refresh bug classifies" run_builder "$BUG"
check "classification is wrapper materialization timestamp bug" assert_json "$BUG/receipt.json" "payload['classification'] == 'wrapper_materialization_timestamp_bug'"

MISSING="$TMPDIR/missing-marker"
make_case "$MISSING"
rm "$MISSING/candidate/artifacts/workspace/newsletter_run_marker_2026-02-14_to_2026-04-16.json"
if run_builder "$MISSING" >/dev/null 2>&1; then
  false
else
  true
fi
check "missing marker fails closed" assert_json "$MISSING/receipt.json" "payload['verdict'] == 'fail_closed_unresolved_staleness_origin'"

CONTROL_STALE="$TMPDIR/control-stale"
make_case "$CONTROL_STALE"
python3 - "$CONTROL_STALE/control/artifacts/workspace/newsletter_run_marker_2026-02-14_to_2026-04-16.json" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
payload = json.loads(path.read_text())
payload["prepared_at_epoch"] = 200
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
if run_builder "$CONTROL_STALE" >/dev/null 2>&1; then
  false
else
  true
fi
check "stale control baseline fails closed" assert_json "$CONTROL_STALE/receipt.json" "'control baseline is not clean' in '\\n'.join(payload['blockers'])"

DIRTY_STATUS="$TMPDIR/dirty-status"
make_case "$DIRTY_STATUS"
python3 - "$DIRTY_STATUS/candidate/run-metadata.json" "$DIRTY_STATUS/candidate/artifacts/workspace/newsletter_run_marker_2026-02-14_to_2026-04-16.json" <<'PY'
import json
import sys
from pathlib import Path
metadata = Path(sys.argv[1])
marker = Path(sys.argv[2])
payload = json.loads(metadata.read_text())
payload["dirty_files"] = ["A  workspace/generated.md"]
metadata.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
marker_payload = json.loads(marker.read_text())
marker_payload["prepared_at_epoch"] = 100
marker_payload.pop("phase_experiment", None)
marker.write_text(json.dumps(marker_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
check "staged generated dirty state classifies" run_builder "$DIRTY_STATUS"
check "staged generated status is recognized" assert_json "$DIRTY_STATUS/receipt.json" "payload['classification'] == 'inherited_generated_artifacts'"

STATIC="$TMPDIR/static-contract"
make_case "$STATIC"
check "orchestrator preserves full-run provenance for stdout/no-tools" bash -c \
  "rg -q -- '--preserve-existing-provenance' tools/run_newsletter_orchestrated.sh"
check "runner supports provenance preservation flag" bash -c \
  "rg -q 'preserve-existing-provenance' tools/run_phase3_stdout_no_tools_artifact_reuse.py"

echo ""
echo "=== test_artifact_staleness_origin_receipt.sh: $PASS pass, $FAIL fail ==="
[ "$FAIL" -eq 0 ]

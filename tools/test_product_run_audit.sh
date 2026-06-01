#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p \
  "$tmpdir/tools" \
  "$tmpdir/workspace" \
  "$tmpdir/output" \
  "$tmpdir/run/proof/artifacts/workspace" \
  "$tmpdir/run/proof/artifacts/output" \
  "$tmpdir/run/proof/session" \
  "$tmpdir/.github/skills/newsletter-validation/scripts"

cp tools/collect_product_run_audit.py "$tmpdir/tools/"
cp tools/validate_pipeline_strict.sh "$tmpdir/tools/"
cp tools/validate_phase2_event_quality.py "$tmpdir/tools/"
cp tools/validate_phase3_curated.py "$tmpdir/tools/"
cp tools/product_run_common.py "$tmpdir/tools/"
cp tools/score-v2-rubric.sh "$tmpdir/tools/"
cp .github/skills/newsletter-validation/scripts/validate_newsletter.sh \
  "$tmpdir/.github/skills/newsletter-validation/scripts/"

bash tools/materialize_committed_product_fixture.sh \
  2026-02-14 \
  2026-04-16 \
  "$tmpdir/run/proof/artifacts"

source_ref_repo="$tmpdir/source-ref-repo"
git clone -q . "$source_ref_repo"
cp tools/materialize_committed_product_fixture.sh "$source_ref_repo/tools/"
printf 'mutated live source discoveries\n' \
  > "$source_ref_repo/workspace/newsletter_phase1a_discoveries_2026-02-14_to_2026-04-16.md"
printf '# mutated live source output\n' \
  > "$source_ref_repo/output/2026-04_april_newsletter.md"
(
  cd "$source_ref_repo"
  bash tools/materialize_committed_product_fixture.sh \
    2026-02-14 \
    2026-04-16 \
    "$tmpdir/source-ref-proof/artifacts"
)
if grep -Fq "mutated live source" \
  "$tmpdir/source-ref-proof/artifacts/workspace/newsletter_phase1a_discoveries_2026-02-14_to_2026-04-16.md"; then
  echo "ASSERTION FAILED: materializer copied mutable live workspace instead of source ref"
  exit 1
fi
if grep -Fq "mutated live source" \
  "$tmpdir/source-ref-proof/artifacts/output/2026-04_april_newsletter.md"; then
  echo "ASSERTION FAILED: materializer copied mutable live output instead of source ref"
  exit 1
fi

cat > "$tmpdir/run/proof/session/events.jsonl" <<'EOF'
{"type":"session.start","timestamp":"2026-04-16T00:00:00Z","data":{"sessionId":"fixture"}}
{"type":"tool.execution_start","timestamp":"2026-04-16T00:00:15Z","data":{"toolCallId":"call-view","toolName":"view"}}
{"type":"hook.start","timestamp":"2026-04-16T00:00:30Z","data":{"hookType":"postToolUse","input":{"toolName":"get_errors"}}}
{"type":"tool.execution_complete","timestamp":"2026-04-16T00:00:35Z","data":{"toolCallId":"call-view","success":true}}
{"type":"tool.execution_start","timestamp":"2026-04-16T00:00:45Z","data":{"toolCallId":"call-bash","toolName":"bash"}}
{"type":"tool.execution_complete","timestamp":"2026-04-16T00:01:00Z","data":{"toolCallId":"call-bash","success":true}}
{"type":"session.shutdown","timestamp":"2026-04-16T00:01:05Z","data":{"reason":"completed"}}
EOF

cat > "$tmpdir/run/proof/run-metadata.json" <<'EOF'
{
  "schema_version": 1,
  "start": "2026-02-14",
  "end": "2026-04-16",
  "mode": "production",
  "start_epoch": 1776301224,
  "started_at_utc": "2026-04-16T01:00:24Z",
  "notes": [
    "fixture metadata"
  ]
}
EOF

printf 'corrupted live discoveries\n' > "$tmpdir/workspace/newsletter_phase1a_discoveries_2026-02-14_to_2026-04-16.md"
printf '# broken live output\n' > "$tmpdir/output/2026-04_april_newsletter.md"

git -C "$tmpdir" init -q

run_root="$tmpdir/run/proof"
audit_dir="$run_root/audit"
mkdir -p "$audit_dir"

snapshot_manifest="$tmpdir/snapshot-before.json"
python3 - "$run_root/artifacts" "$snapshot_manifest" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

artifact_root = Path(sys.argv[1]).resolve()
manifest_path = Path(sys.argv[2]).resolve()
snapshot = {}
for path in sorted(artifact_root.rglob("*")):
    if not path.is_file():
        continue
    rel = path.relative_to(artifact_root).as_posix()
    snapshot[rel] = {
        "mtime_ns": path.stat().st_mtime_ns,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }
manifest_path.write_text(json.dumps(snapshot, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

(
  cd "$tmpdir"
  python3 tools/collect_product_run_audit.py \
    2026-02-14 \
    2026-04-16 \
    --mode production \
    --run-dir "$audit_dir"
)

for required in \
  RUN_AUDIT.md \
  RUN_AUDIT.json \
  session-log-summary.md \
  git-history-summary.md \
  strict-gap-report.md \
  environment-receipt.md; do
  if [ ! -f "$audit_dir/$required" ]; then
    echo "ASSERTION FAILED: missing audit artifact $required"
    exit 1
  fi
done

if [ ! -f "$audit_dir/strict-validator-report.md" ]; then
  echo "ASSERTION FAILED: missing sidecar strict validator report"
  exit 1
fi

python3 - "$run_root/artifacts" "$snapshot_manifest" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

artifact_root = Path(sys.argv[1]).resolve()
baseline_path = Path(sys.argv[2]).resolve()
baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
current = {}
for path in sorted(artifact_root.rglob("*")):
    if not path.is_file():
        continue
    rel = path.relative_to(artifact_root).as_posix()
    current[rel] = {
        "mtime_ns": path.stat().st_mtime_ns,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }

if current != baseline:
    raise SystemExit("retained artifact snapshot changed during audit replay")
PY

python3 - "$audit_dir/RUN_AUDIT.json" "$run_root" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
run_root = Path(sys.argv[2]).resolve()
payload = json.loads(path.read_text(encoding="utf-8"))

if payload.get("mode") != "production":
    raise SystemExit("mode mismatch")
if Path(payload.get("artifact_root", "")).resolve() != (run_root / "artifacts").resolve():
    raise SystemExit("artifact_root mismatch")
session_log = payload.get("session_log", {})
if not session_log.get("present"):
    raise SystemExit("session log should be marked present")
if session_log.get("tool_calls", 0) < 2:
    raise SystemExit("expected at least two tool calls")
if session_log.get("tool_counts", {}).get("view") != 1:
    raise SystemExit("expected one view tool call from current schema fixture")
if session_log.get("tool_counts", {}).get("bash") != 1:
    raise SystemExit("expected one bash tool call from current schema fixture")
if session_log.get("tool_counts", {}).get("get_errors") is not None:
    raise SystemExit("hook input tool name should not be counted as tool call")
if session_log.get("error_events") != 0:
    raise SystemExit("expected zero error events for current schema fixture")

artifact = payload.get("artifacts", {}).get("phase1b_github", {})
expected_logical = "workspace/newsletter_phase1b_interim_github_2026-02-14_to_2026-04-16.md"
if artifact.get("logical_path") != expected_logical:
    raise SystemExit("phase1b_github logical path mismatch")
if not artifact.get("exists"):
    raise SystemExit("phase1b_github should exist in snapshot")
resolved = Path(artifact.get("resolved_path", "")).resolve()
if not str(resolved).startswith(str((run_root / "artifacts").resolve())):
    raise SystemExit("collector should point at retained artifact snapshot, not live workspace")
print("PASS: audit json structure checks passed")
PY

set +e
missing_output="$(
  cd "$tmpdir" && python3 tools/collect_product_run_audit.py \
    2026-02-14 \
    2026-04-16 \
    --mode production \
    --run-dir "$tmpdir/missing-audit" 2>&1
)"
missing_rc=$?
set -e

if [ "$missing_rc" -eq 0 ]; then
  echo "ASSERTION FAILED: collector should fail closed when no retained artifact snapshot exists"
  exit 1
fi

if ! grep -Fq "No retained artifact snapshot found" <<<"$missing_output"; then
  echo "ASSERTION FAILED: missing fail-closed message"
  echo "$missing_output"
  exit 1
fi

echo "PASS: product run audit tests passed"

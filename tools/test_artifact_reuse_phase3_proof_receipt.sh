#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

make_run() {
  local dir="$1"
  local input_tokens="$2"
  local output_tokens="$3"
  local requests="$4"
  mkdir -p "$dir/session" "$dir/prompts"
  cat > "$dir/summary.md" <<EOF
# Phase 3 Curation Experiment Summary
- Run ID: fixture
- Date Range: 2025-12-05 to 2026-02-13
- Model: gpt-5.5
- Build Return Code: 0
- Working Set Receipt Return Code: 0
- Init Return Code: 0
- Phase Return Code: 0
- Signature Scan Return Code: 0
- Validation Return Code: 0
- Curated Receipt Return Code: 0
- Overall Return Code: 0
- Final Status: pass
EOF
  cat > "$dir/session/phase-session-metrics.jsonl" <<EOF
{"phase_id":"phase3_curation","model":"gpt-5.5","exit_code":0,"original_prompt_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","prompt_sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","prompt_binding_marker_included":true,"session_log_detection":{"status":"bound_candidate","bound_candidate_count":1},"direct_provider_token_fields_present":["inputTokens","outputTokens","cacheReadTokens","cacheWriteTokens","reasoningTokens"],"missing_direct_provider_token_fields":[],"token_usage":{"source":"session.shutdown.modelMetrics","input_tokens":$input_tokens,"output_tokens":$output_tokens,"cache_read_tokens":0,"cache_write_tokens":0,"reasoning_tokens":10,"request_count":$requests,"tool_calls":2}}
EOF
}

make_run "$tmpdir/control-run" 1000 100 4
make_run "$tmpdir/reuse-run" 800 90 4

mkdir -p "$tmpdir/control-repo/workspace" "$tmpdir/reuse-repo/workspace"
python3 - "$tmpdir" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
workspace = root / "reuse-repo" / "workspace"
selected_ids = [{"source_id": "a"}]
selected = {
    "selected_source_ids": selected_ids,
    "selection_manifest_sha256": "s",
    "event_sources_sha256": "e",
}
fetch = {
    "network_access_permitted": False,
    "fetch_attempt_count": 0,
    "fetch_attempts": [],
    "selection_manifest_sha256": "s",
    "event_sources_sha256": "e",
}
selected_path = workspace / "newsletter_phase2_selected_source_ids_2026-02-13.json"
fetch_path = workspace / "newsletter_phase2_fetch_attempt_ledger_2026-02-13.json"
selected_path.write_text(json.dumps(selected) + "\n", encoding="utf-8")
fetch_path.write_text(json.dumps(fetch) + "\n", encoding="utf-8")
compliance = {
    "compliance": "pass",
    "network_access_permitted": False,
    "fetch_attempt_count": 0,
    "selection_manifest_sha256": "s",
    "event_sources_sha256": "e",
    "phase2_events_sha256": "p",
    "selected_source_ids_sha256": hashlib.sha256(selected_path.read_bytes()).hexdigest(),
    "fetch_attempt_ledger_sha256": hashlib.sha256(fetch_path.read_bytes()).hexdigest(),
}
(workspace / "newsletter_phase2_no_refetch_compliance_2026-02-13.json").write_text(
    json.dumps(compliance) + "\n", encoding="utf-8"
)
admission = {
    "admission_verdict": "admit_no_refetch",
    "selected_source_count": 1,
    "selected_source_ids": selected_ids,
    "source_pack_sha256": "p",
    "renderer_or_prompt_hash": "r",
    "selection_manifest_sha256": "s",
    "event_sources_sha256": "e",
}
(root / "admission.json").write_text(json.dumps(admission) + "\n", encoding="utf-8")
PY

python3 tools/build_artifact_reuse_phase3_proof_receipt.py \
  --control-run-dir "$tmpdir/control-run" \
  --reuse-run-dir "$tmpdir/reuse-run" \
  --control-repo "$tmpdir/control-repo" \
  --reuse-repo "$tmpdir/reuse-repo" \
  --no-refetch-admission "$tmpdir/admission.json" \
  --output "$tmpdir/pass.json"

python3 - "$tmpdir/pass.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["qualification"]["verdict"] == "qualified_positive_signal"
assert payload["qualification"]["rows_qualified"] is True
assert payload["deltas"]["input_tokens_delta"] == -200
assert payload["prompt_equality"]["original_prompt_sha256_match"] is True
assert payload["model_equality"]["model_match"] is True
assert payload["reuse_no_refetch_binding"]["pass"] is True
PY

python3 - "$tmpdir/reuse-run/session/phase-session-metrics.jsonl" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
row = json.loads(path.read_text(encoding="utf-8"))
row["model"] = "gpt-5.4"
path.write_text(json.dumps(row) + "\n", encoding="utf-8")
PY

if python3 tools/build_artifact_reuse_phase3_proof_receipt.py \
  --control-run-dir "$tmpdir/control-run" \
  --reuse-run-dir "$tmpdir/reuse-run" \
  --control-repo "$tmpdir/control-repo" \
  --reuse-repo "$tmpdir/reuse-repo" \
  --no-refetch-admission "$tmpdir/admission.json" \
  --output "$tmpdir/model-mismatch.json"; then
  echo "Expected model mismatch to fail closed"
  exit 1
fi

python3 - "$tmpdir/model-mismatch.json" "$tmpdir/reuse-run/session/phase-session-metrics.jsonl" <<'PY'
import json
import sys
from pathlib import Path

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["qualification"]["verdict"] == "blocked_incomplete_evidence"
assert any("models do not match" in item for item in payload["qualification"]["blockers"])
path = Path(sys.argv[2])
row = json.loads(path.read_text(encoding="utf-8"))
row["model"] = "gpt-5.5"
path.write_text(json.dumps(row) + "\n", encoding="utf-8")
PY

python3 - "$tmpdir/reuse-run/session/phase-session-metrics.jsonl" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
row = json.loads(path.read_text(encoding="utf-8"))
row["token_usage"]["input_tokens"] = None
path.write_text(json.dumps(row) + "\n", encoding="utf-8")
PY

if python3 tools/build_artifact_reuse_phase3_proof_receipt.py \
  --control-run-dir "$tmpdir/control-run" \
  --reuse-run-dir "$tmpdir/reuse-run" \
  --control-repo "$tmpdir/control-repo" \
  --reuse-repo "$tmpdir/reuse-repo" \
  --no-refetch-admission "$tmpdir/admission.json" \
  --output "$tmpdir/missing-numeric.json"; then
  echo "Expected missing numeric telemetry to fail closed"
  exit 1
fi

python3 - "$tmpdir/missing-numeric.json" "$tmpdir/reuse-run/session/phase-session-metrics.jsonl" <<'PY'
import json
import sys
from pathlib import Path

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["qualification"]["verdict"] == "blocked_incomplete_evidence"
assert any("numeric token telemetry" in item for item in payload["qualification"]["blockers"])
path = Path(sys.argv[2])
row = json.loads(path.read_text(encoding="utf-8"))
row["token_usage"]["input_tokens"] = 800
path.write_text(json.dumps(row) + "\n", encoding="utf-8")
PY

python3 - "$tmpdir/reuse-repo/workspace/newsletter_phase2_selected_source_ids_2026-02-13.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["selected_source_ids"][0]["source_id"] = "tampered"
path.write_text(json.dumps(payload) + "\n", encoding="utf-8")
PY

if python3 tools/build_artifact_reuse_phase3_proof_receipt.py \
  --control-run-dir "$tmpdir/control-run" \
  --reuse-run-dir "$tmpdir/reuse-run" \
  --control-repo "$tmpdir/control-repo" \
  --reuse-repo "$tmpdir/reuse-repo" \
  --no-refetch-admission "$tmpdir/admission.json" \
  --output "$tmpdir/binding-mismatch.json"; then
  echo "Expected selected-source binding mismatch to fail closed"
  exit 1
fi

python3 - "$tmpdir/binding-mismatch.json" "$tmpdir/reuse-repo/workspace/newsletter_phase2_selected_source_ids_2026-02-13.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["qualification"]["verdict"] == "blocked_incomplete_evidence"
assert any("selected-source IDs" in item for item in payload["qualification"]["blockers"])
path = Path(sys.argv[2])
selected = json.loads(path.read_text(encoding="utf-8"))
selected["selected_source_ids"][0]["source_id"] = "a"
path.write_text(json.dumps(selected) + "\n", encoding="utf-8")
PY

python3 - "$tmpdir/reuse-run/session/phase-session-metrics.jsonl" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
row = json.loads(path.read_text(encoding="utf-8"))
row["missing_direct_provider_token_fields"] = ["inputTokens"]
row["direct_provider_token_fields_present"] = ["outputTokens"]
path.write_text(json.dumps(row) + "\n", encoding="utf-8")
PY

if python3 tools/build_artifact_reuse_phase3_proof_receipt.py \
  --control-run-dir "$tmpdir/control-run" \
  --reuse-run-dir "$tmpdir/reuse-run" \
  --control-repo "$tmpdir/control-repo" \
  --reuse-repo "$tmpdir/reuse-repo" \
  --no-refetch-admission "$tmpdir/admission.json" \
  --output "$tmpdir/missing-direct.json"; then
  echo "Expected missing direct token fields to fail"
  exit 1
fi

python3 - "$tmpdir/missing-direct.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["qualification"]["verdict"] == "blocked_incomplete_evidence"
assert any("direct provider token fields" in item for item in payload["qualification"]["blockers"])
PY

python3 - "$tmpdir/reuse-run/summary.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("- Phase Return Code: 0", "- Phase Return Code: None")
text = text.replace("- Overall Return Code: 0", "- Overall Return Code: None")
path.write_text(text, encoding="utf-8")
PY

if python3 tools/build_artifact_reuse_phase3_proof_receipt.py \
  --control-run-dir "$tmpdir/control-run" \
  --reuse-run-dir "$tmpdir/reuse-run" \
  --control-repo "$tmpdir/control-repo" \
  --reuse-repo "$tmpdir/reuse-repo" \
  --no-refetch-admission "$tmpdir/admission.json" \
  --output "$tmpdir/none-return-code.json"; then
  echo "Expected None return codes to fail closed"
  exit 1
fi

python3 - "$tmpdir/none-return-code.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["qualification"]["verdict"] == "blocked_incomplete_evidence"
assert payload["reuse"]["summary"]["overall_return_code"] == 999
assert any("summary did not pass" in item for item in payload["qualification"]["blockers"])
PY

echo "PASS: artifact reuse Phase 3 proof receipt"

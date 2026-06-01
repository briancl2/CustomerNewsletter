#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/artifacts/workspace"

python3 - "$tmpdir" <<'PY'
import json
import sys
from pathlib import Path

tmpdir = Path(sys.argv[1])
event_sources = {
    "schema_version": 1,
    "start": "2025-12-05",
    "end": "2026-02-13",
    "candidate_urls": [
        {
            "url": "https://example.test/event-a",
            "source_types": ["fixture"],
            "source_names": ["fixture_source"],
        },
        {
            "url": "https://example.test/event-b",
            "source_types": ["fixture"],
            "source_names": ["fixture_source"],
        },
    ],
}
selection = {
    "schema_version": 1,
    "start": "2025-12-05",
    "end": "2026-02-13",
    "virtual_events": [
        {
            "source_id": "https://example.test/event-a",
            "title": "Event A",
            "date_label": "Feb 01",
        }
    ],
    "in_person_events": [
        {
            "source_id": "https://example.test/event-b",
            "title": "Event B",
            "date_label": "Feb 02",
        }
    ],
}
bad_selection = {
    **selection,
    "virtual_events": [
        {
            "source_id": "https://example.test/missing",
            "title": "Missing",
            "date_label": "Feb 03",
        }
    ],
    "in_person_events": [],
}
workspace = tmpdir / "artifacts" / "workspace"
(workspace / "newsletter_phase2_event_sources_2026-02-13.json").write_text(
    json.dumps(event_sources, indent=2) + "\n",
    encoding="utf-8",
)
(tmpdir / "selection.json").write_text(json.dumps(selection, indent=2) + "\n", encoding="utf-8")
(tmpdir / "bad-selection.json").write_text(json.dumps(bad_selection, indent=2) + "\n", encoding="utf-8")
PY

event_sources_sha="$(shasum -a 256 "$tmpdir/artifacts/workspace/newsletter_phase2_event_sources_2026-02-13.json" | awk '{print $1}')"

python3 - "$tmpdir/manifest.json" "$tmpdir" "$event_sources_sha" <<'PY'
import json
import sys
from pathlib import Path

manifest = Path(sys.argv[1])
tmpdir = Path(sys.argv[2])
event_sources_sha = sys.argv[3]
payload = {
    "schema_version": 1,
    "manifest_id": "test-manifest",
    "run_id": "test-run",
    "start": "2025-12-05",
    "end": "2026-02-13",
    "mode": "benchmark",
    "source_artifact_root": str(tmpdir / "artifacts"),
    "surfaces": {
        "phase2_entry_surface": [
            {
                "artifact_name": "event_sources",
                "logical_path": "workspace/newsletter_phase2_event_sources_2026-02-13.json",
                "source_path": str(tmpdir / "artifacts/workspace/newsletter_phase2_event_sources_2026-02-13.json"),
                "exists": True,
                "sha256": event_sources_sha,
                "size_bytes": 1,
            }
        ]
    },
}
manifest.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

python3 - "$tmpdir/manifest.json" "$tmpdir/hash-mismatch-manifest.json" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.load(open(sys.argv[1], encoding="utf-8"))
manifest["surfaces"]["phase2_entry_surface"][0]["sha256"] = "0" * 64
Path(sys.argv[2]).write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY

python3 tools/build_artifact_reuse_no_refetch_receipt.py \
  --manifest "$tmpdir/manifest.json" \
  --selection-manifest "$tmpdir/selection.json" \
  --artifact-output-dir "$tmpdir/generated" \
  --output "$tmpdir/admitted.json"

if python3 tools/build_artifact_reuse_no_refetch_receipt.py \
  --manifest "$tmpdir/manifest.json" \
  --selection-manifest "$tmpdir/bad-selection.json" \
  --output "$tmpdir/blocked.json"; then
  echo "Expected missing selected source negative control to fail"
  exit 1
fi

if python3 tools/build_artifact_reuse_no_refetch_receipt.py \
  --manifest "$tmpdir/hash-mismatch-manifest.json" \
  --selection-manifest "$tmpdir/selection.json" \
  --output "$tmpdir/hash-mismatch.json"; then
  echo "Expected retained event source hash mismatch negative control to fail"
  exit 1
fi

python3 - "$tmpdir/admitted.json" "$tmpdir/blocked.json" "$tmpdir/hash-mismatch.json" "$tmpdir/generated" <<'PY'
import json
import sys
from pathlib import Path

admitted = json.load(open(sys.argv[1], encoding="utf-8"))
blocked = json.load(open(sys.argv[2], encoding="utf-8"))
hash_mismatch = json.load(open(sys.argv[3], encoding="utf-8"))
generated = Path(sys.argv[4])

assert admitted["admission_verdict"] == "admit_no_refetch"
assert admitted["selected_source_count"] == 2
assert admitted["fetch_attempt_ledger"]["network_access_permitted"] is False
assert admitted["fetch_attempt_ledger"]["fetch_attempt_count"] == 0
assert admitted["no_refetch_compliance"] == "pass"
assert admitted["renderer_or_prompt_hash"]
assert admitted["source_pack_sha256"]
assert admitted["validator_audit_input_hashes"]
generated_hashes = admitted["generated_artifacts"]
assert generated_hashes["phase2_selected_source_ids"]["sha256"]
assert generated_hashes["phase2_fetch_attempt_ledger"]["sha256"]
assert generated_hashes["phase2_no_refetch_compliance"]["sha256"]
assert (generated / "newsletter_phase2_selected_source_ids_2026-02-13.json").exists()
assert (generated / "newsletter_phase2_fetch_attempt_ledger_2026-02-13.json").exists()
assert (generated / "newsletter_phase2_no_refetch_compliance_2026-02-13.json").exists()
compliance = json.load(open(generated / "newsletter_phase2_no_refetch_compliance_2026-02-13.json", encoding="utf-8"))
assert compliance["selected_source_ids_sha256"] == generated_hashes["phase2_selected_source_ids"]["sha256"]
assert compliance["fetch_attempt_ledger_sha256"] == generated_hashes["phase2_fetch_attempt_ledger"]["sha256"]

assert blocked["admission_verdict"] == "blocked"
assert any("not present" in item for item in blocked["blockers"])
assert blocked["non_claims"]

assert hash_mismatch["admission_verdict"] == "blocked"
assert any("hash mismatch" in item for item in hash_mismatch["blockers"])
PY

echo "PASS: artifact reuse no-refetch receipt"

#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/artifacts/workspace"
printf 'events\n' > "$tmpdir/artifacts/workspace/events.md"
printf 'selected ids\n' > "$tmpdir/artifacts/workspace/selected.json"
printf 'fetch ledger\n' > "$tmpdir/artifacts/workspace/fetch.json"
printf 'no refetch\n' > "$tmpdir/artifacts/workspace/no-refetch.json"

events_sha="$(shasum -a 256 "$tmpdir/artifacts/workspace/events.md" | awk '{print $1}')"
selected_sha="$(shasum -a 256 "$tmpdir/artifacts/workspace/selected.json" | awk '{print $1}')"
fetch_sha="$(shasum -a 256 "$tmpdir/artifacts/workspace/fetch.json" | awk '{print $1}')"
no_refetch_sha="$(shasum -a 256 "$tmpdir/artifacts/workspace/no-refetch.json" | awk '{print $1}')"

manifest="$tmpdir/manifest.json"
python3 - "$manifest" "$tmpdir" "$events_sha" "$selected_sha" "$fetch_sha" "$no_refetch_sha" <<'PY'
import json
import sys
from pathlib import Path

manifest = Path(sys.argv[1])
tmpdir = Path(sys.argv[2])
events_sha, selected_sha, fetch_sha, no_refetch_sha = sys.argv[3:]
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
                "artifact_name": "phase2_events",
                "logical_path": "workspace/events.md",
                "source_path": str(tmpdir / "artifacts/workspace/events.md"),
                "exists": True,
                "sha256": events_sha,
                "size_bytes": 7,
            }
        ],
        "phase2_reuse_surface": [
            {
                "artifact_name": "phase2_events",
                "logical_path": "workspace/events.md",
                "source_path": str(tmpdir / "artifacts/workspace/events.md"),
                "exists": True,
                "sha256": events_sha,
                "size_bytes": 7,
            },
            {
                "artifact_name": "phase2_selected_source_ids",
                "logical_path": "workspace/selected.json",
                "source_path": str(tmpdir / "artifacts/workspace/selected.json"),
                "exists": True,
                "sha256": selected_sha,
                "size_bytes": 13,
            },
            {
                "artifact_name": "phase2_fetch_attempt_ledger",
                "logical_path": "workspace/fetch.json",
                "source_path": str(tmpdir / "artifacts/workspace/fetch.json"),
                "exists": True,
                "sha256": fetch_sha,
                "size_bytes": 13,
            },
            {
                "artifact_name": "phase2_no_refetch_compliance",
                "logical_path": "workspace/no-refetch.json",
                "source_path": str(tmpdir / "artifacts/workspace/no-refetch.json"),
                "exists": True,
                "sha256": no_refetch_sha,
                "size_bytes": 11,
            },
        ],
    },
}
manifest.write_text(json.dumps(payload), encoding="utf-8")
PY

if python3 tools/build_artifact_reuse_admission_receipt.py \
  --manifest "$manifest" \
  --surface-id phase2_entry_surface \
  --require-no-refetch-audit \
  --output "$tmpdir/blocked.json"; then
  echo "Expected no-refetch audit negative control to fail"
  exit 1
fi

python3 tools/build_artifact_reuse_admission_receipt.py \
  --manifest "$manifest" \
  --surface-id phase2_reuse_surface \
  --require-no-refetch-audit \
  --output "$tmpdir/admitted.json"

python3 - "$tmpdir/blocked.json" "$tmpdir/admitted.json" <<'PY'
import json
import sys

blocked = json.load(open(sys.argv[1], encoding="utf-8"))
admitted = json.load(open(sys.argv[2], encoding="utf-8"))
assert blocked["overall_verdict"] == "blocked"
assert blocked["surfaces"][0]["verdict"] == "blocked_missing_no_refetch_audit"
assert admitted["overall_verdict"] == "admit_static_probe"
assert admitted["surfaces"][0]["token_proxy_estimate"] > 0
assert admitted["non_claims"]
PY

echo "PASS: artifact reuse admission receipt"

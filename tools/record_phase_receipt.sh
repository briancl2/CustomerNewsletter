#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

usage() {
  cat <<'USAGE'
Usage: bash tools/record_phase_receipt.sh <START_DATE> <END_DATE> <PHASE_ID> <ARTIFACT_PATH>

Records a deterministic phase receipt for strict provenance validation.

Examples:
  bash tools/record_phase_receipt.sh 2025-12-05 2026-02-13 phase1a_manifest workspace/newsletter_phase1a_url_manifest_2025-12-05_to_2026-02-13.md
  bash tools/record_phase_receipt.sh 2025-12-05 2026-02-13 phase4_output output/2026-02_february_newsletter.md
USAGE
}

if [ "$#" -lt 4 ]; then
  usage
  exit 1
fi

START="$1"
END="$2"
PHASE_ID="$3"
ARTIFACT_PATH="$4"

if ! [[ "$START" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: START_DATE must be YYYY-MM-DD, got: $START"
  exit 1
fi
if ! [[ "$END" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: END_DATE must be YYYY-MM-DD, got: $END"
  exit 1
fi
if [ ! -f "$ARTIFACT_PATH" ]; then
  echo "Error: artifact not found: $ARTIFACT_PATH"
  exit 1
fi

marker="workspace/newsletter_run_marker_${START}_to_${END}.json"
receipts_file="workspace/newsletter_phase_receipts_${END}.json"

if [ ! -f "$marker" ]; then
  echo "Error: run marker missing: $marker"
  echo "Run prepare first: bash tools/prepare_newsletter_cycle.sh $START $END [--no-reuse]"
  exit 1
fi

python3 - "$marker" "$receipts_file" "$START" "$END" "$PHASE_ID" "$ARTIFACT_PATH" <<'PY'
import datetime as dt
import hashlib
import json
import os
import sys
from pathlib import Path

marker_path = Path(sys.argv[1])
receipts_path = Path(sys.argv[2])
start = sys.argv[3]
end = sys.argv[4]
phase_id = sys.argv[5]
artifact_path = Path(sys.argv[6])

with marker_path.open("r", encoding="utf-8") as f:
    marker = json.load(f)

run_id = marker.get("run_id") or marker.get("prepared_at_utc")
if not run_id:
    raise SystemExit(f"run_id not found in marker: {marker_path}")

artifact_bytes = artifact_path.read_bytes()
sha256 = hashlib.sha256(artifact_bytes).hexdigest()
line_count = len(artifact_bytes.splitlines())
size_bytes = len(artifact_bytes)
artifact_stat = artifact_path.stat()
artifact_mtime_epoch = int(artifact_stat.st_mtime)
artifact_mtime_utc = dt.datetime.fromtimestamp(artifact_mtime_epoch, dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

recorded_at_epoch = int(dt.datetime.now(tz=dt.timezone.utc).timestamp())
recorded_at_utc = dt.datetime.fromtimestamp(recorded_at_epoch, dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

if receipts_path.exists():
    with receipts_path.open("r", encoding="utf-8") as f:
        receipts = json.load(f)
else:
    receipts = {
        "schema_version": 1,
        "run_id": run_id,
        "start": start,
        "end": end,
        "receipts": [],
    }

if receipts.get("run_id") != run_id:
    raise SystemExit(
        f"run_id mismatch in receipts file ({receipts.get('run_id')} != {run_id}); "
        f"archive or delete {receipts_path} before recording new run receipts."
    )
if receipts.get("start") != start or receipts.get("end") != end:
    raise SystemExit(
        f"date range mismatch in receipts file ({receipts.get('start')}..{receipts.get('end')}) "
        f"!= ({start}..{end})"
    )

updated = []
for receipt in receipts.get("receipts", []):
    if receipt.get("phase_id") == phase_id:
        continue
    updated.append(receipt)

updated.append(
    {
        "phase_id": phase_id,
        "artifact_path": str(artifact_path),
        "artifact_sha256": sha256,
        "artifact_bytes": size_bytes,
        "artifact_lines": line_count,
        "artifact_mtime_epoch": artifact_mtime_epoch,
        "artifact_mtime_utc": artifact_mtime_utc,
        "recorded_at_epoch": recorded_at_epoch,
        "recorded_at_utc": recorded_at_utc,
    }
)
updated.sort(key=lambda r: (int(r.get("recorded_at_epoch", 0)), r.get("phase_id", "")))

receipts["receipts"] = updated
receipts["updated_at_utc"] = recorded_at_utc

receipts_path.parent.mkdir(parents=True, exist_ok=True)
with receipts_path.open("w", encoding="utf-8") as f:
    json.dump(receipts, f, indent=2)
    f.write("\n")

print(
    f"Recorded receipt: phase={phase_id} artifact={artifact_path} "
    f"sha256={sha256[:12]}... lines={line_count} bytes={size_bytes}"
)
print(f"Receipts file: {receipts_path}")
PY

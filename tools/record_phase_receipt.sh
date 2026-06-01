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
import sys
import time
from pathlib import Path

marker_path = Path(sys.argv[1])
receipts_path = Path(sys.argv[2])
start = sys.argv[3]
end = sys.argv[4]
phase_id = sys.argv[5]
repo_root = Path.cwd().resolve()
artifact_arg = Path(sys.argv[6])
artifact_abs = artifact_arg if artifact_arg.is_absolute() else (repo_root / artifact_arg)
artifact_path = artifact_abs.resolve()

try:
    logical_artifact_path = artifact_path.relative_to(repo_root).as_posix()
except ValueError as exc:
    raise SystemExit(
        f"artifact path must be inside repo root ({repo_root}), got: {artifact_path}"
    ) from exc

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
artifact_mtime_epoch_ns = int(artifact_stat.st_mtime_ns)
artifact_mtime_utc = dt.datetime.fromtimestamp(artifact_mtime_epoch, dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

recorded_at_epoch_ns = time.time_ns()
recorded_at_epoch = recorded_at_epoch_ns // 1_000_000_000
recorded_at_utc = dt.datetime.fromtimestamp(recorded_at_epoch, dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

if receipts_path.exists():
    with receipts_path.open("r", encoding="utf-8") as f:
        receipts = json.load(f)
else:
    receipts = {
        "schema_version": 2,
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
max_receipt_order = 0
for index, receipt in enumerate(receipts.get("receipts", []), start=1):
    if receipt.get("phase_id") == phase_id:
        continue
    normalized = dict(receipt)
    receipt_order = normalized.get("receipt_order")
    if isinstance(receipt_order, bool):
        receipt_order = None
    elif isinstance(receipt_order, str) and receipt_order.isdigit():
        receipt_order = int(receipt_order)
    elif not isinstance(receipt_order, int):
        receipt_order = None
    if receipt_order is None or receipt_order <= 0:
        receipt_order = max_receipt_order + 1 if max_receipt_order else index
    normalized["receipt_order"] = int(receipt_order)
    max_receipt_order = max(max_receipt_order, int(receipt_order))
    updated.append(normalized)

new_receipt_order = max_receipt_order + 1

updated.append(
    {
        "phase_id": phase_id,
        "artifact_path": logical_artifact_path,
        "artifact_sha256": sha256,
        "artifact_bytes": size_bytes,
        "artifact_lines": line_count,
        "artifact_mtime_epoch": artifact_mtime_epoch,
        "artifact_mtime_epoch_ns": artifact_mtime_epoch_ns,
        "artifact_mtime_utc": artifact_mtime_utc,
        "recorded_at_epoch": recorded_at_epoch,
        "recorded_at_epoch_ns": recorded_at_epoch_ns,
        "recorded_at_utc": recorded_at_utc,
        "receipt_order": new_receipt_order,
    }
)
updated.sort(key=lambda r: int(r.get("receipt_order", 0)))

receipts["schema_version"] = 2
receipts["receipts"] = updated
receipts["updated_at_utc"] = recorded_at_utc

receipts_path.parent.mkdir(parents=True, exist_ok=True)
with receipts_path.open("w", encoding="utf-8") as f:
    json.dump(receipts, f, indent=2)
    f.write("\n")

print(
    f"Recorded receipt: phase={phase_id} artifact={logical_artifact_path} "
    f"receipt_order={new_receipt_order} sha256={sha256[:12]}... "
    f"lines={line_count} bytes={size_bytes}"
)
print(f"Receipts file: {receipts_path}")
PY

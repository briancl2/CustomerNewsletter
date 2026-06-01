#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p \
  "$tmpdir/tools" \
  "$tmpdir/workspace" \
  "$tmpdir/.github/skills/newsletter-validation/scripts" \
  "$tmpdir/artifacts/workspace" \
  "$tmpdir/artifacts/output"

cp tools/backfill_receipt_order.py "$tmpdir/tools/"
cp tools/validate_pipeline_strict.sh "$tmpdir/tools/"
cp tools/validate_phase2_event_quality.py "$tmpdir/tools/"
cp tools/validate_phase3_curated.py "$tmpdir/tools/"
cp tools/product_run_common.py "$tmpdir/tools/"
cp .github/skills/newsletter-validation/scripts/validate_newsletter.sh \
  "$tmpdir/.github/skills/newsletter-validation/scripts/"

bash tools/materialize_committed_product_fixture.sh \
  2026-02-14 \
  2026-04-16 \
  "$tmpdir/artifacts"
git -C "$tmpdir" init -q

(
  cd "$tmpdir"
  python3 tools/backfill_receipt_order.py \
    "$tmpdir/artifacts/workspace/newsletter_phase_receipts_2026-04-16.json" \
    --artifact-root "$tmpdir/artifacts"
)

python3 - "$tmpdir/artifacts/workspace/newsletter_phase_receipts_2026-04-16.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
if payload.get("schema_version") != 2:
    raise SystemExit("schema_version should be 2 after backfill")

orders = [receipt.get("receipt_order") for receipt in payload.get("receipts", [])]
if any(order is None for order in orders):
    raise SystemExit("all receipts should have receipt_order after backfill")

by_phase = {receipt["phase_id"]: receipt for receipt in payload.get("receipts", [])}
if by_phase["phase3_working_set"]["receipt_order"] >= by_phase["phase3_curated"]["receipt_order"]:
    raise SystemExit("phase3_working_set must sort before phase3_curated after backfill")
print("PASS: receipt_order backfill shape checks passed")
PY

(
  cd "$tmpdir"
  bash tools/validate_pipeline_strict.sh \
    2026-02-14 \
    2026-04-16 \
    --production-artifacts \
    --artifact-root "$tmpdir/artifacts" \
    --report-path "$tmpdir/backfill-strict-validator-report.md" >/dev/null
)

echo "PASS: receipt-order backfill tests passed"

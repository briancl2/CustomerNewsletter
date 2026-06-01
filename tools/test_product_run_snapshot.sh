#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

source_root="$tmpdir/source"
dest_root="$tmpdir/dest"

bash tools/materialize_committed_product_fixture.sh \
  2026-02-14 \
  2026-04-16 \
  "$source_root"

python3 tools/snapshot_product_run_artifacts.py \
  2026-02-14 \
  2026-04-16 \
  --source-root "$source_root" \
  --dest-root "$dest_root"

for required in \
  "$dest_root/workspace/newsletter_phase_receipts_2026-04-16.json" \
  "$dest_root/workspace/newsletter_phase2_events_2026-04-16.md" \
  "$dest_root/output/2026-04_april_newsletter.md" \
  "$dest_root/snapshot-manifest.json"; do
  if [ ! -f "$required" ]; then
    echo "ASSERTION FAILED: missing snapshot artifact $required"
    exit 1
  fi
done

python3 - \
  "$source_root/workspace/newsletter_phase2_events_2026-04-16.md" \
  "$dest_root/workspace/newsletter_phase2_events_2026-04-16.md" <<'PY'
import hashlib
import sys
from pathlib import Path

source = Path(sys.argv[1])
dest = Path(sys.argv[2])

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

if sha(source) != sha(dest):
    raise SystemExit("snapshot bytes do not match source bytes")
if int(source.stat().st_mtime) != int(dest.stat().st_mtime):
    raise SystemExit("snapshot mtime was not preserved")
print("PASS: snapshot preserved bytes and mtime")
PY

echo "PASS: product run snapshot tests passed"

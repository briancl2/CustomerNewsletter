#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
tmp_archive="archive/__tmp_scope_contract_generation_test/workspace"
tmp_duplicate_manifest="config/experiment_fixture_packs/__tmp_scope_contract_generation_duplicate.json"
trap 'rm -rf "$tmpdir" archive/__tmp_scope_contract_generation_test "$tmp_duplicate_manifest"' EXIT

python3 - <<'PY'
import json
import subprocess
from pathlib import Path

root = Path.cwd()
for manifest_path in sorted((root / "config" / "experiment_fixture_packs").glob("*.json")):
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for rows in manifest.get("surfaces", {}).values():
        if not isinstance(rows, list):
            continue
        for row in rows:
            if row.get("artifact_name") != "scope_contract":
                continue
            source_path = root / row["source_path"]
            if not source_path.exists():
                raise SystemExit(f"fixture scope contract is missing: {source_path.relative_to(root)}")
            completed = subprocess.run(
                ["git", "ls-files", "--error-unmatch", str(source_path.relative_to(root))],
                cwd=root,
                text=True,
                capture_output=True,
                check=False,
            )
            if completed.returncode != 0:
                raise SystemExit(f"fixture scope contract is not committed: {source_path.relative_to(root)}")
PY

historical_scope="$tmpdir/historical-scope.json"
production_scope="$tmpdir/production-scope.json"

mkdir -p "$tmp_archive"
python3 - <<'PY'
import json
from pathlib import Path

path = Path("archive/__tmp_scope_contract_generation_test/workspace/newsletter_scope_contract_2026-02-13.json")
payload = {
    "date_range": {"start": "2025-12-05", "end": "2026-02-13"},
    "expected_versions": {"vscode": ["1.107", "1.108", "1.109"]},
    "expected_sources": [],
    "expected_categories": [],
}
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

python3 tools/generate_scope_contract.py \
  2025-12-05 \
  2026-02-13 \
  --output "$historical_scope" \
  >/dev/null

python3 tools/generate_scope_contract.py \
  2026-02-14 \
  2026-04-16 \
  --output "$production_scope" \
  >/dev/null

python3 - "$historical_scope" "$production_scope" <<'PY'
import json
import sys
from pathlib import Path

historical = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
production = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))

expected_historical_vscode = [
    "1.107.0",
    "1.107.1",
    "1.108.0",
    "1.108.1",
    "1.108.2",
    "1.109.0",
    "1.109.1",
    "1.109.2",
]

historical_versions = historical.get("expected_versions", {}).get("vscode")
if historical_versions != expected_historical_vscode:
    raise SystemExit(f"historical VS Code versions were not fixture-precise: {historical_versions}")

if historical.get("generation_mode") != "experiment_fixture_scope_contract":
    raise SystemExit(f"expected fixture-backed historical generation, got {historical.get('generation_mode')}")

if historical.get("expected_event_date_range") != {"earliest": "2026-02-13", "latest": "2026-08-13"}:
    raise SystemExit(f"unexpected historical event date range: {historical.get('expected_event_date_range')}")

for key in ("visual_studio", "jetbrains", "xcode", "copilot_cli"):
    if not historical.get("expected_versions", {}).get(key):
        raise SystemExit(f"historical fixture completion omitted expected_versions.{key}")

expected_fixture = "config/experiment_fixture_packs/benchmark-anchor-2025-12-05_2026-02-13.json"
if historical.get("fixture_manifest_path") != expected_fixture:
    raise SystemExit(f"unexpected historical fixture manifest: {historical.get('fixture_manifest_path')}")

historical_sources = historical.get("expected_sources", [])
for url in (
    "https://github.com/microsoft/vscode/releases/tag/1.107.1",
    "https://github.com/microsoft/vscode/releases/tag/1.108.2",
    "https://github.com/microsoft/vscode/releases/tag/1.109.2",
):
    if url not in historical_sources:
        raise SystemExit(f"missing recovery-release source in historical contract: {url}")

production_versions = production.get("expected_versions", {}).get("vscode")
if production_versions != ["1.110", "1.111", "1.112", "1.113", "1.114", "1.115", "1.116"]:
    raise SystemExit(f"production fixture scope unexpectedly changed: {production_versions}")

if production.get("generation_mode") != "experiment_fixture_scope_contract":
    raise SystemExit(f"expected fixture-backed production generation, got {production.get('generation_mode')}")

if production.get("expected_event_date_range") != {"earliest": "2026-04-16", "latest": "2026-10-16"}:
    raise SystemExit(f"unexpected production event date range: {production.get('expected_event_date_range')}")

expected_production_versions = {
    "visual_studio": ["18.3.1", "18.3.2", "18.3.3", "18.4.0", "18.4.1", "18.4.2", "18.4.3", "18.4.4", "18.5.0"],
    "jetbrains": ["1.5.66", "1.6.1", "1.7.1", "1.8.0"],
    "xcode": ["0.47.169", "0.47.170"],
}
for key, expected in expected_production_versions.items():
    actual = production.get("expected_versions", {}).get(key)
    if actual != expected:
        raise SystemExit(f"production fixture completion changed expected_versions.{key}: {actual}")

production_sources = production.get("expected_sources", [])
for url in (
    "https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes",
    "plugins.jetbrains.com/api/plugins/17718/updates",
    "github.com/github/CopilotForXcode/releases",
    "github.com/github/copilot-cli/releases",
):
    if url not in production_sources:
        raise SystemExit(f"production fixture completion omitted source: {url}")
PY

cp \
  config/experiment_fixture_packs/benchmark-anchor-2025-12-05_2026-02-13.json \
  "$tmp_duplicate_manifest"

if python3 tools/generate_scope_contract.py \
  2025-12-05 \
  2026-02-13 \
  --output "$tmpdir/duplicate-scope.json" \
  >"$tmpdir/duplicate.out" \
  2>"$tmpdir/duplicate.err"; then
  echo "expected duplicate fixture manifests to fail closed" >&2
  exit 1
fi

if ! grep -q "Multiple experiment fixture scope contracts match this date range" "$tmpdir/duplicate.err"; then
  echo "duplicate fixture failure did not explain the ambiguity" >&2
  cat "$tmpdir/duplicate.err" >&2
  exit 1
fi

echo "PASS: scope contract generation tests passed"

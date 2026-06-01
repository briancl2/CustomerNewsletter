#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

source_root="$tmpdir/source"
output_dir="$tmpdir/generated"
start="2026-04-17"
end="2026-05-21"
mkdir -p "$source_root/workspace" "$source_root/output"

required=(
  "newsletter_run_marker_${start}_to_${end}.json"
  "newsletter_phase_receipts_${end}.json"
  "newsletter_scope_contract_${end}.json"
  "newsletter_phase1a_url_manifest_${start}_to_${end}.md"
  "newsletter_phase1b_interim_github_${start}_to_${end}.md"
  "newsletter_phase1b_interim_vscode_${start}_to_${end}.md"
  "newsletter_phase1b_interim_visualstudio_${start}_to_${end}.md"
  "newsletter_phase1b_interim_jetbrains_${start}_to_${end}.md"
  "newsletter_phase1b_interim_xcode_${start}_to_${end}.md"
  "newsletter_phase1a_discoveries_${start}_to_${end}.md"
)
for file in "${required[@]}"; do
  printf 'fixture for %s\n' "$file" > "$source_root/workspace/$file"
done

python3 - "$source_root/workspace/newsletter_phase2_event_sources_${end}.json" <<'PY'
import json
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(json.dumps({
    "schema_version": 1,
    "start": "2026-04-17",
    "end": "2026-05-21",
    "candidate_urls": [
        {"url": "https://example.com/a", "source_types": ["release"], "source_names": ["A"]},
        {"url": "https://example.com/b", "source_types": ["docs"], "source_names": ["B"]},
        {"url": "https://example.com/c", "source_types": ["docs"], "source_names": ["C"]},
    ],
}), encoding="utf-8")
PY

cat > "$source_root/workspace/newsletter_phase2_events_${end}.md" <<'MD'
# Events

## Virtual Events

| Date | Event |
| --- | --- |
| May 1 | [Event A](https://example.com/a) |

## In Person Events

- [Event B](https://example.com/b)
MD

python3 tools/build_current_cycle_cost_stack_inputs.py \
  --start "$start" \
  --end "$end" \
  --source-root "$source_root" \
  --output-dir "$output_dir"

python3 - "$output_dir" "$end" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
end = sys.argv[2]
manifest = json.loads((root / "current-cycle-fixture-manifest.json").read_text(encoding="utf-8"))
admission = json.loads((root / "current-cycle-no-refetch-admission.json").read_text(encoding="utf-8"))
assert manifest["start"] == "2026-04-17"
assert manifest["end"] == "2026-05-21"
surface = manifest["surfaces"]["phase2_entry_surface"]
names = {row["artifact_name"] for row in surface}
assert "phase2_selected_source_ids" in names
assert all(row["exists"] for row in surface)
for row in surface:
    source_path = Path(row["source_path"])
    assert source_path.is_absolute(), row
    assert source_path.exists(), row
assert admission["admission_verdict"] == "admit_no_refetch"
assert admission["no_refetch_compliance"] == "pass"
assert admission["selected_source_count"] == 2
for artifact_name, payload in admission["generated_artifacts"].items():
    path = Path(payload["path"])
    assert path.exists(), artifact_name
    assert len(payload["sha256"]) == 64
assert (root / "workspace" / f"newsletter_phase2_no_refetch_compliance_{end}.json").exists()
PY

sed -i.bak 's#https://example.com/a#https://not-selected.invalid/a#g; s#https://example.com/b#https://not-selected.invalid/b#g' \
  "$source_root/workspace/newsletter_phase2_events_${end}.md"
if python3 tools/build_current_cycle_cost_stack_inputs.py \
  --start "$start" \
  --end "$end" \
  --source-root "$source_root" \
  --output-dir "$tmpdir/negative" >/dev/null 2>&1; then
  echo "Expected no selected URL negative case to fail"
  exit 1
fi

echo "PASS: current-cycle cost stack input builder"

#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

python3 tools/run_model_routing_subtask_scout.py admit \
  --manifest config/experiment_fixture_packs/benchmark-anchor-2025-12-05_2026-02-13.json \
  --surface-id phase4_fast_surface \
  --target-repo . \
  --section-heading "## Resources and Best Practices" \
  --benchmark-mode feb2026_consistency \
  --output "$tmpdir/admission.json"

python3 - "$tmpdir/admission.json" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["admitted"] is True
assert payload["checks"]["source_curated_validates"] is True
assert payload["checks"]["section_word_count_bounded"] is True
assert payload["section_metrics"]["bullet_count"] >= 2
assert payload["route_boundary"]["type"] == "phase3_section_subtask"
PY

if python3 tools/run_model_routing_subtask_scout.py admit \
  --manifest config/experiment_fixture_packs/benchmark-anchor-2025-12-05_2026-02-13.json \
  --surface-id phase4_fast_surface \
  --target-repo . \
  --section-heading "## Missing Burst 35 Section" \
  --benchmark-mode feb2026_consistency \
  --output "$tmpdir/missing.json"; then
  echo "expected missing section admission to fail closed" >&2
  exit 1
fi

python3 - "$tmpdir/missing.json" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["admitted"] is False
assert "section_present" in payload["blockers"]
PY

echo "PASS model routing subtask scout tests"

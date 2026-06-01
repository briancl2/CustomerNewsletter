#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p \
  "$tmpdir/.github/agents" \
  "$tmpdir/.github/skills/content-curation" \
  "$tmpdir/.github/prompts" \
  "$tmpdir/tools"

cp .github/agents/customer_newsletter.agent.md "$tmpdir/.github/agents/"
cp .github/skills/content-curation/SKILL.md "$tmpdir/.github/skills/content-curation/"
cp .github/prompts/phase_3_content_curation.prompt.md "$tmpdir/.github/prompts/"
cp tools/init_phase3_curated_sections.py "$tmpdir/tools/"
cp tools/validate_phase3_curated.py "$tmpdir/tools/"
cp tools/run_newsletter_orchestrated.sh "$tmpdir/tools/"
cp tools/validate_phase3_instruction_contract.py "$tmpdir/tools/"

python3 tools/validate_phase3_instruction_contract.py --root "$tmpdir" >/dev/null

python3 - "$tmpdir/.github/prompts/phase_3_content_curation.prompt.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace(
    "1. **Review and analyze** `workspace/newsletter_phase3_working_set_YYYY-MM-DD.md` first, and read Phase 1C discoveries only if the working set flags missing data",
    "1. **Review and analyze** the provided raw content list from Phase 1C",
)
path.write_text(text, encoding="utf-8")
PY

set +e
output="$(python3 tools/validate_phase3_instruction_contract.py --root "$tmpdir" 2>&1)"
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
  echo "ASSERTION FAILED: validator should fail after reintroducing Phase 1C-first prompt drift"
  exit 1
fi

if ! grep -Fq ".github/prompts/phase_3_content_curation.prompt.md" <<<"$output"; then
  echo "ASSERTION FAILED: expected prompt-surface failure"
  echo "$output"
  exit 1
fi

echo "PASS: Phase 3 instruction contract tests passed"

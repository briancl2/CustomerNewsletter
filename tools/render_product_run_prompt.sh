#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash tools/render_product_run_prompt.sh <START> <END> <benchmark|production> [--source-pruning-policy PATH | --output-shape-policy PATH]

Modes:
  benchmark   2025-12-05 through 2026-02-13
  production  2026-02-14 through 2026-04-16
EOF
}

if [ "$#" -lt 3 ]; then
  usage
  exit 1
fi

START="$1"
END="$2"
MODE="$3"
shift 3
SOURCE_PRUNING_POLICY=""
OUTPUT_SHAPE_POLICY=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source-pruning-policy)
      if [ "$#" -lt 2 ]; then
        echo "ERROR: --source-pruning-policy requires a path" >&2
        exit 1
      fi
      SOURCE_PRUNING_POLICY="$2"
      shift 2
      ;;
    --output-shape-policy)
      if [ "$#" -lt 2 ]; then
        echo "ERROR: --output-shape-policy requires a path" >&2
        exit 1
      fi
      OUTPUT_SHAPE_POLICY="$2"
      shift 2
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -n "$SOURCE_PRUNING_POLICY" ] && [ -n "$OUTPUT_SHAPE_POLICY" ]; then
  echo "ERROR: --source-pruning-policy and --output-shape-policy are mutually exclusive evidence hooks" >&2
  exit 1
fi

if ! [[ "$START" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "ERROR: START must be YYYY-MM-DD, got: $START" >&2
  exit 1
fi
if ! [[ "$END" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "ERROR: END must be YYYY-MM-DD, got: $END" >&2
  exit 1
fi

case "$MODE" in
  benchmark)
    EXPECTED_START="2025-12-05"
    EXPECTED_END="2026-02-13"
    OUTPUT_FILE="output/2026-02_february_newsletter.md"
    STRICT_CMD="bash tools/validate_pipeline_strict.sh $START $END --require-fresh --production-artifacts --benchmark-mode feb2026_consistency"
    SCORE_CMD="bash tools/score-v2-rubric.sh $OUTPUT_FILE"
    WARNING_TARGETS="- Preserve every VS Code version listed in the scope contract through Phase 1C discoveries and the final output.
- Keep the scope contract, discoveries, and final output rich enough that strict validation emits zero WARN lines.
- Preserve countable Phase 1B and Phase 1C headings so phase-continuity checks can run instead of being skipped."
    ;;
  production)
    EXPECTED_START="2026-02-14"
    EXPECTED_END="2026-04-16"
    OUTPUT_FILE="output/2026-04_april_newsletter.md"
    STRICT_CMD="bash tools/validate_pipeline_strict.sh $START $END --require-fresh --production-artifacts"
    SCORE_CMD="bash tools/score-v2-rubric.sh --mode auto $OUTPUT_FILE"
    WARNING_TARGETS="- Preserve every VS Code version listed in the scope contract through Phase 1C discoveries and the final output.
- Include in-person events when available for the date range.
- Include GitHub Resources or Goldcast event deep links when available.
- Keep the strict validator at zero WARN lines before treating the run as anchor-admission evidence."
    ;;
  *)
    echo "ERROR: MODE must be benchmark or production, got: $MODE" >&2
    usage >&2
    exit 1
    ;;
esac

if [ "$START" != "$EXPECTED_START" ] || [ "$END" != "$EXPECTED_END" ]; then
  echo "ERROR: Mode $MODE is pinned to $EXPECTED_START through $EXPECTED_END, got: $START through $END" >&2
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

SOURCE_PRUNING_POLICY_REL=""
SOURCE_PRUNING_POLICY_SHA=""
SOURCE_PRUNING_POLICY_CLOSED_BUNDLE_REQUIRED="0"
OUTPUT_SHAPE_POLICY_REL=""
OUTPUT_SHAPE_POLICY_SHA=""
if [ -n "$SOURCE_PRUNING_POLICY" ]; then
  if [ ! -f "$SOURCE_PRUNING_POLICY" ]; then
    echo "ERROR: source pruning policy not found: $SOURCE_PRUNING_POLICY" >&2
    exit 1
  fi
  SOURCE_PRUNING_POLICY_REL="$(python3 - "$ROOT" "$SOURCE_PRUNING_POLICY" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
path = Path(sys.argv[2]).expanduser().resolve()
try:
    print(path.relative_to(root))
except ValueError:
    raise SystemExit(f"source pruning policy must be inside repo: {path}")
PY
)"
  SOURCE_PRUNING_POLICY_SHA="$(python3 - "$SOURCE_PRUNING_POLICY_REL" <<'PY'
import hashlib
import sys
from pathlib import Path

print(hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
  SOURCE_PRUNING_POLICY_CLOSED_BUNDLE_REQUIRED="$(python3 - "$SOURCE_PRUNING_POLICY_REL" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print("1" if payload.get("closed_bundle_required") is True else "0")
PY
)"
fi
if [ -n "$OUTPUT_SHAPE_POLICY" ]; then
  if [ ! -f "$OUTPUT_SHAPE_POLICY" ]; then
    echo "ERROR: output shape policy not found: $OUTPUT_SHAPE_POLICY" >&2
    exit 1
  fi
  OUTPUT_SHAPE_POLICY_REL="$(python3 - "$ROOT" "$OUTPUT_SHAPE_POLICY" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
path = Path(sys.argv[2]).expanduser().resolve()
try:
    print(path.relative_to(root))
except ValueError:
    raise SystemExit(f"output shape policy must be inside repo: {path}")
PY
)"
  OUTPUT_SHAPE_POLICY_SHA="$(python3 - "$OUTPUT_SHAPE_POLICY_REL" <<'PY'
import hashlib
import sys
from pathlib import Path

print(hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
fi

AGENT_FILE=".github/agents/customer_newsletter.agent.md"
if [ ! -f "$AGENT_FILE" ]; then
  echo "ERROR: Missing agent contract: $AGENT_FILE" >&2
  exit 1
fi

AGENT_CONTRACT="$(
  awk '
    NR == 1 && $0 == "---" { in_frontmatter = 1; next }
    in_frontmatter && $0 == "---" { in_frontmatter = 0; body = 1; next }
    body { print }
  ' "$AGENT_FILE"
)"

cat <<EOF
Canonical Product Newsletter Run
Mode: $MODE
Pinned date range: $START to $END

Preserve the existing single-shot newsletter oracle.
Do not invent a fleet-native controller.
Do not use the agent tool.
Follow the embedded customer_newsletter contract directly.

Required first step:
bash tools/prepare_newsletter_cycle.sh $START $END --no-reuse

Completion gates:
$STRICT_CMD
bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh $OUTPUT_FILE
$SCORE_CMD

Anchor-admission warning target:
$WARNING_TARGETS
If any completion gate prints WARN lines, repair the underlying artifact and rerun the gate before finalizing. Passing with warnings is retained proof evidence, but it is not Batch 2 anchor-admission evidence.

Source-pruning experiment:
$(if [ -n "$SOURCE_PRUNING_POLICY_REL" ]; then cat <<EOF2
- Enabled with policy: \`$SOURCE_PRUNING_POLICY_REL\`
- Policy SHA256: \`$SOURCE_PRUNING_POLICY_SHA\`
- This is an evidence-only source/candidate pruning run, not production adoption.
- After Phase 3 working set and curated sections exist and before final newsletter drafting, run:
  \`python3 tools/apply_newsletter_source_pruning_policy.py $START $END --policy $SOURCE_PRUNING_POLICY_REL --source-root . --output-root . --require-admission\`
- Read \`workspace/newsletter_source_pruning_context_${END}.md\` as $(if [ "$SOURCE_PRUNING_POLICY_CLOSED_BUNDLE_REQUIRED" = "1" ]; then echo "the closed source bundle"; else echo "the compact source/candidate context"; fi) for final drafting.
- Follow the compact context Usage Boundary and any policy-specific rules.
- Closed source bundle required: \`$(if [ "$SOURCE_PRUNING_POLICY_CLOSED_BUNDLE_REQUIRED" = "1" ]; then echo "true"; else echo "false"; fi)\`
$(if [ "$SOURCE_PRUNING_POLICY_CLOSED_BUNDLE_REQUIRED" = "1" ]; then cat <<EOF3
- After the closed bundle receipt passes, do not perform broad repo/source search expansion, source rediscovery, rg/grep/find over canonical source artifacts, or broad file listing for final drafting.
- If a required detail is missing from the closed bundle, stop and report \`closed_bundle_missing_detail\` instead of searching.
- The run is invalid as a closed-bundle proof row if final drafting depends on broad search expansion after closed-bundle admission.
EOF3
else cat <<EOF3
- After the pruning receipt passes, do not perform broad repo/source search expansion or source rediscovery; if a required detail is missing, open only the specific original source artifact named in Source Inventory and record the reason.
EOF3
fi)
- Do not delete, overwrite, or mutate the canonical source artifacts that the pruning receipt names.
- If the pruning tool fails admission, stop the run and report the failed admission reason instead of continuing to final output.
EOF2
else
  echo "- Disabled. Use the canonical source/candidate artifacts directly."
fi)

Output-shape budget experiment:
$(if [ -n "$OUTPUT_SHAPE_POLICY_REL" ]; then cat <<EOF2
- Enabled with policy: \`$OUTPUT_SHAPE_POLICY_REL\`
- Policy SHA256: \`$OUTPUT_SHAPE_POLICY_SHA\`
- This is an evidence-only output-shape budget run, not production adoption.
- After Phase 3 working set and curated sections exist and before final newsletter drafting, run:
  \`python3 tools/apply_newsletter_output_shape_policy.py $START $END --policy $OUTPUT_SHAPE_POLICY_REL --source-root . --output-root . --require-admission\`
- Read \`workspace/newsletter_output_shape_context_${END}.md\` before final drafting and follow the per-mode word budget, section preservation rules, and quality-floor rules.
- Do not drop required sections, source links, in-person event coverage, version references, validator context, or rubric-critical evidence to satisfy the budget.
- If the output-shape policy fails admission, stop the run and report the failed admission reason instead of continuing to final output.
EOF2
else
  echo "- Disabled. Use the canonical output shape and quality bar."
fi)

Execution rules:
- Write the canonical workspace and output artifacts for this date range.
- Record receipts immediately after each artifact write.
- Record the \`phase1c_discoveries\` receipt before creating or receipting any
  Phase 2 artifact. Do not create \`phase2_event_sources\` until
  \`workspace/newsletter_phase_receipts_${END}.json\` already contains
  \`phase1c_discoveries\` with an earlier \`receipt_order\`.
- After prep, inspect the latest workspace/archived/preflight/${START}_to_${END}_*
  snapshot before broader repo search. Treat that exact-cycle preflight archive
  as the first retained source for prior April wording and artifacts when it is
  present.
- For Phase 3, create and receipt the working set before the curated artifact.
- Keep tools/run_newsletter_orchestrated.sh as a diagnostic-only fallback.
- Do not call copilot again from inside this run.
- Do not widen repo search for prior April content until the latest exact-cycle
  preflight archive has been checked for the canonical artifact you need.
- Do not invoke make newsletter-gen, make newsletter-render-prompt, release_bundle/2026-04_newsletter_launch/run_april_production.sh, or any other wrapper that would re-enter this same top-level prompt.
- If the single-shot path fails, stop after naming the earliest failing phase or validator family before switching to orchestrated diagnosis.
- Do not widen scope into unrelated cleanup, broad repo edits, or speculative editorial rewrites.

Embedded customer_newsletter contract:
$AGENT_CONTRACT
EOF

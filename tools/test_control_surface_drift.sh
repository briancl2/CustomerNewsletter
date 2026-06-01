#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

assert_contains() {
  local file="$1"
  local needle="$2"
  if ! grep -Fq "$needle" "$file"; then
    echo "ASSERTION FAILED: expected $file to contain: $needle"
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  if grep -Fq "$needle" "$file"; then
    echo "ASSERTION FAILED: expected $file to not contain: $needle"
    exit 1
  fi
}

help_target_count="$(
  make help | perl -pe 's/\e\[[0-9;]*m//g' | awk 'NF{count++} END{print count}'
)"
skill_count="$(rg --files .github/skills | rg '/SKILL\.md$' | wc -l | tr -d ' ')"
prompt_count="$(rg --files .github/prompts | rg '\.prompt\.md$' | wc -l | tr -d ' ')"
agent_count="$(rg --files .github/agents | rg '\.agent\.md$' | wc -l | tr -d ' ')"
reference_count="$(find reference -type f | wc -l | tr -d ' ')"
score_tool_count="$(rg --files tools | rg 'score-.*\.sh$' | wc -l | tr -d ' ')"
kb_source_count="$(
  python3 - <<'PY'
from pathlib import Path
import yaml

data = yaml.safe_load(Path('kb/SOURCES.yaml').read_text())
print(len(data.get('sources', [])))
PY
)"

# These visible-surface totals are meant to fail loudly when operator-facing
# commands or the validation battery drift without the canonical docs moving
# with them.
if [ "$help_target_count" -ne 62 ]; then
  echo "ASSERTION FAILED: expected 62 visible help targets, found $help_target_count"
  exit 1
fi

assert_contains README.md "Live operator paths:"
assert_contains README.md "newsletter-orchestrated"
assert_contains README.md "diagnostic-only for phase-local debugging"
assert_contains README.md "regression diagnosis"
assert_contains README.md "Experiment-only optimization helpers:"
assert_contains README.md "newsletter-cost-profiler"
assert_contains README.md "newsletter-hotspot-auditor"
assert_contains README.md "newsletter-phase-experimenter"
assert_contains README.md "newsletter-orchestrated-proof"
assert_contains README.md "| **Skills** | ${skill_count} |"
assert_contains README.md "| **Agents** | ${agent_count} |"
assert_contains README.md "| **Prompts** | ${prompt_count} |"
assert_contains README.md "| **Scoring tools** | ${score_tool_count} |"
assert_contains README.md "| **KB sources** | ${kb_source_count} |"
assert_contains README.md "| **Reference docs** | ${reference_count} |"
assert_contains README.md "make help                      # Show all 62 targets"
assert_contains README.md "| \`.github/skills/\` | ${skill_count} pipeline and meta skills |"
assert_contains README.md "| \`.github/prompts/\` | ${prompt_count} phase prompts + pipeline orchestrator |"
assert_contains README.md "| \`kb/\` | Knowledge base with ${kb_source_count} source entries |"
assert_contains README.md '| `benchmark/` | Gitignored benchmark scratch space, created on demand |'

assert_contains planning/HANDOFF.md "diagnostic-only phase harness:"
assert_contains planning/HANDOFF.md "all local test suites in \`tools/test_all.sh\`: \`PASS\`"

assert_contains planning/PRODUCT_RUN_PLAYBOOK.md "## Live Toolchain"
assert_contains planning/PRODUCT_RUN_PLAYBOOK.md "GitHub Copilot CLI 1.0.28."
assert_contains planning/PRODUCT_RUN_PLAYBOOK.md "Historical Lane A receipt notes:"
assert_contains planning/PRODUCT_RUN_PLAYBOOK.md "GitHub Copilot CLI 1.0.12-2."
assert_contains planning/PRODUCT_RUN_PLAYBOOK.md "the phase-orchestrated harness is diagnostic only"

assert_contains release_bundle/2026-04_newsletter_launch/START_HERE.md "Live operator paths"
assert_contains release_bundle/2026-04_newsletter_launch/START_HERE.md "make newsletter-gen START=2026-02-14 END=2026-04-16 MODE=production"
assert_contains release_bundle/2026-04_newsletter_launch/START_HERE.md "tools/run_newsletter_orchestrated.sh"
assert_contains release_bundle/2026-04_newsletter_launch/START_HERE.md "diagnostic-only"

assert_contains Makefile "newsletter-gen: ## Live operator path:"
assert_contains Makefile "newsletter-proof-run: ## Live operator path:"
assert_contains Makefile "newsletter-cost-profiler: ## Build per-run and per-phase cost ledger"
assert_contains Makefile "newsletter-hotspot-auditor: ## Rank retained run cost/token hotspots"
assert_contains Makefile "newsletter-phase-experimenter: ## Inventory, materialize, or run bounded phase experiments"
assert_contains Makefile "newsletter-orchestrated: ## Diagnostic-only phase-by-phase run"
assert_contains Makefile "newsletter-orchestrated-proof: ## Retained phase-by-phase proof run"
assert_contains Makefile "test-output-shape-amplification: ## Run output-shape amplification trace receipt tests"
assert_contains tools/test_all.sh "Control-Surface Drift Guard"
assert_contains tools/test_all.sh "test_control_surface_drift.sh"
assert_contains tools/test_all.sh "Experiment Surface Tests"
assert_contains tools/test_all.sh "test_experiment_surfaces.sh"
assert_contains tools/test_all.sh "Output Shape Amplification Receipt Tests"
assert_contains tools/test_all.sh "test_output_shape_amplification_trace_receipt.sh"
assert_contains tools/test_all.sh "Phase Session Telemetry Tests"
assert_contains tools/test_all.sh "test_phase_session_telemetry.sh"
assert_contains tools/test_all.sh "Phase Route-Lock Telemetry Tests"
assert_contains tools/test_all.sh "test_phase_route_lock_telemetry.sh"
assert_contains tools/test_all.sh "Phase 1C Calibration Receipt Tests"
assert_contains tools/test_all.sh "test_phase1c_calibration_receipt.sh"

assert_not_contains README.md "Show all 51 targets"
assert_not_contains README.md "Show all 32 targets"

echo "PASS: control-surface drift guard passed"

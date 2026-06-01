#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if ! grep -Fq "$needle" <<<"$haystack"; then
    echo "ASSERTION FAILED: expected prompt to contain: $needle"
    exit 1
  fi
}

benchmark_prompt="$(bash tools/render_product_run_prompt.sh 2025-12-05 2026-02-13 benchmark)"
assert_contains "$benchmark_prompt" "Mode: benchmark"
assert_contains "$benchmark_prompt" "bash tools/prepare_newsletter_cycle.sh 2025-12-05 2026-02-13 --no-reuse"
assert_contains "$benchmark_prompt" "bash tools/validate_pipeline_strict.sh 2025-12-05 2026-02-13 --require-fresh --production-artifacts --benchmark-mode feb2026_consistency"
assert_contains "$benchmark_prompt" "Anchor-admission warning target:"
assert_contains "$benchmark_prompt" "Preserve countable Phase 1B and Phase 1C headings"
assert_contains "$benchmark_prompt" "Embedded customer_newsletter contract:"
assert_contains "$benchmark_prompt" "phase3_working_set"

production_prompt="$(bash tools/render_product_run_prompt.sh 2026-02-14 2026-04-16 production)"
assert_contains "$production_prompt" "Mode: production"
assert_contains "$production_prompt" "bash tools/prepare_newsletter_cycle.sh 2026-02-14 2026-04-16 --no-reuse"
assert_contains "$production_prompt" "bash tools/validate_pipeline_strict.sh 2026-02-14 2026-04-16 --require-fresh --production-artifacts"
assert_contains "$production_prompt" "bash tools/score-v2-rubric.sh --mode auto output/2026-04_april_newsletter.md"
assert_contains "$production_prompt" "Keep the strict validator at zero WARN lines before treating the run as anchor-admission evidence."
assert_contains "$production_prompt" 'Record the `phase1c_discoveries` receipt before creating or receipting any'
assert_contains "$production_prompt" 'Phase 2 artifact.'
assert_contains "$production_prompt" "Do not use the agent tool."
assert_contains "$production_prompt" "Do not call copilot again from inside this run."
assert_contains "$production_prompt" 'workspace/archived/preflight/2026-02-14_to_2026-04-16_*'

if bash tools/render_product_run_prompt.sh 2026-02-14 2026-04-16 invalid >/dev/null 2>&1; then
  echo "ASSERTION FAILED: invalid mode should fail"
  exit 1
fi

if bash tools/render_product_run_prompt.sh 2026-02-14 2026-04-16 benchmark >/dev/null 2>&1; then
  echo "ASSERTION FAILED: mismatched benchmark dates should fail"
  exit 1
fi

echo "PASS: product run prompt rendering tests passed"

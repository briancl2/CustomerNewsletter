#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Test Runner: All Test Suites
# ══════════════════════════════════════════════════════════════
# Runs all test suites in dependency order and reports aggregate results.
#
# Usage: bash tools/test_all.sh
# Exit: 0 if all suites pass, 1 if any fail

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
SKIPPED_SUITES=0
RESULTS=""

run_suite() {
  local name="$1"
  local cmd="$2"
  TOTAL_SUITES=$((TOTAL_SUITES + 1))

  echo "━━━ Suite: $name ━━━"
  if bash -c "$cmd" 2>&1; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
    RESULTS="$RESULTS  PASS: $name\n"
  else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    RESULTS="$RESULTS  FAIL: $name\n"
  fi
  echo ""
}

run_suite_optional() {
  local name="$1"
  local cmd="$2"
  local required_path="$3"
  local reason="$4"
  TOTAL_SUITES=$((TOTAL_SUITES + 1))

  echo "━━━ Suite: $name ━━━"
  if [ ! -e "$required_path" ]; then
    SKIPPED_SUITES=$((SKIPPED_SUITES + 1))
    RESULTS="$RESULTS  SKIP: $name ($reason)\n"
    echo "SKIP: $reason"
  elif bash -c "$cmd" 2>&1; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
    RESULTS="$RESULTS  PASS: $name\n"
  else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    RESULTS="$RESULTS  FAIL: $name\n"
  fi
  echo ""
}

echo "══════════════════════════════════════════════════════"
echo "  Test Runner: All Suites"
echo "══════════════════════════════════════════════════════"
echo ""

# Layer 1: Structural validation (cheapest, run first)
run_suite "Structure Validation" "make validate-structure"
run_suite "Skill Validation (18 skills)" "make validate-all-skills"

# Layer 2: Unit tests
run_suite "Archive Workspace Tests (13 assertions)" "bash tools/test_archive_workspace.sh"
run_suite "Newsletter Validator Self-Test (10 assertions)" "bash tools/test_validator.sh"
run_suite_optional "Phase 3 Contract Tests" "bash tools/test_phase3_contracts.sh" "workspace/newsletter_phase3_working_set_2026-04-16.md" "requires private April workspace fixture"
run_suite "Phase 3 Instruction Contract Tests" "bash tools/test_phase3_instruction_contract.sh"
run_suite_optional "Receipt Order Backfill Tests" "bash tools/test_receipt_order_backfill.sh" "workspace/archived/preflight" "requires retained preflight workspace fixtures"
run_suite "Prepare Newsletter Cycle Tests" "bash tools/test_prepare_newsletter_cycle.sh"
run_suite "Product Prompt Render Tests" "bash tools/test_product_run_prompt.sh"
run_suite_optional "Scope Contract Generation Tests" "bash tools/test_scope_contract_generation.sh" "runs/product_runs/20260430T163723Z_benchmark_proof/artifacts/workspace/newsletter_scope_contract_2026-02-13.json" "requires retained benchmark proof fixture"
run_suite "Phase 1A Scope Alignment Tests" "bash tools/test_phase1a_scope_alignment.sh"
run_suite_optional "Product Snapshot Tests" "bash tools/test_product_run_snapshot.sh" "runs/product_runs" "requires retained product runs"
run_suite_optional "Retained Product Validation Tests" "bash tools/test_product_run_validation.sh" "runs/product_runs" "requires retained product runs"
run_suite "Phase 2 Corpus-Aware Event Floor Tests" "bash tools/test_phase2_corpus_aware_event_floor.sh"
run_suite_optional "Product Run Audit Tests" "bash tools/test_product_run_audit.sh" "runs/product_runs" "requires retained product runs"
run_suite_optional "Experiment Surface Tests" "bash tools/test_experiment_surfaces.sh" "runs/product_runs" "requires retained product runs"
run_suite "Copilot Tool Filter Args" "bash tools/test_copilot_tool_filter_args.sh"
run_suite "Artifact Reuse Admission Receipt Tests" "bash tools/test_artifact_reuse_admission_receipt.sh"
run_suite "Artifact Reuse Phase 3 Proof Receipt Tests" "bash tools/test_artifact_reuse_phase3_proof_receipt.sh"
run_suite "Artifact Reuse Stdout/No-Tools Receipt Tests" "bash tools/test_artifact_reuse_stdout_no_tools.sh"
run_suite_optional "Artifact Reuse Stdout/No-Tools Adoption Readiness Tests" "bash tools/test_stdout_no_tools_adoption_readiness_packet.sh" "planning/stdout-no-tools-production-confirmation-burst-40-2026-05-08/adoption-readiness-packet.json" "requires private planning adoption packet"
run_suite_optional "Artifact Reuse Stdout/No-Tools Disabled Switch Tests" "bash tools/test_stdout_no_tools_switch_dry_run_receipt.sh" "config/production_feature_flags/phase3_stdout_no_tools_artifact_reuse.json" "requires private stdout/no-tools feature flag"
run_suite "Artifact Reuse Stdout/No-Tools Full Private Dry-Run Tests" "bash tools/test_stdout_no_tools_full_private_dry_run_receipt.sh"
run_suite_optional "Artifact Reuse Stdout/No-Tools Private Enablement Authorization Review Tests" "bash tools/test_stdout_no_tools_private_enablement_authorization_review.sh" "planning/stdout-no-tools-full-private-dry-run-burst-44a-2026-05-09/enablement-authorization-packet.json" "requires private planning authorization packet"
run_suite_optional "Artifact Reuse Stdout/No-Tools Private Default Canary Tests" "bash tools/test_stdout_no_tools_private_default_canary_receipt.sh" "config/production_feature_flags/phase3_stdout_no_tools_artifact_reuse.json" "requires private stdout/no-tools feature flag"
run_suite "Current-Cycle Cost Stack Input Builder Tests" "bash tools/test_current_cycle_cost_stack_inputs.sh"
run_suite "Model Routing Binding Receipt Tests" "bash tools/test_model_routing_binding_receipt.sh"
run_suite_optional "Output Shape Experiment Tests" "bash tools/test_output_shape_experiment.sh" "config/experiment_output_shape_policies/burst22-output-shape-v1.json" "requires private output-shape experiment policy"
run_suite "Output Shape Amplification Receipt Tests" "bash tools/test_output_shape_amplification_trace_receipt.sh"
run_suite_optional "Source Pruning Experiment Tests" "bash tools/test_source_pruning_experiment.sh" "runs/product_runs/20260430T115004Z_production_proof/artifacts/workspace/newsletter_phase3_working_set_2026-04-16.md" "requires retained source-pruning proof fixtures"
run_suite_optional "Phase 3 Compact Working-Set Gate Packet Tests" "bash tools/test_phase3_compact_working_set_gate_packet.sh" "config/production_feature_flags/phase3_compact_working_set_gate.json" "requires private compact working-set feature flag"
run_suite "Phase 3 V2 Readiness Tests" "bash tools/test_phase3_v2_readiness.sh"
run_suite_optional "Integrated Cost Optimization Stack Render Tests" "bash tools/test_cost_opt_stack_orchestrator.sh" "config/production_feature_flags/newsletter_cost_opt_stack_default.json" "requires private cost-stack feature flag"
run_suite "Source Pruning Amplification Receipt Tests" "bash tools/test_source_pruning_amplification_receipt.sh"
run_suite "Source Pruning Variance Receipt Tests" "bash tools/test_source_pruning_variance_receipt.sh"
run_suite_optional "Source Pruning Variance RCA Receipt Tests" "bash tools/test_source_pruning_variance_rca_receipt.sh" "config/experiment_pruning_policies/burst26-source-candidate-v2.json" "requires private source-pruning repair policy"
run_suite "Production Source Pruning Amplification Receipt Tests" "bash tools/test_production_source_pruning_amplification_receipt.sh"
run_suite_optional "Closed-Bundle Source Pruning Tests" "bash tools/test_closed_bundle_source_pruning.sh" "runs/product_runs/20260430T163723Z_benchmark_proof/artifacts" "requires retained benchmark proof fixture"
run_suite "Closed-Bundle Source Pruning Replication Receipt Tests" "bash tools/test_closed_bundle_source_pruning_replication_receipt.sh"
run_suite_optional "Phase Session Telemetry Tests" "bash tools/test_phase_session_telemetry.sh" "runs/product_runs/20260430T165856Z_production_proof/run-metadata.json" "requires retained phase telemetry proof fixture"
run_suite "Phase Route-Lock Telemetry Tests" "bash tools/test_phase_route_lock_telemetry.sh"
run_suite_optional "Phase 1C Calibration Receipt Tests" "bash tools/test_phase1c_calibration_receipt.sh" "runs/product_runs/20260501T024928Z_benchmark_proof/run-metadata.json" "requires retained calibration proof fixtures"
run_suite_optional "Control-Surface Drift Guard" "bash tools/test_control_surface_drift.sh" "planning/HANDOFF.md" "requires private planning docs"
run_suite "Phase 3 Instruction Validator" "python3 tools/validate_phase3_instruction_contract.py"

# Layer 3: Scoring tools
run_suite "Structural Scoring (30pt)" "bash tools/score-structural.sh > /dev/null"
run_suite "Heuristic Scoring (41pt)" "bash tools/score-heuristic.sh > /dev/null"

# Layer 4: Integration / benchmark
run_suite "Newsletter Validation (Feb 2026)" "bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh output/2026-02_february_newsletter.md > /dev/null"
run_suite "External Critique Proving Ground" "bash tools/test_external_critique_proving_ground.sh"
run_suite "Benchmark Regression (3 cycles)" "bash tools/test_benchmark_regression.sh"

# Layer 5: Intelligence checks
run_suite "Intelligence Sync (7 surfaces)" "bash tools/check_intelligence_sync.sh > /dev/null"
run_suite "Intelligence Effectiveness (7 gaps)" "bash tools/test_intelligence_effectiveness.sh > /dev/null"
run_suite "Polishing Rules (6 checks)" "bash tools/test_polishing_rules.sh > /dev/null"

# Summary
echo "══════════════════════════════════════════════════════"
echo "  Results: $PASSED_SUITES/$TOTAL_SUITES suites passed, $SKIPPED_SUITES skipped"
echo "══════════════════════════════════════════════════════"
echo ""
printf "$RESULTS"
echo ""

if [ "$FAILED_SUITES" -eq 0 ]; then
  echo "** ALL REQUIRED SUITES PASS **"
  exit 0
else
  echo "** $FAILED_SUITES SUITE(S) FAILED **"
  exit 1
fi

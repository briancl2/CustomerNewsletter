#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Editorial Intelligence Pipeline
# ══════════════════════════════════════════════════════════════
# Orchestrates the full editorial intelligence extraction loop.
#
# Usage: ./tools/run_editorial_intel.sh [phase]
#   Phases: analyze | mine | synthesize | all
#
# Follows autonomous_loops_guide.md:
#   BUILD → MEASURE → SCORE → DIAGNOSE → FIX → MEASURE AGAIN

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

COPILOT="copilot"
MODEL="${MODEL:-}"
COPILOT_MODEL_ARGS=()
if [ -n "$MODEL" ]; then
  COPILOT_MODEL_ARGS=(--model "$MODEL")
fi
INTEL_DIR="runs/editorial-intelligence"
CLI_TIMEOUT=600

log()  { echo ""; echo "══ $1 ══"; echo ""; }
info() { echo "  ▸ $1"; }
pass() { echo "  ✅ $1"; }
fail() { echo "  ❌ $1"; }

# ── Phase A: Structural Analysis (deterministic, free) ──
phase_analyze() {
  log "Phase A: Structural Analysis (deterministic)"
  bash tools/analyze-newsletters.sh "$INTEL_DIR/phase-a"

  if [ -f "$INTEL_DIR/phase-a/analysis.md" ] && [ -f "$INTEL_DIR/phase-a/metrics.csv" ]; then
    pass "Phase A complete: $(wc -l < "$INTEL_DIR/phase-a/analysis.md" | tr -d ' ') lines of analysis"
  else
    fail "Phase A output missing"
    exit 1
  fi
}

# ── Phase B+C: Fleet Editorial Mining (parallel, LLM) ──
phase_mine() {
  log "Phase B+C: Fleet Editorial Mining (6 parallel agents)"

  mkdir -p "$INTEL_DIR"/{themes,selection,evolution,patterns,weights}

  info "Dispatching fleet with 6 editorial analysts..."
  info "This runs 6 parallel LLM agents analyzing different aspects of editorial history."

  "$COPILOT" "${COPILOT_MODEL_ARGS[@]}" \
    -p "/fleet $(cat tools/fleet_editorial_mining.md)" \
    --allow-all --no-ask-user \
    2>&1 | tee "$INTEL_DIR/fleet-mining.log"

  log "Fleet complete - disk verification"

  local ok=0
  local missing=""
  for f in themes/theme-detection.md \
           selection/december-selection-analysis.md \
           selection/august-selection-analysis.md \
           evolution/era-evolution.md \
           patterns/expansion-compression.md \
           weights/audience-calibration.md; do
    if [ -f "$INTEL_DIR/$f" ]; then
      local lines
      lines=$(wc -l < "$INTEL_DIR/$f" | tr -d ' ')
      if [ "$lines" -ge 20 ]; then
        ok=$((ok + 1))
        info "$f: $lines lines"
      else
        missing="$missing $f(${lines}L-thin)"
      fi
    else
      missing="$missing $f(MISSING)"
    fi
  done

  info "Complete: $ok/6"
  if [ -n "$missing" ]; then
    fail "Missing or thin:$missing"
    fail "Fleet mining insufficient (${ok}/6 reports) - re-run or dispatch individual agents"
    return 1
  fi

  pass "Fleet mining complete (${ok}/6 reports)"
}

# ── Phase D: Synthesis (combine findings into actionable intelligence) ──
phase_synthesize() {
  log "Phase D: Synthesis"

  local SYNTH_PROMPT="You are synthesizing editorial intelligence findings into actionable skill improvements.

Read ALL of these files (they are the output of 6 parallel editorial analysts + structural analysis):
1. runs/editorial-intelligence/phase-a/analysis.md (structural metrics for 14 newsletters)
2. runs/editorial-intelligence/themes/theme-detection.md (theme patterns)
3. runs/editorial-intelligence/selection/december-selection-analysis.md (Dec selection funnel)
4. runs/editorial-intelligence/selection/august-selection-analysis.md (Aug selection funnel)
5. runs/editorial-intelligence/evolution/era-evolution.md (era evolution)
6. runs/editorial-intelligence/patterns/expansion-compression.md (expansion/compression)
7. runs/editorial-intelligence/weights/audience-calibration.md (audience weights)

If any file is missing, work with what exists.

Produce THREE deliverables:

DELIVERABLE 1: reference/editorial-intelligence.md (max 300 lines)
The accumulated editorial knowledge base. Structure:
- Theme Detection Rules (when to create lead sections, with evidence)
- Selection Priority Weights (calibrated from data, not generic)
- Expansion Triggers (what makes an item expansion-worthy)
- Compression Rules (what triggers consolidation)
- Audience-Specific Signals (Healthcare/Manufacturing/FinServ emphasis patterns)
- Blind Spots (what the human does that rules don't capture yet)
- Cross-Cycle Patterns (what's consistent vs. conditional)

DELIVERABLE 2: reference/editorial-questions.md (max 50 lines)
Questions for the human curator to answer. These address ambiguities and blind spots found during analysis. Format as numbered questions, each with:
- The question
- Why we're asking (what data triggered this question)
- Multiple choice options where applicable
- How the answer would change the selection criteria

DELIVERABLE 3: Update .github/skills/content-curation/references/selection-criteria.md
Replace the current equal-weight criteria with the empirically-calibrated weights from the analysis. Keep the same structure but make the priorities data-driven.

After writing all 3 files:
- Update HYPOTHESES.md: resolve EH-1 through EH-10 with evidence
- Update LEARNINGS.md: add lessons L11+ from the analysis findings
- Run: make validate-all-skills (to ensure nothing broke)
- Report what you changed and key findings"

  info "Dispatching synthesis agent..."
  timeout "${CLI_TIMEOUT}" "$COPILOT" "${COPILOT_MODEL_ARGS[@]}" \
    -p "$SYNTH_PROMPT" \
    --allow-all --no-ask-user \
    2>&1 | tee "$INTEL_DIR/synthesis.log"

  log "Synthesis complete - disk verification"

  local missing=0
  for f in reference/editorial-intelligence.md \
           reference/editorial-questions.md; do
    if [ -f "$f" ]; then
      pass "$f exists ($(wc -l < "$f" | tr -d ' ') lines)"
    else
      fail "$f missing"
      missing=1
    fi
  done

  if [ "$missing" -ne 0 ]; then
    fail "Synthesis deliverables missing - failing pipeline"
    exit 1
  fi
}

# ── Dispatch ──
PHASE="${1:-all}"
case "$PHASE" in
  analyze)
    phase_analyze
    ;;
  mine)
    phase_mine
    ;;
  synthesize)
    phase_synthesize
    ;;
  all)
    phase_analyze
    phase_mine
    phase_synthesize
    log "EDITORIAL INTELLIGENCE PIPELINE COMPLETE"
    echo "Review:"
    echo "  Structural analysis: $INTEL_DIR/phase-a/analysis.md"
    echo "  Theme patterns:      $INTEL_DIR/themes/theme-detection.md"
    echo "  Selection funnels:   $INTEL_DIR/selection/"
    echo "  Era evolution:       $INTEL_DIR/evolution/era-evolution.md"
    echo "  Exp/compression:     $INTEL_DIR/patterns/expansion-compression.md"
    echo "  Audience weights:    $INTEL_DIR/weights/audience-calibration.md"
    echo "  Editorial intel:     reference/editorial-intelligence.md"
    echo "  Curator questions:   reference/editorial-questions.md"
    ;;
  *)
    echo "Usage: $0 [analyze|mine|synthesize|all]"
    exit 1
    ;;
esac

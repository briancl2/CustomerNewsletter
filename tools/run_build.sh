#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Outer Loop Orchestrator — Newsletter Agent System Build
# ══════════════════════════════════════════════════════════════
#
# Implements: BUILD → MEASURE → SCORE → DIAGNOSE → FIX → MEASURE AGAIN
# Based on: reference/autonomous_loops_guide.md
#
# Usage:
#   ./tools/run_build.sh [phase]
#   Phases: preflight | fleet | score | test | rework | refactor | ship | all
#
# Key principles:
#   - Trust disk, not self-reports (every gate checks files with ls/wc)
#   - Cheapest test first (structural → heuristic → LLM-judge)
#   - One fix per iteration
#   - Max 5 rework cycles total, max 3 per skill
#   - Feed forward: update LEARNINGS.md after every run
#   - RUN_ID scoped artifacts for comparison
# ══════════════════════════════════════════════════════════════

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# ── Config ──
PHASE="${1:-all}"
COPILOT="copilot"
MODEL="${MODEL:-}"
MAX_REWORK_TOTAL=5
MAX_REWORK_PER_SKILL=3
CLI_TIMEOUT=600  # seconds per CLI session
RUN_ID=$(date -u '+%Y%m%dT%H%M%SZ')
RUN_DIR="runs/$RUN_ID"

SKILLS=(url-manifest content-retrieval content-consolidation events-extraction content-curation newsletter-assembly newsletter-validation kb-maintenance)

# ── Helpers ──
log()  { echo ""; echo "══ $1 ══"; echo ""; }
info() { echo "  ▸ $1"; }
pass() { echo "  ✅ $1"; }
fail() { echo "  ❌ $1"; }
warn() { echo "  ⚠️  $1"; }

COPILOT_MODEL_ARGS=()
if [ -n "$MODEL" ]; then
  COPILOT_MODEL_ARGS=(--model "$MODEL")
fi

init_run() {
  mkdir -p "$RUN_DIR"/{scores,logs,diagnostics,artifacts}
  echo "$RUN_ID" > "$RUN_DIR/.run_id"
  echo "run_start: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$RUN_DIR/STATUS.md"
  info "Run ID: $RUN_ID"
  info "Run dir: $RUN_DIR"
}

# Disk-based gate: verify file exists and has content
gate_file() {
  local path="$1"
  local min_bytes="${2:-1}"
  if [ -f "$path" ]; then
    local size
    size=$(wc -c < "$path" | tr -d ' ')
    if [ "$size" -ge "$min_bytes" ]; then
      return 0
    fi
  fi
  return 1
}

# Disk-based gate: verify file has minimum line count
gate_lines() {
  local path="$1"
  local min_lines="$2"
  if [ -f "$path" ]; then
    local lines
    lines=$(wc -l < "$path" | tr -d ' ')
    if [ "$lines" -ge "$min_lines" ]; then
      return 0
    fi
  fi
  return 1
}

# Update hypothesis status
update_hypothesis() {
  local id="$1"
  local status="$2"  # confirmed|falsified|partially
  local evidence="$3"
  info "Hypothesis $id -> $status ($evidence)"
  echo "| $id | $status | $evidence | $RUN_ID |" >> "$RUN_DIR/diagnostics/hypothesis-results.md"
}

# ══════════════════════════════════════════════════════════════
# Phase 0: Pre-flight
# ══════════════════════════════════════════════════════════════
phase_preflight() {
  log "Phase 0: Pre-flight checks"

  # Read learnings from previous runs
  if [ -f "LEARNINGS.md" ]; then
    info "LEARNINGS.md exists ($(wc -l < LEARNINGS.md | tr -d ' ') lines)"
  else
    warn "No LEARNINGS.md -- first run"
  fi

  # Read hypothesis ledger
  if [ -f "HYPOTHESES.md" ]; then
    local untested
    untested=$(grep -c "untested" HYPOTHESES.md || true)
    info "HYPOTHESES.md: $untested untested hypotheses"
  fi

  # Structural checks (cheapest first)
  info "Running make validate-structure..."
  if make validate-structure 2>&1; then
    pass "Repo structure valid"
  else
    fail "Repo structure invalid -- cannot proceed"
    exit 1
  fi

  info "Running make validate-all-skills..."
  if make validate-all-skills 2>&1; then
    pass "All skills structurally valid"
  else
    fail "Skill validation failed -- cannot proceed"
    exit 1
  fi

  # Disk checks: verify required skills and examples populated
  local skill_count example_count missing_required=0
  skill_count=$(find .github/skills -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  example_count=$(find .github/skills/*/examples -type f 2>/dev/null | wc -l | tr -d ' ')
  info "Skills discovered: $skill_count | Required build skills: ${#SKILLS[@]} | Example files: $example_count"

  for skill in "${SKILLS[@]}"; do
    if [ ! -f ".github/skills/$skill/SKILL.md" ]; then
      fail "Required skill missing: .github/skills/$skill/SKILL.md"
      missing_required=$((missing_required + 1))
    fi
  done
  if [ "$missing_required" -gt 0 ]; then
    fail "Missing required build skills: $missing_required"
    exit 1
  fi
  if [ "$example_count" -lt "${#SKILLS[@]}" ]; then
    fail "Expected >=${#SKILLS[@]} example files, found $example_count"
    exit 1
  fi

  # Disk check: copilot CLI available
  if command -v "$COPILOT" &>/dev/null; then
    pass "Copilot CLI available: $($COPILOT --version 2>&1 | head -1)"
  else
    fail "Copilot CLI not found"
    exit 1
  fi

  echo "phase_0: PASS" >> "$RUN_DIR/STATUS.md"
  pass "Pre-flight complete"
}

# ══════════════════════════════════════════════════════════════
# Phase 1: Fleet Build
# ══════════════════════════════════════════════════════════════
phase_fleet() {
  log "Phase 1: Fleet parallel skill building (8 skills)"

  local fleet_log="$RUN_DIR/logs/fleet-build.log"

  info "Dispatching fleet orchestrator..."
  info "Output: $fleet_log"
  info "Timeout: none (fleet manages its own lifecycle)"

  "$COPILOT" "${COPILOT_MODEL_ARGS[@]}" \
    -p "/fleet $(cat tools/fleet_build_skills.md)" \
    --allow-all --no-ask-user \
    2>&1 | tee "$fleet_log"

  log "Fleet complete -- disk verification"

  # DISK VERIFICATION (trust disk, not self-reports)
  local built=0
  local failed_skills=""
  for skill in "${SKILLS[@]}"; do
    local f=".github/skills/$skill/SKILL.md"
    if gate_lines "$f" 50; then
      built=$((built + 1))
      info "$skill: $(wc -l < "$f" | tr -d ' ') lines"
    else
      failed_skills="$failed_skills $skill"
      if [ -f "$f" ]; then
        warn "$skill: only $(wc -l < "$f" | tr -d ' ') lines (need >50)"
      else
        fail "$skill: SKILL.md missing!"
      fi
    fi
  done

  info "Built: $built/8"

  # Test hypothesis BH-1
  if [ "$built" -eq 8 ]; then
    update_hypothesis "BH-1" "confirmed" "8/8 skills >=50 lines"
  else
    update_hypothesis "BH-1" "falsified" "${built}/8 skills >=50 lines; failed:${failed_skills}"
  fi

  # Test hypothesis BH-2: reference files
  local refs_ok=0
  for skill in "${SKILLS[@]}"; do
    local has_ref=false
    for ref in ".github/skills/$skill/references/"*.md; do
      [ ! -f "$ref" ] && continue
      if gate_lines "$ref" 20; then
        has_ref=true
        break
      fi
    done
    $has_ref && refs_ok=$((refs_ok + 1))
  done
  if [ "$refs_ok" -eq 8 ]; then
    update_hypothesis "BH-2" "confirmed" "8/8 skills have >=1 reference >=20 lines"
  else
    update_hypothesis "BH-2" "falsified" "${refs_ok}/8 skills have adequate references"
  fi

  echo "phase_1_fleet: built=${built}/8 refs=${refs_ok}/8" >> "$RUN_DIR/STATUS.md"

  if [ "$built" -lt 8 ]; then
    warn "Not all skills built. Run 'rework' phase to fix."
    return 1
  fi
  pass "Fleet build complete"
}

# ══════════════════════════════════════════════════════════════
# Phase 2: Score (layered, cheapest first)
# ══════════════════════════════════════════════════════════════
phase_score() {
  log "Phase 2: Layered scoring"

  # Layer 1: Structural (free)
  info "Layer 1: Structural rubric..."
  if bash tools/score-structural.sh "$RUN_DIR" 2>&1; then
    pass "Structural rubric PASSED"
  else
    fail "Structural rubric FAILED -- fix before proceeding"
    echo "phase_2_score: structural=FAIL" >> "$RUN_DIR/STATUS.md"
    return 1
  fi

  # Layer 2: Heuristic (~5s)
  info "Layer 2: Heuristic scoring..."
  if bash tools/score-heuristic.sh "$RUN_DIR" 2>&1; then
    pass "Heuristic scoring PASSED"
  else
    warn "Heuristic scoring FAILED -- weakest tier needs rework"
    echo "phase_2_score: heuristic=FAIL" >> "$RUN_DIR/STATUS.md"
    return 1
  fi

  # Layer 3: LLM-as-judge (expensive, only if L1+L2 pass)
  # Deferred to test phase -- we don't burn tokens until structure + heuristics are clean

  echo "phase_2_score: structural=PASS heuristic=PASS" >> "$RUN_DIR/STATUS.md"
  pass "All scoring layers passed"
}

# ══════════════════════════════════════════════════════════════
# Phase 3: Test (sequential benchmark testing)
# ══════════════════════════════════════════════════════════════
phase_test() {
  log "Phase 3: Sequential benchmark testing"

  mkdir -p "$RUN_DIR/artifacts"

  for skill in "${SKILLS[@]}"; do
    echo ""
    info "Testing: $skill"

    local test_log="$RUN_DIR/logs/test-${skill}.log"
    local test_report="$RUN_DIR/artifacts/test-${skill}.md"

    # Build test prompt with explicit deliverable + stop rules
    local TEST_PROMPT
    case "$skill" in
      url-manifest)
        TEST_PROMPT="You are testing the url-manifest skill. Do these steps in order:
1. Read .github/skills/url-manifest/SKILL.md
2. Read the benchmark example: .github/skills/url-manifest/examples/newsletter_phase1a_url_manifest_2025-10-06_to_2025-12-02.md
3. Compare: does the skill's workflow cover all 5 sources in the benchmark? Does it specify URL patterns that would generate the benchmark URLs?
4. Write a test report to $test_report with these fields:
   - sources_covered: number out of 5
   - format_match: yes/no
   - missing_logic: list of gaps (or 'none')
   - verdict: PASS or FAIL
Max 50 lines. Do not write any other files."
        ;;
      content-retrieval)
        TEST_PROMPT="You are testing the content-retrieval skill. Do these steps:
1. Read .github/skills/content-retrieval/SKILL.md
2. Read ONE benchmark interim file: .github/skills/content-retrieval/examples/newsletter_phase1b_interim_github_2025-10-06_to_2025-12-02.md
3. Compare: does the skill define the extraction format fields that appear in the benchmark?
4. Write a test report to $test_report with: fields_match (yes/no), 5_source_structure (yes/no), missing_logic (list), verdict (PASS/FAIL).
Max 50 lines."
        ;;
      content-consolidation)
        TEST_PROMPT="You are testing the content-consolidation skill. Do these steps:
1. Read .github/skills/content-consolidation/SKILL.md
2. Read the benchmark: .github/skills/content-consolidation/examples/newsletter_phase1a_discoveries_2025-10-06_to_2025-12-02.md (first 100 lines)
3. Compare: does the skill specify dedup rules, category taxonomy, and enterprise filter matching the benchmark structure?
4. Write a test report to $test_report with: dedup_rules (yes/no), category_taxonomy (yes/no), item_count_target (what the skill says vs benchmark ~40), verdict (PASS/FAIL).
Max 50 lines."
        ;;
      events-extraction)
        TEST_PROMPT="You are testing the events-extraction skill. Do these steps:
1. Read .github/skills/events-extraction/SKILL.md
2. Read the benchmark: .github/skills/events-extraction/examples/newsletter_phase2_events_2025-12-02.md
3. Compare: virtual table format, in-person bullet format, category taxonomy, date-only for virtual events.
4. Write a test report to $test_report with: virtual_format (yes/no), categories (list found), standard_content_blocks (yes/no), verdict (PASS/FAIL).
Max 50 lines."
        ;;
      content-curation)
        TEST_PROMPT="You are testing the content-curation skill. Do these steps:
1. Read .github/skills/content-curation/SKILL.md
2. Read the benchmark: .github/skills/content-curation/examples/newsletter_phase3_curated_sections_2025-12-02.md (first 100 lines)
3. Compare: section structure (Lead, Latest Releases, Copilot at Scale), IDE parity pattern, selection criteria.
4. Write a test report to $test_report with: section_structure (yes/no), ide_parity_pattern (yes/no), selection_criteria (yes/no), verdict (PASS/FAIL).
Max 50 lines."
        ;;
      newsletter-assembly)
        TEST_PROMPT="You are testing the newsletter-assembly skill. Do these steps:
1. Read .github/skills/newsletter-assembly/SKILL.md
2. Read the benchmark: .github/skills/newsletter-assembly/examples/December.md (first 50 lines for structure)
3. Verify: section order, no Dylan's Corner, mandatory changelog links, mandatory YouTube playlists.
4. Write a test report to $test_report with: section_order (yes/no), no_dylan (yes/no), changelog_links (yes/no), youtube_playlists (yes/no), verdict (PASS/FAIL).
Max 50 lines."
        ;;
      newsletter-validation)
        TEST_PROMPT="You are testing the newsletter-validation skill. Do these steps:
1. If .github/skills/newsletter-validation/scripts/validate_newsletter.sh exists, run: bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh .github/skills/newsletter-validation/examples/December.md
2. Report the exit code and any output.
3. If the script doesn't exist, report FAIL.
4. Write a test report to $test_report with: script_exists (yes/no), exit_code (number), output (summary), verdict (PASS/FAIL).
Max 50 lines."
        ;;
      kb-maintenance)
        TEST_PROMPT="You are testing the kb-maintenance skill. Do these steps:
1. Check if .github/skills/kb-maintenance/scripts/poll_sources.py exists. If yes, run: python3 .github/skills/kb-maintenance/scripts/poll_sources.py --dry-run 2>&1 | head -20
2. Check if .github/skills/kb-maintenance/scripts/check_link_health.py exists. If yes, run: python3 .github/skills/kb-maintenance/scripts/check_link_health.py --dry-run --sample 3 2>&1 | head -20
3. Write a test report to $test_report with: poll_exists (yes/no), poll_exit_code, health_exists (yes/no), health_exit_code, verdict (PASS/FAIL).
Max 50 lines."
        ;;
    esac

    # Dispatch inner session
    timeout "${CLI_TIMEOUT}" "$COPILOT" "${COPILOT_MODEL_ARGS[@]}" \
      -p "$TEST_PROMPT" \
      --allow-all --no-ask-user \
      2>&1 | tee "$test_log" || true

    # DISK VERIFICATION of test report
    if gate_file "$test_report" 50; then
      local verdict
      verdict=$(grep -i "verdict" "$test_report" | head -1 || echo "unknown")
      info "$skill: report written -- $verdict"
    else
      warn "$skill: NO test report on disk (agent may have failed silently)"
      echo "VERDICT: FAIL (no report produced)" > "$test_report"
    fi
  done

  # Summarize
  echo ""
  log "Test Summary"
  local pass_count=0
  for skill in "${SKILLS[@]}"; do
    local report="$RUN_DIR/artifacts/test-${skill}.md"
    if [ -f "$report" ] && grep -qi "PASS" "$report"; then
      pass "$skill"
      pass_count=$((pass_count + 1))
    else
      fail "$skill"
    fi
  done

  echo "phase_3_test: ${pass_count}/8 passed" >> "$RUN_DIR/STATUS.md"
  info "Passed: $pass_count/8"
}

# ══════════════════════════════════════════════════════════════
# Phase 4: Rework (diagnose weakest, fix one thing, re-measure)
# ══════════════════════════════════════════════════════════════
phase_rework() {
  log "Phase 4: Rework loop (max $MAX_REWORK_TOTAL iterations)"

  local iteration=0
  local rework_counts=""  # track per-skill rework counts

  while [ "$iteration" -lt "$MAX_REWORK_TOTAL" ]; do
    iteration=$((iteration + 1))
    info "Rework iteration $iteration/$MAX_REWORK_TOTAL"

    # Re-score to find weakest dimension
    local weakest=""
    local weakness_detail=""

    # Layer 1
    if ! bash tools/score-structural.sh "$RUN_DIR" 2>/dev/null; then
      weakest="structural"
      weakness_detail=$(grep "FAIL\|MISSING" "$RUN_DIR/scores/structural-rubric.md" 2>/dev/null | head -3)
    # Layer 2
    elif ! bash tools/score-heuristic.sh "$RUN_DIR" 2>/dev/null; then
      weakest="heuristic"
      weakness_detail=$(grep "FAIL\|PARTIAL" "$RUN_DIR/scores/heuristic-scores.md" 2>/dev/null | head -3)
    else
      pass "All scoring layers pass -- rework complete"
      break
    fi

    info "Weakest layer: $weakest"
    info "Detail: $weakness_detail"

    # Identify the specific skill to fix (first failing)
    local target_skill=""
    for skill in "${SKILLS[@]}"; do
      local f=".github/skills/$skill/SKILL.md"
      if ! gate_lines "$f" 50; then
        target_skill="$skill"
        break
      fi
      local ref_count
      ref_count=$(find ".github/skills/$skill/references" -type f -name '*.md' -size +100c 2>/dev/null | wc -l | tr -d ' ')
      if [ "$ref_count" -eq 0 ]; then
        target_skill="$skill"
        break
      fi
    done

    if [ -z "$target_skill" ]; then
      # Fall back to the skill mentioned in the weakness detail
      for skill in "${SKILLS[@]}"; do
        if echo "$weakness_detail" | grep -q "$skill"; then
          target_skill="$skill"
          break
        fi
      done
    fi

    if [ -z "$target_skill" ]; then
      warn "Cannot identify target skill for rework -- stopping"
      break
    fi

    # Check per-skill rework cap
    local skill_count
    skill_count=$(echo "$rework_counts" | grep -c "$target_skill" || true)
    if [ "$skill_count" -ge "$MAX_REWORK_PER_SKILL" ]; then
      warn "$target_skill hit max rework cap ($MAX_REWORK_PER_SKILL). Skipping."
      continue
    fi
    rework_counts="$rework_counts $target_skill"

    info "Fixing: $target_skill (weakness: $weakest)"

    # Dispatch ONE targeted fix
    local fix_log="$RUN_DIR/logs/rework-${iteration}-${target_skill}.log"
    local FIX_PROMPT="You must fix ONE specific issue in .github/skills/$target_skill/.

Issue category: $weakest
Specific problems:
$weakness_detail

Instructions:
1. Read .github/skills/$target_skill/SKILL.md
2. Read .github/skills/building-skill/SKILL.md for the spec
3. Read the relevant prompt file in .github/prompts/ and agent section in .github/agents/customer_newsletter.agent.md
4. Make the MINIMUM change to fix the identified issue
5. Do NOT change any files outside .github/skills/$target_skill/

Stop rules:
- Change at most 2 files
- Total new content: max 200 lines
- Do not rewrite from scratch -- patch the existing content"

    timeout "${CLI_TIMEOUT}" "$COPILOT" "${COPILOT_MODEL_ARGS[@]}" \
      -p "$FIX_PROMPT" \
      --allow-all --no-ask-user \
      2>&1 | tee "$fix_log" || true

    info "Rework $iteration complete. Re-measuring..."
  done

  if [ "$iteration" -ge "$MAX_REWORK_TOTAL" ]; then
    warn "Hit max rework iterations ($MAX_REWORK_TOTAL). Shipping current best."
  fi

  echo "phase_4_rework: ${iteration} iterations" >> "$RUN_DIR/STATUS.md"
}

# ══════════════════════════════════════════════════════════════
# Phase 5: Agent Refactor
# ══════════════════════════════════════════════════════════════
phase_refactor() {
  log "Phase 5: Agent refactor"

  local refactor_log="$RUN_DIR/logs/refactor.log"

  local REFACTOR_PROMPT="Refactor .github/agents/customer_newsletter.agent.md from ~455 lines to ~150 lines body (excluding frontmatter).

DELETE all inline domain logic now in skills:
- URL pattern details -> url-manifest skill
- Extraction format details -> content-retrieval skill
- Consolidation rules -> content-consolidation skill
- Events formatting rules -> events-extraction skill
- Content selection criteria -> content-curation skill
- Assembly rules, templates, section ordering -> newsletter-assembly skill
- ALL Dylan's Corner references (Decision D11)
- All mermaid diagrams

KEEP:
- Mission statement and audience
- Pipeline overview table (Phase -> Skill -> Input -> Output)
- Category taxonomy (4 categories, 1 line each)
- Key formatting rules (3-4 bullet summary)
- Skill references (links to each SKILL.md)
- Done-when criteria
- Standard intro/closing templates (brief)

Stop rules: Agent body must be <=150 lines. Total file <=200 lines.
Deliverable: Modified .github/agents/customer_newsletter.agent.md
Verification: After editing, run wc -l on the file and report the count."

  timeout "${CLI_TIMEOUT}" "$COPILOT" "${COPILOT_MODEL_ARGS[@]}" \
    -p "$REFACTOR_PROMPT" \
    --allow-all --no-ask-user \
    2>&1 | tee "$refactor_log" || true

  # DISK VERIFICATION
  local agent_lines dylan_count skill_refs
  agent_lines=$(wc -l < .github/agents/customer_newsletter.agent.md | tr -d ' ')
  dylan_count=$(grep -ci "dylan" .github/agents/customer_newsletter.agent.md || true)
  skill_refs=$(grep -c "\.github/skills/" .github/agents/customer_newsletter.agent.md || true)

  info "Agent lines: $agent_lines (target: <=200)"
  info "Dylan refs: $dylan_count (target: 0)"
  info "Skill refs: $skill_refs (target: >=8)"

  # Test BH-5
  if [ "$agent_lines" -le 200 ] && [ "$dylan_count" -eq 0 ]; then
    update_hypothesis "BH-5" "confirmed" "agent=${agent_lines}L, dylan=0"
    pass "Agent refactor complete"
  else
    update_hypothesis "BH-5" "falsified" "agent=${agent_lines}L, dylan=${dylan_count}"
    warn "Agent refactor did not fully succeed"
  fi

  echo "phase_5_refactor: lines=$agent_lines dylan=$dylan_count refs=$skill_refs" >> "$RUN_DIR/STATUS.md"
}

# ══════════════════════════════════════════════════════════════
# Phase 6: Ship Gate (multi-layer)
# ══════════════════════════════════════════════════════════════
phase_ship_gate() {
  log "Phase 6: Ship gate (multi-layer)"

  local pass_count=0
  local gate_count=6

  # Gate 1: Structural rubric
  if bash tools/score-structural.sh "$RUN_DIR" 2>/dev/null; then
    pass "Gate 1: Structural rubric"
    pass_count=$((pass_count + 1))
  else
    fail "Gate 1: Structural rubric"
  fi

  # Gate 2: Heuristic scoring
  if bash tools/score-heuristic.sh "$RUN_DIR" 2>/dev/null; then
    pass "Gate 2: Heuristic scoring"
    pass_count=$((pass_count + 1))
  else
    fail "Gate 2: Heuristic scoring"
  fi

  # Gate 3: make validate-all-skills
  if make validate-all-skills 2>/dev/null; then
    pass "Gate 3: Skill validation"
    pass_count=$((pass_count + 1))
  else
    fail "Gate 3: Skill validation"
  fi

  # Gate 4: No Dylan's Corner
  local dylan_total
  dylan_total=$(grep -ri "Dylan" .github/skills/ .github/agents/ 2>/dev/null | grep -v "examples/" | wc -l | tr -d ' ')
  if [ "$dylan_total" -eq 0 ]; then
    pass "Gate 4: No Dylan's Corner ($dylan_total refs)"
    pass_count=$((pass_count + 1))
  else
    fail "Gate 4: Dylan's Corner found ($dylan_total refs)"
  fi

  # Gate 5: Agent <=200 lines
  local agent_lines
  agent_lines=$(wc -l < .github/agents/customer_newsletter.agent.md | tr -d ' ')
  if [ "$agent_lines" -le 200 ]; then
    pass "Gate 5: Agent size ($agent_lines lines)"
    pass_count=$((pass_count + 1))
  else
    fail "Gate 5: Agent too large ($agent_lines lines, max 200)"
  fi

  # Gate 6: All 8 skills have SKILL.md >50 lines + >=1 reference
  local skills_complete=0
  for skill in "${SKILLS[@]}"; do
    if gate_lines ".github/skills/$skill/SKILL.md" 50; then
      local ref_count
      ref_count=$(find ".github/skills/$skill/references" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
      [ "$ref_count" -ge 1 ] && skills_complete=$((skills_complete + 1))
    fi
  done
  if [ "$skills_complete" -eq 8 ]; then
    pass "Gate 6: All skills complete ($skills_complete/8)"
    pass_count=$((pass_count + 1))
  else
    fail "Gate 6: Incomplete skills ($skills_complete/8)"
  fi

  echo ""
  echo "Ship gate: $pass_count/$gate_count"
  echo "phase_6_ship_gate: ${pass_count}/${gate_count}" >> "$RUN_DIR/STATUS.md"

  if [ "$pass_count" -eq "$gate_count" ]; then
    pass "ALL GATES PASS -- ready to generate February 2026 newsletter"
    return 0
  else
    fail "$((gate_count - pass_count)) gate(s) failed"
    return 1
  fi
}

# ══════════════════════════════════════════════════════════════
# Phase 7: Post-run (diagnostics, feed-forward)
# ══════════════════════════════════════════════════════════════
phase_postrun() {
  log "Phase 7: Post-run diagnostics"

  # Finalize STATUS.md
  echo "run_end: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$RUN_DIR/STATUS.md"

  # Summarize hypothesis results
  if [ -f "$RUN_DIR/diagnostics/hypothesis-results.md" ]; then
    info "Hypothesis results:"
    cat "$RUN_DIR/diagnostics/hypothesis-results.md"
  fi

  # List all artifacts created
  info "Artifacts created:"
  find "$RUN_DIR" -type f | sort | while read -r f; do
    local size
    size=$(wc -c < "$f" | tr -d ' ')
    echo "    $f (${size}b)"
  done

  # Prompt for LEARNINGS.md update
  echo ""
  info "Review $RUN_DIR/STATUS.md and update LEARNINGS.md with new lessons."
  info "Next run will read LEARNINGS.md at Phase 0."

  pass "Post-run complete"
}

# ══════════════════════════════════════════════════════════════
# Dispatch
# ══════════════════════════════════════════════════════════════
case "$PHASE" in
  preflight)
    init_run
    phase_preflight
    ;;
  fleet)
    init_run
    phase_fleet
    ;;
  score)
    init_run
    phase_score
    ;;
  test)
    init_run
    phase_test
    ;;
  rework)
    init_run
    phase_rework
    ;;
  refactor)
    init_run
    phase_refactor
    ;;
  ship)
    init_run
    phase_ship_gate
    ;;
  all)
    init_run
    phase_preflight
    phase_fleet
    phase_score || phase_rework  # If score fails, rework then re-score
    phase_score || { warn "Score still failing after rework"; }
    phase_test
    phase_refactor
    phase_ship_gate || warn "Ship gate did not fully pass"
    phase_postrun
    log "BUILD COMPLETE -- Run ID: $RUN_ID"
    echo "Review: cat $RUN_DIR/STATUS.md"
    echo "Next: Generate February 2026 newsletter"
    echo "  @customer_newsletter Generate the February 2026 newsletter (DATE_RANGE: 2026-01-01 to 2026-02-10)"
    ;;
  *)
    echo "Usage: $0 [preflight|fleet|score|test|rework|refactor|ship|all]"
    echo ""
    echo "Loop: preflight -> fleet -> score -> [rework] -> test -> refactor -> ship -> postrun"
    echo "  all    Run the full loop"
    echo ""
    echo "Individual phases:"
    echo "  preflight  Verify env, check learnings + hypotheses"
    echo "  fleet      Fleet parallel skill building (8 sub-agents)"
    echo "  score      Layered scoring (structural -> heuristic)"
    echo "  test       Sequential benchmark testing per skill"
    echo "  rework     Diagnose weakest, fix one thing, re-measure (max $MAX_REWORK_TOTAL)"
    echo "  refactor   Slim agent from 455 -> ~150 lines"
    echo "  ship       Multi-layer ship gate"
    exit 1
    ;;
esac

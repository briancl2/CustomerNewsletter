# How to Build Autonomous Agent Loops

> A practitioner's guide to hypothesis-driven, self-measuring, self-correcting agent systems.
> Distilled from 20+ autonomous runs across 4 models, 5 targets, and 3 weeks of iteration.

---

## The Core Idea

You build something. You measure it. You score it against a rubric. You find the weakest point. You fix that one thing. You measure again. The loop runs until a ship gate passes or you hit a wall.

Everything else — hypothesis testing, competitive builds, feed-forward learnings — exists to make that loop faster and more honest.

---

## 1. The Loop

```
BUILD → MEASURE → SCORE → DIAGNOSE → FIX → MEASURE AGAIN
  ↑                                              |
  └──────────────────────────────────────────────┘
```

**Phases (from the RUNBOOK):**

| Phase | What happens | Gate to proceed |
|---|---|---|
| 0: Pre-flight | Verify env, set hypotheses, confirm rubrics | All paths exist |
| 1: Build | Construct the thing (or skip if it exists) | ≥1 build above rubric threshold |
| 2: Measure | Static analysis, line counts, schema checks | Scores + manifest on disk |
| 3: Diagnose | Compare to baselines, find weakest point | Rework dispatched or threshold met |
| 4: Learn | Update learnings file, memorialize evidence | Learnings + roadmap on disk |
| 5: Test | Functional/quality testing against real targets | ≥1 quality score on disk |
| 6: Ship gate | Multi-layer pass/fail decision | All layers pass → ship |
| 7: Post-run | Diagnostics, handoff, session log parsing | Always runs |

**Key rule: every phase gate checks files on disk.** Not self-reports. Not summaries. `ls` and `wc -c`.

---

## 2. Hypothesis Testing

Every loop iteration should test at least one hypothesis. Untested hypothesis count must not grow between runs.

### How to write a hypothesis

```
ID:        MH-4
Statement: Critic pass finds ≥3 defects
Threshold: ≥3 defects found OR <3 defects found
Status:    untested → confirmed/falsified/partially tested
Evidence:  run ID + specific artifacts
```

### Rules

1. **Always pick the cheapest untested hypothesis first.** If it takes <5 minutes, there is no reason to defer. (L2)
2. **A hypothesis needs a pass/fail threshold before you test it.** "See what happens" is not a hypothesis.
3. **Record the result even if it's negative.** Falsified hypotheses are data, not failures.
4. **Maintain a ledger.** Track status across runs so nothing falls through cracks.

### Example from this project

| ID | Hypothesis | Result |
|---|---|---|
| MH-1 | Prompt files are the universal weakness | **Confirmed** — avg 4.5/10 vs agent 9.0/10 |
| MH-2 | Conversational patterns break --no-ask-user | **Partially falsified** — no hard failure |
| QH-5 | Advisor struggles with high-complexity targets | **Falsified** — no complexity penalty found |
| QH-6 | Patches from B4 are syntactically valid | **Confirmed** — 7/7 pass `git apply --check` |

Falsified hypotheses are just as valuable. QH-5 being wrong means you don't need to build complexity-aware routing — that's saved work.

---

## 3. Rubric Scoring

### Why rubrics

Vibes don't compound. Rubrics do.

A rubric converts "this feels better" into "this scores 34/41, up from 31/41, because tier-2 criteria C8 went from FAIL to PASS after the prompt fix." That's actionable. That feeds forward.

### The scoring stack (layered, cheapest first)

| Layer | What it measures | Cost | Tool |
|---|---|---|---|
| **Structural rubric** | Does the build have the right files/structure? | Free | `scripts/score-rubric.sh` |
| **Chain test** | Does it execute without crashing? | ~20 min | `scripts/run-advisor-chain-test.sh` |
| **Heuristic scorer** | Are structural quality markers present? (41 criteria) | ~5 sec | `scripts/score-output-quality.sh` |
| **LLM-as-judge** | Is the content semantically correct? (5 dims × 5pt) | ~5 min | `scripts/score-output-quality-llm.sh` |
| **Panel of judges** | Multi-perspective semantic scoring (3 judges × 5 dims) | ~15 min | `scripts/score-output-quality-panel.sh` |

**Run them in order.** If structural rubric fails, don't waste tokens on LLM judges. Gate expensive checks behind cheap ones.

### Heuristic tiers

```
Tier 1 (26 pts): Structural — files exist, sections present, format correct
Tier 2 (10 pts): Content — depth, specificity, actionability
Tier 3 (5 pts):  Semantic — path validity, patch context, no hallucination
```

Tier 1 is deterministic grep. Tier 2 needs line-counting heuristics. Tier 3 needs cross-referencing against the target repo. Each tier catches things the previous tier missed.

### Ship gate (multi-layer)

All layers must pass on ≥3 build×target pairs to ship:

| Layer | Threshold |
|---|---|
| Build structure rubric | ≥24/30 |
| Chain test | ≥4/6 PASS |
| Heuristic tier-1 | ≥22/26 |
| Heuristic tier-2 | ≥6/10 |
| Heuristic tier-3 | ≥3/5 |
| Panel median | ≥15/25 |
| No single judge | ≥10/25 |

A build that passes structural checks but fails semantic checks is not ship-ready. That's the whole point of layering.

---

## 4. The Build/Test/Measure/Rework Loop

This is the tight inner loop (Phases 3-6 of the RUNBOOK). Run up to 5 iterations.

### Each iteration:

1. **Identify the weakest scoring dimension.** Look at the rubric breakdown, not the total.
2. **Make exactly one targeted change.** Edit one prompt, one agent, one config file.
3. **Document what you changed and why.** Write `prompt-changes.md` with: what changed, which criterion it targets, expected effect.
4. **Re-measure.** Run the same scoring pipeline. Compare before/after.
5. **Decide:** improved → continue or ship. Regressed → rollback. Flat for 2 cycles → stop.

### Decision table

| Condition | Action |
|---|---|
| All gates pass on ≥3 pairs | **Ship** |
| Heuristic tier-2 < 6/10 | Fix advisor prompts, investigate reasoning |
| LLM-judge < 15/25 | Fix advisor prompts, investigate reasoning |
| Rubric < 24/30 | Fix build structure |
| Rubric unchanged 2 cycles | Stop. Ship current best. |
| Rubric regressed | Rollback immediately |

---

## 5. Feed-Forward Learnings

Learnings are the compound interest of the loop. Every run should produce at least one lesson that makes the next run better.

### The LEARNINGS.md pattern

```markdown
| ID | Lesson | Evidence | Fix |
|---|---|---|---|
| L1 | Analysis without action is the default failure mode | 3 runs: 2000+ lines, 0 files modified | 40/60 rule enforcement |
```

Every lesson has:
- **ID** — for referencing in future prompts and decisions
- **Evidence** — specific run, specific artifact, specific numbers
- **Fix** — concrete change to process, prompts, or tooling

### Anti-patterns and design patterns

Track both. Design patterns that correlate with quality:

| Pattern | Why it works |
|---|---|
| File-driven config (not "ask the user") | Agents in non-interactive mode can't ask; file reads always work |
| Explicit stop rules per prompt | Prevents runaway output; B4 (6/6 stop rules) scored 34.7/36 vs B3 (2/6) at 31.3/36 |
| Named agent files with `model:` field | Without this, fleet sub-agents silently default to cheapest model |
| Multi-pass pipeline with critic | Critic found 3 real defects that single-pass missed |

Anti-patterns to avoid:

| Anti-pattern | What goes wrong |
|---|---|
| "Ask the user" in non-interactive context | Agent profiles itself instead of the target (B3-T1: 7/25) |
| Cutting untested features | 0 invocations = 0 tests ≠ 0 value (L17) |
| Synthesis that accepts cuts uncritically | Competitive framing collapses into mediocre compromise (L18) |
| Trusting self-reports over disk verification | Agents claim "quality testing complete" with 0 files on disk (L8) |

### Root Cause Analysis

When something fails badly, do a proper RCA:

```
Causal chain: "Ask the user" → no user in fleet mode → agent profiles itself → wrong target → 7/25 LLM score

Contributing factors:
  - "Ask the user" prompt pattern (40%)
  - Empty TARGETS.md fallback (25%)
  - Missing agent: routing field (15%)
  - No stop rule on file count (10%)
  - Fleet mode environment (10%)
```

RCAs produce the highest-signal learnings because they trace failure to root cause, not symptoms.

---

## 6. Competitive Builds

Run the same task on multiple models/surfaces and compare:

| Build | Model | Surface | Rubric | Heuristic |
|---|---|---|---|---|
| B1 | GPT-5.3-Codex | Codex-app | baseline | — |
| B2 | GPT-5.2-Codex | Fleet | baseline | — |
| B3 | Opus 4.6 | Fleet | 24/30 | 31.3/36 |
| B4 | Opus 4.6 | Autopilot | **30/30** | **34.7/36** |

### Why this works

- Different models emphasize different concerns (Opus: architecture; GPT: simplicity; Sonnet: implementation)
- The rubric makes comparison objective
- "Innovation lives in the losers" — B2 (ranked last) produced the most architecturally novel feature
- Competitive planning followed by synthesis produces better plans than single-model planning

### Watch out for

- Synthesis rounds that soften all competitive tension into compromise (L18)
- Human review is essential after competitive rounds — LLM synthesis alone drifts to median
- The spec (input) determines quality more than the process — garbage in, garbage out even with a perfect loop

---

## 7. The Outer Loop / Inner Loop Architecture

```
OUTER LOOP (orchestrator)
  ├── dispatches inner CLI sessions
  ├── reads their artifacts + session logs
  ├── cross-checks self-reports against ground truth
  ├── scores at every phase gate
  └── decides: re-run, fix, or ship

INNER LOOP (worker agent)
  ├── receives a specific task prompt
  ├── executes with --allow-all --no-ask-user
  ├── produces artifacts + self-diagnostic
  └── stdout captured via tee
```

### Why two loops

The inner agent does the work but cannot be trusted to evaluate its own work. The outer agent reads the artifacts AND the session log, cross-checks claims, and makes the ship/iterate decision.

### The dispatch pattern

```bash
copilot -p "$(cat <prompt>)" \
  --allow-all --no-ask-user \
  2>&1 | tee runs/$RUN_ID/<phase>-stdout.txt
```

- `--allow-all`: let the agent use all tools
- `--no-ask-user`: prevent blocking on human input
- `tee`: capture everything for post-hoc analysis
- Session logs at `~/.copilot/session-state/<id>/events.jsonl` for ground truth

### Cross-check protocol

After every inner session:
1. Read the agent's self-diagnostic
2. Parse the session log for actual tool call counts
3. Compare: did it do what it said it did?
4. If discrepancy > threshold, flag and investigate

---

## 8. Key Principles

These are the operational truths that emerged from running this system:

1. **Execution first.** ≤40% of effort on analysis, ≥60% on building and measuring. Analysis without action is the default failure mode.

2. **Trust disk, not self-reports.** Verify artifacts exist with `ls` and `wc -c`. Agents will claim they completed testing when no test files exist.

3. **Cheapest test first.** Run free structural checks before burning tokens on LLM judges. Run the 3-minute hypothesis before the 3-hour one.

4. **One fix per iteration.** Change one thing, measure the delta. If you change three things and the score improves, you don't know which fix mattered.

5. **Rubrics over vibes.** Convert subjective quality assessments into deterministic, numbered criteria. A rubric that's 80% right beats an assessment that's 100% subjective.

6. **Feed forward everything.** Every run produces lessons. Lessons go in LEARNINGS.md. Learnings get read at Phase 0 of the next run. The system gets smarter.

7. **Falsification > confirmation.** A falsified hypothesis saves work. QH-5 ("advisor struggles with complexity") being wrong means you skip building complexity routing.

8. **Ship gates must be multi-layer.** Structural PASS ≠ quality. Chain test PASS ≠ good advice. You need structural + functional + heuristic + semantic layers to catch the full spectrum of failures.

9. **Competitive diversity, not consensus.** Different models produce different architectures. Cherry-pick from all of them. Don't let synthesis rounds flatten the competition.

10. **Stop rules prevent runaway.** Cap iterations (max 5 rework cycles). Cap output ("5 opportunities max"). Cap time (600s timeout per command). Agents without limits will analyze forever.

---

## 9. Quickstart: Your First Autonomous Loop

```bash
# 1. Set up the run
RUN_ID=$(date -u '+%Y%m%dT%H%M%SZ')
mkdir -p runs/$RUN_ID/{diagnostics,scores,quality}

# 2. Build (or point at existing build)
BUILD_PATH=~/repos/my-agent-project

# 3. Measure — structural rubric
bash scripts/score-rubric.sh $BUILD_PATH > runs/$RUN_ID/scores/rubric.md

# 4. Test — run against a real target
bash scripts/run-advisor-chain-test.sh $BUILD_PATH targets/T4-territory-manager \
  runs/$RUN_ID/quality/B-T4 T4

# 5. Score — heuristic quality
ARTIFACTS=$(find runs/$RUN_ID/quality/B-T4/artifacts -maxdepth 1 -type d -name '20*' | head -1)
bash scripts/score-output-quality.sh "$ARTIFACTS" targets/T4-territory-manager \
  runs/$RUN_ID/quality/B-T4/heuristic-scores.md

# 6. Diagnose — read the scores, find the weakest criterion
cat runs/$RUN_ID/quality/B-T4/heuristic-scores.md

# 7. Fix — edit the specific prompt/agent that governs the weakest criterion

# 8. Repeat from step 3
```

---

## 10. The Full Autonomous Launch

One command to run the entire Phase 0-7 cycle with zero human intervention:

```bash
cd ~/repos/build-meta-analysis
RUN_ID=$(date -u '+%Y%m%dT%H%M%SZ')
mkdir -p runs/$RUN_ID/{diagnostics,scores,data,quality}
echo "$RUN_ID" > runs/$RUN_ID/.run_id

copilot --model claude-opus-4.6 \
  -p "Your run ID is $RUN_ID. $(cat .github/agents/outer-loop-orchestrator.agent.md)" \
  --allow-all --no-ask-user \
  2>&1 | tee runs/$RUN_ID/orchestrator-stdout.txt
```

After it completes:
```bash
cat STATUS.md                                    # What changed
cat runs/$RUN_ID/diagnostics/SESSION-DIAGNOSTIC.md # Self-grade
cat runs/$RUN_ID/quality/*/heuristic-scores.md     # Quality scores
```

The orchestrator reads STATUS.md, skips completed phases, runs whatever's next, scores at every gate, updates STATUS.md, and produces a handoff for the next run. Full loop completes in ~10 minutes for incremental work, ~2-5 hours for full cross-build quality validation.

---

*This guide is a living document. It should be updated as the loop evolves and new learnings emerge.*

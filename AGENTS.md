# AGENTS.md

> Primary AI instruction surface for briancl2-customer-newsletter (platform-agnostic).
> Monthly GitHub customer newsletter pipeline: 6-phase LLM-driven system with skills, scoring, and intelligence mining.

## Operating Protocol

Every change follows this numbered workflow. No exceptions.
1. **Hypothesize** -- State a testable prediction with explicit PASS criteria (HIGR)
2. **Score** -- Define a scoring rubric with acceptance threshold
3. **Plan** -- Design the approach before building
4. **Build** -- Implement the change
5. **Test** -- Validate against PASS criteria using layered scoring (cheapest first)
6. **Fix** -- Iterate until all criteria pass
7. **Validate** -- Run quality checks (scoring battery and tests)
8. **Document** -- Update HYPOTHESES.md, LEARNINGS.md, HANDOFF.md
9. **Clean up** -- Delete old implementations (Deletion Discipline), archive stale artifacts
10. **Report + Handoff** -- Write HANDOFF.md for session continuity

## Core Principles

- **Deletion Discipline**: Replace directly. No `_v2` suffixes, no parallel code paths.
- **LLM-First**: Agent-orchestrated workflows over deterministic scripts.
- **Skills-First**: Check `.github/skills/` before implementing ad-hoc procedures.
- **HIGR**: Every change is a testable hypothesis with PASS criteria.
- **Trust Disk, Not Self-Reports**: Verify by reading files, not trusting agent claims.
- **Layered Scoring (Cheapest First)**: Structural → Heuristic → Selection → Editorial.
- **Feed-Forward Learnings**: Every finding becomes an L-number in LEARNINGS.md.
- **Benchmark-Grounded**: Score against benchmark data, not intuition.

## Agents (3)

| # | Agent | Purpose |
|---|---|---|
| 1 | customer_newsletter | 6-phase pipeline orchestrator |
| 2 | editorial-analyst | Editorial intelligence mining + corrections |
| 3 | skill-builder | Create and validate new skills |

## Skills (17)

| # | Skill | Purpose |
|---|---|---|
| 1 | url-manifest | Phase 1a: Discover announcement URLs |
| 2 | content-retrieval | Phase 1b: Fetch and extract content |
| 3 | content-consolidation | Phase 1c: Merge discoveries |
| 4 | events-extraction | Phase 2: Extract events and dates |
| 5 | content-curation | Phase 3: Select and organize content |
| 6 | newsletter-assembly | Phase 4: Assemble final newsletter |
| 7 | newsletter-validation | Validate assembled newsletter |
| 8 | newsletter-polishing | Phase 4.5: Apply editorial polish |
| 9 | video-matching | Phase 4.6: Match YouTube videos to entries |
| 10 | editorial-review | Post-assembly editorial corrections |
| 11 | kb-maintenance | Knowledge base upkeep |
| 12 | testing-prompt-changes | A/B test prompt modifications |
| 13 | building-skill | Create new skills (meta-skill) |
| 14 | scope-contract | Manage scope boundaries |
| 15 | curator-notes | Phase 1.5: Process curator brain dump |
| 16 | session-log-manager | Archive and health-check session logs |
| 17 | deprecation-consolidation | Phase 4.5: Consolidate deprecation notices |

Skills are at `.github/skills/<name>/SKILL.md`.

## Scoring Tools (Layered, Cheapest First)

| Layer | Tool | Max | Use |
|---|---|---|---|
| 1 | `tools/score-structural.sh` | 30 | Gate: must pass before Layer 2 |
| 2 | `tools/score-heuristic.sh` | 41 | Quality dimensions check |
| 3 | `tools/score-selection.sh` | 25 | Content selection quality |
| 4 | `tools/score-v2-rubric.sh` | 50 | Full editorial rubric |

## Key Files

| File | Purpose |
|---|---|
| HYPOTHESES.md | Hypothesis ledger — testable predictions |
| LEARNINGS.md | Append-only operational lessons |
| .github/skills/ | 17 skills |
| tools/ | Scoring + build automation |
| reference/ | Editorial intelligence + source intelligence |
| kb/ | Knowledge base (sources, taxonomy, maintenance) |

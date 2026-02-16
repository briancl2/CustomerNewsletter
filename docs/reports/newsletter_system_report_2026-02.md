# Building a Self-Learning Newsletter System with GitHub Copilot

**Report Date:** February 2026 | **Repository:** Private source repository (sanitized for public release) | **Audience:** Copilot developers and technical practitioners

---

## Executive Summary

If you want the short version first:
- Start here: [`launch/2026-02/start-here.md`](../launch/2026-02/start-here.md)
- Case study: [`launch/2026-02/case-study.md`](../launch/2026-02/case-study.md)
- Timeline: [`launch/2026-02/timeline.md`](../launch/2026-02/timeline.md)

In February 2026, a manually curated Copilot newsletter workflow was rebuilt into a Copilot-assisted pipeline that can draft a full issue from a one-line prompt, then be brought to “ship ready” with a light editorial pass.

The core design is a loop: generate a draft, run checks, review what’s off, turn those notes into durable rules (skills, prompts, reference docs, validators), then rerun. The goal isn’t “no humans.” The goal is that repeated fixes don’t need to be repeated.

A big unlock was treating the historical corpus as more than finished newsletters. The incremental git edits and publication-time polish capture how “good” was reached (what got removed, reordered, reframed, and tightened). Those patterns were turned into reusable instructions and checks.

The rest of this document is the deep technical write-up: architecture, data sources, and the decisions that made the workflow more reliable.

---

# Part 1: How It Was Built

## The Problem

GitHub ships 30-50 changelog entries per month, VS Code now ships weekly releases, JetBrains pushes 3-4 plugin updates, and strategic announcements appear on `github.blog/news-insights/` separately from the changelog. Enterprise customers cannot keep up -- updates are scattered across 9+ sources with no single enterprise-focused view.

The curator's monthly newsletter filled this gap, but it had become unsustainable. Each issue required 4-6 hours of manual assembly. The curator had tried using Copilot with ad-hoc prompt files, but the prompts were harder to maintain than the time they saved -- a messy collection that became another thing to debug rather than a solution.

## The Old System: 2,456 Lines of Monolithic Prompts

The initial commit (`f6340a7`) preserved the old approach: **2,456 lines across 8 files**, each encoding an entire pipeline phase in one monolithic document. The largest -- `phase_1b_content_retrieval.prompt.md` at 678 lines -- tried to handle per-source extraction strategies for 5 different source types in a single prompt. The `customer_newsletter.agent.md` was 454 lines of pipeline logic, audience rules, formatting, and orchestration crammed into one file.

When output had problems (wrong dates, hallucinated links, version misattributions), the curator edited the generated markdown directly. There was no feedback loop. The same errors recurred every month. Fixes never propagated back to the prompts.

## The New System: Conversational Chat Turns → Permanent Intelligence

The current system inverts this entirely. The curator interacts through **short, natural chat turns** in VS Code:

> *"the Copilot at Scale section doesn't really make sense. GHEC and GHES updates in there are not copilot related at all."*

> *"combine the two secret scanning entries"*

> *"put the GHAS trials first"*

Each note triggers: RCA → update skill files → regenerate from updated rules → validate. The human never touches the newsletter markdown directly. **In the old system, fixes were applied to the output. In the new system, fixes are applied to the intelligence.**

A 10-word note in Copilot Chat produces a systemic fix in under 2 minutes, including regeneration and validation.

## Build Sprint: Feb 9-12 (56 commits)

The 454-line monolithic agent shrank to 81 lines (a pure orchestrator). Domain logic moved into 16 SKILL.md files following the [Agent Skills](https://agentskills.io) specification. Intelligence was mined from 14 newsletters, 132 edit diffs, and 72 SOURCES.yaml entries.

**Copilot features used**: VS Code Agent Mode (primary), Copilot CLI (`make review`), custom agents (`.agent.md`), custom instructions (`AGENTS.md`), prompt files (`.prompt.md`), Agent Skills (`SKILL.md`), GitHub Actions CI, `/fleet` for parallel sub-agent research.

**Key decisions**: Skills-first architecture (L42), file-driven configuration, disk-based phase gates (L2), deletion discipline, feed-forward learnings (L1-L69).

For detailed build plans, see [planning/BUILD_PLAN.md](planning/BUILD_PLAN.md), sprint designs at [planning/sprint-automation.md](planning/sprint-automation.md), [planning/sprint-polishing-intelligence.md](planning/sprint-polishing-intelligence.md), [planning/sprint-feed-forward.md](planning/sprint-feed-forward.md), [planning/sprint-pipeline-hardening.md](planning/sprint-pipeline-hardening.md), and session handoff at [planning/HANDOFF.md](planning/HANDOFF.md).

---

# Part 2: Self-Learning Evolution

## The Self-Healing Loop

Every bug becomes a permanent fix through a mechanical loop:

```
Bug found → RCA → Distill learning → Update skills → Regenerate → Verify → Record
```

69 learnings (L1-L69) and 56 hypotheses (43 confirmed, 1 partially confirmed, 1 falsified, 11 untested) across the sprint. The 10-step Operating Protocol in `AGENTS.md` governs every change.

## How Intelligence Propagates

A single human correction follows this path: **learning recorded** (LEARNINGS.md) → **format spec updated** (content-format-spec.md) → **quality check added** (quality-checklist.md) → **validation script updated** (validate_newsletter.sh) → **skill instructions updated** (SKILL.md) → **scoring catches violations** → **next generation never regresses**.

The `check_intelligence_sync.sh` script verifies propagation across 7 surfaces. This is infrastructure, not convention.

## Key Self-Healing Examples

**L64 -- Agent fabricated release dates.** VS Code v1.108 ("December 2025") released Jan 8 was excluded. The agent fabricated "released Nov 2025" and confirmed its own wrong answer 3 times. Fix: mechanical fetch of the VS Code updates index page at Phase 0, 1A, and 1B. Gate: ≥2 versions for 30+ day ranges.

**L66 -- Weekly releases break version-centric output.** 2 monthly versions produced a "latest + afterthought" pattern. With weekly cadence (4-5 versions), this would produce 5 afterthought bullets. Fix: diff-based extraction (read newest first, diff earlier for status changes). 3-layer rewrite across 12 files.

**L68 -- Eight corrections become eight systemic rules.** One editorial review produced: link labels never include status text, surface attribution enforced at assembly, every bullet gets docs links, revenue-positive items sort first, enterprise items in Enterprise & Security not Copilot at Scale, same-domain consolidation mandatory, commercial context on cost-relevant features, section naming reflects content scope. Pre: 44/50. Post: 49/50.

**L69 -- Microsoft Reactor as systematic source.** 28 GitHub-tagged Reactor events existed but the pipeline never scanned them. Added filtering rules (English, GitHub-integrated, enterprise-relevant). Events section grew from 5 to 13 virtual events.

## Evolution Metrics

| Metric | Value |
|--------|-------|
| Learnings | 69 (L1-L69) |
| Hypotheses confirmed | 43/44 tested (97.7%) |
| Score progression | 31→50/50 (first run), 44→49/50 (Feb 2026) |
| Polishing patterns mined | 13 from 132 diffs (34% eliminable) |
| Skills | 8 initial → 16 final |

---

# Part 3: New Features vs Previous Newsletters

| Feature | Previous Newsletters | Feb 2026 Generated |
|---------|--------------------|--------------------|
| Video links with duration | None | Labels include duration (e.g., `Video (60m)`). |
| MS Learn courses | None | 4 courses with episodes, durations, levels |
| Docs/implementation links | Changelog only | Changelog + VS Code Setup + Docs |
| Inline feature linking (7+ links) | Sub-bullet lists | Feature names ARE the links in prose |
| Per-model GA/PREVIEW labels | Prose grouping | Every model individually labeled |
| Cross-IDE alignment matrix | Sparse, Eclipse missing | All 4 IDEs, every feature labeled |
| Microsoft Reactor events | 0-2 occasional | 8+ filtered from 28 candidates |
| Resources section | None | 7 items: GH-AW, Orchestra, prompt engineering, etc. |
| Commercial context | Missing | "no additional cost, existing terms apply" |
| Revenue-first ordering | Arbitrary | Revenue-positive items first per section |
| Same-domain consolidation | Duplicate bullets | Single bullets per topic area |

**Section structure evolution**: `Copilot → Scale → Security → Events` became `Lead → Copilot → IDE Parity → Copilot at Scale (links only) → Enterprise & Security → Resources → Events (with MS Learn) → Migration Notices`.

**Content density**: 29 GA/PREVIEW labels (vs 18 in target), 67 links (vs 49), 34 table rows (vs 21), 20 unique domains (vs 11).

---

# Part 4: Session Metrics

| Metric | Value |
|--------|-------|
| Commits | 56 across 4 days |
| VS Code tool calls | 278 (34.5% terminal, 22.7% read_file, 18.3% todo, 6.5% edit) |
| Strategy | Action-dominant (0.53 action ratio) |
| Hypotheses requiring 0 rework | 40/43 (93%) |
| Score improvement per rework | +4 points average |
| Learnings per commit | 1.23 |
| Fleet research report | 4 parallel sub-agents, 7m 26s wall time (13m 30s API), ~3 PRUs |

---

# Appendix: System Inventory

**16 Skills**: url-manifest, content-retrieval, content-consolidation, curator-notes, events-extraction, content-curation, newsletter-assembly, newsletter-polishing, video-matching, newsletter-validation, editorial-review, scope-contract, kb-maintenance, testing-prompt-changes, building-skill, reviewing-code-locally

**7 Scoring Tools**: score-structural (30pt), score-heuristic (41pt), score-selection (25pt), score-v2-rubric (50pt), score-sync, score-automation, score-sprint

**Key Reference Files**: editorial-intelligence.md (7 sections), polishing-intelligence.md (13 patterns), curator-notes-intelligence.md, source-intelligence/ (5 per-source files + meta-analysis), fleet_best_practices.md

**Key System Files**: AGENTS.md (operating protocol), LEARNINGS.md (69 entries), HYPOTHESES.md (56 hypotheses), kb/SOURCES.yaml (72 sources), Makefile (33 targets)

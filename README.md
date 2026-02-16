# Customer Newsletter Generator

A fully automated, skills-based system for generating monthly GitHub customer newsletters. Built with hypothesis-driven development, layered scoring, and iterative editorial intelligence mining.

## Quick Start

```bash
# Validate repository health
make validate-structure
make validate-all-skills

# Generate and validate February 2026 window
make newsletter START=2025-12-05 END=2026-02-13
make validate-newsletter FILE=output/2026-02_february_newsletter.md
```

VS Code flow: open the repo, select the `customer_newsletter` agent, then run:

```text
please generate the february newsletter from scratch for the dates Dec 05 2025 to Feb 13 2026
```

Copilot CLI equivalent:

```bash
copilot --agent customer_newsletter \
  --model claude-opus-4.6 \
  --allow-all \
  --no-ask-user \
  -p "please generate the february newsletter from scratch for the dates Dec 05 2025 to Feb 13 2026"
```

More context: [release_bundle/2026-02_newsletter_launch/START_HERE.md](release_bundle/2026-02_newsletter_launch/START_HERE.md)

## System Overview

| Component | Count | Key Files |
|-----------|-------|-----------|
| **Skills** | 12 | `.github/skills/*/SKILL.md` |
| **Agents** | 3 | `.github/agents/*.agent.md` |
| **Prompts** | 7 | `.github/prompts/*.prompt.md` |
| **Scoring tools** | 7 | `tools/score-*.sh` |
| **KB sources** | 72 | `kb/SOURCES.yaml` |
| **Reference docs** | 16 | `reference/` |

## 6-Phase Pipeline

| Phase | Skill | Input | Output |
|-------|-------|-------|--------|
| 1A | url-manifest | DATE_RANGE, SOURCES.yaml | Candidate URLs |
| 1B | content-retrieval | URL manifest | 5 interim files |
| 1C | content-consolidation | Interim files | 30-50 discoveries |
| 2 | events-extraction | Event URLs | Event tables |
| 3 | content-curation | Discoveries | 15-20 curated sections |
| 4 | newsletter-assembly | Curated + Events | Final newsletter |
| 5 | editorial-review | Human corrections | Updated newsletter |

## Target Audience

Engineering Managers, DevOps Leads, and IT Leadership at large regulated enterprises (Healthcare, Manufacturing, Financial Services).

## Key Directories

| Path | Purpose |
|------|---------|
| `.github/skills/` | 11 pipeline and meta skills |
| `.github/prompts/` | Phase prompts + pipeline orchestrator |
| `reference/` | Editorial intelligence, source intelligence, methodology |
| `kb/` | Knowledge base with 72 source entries |
| `tools/` | Scoring, build automation, archival scripts |
| `output/` | Final newsletter files |
| `archive/` | Historical newsletters by year |
| `workspace/` | Pipeline intermediates (gitignored) |
| `benchmark/` | 16 cycles, 339 files (gitignored) |

## Methodology

- **HIGR** (Hypothesis-Implement-Grade-Rework) for all changes
- **Layered scoring**: structural (free) -> heuristic (5s) -> selection (benchmark) -> editorial rubric
- **Feed-forward learnings**: 57 lessons captured in `LEARNINGS.md`
- **Skills-first**: domain logic in skills, agent is a pure orchestrator (87 lines)

## Makefile Targets

```bash
make help                      # Show all 32 targets
make validate-all-skills       # Validate all skills
make validate-newsletter FILE= # Validate a newsletter
make validate-kb               # KB link health check
make kb-poll                   # Poll sources for new content
make score-all                 # Run all scoring layers
make newsletter START= END=   # Full pipeline orchestration
```

## Documentation

- [Build Plan](planning/BUILD_PLAN.md) -- phased implementation plan
- [Handoff](planning/HANDOFF.md) -- project state for session continuity
- [Hypotheses](HYPOTHESES.md) -- 46 tracked, 43 confirmed
- [Learnings](LEARNINGS.md) -- 57 lessons with evidence and fixes

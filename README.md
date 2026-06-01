# Customer Newsletter Generator

A fully automated, skills-based system for generating monthly GitHub customer newsletters. Built with hypothesis-driven development, layered scoring, and iterative editorial intelligence mining.

## Quick Start

```bash
# Validate repository health
make validate-structure
make validate-all-skills

# Canonical production command
copilot --model gpt-5.5 --allow-all --deny-tool agent --no-ask-user --stream off \
  -p "$(bash tools/render_product_run_prompt.sh 2026-02-14 2026-04-16 production)"
```

Convenience wrapper over the same canonical command:

```bash
make newsletter-gen START=2026-02-14 END=2026-04-16 MODE=production
```

Retained proof-run wrapper over the same oracle:

```bash
make newsletter-proof-run START=2026-02-14 END=2026-04-16 MODE=production
```

The proof-run wrapper snapshots canonical `workspace/` and `output/` artifacts
into retained private run evidence without replacing the raw prompt-rendered
production authority.

Live operator paths:

- `make newsletter-gen START=2026-02-14 END=2026-04-16 MODE=production`
- `make newsletter-proof-run START=2026-02-14 END=2026-04-16 MODE=production`

Experiment-only optimization helpers:

- `make newsletter-cost-profiler`
- `make newsletter-hotspot-auditor`
- `make newsletter-phase-experimenter`
- `make newsletter-orchestrated-proof`

`newsletter-orchestrated` stays diagnostic-only for phase-local debugging and
regression diagnosis. `newsletter-orchestrated-proof` packages that diagnostic
path as retained evidence with phase-session telemetry for cost experiments.

Retained production authority lives in the private source repository. The public
snapshot keeps the runnable pipeline, selected outputs, and customer-safe bundle
material, but not raw run logs or session evidence.

VS Code flow: open the repo, select the `customer_newsletter` agent, then run:

```text
please generate the april newsletter from scratch for the dates Feb 14 2026 to Apr 16 2026
```

Benchmark command on the same prompt-rendered surface:

```bash
bash tools/prepare_newsletter_cycle.sh 2025-12-05 2026-02-13 --no-reuse
copilot --model gpt-5.5 --allow-all --deny-tool agent --no-ask-user --stream off \
  -p "$(bash tools/render_product_run_prompt.sh 2025-12-05 2026-02-13 benchmark)"
```

## Primary Regression Benchmark

Public benchmark-mode contract: `config/benchmark_modes/feb2026_consistency.json`

Use this before relying on the diagnostic-only phase harness for regression
claims:

```bash
bash tools/prepare_newsletter_cycle.sh 2025-12-05 2026-02-13 --no-reuse
copilot --model gpt-5.5 --allow-all --deny-tool agent --no-ask-user --stream off \
  -p "$(bash tools/render_product_run_prompt.sh 2025-12-05 2026-02-13 benchmark)"
bash tools/validate_pipeline_strict.sh 2025-12-05 2026-02-13 --require-fresh --benchmark-mode feb2026_consistency
```

Rule:

- treat the single-shot prompt-rendered `copilot -p` run as the production-like oracle
- use `tools/run_newsletter_orchestrated.sh` only after the single-shot benchmark fails and you need phase-local diagnosis
- if a pinned historical commit does not reproduce this benchmark cleanly on the current host, classify execution-surface parity before claiming a repo regression
- for full production runs, use the prompt-rendered command path above and the
  validation commands shown in the release bundles

More context:
- [release_bundle/2026-04_newsletter_launch/START_HERE.md](release_bundle/2026-04_newsletter_launch/START_HERE.md)
- [release_bundle/2026-02_newsletter_launch/public/START_HERE.md](release_bundle/2026-02_newsletter_launch/public/START_HERE.md)

## System Overview

| Component | Count | Key Files |
|-----------|-------|-----------|
| **Skills** | 18 | `.github/skills/*/SKILL.md` |
| **Agents** | 4 | `.github/agents/*.agent.md` |
| **Prompts** | 8 | `.github/prompts/*.prompt.md` |
| **Scoring tools** | 7 | `tools/score-*.sh` |
| **KB sources** | 72 | `kb/SOURCES.yaml` |
| **Reference docs** | 20 | `reference/` |

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
| `.github/skills/` | 18 pipeline and meta skills |
| `.github/prompts/` | 8 phase prompts + pipeline orchestrator |
| `reference/` | Editorial intelligence, source intelligence, methodology |
| `kb/` | Knowledge base with 72 source entries |
| `tools/` | Scoring, build automation, archival scripts |
| `output/` | Final newsletter files |
| `archive/` | Historical newsletters by year |
| `workspace/` | Pipeline intermediates during local runs; public snapshot keeps only `.gitkeep` |
| `benchmark/` | Gitignored benchmark scratch space, created on demand |

## Methodology

- **HIGR** (Hypothesis-Implement-Grade-Rework) for all changes
- **Layered scoring**: structural (free) -> heuristic (5s) -> selection (benchmark) -> editorial rubric
- **Feed-forward learnings**: recurring lessons captured back into skills, validation, and reference guidance
- **Skills-first**: domain logic in skills, agent is a pure orchestrator (87 lines)

## Makefile Targets

```bash
make validate-all-skills       # Validate all skills
make validate-newsletter FILE= # Validate a newsletter
make validate-kb               # KB link health check
make kb-poll                   # Poll sources for new content
make score-all                 # Run all scoring layers
make newsletter START= END=   # Full pipeline orchestration
make help                      # Show all 62 targets
```

## Documentation

- [Public repo guide](reference/public_repo_guide.md) -- publication boundary and review checklist
- [April launch bundle](release_bundle/2026-04_newsletter_launch/START_HERE.md) -- production command and validation gates
- [February public launch bundle](release_bundle/2026-02_newsletter_launch/public/START_HERE.md) -- public case study and runnable example

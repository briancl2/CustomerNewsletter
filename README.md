# CustomerNewsletter

A public, reusable system for drafting enterprise-focused Copilot newsletters.

## Start Here

- Start here (Feb 2026 launch):
  [Start here](https://briancl2.github.io/CustomerNewsletter/launch/2026-02/start-here/)
- Current newsletter:
  [February 2026 newsletter (Discussion #18)](https://github.com/briancl2/CustomerNewsletter/discussions/18)
- Last newsletter:
  [December 2025 newsletter (Discussion #15)](https://github.com/briancl2/CustomerNewsletter/discussions/15)

## Run It

### VS Code Copilot Chat

1. Open this repo in VS Code.
2. Open Copilot Chat and select the `customer_newsletter` agent.
3. Paste this prompt:

```text
i want you to generate a from-scratch brand new february newsletter using the dates Dec 5 2025 to Feb 13 2026
```

### Copilot CLI

Headless mode:

```bash
copilot --agent customer_newsletter \
  --model claude-opus-4.6 \
  --allow-all \
  --no-ask-user \
  -p "i want you to generate a from-scratch brand new february newsletter using the dates Dec 5 2025 to Feb 13 2026"
```

Interactive mode:

```bash
copilot --agent customer_newsletter --model claude-opus-4.6 -i
```

Then paste the same prompt from the VS Code section.

## Principles

- **HIGR:** treat changes like experiments (Hypothesize → Implement → Grade → Rework), not one-off edits.
- **Feed-forward learning:** when something is consistently off, fix the underlying skill/rule so future runs improve.
- **Trust disk, not self-reports:** the system proves work by writing artifacts to `workspace/` and validating them.
- **Layered scoring:** cheap checks first (structure/heuristics), then deeper rubric checks when needed.
- **Skills-first architecture:** domain rules live in `.github/skills/`; the agent stays thin and orchestrates phases.

## Architecture

At a high level, the system is a multi-phase pipeline plus a self-learning loop.

- **End-to-end pipeline:** URL manifest → content retrieval → consolidation → curator notes (optional)
  → event sources → events → content curation → assembly → polishing → validation + scoring.
- **Self-learning loop:** human corrections → learning capture → skill/reference update → regenerate
  → validate + score → future runs improve.
- **Key interfaces:**
  - Agent entrypoint: `.github/agents/customer_newsletter.agent.md`
  - Phase skills: `.github/skills/*/SKILL.md`
  - Phase prompts: `.github/prompts/*.prompt.md`
  - Fresh-cycle prep: `tools/prepare_newsletter_cycle.sh`
  - Strict validation: `tools/validate_pipeline_strict.sh`
  - Deterministic event sources: `kb/EVENT_SOURCES.yaml`, `tools/extract_event_sources.py`

More detail: [docs/architecture.md](docs/architecture.md)

## What You Should See

- Final draft written to `output/2026-02_february_newsletter.md`
- A paper trail in `workspace/` showing what was collected and curated along the way

## Docs

- Launch (Feb 2026):
  - [Start here](docs/launch/2026-02/start-here.md)
  - [Case study](docs/launch/2026-02/case-study.md)
  - [Timeline](docs/launch/2026-02/timeline.md)
- [How it works](docs/how-it-works.md)
- [Architecture](docs/architecture.md)
- [Feb 2026 system report](docs/reports/newsletter_system_report_2026-02.md)

## Repo Layout

- `.github/agents/`: the Copilot agent entrypoints
- `.github/skills/`: the phase skills (the real “how it works”)
- `.github/prompts/`: prompt files the agent uses for each phase
- `kb/`: source intelligence and source lists
- `reference/`: editorial intelligence and other long-lived guidance
- `tools/`: scoring + validation scripts
- `workspace/`: intermediate artifacts produced during a run
- `output/`: final newsletter drafts
- `archive/`: historical newsletters by year

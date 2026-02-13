# AGENTS.md

Primary AI instruction surface for `briancl2/CustomerNewsletter`.

This repository is an open-source, Copilot-first newsletter generation system for enterprise customer communication.

## Operating Protocol

1. Hypothesize with explicit PASS criteria.
2. Score with deterministic checks first.
3. Plan before editing core system behavior.
4. Build with a skills-first approach.
5. Test changes with the cheapest reliable layer first.
6. Fix and re-run checks until stable.
7. Validate outputs on disk, not self-reports.
8. Document important findings in `HYPOTHESES.md` and `LEARNINGS.md`.

## Required Config Read

Before generating or editing newsletter outputs, read:
- `config/profile.yaml`

This file is the canonical personalization surface for curator voice, audience, links, and optional sections.

## Agents

| Agent | Purpose |
|---|---|
| `customer_newsletter` | End-to-end pipeline orchestration |
| `editorial-analyst` | Editorial intelligence mining |
| `skill-builder` | Skill authoring and refinement |

## Skills

Skills live in `.github/skills/<name>/SKILL.md`.
Current public count: 17.

## Core Principles

- Deletion discipline: replace old implementations directly.
- Skills-first architecture: keep domain logic in skills.
- Deterministic quality gates: validation and scoring scripts are first-class.
- Feed-forward learning: encode recurring failures into reusable rules.

## Build and Validation

Use these as default gates:

```bash
make validate-structure
make validate-all-skills
make test-validator
make score-all
```

For newsletter generation:

```bash
make newsletter START=YYYY-MM-DD END=YYYY-MM-DD
```

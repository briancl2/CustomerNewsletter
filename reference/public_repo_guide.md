# Public Repo Guide

## Purpose

This repository is a public template and reference implementation for building a Copilot-powered customer newsletter system.

It demonstrates how to move from manual curation and monolithic prompts to:
- skills-based orchestration
- deterministic quality gates
- iterative self-learning improvements

## Who This Is For

- Developer productivity leaders
- Platform engineering teams
- Technical account teams running recurring update communications
- Builders learning how to design multi-phase Copilot workflows

## Start Here

1. Read `README.md` for quick start.
2. Review `config/profile.yaml` and customize it.
3. Walk through `docs/how-it-works.md`.
4. Run validation gates:

```bash
make validate-structure
make validate-all-skills
make test-validator
make score-all
```

5. Run a generation pass:

```bash
make newsletter START=2026-01-01 END=2026-02-10
```

## Repo Navigation

| Path | Purpose |
|---|---|
| `.github/agents/` | Orchestrator and specialist agents |
| `.github/skills/` | Phase-by-phase workflows and references |
| `.github/prompts/` | Prompt artifacts for each pipeline phase |
| `tools/` | Validation, scoring, orchestration, utilities |
| `kb/` | Source registry and content taxonomy |
| `docs/` | How-to, architecture, and report content |
| `legacy/` | Preserved pre-overhaul prompt/chatmode artifacts |

## Notes on Copilot Usage

This system is Copilot-first but not Copilot-only:
- Copilot drives orchestration and content generation paths.
- Deterministic scripts handle structure checks, validation, and scoring.

## Maintainer Model

See `docs/how-we-maintain-this.md` for private-to-public sync expectations.

# CustomerNewsletter

A public, reusable system for generating enterprise-focused monthly Copilot newsletters.

## What You Get

- Multi-phase generation pipeline powered by agents and skills
- Deterministic validation and scoring gates
- Self-learning loop that turns corrections into persistent rules
- Sample outputs and legacy artifacts for comparison

## Why This Exists

The project demonstrates how to evolve from:
- manual curation and prompt sprawl

to:
- skills-first orchestration
- repeatable quality gates
- maintainable, auditable workflow design

## Start in 10 Minutes

1. Customize `config/profile.yaml`.
2. Run `make validate-structure` and `make validate-all-skills`.
3. Run `make newsletter START=2026-01-01 END=2026-02-10`.
4. Validate output with `make validate-newsletter FILE=output/2026-02_february_newsletter.md`.

## Release Artifacts

- February 2026 sample newsletter: `output/2026-02_february_newsletter.md`
- System report (verbatim): `reports/newsletter_system_report_2026-02.md`
- Legacy-to-modern mapping: `legacy/README.md`

## Screenshots Placeholder

Add screenshots here for:
- VS Code Agent Mode orchestration
- Pipeline artifacts in `workspace/`
- Final newsletter rendering

# Copilot Instructions

## Mission

Help users generate high-quality monthly enterprise newsletters using this repository's skills-first pipeline.

## Always Read First

- `AGENTS.md`
- `config/profile.yaml`
- `.github/agents/customer_newsletter.agent.md`

## Core Workflow

1. Validate structure and skills.
2. Run pipeline phases in order (1A, 1B, 1C, 2, 3, 4).
3. Validate newsletter output.
4. Apply polishing and editorial feedback when needed.

## Rules

- Keep domain logic in skills, not in ad-hoc prompt text.
- Prefer deterministic checks before subjective scoring.
- Do not invent links, dates, or release statuses.
- Maintain enterprise-focused tone and audience relevance.
- Respect `config/profile.yaml` as the personalization source of truth.

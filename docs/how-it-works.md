# How It Works

## Pipeline Phases

1. Phase 1A, URL manifest generation
2. Phase 1B, source content retrieval
3. Phase 1C, discovery consolidation
4. Phase 2, events extraction
5. Phase 3, content curation
6. Phase 4, newsletter assembly

## Phase Gates

Each phase writes explicit artifacts to disk and must pass existence/quality gates before the next phase.

Examples:
- `workspace/newsletter_phase1a_url_manifest_*.md`
- `workspace/newsletter_phase1a_discoveries_*.md`
- `workspace/newsletter_phase3_curated_sections_*.md`
- `output/YYYY-MM_month_newsletter.md`

## Self-Learning Loop

Corrections are encoded into skills and references, then validated by scoring and rule checks.

Loop:

```text
Finding -> Root cause -> Skill/rule update -> Regenerate -> Validate -> Record learning
```

## Trust Disk, Not Self-Reports

The system relies on file-based proof and deterministic checks rather than agent claims.

Core commands:

```bash
make validate-structure
make validate-all-skills
make score-all
make validate-newsletter FILE=output/2026-02_february_newsletter.md
```

# How It Works

This repo is a multi-phase pipeline that turns a date window into a newsletter draft,
with a paper trail in `workspace/` that shows what was collected and curated along the
way.

If you want to run it, start with:
- [Start here (Feb 2026)](launch/2026-02/start-here.md)

## Pipeline Phases

1. Phase 1A: URL manifest generation
2. Phase 1B: Source content retrieval
3. Phase 1C: Discovery consolidation
4. Phase 1.5: Curator notes (optional, if notes exist)
5. Phase 2: Events extraction
6. Phase 3: Content curation
7. Phase 4: Newsletter assembly
8. Phase 4.5: Polishing + validation

## Phase Gates

Each phase writes explicit artifacts to disk and must pass existence/quality gates
before the next phase.

Examples:
- `workspace/newsletter_phase1a_url_manifest_*.md`
- `workspace/newsletter_phase1b_interim_*_*.md`
- `workspace/newsletter_phase1a_discoveries_*.md`
- `workspace/newsletter_phase2_events_*.md`
- `workspace/newsletter_phase3_curated_sections_*.md`
- `output/YYYY-MM_month_newsletter.md`

## Self-Learning Loop

Corrections are encoded into skills and references, then validated by scoring and rule
checks.

Loop:

```text
Finding -> Root cause -> Skill/rule update -> Regenerate -> Validate -> Record learning
```

## Trust Disk, Not Self-Reports

The system relies on file-based proof and deterministic checks rather than agent claims.

# How It Works

This repo is a multi-phase pipeline that turns a date window into a newsletter draft,
with a paper trail in `workspace/` that shows what was collected and curated along the
way.

If you want to run it, start with:
- [Start here (Feb 2026)](launch/2026-02/start-here.md)
- [May 2026 cost optimization companion](https://github.com/briancl2/CustomerNewsletter/blob/main/release_bundle/2026-05_newsletter_cost_optimization/CUSTOMER_COMPANION.md)
- [May 2026 system release notes](https://github.com/briancl2/CustomerNewsletter/blob/main/release_bundle/2026-05_newsletter_cost_optimization/NEWSLETTER_SYSTEM_RELEASE_NOTES.md)

## Pipeline Phases

1. Phase 1A: URL manifest generation
2. Phase 1B: Source content retrieval
3. Phase 1C: Discovery consolidation
4. Phase 1.5: Curator notes (optional, if notes exist)
5. Phase 2: Events extraction
6. Phase 3: Content curation
7. Phase 4: Newsletter assembly
8. Phase 4.5: Polishing + deprecation consolidation + validation
9. Phase 4.6: Video matching (optional enrichment)
10. Phase 5: Editorial review (human corrections)

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

## Cost-Aware Run Pattern

The current production-like route starts with a clean cycle, runs the admitted prompt-rendered production command for its pinned range, and validates the output before any cost or quality claim is made.

```bash
bash tools/prepare_newsletter_cycle.sh 2026-02-14 2026-04-16 --no-reuse
make newsletter-gen START=2026-02-14 END=2026-04-16 MODE=production
make validate-newsletter FILE=output/YYYY-MM_month_newsletter.md
bash tools/validate_pipeline_strict.sh 2026-02-14 2026-04-16 --require-fresh --production-artifacts
```

`MODE=production` is pinned to the April 2026 range by the prompt renderer. For another date range, reuse the workflow pattern and validation gates, but first extend and validate the admitted prompt-rendered mode for that range.

The token-efficient path is about reducing repeated work, not just shortening prompts. The system now emphasizes accepted source sets, artifact reuse, compact Phase 3 curation inputs, readiness checks, and fallback to fuller context when quality is at risk.

Use `tools/run_newsletter_orchestrated.sh` for phase-local diagnosis when the prompt-rendered route needs repair. Treat it as diagnostic unless the release notes for a given run say otherwise.

## Self-Learning Loop

Corrections are encoded into skills and references, then validated by scoring and rule
checks.

Loop:

```text
Finding -> Root cause -> Skill/rule update -> Regenerate -> Validate -> Record learning
```

## Trust Disk, Not Self-Reports

The system relies on file-based proof and deterministic checks rather than agent claims.

For cost-related claims, the proof must also say what it does not prove. The May bundle labels workflow movement as aggregate/proxy evidence, not Copilot billing proof, durable savings, model superiority, or fleet readiness.

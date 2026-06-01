# Start Here

This bundle is the production kickoff surface for the April 2026 newsletter run.
Use the live operator paths in `make newsletter-gen` and
`make newsletter-proof-run`; keep `newsletter-orchestrated` for diagnostics
only.

## What it gives you

- A one-command Copilot CLI path for the April cycle
- The expected artifact and receipt trail
- The quality gates that must pass before treating the issue as ready

## Canonical production command

```bash
copilot --model gpt-5.5 --allow-all --deny-tool agent --no-ask-user --stream off \
  -p "$(bash tools/render_product_run_prompt.sh 2026-02-14 2026-04-16 production)"
```

Default window:

- `START=2026-02-14`
- `END=2026-04-16`

## Convenience wrapper

```bash
bash release_bundle/2026-04_newsletter_launch/run_april_production.sh
```

## Live operator paths

```bash
make newsletter-gen START=2026-02-14 END=2026-04-16 MODE=production
make newsletter-proof-run START=2026-02-14 END=2026-04-16 MODE=production
```

`tools/run_newsletter_orchestrated.sh` stays diagnostic-only.

## Dry-run / prompt render

```bash
bash tools/render_product_run_prompt.sh 2026-02-14 2026-04-16 production
```

## Expected outputs

- Final issue: `output/2026-04_april_newsletter.md`
- Receipts: `workspace/newsletter_phase_receipts_2026-04-16.json`
- Polishing report: `workspace/newsletter_phase4_5_polishing_2026-04-16.md`
- Video report: `workspace/newsletter_phase4_6_video_matches_2026-04-16.md`
- Editorial review: `workspace/2026-04_editorial_review.md`

## Required quality gates

```bash
bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh output/2026-04_april_newsletter.md
bash tools/validate_pipeline_strict.sh 2026-02-14 2026-04-16 --production-artifacts
bash tools/score-v2-rubric.sh --mode auto output/2026-04_april_newsletter.md
```

## Important note

Treat any run executed before `2026-04-16` as a pre-close edition. The current
fresh closed-window retained proof is
`runs/product_runs/20260417T024756Z_production_proof/`, produced from
newsletter `main` commit `99a0926f2ae74030a9392ab11d82731288b59f43` and
carried forward by the current repo-local authority surfaces on `main`.
It records aligned `GitHub Copilot CLI 1.0.31.` receipts, and the repaired
`audit/session-log-summary.md` now agrees with a direct parser read on the same
retained session log. The retained reconciliation ledger at
`runs/product_runs/20260416T235552Z_production_proof_session-log-tool-call-reconciliation.md`
remains historical repair evidence for the pre-repair proof bundle rather than
the current authority surface.
`runs/product_runs/20260416T235552Z_production_proof/`,
`runs/product_runs/20260416T210231Z_production_proof/`,
`runs/product_runs/20260416T204543Z_production_proof/`,
`runs/product_runs/20260416T200001Z_production_proof/`, and
`runs/product_runs/20260416T175225Z_production_proof/` remain earlier same-day
mainline proof evidence, and
`runs/product_runs/20260416T155723Z_production_proof/` remains precursor
evidence from the quick-sweep branch state. Re-run on or after `2026-04-16`
only if you materially change the live operator surfaces, the canonical
pipeline behavior, or the session-summary collector itself.

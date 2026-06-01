# Newsletter Generation System Release Notes

This note summarizes the customer-safe newsletter generation system changes included with the May 2026 public catch-up. It is about the reusable newsletter pipeline itself, not the May newsletter content.

## Measured Impact

The cost optimization work produced measurable aggregate/proxy movement in retained comparisons. These are not billing claims, but they are meaningful workflow measurements:

| Signal | Rounded public-safe metric | Quality status |
|---|---:|---|
| Integrated fixed-corpus comparison | About 27% lower aggregate token total | Quality gates passed. |
| Integrated current-cycle comparison | About 45% lower aggregate token total | Newsletter validation passed; corpus caveats apply. |
| Phase 3 compact working-set example | About 89% lower Phase 3 curation token load | Source coverage and curation checks passed. |
| Cheaper but blocked route | About 22% lower aggregate token total | Rejected because quality fell below threshold. |
| Repaired optimized route | V2 `48/50` and newsletter validation passed | Accepted as the safer route shape. |

The headline: the system got cheaper because it did less repeated work, not because it merely asked for shorter answers. The strongest levers were source/candidate discipline, compact synthesis inputs, accepted-artifact reuse, tool suppression when safe, and quality gates that rejected cheap but weak output.

## What Changed

### Safer Public Publishing

- Added an allowlist-and-prune publication flow so public snapshots copy only approved surfaces and remove stale target-only files before validation. See [publish_public_snapshot.sh](../../tools/publish_public_snapshot.sh), [public_snapshot_allowlist.txt](../../tools/public_snapshot_allowlist.txt), and [public_snapshot_prune.txt](../../tools/public_snapshot_prune.txt).
- Made the publisher pull-request safe by default. It now leaves changes uncommitted unless `--commit` is explicitly provided. This helps reviewers inspect the public diff before publishing.
- Added target safety checks so the publisher refuses to run against the source repo, refuses nested source/target layouts, validates relative allowlist and prune entries, and treats sensitive-scan errors as hard failures.
- Expanded sensitive-pattern scanning for local paths, private source links, private proof markers, stale release-bundle internals, and other non-public terms.

### Public Snapshot Boundary

- Removed raw public copies of private `planning/`, `workspace/`, `runs/`, internal February source notes, and stale output variants from the public snapshot boundary.
- Replaced broad `config/` publication with the public benchmark-mode config only: [feb2026_consistency.json](../../config/benchmark_modes/feb2026_consistency.json). Internal experiment policies, feature flags, fixture packs, and retained-run benchmark lanes stay private.
- Kept customer-safe release material selective: February public launch assets, April launch command notes, and May customer-facing cost guidance. See [February public launch](../2026-02_newsletter_launch/public/START_HERE.md), [April launch notes](../2026-04_newsletter_launch/START_HERE.md), and [May customer companion](CUSTOMER_COMPANION.md).

### Stronger Validation Gates

- Updated the all-suite test runner to distinguish required public-safe suites from private retained-fixture suites. When private-only fixtures are absent from the public snapshot, those suites are skipped with an explicit reason rather than failing the public build. See [test_all.sh](../../tools/test_all.sh).
- Added targeted validator coverage for May root-cause drift classes in [validate_newsletter.sh](../../.github/skills/newsletter-validation/scripts/validate_newsletter.sh) and its self-test harness [test_validator.sh](../../tools/test_validator.sh).
- Added or synced regression coverage for phase contracts, product prompt rendering, scope alignment, public newsletter validation, external critique fixtures, source-pruning receipts, output-shape receipts, and route-lock telemetry under [tools/](../../tools/) and [tests/](../../tests/).

### Cost Optimization Mechanisms

- Added source/candidate pruning and source bundle receipts so downstream phases can work from accepted source sets rather than rediscovering broad context. See [apply_newsletter_source_pruning_policy.py](../../tools/apply_newsletter_source_pruning_policy.py), [build_source_pruning_experiment_receipt.py](../../tools/build_source_pruning_experiment_receipt.py), and [build_source_pruning_amplification_receipt.py](../../tools/build_source_pruning_amplification_receipt.py).
- Added artifact reuse and no-refetch receipts so accepted intermediate artifacts can be consumed without repeated retrieval. See [build_artifact_reuse_admission_receipt.py](../../tools/build_artifact_reuse_admission_receipt.py), [build_artifact_reuse_no_refetch_receipt.py](../../tools/build_artifact_reuse_no_refetch_receipt.py), and [build_artifact_reuse_phase3_proof_receipt.py](../../tools/build_artifact_reuse_phase3_proof_receipt.py).
- Added compact working-set generation and Phase 3 readiness checks to reduce synthesis load while protecting source coverage. See [build_phase3_working_set.py](../../tools/build_phase3_working_set.py), [validate_phase3_curated.py](../../tools/validate_phase3_curated.py), and [validate_phase3_v2_readiness.py](../../tools/validate_phase3_v2_readiness.py).
- Added route telemetry and fail-closed proof helpers so token movement is tied to route identity and quality state. See [run_copilot_phase.py](../../tools/run_copilot_phase.py), [build_phase_token_telemetry_receipt.py](../../tools/build_phase_token_telemetry_receipt.py), and [test_phase_route_lock_telemetry.sh](../../tools/test_phase_route_lock_telemetry.sh).
- Kept failed output-shape work visible as a negative result. The tested shape reduced the wrong thing and amplified total route cost, so it stayed out of the accepted path. See [apply_newsletter_output_shape_policy.py](../../tools/apply_newsletter_output_shape_policy.py) and [build_output_shape_experiment_receipt.py](../../tools/build_output_shape_experiment_receipt.py).

### Pipeline And Operator Surfaces

- Added the `upgrade-advisor` agent for bounded workflow, harness, validation, and execution-surface recommendations. See [upgrade-advisor.agent.md](../../.github/agents/upgrade-advisor.agent.md).
- Updated the pipeline prompts and phase skills to reflect current phase boundaries, content curation requirements, event extraction rules, polishing rules, and validation checks. Start with [run_pipeline.prompt.md](../../.github/prompts/run_pipeline.prompt.md), [content-curation](../../.github/skills/content-curation/SKILL.md), [content-retrieval](../../.github/skills/content-retrieval/SKILL.md), [events-extraction](../../.github/skills/events-extraction/SKILL.md), [newsletter-polishing](../../.github/skills/newsletter-polishing/SKILL.md), and [newsletter-validation](../../.github/skills/newsletter-validation/SKILL.md).
- Added live production and retained proof-run helpers for prompt-rendered newsletter runs. See [render_product_run_prompt.sh](../../tools/render_product_run_prompt.sh), [run_product_newsletter.sh](../../tools/run_product_newsletter.sh), and the Makefile targets in [Makefile](../../Makefile).
- Added current source-intelligence guidance for the GitHub Copilot app and Copilot CLI. See [copilot-app.md](../../reference/source-intelligence/copilot-app.md) and [copilot-cli.md](../../reference/source-intelligence/copilot-cli.md).

### Published Outputs

- Added the April 2026 generated newsletter alongside the existing February and May outputs. See [2026-04_april_newsletter.md](../../output/2026-04_april_newsletter.md).
- Refreshed the May newsletter body and May public cost companion links so customer-facing cost guidance points to public-safe material. See [2026-05_may_newsletter.md](../../output/2026-05_may_newsletter.md) and [CUSTOMER_COMPANION.md](CUSTOMER_COMPANION.md).

## Validation Summary

- Public sensitive-pattern scan: pass.
- Public `make test-all`: required public suites pass; private retained-fixture suites skip when private fixtures are absent.
- April newsletter validation: pass, 0 warnings.
- May newsletter validation: pass, 0 warnings.
- Private full-suite validation before public sync: required suites pass, with only the expected private workspace fixture skip.

## Publication Boundary

This release note intentionally excludes private run logs, private planning bursts, raw internal evidence, local machine paths, retained-run benchmark artifacts, and non-public source notes. Those materials remain in the private source repo and are represented here only as public-safe workflow descriptions.
# Newsletter Generation System Release Notes

> **Bottom line:** I re-engineered this newsletter's generation system to do less repeated AI work; the accepted route cut aggregate token totals by roughly 27-45% per run -- about $6-12 per run in illustrative API-equivalent terms -- while quality gates stayed in force. This note also doubles as the standard release readout of every system and repository change since the February 2026 release; see [Changes Since the February 2026 Release](#changes-since-the-february-2026-release). **For:** developers and Admin & FinOps owners who want the technical map and the before/after evidence. **Read time:** about 15 minutes.

This note summarizes the newsletter generation system changes included with the May 2026 update. It is about the reusable newsletter pipeline itself, not the May newsletter content. The cost-optimization work is the headline; the [Changes Since the February 2026 Release](#changes-since-the-february-2026-release) section is the full, grouped readout of everything else that changed in the same window.

Use this file when you want the technical map: what changed, where it changed, what each change does, what it cost, and how to operate the updated system. For developer/admin cost guidance, start with [CUSTOMER_COMPANION.md](CUSTOMER_COMPANION.md). For product-source inventory, use [PRODUCT_FEATURE_QUICK_HITS.md](PRODUCT_FEATURE_QUICK_HITS.md).

## Measured Impact

The cost optimization work I ran produced measurable aggregate/proxy movement in retained comparison runs. These are workflow-engineering measurements of direct provider token totals, not GitHub Copilot billing claims.

| Comparison run | Before (tokens) | After (tokens) | Change | Quality status |
|---|---:|---:|---:|---|
| Integrated fixed-corpus | 7,846,260 | 5,699,291 | about -27% | Quality gates passed. |
| Integrated current-cycle | 9,001,070 | 4,957,442 | about -45% | Newsletter validation passed; corpus caveats apply. |
| Phase 3 compact working-set example | 284,862 | 31,333 | about -89% | Source coverage and curation checks passed. |
| Cheaper but blocked route | 5,785,064 | 4,501,184 | about -22% | Rejected: quality fell below threshold (V2 `39/50`). |
| Repaired optimized route | — | 4,388,338 | — | Accepted: V2 `48/50`, newsletter validation passed. |

On the integrated runs, requests and tool calls dropped alongside tokens: the fixed-corpus run moved from `126` to `102` requests and `212` to `184` tool calls; the current-cycle run moved from `125` to `93` requests and `267` to `149` tool calls. The system got cheaper because I made it do less repeated work, not because it merely asked for shorter answers -- that was the central lesson I took from the May cycle.

These totals count direct provider tokens across the full route. They are engineering evidence under bounded workflow conditions; they are not a durable percentage, a universal benchmark, or a Copilot AI Credits invoice.

## Illustrative Cost Translation

These token movements can be translated into an illustrative dollar figure so the "bottom line" is concrete. The translation is engineering math on direct provider tokens, **not** a GitHub Copilot AI Credits bill.

The system's own matched-pair experiments recorded both token deltas and the corresponding API-equivalent cost deltas (see the output-shape negative result below). Two of those matched pairs imply a blended rate of about **$3 per million direct provider tokens** (`+2,091,727` tokens for `+$6.18`; `+2,295,172` tokens for `+$7.05`). That blended rate is consistent with current frontier list pricing such as a `gpt-5.5`-class model; substitute your own current rate from the [OpenAI pricing](https://developers.openai.com/api/docs/pricing) page for your own estimates.

Applying that illustrative `~$3 / million-token` rate:

| Comparison run | Tokens saved | Illustrative API-equivalent saving per run |
|---|---:|---:|
| Integrated current-cycle | about 4,043,000 | about **$12** |
| Integrated fixed-corpus | about 2,147,000 | about **$6** |
| Phase 3 compact working-set example | about 253,000 | under **$1** |

Read this as: with a `gpt-5.5`-class blended rate, the workflow changes removed roughly `$12` of API-equivalent token cost from a full current-cycle newsletter run. The number is illustrative and route-specific. It is not a billing-savings claim, it does not include tool/runtime/validation side costs, and it does not transfer to other workflows or to GitHub Copilot AI Credit pricing, which uses its own model-specific conversion.

## What The Strongest Levers Were

The strongest levers were source/candidate discipline, compact synthesis inputs, accepted-artifact reuse, tool suppression when safe, and quality gates that rejected cheap but weak output. Each lever, its before/after evidence, and the file that implements it are mapped in [How The Cost Mechanisms Fit Together](#how-the-cost-mechanisms-fit-together) below.

## What Changed

### Operator Entry Points

| Task | Command or file | Use it when |
|---|---|---|
| Run a production-like newsletter generation | `make newsletter-gen START=2026-02-14 END=2026-04-16 MODE=production` | You want the admitted prompt-rendered production oracle. |
| Retain proof artifacts for a production run | `make newsletter-proof-run START=2026-02-14 END=2026-04-16 MODE=production` | You need retained evidence for the admitted April range in the source repo. |
| Prepare a clean cycle | [prepare_newsletter_cycle.sh](../../tools/prepare_newsletter_cycle.sh) | You need to clear stale intermediates before a run. |
| Render the exact product prompt | [render_product_run_prompt.sh](../../tools/render_product_run_prompt.sh) | You want to inspect or run the prompt outside Make. |
| Diagnose phase-local behavior | [run_newsletter_orchestrated.sh](../../tools/run_newsletter_orchestrated.sh) | The prompt-rendered route failed and needs phase-local repair. |
| Validate newsletter content | [validate_newsletter.sh](../../.github/skills/newsletter-validation/scripts/validate_newsletter.sh) | You need deterministic newsletter checks. |
| Validate retained artifacts | [validate_pipeline_strict.sh](../../tools/validate_pipeline_strict.sh) | You need source, scope, freshness, and production-artifact gates. |
| Score editorial quality | [score-v2-rubric.sh](../../tools/score-v2-rubric.sh) | You need rubric-level quality evidence. |

Production-like path (the prompt renderer pins `production` to its admitted range):

```bash
bash tools/prepare_newsletter_cycle.sh <START> <END> --no-reuse
make newsletter-gen START=<START> END=<END> MODE=production
make validate-newsletter FILE=output/YYYY-MM_month_newsletter.md
bash tools/validate_pipeline_strict.sh <START> <END> --require-fresh --production-artifacts
```

The prompt renderer currently pins `production` mode to `2026-02-14` through
`2026-04-16` and `benchmark` mode to `2025-12-05` through `2026-02-13`. Substitute
the pinned `<START>`/`<END>` and the matching `output/YYYY-MM_month_newsletter.md`
for the mode you run. For other date ranges, treat the commands above as the
workflow pattern, then extend and validate the admitted prompt-rendered mode
before using `MODE=production`.

Diagnostic path:

```bash
bash tools/run_newsletter_orchestrated.sh START_DATE END_DATE
bash tools/score-v2-rubric.sh output/YYYY-MM_month_newsletter.md
```

The diagnostic path is for localizing failures and measuring candidate route changes. It is not the default production authority.

### Safer Publication

- Added an allowlist-and-prune publication flow so a published snapshot copies only approved surfaces and removes stale target-only files before validation.
- Made the publication step pull-request safe by default. It now leaves changes uncommitted unless `--commit` is explicitly provided, so reviewers can inspect the diff before publishing.
- Added safety checks so publication refuses unsafe target layouts, validates relative allowlist and prune entries, and treats sensitive-scan errors as hard failures.
- Expanded sensitive-pattern scanning for local paths, restricted source links, proof markers, stale release-bundle internals, and other non-shippable terms.

### Published Surface Boundary

- Excluded raw copies of `planning/`, `workspace/`, `runs/`, February source notes, and stale output variants from the published surface.
- Replaced broad `config/` publication with the public benchmark-mode config only: [feb2026_consistency.json](../../config/benchmark_modes/feb2026_consistency.json). Experiment policies, feature flags, fixture packs, and retained-run benchmark lanes stay out of the published bundle.
- Kept release material selective: February public launch assets and May customer-facing cost guidance. See [February public launch](../2026-02_newsletter_launch/public/START_HERE.md) and [May customer companion](CUSTOMER_COMPANION.md).

### Stronger Validation Gates

- Updated the all-suite test runner to distinguish required suites from retained-fixture suites. When retained fixtures are absent, those suites are skipped with an explicit reason rather than failing the build. See [test_all.sh](../../tools/test_all.sh).
- Added targeted validator coverage for May root-cause drift classes in [validate_newsletter.sh](../../.github/skills/newsletter-validation/scripts/validate_newsletter.sh) and its self-test harness [test_validator.sh](../../tools/test_validator.sh).
- Added or synced regression coverage for phase contracts, product prompt rendering, scope alignment, public newsletter validation, external critique fixtures, source-pruning receipts, output-shape receipts, and route-lock telemetry under [tools/](../../tools/) and [tests/](../../tests/).

### Cost Optimization Mechanisms

- Added source/candidate pruning and source bundle receipts so downstream phases can work from accepted source sets rather than rediscovering broad context. See [apply_newsletter_source_pruning_policy.py](../../tools/apply_newsletter_source_pruning_policy.py), [build_source_pruning_experiment_receipt.py](../../tools/build_source_pruning_experiment_receipt.py), and [build_source_pruning_amplification_receipt.py](../../tools/build_source_pruning_amplification_receipt.py).
- Added artifact reuse and no-refetch receipts so accepted intermediate artifacts can be consumed without repeated retrieval. See [build_artifact_reuse_admission_receipt.py](../../tools/build_artifact_reuse_admission_receipt.py), [build_artifact_reuse_no_refetch_receipt.py](../../tools/build_artifact_reuse_no_refetch_receipt.py), and [build_artifact_reuse_phase3_proof_receipt.py](../../tools/build_artifact_reuse_phase3_proof_receipt.py).
- Added compact working-set generation and Phase 3 readiness checks to reduce synthesis load while protecting source coverage. See [build_phase3_working_set.py](../../tools/build_phase3_working_set.py), [validate_phase3_curated.py](../../tools/validate_phase3_curated.py), and [validate_phase3_v2_readiness.py](../../tools/validate_phase3_v2_readiness.py).
- Added route telemetry and fail-closed proof helpers so token movement is tied to route identity and quality state. See [run_copilot_phase.py](../../tools/run_copilot_phase.py), [build_phase_token_telemetry_receipt.py](../../tools/build_phase_token_telemetry_receipt.py), and [test_phase_route_lock_telemetry.sh](../../tools/test_phase_route_lock_telemetry.sh).
- Kept failed output-shape work visible as a negative result. The tested shape reduced the wrong thing and amplified total route cost, so it stayed out of the accepted path. Across three matched pairs it increased total direct provider tokens by `2,091,727`, `2,295,172`, and `166,553`, which mapped to API-equivalent cost increases of `+$6.18`, `+$7.05`, and `+$1.09`. See [apply_newsletter_output_shape_policy.py](../../tools/apply_newsletter_output_shape_policy.py) and [build_output_shape_experiment_receipt.py](../../tools/build_output_shape_experiment_receipt.py).

### How The Cost Mechanisms Fit Together

The accepted route is not one trick. It is a set of controls that reduce repeated work while keeping fallback and validation intact.

| Lever | Where it changed | What it does | How to use it safely |
|---|---|---|---|
| Source/candidate pruning | [apply_newsletter_source_pruning_policy.py](../../tools/apply_newsletter_source_pruning_policy.py), source-pruning receipts | Narrows downstream material to accepted source sets. | Preserve source floors and measure search/request compensation. |
| Artifact reuse | [build_artifact_reuse_admission_receipt.py](../../tools/build_artifact_reuse_admission_receipt.py), [build_artifact_reuse_no_refetch_receipt.py](../../tools/build_artifact_reuse_no_refetch_receipt.py) | Lets later phases consume accepted artifacts instead of re-fetching. | Bind identity, freshness, scope, and validation before reuse. |
| Compact Phase 3 working set | [build_phase3_working_set.py](../../tools/build_phase3_working_set.py), [validate_phase3_curated.py](../../tools/validate_phase3_curated.py) | Reduces expensive curation context while preserving required coverage. One Phase 3 example moved `284,862 -> 31,333` tokens (about -89%). | Keep required source classes and fallback to fuller context. |
| Tool-suppressed Phase 3 route | [run_phase3_stdout_no_tools_artifact_reuse.py](../../tools/run_phase3_stdout_no_tools_artifact_reuse.py), [validate_phase3_v2_readiness.py](../../tools/validate_phase3_v2_readiness.py) | Prevents tool-heavy reconstruction when accepted artifacts are ready. | Run readiness checks first; fail closed to fallback. |
| Route telemetry | [run_copilot_phase.py](../../tools/run_copilot_phase.py), [build_phase_token_telemetry_receipt.py](../../tools/build_phase_token_telemetry_receipt.py) | Connects route identity, prompts, token signals, and quality state. | Treat aggregate/proxy data as engineering evidence, not billing proof. |
| Negative evidence | [apply_newsletter_output_shape_policy.py](../../tools/apply_newsletter_output_shape_policy.py), [build_output_shape_experiment_receipt.py](../../tools/build_output_shape_experiment_receipt.py) | Keeps tempting failed strategies from being repeated. The output-shape shape added up to `+2,295,172` tokens (`+$7.05`) instead of saving. | Promote only route-level wins that pass quality gates. |

The integrated `-27%` and `-45%` movements are route-level results from the full stack working together. Isolated single-lever movement was often small, so the bundle attributes whole-route gains to the route, not to any one trick. The Phase 3 compact example is the clearest single-lever signal.

### Generating A Newsletter With Lower Token Pressure

1. Start from the prompt-rendered route, not the diagnostic harness.
2. Prepare the cycle cleanly so stale intermediates do not drive extra repair work.
3. Keep Phase 1 source identity and Phase 3 curation coverage explicit.
4. Reuse accepted artifacts instead of asking later phases to search again.
5. Use compact working sets only where source coverage and fallback are available.
6. Validate before claiming movement: newsletter validation, strict pipeline validation, and editorial scoring.
7. If a route gets cheaper but quality falls, repair the route or reject it while keeping the quality bar unchanged.

### Applying The Pattern Elsewhere

For another agentic workflow, copy the pattern rather than the numbers:

- Separate research, synthesis, implementation, and validation phases.
- Make each phase write artifacts to disk so later phases can reuse accepted work.
- Add artifact identity, freshness, and source-scope checks before reuse.
- Define mandatory context floors before compacting prompts or working sets.
- Restrict tools when reuse is the goal, but keep fallback when readiness fails.
- Track route-level movement, including retries, repairs, validations, and failed attempts.
- Publish negative results as guardrails so teams do not repeat locally cheap but globally expensive strategies.

### Pipeline And Operator Surfaces

- Added the `upgrade-advisor` agent for bounded workflow, harness, validation, and execution-surface recommendations. See [upgrade-advisor.agent.md](../../.github/agents/upgrade-advisor.agent.md).
- Updated the pipeline prompts and phase skills to reflect current phase boundaries, content curation requirements, event extraction rules, polishing rules, and validation checks. Start with [run_pipeline.prompt.md](../../.github/prompts/run_pipeline.prompt.md), [content-curation](../../.github/skills/content-curation/SKILL.md), [content-retrieval](../../.github/skills/content-retrieval/SKILL.md), [events-extraction](../../.github/skills/events-extraction/SKILL.md), [newsletter-polishing](../../.github/skills/newsletter-polishing/SKILL.md), and [newsletter-validation](../../.github/skills/newsletter-validation/SKILL.md).
- Added live production and retained proof-run helpers for prompt-rendered newsletter runs. See [render_product_run_prompt.sh](../../tools/render_product_run_prompt.sh), [run_product_newsletter.sh](../../tools/run_product_newsletter.sh), and the Makefile targets in [Makefile](../../Makefile).
- Added current source-intelligence guidance for the GitHub Copilot app and Copilot CLI. See [copilot-app.md](../../reference/source-intelligence/copilot-app.md) and [copilot-cli.md](../../reference/source-intelligence/copilot-cli.md).

### Broader System Changes Beyond Cost Optimization

- The publication boundary is now a first-class release surface. Allowlists, prune lists, and sensitive scans define what is included in the published repository.
- The newsletter validator now carries more product-specific drift checks, so published output quality does not depend only on human review.
- The source-intelligence layer was refreshed for Copilot CLI and Copilot app surfaces so future newsletters can reason over current product areas.
- The `upgrade-advisor` agent makes system-improvement recommendations bounded by workflow, harness, validation, and execution-surface evidence.
- Tests now distinguish required suites from retained-fixture suites, which keeps the published repository runnable without retained run logs.
- The release bundle itself now acts as a handoff artifact: it pairs user guidance, technical change mapping, source inventory, validation evidence, and claim boundaries.

### Published Outputs

- Refreshed the May newsletter body and May cost companion links so customer-facing cost guidance points to the published companion material. See [2026-05_may_newsletter.md](../../output/2026-05_may_newsletter.md) and [CUSTOMER_COMPANION.md](CUSTOMER_COMPANION.md).

## Changes Since the February 2026 Release

This section is the standard release readout for the whole system: everything that
changed between the February 2026 newsletter release and this May/June publication,
grouped by area. The cost-optimization work above is the headline of this window;
the items below place it alongside the other system, tooling, and repository
changes from the same period. Where a change is detailed earlier in this note, the
entry links to that subsection instead of repeating it.

### Current System At A Glance

This is the state the changes below add up to, so a reader can anchor the deltas
against the current system:

- **Pipeline:** six core phases (1A URL manifest, 1B retrieval, 1C consolidation,
  2 events, 3 curation, 4 assembly) plus optional phase 4.5 (polishing and
  deprecation consolidation), 4.6 (video matching), and 5 (editorial review). See
  [run_pipeline.prompt.md](../../.github/prompts/run_pipeline.prompt.md).
- **Skills:** 18 pipeline and operations skills under
  [.github/skills/](../../.github/skills/).
- **Agents:** 4 agents (`customer_newsletter`, `editorial-analyst`,
  `skill-builder`, `upgrade-advisor`) under
  [.github/agents/](../../.github/agents/).
- **Docs site:** a source-owned MkDocs site under [docs/](../../docs/) describing
  how the system works and its architecture.

### March-April: Benchmark Recovery And Phase Repair

- Added benchmark-recovery surfaces and bounded two phases that had been
  over-running their scope: phase 0/1 scope-contract generation and phase 3
  curation working-set construction now stay within explicit bounds, which set up
  the May cost-optimization route.
- Added strict closure and contract-replay test coverage so a production-like run
  proves its phase contracts and retained artifacts rather than trusting
  self-reports.
- Produced and validated an April production cycle as an internal benchmark. It
  was used to harden the pipeline and was not published as an official monthly
  newsletter.

### May: Cost Optimization, Publishing, And Operator Surfaces

- **Cost-optimization route.** The integrated source-pruning, compact working-set,
  artifact-reuse, tool-suppression, and route-telemetry stack landed this cycle and
  is the headline of this note. See [Cost Optimization
  Mechanisms](#cost-optimization-mechanisms) and [How The Cost Mechanisms Fit
  Together](#how-the-cost-mechanisms-fit-together).
- **Safer publication.** The allowlist-and-prune publication flow,
  pull-request-safe defaults, target safety checks, and expanded sensitive
  scanning. See [Safer Publication](#safer-publication) and [Published
  Surface Boundary](#published-surface-boundary).
- **Stronger validation gates.** Required-vs-retained suite separation, May
  drift-class validator coverage, and synced regression suites. See [Stronger
  Validation Gates](#stronger-validation-gates).
- **Operator surfaces.** The `upgrade-advisor` agent, refreshed pipeline prompts and
  phase skills, prompt-rendered production and proof-run helpers, and refreshed
  Copilot app and CLI source intelligence. See [Pipeline And Operator
  Surfaces](#pipeline-and-operator-surfaces).

### June: Finalization And Documentation

- **Source-owned documentation site.** The MkDocs site (`docs/` + `mkdocs.yml`) is
  now maintained alongside the pipeline and propagated on publish, with
  `how-it-works` and the architecture diagram covering the optional phases. See
  [docs/how-it-works.md](../../docs/how-it-works.md) and
  [docs/architecture.md](../../docs/architecture.md).
- **Full-pipeline framing in the entry docs.** `README.md` and `AGENTS.md` now
  describe the complete pipeline including the optional 4.5/4.6/5 stages and the
  full skill and agent inventory.
- **Hardened repository hygiene checks.** The sensitive-pattern scan now also
  covers hidden directories (so dotfile surfaces are no longer skipped), with the
  scan split so a small set of legitimate domains is exempted narrowly rather than
  excluding whole files. Local absolute paths in a research prompt were sanitized
  in the same pass.
- **May newsletter content refresh.** The shipped May newsletter's Microsoft Build
  session guide was updated to current sessions, and broken cross-links and pinned
  command examples in this bundle were genericized. See
  [2026-05_may_newsletter.md](../../output/2026-05_may_newsletter.md).

### Knowledge Base And Source Intelligence

- Refreshed the source-intelligence layer for the GitHub Copilot app and Copilot
  CLI so future newsletters reason over current product areas. See
  [copilot-app.md](../../reference/source-intelligence/copilot-app.md) and
  [copilot-cli.md](../../reference/source-intelligence/copilot-cli.md).
- Maintained the canonical source knowledge base and its change log. See
  [kb/CHANGELOG.md](../../kb/CHANGELOG.md).

## Validation Summary

- Sensitive-pattern scan: pass.
- `make test-all`: required suites pass; retained-fixture suites skip when their fixtures are absent.
- May newsletter validation: pass, 0 warnings.
- Full-suite validation before publication: required suites pass, with only the expected retained workspace fixture skip.

Recommended validation when adapting this release:

```bash
git diff --check
make test-all
make validate-newsletter FILE=output/YYYY-MM_month_newsletter.md
bash tools/validate_pipeline_strict.sh START_DATE END_DATE --require-fresh --production-artifacts
bash tools/score-v2-rubric.sh output/YYYY-MM_month_newsletter.md
```

## Publication Boundary

This release note describes the published newsletter generation system. Detailed run logs, planning bursts, raw evidence, local machine paths, and retained benchmark artifacts are out of scope and are represented here only as workflow descriptions.
# Customer Companion: Cost-Aware Copilot Usage

> **Bottom line:** Re-engineering this newsletter's own AI workflow cut **roughly 27-45% of the direct provider tokens per run (about $6-12 per run in API-equivalent terms)** while quality gates held. The same moves -- route over prompt, compact context, artifact reuse, quality-gated fallback -- paired with usage-based billing controls are how you hold agentic Copilot costs down.

This is the companion to the May 2026 newsletter. It summarizes practical usage-based billing (UBB), Copilot governance, and cost-aware workflow guidance without exposing experiment logs or stronger claims than the evidence supports.

Use this file when you want the operating guidance. Use [NEWSLETTER_SYSTEM_RELEASE_NOTES.md](NEWSLETTER_SYSTEM_RELEASE_NOTES.md) when you want the implementation map of what changed in the newsletter generation system, including exact before/after token counts and an illustrative cost translation.

## From Brian

For May's newsletter, I set out to learn how to optimize my generation workflow to understand what works and what doesn't for cost reduction. I asked Copilot to do most of the heavy lifting, setting up experiments, measuring what works and what doesn't, and then baking in the proven learnings into the newsletter generation process. The most humbling finding is that the cheapest or shortest prompt is rarely the cheapest workflow. Most of the savings came from making the system stop repeating work, not from asking for shorter responses. If you are a developer or otherwise responsible for AI costs, that is the lever I would reach for first -- Brian

## START HERE

This is the canonical landing page for the bundle. The shipped May newsletter intentionally links to `CUSTOMER_COMPANION.md`. [START_HERE.md](START_HERE.md) is a thin pointer back to this file for readers browsing the release bundle directory.

| Time | Path | Use when |
|---|---|---|
| 3 minutes | [Executive Summary](#executive-summary) below | You need the core message and the takeaways. |
| 10 minutes | Keep reading this companion | You want the practical UBB, developer workflow, governance, and source-link guidance in one place. |
| Implementation planning | [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md), [ADMIN_FINOPS_GUIDE.md](ADMIN_FINOPS_GUIDE.md) | You are turning the guidance into team operating practices. |
| Technical deep dive | [NEWSLETTER_SYSTEM_RELEASE_NOTES.md](NEWSLETTER_SYSTEM_RELEASE_NOTES.md), [PRODUCT_FEATURE_QUICK_HITS.md](PRODUCT_FEATURE_QUICK_HITS.md), [PUBLIC_SOURCES.md](PUBLIC_SOURCES.md) | You want implementation details, exact numbers, product controls, and public sources. |

| Role | Recommended path |
|---|---|
| Developer or team lead | [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) -> [NEWSLETTER_SYSTEM_RELEASE_NOTES.md](NEWSLETTER_SYSTEM_RELEASE_NOTES.md) |
| Admin & FinOps owner | [ADMIN_FINOPS_GUIDE.md](ADMIN_FINOPS_GUIDE.md) -> [Measurement Checklist](#measurement-checklist) -> [PRODUCT_FEATURE_QUICK_HITS.md](PRODUCT_FEATURE_QUICK_HITS.md) |

If you just need the core message and the takeaways in three minutes, read the [Executive Summary](#executive-summary) below; if you are presenting the cost story, the [NEWSLETTER_MAY_COST_SECTION.md](NEWSLETTER_MAY_COST_SECTION.md) excerpt is the verbatim newsletter section.

This bundle provides workflow guidance, public-source references, and practical lessons from the newsletter generation system. It is not billing proof, a durable savings claim, a model recommendation, or a universal benchmark.

## Executive Summary

> **Expected savings, concretely.** In my own newsletter runs, the accepted optimized route moved a full current-cycle generation from about 9.0M to about 5.0M direct provider tokens (~45% fewer), and a fixed-corpus run from about 7.8M to about 5.7M (~27% fewer). At a blended illustrative rate of about $3 per million direct provider tokens (a `gpt-5.5`-class list price -- substitute your own from the [OpenAI pricing](https://developers.openai.com/api/docs/pricing) page), that is roughly **$12 per current-cycle run** and **$6 per fixed-corpus run** of API-equivalent token cost removed. These are illustrative engineering estimates on direct provider tokens, **not** a GitHub Copilot AI Credits bill. For the full before/after tables and the cost math, see [NEWSLETTER_SYSTEM_RELEASE_NOTES.md](NEWSLETTER_SYSTEM_RELEASE_NOTES.md).

- **UBB starts June 1 for affected customers.** Metered Copilot interactions use GitHub AI Credits where applicable.
- **Developer clarification:** code completions and Next Edit Suggestions are not billed in AI Credits for paid Copilot plans. Developers should use GitHub's model and pricing documentation to understand which interactions can consume AI Credits.
- **Code review clarification:** Copilot code review should be tracked separately because it can consume AI Credits and GitHub Actions minutes.
- **Routing clarification:** Auto model selection can help route work by task and model health, but it should be treated as workflow guidance, not billing proof.
- **Budgets and behavior must be paired.** ULBs, cost-center budgets, enterprise limits, alerts, and usage exports work best when developers also get workflow guidance.
- **The useful optimization target is finished work.** Measure the route to a correct, reviewed, tested result, not only one prompt or one phase.
- **A real workflow moved materially.** When I applied phase-specific routing, compact working sets, artifact reuse, and quality-gated fallback to my own newsletter system, rounded aggregate/proxy comparisons showed roughly **27-45% less token mass** per run. Treat that as a workflow-specific engineering signal, not billing proof or a transferable savings percentage.

## Mental Model

Copilot bills metered usage in GitHub AI Credits, based on the model used and the number of tokens each interaction consumes. GitHub's [Copilot billing docs](https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing) are the authoritative source for what is charged. Provider API pricing pages are background only: useful for understanding token economics, but they are not your Copilot bill.

Useful finished-work cost is closer to this shape:

```text
finished-work cost =
	model and feature pricing
	x input + cached input + output token behavior
	x attempts and retries
	+ tool, search, review, runtime, and validation side costs
	+ repair work when quality fails
```

The practical target is not the shortest prompt. It is the route that reaches a correct, reviewed, tested result with the fewest failed attempts, unnecessary tool calls, repeated context assembly, and repairs.

## What Changed In The Workflow

The cost story behind this newsletter is concrete: I changed the generation system to do less repeated AI work while keeping validation in the loop. For the exact before/after token counts and the cost translation, see [NEWSLETTER_SYSTEM_RELEASE_NOTES.md](NEWSLETTER_SYSTEM_RELEASE_NOTES.md); for the developer patterns behind each change, see [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md).

| Change | Takeaway | Metric signal |
|---|---|---:|
| Phase-specific routing | Different phases deserve different model/reasoning choices; test the route, not the model in isolation. | Integrated comparisons showed roughly 27-45% lower aggregate/proxy token mass. |
| Compact working set | Smaller context can help when required source classes and fallback are preserved. | One Phase 3 example reduced the curation token load by roughly nine-tenths. |
| Artifact reuse / no-refetch | Reuse accepted artifacts instead of re-fetching, but bind identity, freshness, and scope first. | Helped reduce repeated retrieval and synthesis work inside the accepted route. |
| stdout/no-tools route | Suppress unnecessary tools only after readiness checks pass; keep fallback available. | Repaired route passed V2 quality and newsletter validation. |
| Failed output-shape policy | Shorter output instructions can increase total route cost by causing compensation elsewhere. | Negative result; not promoted. |

The point is not that these exact percentages transfer to another team. The point I took away is that finished-workflow measurement can reveal where agentic work is being repeated, amplified, or repaired.

## Developer Workflow Guide

### Generate A Newsletter With Fewer Wasted Tokens

Use the admitted prompt-rendered production route as the source of truth for its pinned range, then use phase-level tools only when diagnosis is needed.

```bash
# Prepare a clean cycle so old intermediates do not pollute the route.
bash tools/prepare_newsletter_cycle.sh <START> <END> --no-reuse

# Run the canonical prompt-rendered production path for its pinned range.
make newsletter-gen START=<START> END=<END> MODE=production

# Validate the generated issue and retained artifacts.
make validate-newsletter FILE=output/YYYY-MM_month_newsletter.md
bash tools/validate_pipeline_strict.sh <START> <END> --require-fresh --production-artifacts
```

`MODE=production` is pinned by the prompt renderer. Substitute its pinned
`<START>`/`<END>` and the matching `output/YYYY-MM_month_newsletter.md`. For
another month, copy the workflow shape and validation discipline, but first add
or admit the new date range instead of assuming the production mode accepts
arbitrary dates.

Use these rules while running or adapting the pipeline:

1. Define the date range, audience, scope, and acceptance criteria before generation.
2. Let Phase 1A/1B bind source identity before later phases synthesize.
3. Reuse accepted artifacts only when freshness, identity, and scope are clear.
4. Compact Phase 3 curation inputs only after required source classes are preserved.
5. Keep validation inside the cost gate. A cheaper invalid newsletter is not cheaper.
6. Use `make validate-newsletter`, strict validation, and scoring before promoting a route change.
7. Treat `tools/run_newsletter_orchestrated.sh` as diagnostic unless the prompt-rendered route needs phase-local repair.

### Optimize A Similar Workflow

The same pattern applies to other agentic workflows:

1. **Map the route.** Identify phases, inputs, outputs, tools, validations, and stop conditions.
2. **Find repeated work.** Look for repeated source discovery, re-reading, broad search, and repeated synthesis.
3. **Bind artifacts.** Save accepted source sets, prompt hashes, generated artifacts, validation receipts, and freshness checks.
4. **Compact only after preserving floors.** Define mandatory source classes, API contracts, security constraints, or test coverage before shrinking context.
5. **Constrain tools when reuse is the goal.** If the agent can browse freely, it may reconstruct work that already passed.
6. **Route by task, not habit.** Test model and reasoning choices phase-by-phase against output quality.
7. **Measure finished work.** Include requests, retries, repairs, tool calls, validation, and final acceptance.
8. **Keep a fallback.** Optimized routes should fail closed to fuller context or human review when readiness checks fail.

## Decision Tree

```text
Is the agent failing, retrying, or producing weak output?
	-> Tighten acceptance criteria, tests, validation, and task boundaries first.

Is the agent exploring too much code or too many sources?
	-> Provide exact files, source bundles, logs, and known constraints.
	-> Use read-only research before implementation.

Is context large or stale?
	-> Split research, plan, implementation, and validation.
	-> Carry forward only the plan, source list, constraints, and commands.

Is spend concentrated in a few people, teams, or surfaces?
	-> Review usage exports, team metrics, CLI activity, and code review separately.
	-> Use model guidance and budget overrides before blanket restrictions.

Are developers blocked by budgets?
	-> Diagnose user-level, cost-center, and enterprise budget layers.
	-> Keep validation in place while owners decide whether the fix is an override, budget change, or workflow guidance.

Is the same context reused frequently?
	-> Stabilize instructions, prompt prefixes, source bundles, and tool schemas.
	-> Track cache or reuse indicators when available, without treating them as billing proof.
```

## Scenario Guidance

| Scenario | Recommended pattern | Model posture | Cost control |
|---|---|---|---|
| Small refactor or doc update | Provide exact files and expected diff shape. | Lightweight or mid-tier. | Avoid broad search; set a stopping condition. |
| Codebase exploration | Ask for read-only mapping of relevant files and risks. | Mid-tier; reasoning if architecture is unclear. | No code changes; carry only useful context forward. |
| Architecture decision | Ask for options, tradeoffs, constraints, and a recommendation. | Reasoning/frontier where complexity warrants it. | Bound the question and require assumptions. |
| Implementation from a known plan | Start fresh with approved plan and file list. | Mid-tier where quality gates are strong. | Avoid re-research; run tests; stop at planned scope. |
| Unknown failure debugging | Provide logs, stack traces, repro steps, and recent changes. | Reasoning for root cause, then cheaper scoped patching where appropriate. | Use hypothesis -> test -> fix -> validation. |
| Test generation | Provide target behavior, edge cases, and framework. | Lightweight or mid-tier. | Keep production code unchanged unless the task explicitly includes it. |
| Repeated team workflow | Convert into instructions, prompt files, skills, or custom agents. | Depends on workflow complexity. | Reduce repeated discovery and inconsistent tool use. |

## Terms

- **UBB:** usage-based billing for metered Copilot interactions.
- **AI Credits:** GitHub's billing unit for metered Copilot usage where applicable; `1 AI Credit = $0.01 USD`.
- **ULB:** user-level budget, the per-user cap for AI Credit usage in a billing period.
- **Pooled credits:** included monthly AI Credits shared across licensed users in the billing entity.
- **Additional spend:** metered charges after included pooled credits are exhausted.

## Admin Checklist

For the full admin and FinOps operating model -- budgets, reporting, showback, and governance -- see [ADMIN_FINOPS_GUIDE.md](ADMIN_FINOPS_GUIDE.md). For the product controls behind these actions, see [PRODUCT_FEATURE_QUICK_HITS.md](PRODUCT_FEATURE_QUICK_HITS.md).

| Owner | Action | Why It Matters | Source |
|---|---|---|---|
| Enterprise owner or billing manager | Set a universal user-level budget. | ULBs prevent a small number of users or sessions from consuming the shared pool early. | [Budget controls](https://docs.github.com/en/copilot/tutorials/budgets/getting-started-with-budget-controls) |
| Billing manager | Identify power users and define overrides. | Large-codebase, agentic, frontier-model, and code-review-heavy users may need higher limits. | [Budget controls](https://docs.github.com/en/copilot/tutorials/budgets/getting-started-with-budget-controls) |
| Billing manager and cost owners | Configure cost-center and enterprise spending limits. | These manage additional spend exposure after included credits are exhausted. | [Managing AI credits](https://wellarchitected.github.com/library/governance/recommendations/managing-ai-credits/) |
| Billing manager | Decide who receives alerts and who responds. | A hard stop without an owner creates support friction; an alert without enforcement may not control spend. | [Budget controls](https://docs.github.com/en/copilot/tutorials/budgets/getting-started-with-budget-controls) |
| Platform owner | Publish developer guidance before enforcement. | Budget controls reduce runaway usage, but efficient work depends on task boundaries, context hygiene, model routing, and validation. | [Optimize AI usage](https://docs.github.com/en/copilot/tutorials/optimize-ai-usage) |
| FinOps or platform owner | Review usage weekly during rollout, then monthly once stable. | Usage reports, team metrics, and CLI metrics help identify concentrated consumption, temporary spikes, and users blocked before finishing useful work. | [Usage reports](https://github.blog/changelog/2026-05-20-copilot-usage-metrics-reports-now-use-github-owned-download-urls) |

## Budget And Governance Notes

- Budget setup is conceptually straightforward, but rollout requires ownership decisions: user-level budget defaults, power-user overrides, cost-center mapping, enterprise spending limits, alert recipients, hard-stop behavior, and a support path for blocked users.
- Use ULBs to prevent a small number of users or agentic sessions from consuming the shared pool early.
- Use cost-center and enterprise budgets to manage additional spend exposure after included credits are exhausted, depending on configuration.
- Make sure support teams can diagnose which budget layer caused a block.
- Review usage weekly during rollout, then monthly once stable. Look for concentrated per-user consumption, premium-model concentration, temporary spikes, and teams blocked before completing productive work.
- Track Copilot code review separately from normal chat and agent usage because it may consume AI Credits and GitHub Actions minutes.
- For custom agentic workflows built with the Copilot SDK, OpenTelemetry can connect agent sessions, tool calls, and application traces. For standard VS Code and Copilot CLI usage, start with GitHub usage reports and available IDE/CLI telemetry, then add SDK/OpenTelemetry where your team owns the workflow harness.

## Developer Playbook

Do:

- Start with a clear task, relevant files, expected outcome, and stopping condition.
- Check official model and pricing documentation before making model-cost assumptions.
- Split larger work into research, plan, implementation, and validation phases.
- Use the smallest capable model for the phase, not the cheapest model by price alone.
- Provide exact files, logs, stack traces, issue links, constraints, and acceptance criteria when known.
- Use tests, linters, type checks, security scans, build commands, and CI checks.
- Measure the full route: requests, tool calls, retries, validations, repairs, and final acceptance.
- Start a fresh session between phases when old context no longer matters.
- Keep repository instructions short, specific, and grounded in repeated agent failure modes.
- Reuse artifacts only when identity, freshness, and scope are clear.

Common pitfalls:

- Shorter prompts alone rarely fix an expensive workflow if retries, repairs, or broad search continue.
- Phase-local token movement is diagnostic until the full route and quality gates are measured.
- Context reduction needs a fallback path for required source material.
- Lower reasoning or cheaper models should be promoted only when quality evidence supports the route.
- Workflow telemetry is engineering evidence; invoice-grade billing claims need billing data.
- One workflow experiment should not become a universal model recommendation.
- Output length limits work best as a formatting tool, not the primary cost-control strategy.
- Agents should have bounded search and tool access when the relevant files are already known.
- User-level budget changes should be checked against cost-center and enterprise budgets.
- BYOK, provider pricing, and OpenTelemetry guidance should specify the surface and whether the question is Copilot billing, reporting, or custom workflow instrumentation.

## Claim Discipline

Label every optimization claim by evidence type:

- **Official product behavior:** first-party GitHub or Microsoft product documentation, changelog, or release note.
- **GitHub usage report/export:** usage reporting or export evidence.
- **Workflow telemetry:** aggregate/proxy data from a bounded workflow or experiment.
- **Workflow experiment:** bounded experimental result with quality and provenance checks.
- **Recommendation/inference:** guidance derived from evidence, not direct proof.

Keep evidence types separate. Workflow telemetry is not billing proof, and one workflow experiment is not a universal model benchmark.

## Measurement Checklist

Before claiming savings, confirm:

- The result is measured at finished-workflow level.
- The final output passed quality gates.
- Retries, repairs, tool calls, and validations are counted.
- The claim distinguishes estimate, telemetry, usage export, and invoice-grade billing data.
- The evidence says what it does not prove.
- Negative results are recorded as guardrails.
- The measurement is tied to a real workflow change, not a generic prompt-style preference.
- The requested model and the model or feature actually reported in usage data are recorded where available.
- Similar tasks, repos, source conditions, and validation bars are compared before quoting movement.

## Source Links

### GitHub Copilot And UBB

- [GitHub Copilot plans](https://docs.github.com/en/copilot/get-started/plans)
- [Models and pricing for GitHub Copilot](https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing)
- [Getting started with budget controls](https://docs.github.com/en/copilot/tutorials/budgets/getting-started-with-budget-controls)
- [Optimizing your budget configuration](https://docs.github.com/en/copilot/tutorials/budgets/optimizing-your-budget-configuration)
- [Improving agent quality to optimize AI usage](https://docs.github.com/en/copilot/tutorials/optimize-ai-usage)
- [Managing AI credits, GitHub Well-Architected](https://wellarchitected.github.com/library/governance/recommendations/managing-ai-credits/)
- [Auto model selection now routes based on your task in VS Code](https://github.blog/changelog/2026-05-20-auto-model-selection-now-routes-based-on-your-task-in-vs-code)
- [Copilot usage metrics reports now use GitHub-owned download URLs](https://github.blog/changelog/2026-05-20-copilot-usage-metrics-reports-now-use-github-owned-download-urls)
- [OpenTelemetry instrumentation for Copilot SDK](https://docs.github.com/en/copilot/how-tos/copilot-sdk/observability/opentelemetry)

### Provider Token Mechanics

Use these for general token, context, caching, batch, reasoning, and evaluation concepts. Use GitHub Copilot billing documentation for Copilot charge and AI Credit questions.

- [OpenAI pricing](https://developers.openai.com/api/docs/pricing)
- [OpenAI cost optimization](https://developers.openai.com/api/docs/guides/cost-optimization)
- [OpenAI prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching)
- [OpenAI conversation state](https://developers.openai.com/api/docs/guides/conversation-state)
- [OpenAI reasoning models](https://developers.openai.com/api/docs/guides/reasoning)
- [OpenAI evals](https://developers.openai.com/api/docs/guides/evals)
- [Anthropic pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- [Anthropic prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- [Anthropic token counting](https://platform.claude.com/docs/en/build-with-claude/token-counting)
- [Anthropic context windows](https://platform.claude.com/docs/en/build-with-claude/context-windows)
- [Anthropic extended thinking](https://platform.claude.com/docs/en/build-with-claude/extended-thinking)
- [Google Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing)
- [Google Gemini context caching](https://ai.google.dev/gemini-api/docs/caching)
- [Google Gemini token counting](https://ai.google.dev/gemini-api/docs/tokens)
- [Google Gemini thinking](https://ai.google.dev/gemini-api/docs/thinking)
- [Google Gemini Batch API](https://ai.google.dev/gemini-api/docs/batch-api)
- [OpenTelemetry GenAI semantic conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/)

## Boundary

This companion does not claim billing savings, durable savings, a universal percentage, request-level provider-token proof, model superiority, or fleet readiness. Those boundaries are intentional.

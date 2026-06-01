# Customer Companion: Cost-Aware Copilot Usage

This is the customer-safe companion to the May 2026 newsletter. It summarizes the practical UBB and cost-aware workflow guidance without exposing experiment logs or stronger claims than the evidence supports.

## Executive Summary

- **UBB starts June 1 for affected customers.** Metered Copilot interactions use GitHub AI Credits where applicable.
- **Developer clarification:** code completions and Next Edit Suggestions are not billed in AI Credits for paid Copilot plans. Developers should use GitHub's model and pricing documentation to understand which interactions can consume AI Credits.
- **Code review clarification:** Copilot code review should be tracked separately because it can consume AI Credits and GitHub Actions minutes.
- **Routing clarification:** Auto model selection can help route work by task and model health, but it should be treated as workflow guidance, not billing proof.
- **Budgets and behavior must be paired.** ULBs, cost-center budgets, enterprise limits, alerts, and usage exports work best when developers also get workflow guidance.
- **The useful optimization target is finished work.** Measure the route to a correct, reviewed, tested result, not only one prompt or one phase.
- **A real workflow moved materially.** In this newsletter system, retained aggregate/proxy comparisons showed roughly **25-45% less token mass** after workflow changes such as phase-specific routing, compact working sets, artifact reuse, and quality-gated fallback. Treat that as a measured workflow signal, not billing proof.

## What Changed In The Workflow

The cost story behind this newsletter is concrete: the generation system was changed to do less repeated AI work while keeping validation in the loop.

| Change | Customer-safe takeaway | Metric signal |
|---|---|---:|
| Phase-specific routing | Different phases deserve different model/reasoning choices; test the route, not the model in isolation. | Integrated comparisons showed roughly 25-45% lower aggregate/proxy token mass. |
| Compact working set | Smaller context can help when required source classes and fallback are preserved. | One Phase 3 example reduced the curation token load by roughly nine-tenths. |
| Artifact reuse / no-refetch | Reuse accepted artifacts instead of re-fetching, but bind identity, freshness, and scope first. | Helped reduce repeated retrieval and synthesis work inside the accepted route. |
| stdout/no-tools route | Suppress unnecessary tools only after readiness checks pass; keep fallback available. | Repaired route passed V2 quality and newsletter validation. |
| Failed output-shape policy | Shorter output instructions can increase total route cost by causing compensation elsewhere. | Negative result; not promoted. |

The point is not that these exact percentages transfer to another team. The point is that finished-workflow measurement can reveal where agentic work is being repeated, amplified, or repaired.

## Terms

- **UBB:** usage-based billing for metered Copilot interactions.
- **AI Credits:** GitHub's billing unit for metered Copilot usage where applicable; `1 AI Credit = $0.01 USD`.
- **ULB:** user-level budget, the per-user cap for AI Credit usage in a billing period.
- **Pooled credits:** included monthly AI Credits shared across licensed users in the billing entity.
- **Additional spend:** metered charges after included pooled credits are exhausted.

## Admin Checklist

| Owner | Action | Why It Matters | Source |
|---|---|---|---|
| Enterprise owner or billing manager | Set a universal user-level budget. | ULBs prevent a small number of users or sessions from consuming the shared pool early. | [Budget controls](https://docs.github.com/en/copilot/tutorials/budgets/getting-started-with-budget-controls) |
| Billing manager | Identify power users and define overrides. | Large-codebase, agentic, frontier-model, and code-review-heavy users may need higher limits. | [Budget controls](https://docs.github.com/en/copilot/tutorials/budgets/getting-started-with-budget-controls) |
| Billing manager and cost owners | Configure cost-center and enterprise spending limits. | These manage additional spend exposure after included credits are exhausted. | [Managing AI credits](https://wellarchitected.github.com/library/governance/recommendations/managing-ai-credits/) |
| Billing manager | Decide who receives alerts and who responds. | A hard stop without an owner creates support friction; an alert without enforcement may not control spend. | [Budget controls](https://docs.github.com/en/copilot/tutorials/budgets/getting-started-with-budget-controls) |
| Platform owner | Publish developer guidance before enforcement. | Budget controls reduce runaway usage, but efficient work depends on task boundaries, context hygiene, model routing, and validation. | [Optimize AI usage](https://docs.github.com/en/copilot/tutorials/optimize-ai-usage) |
| FinOps or platform owner | Review usage weekly during rollout, then monthly once stable. | Usage reports, team metrics, and CLI metrics help identify concentrated consumption, temporary spikes, and users blocked before finishing useful work. | [Usage reports](https://github.blog/changelog/2026-05-20-copilot-usage-metrics-reports-now-use-github-owned-download-urls) |

## Developer Playbook

Do:

- Start with a clear task, relevant files, expected outcome, and stopping condition.
- Check official model and pricing documentation before making model-cost assumptions.
- Split larger work into research, plan, implementation, and validation phases.
- Use the smallest capable model for the phase, not the cheapest model by price alone.
- Provide exact files, logs, stack traces, issue links, constraints, and acceptance criteria when known.
- Use tests, linters, type checks, security scans, build commands, and CI checks.
- Measure the full route: requests, tool calls, retries, validations, repairs, and final acceptance.

Do not:

- Do not claim savings from shorter prompts alone.
- Do not treat phase-local token movement as full-route savings.
- Do not strip context without a fallback path to restore required source material.
- Do not force lower reasoning or cheaper models without quality evidence.
- Do not treat internal telemetry as billing proof.
- Do not quote private exact token counts in customer material unless the evidence owner approves the metric and caveat.
- Do not turn one workflow experiment into a universal model recommendation.

## Measurement Checklist

Before claiming savings, confirm:

- The result is measured at finished-workflow level.
- The final output passed quality gates.
- Retries, repairs, tool calls, and validations are counted.
- The claim distinguishes estimate, telemetry, usage export, and invoice-grade billing data.
- The evidence says what it does not prove.
- Negative results are recorded as guardrails.
- The measurement is tied to a real workflow change, not a generic prompt-style preference.

## Source Links

- [Models and pricing for GitHub Copilot](https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing)
- [Getting started with budget controls](https://docs.github.com/en/copilot/tutorials/budgets/getting-started-with-budget-controls)
- [Improving agent quality to optimize AI usage](https://docs.github.com/en/copilot/tutorials/optimize-ai-usage)
- [Managing AI credits, GitHub Well-Architected](https://wellarchitected.github.com/library/governance/recommendations/managing-ai-credits/)
- [Auto model selection now routes based on your task in VS Code](https://github.blog/changelog/2026-05-20-auto-model-selection-now-routes-based-on-your-task-in-vs-code)
- [Copilot usage metrics reports now use GitHub-owned download URLs](https://github.blog/changelog/2026-05-20-copilot-usage-metrics-reports-now-use-github-owned-download-urls)
- [OpenTelemetry instrumentation for Copilot SDK](https://docs.github.com/en/copilot/how-tos/copilot-sdk/observability/opentelemetry)

## Boundary

This companion does not claim billing savings, durable savings, a universal percentage, request-level provider-token proof, model superiority, or fleet readiness. Those boundaries are intentional.

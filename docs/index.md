# CustomerNewsletter

A public, reusable system for drafting enterprise-focused Copilot newsletters.

## Start Here

If you only read one page, start here:
- [Start here (Feb 2026)](launch/2026-02/start-here.md)

For the current cost-aware workflow release:
- [May 2026 cost optimization companion](https://github.com/briancl2/CustomerNewsletter/blob/main/release_bundle/2026-05_newsletter_cost_optimization/CUSTOMER_COMPANION.md) (canonical landing page from the shipped newsletter)
- [May 2026 system release notes](https://github.com/briancl2/CustomerNewsletter/blob/main/release_bundle/2026-05_newsletter_cost_optimization/NEWSLETTER_SYSTEM_RELEASE_NOTES.md)
- [May 2026 product feature quick hits](https://github.com/briancl2/CustomerNewsletter/blob/main/release_bundle/2026-05_newsletter_cost_optimization/PRODUCT_FEATURE_QUICK_HITS.md)

The companion's `START HERE` section routes to the start-here copy, FinOps playbook, worked examples, admin guide, developer guide, and source references.

Then, if you want the backstory:
- [Short case study](launch/2026-02/case-study.md)
- [Timeline](launch/2026-02/timeline.md)

Want to see a real shipped example?
- [Published February issue (Discussion #18)](https://github.com/briancl2/CustomerNewsletter/discussions/18)
- [Published May issue (Discussion #21)](https://github.com/briancl2/CustomerNewsletter/discussions/21)

## Current Release Focus

The May 2026 release bundle explains how the newsletter generation system was updated to reduce repeated agent work while keeping validation in the route. It covers:

- how to generate a newsletter with fewer wasted tokens
- how to apply the same workflow patterns to other agentic systems
- what changed across the source-pruning, artifact-reuse, compact-working-set, validation, and publication surfaces
- which Copilot billing, budget, reporting, model-routing, and provider token-mechanics sources support the guidance
- how FinOps teams can reason about baselines, budget layers, showback, and savings-claim discipline
- worked examples for content generation, docs updates, debugging, budget-block triage, and custom agent workflows

The bundle uses rounded aggregate/proxy workflow metrics with explicit non-billing caveats. Private run logs, exact token tables, retained evidence paths, and internal source notes are not published.

## Try It

### VS Code Copilot Chat

1. Open this repo in VS Code.
2. Open Copilot Chat and select the `customer_newsletter` agent.
3. Paste this prompt:

```text
i want you to generate a from-scratch brand new february newsletter using the dates Dec 5 2025 to Feb 13 2026
```

### Copilot CLI

Headless mode:

```bash
copilot --agent customer_newsletter \
  --model claude-opus-4.7 \
  --allow-all \
  --no-ask-user \
  -p "i want you to generate a from-scratch brand new february newsletter using the dates Dec 5 2025 to Feb 13 2026"
```

Interactive mode:

```bash
copilot --agent customer_newsletter --model claude-opus-4.7 -i
```

## Docs

- [How it works](how-it-works.md)
- [Architecture](architecture.md)
- [Feb 2026 system report](reports/newsletter_system_report_2026-02.md)
- [May 2026 cost optimization bundle](https://github.com/briancl2/CustomerNewsletter/tree/main/release_bundle/2026-05_newsletter_cost_optimization)

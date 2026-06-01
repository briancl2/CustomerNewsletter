# Admin Readiness Guide: Budgets, Reporting, And Governance

This guide is for enterprise owners, billing managers, platform owners, security leads, and finance partners preparing for usage-based billing and agentic development at scale.

## Operating Model

Budgets and reports do not replace workflow discipline, but they make it possible to manage it. Pair UBB reporting with model policy, usage metrics, observability, tool boundaries, and developer enablement.

## Review First

1. Usage-based billing readiness: AI Credits, included usage, model-specific pricing, budgets, and escalation paths.
2. Reporting: April reports, team-level metrics, CLI activity, plan mode, report download URLs, and audit APIs.
3. Model policy: Auto model selection, model-cost documentation, and model rules.
4. Observability: Copilot SDK OpenTelemetry, BYOK surface-specific visibility, and terminal output compression.
5. Governance: terminal sandboxing, local MCP server sandboxing, network-domain policy, command risk assessment, cloud-agent runner controls, and firewall settings.

## Before UBB Go-Live

- Confirm budget owners and escalation paths.
- Pull April reports as a baseline.
- Set a universal user-level budget and define power-user overrides.
- Decide how cost-center and enterprise spending limits should behave when included pooled credits are exhausted.
- Assign alert recipients and support-path owners for blocked users.
- Decide where model rules are required.
- Explain model-specific AI Credit pricing with GitHub billing docs, not provider API price sheets or hearsay.
- Give teams developer guidance before enforcing blunt usage limits.

## Weekly Cost Visibility Review

- Review usage by team and surface.
- Separate plan mode, CLI activity, code review, and cloud-agent activity where possible.
- Ask whether spikes came from valuable work, repeated failed work, or missing workflow boundaries.
- Feed repeated cost patterns back into developer playbooks.

## Billing Caveats To Communicate

- Code completions and Next Edit Suggestions are not billed in AI Credits for paid Copilot plans.
- Copilot code review should be tracked separately because it can consume AI Credits and GitHub Actions minutes.
- User-facing budget block messages may not identify which budget layer caused the block; support processes should be ready to diagnose ULB, cost-center, and enterprise limits.
- Telemetry is engineering evidence, not billing proof.

## Product Surfaces

| Surface | Admin question | Source |
|---|---|---|
| UBB and AI Credits | Who owns budget thresholds and escalation paths? | https://github.blog/news-insights/company-news/github-copilot-is-moving-to-usage-based-billing/ |
| GitHub Learn UBB module | What should teams read first? | https://learn.github.com/courses/gitHubusagebasedbillingmodule |
| Model pricing | How should teams understand model-cost differences? | https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing |
| Auto model selection | Where can task-aware routing replace manual model choice? | https://github.blog/changelog/2026-05-20-auto-model-selection-now-routes-based-on-your-task-in-vs-code |
| Model rules | Which models are available to which organizations, and which rules are still preview-scoped? | https://github.blog/changelog/2026-05-26-target-copilot-models-to-organizations-with-model-rules |
| Plan mode metrics | How much work is planning rather than editing? | https://github.blog/changelog/2026-03-02-copilot-metrics-now-includes-plan-mode |
| CLI activity metrics | Are terminal-native agent workflows visible? | https://github.blog/changelog/2026-04-10-copilot-cli-activity-now-included-in-usage-metrics-totals-and-feature-breakdowns |
| Team-level metrics API | Can teams self-serve usage reporting? | https://github.blog/changelog/2026-05-14-team-level-copilot-usage-metrics-now-available-via-api |
| Report download URLs | Can finance/reporting integrations retrieve stable reports? | https://github.blog/changelog/2026-05-20-copilot-usage-metrics-reports-now-use-github-owned-download-urls |
| Cloud-agent audit API | Which repos have cloud-agent settings enabled? | https://github.blog/changelog/2026-05-18-audit-repository-copilot-cloud-agent-configuration-via-the-rest-api |
| Copilot SDK OpenTelemetry | Can custom agents be traced end to end as engineering signal, not billing proof? | https://docs.github.com/en/copilot/how-tos/copilot-sdk/observability/opentelemetry |
| BYOK scope | Which surface, provider path, and billing/reporting context applies to BYOK usage? | https://code.visualstudio.com/updates/v1_117 |
| Terminal output compression | Are terminal-heavy sessions reducing context noise? | https://code.visualstudio.com/updates/v1_121 |
| Cloud-agent runner controls | Where can agents run? | https://github.blog/changelog/2026-04-03-organization-runner-controls-for-copilot-cloud-agent |
| Cloud-agent firewall settings | What network access do agents have? | https://github.blog/changelog/2026-04-03-organization-firewall-settings-for-copilot-cloud-agent |
| MCP secret scanning | Are MCP-connected tools covered by secret scanning? | https://github.blog/changelog/2026-05-05-secret-scanning-with-github-mcp-server-is-now-generally-available |

## Recommended Practices

- Pair budget controls with developer workflow guidance.
- Use metrics to ask better questions, not to shame usage.
- Track quality and outcome alongside usage.
- Treat model rules as policy, not as model ranking.
- Make observability a prerequisite for custom agent scale.
- Keep security and cost governance together because tool scope affects both.

## Common Pitfalls

- High usage needs context before it is classified as waste.
- Telemetry is useful for engineering diagnosis; invoice savings need billing evidence.
- Cheaper models and lower reasoning settings still need quality validation.
- Broad autonomous tool access should follow audit, sandbox, and network-boundary decisions.
- BYOK, OpenTelemetry, and provider pricing guidance should specify whether the question is Copilot billing, Copilot reporting, direct provider usage, or custom workflow instrumentation.

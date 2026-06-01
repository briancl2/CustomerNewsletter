# Admin And FinOps Guide: Budgets, Reporting, And Governance

> **Bottom line:** Pair usage-based billing controls with reporting, model policy, and developer guidance; budgets limit runaway spend, but efficient work comes from workflow design. **For:** Admin & FinOps owners -- billing managers, platform owners, and FinOps partners. **Read time:** about 8 minutes.

This guide combines admin readiness and FinOps operating guidance for usage-based billing (UBB) and agentic development at scale. It is general guidance, not invoice analysis or a savings guarantee. Use the [admin track](#admin-and-platform-track) for budgets, reporting, and governance, and the [FinOps track](#finops-track) for the operating model, evidence typing, and showback.

## Operating Model

Cost control works best when finance, platform, and developer enablement move together. Budgets and reports do not replace workflow discipline, but they make it possible to manage it.

| Layer | Owner | Question | Output |
|---|---|---|---|
| Billing authority | Billing or enterprise owner | Which charges are invoice-grade? | Billing report and budget configuration. |
| Usage visibility | Platform or analytics owner | Who is using which surfaces? | Usage exports, team reports, CLI metrics, code review tracking. |
| Workflow behavior | Engineering lead | Which patterns cause repeated attempts or repairs? | Team guidance, validation gates, scoped prompts, reusable artifacts. |
| Policy | Platform and governance owners | Which controls should apply by default? | User-level budgets, cost-center limits, model policy, tool boundaries. |
| Support path | Admin and support owners | What happens when a user is blocked? | Escalation path and override process. |

## Admin And Platform Track

### Review First

1. **UBB readiness:** AI Credits, included usage, model-specific pricing, budgets, and escalation paths.
2. **Reporting:** April reports, team-level metrics, CLI activity, plan mode, report download URLs, and audit APIs.
3. **Model policy:** Auto model selection, model-cost documentation, and model rules.
4. **Observability:** Copilot SDK OpenTelemetry, BYOK surface-specific visibility, and terminal output compression.
5. **Governance:** terminal sandboxing, local MCP server sandboxing, network-domain policy, command risk assessment, cloud-agent runner controls, and firewall settings.

### Before UBB Go-Live

- Confirm budget owners and escalation paths.
- Pull April reports as a baseline.
- Set a universal user-level budget and define power-user overrides.
- Decide how cost-center and enterprise spending limits behave when included pooled credits are exhausted.
- Assign alert recipients and support-path owners for blocked users.
- Decide where model rules are required.
- Explain model-specific AI Credit pricing with GitHub billing docs, not provider API price sheets or hearsay.
- Give teams developer guidance before enforcing blunt usage limits.

### Weekly Cost Visibility Review

- Review usage by team and surface.
- Separate plan mode, CLI activity, code review, and cloud-agent activity where possible.
- Ask whether spikes came from valuable work, repeated failed work, or missing workflow boundaries.
- Feed repeated cost patterns back into developer guidance.

### Billing Caveats To Communicate

- Code completions and Next Edit Suggestions are not billed in AI Credits for paid Copilot plans.
- Copilot code review should be tracked separately because it can consume AI Credits and GitHub Actions minutes.
- User-facing budget block messages may not identify which budget layer caused the block; support processes should be ready to diagnose user-level, cost-center, and enterprise limits.
- Telemetry is engineering evidence, not billing proof.

### Product Surfaces

This is the admin-facing subset. For the full feature inventory with status labels, use [PRODUCT_FEATURE_QUICK_HITS.md](PRODUCT_FEATURE_QUICK_HITS.md).

| Surface | Admin question | Source |
|---|---|---|
| UBB and AI Credits | Who owns budget thresholds and escalation paths? | https://github.blog/news-insights/company-news/github-copilot-is-moving-to-usage-based-billing/ |
| Model pricing | How should teams understand model-cost differences? | https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing |
| Auto model selection | Where can task-aware routing replace manual model choice? | https://github.blog/changelog/2026-05-20-auto-model-selection-now-routes-based-on-your-task-in-vs-code |
| Model rules | Which models are available to which organizations? | https://github.blog/changelog/2026-05-26-target-copilot-models-to-organizations-with-model-rules |
| Plan mode metrics | How much work is planning rather than editing? | https://github.blog/changelog/2026-03-02-copilot-metrics-now-includes-plan-mode |
| CLI activity metrics | Are terminal-native agent workflows visible? | https://github.blog/changelog/2026-04-10-copilot-cli-activity-now-included-in-usage-metrics-totals-and-feature-breakdowns |
| Team-level metrics API | Can teams self-serve usage reporting? | https://github.blog/changelog/2026-05-14-team-level-copilot-usage-metrics-now-available-via-api |
| Report download URLs | Can finance integrations retrieve stable reports? | https://github.blog/changelog/2026-05-20-copilot-usage-metrics-reports-now-use-github-owned-download-urls |
| Cloud-agent audit API | Which repos have cloud-agent settings enabled? | https://github.blog/changelog/2026-05-18-audit-repository-copilot-cloud-agent-configuration-via-the-rest-api |
| Copilot SDK OpenTelemetry | Can custom agents be traced as engineering signal, not billing proof? | https://docs.github.com/en/copilot/how-tos/copilot-sdk/observability/opentelemetry |
| Cloud-agent runner controls | Where can agents run? | https://github.blog/changelog/2026-04-03-organization-runner-controls-for-copilot-cloud-agent |
| Cloud-agent firewall settings | What network access do agents have? | https://github.blog/changelog/2026-04-03-organization-firewall-settings-for-copilot-cloud-agent |
| MCP secret scanning | Are MCP-connected tools covered by secret scanning? | https://github.blog/changelog/2026-05-05-secret-scanning-with-github-mcp-server-is-now-generally-available |

## FinOps Track

### Evidence Types

Use the right evidence for the right decision.

| Evidence type | Good for | Not good for |
|---|---|---|
| Invoice or billing report | Finance-grade spend decisions. | Explaining every workflow cause. |
| GitHub usage export or report | Trends, concentration, rollout monitoring. | Proving exact avoided spend. |
| Product telemetry or traces | Engineering diagnosis and workflow tuning. | Invoice-grade claims by itself. |
| Workflow experiment | Finding repeated work and quality tradeoffs. | Universal model or savings claims. |
| Estimate | Planning and prioritization. | Customer-facing proof without caveats. |

### Baseline Process

1. Confirm budget owners, cost-center mapping, and enterprise spending-limit behavior.
2. Pull available usage reports before changing policy.
3. Segment usage by team, surface, and known workflow where reporting allows.
4. Separate chat, agents, CLI activity, code review, and custom-agent workflows where possible.
5. Identify concentrated usage and ask whether it came from valuable work, repeated failed work, or missing guidance.
6. Publish developer guidance before tightening controls.
7. Review weekly during rollout, then monthly once usage stabilizes.

### Showback Starter

Use a simple showback table before moving toward chargeback.

| Field | Example |
|---|---|
| Team or cost center | Platform Engineering |
| Budget owner | Engineering director |
| Usage owner | Platform lead |
| Primary surfaces | VS Code chat, Copilot CLI, code review |
| Review cadence | Weekly during rollout |
| Override policy | Power-user override with owner approval |
| Support path | Admin triage, then billing owner escalation |
| Quality guardrail | Tests and validation remain required even when usage is constrained |

### Budget Block Triage

When a developer is blocked, diagnose the layer before changing behavior.

1. Check the user-level budget.
2. Check cost-center and enterprise spending limits.
3. Check whether the user is a known power user or running a temporary rollout task.
4. Check whether the work is repeated because of unclear task boundaries, missing files, or failed validations.
5. Decide whether the fix is an override, a policy adjustment, or workflow guidance.

### Savings Claim Discipline

Use precise wording:

- Say **usage decreased** only when usage reports show it.
- Say **workflow repeated less work** when telemetry or experiments show fewer retries, tool calls, or repairs.
- Say **invoice savings** only when billing reports support it.
- Say **quality-preserving optimization** only when the output passed the agreed gates.

Avoid turning a workflow experiment into a universal percentage, a model ranking, or a billing promise.

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

## First-Party References

- [Models and pricing for GitHub Copilot](https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing)
- [Getting started with budget controls](https://docs.github.com/en/copilot/tutorials/budgets/getting-started-with-budget-controls)
- [Optimizing your budget configuration](https://docs.github.com/en/copilot/tutorials/budgets/optimizing-your-budget-configuration)
- [Managing AI credits, GitHub Well-Architected](https://wellarchitected.github.com/library/governance/recommendations/managing-ai-credits/)
- [Copilot usage metrics reports now use GitHub-owned download URLs](https://github.blog/changelog/2026-05-20-copilot-usage-metrics-reports-now-use-github-owned-download-urls)
- [Team-level Copilot usage metrics API](https://github.blog/changelog/2026-05-14-team-level-copilot-usage-metrics-now-available-via-api)
- [Copilot CLI activity in usage metrics](https://github.blog/changelog/2026-04-10-copilot-cli-activity-now-included-in-usage-metrics-totals-and-feature-breakdowns)

For the complete bundle link list, use [PUBLIC_SOURCES.md](PUBLIC_SOURCES.md).

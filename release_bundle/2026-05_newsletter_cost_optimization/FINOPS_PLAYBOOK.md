# FinOps Playbook: Cost-Aware Copilot Rollout

This playbook is for FinOps partners, billing owners, platform teams, and engineering leaders who need a practical operating model for Copilot usage-based billing. It is customer-safe guidance, not invoice analysis or a savings guarantee.

## Operating Model

Cost control works best when finance, platform, and developer enablement move together.

| Layer | Owner | Question | Output |
|---|---|---|---|
| Billing authority | Billing owner or enterprise owner | Which charges are invoice-grade? | Billing report and budget configuration. |
| Usage visibility | Platform or analytics owner | Who is using which surfaces? | Usage exports, team reports, CLI metrics, code review tracking. |
| Workflow behavior | Engineering lead | Which work patterns cause repeated attempts or repairs? | Team guidance, validation gates, scoped prompts, reusable artifacts. |
| Policy | Platform and governance owners | Which controls should apply by default? | User-level budgets, cost-center limits, model policy, tool boundaries. |
| Support path | Admin and support owners | What happens when a user is blocked? | Escalation path and override process. |

## Evidence Types

Use the right evidence for the right decision.

| Evidence type | Good for | Not good for |
|---|---|---|
| Invoice or billing report | Finance-grade spend decisions. | Explaining every workflow cause. |
| GitHub usage export or report | Trends, concentration, rollout monitoring. | Proving exact avoided spend. |
| Product telemetry or traces | Engineering diagnosis and workflow tuning. | Invoice-grade claims by itself. |
| Workflow experiment | Finding repeated work and quality tradeoffs. | Universal model or savings claims. |
| Estimate | Planning and prioritization. | Customer-facing proof without caveats. |

## Baseline Process

1. Confirm budget owners, cost-center mapping, and enterprise spending-limit behavior.
2. Pull available usage reports before changing policy.
3. Segment usage by team, surface, and known workflow where reporting allows.
4. Separate chat, agents, CLI activity, code review, and custom-agent workflows where possible.
5. Identify concentrated usage and ask whether it came from valuable work, repeated failed work, or missing guidance.
6. Publish developer guidance before tightening controls.
7. Review weekly during rollout, then monthly once usage stabilizes.

## Showback Starter

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

## Budget Block Triage

When a developer is blocked, diagnose the layer before changing behavior.

1. Check the user-level budget.
2. Check cost-center and enterprise spending limits.
3. Check whether the user is a known power user or running a temporary rollout task.
4. Check whether the work is repeated because of unclear task boundaries, missing files, or failed validations.
5. Decide whether the fix is an override, a policy adjustment, or workflow guidance.

## Savings Claim Discipline

Use precise wording:

- Say **usage decreased** only when usage reports show it.
- Say **workflow repeated less work** when telemetry or experiments show fewer retries, tool calls, or repairs.
- Say **invoice savings** only when billing reports support it.
- Say **quality-preserving optimization** only when the output passed the agreed gates.

Avoid turning a workflow experiment into a universal percentage, a model ranking, or a billing promise.

## Questions Before Policy Changes

- Which teams or users are concentrated in the usage report?
- Did the usage produce accepted work?
- Which tasks required repeated attempts or repairs?
- Are developers using broad context because required files are hard to identify?
- Are code review and agent sessions tracked separately?
- Would model policy help, or would it block valid work?
- Is the support team ready to diagnose budget-layer blocks?

## First-Party References

- [Models and pricing for GitHub Copilot](https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing)
- [Getting started with budget controls](https://docs.github.com/en/copilot/tutorials/budgets/getting-started-with-budget-controls)
- [Optimizing your budget configuration](https://docs.github.com/en/copilot/tutorials/budgets/optimizing-your-budget-configuration)
- [Managing AI credits, GitHub Well-Architected](https://wellarchitected.github.com/library/governance/recommendations/managing-ai-credits/)
- [Copilot usage metrics reports now use GitHub-owned download URLs](https://github.blog/changelog/2026-05-20-copilot-usage-metrics-reports-now-use-github-owned-download-urls)
- [Team-level Copilot usage metrics API](https://github.blog/changelog/2026-05-14-team-level-copilot-usage-metrics-now-available-via-api)
- [Copilot CLI activity in usage metrics](https://github.blog/changelog/2026-04-10-copilot-cli-activity-now-included-in-usage-metrics-totals-and-feature-breakdowns)

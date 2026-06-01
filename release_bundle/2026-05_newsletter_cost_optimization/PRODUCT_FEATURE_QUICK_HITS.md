# Product Feature Quick Hits For Cost Management

This is a first-party-source-backed inventory of features related to cost management, cost visibility, token efficiency, routing, and governance. Use the `Group` column for operational scanning before reading individual rows. Status labels are conservative: `GA` or `PREVIEW` appear only where the source explicitly supports that status.

| Group | Feature | Audience | Mechanism | Status | Source | Action |
|---|---|---|---|---|---|---|
| UBB readiness | Usage-based billing and AI Credits | Admin, finance | Budgeting and consumption model | Effective June 1, 2026 | https://github.blog/news-insights/company-news/github-copilot-is-moving-to-usage-based-billing/ | Prepare budgets, reports, and escalation paths. |
| UBB readiness | GitHub Learn UBB module | Admin, enablement | UBB education | Published | https://learn.github.com/courses/gitHubusagebasedbillingmodule | Use as the first readiness resource. |
| UBB readiness | April reports | Admin, finance | Baseline reporting | Available | https://github.blog/changelog/2026-05-12-april-reports-are-now-available-to-prepare-for-usage-based-billing | Pull baseline reports before policy changes. |
| UBB readiness | Model pricing for GitHub Copilot | Admin, finance | Copilot-specific per-token model pricing converted to AI Credits | Docs | https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing | Use GitHub Copilot billing docs for model-cost discussions. |
| Model and policy | Auto model selection | Developer, platform | Task-aware routing and intent detection | Available | https://github.blog/changelog/2026-05-20-auto-model-selection-now-routes-based-on-your-task-in-vs-code | Prefer policy-aware routing over manual guessing. |
| Model and policy | Auto model selection docs | Developer, platform | Routing semantics | Docs | https://docs.github.com/en/copilot/concepts/auto-model-selection | Teach what Auto does and does not prove. |
| Model and policy | Model rules | Admin, platform | Organization model policy | PREVIEW | https://github.blog/changelog/2026-05-26-target-copilot-models-to-organizations-with-model-rules | Target model availability by policy while preview scope applies. |
| Observability | Plan mode metrics | Admin, analytics | Usage visibility | Available | https://github.blog/changelog/2026-03-02-copilot-metrics-now-includes-plan-mode | Track planning behavior separately. |
| Observability | CLI activity metrics | Admin, DevOps | Terminal-agent visibility | Available | https://github.blog/changelog/2026-04-10-copilot-cli-activity-now-included-in-usage-metrics-totals-and-feature-breakdowns | Include CLI work in dashboards. |
| Observability | Team-level metrics API | Admin, analytics | Team reporting | Available | https://github.blog/changelog/2026-05-14-team-level-copilot-usage-metrics-now-available-via-api | Build self-serve team dashboards. |
| Observability | GitHub-owned report URLs | Admin, finance | Reporting integration | Available | https://github.blog/changelog/2026-05-20-copilot-usage-metrics-reports-now-use-github-owned-download-urls | Stabilize report retrieval. |
| Governance | Cloud-agent audit API | Admin, compliance | Auditability | PREVIEW | https://github.blog/changelog/2026-05-18-audit-repository-copilot-cloud-agent-configuration-via-the-rest-api | Audit repository cloud-agent settings before broad rollout. |
| Observability | Copilot SDK OpenTelemetry | Platform, observability | Trace context and telemetry | Docs | https://docs.github.com/en/copilot/how-tos/copilot-sdk/observability/opentelemetry | Instrument custom agents; use telemetry as engineering signal, not billing proof. |
| Preview watchlist | Copilot SDK | Platform | Agent application surface | PREVIEW | https://github.blog/changelog/2026-04-02-copilot-sdk-in-public-preview | Pair SDK adoption with telemetry and preview controls. |
| Developer efficiency | Prompt caching in VS Code | Developer | Stable context reuse | Available | https://code.visualstudio.com/updates/v1_118 | Treat as product behavior and engineering signal, not billing proof. |
| Developer efficiency | Tool search in VS Code | Developer | Tool-selection efficiency | Available | https://code.visualstudio.com/updates/v1_119 | Scope tools and observe behavior. |
| Developer efficiency | Terminal output compression | Developer, SRE | Context compression | PREVIEW | https://code.visualstudio.com/updates/v1_121 | Use for noisy terminal sessions where preview controls are acceptable. |
| Model and policy | BYOK for VS Code Business and Enterprise | Developer, platform | Bring your own provider key into VS Code chat | Surface-specific | https://code.visualstudio.com/updates/v1_117 | Specify surface and billing/reporting context before making cost claims. |
| Developer efficiency | Reasoning effort controls | Developer, platform | Model effort control | Surface-specific | https://code.visualstudio.com/updates/v1_121 | Test phase-by-phase and avoid generic savings claims. |
| Observability | Agent Debug and troubleshooting | Developer | Session visibility | Available | https://code.visualstudio.com/updates/v1_116 | Inspect behavior before optimizing. |
| Observability | Chronicle session history | Developer, lead | Session recall and search | CLI release | https://github.com/github/copilot-cli/releases/tag/v1.0.49 | Use for local learning; keep cost-tips claims out unless public docs become explicit. |
| Observability | Copilot CLI AI Credits display | Developer, admin | Cost visibility in CLI | CLI release | https://github.com/github/copilot-cli/releases/tag/v1.0.51 | Treat as visibility signal, not invoice proof. |
| Model and policy | BYOK/local providers in CLI | Developer, platform | Provider/model control | Docs | https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-byok-models | Govern provider choice with quality and policy. |
| Security and governance | Terminal sandboxing | Security, admin | Tool boundary | PREVIEW | https://code.visualstudio.com/updates/v1_112 | Bound shell access. |
| Security and governance | Local MCP server sandboxing | Security, platform | Tool boundary | PREVIEW | https://code.visualstudio.com/updates/v1_112 | Restrict MCP access. |
| Security and governance | Network-domain group policy | Admin, security | Network control | Available | https://code.visualstudio.com/updates/v1_120 | Reduce ungoverned external access. |
| Security and governance | Command risk assessment | Security, developer | Risk visibility | PREVIEW | https://code.visualstudio.com/updates/v1_121 | Add human approval for risky commands. |
| Governance | Cloud-agent runner controls | Admin, platform | Runtime governance | Available | https://github.blog/changelog/2026-04-03-organization-runner-controls-for-copilot-cloud-agent | Decide where agents run. |
| Governance | Cloud-agent firewall settings | Admin, security | Network governance | Available | https://github.blog/changelog/2026-04-03-organization-firewall-settings-for-copilot-cloud-agent | Control egress before scaling. |
| Governance | Cloud-agent REST task API | Platform | Workflow integration | PREVIEW | https://github.blog/changelog/2026-05-13-start-copilot-cloud-agent-tasks-via-the-rest-api | Automate only with audit and budget visibility. |
| Security and governance | MCP secret scanning | Security | Tool ecosystem trust | GA | https://github.blog/changelog/2026-05-05-secret-scanning-with-github-mcp-server-is-now-generally-available | Include in MCP governance. |
| Security and governance | MCP dependency scanning | Security | Tool ecosystem trust | PREVIEW | https://github.blog/changelog/2026-05-05-dependency-scanning-with-github-mcp-server-is-in-public-preview | Review MCP tool risk. |

## Verification Flags

| Item | Status | Bundle handling |
|---|---|---|
| `/chronicle cost-tips` | Not source-verified as a public/product claim | Keep out of direct product claims until release notes or docs are explicit. |
| Grafana dashboards | No direct public Copilot/Grafana setup source verified | Treat as an observability gap, not a quick hit. |
| Prompt caching savings magnitude | Product feature exists, billing impact not proved here | Describe mechanism, not savings. |
| Tool search savings magnitude | Product source exists, scenario-specific magnitude unclear | Describe scoped tool efficiency, not universal token reduction. |

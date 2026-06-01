# Product Feature Quick Hits For Cost Management

> **Bottom line:** A first-party-source-backed inventory of Copilot cost, visibility, routing, and governance features with conservative status labels. **For:** developers and Admin & FinOps owners auditing what is available and where. **Read time:** scan by `Group` column, about 5 minutes.

This is a first-party-source-backed inventory of features related to cost management, cost visibility, token efficiency, routing, and governance. Use the `Group` column for operational scanning before reading individual rows. Status labels are conservative: `GA` or `PREVIEW` appear only where the source explicitly supports that status.

GitHub Copilot billing and AI Credit claims should cite GitHub Docs, GitHub Blog, GitHub Changelog, or GitHub Well-Architected sources. Provider docs below are included for general token mechanics, context, caching, reasoning, batch, and instrumentation concepts; they are not Copilot billing sources.

| Group | Feature | Audience | Mechanism | Status | Source | Action |
|---|---|---|---|---|---|---|
| UBB readiness | Usage-based billing and AI Credits | Admin, finance | Budgeting and consumption model | Effective June 1, 2026 | https://github.blog/news-insights/company-news/github-copilot-is-moving-to-usage-based-billing/ | Prepare budgets, reports, and escalation paths. |
| UBB readiness | GitHub Learn UBB module | Admin, enablement | UBB education | Published | https://learn.github.com/courses/gitHubusagebasedbillingmodule | Use as the first readiness resource. |
| UBB readiness | April reports | Admin, finance | Baseline reporting | Available | https://github.blog/changelog/2026-05-12-april-reports-are-now-available-to-prepare-for-usage-based-billing | Pull baseline reports before policy changes. |
| UBB readiness | Model pricing for GitHub Copilot | Admin, finance | Copilot-specific per-token model pricing converted to AI Credits | Docs | https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing | Use GitHub Copilot billing docs for model-cost discussions. |
| UBB readiness | Code completions and Next Edit Suggestions caveat | Developer, admin | Clarifies what is outside AI Credit billing for paid Copilot plans | Docs | https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing#code-completions | Reduce developer anxiety around normal completions. |
| UBB readiness | Copilot code review billing caveat | Admin, developer | Separates AI Credits and Actions-minute considerations | Docs | https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing#pricing-and-usage-cost-considerations-for-copilot-code-review | Track code review separately from chat and agent usage. |
| UBB readiness | Budget controls | Admin, finance | User-level budgets, hard stops, alerts, and overrides | Docs | https://docs.github.com/en/copilot/tutorials/budgets/getting-started-with-budget-controls | Set defaults, power-user overrides, and alert ownership. |
| UBB readiness | Budget optimization | Admin, finance | Budget sizing and ongoing review | Docs | https://docs.github.com/en/copilot/tutorials/budgets/optimizing-your-budget-configuration | Review historical usage before tightening policy. |
| UBB readiness | GitHub Well-Architected AI credit management | Admin, FinOps | Layered budgets, attribution, and governance | Guidance | https://wellarchitected.github.com/library/governance/recommendations/managing-ai-credits/ | Pair spend controls with model/context guidance. |
| Model and policy | Auto model selection | Developer, platform | Task-aware routing and intent detection | Available | https://github.blog/changelog/2026-05-20-auto-model-selection-now-routes-based-on-your-task-in-vs-code | Prefer policy-aware routing over manual guessing. |
| Model and policy | Auto model selection docs | Developer, platform | Routing semantics | Docs | https://docs.github.com/en/copilot/concepts/auto-model-selection | Teach what Auto does and does not prove. |
| Model and policy | Model rules | Admin, platform | Organization model policy | PREVIEW | https://github.blog/changelog/2026-05-26-target-copilot-models-to-organizations-with-model-rules | Target model availability by policy while preview scope applies. |
| Observability | Plan mode metrics | Admin, analytics | Usage visibility | Available | https://github.blog/changelog/2026-03-02-copilot-metrics-now-includes-plan-mode | Track planning behavior separately. |
| Observability | CLI activity metrics | Admin, DevOps | Terminal-agent visibility | Available | https://github.blog/changelog/2026-04-10-copilot-cli-activity-now-included-in-usage-metrics-totals-and-feature-breakdowns | Include CLI work in dashboards. |
| Observability | Team-level metrics API | Admin, analytics | Team reporting | Available | https://github.blog/changelog/2026-05-14-team-level-copilot-usage-metrics-now-available-via-api | Build self-serve team dashboards. |
| Observability | GitHub-owned report URLs | Admin, finance | Reporting integration | Available | https://github.blog/changelog/2026-05-20-copilot-usage-metrics-reports-now-use-github-owned-download-urls | Stabilize report retrieval. |
| Governance | Cloud-agent audit API | Admin, compliance | Auditability | PREVIEW | https://github.blog/changelog/2026-05-18-audit-repository-copilot-cloud-agent-configuration-via-the-rest-api | Audit repository cloud-agent settings before broad rollout. |
| Observability | Copilot SDK OpenTelemetry | Platform, observability | Trace context and telemetry | Docs | https://docs.github.com/en/copilot/how-tos/copilot-sdk/observability/opentelemetry | Instrument custom agents; use telemetry as engineering signal, not billing proof. |
| Observability | OpenTelemetry GenAI semantic conventions | Platform, observability | Common vocabulary for GenAI traces | Spec | https://opentelemetry.io/docs/specs/semconv/gen-ai/ | Align custom instrumentation with standard GenAI attributes. |
| Preview watchlist | Copilot SDK | Platform | Agent application surface | PREVIEW | https://github.blog/changelog/2026-04-02-copilot-sdk-in-public-preview | Pair SDK adoption with telemetry and preview controls. |
| Developer efficiency | Prompt caching in VS Code | Developer | Stable context reuse | Available | https://code.visualstudio.com/updates/v1_118 | Treat as product behavior and engineering signal, not billing proof. |
| Developer efficiency | Tool search in VS Code | Developer | Tool-selection efficiency | Available | https://code.visualstudio.com/updates/v1_119 | Scope tools and observe behavior. |
| Developer efficiency | Terminal output compression | Developer, SRE | Context compression | PREVIEW | https://code.visualstudio.com/updates/v1_121 | Use for noisy terminal sessions where preview controls are acceptable. |
| Model and policy | BYOK for VS Code Business and Enterprise | Developer, platform | Bring your own provider key into VS Code chat | Surface-specific | https://code.visualstudio.com/updates/v1_117 | Specify surface and billing/reporting context before making cost claims. |
| Developer efficiency | Reasoning effort controls | Developer, platform | Model effort control | Surface-specific | https://code.visualstudio.com/updates/v1_121 | Test phase-by-phase and avoid generic savings claims. |
| Developer efficiency | GitHub optimize AI usage guide | Developer, team lead | Prompt clarity, phase separation, guardrails, and model/task fit | Docs | https://docs.github.com/en/copilot/tutorials/optimize-ai-usage | Use as the first developer enablement reference. |
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

## Provider Token Mechanics References

These sources explain token economics and workflow design concepts that can inform custom agent systems. They are not authoritative for GitHub Copilot charges.

| Provider | Topic | Source | Use |
|---|---|---|---|
| OpenAI | Pricing | https://developers.openai.com/api/docs/pricing | Understand direct API price structures for non-Copilot workflows. |
| OpenAI | Cost optimization | https://developers.openai.com/api/docs/guides/cost-optimization | Compare general levers such as model choice, batching, caching, and output control. |
| OpenAI | Prompt caching | https://developers.openai.com/api/docs/guides/prompt-caching | Understand why stable repeated prefixes can matter. |
| OpenAI | Conversation state | https://developers.openai.com/api/docs/guides/conversation-state | Manage long-running context and state. |
| OpenAI | Reasoning models | https://developers.openai.com/api/docs/guides/reasoning | Scope reasoning use to tasks that need it. |
| OpenAI | Evals | https://developers.openai.com/api/docs/guides/evals | Pair cost changes with quality measurement. |
| Anthropic | Pricing | https://platform.claude.com/docs/en/about-claude/pricing | Understand direct API price categories for non-Copilot workflows. |
| Anthropic | Prompt caching | https://platform.claude.com/docs/en/build-with-claude/prompt-caching | Understand cache-aware prompt design. |
| Anthropic | Token counting | https://platform.claude.com/docs/en/build-with-claude/token-counting | Estimate prompt and response size in custom workflows. |
| Anthropic | Context windows | https://platform.claude.com/docs/en/build-with-claude/context-windows | Design context floors and compaction rules. |
| Anthropic | Extended thinking | https://platform.claude.com/docs/en/build-with-claude/extended-thinking | Treat thinking/reasoning controls as task-specific. |
| Google Gemini | Pricing | https://ai.google.dev/gemini-api/docs/pricing | Understand direct Gemini API cost categories for non-Copilot workflows. |
| Google Gemini | Context caching | https://ai.google.dev/gemini-api/docs/caching | Understand cache lifecycle and repeated-context patterns. |
| Google Gemini | Token counting | https://ai.google.dev/gemini-api/docs/tokens | Estimate token use in custom Gemini workflows. |
| Google Gemini | Thinking | https://ai.google.dev/gemini-api/docs/thinking | Scope thinking budgets to task complexity. |
| Google Gemini | Batch API | https://ai.google.dev/gemini-api/docs/batch-api | Consider batch processing for offline custom workflows. |

## Workflow Guidance Map

| Question | First stop | Why |
|---|---|---|
| What is billed in Copilot? | GitHub Copilot models and pricing docs | GitHub is authoritative for AI Credits and Copilot feature behavior. |
| How should admins set controls? | Budget controls and Well-Architected AI credit management | Budget layers, overrides, and ownership decisions are operational. |
| How should developers reduce waste? | GitHub optimize AI usage guide plus [Customer Companion](CUSTOMER_COMPANION.md) | Workflow design, scoped context, and validation reduce rework. |
| How should custom agents be instrumented? | Copilot SDK OpenTelemetry and OpenTelemetry GenAI conventions | Custom harnesses need traceability before making cost claims. |
| How do provider concepts transfer? | Provider token mechanics references | Transfer concepts, not Copilot billing conclusions. |

## Verification Flags

| Item | Status | Bundle handling |
|---|---|---|
| `/chronicle cost-tips` | Not source-verified as a public/product claim | Keep out of direct product claims until release notes or docs are explicit. |
| Grafana dashboards | No direct public Copilot/Grafana setup source verified | Treat as an observability gap, not a quick hit. |
| Prompt caching savings magnitude | Product feature exists, billing impact not proved here | Describe mechanism, not savings. |
| Tool search savings magnitude | Product source exists, scenario-specific magnitude unclear | Describe scoped tool efficiency, not universal token reduction. |
| Provider API pricing | Not Copilot billing authority | Use only for direct API or general token-mechanics context. |
| Model availability claims | High-change-rate surface | Re-check supported-models docs or changelog at publication time. |
| Legal, DPA, indemnity, or preview terms | Requires exact current source and owner review | Keep out of quick-hit recommendations unless verified. |

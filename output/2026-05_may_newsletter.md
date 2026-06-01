# May 2026 GitHub Customer Newsletter

This is a personally curated newsletter for my customers, focused on the most relevant GitHub updates and resources this month. The May issue leads with the June 1 **GitHub Copilot** usage-based billing transition, then moves into cost-aware developer guidance, Copilot platform updates, governance and security items, and a short list of upcoming training and events. If you have feedback or want to dive deeper into any topic, please let me know. Feel free to share this newsletter with your team. You can find an archive of past newsletters [here](https://github.com/briancl2/CustomerNewsletter).

## Executive Summary

- **GitHub Copilot** usage-based billing starts June 1 for affected customers, with metered interactions converted into **GitHub AI Credits**.
- Admins should set user-level budgets, identify power users, configure cost-center and enterprise spending limits, assign alert owners, and review usage weekly during rollout.
- Developers should know actual model costs, the new intent detection just launched in Auto mode, and that code completions and Next Edit Suggestions consume zero AI Credits.
- **Copilot CLI** (`GA`), the **GitHub Copilot App** (`PREVIEW`), VS Code agent features, and cross-IDE updates are expanding agent workflows across more surfaces, which increases the need for consistent policy, observability, and developer guidance.

## Table of Contents

- [UBB Readiness and Cost-Aware Copilot Usage](#ubb-readiness-and-cost-aware-copilot-usage)
- [Copilot Updates](#copilot)
- [Governance, Reporting, and Security Updates](#governance-reporting-and-security-updates)
- [GitHub Platform Updates](#github-platform-updates)
- [Resources and Best Practices](#resources-and-best-practices)
- [Webinars, Events, and Recordings](#webinars-events-and-recordings)

---

# UBB Readiness and Cost-Aware Copilot Usage

**The theme this month is operating readiness.** Usage-based billing starts June 1, so the work now is budget setup, user guidance, model policy, reporting access, and a support path for teams whose agentic usage grows quickly.

New definitions: [**UBB**](https://github.blog/news-insights/company-news/github-copilot-is-moving-to-usage-based-billing/) means usage-based billing; [**AI Credits**](https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing) are GitHub's billing unit for metered Copilot usage where applicable; [**ULB**](https://docs.github.com/en/copilot/tutorials/budgets/getting-started-with-budget-controls) means user-level budget; pooled credits are included monthly AI Credits shared across licensed users in the billing entity; [additional spend](https://wellarchitected.github.com/library/governance/recommendations/managing-ai-credits/) means metered charges after included pooled credits are exhausted.

## Action Required Now: UBB Readiness

| Owner | Action | Why it matters | Source |
|---|---|---|---|
| Enterprise owner or billing manager | Set a universal [user-level budget](https://docs.github.com/en/copilot/tutorials/budgets/getting-started-with-budget-controls). | ULBs cap each user's AI Credit usage across pooled credits and additional metered usage, helping prevent a small number of users or sessions from consuming the shared pool early. | [Budget controls](https://docs.github.com/en/copilot/tutorials/budgets/getting-started-with-budget-controls) |
| Billing manager | Identify power users and define [individual overrides](https://docs.github.com/en/copilot/tutorials/budgets/getting-started-with-budget-controls). | Developers running frequent agent sessions, large-codebase work, code review, or frontier-model workflows may need a higher limit to avoid blocking productive work. | [Budget optimization](https://docs.github.com/en/copilot/tutorials/budgets/optimizing-your-budget-configuration) |
| Billing manager and cost owners | Configure [cost-center](https://wellarchitected.github.com/library/governance/recommendations/managing-ai-credits/) and [enterprise spending limits](https://docs.github.com/en/copilot/tutorials/budgets/getting-started-with-budget-controls). | These controls manage additional spend exposure after included pooled credits are exhausted, and the most restrictive applicable budget can block usage. | [Managing AI credits](https://wellarchitected.github.com/library/governance/recommendations/managing-ai-credits/) |
| Billing manager | Decide where [hard stops](https://docs.github.com/en/copilot/tutorials/budgets/getting-started-with-budget-controls) and alert recipients belong. | Spending limits without stop-usage enforcement may only alert; alert ownership determines who responds when thresholds are reached. | [Budget controls](https://docs.github.com/en/copilot/tutorials/budgets/getting-started-with-budget-controls) |
| Platform owner | Publish [developer usage guidance](https://docs.github.com/en/copilot/tutorials/optimize-ai-usage) before enforcement. | Budget controls limit runaway consumption, but efficient work comes from clearer tasks, scoped context, model-to-task matching, and validation gates. | [Optimize AI usage](https://docs.github.com/en/copilot/tutorials/optimize-ai-usage) |
| FinOps or platform owner | Review [usage exports and reports](https://github.blog/changelog/2026-05-20-copilot-usage-metrics-reports-now-use-github-owned-download-urls) weekly during rollout, then monthly once stable. | Usage exports, [team metrics](https://github.blog/changelog/2026-05-14-team-level-copilot-usage-metrics-now-available-via-api), and [CLI activity metrics](https://github.blog/changelog/2026-04-10-copilot-cli-activity-now-included-in-usage-metrics-totals-and-feature-breakdowns) help identify concentrated consumption, premium-model concentration, temporary spikes, and users blocked before completing useful work. | [April reports](https://github.blog/changelog/2026-05-12-april-reports-are-now-available-to-prepare-for-usage-based-billing) |

Related webinar recordings: [Understanding Budgets Webinar](https://www.youtube.com/watch?v=F2rJ55VVf44) | [Token Optimization Webinar](https://www.youtube.com/watch?v=0IOcPqubpMc)

## Developer Playbook: Cost-Aware Copilot Usage

- **Developer billing clarifications** -- [Code completions and Next Edit Suggestions](https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing#code-completions) are not billed in AI Credits for paid Copilot plans. UBB attention should focus on chat, agents, premium models, large-context work, repeated sessions, and [**Copilot code review**](https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing#pricing-and-usage-cost-considerations-for-copilot-code-review). Code review is a separate tracking surface because token consumption is billed in AI Credits and the agentic infrastructure consumes GitHub Actions minutes. - [Models and Pricing](https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing) | [Code Review Docs](https://docs.github.com/en/copilot/using-github-copilot/code-review/using-copilot-code-review)

- **Feature-specific token and context controls** -- [Auto model selection](https://github.blog/changelog/2026-05-20-auto-model-selection-now-routes-based-on-your-task-in-vs-code), [prompt caching](https://code.visualstudio.com/updates/v1_118#_prompt-caching-efficiency), [tool search](https://code.visualstudio.com/updates/v1_118#_tool-search-tool), [agentic search and execution tools](https://code.visualstudio.com/updates/v1_118#_new-tools-for-search-and-execution), [OpenTelemetry tracing for agent sessions](https://code.visualstudio.com/updates/v1_119#_opentelemetry-tracing-for-agent-sessions), [model details in agent responses](https://code.visualstudio.com/updates/v1_119#_show-model-details-for-copilot-cli-and-claude-agent-responses), [terminal output compression](https://code.visualstudio.com/updates/v1_121#_broader-compression-for-terminal-tool-output), [reasoning controls](https://code.visualstudio.com/updates/v1_113#_configurable-thinking-effort-in-model-picker), and [Copilot SDK OpenTelemetry](https://docs.github.com/en/copilot/how-tos/copilot-sdk/observability/opentelemetry) all help teams understand, manage, or control context and token usage. Treat those signals as engineering input before writing policy. - [Token Efficiency Notes](https://code.visualstudio.com/updates/v1_118#_improving-token-efficiency) | [Agent Observability Notes](https://code.visualstudio.com/updates/v1_119#_opentelemetry-tracing-for-agent-sessions) | [Terminal Controls Notes](https://code.visualstudio.com/updates/v1_121#_broader-compression-for-terminal-tool-output)

- **Workflow design beats blunt output limits** -- Useful agent work gets cheaper through better routes, not just shorter prompts. Start with [clear tasks and stopping conditions](https://docs.github.com/en/copilot/tutorials/optimize-ai-usage), split larger work into research, plan, implementation, and validation phases, use the smallest capable model for the phase, and keep deterministic guardrails in the loop. - [Optimize AI Usage](https://docs.github.com/en/copilot/tutorials/optimize-ai-usage) | [VS Code Harness Blog](https://code.visualstudio.com/blogs/2026/05/15/agent-harnesses-github-copilot-vscode)

- **Measure before policy** -- [Usage reports](https://github.blog/changelog/2026-05-20-copilot-usage-metrics-reports-now-use-github-owned-download-urls), [team metrics](https://github.blog/changelog/2026-05-14-team-level-copilot-usage-metrics-now-available-via-api), [CLI metrics](https://github.blog/changelog/2026-04-10-copilot-cli-activity-now-included-in-usage-metrics-totals-and-feature-breakdowns), and OpenTelemetry can all provide engineering signals. Treat metrics as engineering evidence, not invoices, durable savings proof, or model-superiority evidence. - [Copilot Usage Metrics API](https://docs.github.com/rest/copilot/copilot-usage-metrics) | [OpenTelemetry Docs](https://docs.github.com/en/copilot/how-tos/copilot-sdk/observability/opentelemetry)

> **May cost optimization bundle** -- Like February's [Co-launch](https://briancl2.github.io/CustomerNewsletter/launch/2026-02/start-here/) where I open-sourced my newsletter generation system, I used May's newsletter creation process to learn real world do's and don'ts for agentic workflow cost optimization. I packaged the evidence and source notes behind my process into a [Cost Optimization Guide](https://github.com/briancl2/CustomerNewsletter/blob/main/release_bundle/2026-05_newsletter_cost_optimization/CUSTOMER_COMPANION.md) along with a technical deep dive on exactly what changed in the workflow at [Technical Deep Dive](https://github.com/briancl2/CustomerNewsletter/blob/main/release_bundle/2026-05_newsletter_cost_optimization/NEWSLETTER_SYSTEM_RELEASE_NOTES.md)
>
> The results show about a **25-50% reduction** in actual tokens per run that translate to a **$6-12 per run cost reduction.** It shows the practical learning process behind the guidance, including the quality gates that kept the evidence honest and the things that did not work. Use it as a real world cost optimization example. Included in the release bundle are links to other first-party cost optimization guides, and release notes for enhancements to the newsletter generation system.
>
> The most humbling finding is that the cheapest or shortest prompt is rarely the cheapest workflow. Most of the savings came from making the system stop repeating work, not from asking for shorter responses. If you are a developer or otherwise responsible for AI costs, that is the lever I would reach for first

---

# Copilot

## Latest Releases

**Copilot capabilities are expanding across IDE, CLI, GitHub.com, app, and mobile surfaces.** The operational question for enterprise teams is how to keep model policy, observability, tool permissions, and user guidance consistent as agent work spreads across those surfaces.

Selected feature recordings: [GitHub Copilot App Video (5m)](https://www.youtube.com/watch?v=x4QITiQINhg) | [Copilot CLI Rubber Duck Video (5m)](https://www.youtube.com/watch?v=VgwrtU_dTUU) | [Hooks Video (20m)](https://www.youtube.com/watch?v=03CfGf9iw_U) | [Copilot CLI Build Video (5m)](https://www.youtube.com/watch?v=zS_40Tfl75w)

- **Copilot CLI operational themes** -- **Copilot CLI** is moving from terminal helper to governed agent runtime. Key themes this month are session control with [remote control (`GA`)](https://github.blog/changelog/2026-05-18-remote-control-for-copilot-cli-sessions-now-generally-available-on-mobile-web-and-vs-code) through `/remote on`, `--remote`, and [`/keep-alive`](https://github.com/github/copilot-cli/releases/tag/v1.0.36); autonomy controls with [`--mode`, `--autopilot`, and `--plan`](https://github.com/github/copilot-cli/releases/tag/v1.0.23) plus [`/autopilot`](https://github.com/github/copilot-cli/releases/tag/v1.0.45); workflow reuse with [`copilot plugin marketplace update`](https://github.com/github/copilot-cli/releases/tag/v1.0.27) and [`/skills`](https://github.com/github/copilot-cli/releases/tag/v1.0.40); policy hooks such as [HTTP hooks](https://github.com/github/copilot-cli/releases/tag/v1.0.35-0) and [`preMcpToolCall`](https://github.com/github/copilot-cli/releases/tag/v1.0.51); MCP integration through [`copilot mcp`](https://github.com/github/copilot-cli/releases/tag/v1.0.21) and [`/mcp search`](https://github.com/github/copilot-cli/releases/tag/v1.0.49-0); and history, memory, model, and cost signals through [`/chronicle search`](https://github.com/github/copilot-cli/releases/tag/v1.0.49), [`/memory show`](https://github.blog/changelog/2026-05-26-copilot-memory-has-more-controls-for-deletion-scope-and-the-copilot-cli), and [`auto` model selection](https://github.com/github/copilot-cli/releases/tag/v1.0.32). - [Copilot CLI Releases](https://github.com/github/copilot-cli/releases)

- **GitHub Copilot app (`PREVIEW`)** -- The **GitHub Copilot app** brings GitHub-native agent work into a focused desktop workflow. It starts from [GitHub context](https://github.blog/changelog/2026-05-14-github-copilot-app-is-now-available-in-technical-preview/#%f0%9f%a7%ad-start-from-github-context), keeps work in [focused sessions](https://github.blog/changelog/2026-05-14-github-copilot-app-is-now-available-in-technical-preview/#%e2%9a%a1-work-in-focused-sessions), supports review of [plans, diffs, comments, checks, pull request creation, and merge requirements](https://github.blog/changelog/2026-05-14-github-copilot-app-is-now-available-in-technical-preview/#%e2%9c%85-steer-validate-and-ship-in-one-place), provides [Agent Merge](https://github.blog/changelog/2026-05-14-github-copilot-app-is-now-available-in-technical-preview/#%e2%9c%85-steer-validate-and-ship-in-one-place) follow-through, includes [integrated terminal and browser testing](https://github.blog/changelog/2026-05-14-github-copilot-app-is-now-available-in-technical-preview/#%e2%9c%85-steer-validate-and-ship-in-one-place), and turns [skills and prompts into workflows](https://github.blog/changelog/2026-05-14-github-copilot-app-is-now-available-in-technical-preview/#%e2%9a%a1-work-in-focused-sessions). Recommended action: pilot with preview controls enabled, verify policy requirements, and share real world feedback before general availability. - [Changelog](https://github.blog/changelog/2026-05-14-github-copilot-app-is-now-available-in-technical-preview/) | [Preview Terms](https://docs.github.com/en/site-policy/github-terms/github-pre-release-license-terms)

- **Model availability updates (`GA`)** -- **GPT-5.4**, **GPT-5.5**, [**Claude Opus 4.8**](https://github.blog/changelog/2026-05-28-claude-opus-4-8-is-generally-available-for-github-copilot), **Gemini 3.5 Flash**, and **GPT-5.3-Codex** are listed as GA in current Copilot model references. Availability can still depend on plan, model policy, rollout timing, client surface, and minimum IDE or extension versions. - [GPT-5.4](https://github.blog/changelog/2026-03-05-gpt-5-4-is-generally-available-in-github-copilot) | [GPT-5.5](https://github.blog/changelog/2026-04-24-gpt-5-5-is-generally-available-for-github-copilot) | [Gemini 3.5 Flash](https://github.blog/changelog/2026-05-19-gemini-3-5-flash-is-generally-available-for-github-copilot) | [Supported Models](https://docs.github.com/en/copilot/reference/ai-models/supported-models?versionId=free-pro-team%40latest&productId=copilot#supported-ai-models-in-copilot)

- **Copilot Memory, SDK, Spaces, and observability** -- [**Copilot Memory** (`PREVIEW`)](https://github.blog/changelog/2026-05-26-copilot-memory-has-more-controls-for-deletion-scope-and-the-copilot-cli) gained controls for deletion, scope, and CLI support; **Copilot SDK** is `PREVIEW`; **Copilot Spaces API** is `GA`; and SDK [OpenTelemetry docs](https://docs.github.com/en/copilot/how-tos/copilot-sdk/observability/opentelemetry) show how instrumented SDK applications can collect traces and propagate W3C trace context. Recommended action: use GitHub usage reports and IDE/CLI telemetry first for standard usage, then add SDK/OpenTelemetry where your team owns the agent harness. - [SDK Preview](https://github.blog/changelog/2026-04-02-copilot-sdk-in-public-preview) | [Spaces API](https://github.blog/changelog/2026-05-18-copilot-spaces-api-now-generally-available)

- **Copilot on GitHub.com and pull requests** -- GitHub.com added Copilot repository exploration, pull request change requests, merge conflict help, web debugging, semantic issue search (`GA`), and agent session management from issues and projects. Recommended action: decide which collaboration surfaces are awareness-only for now and which should be included in rollout guidance. - [Explore Repository](https://github.blog/changelog/2026-03-11-explore-a-repository-using-copilot-on-the-web) | [PR Changes](https://github.blog/changelog/2026-03-24-ask-copilot-to-make-changes-to-any-pull-request) | [Merge Conflicts](https://github.blog/changelog/2026-03-26-ask-copilot-to-resolve-merge-conflicts-on-pull-requests) | [Semantic Issue Search](https://github.blog/changelog/2026-05-20-semantic-issue-search-in-copilot-chat)

**VS Code is the coordination hub for agentic development.** The recent releases clusters around agent windows, remote agents, CLI session continuity, observability, token efficiency, provider controls, sandboxing, and reusable customization.

Selected VS Code recordings: [Remote Sessions Video (5m)](https://www.youtube.com/watch?v=mUp40iig8mY) | [Chronicle Video (5m)](https://www.youtube.com/watch?v=8Mgfxj7iaK4) | [Agent Plugins Video (5m)](https://www.youtube.com/watch?v=9lonfxt7dqU)

- **VS Code agent workflow surface (`PREVIEW`)** -- The [Agents window](https://code.visualstudio.com/updates/v1_115#_visual-studio-code-agents-preview), [remote agents](https://code.visualstudio.com/updates/v1_121#_remote-agents-preview), Agent Host Protocol work, chat-session handoff, and richer session management make parallel or remote sessions trackable work instead of hidden background prompts. - [Agent Host](https://code.visualstudio.com/updates/v1_121#_agent-host-protocol) | [Session Management](https://code.visualstudio.com/updates/v1_120#_orchestrate-tasks-across-projects-with-the-agents-window-preview) | [Latest Release](https://code.visualstudio.com/updates/v1_123) | [Video (5m)](https://www.youtube.com/watch?v=DC_z7VjJCJM)

- **VS Code CLI continuity and observability** -- VS Code expanded **Copilot CLI** oversight with background agents, steering, permission levels, MCP bridging, session forking, debug logs, remote control, plan controls, terminal output compression, prompt caching, tool search, and reasoning controls. Recommended action: use these as engineering signals and guardrails to learn about cost. - [Agent Sessions](https://code.visualstudio.com/updates/v1_110#_background-agents) | [Permissions](https://code.visualstudio.com/updates/v1_111#_autopilot-and-agent-permissions) | [MCP Bridge](https://code.visualstudio.com/updates/v1_113#_mcp-support-in-copilot-cli-claude-agents) | [Session Forking](https://code.visualstudio.com/updates/v1_113#_forking-sessions-in-copilot-cli-claude-agents) | [Debug Logs](https://code.visualstudio.com/updates/v1_116#_debug-previous-agent-sessions) | [Tool Search](https://code.visualstudio.com/updates/v1_118#_tool-search-tool) | [Plan Controls](https://code.visualstudio.com/updates/v1_120#_plan-mode-control-for-claude-and-copilot-cli) | [Reasoning Controls](https://code.visualstudio.com/updates/v1_116#_configure-thinking-effort-in-copilot-cli) | [Skills Context](https://code.visualstudio.com/updates/v1_118#_dedicated-context-for-skills-experimental)

- **Provider choice, sandboxing, and customization controls** -- [BYOK for Copilot Business and Enterprise in VS Code](https://code.visualstudio.com/updates/v1_117#_bring-your-own-key-for-copilot-business-and-enterprise), provider-grouped model picker, terminal sandboxing, local MCP server sandboxing, network-domain group policy, approved-account policy, sensitive terminal prompt handling, command risk assessment, agent plugins, and customization diagnostics give platform teams clearer workspace, network, provider, and instruction boundaries. - [Policy Controls](https://code.visualstudio.com/updates/v1_114#_group-policy-to-disable-claude-agent) | [Security Prompts](https://code.visualstudio.com/updates/v1_121#_sensitive-terminal-prompts-stay-in-the-terminal)

## IDE Parity

Agent capability rollouts are increasingly feature-centric rather than IDE-centric. The practical customer action is to verify minimum versions and policy requirements before promising parity to teams.

- **VS Code** -- Still the broadest coordination surface for agent workflows, with Agents window (`PREVIEW`), remote agents (`PREVIEW`), session management, MCP bridging, debugging, OpenTelemetry, BYOK, sandboxing, tool search, and customization controls. - [VS Code Updates](https://code.visualstudio.com/updates) | [Latest Release Notes](https://code.visualstudio.com/updates/v1_123)

- **Visual Studio** -- Continues custom agents, skills, cloud sessions, debugger/profiling/testing agents, and modernization agents, especially for .NET, C++, and enterprise Visual Studio teams. - [Visual Studio Release Notes](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes)

- **JetBrains IDEs** -- Adds custom agents (`GA`), subagents (`GA`), Plan agent (`GA`), agent skills/hooks/prompt files (`GA`), auto model selection (`GA`), inline agent mode, Copilot CLI agent, unified sessions, MCP allowlist controls, and global instruction file support. - [JetBrains Plugin](https://plugins.jetbrains.com/plugin/17718-github-copilot--your-ai-pair-programmer/versions)

- **Xcode** -- Includes BYOK (`GA`), custom agents (`GA`), Auto model selection (`GA`), reasoning controls, context-window token breakdowns, and Auto Compress for Apple-platform teams. - [Xcode Releases](https://github.com/github/CopilotForXcode/blob/main/CHANGELOG.md)

- **Eclipse** -- The Copilot for Eclipse plugin is now open source and includes chat, agent mode, skills, prompt files, BYOK, custom agents, isolated subagents, Plan agent, and MCP integration. - [Eclipse Marketplace](https://marketplace.eclipse.org/content/github-copilot)

> Note: **Copilot** features often start in **VS Code**, then roll out across **Visual Studio** and **JetBrains IDEs**, followed by **Eclipse** and **Xcode**. Labels, policies, and minimum versions can vary by client.

Stay current with the latest changes: [Copilot Feature Matrix](https://docs.github.com/en/copilot/reference/copilot-feature-matrix?tool=ides) | [GitHub Copilot Changelog](https://github.blog/changelog/label/copilot/feed/) | [VS Code Release Notes](https://code.visualstudio.com/updates) | [Visual Studio Release Notes](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes) | [JetBrains Plugin](https://plugins.jetbrains.com/plugin/17718-github-copilot--your-ai-pair-programmer/versions) | [Xcode Releases](https://github.com/github/CopilotForXcode/blob/main/CHANGELOG.md) | [Eclipse Marketplace](https://marketplace.eclipse.org/content/github-copilot) | [Copilot CLI Releases](https://github.com/github/copilot-cli/releases) | [GitHub Previews](https://github.com/features/preview) | [Preview Terms Changelog](https://docs.github.com/en/site-policy/github-terms/github-pre-release-license-terms)

---

# Governance, Reporting, and Security Updates

- **Copilot governance, metrics, and auditability** -- Plan-mode metrics, CLI activity, team-level API access, GitHub-owned report URLs, AI adoption cohorts, and cloud-agent configuration audit APIs (`PREVIEW`) can give admins a practical evidence layer for rollout, compliance reporting, and UBB readiness. - [Plan Mode Metrics](https://github.blog/changelog/2026-03-02-copilot-metrics-now-includes-plan-mode) | [CLI Metrics](https://github.blog/changelog/2026-04-10-copilot-cli-activity-now-included-in-usage-metrics-totals-and-feature-breakdowns) | [Team Metrics](https://github.blog/changelog/2026-05-14-team-level-copilot-usage-metrics-now-available-via-api) | [Report URLs](https://github.blog/changelog/2026-05-20-copilot-usage-metrics-reports-now-use-github-owned-download-urls) | [Audit API](https://github.blog/changelog/2026-05-18-audit-repository-copilot-cloud-agent-configuration-via-the-rest-api)

- **Copilot cloud agent controls** -- Organization runner controls, firewall settings, custom property enablement, custom images, faster validation tools, REST task start APIs (`PREVIEW`), and more flexible secrets/variables make cloud-agent rollout more governable. Recommended action: decide where cloud agents can run, which networks they can reach, and which repositories can enable them. - [Runner Controls](https://github.blog/changelog/2026-04-03-organization-runner-controls-for-copilot-cloud-agent) | [Firewall Settings](https://github.blog/changelog/2026-04-03-organization-firewall-settings-for-copilot-cloud-agent) | [Custom Properties](https://github.blog/changelog/2026-04-15-enable-copilot-cloud-agent-via-custom-properties) | [REST API](https://github.blog/changelog/2026-05-13-start-copilot-cloud-agent-tasks-via-the-rest-api) | [Secrets](https://github.blog/changelog/2026-05-08-more-flexible-secrets-and-variables-for-copilot-cloud-agent)

- **GitHub Enterprise Server signing key rotation** -- GHES administrators need to rotate GPG public keys using GitHub's provided script before installing future patches and releases signed with the new key. No action is required for GitHub Enterprise Cloud. Recommended action: review the rotation instructions and schedule this with your GHES maintenance owners. - [GitHub Blog](https://github.blog/security/investigating-unauthorized-access-to-githubs-internal-repositories/)

- **MCP security, code-to-cloud visibility, and GHAS budgets** -- Secret scanning through **GitHub MCP Server** is `GA`, dependency scanning through MCP is `PREVIEW`, **Microsoft Defender for Cloud** code-to-cloud risk visibility is `GA`, the [Code Security Risk Assessment](https://github.blog/changelog/2026-04-08-code-security-risk-assessment-available-for-organizations) gives organization admins a no-cost CodeQL scan of active repositories, and GHAS [hard budget limits](https://github.blog/changelog/2026-05-28-hard-budget-limits-now-available-for-github-advanced-security) add enforceable license caps and cost-center controls for security spend. - [Secret Scanning MCP](https://github.blog/changelog/2026-05-05-secret-scanning-with-github-mcp-server-is-now-generally-available) | [Dependency Scanning MCP](https://github.blog/changelog/2026-05-05-dependency-scanning-with-github-mcp-server-is-in-public-preview) | [Defender](https://github.blog/changelog/2026-05-05-code-to-cloud-risk-visibility-with-microsoft-defender-for-cloud-is-now-generally-available) | [GHAS Trial](https://github.blog/changelog/2026-05-19-start-a-github-advanced-security-trial-from-a-risk-assessment)

- **Deprecations and Migration Notices** -- Plan once for older Copilot model retirements, Grok Code Fast 1 retirement, Python 3.9 for Dependabot, synchronous SBOM API deprecation, `code_scanning_upload` rate limit API removal, and the upcoming GitHub App installation token format change. - [Supported Models](https://docs.github.com/en/copilot/reference/ai-models/supported-models?versionId=free-pro-team%40latest&productId=copilot#model-retirement-history) | [Dependabot Python](https://github.blog/changelog/2026-05-19-upcoming-deprecation-of-python-3-9-for-dependabot) | [SBOM API](https://github.blog/changelog/2026-05-12-synchronous-sbom-api-deprecated) | [Rate Limit API](https://github.blog/changelog/2026-05-19-removal-of-code_scanning_upload-field-from-rate_limit-api-endpoint) | [App Tokens](https://github.blog/changelog/2026-04-24-notice-about-upcoming-new-format-for-github-app-installation-tokens)

---

# GitHub Platform Updates

- **GitHub Code Quality and code coverage (`PREVIEW`)** -- [**GitHub Code Quality**](https://github.blog/changelog/2026-04-14-github-code-quality-improvements-to-standard-findings-in-public-preview) standard findings, the [repository enablement API](https://github.blog/changelog/2026-05-26-github-code-quality-repository-enablement-api), and [code coverage on pull requests](https://github.blog/changelog/2026-05-26-code-coverage-in-pull-requests-is-now-in-public-preview) are in `PREVIEW`. Customer action: awareness now, pilot where code-quality gates are already part of PR policy.

- **Enterprise administration, supply chain, and Actions updates** -- Platform updates include EU data residency expansion to EFTA, [enterprise installation APIs](https://github.blog/changelog/2026-05-13-new-enterprise-installation-api-now-in-public-preview) (`PREVIEW`), [Enterprise Live Migrations](https://github.blog/changelog/2026-05-07-enterprise-live-migrations-is-now-in-public-preview) (`PREVIEW`), commit-comment controls, [repository ruleset improvements](https://github.blog/changelog/2026-05-07-repository-rulesets-user-bypass-and-branch-renaming), [npm staged publishing](https://github.blog/changelog/2026-05-22-staged-publishing-and-new-install-time-controls-for-npm) (`GA`) and install-time controls, [expanded OIDC](https://github.blog/changelog/2026-05-19-expanded-oidc-support-for-dependabot-and-code-scanning) (`GA` on github.com; GHES 3.22 planned), org-level private registries, [async SBOM exports](https://github.blog/changelog/2026-04-14-sbom-exports-are-now-computed-asynchronously), and [custom images for GitHub-hosted runners](https://github.blog/changelog/2026-03-26-custom-images-for-github-hosted-runners-are-now-generally-available) (`GA`). - [EU Data Residency](https://github.blog/changelog/2026-03-31-eu-data-residency-region-expanding-to-include-efta-countries) | [Private Registries](https://github.blog/changelog/2026-04-14-dependabot-and-code-scanning-org-level-private-registries)

---

# Resources and Best Practices

- **Agent harness and evaluation thinking** -- The VS Code harness blog explains why agent quality depends on context assembly, tool exposure, loop control, provider-specific harness behavior, and product-specific evaluation, not the model alone. - [VS Code Harness Blog](https://code.visualstudio.com/blogs/2026/05/15/agent-harnesses-github-copilot-vscode)

- **Security incident response reference** -- GitHub Docs now has a security incident response reference for investigation tools and common incident investigation areas across GitHub. - [Docs](https://docs.github.com/en/code-security/reference/security-incident-response)

- **GitHub Certified: Agentic AI Developer** -- The GH-600 beta exam focuses on operating AI agents safely: tool permissions, environments, memory/state, evaluation, multi-agent workflows, guardrails, and human-in-the-loop systems. - [Microsoft Tech Community](https://techcommunity.microsoft.com/blog/skills-hub-blog/new-github-certified-agentic-ai-developer/4517571)

---

# Webinars, Events, and Recordings

- [GitHub Copilot YouTube playlist](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D)
- [GitHub Advanced Security playlist](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ3wk4atKpN-yOW1FtyxN48W)

## Recommended

- Budget controls webinar recording: for admins, billing managers, and FinOps partners. - [Watch](https://www.youtube.com/watch?v=F2rJ55VVf44)
- Token optimization webinar recording: for platform teams and developer leads. - [Watch](https://www.youtube.com/watch?v=0IOcPqubpMc)
- GitHub Certified: Agentic AI Developer resources: for enablement leads planning agent training. - [Resources](https://techcommunity.microsoft.com/blog/skills-hub-blog/new-github-certified-agentic-ai-developer/4517571)

## Microsoft Build 2026: GitHub and Copilot Session Guide

Microsoft Build runs June 2-3 in San Francisco and online. The GitHub-filtered online catalog has a large set of sessions; these are the most relevant for Copilot, GitHub platform, agent workflows, and enterprise rollout.

| Date | Time (CT) | Session | Categories |
|---|---|---|---|
| Jun 2 | 4:30 PM - 5:15 PM | [Your agent, anywhere: MultiClient, MultiDevice with GitHub Copilot SDK](https://build.microsoft.com/en-US/sessions/BRK206?source=sessions) | Copilot, Developer Experience |
| Jun 2 | 5:45 PM - 6:30 PM | [From prototype to production: build and run agents at scale](https://build.microsoft.com/en-US/sessions/BRK241?source=sessions) | Developer Experience, Enterprise |
| Jun 3 | 11:00 AM - 11:45 AM | [From CLI to PR: Automating the path to merged code](https://build.microsoft.com/en-US/sessions/BRK203?source=sessions) | Copilot, Developer Experience |
| Jun 3 | 2:30 PM - 2:45 PM | [From issue to merge in one loop: the GitHub Copilot app](https://build.microsoft.com/en-US/sessions/LIVE162?source=sessions) | Copilot, Developer Experience |
| Jun 3 | 6:00 PM - 6:45 PM | [GitHub Copilot in Visual Studio: Agents That Debug, Profile, and Test](https://build.microsoft.com/en-US/sessions/BRK207?source=sessions) | Copilot, Developer Experience |

The [full GitHub online session catalog](https://build.microsoft.com/en-US/sessions?search=github&sortBy=relevance&filter=deliveryTypes%2FlogicalValue%3EOnline) also includes digital labs for GitHub Actions supply chain risk, Copilot custom tools/context/workflows, Copilot CLI live coding, and agent deployment on Azure.

## Virtual Events

| Date | Event | Categories |
|---|---|---|
| Jun 5 | [GitHub Copilot Webinar: Agent Quality & Token Optimisation](https://github.registration.goldcast.io/webinar/0cc0d88d-52ea-4837-9fce-1da721aea31b) | Copilot, Developer Experience |
| Jun 12 | [DevOps Foundations for the AI Agentic Era](https://developer.microsoft.com/en-us/reactor/events/27135/) | Developer Experience |
| Jun 18 | [GitHub Q2 Roadmap Webinar](https://github.registration.goldcast.io/webinar/1dd0b7b0-5d4e-4c83-b231-24a4eef1675a?utm_source=gh_web_banner&utm_medium=web&utm_campaign=AMER+Q2+Roadmap+Webinar) | Copilot, Enterprise |
| Jun 24 | [Copilot in action: Best practices and use cases for teams](https://github.registration.goldcast.io/events/5b2f44cc-7eac-45de-898f-d1cf546c420c) | Copilot, Developer Experience |

## Training and In-Person Events

| Date | Event | Categories |
|---|---|---|
| Jun 2-3 | [Microsoft Build 2026](https://build.microsoft.com/en-US/home), San Francisco and online | Copilot, GitHub Platform |
| Jun 1 | [GitHub Social Club at Microsoft Build](https://gh.io/socialclubsf0601), San Francisco | GitHub Community |
| Jun 3 | [OpenClaw: After Hours at GitHub](https://luma.com/OpenClaw-GitHub?tk=vQX2NH), GitHub HQ | Developer Experience |
| Jun 4 | [Beyond Build: AI Developer Day](https://learn.github.com/event/79c47245-f2ef-441d-a1e6-84a3ad105a72), GitHub HQ | Developer Experience |
| Jun 8-12 | [Microsoft AI Skills Fest](https://learn.github.com/event/d164f5ba-23e1-4545-84fd-b830eb25b56f) | Developer Experience |


## Official Microsoft Learn Training (Free)

Official instructor-led video courses from **Microsoft Learn**, available free on YouTube. These are useful for structured team onboarding, certification preparation, and self-paced upskilling.

| Course | Episodes | Total Length | Level | Playlist |
|---|---|---|---|---|
| **GH-900: GitHub Foundations** | Course preview + 9 episodes: Version Control (44m), GitHub (45m), GitHub Products (21m), Open Source (32m), Markdown (21m), Projects (23m), Codespaces (21m), Security (42m), Copilot (31m) | ~4h 41m | Beginner | [Watch](https://www.youtube.com/watch?v=GKS32EgbzUc&list=PLahhVEj9XNTf5iQVK_80RdvTju7ov6RYy) |
| **GH-300: GitHub Copilot** | Course preview + 5 episodes: Introduction (41m), Exploring Features (1h15m), Generative AI Use Cases (42m), Writing Unit Tests (20m), Advanced Features (59m) | ~3h 57m | Intermediate | [Watch](https://www.youtube.com/watch?v=_HBCwxJmq7Y&list=PLahhVEj9XNTd8lE7clFGR1el35zaBmJbS) |
| **AZ-2007: Accelerate app development by using GitHub Copilot** | 5 episodes: Get Started (30m), Documentation (42m), Code Features (49m), Unit Tests (35m), Code Improvements (42m) | ~3h 17m | Intermediate | [Watch](https://www.youtube.com/watch?v=7FDrdrGQ1Oc&list=PLahhVEj9XNTddVUvFqAzXd2tKR1TLOjCd) |
| **GH-500: GitHub Advanced Security** | Course preview + 5 episodes: Introduction to GHAS (36m), Sensitive Data and Security Policies (40m), Dependabot Security Updates (28m), Secret Scanning (12m), Code Scanning (39m) | ~2h 35m | Intermediate | [Watch](https://www.youtube.com/watch?v=ikneq7kZIDw&list=PLahhVEj9XNTcJZjBU671JAiX8St3CV5dA) |
| **GH-200: Automate your workflow with GitHub Actions** | 5 episodes: Course Introduction (5m), Intro to Actions (48m), Pipelines in Actions (1h7m), Extending Workflows (55m), Org and Enterprise Config (44m) | ~3h 39m | Beginner | [Watch](https://www.youtube.com/watch?v=8m9JBtGFMp8&list=PLahhVEj9XNTd5N_seZDoRXVIn6N1qAp-_) |
| **AZ-2008: DevOps Foundations: The Core Principles and Practices** | 6 episodes: Core Principles (3m), Discover DevOps (12m), Plan (20m), Develop (25m), Deliver (20m), Operate (24m) | ~1h 44m | Beginner | [Watch](https://www.youtube.com/watch?v=Vfz6WtUK6B0&list=PLahhVEj9XNTfLw9oLP-XeTUvw3IknTRwk) |


---

# Closing

If you have any questions or want to discuss these updates in detail, feel free to reach out. As always, I'm here to help you and your team stay informed and get the most value from GitHub. I welcome your feedback, and please let me know if you would like to add or remove anyone from this list.

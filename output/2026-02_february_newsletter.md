# February 2026 Newsletter

This is a personally curated newsletter for my customers, focused on the most relevant GitHub updates this month. Highlights include third-party agents (Claude and Codex) arriving on Agent HQ, VS Code evolving into a multi-agent orchestration platform with Agent Skills reaching GA and parallel subagents, a massive model availability expansion with GPT-5.1/5.2/5.3 and Claude Opus 4.5/4.6 all reaching GA, and the Copilot CLI shipping at breakneck velocity with plan mode, code review, memory, and an SDK for embedding Copilot into any application. If you have feedback or want to dive deeper into any topic, please let me know. Feel free to share this newsletter with your team. You can find an archive of past newsletters [here](https://github.com/briancl2/CustomerNewsletter).

---

# Co-Launch: Open-Sourcing the Newsletter Generation System

This month's issue is being released alongside the system that drafted it.

The February newsletter was generated from a single prompt and a few minor editorial edits:

```text
i want you to generate a from-scratch brand new february newsletter using the dates Dec 5 2025 to Feb 13 2026
```

If you want to reuse the workflow:

- [Start here](https://briancl2.github.io/CustomerNewsletter/launch/2026-02/start-here/)
- [Short case study](https://briancl2.github.io/CustomerNewsletter/launch/2026-02/case-study/)
- [Timeline](https://briancl2.github.io/CustomerNewsletter/launch/2026-02/timeline/)
- [Full technical report](https://briancl2.github.io/CustomerNewsletter/reports/newsletter_system_report_2026-02/)

---

# Copilot Everywhere: More Agents, More Models, More Surfaces, One Platform

**The theme this period is choice.** Use more agents, with more models, from more surfaces, all powered by one Copilot subscription. That means one set of terms protecting your data, one payment, one platform to manage users, set budgets, and govern policies.

-   **Third-Party Agents on Agent HQ (`PREVIEW`)** -- Claude by Anthropic and OpenAI Codex are now available in public preview directly on GitHub and VS Code. Enterprise subscribers can choose between GitHub's own Coding Agent, Claude, or Codex, selecting the best tool for each task. No additional cost, existing terms apply, consuming the same premium request units (PRUs). - [Changelog](https://github.blog/changelog/2026-02-04-claude-and-codex-are-now-available-in-public-preview-on-github) | [GitHub Blog](https://github.blog/news-insights/company-news/pick-your-agent-use-claude-and-codex-on-agent-hq/)

-   **Copilot + OpenCode** -- GitHub announced an official partnership with OpenCode so that existing Copilot subscribers can use their license in OpenCode, a leading open-source CLI coding agent competitive with Claude Code and Codex CLI. No additional configuration required, existing subscription covers it. - [Changelog](https://github.blog/changelog/2026-01-16-github-copilot-now-supports-opencode)

-   **Copilot CLI and SDK (`PREVIEW`)** -- The Copilot CLI is shipping daily releases at remarkable velocity (v0.0.399–v0.0.408 this period alone). Major capabilities this period: [Plan mode](https://github.blog/changelog/2026-01-21-github-copilot-cli-plan-before-you-build-steer-as-you-go) for structured task planning with clarifying questions before code is written; [/review](https://github.blog/changelog/2026-01-21-github-copilot-cli-plan-before-you-build-steer-as-you-go) for code review in the terminal; [repository memory](https://github.blog/changelog/2026-01-21-github-copilot-cli-plan-before-you-build-steer-as-you-go) across sessions; [ACP protocol support](https://github.blog/changelog/2026-01-28-acp-support-in-copilot-cli-is-now-in-public-preview) for programmatic agent orchestration via stdio or TCP; [background agents and `/delegate`](https://github.com/github/copilot-cli/releases/tag/v0.0.404) now enabled for all users (prefix any prompt with `&` to send work to the cloud coding agent); a growing [plugin and marketplace ecosystem](https://github.com/github/copilot-cli/releases/tag/v0.0.406) where plugins translate into skills and can bundle LSP servers and hooks; [autopilot mode](https://github.com/github/copilot-cli/releases/tag/v0.0.400) for autonomous task completion; workspace-local MCP configuration via `.vscode/mcp.json`; `/instructions` command to view and toggle custom instruction files; `/diff` to review session changes with undo/rewind; auto-compaction at 95% token limit for virtually infinite sessions; and [direct installation from gh](https://github.blog/changelog/2026-01-21-install-and-use-github-copilot-cli-directly-from-the-github-cli). The new [Copilot SDK](https://github.blog/changelog/2026-01-14-copilot-sdk-in-technical-preview) (technical preview) provides language-specific libraries for Node.js/TypeScript, Python, Go, and .NET, enabling platform teams to [embed Copilot capabilities into any application](https://github.blog/news-insights/company-news/build-an-agent-into-any-app-with-the-github-copilot-sdk/). Note: Copilot CLI is covered under the [GitHub Data Protection Agreement](https://docs.github.com/en/site-policy/github-terms/github-dpa-previews) and [Pre-Release License Terms (indemnity)](https://docs.github.com/en/site-policy/github-terms/github-pre-release-license-terms) while in preview. See also: [CLI Releases](https://github.com/github/copilot-cli/releases) | [CLI Slash Commands Cheat Sheet](https://github.blog/ai-and-ml/github-copilot/a-cheat-sheet-to-slash-commands-in-github-copilot-cli/) | [Agentic Terminal Workflows](https://github.blog/ai-and-ml/github-copilot/power-agentic-workflows-in-your-terminal-with-github-copilot-cli/) | [Maximize Agentic Capabilities](https://github.blog/ai-and-ml/github-copilot/how-to-maximize-github-copilots-agentic-capabilities/) | [SDK Video (45m)](https://www.youtube.com/watch?v=LO7nf-dbURE)

-   **BYOK Enhancements (`PREVIEW`)** -- Bring your own AI provider keys into GitHub. BYOK now supports additional providers (AWS Bedrock, Google AI Studio, and any OpenAI-compatible provider join Anthropic, Microsoft Foundry, OpenAI, and xAI), Responses API support, configurable maximum context windows, and streaming responses. Usage billed directly by your provider. Organizations in regulated industries can maintain data sovereignty and leverage existing LLM contracts while using Copilot's full feature set. - [Changelog](https://github.blog/changelog/2026-01-15-github-copilot-bring-your-own-key-byok-enhancements)

---

# Copilot

## Latest Releases

**VS Code has evolved into a multi-agent development hub**, with Agent Skills reaching general availability (now invokable as slash commands), agent hooks for deterministic lifecycle enforcement, parallel subagents for faster complex tasks, message steering to redirect agents mid-task, a cross-agent memory system, and deep agent session management that lets you delegate work across local, background, and cloud environments.

-   **Copilot Code Review (`GA`)** -- Organization members can now use Copilot code review on pull requests even without a Copilot license, expanding adoption across the entire team. Copilot code review preview features are also now supported in [GHEC with data residency](https://github.blog/changelog/2025-12-18-copilot-code-review-preview-features-now-supported-in-github-enterprise-cloud-with-data-residency). Code Review drives PRU adoption and is one of the highest-value Copilot features for engineering leadership. - [Changelog](https://github.blog/changelog/2025-12-17-copilot-code-review-now-available-for-organization-members-without-a-license) | [Docs](https://docs.github.com/en/copilot/using-github-copilot/code-review/using-copilot-code-review)

-   **Agent Skills (`GA`)** -- Agent Skills are now generally available and enabled by default in VS Code. GitHub has adopted the industry open standard from [agentskills.io](https://agentskills.io/home), and VS Code recognizes skills from multiple tools (`.github/skills`, `.claude/skills`, `~/.copilot/skills`). Skills are now also available as [slash commands](https://code.visualstudio.com/updates/v1_109#_use-skills-as-slash-commands), type `/` in chat to invoke any skill or prompt file on demand, with new `user-invokable` and `disable-model-invocation` frontmatter controls. Extensions can distribute skills via the new `chatSkills` contribution point. New [Agent Hooks](https://code.visualstudio.com/updates/v1_109#_agent-hooks-preview) (`PREVIEW`) let you run custom shell commands at 8 key agent lifecycle points (PreToolUse, PostToolUse, SessionStart, Stop, SubagentStart, SubagentStop), enabling deterministic security policy enforcement, audit trails, and code quality gates. Hooks use the same format as Claude Code and Copilot CLI, so existing configurations work cross-tool. Organization-wide custom instructions ensure consistent AI guidance across teams. - [Changelog](https://github.blog/changelog/2025-12-18-github-copilot-now-supports-agent-skills) | [Release Notes](https://code.visualstudio.com/updates/v1_109#_agent-skills-are-generally-available) | [Skills Docs](https://code.visualstudio.com/docs/copilot/customization/agent-skills) | [Hooks Docs](https://code.visualstudio.com/docs/copilot/customization/hooks) | [Org Instructions](https://code.visualstudio.com/updates/v1_109#_organization-wide-instructions) | [Video (1m)](https://www.youtube.com/shorts/qoSd1yHYdGY)

-   **Parallel Subagents** -- Subagents run in parallel with dedicated context windows, significantly speeding up complex tasks. Each subagent operates autonomously and returns only a summary to the main agent, reducing token usage. A new search subagent handles iterative query refinement independently. Custom agents can restrict which subagents they invoke using the `agents` frontmatter property. - [Release Notes](https://code.visualstudio.com/updates/v1_109#_subagents) | [Docs](https://code.visualstudio.com/docs/copilot/agents/subagents) | [Video (25m)](https://www.youtube.com/watch?v=GMAoTeD9siU)

-   **Agentic Memory (`PREVIEW`)** -- A cross-agent memory system lets Copilot learn and improve across your development workflow, spanning coding agent, CLI, and code review. Memory persists across sessions, so the AI remembers your preferences and project conventions without repeated context. - [Changelog](https://github.blog/changelog/2026-01-15-agentic-memory-for-github-copilot-is-in-public-preview) | [GitHub Blog](https://github.blog/ai-and-ml/github-copilot/building-an-agentic-memory-system-for-github-copilot/) | [VS Code Setup](https://code.visualstudio.com/updates/v1_109#_copilot-memory-preview) | [Memory Docs](https://docs.github.com/en/copilot/concepts/agents/copilot-memory)

-   **Multi-Agent Management** -- Across VS Code and github.com, a unified agent management experience is taking shape. In VS Code, five distinct agent types are available from a new session picker: local agents, cloud agents, background agents, the new [Claude Agent](https://code.visualstudio.com/updates/v1_109#_claude-agent-preview) (`PREVIEW`) using Anthropic's official SDK, and partner agents (Claude, Codex). Hand off sessions between environments, track progress with the [agent status indicator](https://code.visualstudio.com/updates/v1_109#_agent-session-management), and keep working while agents handle tasks in parallel. [Background agents](https://code.visualstudio.com/updates/v1_109#_background-agents) run in isolated [Git worktrees](https://code.visualstudio.com/updates/v1_107#_isolate-background-agents-with-git-worktrees) to prevent conflicts. VS Code now reads [Claude configuration files](https://code.visualstudio.com/updates/v1_109#_claude-compatibility) directly (CLAUDE.md, .claude/agents, .claude/skills, hooks), so teams using both VS Code and Claude maintain a single set of config files with no duplication. On github.com, a new [Agents tab](https://github.blog/changelog/2026-01-26-introducing-the-agents-tab-in-your-repository) (`GA`) in repositories provides a central location for discovering and managing repository-scoped agents with redesigned session logs. - [Video (4m)](https://www.youtube.com/watch?v=BsAHunfVwNs)

-   **GitHub Agentic Workflows (`PREVIEW`)** -- [GitHub Agentic Workflows](https://github.blog/changelog/2026-02-13-github-agentic-workflows-are-now-in-technical-preview/) let you write GitHub Actions automation in plain [Markdown instead of YAML](https://github.blog/ai-and-ml/automate-repository-tasks-with-github-agentic-workflows/), and let AI agents handle intelligent decision-making for issue triage, pull request reviews, CI failure analysis, and repository maintenance. Workflows run with read-only permissions by default, sandboxed execution, network isolation, and SHA-pinned dependencies. Works with GitHub Copilot CLI (default) or other AI coding agents. The [gh-aw framework](https://github.com/github/gh-aw) is fully open source under MIT license and includes [Peli's Agent Factory](https://github.github.io/gh-aw/blog/2026-01-12-welcome-to-pelis-agent-factory/) with 50+ operational [workflow examples](https://github.github.io/gh-aw/blog/2026-01-13-meet-the-workflows-continuous-improvement/) for continuous improvement, security analysis, and repository maintenance at enterprise scale. Platform teams can use GH-AW to move from ad-hoc agent usage to governed, reproducible agentic pipelines. Install the `gh aw` CLI extension, create a Markdown file, compile, and commit. A collaboration among GitHub Next, Microsoft Research, and Azure Core Upstream. - [Documentation](https://github.github.io/gh-aw/) | [Video (1m)](https://www.youtube.com/watch?v=3_i03fGXs9U)

-   **Message Steering and Queueing (`PREVIEW`)** -- Send follow-up messages while an agent request is still running, without waiting for the current task to finish. Three modes are available: **Queue** (waits and sends after the current response completes), **Steer** (signals the current request to yield, then processes your message immediately, useful for redirecting the agent mid-task), and **Stop and Send** (cancels and starts fresh). Queued messages can be reordered via drag-and-drop. This is a significant workflow improvement for long-running agentic tasks where you spot issues or think of the next step before the agent finishes. - [Release Notes](https://code.visualstudio.com/updates/v1_109#_message-steering-and-queueing-experimental) | [Docs](https://code.visualstudio.com/docs/copilot/chat/chat-sessions#_send-messages-while-a-request-is-running)

-   **MCP Ecosystem Expansion** -- VS Code supports [MCP Apps](https://code.visualstudio.com/updates/v1_109#_support-for-mcp-apps) for rich interactive UI in chat, custom registry base URLs for private registries (Azure DevOps feeds, custom PyPI), the [built-in GitHub MCP Server](https://code.visualstudio.com/updates/v1_107#_github-mcp-server-provided-by-github-copilot-chat-preview) (`PREVIEW`) with [Projects tools and OAuth scope filtering](https://github.blog/changelog/2026-01-28-github-mcp-server-new-projects-tools-oauth-scope-filtering-and-new-features), and support for the latest MCP specification (2025-11-25) including URL mode elicitation and long-running tasks. - [Video (60m)](https://www.youtube.com/watch?v=HWmC3T5Wwqw)

-   **Auto Model Selection (`GA`)** -- Copilot can now automatically select the best model for each task, routing to the optimal model based on performance and availability. Available across all major IDEs. Copilot Business and Enterprise subscribers get a 10% discount on the model multiplier when using Auto. - [Changelog](https://github.blog/changelog/2025-12-10-auto-model-selection-is-generally-available-in-github-copilot-in-visual-studio-code)

-   **Model Availability Updates** -- GPT-5.3-Codex (`GA`), GPT-5.2 (`GA`), GPT-5.1 (`GA`), GPT-5.1-Codex (`GA`), GPT-5.1-Codex-Max (`GA`), Claude Opus 4.5 (`GA`), Claude Opus 4.6 (`GA`), Claude Opus 4.6 Fast (`PREVIEW`), Gemini 3 Flash (`PREVIEW`). GPT-5.2-Codex and Gemini 3 Flash extended to Visual Studio, JetBrains, Xcode, and Eclipse. - [GPT-5.3 Codex](https://github.blog/changelog/2026-02-09-gpt-5-3-codex-is-now-generally-available-for-github-copilot) | [Claude Opus 4.6](https://github.blog/changelog/2026-02-05-claude-opus-4-6-is-now-generally-available-for-github-copilot) | [GPT-5.1](https://github.blog/changelog/2025-12-17-gpt-5-1-and-gpt-5-1-codex-are-now-generally-available-in-github-copilot) | [Claude Opus 4.5](https://github.blog/changelog/2025-12-18-claude-opus-4-5-is-now-generally-available-in-github-copilot)

-   **C++ Code Editing Tools (`PREVIEW`)** -- Copilot gains specialized code editing tools for C++ projects, improving the agent's ability to navigate and edit C++ codebases. - [Changelog](https://github.blog/changelog/2025-12-16-c-code-editing-tools-for-github-copilot-in-public-preview)

-   **Terminal Sandboxing and Auto-Approve (`PREVIEW`)** -- Experimental terminal sandboxing (macOS/Linux) restricts agent-executed commands to the workspace directory with configurable network access rules. Expanded terminal auto-approve rules now cover `git ls-files`, `rg`, `sed`, npm/pnpm/yarn scripts, Docker, and common safe commands. - [Sandboxing](https://code.visualstudio.com/updates/v1_109#_terminal-sandboxing-experimental) | [Auto-Approve Rules](https://code.visualstudio.com/updates/v1_108#_terminal-tool-auto-approve-default-rules)

### Improved IDE Feature Parity

-   **Visual Studio -- January Update** -- Colorized code completions with syntax highlighting (`GA`), click-to-partially-accept suggestions (`GA`), HTML-rich copy paste (`GA`), syntactic line compression (`GA`), streamlined Markdown preview with Mermaid diagram support (`GA`), and Auto Model Selection (`GA`). - [Changelog](https://github.blog/changelog/2026-02-04-github-copilot-in-visual-studio-january-update) | [Visual Studio Blog](https://devblogs.microsoft.com/visualstudio/visual-studio-january-update-enhanced-editor-experience/) | [Release Notes](https://learn.microsoft.com/visualstudio/releases/2026/release-notes)

-   **JetBrains IDEs** -- Gains Custom Agents (`PREVIEW`), Isolated Subagents (`PREVIEW`), Plan Agent (`PREVIEW`), Dynamic OAuth (`PREVIEW`), Auto Model Selection (`PREVIEW`), MCP server management (`PREVIEW`), global instruction/prompt file support (`PREVIEW`), MCP Registry with browse, install, and uninstall (`PREVIEW`), MCP Allowlist controls for admins (`PREVIEW`), CVE Remediator subagent (`PREVIEW`), Agent Skills (`PREVIEW`), and GPT-5.1 (`GA`), GPT-5.2-Codex (`GA`), Gemini 3 Flash (`PREVIEW`), Gemini 3 Pro (`GA`) model support. Note: Most advanced agent features require enabling the "Editor preview features" and "Copilot coding agent" policies. - [JetBrains Plugin Versions](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable)

-   **Eclipse** -- GPT-5.2-Codex (`GA`), Gemini 3 Flash (`PREVIEW`), Gemini 3 Pro (`GA`), and Claude Opus 4.5 (`GA`) model support extended. C++ code editing tools (`PREVIEW`). Existing Copilot Chat, agent mode, and code completion features continue to be available. - [Eclipse Marketplace](https://marketplace.eclipse.org/content/github-copilot#details)

-   **Copilot for Xcode** -- Gains toolcall auto-approval for MCP tools, sensitive files, and terminal commands (`PREVIEW`), MCP Registry and allowlist features (`PREVIEW`). GPT-5.2-Codex (`GA`), Gemini 3 Flash (`PREVIEW`), Gemini 3 Pro (`GA`), and Claude Opus 4.5 (`GA`) model support extended. - [Releases](https://github.com/github/CopilotForXcode/releases/tag/0.47.0) | [Release Notes](https://github.com/github/CopilotForXcode/blob/main/ReleaseNotes.md)

> Note: **Copilot** features typically follow a predictable pattern in their release cycle, starting in **VS Code** (usually in **`PREVIEW`**), then rolling out to **Visual Studio** and **JetBrains** IDEs, followed by **Eclipse** and **Xcode**.

Stay current with the latest changes: [Copilot Feature Matrix](https://docs.github.com/en/copilot/reference/copilot-feature-matrix?tool=ides) | [GitHub Changelog (Copilot)](https://github.blog/changelog/label/copilot/) | [VS Code Release Notes](https://code.visualstudio.com/updates/) | [Visual Studio Release Notes](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes) | [JetBrains Plugin](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable) | [Xcode Releases](https://github.com/github/CopilotForXcode/releases) | [Copilot CLI Releases](https://github.com/github/copilot-cli/releases) | [GitHub Previews](https://github.com/features/preview) | [Preview Terms Changelog](https://github.com/customer-terms/updates)

---

# Enterprise and Security Updates

-   **GitHub Advanced Security Trials Expanded** -- GHAS trials now available for more GitHub Enterprise customers, lowering the barrier to evaluate security tooling. Start with the free [Secret Risk Assessment](https://docs.github.com/en/code-security/how-tos/secure-at-scale/configure-organization-security/configure-specific-tools/assess-your-secret-risk) to understand your organization's exposure. - [GHAS Trials](https://github.blog/changelog/2025-12-18-github-advanced-security-trials-now-available-for-more-github-enterprise-customers) | [Risk Assessment GA](https://github.blog/changelog/2025-08-26-the-secret-risk-assessment-is-generally-available/)

-   **Copilot Metrics and Dashboards** -- Track Copilot code generation metrics in a dedicated [dashboard](https://github.blog/changelog/2025-12-05-track-copilot-code-generation-metrics-in-a-dashboard) (`GA`). Enterprise-level [pull request activity](https://github.blog/changelog/2025-12-18-enterprise-level-pull-request-activity-metrics-now-in-public-preview) now included in Copilot Usage Metrics (`PREVIEW`). [Track organization-level Copilot usage](https://github.blog/changelog/2025-12-16-track-organization-copilot-usage) (`GA`).

-   **Deprecations and Migration Notices** -- If you're running Copilot and enterprise GitHub at scale, these are the key upcoming changes to plan for: **legacy Copilot metrics APIs** sunset March 2 and April 2, 2026 (migrate to the [modern metrics API](https://docs.github.com/en/rest/copilot/copilot-usage-metrics)); **self-hosted runner minimum version enforcement** extended; **select Copilot models** from Claude, Google, and OpenAI being deprecated; **Dependabot PR comment commands** changing syntax; **VS Code Copilot extension** deprecated (functionality merged into Copilot Chat extension); and **npm classic tokens** revoked in favor of session-based auth and CLI token management. - [Metrics APIs](https://github.blog/changelog/2026-01-29-closing-down-notice-of-legacy-copilot-metrics-apis) | [Runner Enforcement](https://github.blog/changelog/2026-02-05-github-actions-self-hosted-runner-minimum-version-enforcement-extended) | [Model Deprecations](https://github.blog/changelog/2026-01-13-upcoming-deprecation-of-select-github-copilot-models-from-claude-and-openai) | [npm Tokens](https://github.blog/changelog/2025-12-09-npm-classic-tokens-revoked-session-based-auth-and-cli-token-management-now-available)

-   **GHEC with Data Residency -- Japan (`GA`)** -- GitHub Enterprise Cloud data residency in Japan is now generally available. Copilot metrics (`PREVIEW`) and Codespaces (`PREVIEW`) are also now available in data-residency-aware deployments. - [Japan GA](https://github.blog/changelog/2025-12-18-github-enterprise-cloud-data-residency-in-japan-is-generally-available) | [Copilot Metrics in DR](https://github.blog/changelog/2026-01-29-copilot-metrics-in-github-enterprise-cloud-with-data-residency-in-public-preview) | [Codespaces in DR](https://github.blog/changelog/2026-01-29-codespaces-is-now-in-public-preview-for-github-enterprise-with-data-residency)

-   **Enterprise Governance Roundup** -- [Enterprise-scoped budgets](https://github.blog/changelog/2026-01-19-enterprise-scoped-budgets-that-exclude-cost-center-usage-in-public-preview) with cost center exclusion (`PREVIEW`), [organization custom properties](https://github.blog/changelog/2026-01-13-organization-custom-properties-now-generally-available) (`GA`), [Enterprise Teams APIs](https://github.blog/changelog/2026-02-09-github-apps-can-now-utilize-public-preview-enterprise-teams-apis-via-fine-grained-permissions) via fine-grained permissions (`PREVIEW`), app request controls for organizations (`GA`), block repo admins from installing GitHub Apps (`GA`), [enterprise teams product limits increased by over 10x](https://github.blog/changelog/2025-12-08-enterprise-teams-product-limits-increased-by-over-10x), and improved GitHub org policy enforcement in VS Code.

-   **Secret Scanning Updates (`GA`)** -- Enterprise governance and policy improvements for secret scanning are now generally available, giving admins centralized control over scanning configurations. Secret scanning extended metadata is now automatically enabled for eligible repositories, broadening protection without admin action. - [Governance](https://github.blog/changelog/2025-12-16-enterprise-governance-and-policy-improvements-for-secret-scanning-now-generally-available) | [Auto-Enabled Metadata](https://github.blog/changelog/2026-01-15-secret-scanning-extended-metadata-to-be-automatically-enabled-for-certain-repositories)

-   **Code-to-Cloud Traceability and SLSA Build Level 3 (`GA`)** -- End-to-end code-to-cloud traceability and SLSA Build Level 3 security attestations provide verified provenance for enterprise builds. - [Changelog](https://github.blog/changelog/2026-01-20-strengthen-your-supply-chain-with-code-to-cloud-traceability-and-slsa-build-level-3-security)

-   **Code Scanning and AI-Powered Triage** -- Assign code scanning alerts to specific team members for accountability (`GA`). The open-source [Security Lab Taskflow Agent](https://github.blog/security/ai-supported-vulnerability-triage-with-the-github-security-lab-taskflow-agent/) automates vulnerability analysis in GitHub Actions and JavaScript projects. - [Alert Assignees](https://github.blog/changelog/2025-12-16-code-scanning-alert-assignees-are-now-generally-available) | [Taskflow Framework](https://github.blog/security/community-powered-security-with-ai-an-open-source-framework-for-security-research/)

-   **Dependabot Security Improvements** -- [OIDC authentication](https://github.blog/changelog/2026-02-03-dependabot-now-supports-oidc-authentication) for private registries eliminates long-lived credentials (`GA`). Configuration changes tracked in [audit logs](https://github.blog/changelog/2026-02-10-track-additional-dependabot-configuration-changes-in-audit-logs). The [Dependabot Proxy](https://github.blog/changelog/2026-02-03-the-dependabot-proxy-is-now-open-source-with-an-mit-license) is now open source under MIT license. New ecosystem support: [Bazel](https://github.blog/changelog/2025-12-16-dependabot-version-updates-now-support-bazel) (`GA`), OpenTofu (`GA`), Julia (`GA`), Conda (`GA`), [uv](https://github.blog/changelog/2025-12-16-dependabot-security-updates-now-support-uv) (`GA`).

---

# Resources and Best Practices

**The agent ecosystem around Copilot is maturing rapidly.** These community resources, practitioner guides, and prompt engineering references provide concrete patterns for enterprise teams adopting agentic workflows.

-   **Understanding Copilot's Context Window** -- An excellent deep dive explaining how Copilot generates the full context window, where custom instructions and prompt files are most effective, how to avoid context rot, and how to build workflows using different models to maximize PRU efficiency. - [YouTube](https://www.youtube.com/watch?v=0XoXNG65rfg)

-   **Copilot Customization Guide** -- Practitioner walkthrough covering custom instructions, prompt files, and agent configuration patterns for platform teams. - [Blog Post](https://blog.cloud-eng.nl/2025/12/22/copilot-customization/)

-   **Agent Orchestration Patterns** -- **Copilot Orchestra** provides a multi-agent system with a "Conductor" that orchestrates planning, implementation, and code review subagents (referenced in VS Code release notes). **Spec Kit** is a GitHub-maintained toolkit for spec-driven development workflows. Both provide starting points for enterprise teams building structured agent workflows. - [Copilot Orchestra](https://github.com/ShepAlderson/copilot-orchestra) | [Spec Kit](https://github.com/github/spec-kit)

-   **Prompt Engineering Best Practices** -- Vendor-published guides for getting the most out of the models powering Copilot. Anthropic's guide covers instruction clarity, chain-of-thought, and tool use patterns. OpenAI's evaluation flywheel cookbook shows how to build resilient prompts using iterative testing loops. Both are directly applicable to writing effective custom instructions and agent prompts. - [Claude Best Practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) | [OpenAI Eval Flywheel](https://developers.openai.com/cookbook/examples/evaluation/building_resilient_prompts_using_an_evaluation_flywheel)

-   **Agent Configuration and Discovery** -- **Awesome Copilot** is the official GitHub-curated collection of Copilot extensions, custom agents, and partner integrations. **agentconfig.org** maps configuration conventions across major coding assistants, helping teams standardize their multi-tool AI governance. - [Awesome Copilot](https://github.com/github/awesome-copilot) | [agentconfig.org](https://agentconfig.org/)

-   **Turning Agent Misses into Systemic Improvements** -- Practitioner post detailing how repeated agent errors can be converted into durable process assets. - [Blog Post](https://jonmagic.com/posts/turning-agent-misses-into-systemic-improvements/)

---

# Webinars, Events, and Recordings

Brian's personally curated YouTube playlists, updated monthly: [Copilot Tips and Training Video](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D), [GitHub Enterprise, Actions, and GHAS videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ3wk4atKpN-yOW1FtyxN48W), [How GitHub GitHubs videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1nWhqxi-UQF_O-gYWo5jpG)

## Official Microsoft Learn Training (Free)

Official instructor-led video courses from **Microsoft Learn**, available free on YouTube. These are GitHub's recommended training paths for structured team onboarding, certification preparation, and self-paced upskilling.

| Course | Episodes | Total Length | Level | Playlist |
|--------|----------|--------------|-------|----------|
| **GH-300: GitHub Copilot** | 5 episodes: Introduction (41m), Exploring Features (1h15m), Generative AI Use Cases (42m), Writing Unit Tests (20m), Advanced Features (59m) | ~3h 17m | Intermediate | [Watch](https://www.youtube.com/watch?v=-1-ZeFMmlOM&list=PLahhVEj9XNTd8lE7clFGR1el35zaBmJbS) |
| **GH-500: GitHub Advanced Security** | 5 episodes: Introduction to GHAS (36m), Security Data and Policies (40m), Dependabot Security Updates (28m), Secret Scanning (12m), Code Scanning (39m) | ~2h 35m | Intermediate | [Watch](https://www.youtube.com/watch?v=hb7AllAd7l0&list=PLahhVEj9XNTcJZjBU671JAiX8St3CV5dA) |
| **GH-200: Automate Your Workflow with GitHub Actions** | 5 episodes: Course Introduction (5m), Intro to Actions (48m), Pipelines in Actions (1h7m), Extending Workflows (55m), Org and Enterprise Config (44m) | ~3h 19m | Beginner | [Watch](https://www.youtube.com/watch?v=8m9JBtGFMp8&list=PLahhVEj9XNTd5N_seZDoRXVIn6N1qAp-_) |
| **AZ-2008: DevOps Foundations** | 6 episodes: Core Principles (3m), Discover DevOps (12m), Plan (20m), Develop (25m), Deliver (20m), Operate (24m) | ~1h 44m | Beginner | [Watch](https://www.youtube.com/watch?v=Vfz6WtUK6B0&list=PLahhVEj9XNTfLw9oLP-XeTUvw3IknTRwk) |

## Virtual Events

| Date | Event | Category |
|------|-------|----------|
| Feb 17 | [Modernize Your Java Apps in Days with AI Agents](https://developer.microsoft.com/en-us/reactor/events/26640/) | Copilot, Agentic DevOps |
| Feb 19 | [VS Code Agent Sessions Day](https://youtube.com/live/tAezuMSJuFs) | Copilot |
| Feb 22 | [AI Dev Days Hackathon](https://developer.microsoft.com/en-us/reactor/events/26647/) | Copilot, Enterprise |
| Feb 24 | [AI-Powered Workflows with GitHub and Azure DevOps](https://developer.microsoft.com/en-us/reactor/events/26641/) | Copilot, Agentic DevOps |
| Feb 24 | [Python + Agents: Building AI Agents with Agent Framework](https://developer.microsoft.com/en-us/reactor/series/S-1631/) | Copilot, Developer Experience |
| Feb 26 | [KUWC: Agents in the Wild](https://github.com/resources/events/github-kuwc-part-one26) | Copilot |
| Mar 3 | [Get Secure and Stay Secure in the World of Agentic AI](https://developer.microsoft.com/en-us/reactor/events/26642/) | GHAS, Enterprise |
| Mar 10 | [Root Cause Analysis with Code Context: Azure SRE Agent + GitHub](https://developer.microsoft.com/en-us/reactor/events/26780/) | Enterprise, Agentic DevOps |
| Mar 19 | [VS Code Live: 1.110 Release](https://developer.microsoft.com/en-us/reactor/events/26589/) | Copilot |
| Mar 24 | [Modernizing .NET at Scale with the GitHub Copilot App Mod Agent](https://developer.microsoft.com/en-us/reactor/events/26782/) | Copilot, Agentic DevOps |
| Mar 26 | [KUWC: Instructions, Agents, Prompts, Skills](https://github.com/resources/events/github-kuwc-part-two26) | Copilot |
| Apr 30 | [KUWC: Copilot Greatness: Best Practices + Metrics](https://github.com/resources/events/github-kuwc-part-three26) | Copilot, Enterprise |
| May 28 | [KUWC: Making AI a Developer Team Sport](https://github.com/resources/events/github-kuwc-part-four26) | Copilot |

Browse all GitHub-tagged Reactor events: [Microsoft Reactor](https://developer.microsoft.com/en-us/reactor/?search=github) | [Agentic DevOps Live Series](https://developer.microsoft.com/en-us/reactor/series/s-1625/)

## In-Person Events

| Event | Date | Location | Link |
|-------|------|----------|------|
| Microsoft AI Tour Sao Paulo | Feb 11, 2026 | Sao Paulo, Brazil | [Register](https://aitour.microsoft.com/flow/microsoft/saopaulo26/landingpage/page/cityhome) |
| Microsoft AI Tour Mexico City | Feb 12, 2026 | Mexico City, Mexico | [Register](https://aitour.microsoft.com/flow/microsoft/mexicocity26/landingpage/page/cityhome) |
| From SDLC to AI-Native Delivery | Feb 18, 2026 | Paris, France | [Register](https://github.registration.goldcast.io/events/3f6e5c24-d1c7-43c8-8907-4f971f3bbadb) |
| Mastering GitHub Copilot Workshop | Feb 23, 2026 | London, UK | [Register](https://github.registration.goldcast.io/events/ec428ae7-9774-4fbb-b5a2-321b3925e362) |
| Microsoft AI Tour London | Feb 24, 2026 | London, UK | [Register](https://aitour.microsoft.com/flow/microsoft/london262/landingpage/page/cityhome) |
| GitHub Connect Toronto | Mar 5, 2026 | Toronto, ON | [Register](https://github.com/resources/events/github-connect-toronto26) |
| Microsoft AI Tour Washington D.C. | Mar 10, 2026 | Washington D.C. | [Register](https://aitour.microsoft.com/flow/microsoft/washingtondc26/landingpage/page/cityhome) |
| Microsoft AI Tour Paris | Mar 11, 2026 | Paris, France | [Register](https://aitour.microsoft.com/flow/microsoft/paris26/landingpage/page/cityhome) |
| GitHub at RSAC 2026 | Mar 23-26, 2026 | San Francisco, CA | [Register](https://github.com/resources/events/github-rsac2026) |
| Microsoft AI Tour Seoul | Mar 26, 2026 | Seoul, Korea | [Register](https://aitour.microsoft.com/flow/microsoft/aitour/landing/page/home) |
| GitHub at Google Cloud Next 2026 | Apr 22-24, 2026 | Las Vegas, NV | [Register](https://github.com/resources/events/github-gcn2026) |


---

If you have any questions or want to discuss these updates in detail, feel free to reach out. As always, I'm here to help you and your team stay informed and get the most value from GitHub. I welcome your feedback, and please let me know if you would like to add or remove anyone from this list.

# Copilot

## Latest Releases

**VS Code v1.110 ships with agent UX improvements and MCP health monitoring**, while Claude Opus 4.6 Fast reaches general availability across all IDEs.

-   **Copilot code review custom instructions improvements (`GA`)** -- Custom instructions for Copilot code review now support repository-level and organization-level configuration files, enabling teams to enforce review standards across all pull requests consistently. Administrators can define coding standards, security checks, and style guidelines that Copilot applies automatically. - [Changelog](https://github.blog/changelog/2026-02-18-copilot-code-review-custom-instructions-improvements)

-   **Agent mode: multi-repository context (`PREVIEW`)** -- Copilot agent mode can now reference and navigate across multiple repositories within the same organization when resolving tasks. The agent uses cross-repo search to find relevant code, types, and interfaces in dependent repositories, improving accuracy for monorepo and multi-service architectures. - [Changelog](https://github.blog/changelog/2026-02-17-copilot-agent-mode-multi-repository-context)

-   **Code completions: improved multi-file context (`GA`)** -- Copilot code completions now use an improved multi-file context algorithm that considers recently edited files, imported modules, and type definitions when generating suggestions. The new algorithm reduces irrelevant suggestions by 23% in internal benchmarks. - [Release Notes](https://code.visualstudio.com/updates/v1_110#_improved-multi-file-context)

-   **Agent mode: improved tool confirmation UX (`GA`)** -- Agent mode now provides a streamlined tool confirmation experience with inline previews of proposed file changes before acceptance. Users can review, modify, or reject individual tool calls without interrupting the overall agent workflow. - [Release Notes](https://code.visualstudio.com/updates/v1_110#_agent-tool-confirmation-ux)

-   **MCP server health monitoring (`PREVIEW`)** -- VS Code now provides health monitoring for connected MCP servers, displaying connection status, latency metrics, and error rates in the MCP panel. Automatic reconnection with exponential backoff is now enabled by default. Administrators can configure health check intervals and failure thresholds. - [Release Notes](https://code.visualstudio.com/updates/v1_110#_mcp-server-health-monitoring)

-   **Copilot Chat: conversation branching (`PREVIEW`)** -- Copilot Chat now supports conversation branching, allowing users to explore alternative approaches from any point in a conversation without losing the original thread. Users can fork a conversation, try a different approach, and switch between branches. - [Release Notes](https://code.visualstudio.com/updates/v1_110#_conversation-branching)

-   **Agent hooks: PostToolUse error recovery (`PREVIEW`)** -- Agent hooks now support error recovery in PostToolUse handlers. When a tool call fails, the PostToolUse hook can provide alternative actions or fallback behaviors, enabling more resilient agentic workflows. - [Release Notes](https://code.visualstudio.com/updates/v1_110#_agent-hooks-error-recovery)

-   **Copilot Workspace: project planning and task decomposition (`PREVIEW`)** -- Copilot Workspace now supports natural language project planning with automatic task decomposition. Describe a goal and Copilot breaks it into actionable implementation steps with file-level change proposals. - [Changelog](https://github.blog/changelog/2026-02-14-copilot-workspace-project-planning-and-task-decomposition)

-   **Model availability updates** -- Claude Opus 4.6 Fast (`GA`) is now generally available across all supported IDEs, offering the same capabilities as Claude Opus 4.6 with significantly reduced latency, optimized for interactive coding workflows. Available to Copilot Business and Enterprise subscribers. - [Changelog](https://github.blog/changelog/2026-02-18-claude-opus-4-6-fast-is-now-generally-available-for-github-copilot)

### Improved IDE Feature Parity

-   **JetBrains IDEs** -- Plugin version 1.5.68 adds MCP allowlist enforcement (`GA`) for organization-administered server restrictions, agent session persistence (`GA`) across IDE restarts, and Claude Opus 4.6 Fast (`GA`) model support. - [JetBrains Plugin](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable/905123)

-   **Copilot for Xcode** -- Version 0.48.0 adds Claude Opus 4.6 Fast (`GA`) model support and improved completions for Swift concurrency patterns (`GA`) including async/await, actors, and structured concurrency. - [CHANGELOG](https://github.com/github/CopilotForXcode/blob/main/CHANGELOG.md#0480---february-19-2026)

> Note: **Copilot** features typically follow a predictable pattern in their release cycle, starting in **VS Code** (usually in **`PREVIEW`**), then rolling out to **Visual Studio** and **JetBrains** IDEs, followed by **Eclipse** and **Xcode**.

Stay current with the latest changes: [Copilot Feature Matrix](https://docs.github.com/en/copilot/reference/copilot-feature-matrix?tool=ides) | [GitHub Changelog (Copilot)](https://github.blog/changelog/label/copilot/) | [VS Code Release Notes](https://code.visualstudio.com/updates/) | [Visual Studio Release Notes](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes) | [JetBrains Plugin](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable) | [Xcode Releases](https://github.com/github/CopilotForXcode/releases) | [Copilot CLI Releases](https://github.com/github/copilot-cli/releases) | [GitHub Previews](https://github.com/features/preview) | [Preview Terms Changelog](https://github.com/customer-terms/updates)

---

# Enterprise and Security Updates

-   **AI-powered autofix for CodeQL alerts expanded (`GA`)** -- AI-powered autofix for CodeQL code scanning alerts is now generally available for all supported languages including Java, Python, JavaScript/TypeScript, C#, Go, Ruby, and C/C++. Autofix generates remediation suggestions directly in pull requests, reducing mean-time-to-remediation for security vulnerabilities. - [Changelog](https://github.blog/changelog/2026-02-19-ai-powered-autofix-for-codeql-alerts-expanded)

-   **Secret scanning: delegated bypass for push protection (`GA`)** -- Organizations can now configure delegated bypass for secret scanning push protection, allowing designated security team members to approve bypass requests while maintaining audit trails. Supports integration with existing approval workflows and ITSM tools. - [Changelog](https://github.blog/changelog/2026-02-20-secret-scanning-delegated-bypass-for-push-protection)

-   **GitHub Actions: immutable actions from verified creators (`GA`)** -- Actions from verified creators are now immutably published to the Actions marketplace. Immutable actions cannot be modified after publication, providing supply chain integrity guarantees. Organizations can restrict workflow usage to only immutable actions via a new repository policy setting. - [Changelog](https://github.blog/changelog/2026-02-19-github-actions-immutable-actions-from-verified-creators)

-   **Dependabot: grouped security updates for monorepos (`GA`)** -- Dependabot now groups related security updates into a single pull request for monorepo configurations, reducing PR noise by consolidating multiple dependency updates that share the same security advisory into one actionable PR. - [Changelog](https://github.blog/changelog/2026-02-15-dependabot-grouped-security-updates-for-monorepos)

-   **Visual Studio 2022 17.14.27 servicing update (`GA`)** -- Addresses CVE-2026-21233 (remote code execution in project file parsing) and CVE-2026-21234 (elevation of privilege in NuGet package restore), both rated Important. Also includes stability improvements for Copilot agent mode in Visual Studio. - [Release Notes](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes#17.14.27)

-   **GitHub Actions: enhanced workflow run visibility (`GA`)** -- Workflow runs now include expanded step-level timing, resource utilization metrics, and improved log navigation. Administrators can view aggregate workflow performance trends across the organization. - [Changelog](https://github.blog/changelog/2026-02-16-github-actions-enhanced-workflow-run-visibility)

-   **GitHub Projects: automation rules for status transitions (`GA`)** -- GitHub Projects now supports configurable automation rules for status field transitions. Define conditions (label changes, PR merges, issue closures) that automatically move items between status columns. - [Changelog](https://github.blog/changelog/2026-02-20-github-projects-automation-rules-for-status-transitions)

---

# Resources and Best Practices

-   **How enterprise teams are adopting agentic workflows at scale** -- Case study examining how three Fortune 500 companies deployed GitHub Copilot's agentic capabilities across 1000+ developer teams. Covers governance patterns, custom instruction strategies, MCP server deployment, and measured productivity outcomes. - [GitHub Blog](https://github.blog/ai-and-ml/github-copilot/how-enterprise-teams-are-adopting-agentic-workflows-at-scale/)

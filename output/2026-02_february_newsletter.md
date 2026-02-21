# February 2026 Newsletter (Week of Feb 14-21)

This is a personally curated newsletter for my customers, focused on the most relevant updates and resources from GitHub this week. Highlights for this week include AI-powered autofix for CodeQL expanding to all supported languages, Copilot agent mode gaining multi-repository context, and Claude Opus 4.6 Fast reaching general availability across all IDEs. If you have any feedback or want to dive deeper into any topic, please let me know. Feel free to share this newsletter with others on your team as well. You can find an archive of past newsletters [here](https://github.com/briancl2/CustomerNewsletter).

---

# Copilot

## Latest Releases

**VS Code v1.110 ships with agent UX improvements and MCP health monitoring**, while Claude Opus 4.6 Fast reaches general availability across all IDEs.

-   **Copilot Code Review custom instructions improvements (`GA`)** -- Custom instructions for Copilot code review now support repository-level and organization-level configuration files, enabling teams to enforce review standards across all pull requests consistently. Administrators can define coding standards, security checks, and style guidelines that Copilot applies automatically. - [Changelog](https://github.blog/changelog/2026-02-18-copilot-code-review-custom-instructions-improvements)

-   **Agent Mode: multi-repository context (`PREVIEW`)** -- Copilot Agent Mode can now reference and navigate across multiple repositories within the same organization when resolving tasks. The agent uses cross-repo search to find relevant code, types, and interfaces in dependent repositories, improving accuracy for monorepo and multi-service architectures. - [Changelog](https://github.blog/changelog/2026-02-17-copilot-agent-mode-multi-repository-context)

-   **Code completions: improved multi-file context (`GA`)** -- Copilot code completions now use an improved multi-file context algorithm that considers recently edited files, imported modules, and type definitions when generating suggestions. The new algorithm reduces irrelevant suggestions by 23% in internal benchmarks. - [Release Notes](https://code.visualstudio.com/updates/v1_110#_improved-multi-file-context)

-   **Agent Mode: improved tool confirmation UX (`GA`)** -- Agent Mode now provides a streamlined tool confirmation experience with inline previews of proposed file changes before acceptance. Users can review, modify, or reject individual tool calls without interrupting the overall agent workflow. - [Release Notes](https://code.visualstudio.com/updates/v1_110#_agent-tool-confirmation-ux)

-   **MCP Server health monitoring (`PREVIEW`)** -- VS Code now provides health monitoring for connected MCP servers, displaying connection status, latency metrics, and error rates in the MCP panel. Automatic reconnection with exponential backoff is now enabled by default. Administrators can configure health check intervals and failure thresholds. - [Release Notes](https://code.visualstudio.com/updates/v1_110#_mcp-server-health-monitoring)

-   **Copilot Chat: conversation branching (`PREVIEW`)** -- Copilot Chat now supports conversation branching, allowing users to explore alternative approaches from any point in a conversation without losing the original thread. Users can fork a conversation, try a different approach, and switch between branches. - [Release Notes](https://code.visualstudio.com/updates/v1_110#_conversation-branching)

-   **Agent Hooks: PostToolUse error recovery (`PREVIEW`)** -- Agent hooks now support error recovery in PostToolUse handlers. When a tool call fails, the PostToolUse hook can provide alternative actions or fallback behaviors, enabling more resilient agentic workflows. - [Release Notes](https://code.visualstudio.com/updates/v1_110#_agent-hooks-error-recovery)

-   **Copilot Workspace: project planning and task decomposition (`PREVIEW`)** -- Copilot Workspace now supports natural language project planning with automatic task decomposition. Describe a goal and Copilot breaks it into actionable implementation steps with file-level change proposals. - [Changelog](https://github.blog/changelog/2026-02-14-copilot-workspace-project-planning-and-task-decomposition)

-   **Model availability updates** -- Claude Opus 4.6 Fast (`GA`) is now generally available across all supported IDEs, offering the same capabilities as Claude Opus 4.6 with significantly reduced latency, optimized for interactive coding workflows. Available to Copilot Business and Enterprise subscribers. - [Changelog](https://github.blog/changelog/2026-02-18-claude-opus-4-6-fast-is-now-generally-available-for-github-copilot)

-   **Copilot CLI updates (`PREVIEW`)** -- The CLI continues to ship daily releases (v0.0.410-v0.0.411 this week). Plan mode gains improved output formatting with structured task breakdowns and file-level change previews. MCP Server auto-discovery from workspace config (`.vscode/mcp.json`, `.copilot/mcp.json`) ensures consistent tool access across VS Code and CLI environments. Note: Copilot CLI is covered under the [GitHub Data Protection Agreement](https://docs.github.com/en/site-policy/github-terms/github-dpa-previews) and [Pre-Release License Terms (indemnity)](https://docs.github.com/en/site-policy/github-terms/github-pre-release-license-terms) while in preview. - [CLI Releases](https://github.com/github/copilot-cli/releases) | [v0.0.410](https://github.com/github/copilot-cli/releases/tag/v0.0.410) | [v0.0.411](https://github.com/github/copilot-cli/releases/tag/v0.0.411)

### Improved IDE Feature Parity

-   **JetBrains IDEs** -- Plugin version 1.5.68 adds MCP allowlist enforcement (`GA`) for organization-administered server restrictions, agent session persistence (`GA`) across IDE restarts, and Claude Opus 4.6 Fast (`GA`) model support. - [JetBrains Plugin](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable/905123)

-   **Copilot for Xcode** -- Version 0.48.0 adds Claude Opus 4.6 Fast (`GA`) model support and improved completions for Swift concurrency patterns (`GA`) including async/await, actors, and structured concurrency. - [CHANGELOG](https://github.com/github/CopilotForXcode/blob/main/CHANGELOG.md#0480---february-19-2026)

> Note: **Copilot** features typically follow a predictable pattern in their release cycle, starting in **VS Code** (usually in **`PREVIEW`**), then rolling out to **Visual Studio** and **JetBrains** IDEs, followed by **Eclipse** and **Xcode**.

Stay current with the latest changes: [Copilot Feature Matrix](https://docs.github.com/en/copilot/reference/copilot-feature-matrix?tool=ides) | [GitHub Changelog (Copilot)](https://github.blog/changelog/label/copilot/) | [VS Code Release Notes](https://code.visualstudio.com/updates/) | [Visual Studio Release Notes](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes) | [JetBrains Plugin](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable) | [Xcode Releases](https://github.com/github/CopilotForXcode/releases) | [Copilot CLI Releases](https://github.com/github/copilot-cli/releases) | [GitHub Previews](https://github.com/features/preview) | [Preview Terms Changelog](https://github.com/customer-terms/updates)

---

# Enterprise and Security Updates

-   **AI-powered autofix for CodeQL alerts expanded (`GA`)** -- AI-powered autofix for CodeQL Code Scanning alerts is now generally available for all supported languages including Java, Python, JavaScript/TypeScript, C#, Go, Ruby, and C/C++. Autofix generates remediation suggestions directly in pull requests, reducing mean-time-to-remediation for security vulnerabilities. - [Changelog](https://github.blog/changelog/2026-02-19-ai-powered-autofix-for-codeql-alerts-expanded)

-   **Secret Scanning: delegated bypass for push protection (`GA`)** -- Organizations can now configure delegated bypass for Secret Scanning push protection, allowing designated security team members to approve bypass requests while maintaining audit trails. Supports integration with existing approval workflows and ITSM tools. - [Changelog](https://github.blog/changelog/2026-02-20-secret-scanning-delegated-bypass-for-push-protection)

-   **GitHub Actions: immutable actions from verified creators (`GA`)** -- Actions from verified creators are now immutably published to the Actions marketplace. Immutable actions cannot be modified after publication, providing supply chain integrity guarantees. Organizations can restrict workflow usage to only immutable actions via a new repository policy setting. - [Changelog](https://github.blog/changelog/2026-02-19-github-actions-immutable-actions-from-verified-creators)

-   **Dependabot: grouped security updates for monorepos (`GA`)** -- Dependabot now groups related security updates into a single pull request for monorepo configurations, reducing PR noise by consolidating multiple dependency updates that share the same security advisory into one actionable PR. - [Changelog](https://github.blog/changelog/2026-02-15-dependabot-grouped-security-updates-for-monorepos)

-   **Visual Studio 2022 17.14.27 servicing update (`GA`)** -- Addresses CVE-2026-21233 (remote code execution in project file parsing) and CVE-2026-21234 (elevation of privilege in NuGet package restore), both rated Important. Also includes stability improvements for Copilot Agent Mode in Visual Studio. - [Release Notes](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes#17.14.27)

-   **GitHub Actions: enhanced workflow run visibility (`GA`)** -- Workflow runs now include expanded step-level timing, resource utilization metrics, and improved log navigation. Administrators can view aggregate workflow performance trends across the organization. - [Changelog](https://github.blog/changelog/2026-02-16-github-actions-enhanced-workflow-run-visibility)

-   **GitHub Projects: automation rules for status transitions (`GA`)** -- GitHub Projects now supports configurable automation rules for status field transitions. Define conditions (label changes, PR merges, issue closures) that automatically move items between status columns. - [Changelog](https://github.blog/changelog/2026-02-20-github-projects-automation-rules-for-status-transitions)

---

# Resources and Best Practices

-   **How enterprise teams are adopting agentic workflows at scale** -- Case study examining how three Fortune 500 companies deployed GitHub Copilot's agentic capabilities across 1000+ developer teams. Covers governance patterns, custom instruction strategies, MCP server deployment, and measured productivity outcomes. - [GitHub Blog](https://github.blog/ai-and-ml/github-copilot/how-enterprise-teams-are-adopting-agentic-workflows-at-scale/)

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
| Mastering GitHub Copilot Workshop | Feb 23, 2026 | London, UK | [Register](https://github.registration.goldcast.io/events/ec428ae7-9774-4fbb-b5a2-321b3925e362) |
| Microsoft AI Tour London | Feb 24, 2026 | London, UK | [Register](https://aitour.microsoft.com/flow/microsoft/london262/landingpage/page/cityhome) |
| GitHub Connect Toronto | Mar 5, 2026 | Toronto, ON | [Register](https://github.com/resources/events/github-connect-toronto26) |
| Microsoft AI Tour Washington D.C. | Mar 10, 2026 | Washington D.C. | [Register](https://aitour.microsoft.com/flow/microsoft/washingtondc26/landingpage/page/cityhome) |
| Microsoft AI Tour Paris | Mar 11, 2026 | Paris, France | [Register](https://aitour.microsoft.com/flow/microsoft/paris26/landingpage/page/cityhome) |
| GitHub at RSAC 2026 | Mar 23-26, 2026 | San Francisco, CA | [Register](https://github.com/resources/events/github-rsac2026) |
| Microsoft AI Tour Seoul | Mar 26, 2026 | Seoul, Korea | [Register](https://aitour.microsoft.com/flow/microsoft/aitour/landing/page/home) |
| GitHub at Google Cloud Next 2026 | Apr 22-24, 2026 | Las Vegas, NV | [Register](https://github.com/resources/events/github-gcn2026) |

---

If you have any questions or want to discuss these updates in detail, feel free to reach out. As always, I'm here to help you and your team stay informed and get the most value from GitHub.

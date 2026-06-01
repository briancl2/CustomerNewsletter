# April 2026 Newsletter

This is a personally curated newsletter for my customers, focused on the most relevant updates and resources from GitHub this month. Highlights for this month include **Copilot cloud agent** with runner and firewall controls, **bring your own key** support across **VS Code** and **Copilot CLI**, and the expansion of governed custom-agent workflows across **Visual Studio**, **JetBrains**, and **VS Code**. If you have any feedback or want to dive deeper into any topic, please let me know. Feel free to share this newsletter with others on your team as well. You can find an archive of past newsletters [here](https://github.com/briancl2/CustomerNewsletter).

---

# Copilot Everywhere: More Control, More Surfaces, More Enterprise Choice

- **Copilot cloud agent (`PREVIEW`)** moved GitHub into a true research, plan, and code workflow, then immediately added [organization runner controls](https://github.blog/changelog/2026-04-03-organization-runner-controls-for-copilot-cloud-agent), [organization firewall settings](https://github.blog/changelog/2026-04-03-organization-firewall-settings-for-copilot-cloud-agent), and [signed commits](https://github.blog/changelog/2026-04-03-copilot-cloud-agent-signs-its-commits). This is the strongest signal in the window for regulated customers because GitHub paired agent execution with the controls needed for real rollout. [Changelog](https://github.blog/changelog/2026-04-01-research-plan-and-code-with-copilot-cloud-agent)

- **Bring your own key (`PREVIEW`)** expanded across [**Copilot CLI**](https://github.blog/changelog/2026-04-07-copilot-cli-now-supports-byok-and-local-models) and [**VS Code**](https://code.visualstudio.com/updates/v1_115). For customers that need provider governance, regional model choice, or staged adoption of third-party models, BYOK is one of the highest-value enterprise updates in this cycle.

- Governed agent workflows now span the major enterprise IDE surfaces. [**Visual Studio** custom agents](https://devblogs.microsoft.com/visualstudio/custom-agents-in-visual-studio-built-in-and-build-your-own-agents/), [**JetBrains** custom agents and Plan Agent](https://github.blog/changelog/2026-03-11-major-agentic-capabilities-improvements-in-github-copilot-for-jetbrains-ides), and the [**VS Code Agents** companion app](https://code.visualstudio.com/updates/v1_115) all point in the same direction: agent work is becoming a first-class operating model, not a side feature.

---

# Copilot

## Latest Releases

- **Copilot cloud agent (`PREVIEW`)** launched as a full research-to-execution workflow on GitHub. The launch matters because it shipped with enterprise controls from day one, including runner placement, firewall scoping, and signed commits for provenance. [Changelog](https://github.blog/changelog/2026-04-01-research-plan-and-code-with-copilot-cloud-agent) | [Runner controls](https://github.blog/changelog/2026-04-03-organization-runner-controls-for-copilot-cloud-agent) | [Firewall settings](https://github.blog/changelog/2026-04-03-organization-firewall-settings-for-copilot-cloud-agent) | [Signed commits](https://github.blog/changelog/2026-04-03-copilot-cloud-agent-signs-its-commits)

- **Enterprise AI controls** and the **agent control plane (`GA`)** reached general availability. This gives enterprises a central place for governance, rollout policy, and oversight across Copilot and agent experiences. [Changelog](https://github.blog/changelog/2026-02-26-enterprise-ai-controls-agent-control-plane-now-generally-available)

- **Custom agents in Visual Studio** turned the IDE into a stronger enterprise control point for grounded agent workflows. Repository-defined `.agent.md` files can now connect to internal docs, APIs, and databases through MCP, which is especially relevant for .NET-heavy organizations. [DevBlog](https://devblogs.microsoft.com/visualstudio/custom-agents-in-visual-studio-built-in-and-build-your-own-agents/)

- **VS Code Agents (`PREVIEW`)** introduced a companion surface for agent-native development with parallel sessions across repositories, inline diff review, and pull request creation. This is an important platform signal because it makes agent work visible and reviewable outside the standard sidebar workflow, and the latest in-range [April release notes](https://code.visualstudio.com/updates/v1_116) preserved that agent-centric direction. [Release Notes](https://code.visualstudio.com/updates/v1_115)

- **Bring your own key (`PREVIEW`)** and provider choice expanded across **Copilot CLI** and **VS Code**. This gives customers more control over model sourcing and is a meaningful step toward enterprise-grade provider governance. [CLI changelog](https://github.blog/changelog/2026-04-07-copilot-cli-now-supports-byok-and-local-models) | [VS Code release notes](https://code.visualstudio.com/updates/v1_115)

- **JetBrains custom agents, sub-agents, and Plan Agent (`GA`)** made JetBrains a much stronger first-class Copilot surface for enterprises that do not standardize on VS Code. Agent hooks and MCP controls landed in the same release wave, which makes the overall story more operationally complete. [Changelog](https://github.blog/changelog/2026-03-11-major-agentic-capabilities-improvements-in-github-copilot-for-jetbrains-ides) | [Plugin 1.6.1](https://plugins.jetbrains.com/plugin/17718-github-copilot--your-ai-pair-programmer/versions/stable/982717)

- Cross-IDE **MCP governance controls** tightened the external-tool story across all major IDEs. **VS Code** added sandboxing for local stdio MCP servers, **Visual Studio** improved MCP authentication and elicitation handling, and **JetBrains** added server and tool-level auto-approve controls. [VS Code](https://code.visualstudio.com/updates/v1_112) | [Visual Studio](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes#github-copilot) | [JetBrains](https://plugins.jetbrains.com/plugin/17718-github-copilot--your-ai-pair-programmer/versions/stable/982717)

- **Autopilot (`PREVIEW`)** and permission levels in **VS Code** brought a more governed approval model to both editor agents and **Copilot CLI** sessions. For teams rolling out agents in stages, that permission gradient is a major operational advantage. [Release Notes](https://code.visualstudio.com/updates/v1_111) | [CLI permissions](https://code.visualstudio.com/updates/v1_112)

- The **Agent Debug** panel and exported debug logs in **VS Code (`PREVIEW`)** improved observability for prompt loading, tools, hooks, and session events. This matters for enterprise trust because rollout teams can troubleshoot agent behavior with concrete evidence instead of guesswork. [Release Notes](https://code.visualstudio.com/updates/v1_110) | [Log export and import](https://code.visualstudio.com/updates/v1_112)

- **Copilot Content Exclusion REST API (`PREVIEW`)** made repository and path-level exclusion rules scriptable. For enterprises managing policy as code, this is more useful than a manual-only control surface. [Changelog](https://github.blog/changelog/2026-02-26-copilot-content-exclusion-rest-api-in-public-preview)

## IDE Parity

- **Improved IDE Feature Parity**: Copilot agent capabilities expanded broadly across all major IDEs this cycle.
  - **VS Code** added MCP sandboxing, nested subagents, MCP bridging into **Copilot CLI** and external agents, **Autopilot**, the **Agent Debug** panel, organization policy to disable the **Claude** agent, the **VS Code Agents** companion app, and the late-window Agent Host and worktree isolation updates. [v1_110](https://code.visualstudio.com/updates/v1_110) | [v1_111](https://code.visualstudio.com/updates/v1_111) | [v1_112](https://code.visualstudio.com/updates/v1_112) | [v1_113](https://code.visualstudio.com/updates/v1_113) | [v1_114](https://code.visualstudio.com/updates/v1_114) | [v1_115](https://code.visualstudio.com/updates/v1_115) | [v1_116](https://code.visualstudio.com/updates/v1_116)
  - **Visual Studio** added custom agents, reusable agent skills, `find_symbol`, task delegation to the Copilot coding agent, and stronger MCP authentication management. [Custom agents](https://devblogs.microsoft.com/visualstudio/custom-agents-in-visual-studio-built-in-and-build-your-own-agents/) | [March update](https://devblogs.microsoft.com/visualstudio/visual-studio-march-update-build-your-own-custom-agents/) | [Task delegation](https://github.blog/changelog/2026-02-17-delegate-tasks-to-copilot-coding-agent-from-visual-studio)
  - **JetBrains** gained custom agents, sub-agents, **Plan Agent (`GA`)**, agent hooks (`PREVIEW`), MCP auto-approve controls, auto model selection (`GA`), and instruction-file support for `AGENTS.md` and `CLAUDE.md`. [Plugin 1.6.1](https://plugins.jetbrains.com/plugin/17718-github-copilot--your-ai-pair-programmer/versions/stable/982717) | [Changelog](https://github.blog/changelog/2026-03-11-major-agentic-capabilities-improvements-in-github-copilot-for-jetbrains-ides)
  - **Xcode** did not get the same depth of agent-surface expansion, but it did keep model-picker parity with **Claude Opus 4.6 (`GA`)** and **Gemini 3.1 Pro (`PREVIEW`)**. [Claude Opus 4.6](https://github.blog/changelog/2026-02-18-claude-opus-4-6-is-now-available-in-visual-studio-jetbrains-ides-xcode-and-eclipse) | [Gemini 3.1 Pro](https://github.blog/changelog/2026-03-23-gemini-3-1-pro-is-now-available-in-jetbrains-ides-xcode-and-eclipse)

- **Model parity** also improved across non-VS Code IDEs. **Claude Opus 4.6 (`GA`)** expanded to **Visual Studio**, **JetBrains**, **Xcode**, and **Eclipse**, while **GPT-5.3-Codex** and **Gemini 3.1 Pro (`PREVIEW`)** broadened provider choice across the JetBrains and Xcode surfaces. [Claude Opus 4.6](https://github.blog/changelog/2026-02-18-claude-opus-4-6-is-now-available-in-visual-studio-jetbrains-ides-xcode-and-eclipse) | [GPT-5.3-Codex](https://github.blog/changelog/2026-02-25-gpt-5-3-codex-is-now-available-in-github-com-github-mobile-and-visual-studio) | [Gemini 3.1 Pro](https://github.blog/changelog/2026-03-23-gemini-3-1-pro-is-now-available-in-jetbrains-ides-xcode-and-eclipse)

---

# Enterprise and Security Updates

- **Copilot metrics (`GA`)** reached general availability and then expanded to cover plan mode, code review, CLI activity, and actual-model attribution. This is useful for engineering leaders because adoption can now be measured against real workflows instead of broad usage anecdotes. [GA](https://github.blog/changelog/2026-02-27-copilot-metrics-is-now-generally-available) | [Plan mode](https://github.blog/changelog/2026-03-02-copilot-metrics-now-includes-plan-mode) | [Actual model attribution](https://github.blog/changelog/2026-03-20-copilot-usage-metrics-now-resolve-auto-model-selection-to-actual-models) | [CLI totals](https://github.blog/changelog/2026-04-10-copilot-cli-activity-now-included-in-usage-metrics-totals-and-feature-breakdowns)

- **CLI activity** is now visible at enterprise, organization, and per-user levels in Copilot reporting. For platform teams trying to justify terminal-centric enablement work, this closes a major visibility gap. [Enterprise CLI activity](https://github.blog/changelog/2026-02-27-copilot-usage-metrics-now-includes-enterprise-level-github-copilot-cli-activity) | [User CLI activity](https://github.blog/changelog/2026-03-05-copilot-usage-metrics-now-includes-user-level-github-copilot-cli-activity) | [Organization reports](https://github.blog/changelog/2026-04-02-copilot-usage-metrics-now-includes-per-user-github-copilot-cli-activity-in-organization-reports)

- **Organization-wide policy controls (`GA`)** expanded in two important ways: **VS Code** gained a managed policy to disable the **Claude** agent, and GitHub made organization-level custom instructions generally available. Together, those changes strengthen central control over provider access and standardized guidance. [Disable Claude agent](https://code.visualstudio.com/updates/v1_114) | [Organization custom instructions](https://github.blog/changelog/2026-04-02-copilot-organization-custom-instructions-are-generally-available)

- **Interaction data usage policy** updates from GitHub are worth reading closely if legal, procurement, or internal AI governance is part of your rollout path. The company-news post plus the matching changelog entry are a stronger governance signal than a typical product update. [GitHub Blog](https://github.blog/news-insights/company-news/updates-to-github-copilot-interaction-data-usage-policy/) | [Changelog](https://github.blog/changelog/2026-03-25-updates-to-our-privacy-statement-and-terms-of-service-how-we-use-your-data)

- **EU data residency** now includes EFTA countries. For region-sensitive customers, this can remove friction in procurement and expand where GitHub-backed AI services can be considered for broader rollout. [Changelog](https://github.blog/changelog/2026-03-31-eu-data-residency-region-expanding-to-include-efta-countries)

- **Code Security risk assessment** is now available at the organization level, giving security leaders a more useful top-down exposure view than repository-by-repository review alone. [Changelog](https://github.blog/changelog/2026-04-08-code-security-risk-assessment-available-for-organizations)

- **Ask Copilot in security assessments** brings Copilot into a higher-trust security workflow. For customers already standardizing on GitHub Code Security, this is one of the more practical ways AI can reduce investigation time without leaving a governed surface. [Changelog](https://github.blog/changelog/2026-04-09-ask-copilot-in-security-assessments-now-available)

---

# GitHub Platform Updates

- **Explore a repository using Copilot on the web** helps onboarding, architecture review, and codebase research happen in GitHub.com without requiring a local IDE. [Changelog](https://github.blog/changelog/2026-03-11-explore-a-repository-using-copilot-on-the-web)

- **Ask Copilot to make changes to any pull request** moves review threads closer to executable remediation and can shorten the time from feedback to fix. [Changelog](https://github.blog/changelog/2026-03-24-ask-copilot-to-make-changes-to-any-pull-request)

- **Ask Copilot to resolve merge conflicts on pull requests** targets one of the most interruption-prone moments in team delivery, which is especially useful in busier release windows. [Changelog](https://github.blog/changelog/2026-03-26-ask-copilot-to-resolve-merge-conflicts-on-pull-requests)

- **Create issues from Slack with Copilot** improves traceability for teams that start triage in chat before formalizing the work in GitHub. [Changelog](https://github.blog/changelog/2026-03-30-create-issues-from-slack-with-copilot)

---

# Resources and Best Practices

- **Copilot CLI** remains pre-release. Review the [DPA-Covered Previews](https://docs.github.com/en/site-policy/github-terms/github-dpa-previews) and [Pre-Release License Terms](https://docs.github.com/en/site-policy/github-terms/github-pre-release-license-terms) before enabling it broadly. The full release history is available at [Copilot CLI Releases](https://github.com/github/copilot-cli/releases), and a representative stable build from this window is [v1.0.29](https://github.com/github/copilot-cli/releases/tag/v1.0.29).

- Stay up to date on the latest releases: [GitHub Copilot Changelog](https://github.blog/changelog/label/copilot/feed/), [VS Code Release Notes](https://code.visualstudio.com/updates/#_github-copilot), [Visual Studio Release Notes](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes#github-copilot), [JetBrains Plugin Updates](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable), [Xcode Releases](https://github.com/github/CopilotForXcode/blob/main/CHANGELOG.md), [GitHub Previews](https://github.com/features/preview), and [Preview Terms Changelog](https://docs.github.com/en/site-policy/github-terms/github-pre-release-license-terms).

- The governance baseline is much stronger than it was a few months ago. **Enterprise AI controls (`GA`)**, the **agent control plane (`GA`)**, **organization custom instructions (`GA`)**, and **Copilot metrics (`GA`)** now give enterprises a more complete starting point for scaling agentic workflows with policy and measurement. [Enterprise AI controls](https://github.blog/changelog/2026-02-26-enterprise-ai-controls-agent-control-plane-now-generally-available) | [Organization custom instructions](https://github.blog/changelog/2026-04-02-copilot-organization-custom-instructions-are-generally-available) | [Copilot metrics](https://github.blog/changelog/2026-02-27-copilot-metrics-is-now-generally-available)

---

# Webinars, Events, and Recordings

Brian's personally curated YouTube playlists, updated monthly: [Copilot Tips and Training Video](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D), [GitHub Enterprise, Actions, and GHAS videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ3wk4atKpN-yOW1FtyxN48W), [How GitHub GitHubs videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1nWhqxi-UQF_O-gYWo5jpG).

## Virtual Events

| Date | Event | Categories |
|------|-------|------------|
| Feb 17 | [Modernize your Java apps in days with AI Agents](https://developer.microsoft.com/en-us/reactor/events/26640) | Copilot |
| Feb 19 | [VS Code Live: Agent Sessions Day](https://developer.microsoft.com/en-us/reactor/events/26588) | Copilot |
| Feb 24 | [AI-powered workflows with GitHub and Azure DevOps](https://developer.microsoft.com/en-us/reactor/events/26641) | GitHub Platform |
| Mar 03 | [Get Secure and Stay Secure in the world of agentic AI](https://developer.microsoft.com/en-us/reactor/events/26642) | Enterprise |
| Mar 10 | [Root Cause Analysis with Code Context: Azure SRE Agent + GitHub Integration](https://developer.microsoft.com/en-us/reactor/events/26780) | GitHub Platform |
| Mar 17 | [Extend Azure SRE Agent: Custom Runbooks and Ecosystem Tools for Proactive Reliability](https://developer.microsoft.com/en-us/reactor/events/26781) | Developer Experience |
| Mar 19 | [VS Code Live: 1.110 Release](https://developer.microsoft.com/en-us/reactor/events/26589) | Copilot |
| Mar 24 | [Modernizing .NET at Scale with the GitHub Copilot App Mod Agent](https://developer.microsoft.com/en-us/reactor/events/26782) | Copilot |
| Mar 31 | [From Idea to Intelligent Agent: Build, Debug & Deploy AI Experiences Fast in VS Code](https://developer.microsoft.com/en-us/reactor/events/26783) | Copilot |
| Apr 07 | [Code to cloud: Fast-track delivery with GitHub Copilot and Azure](https://developer.microsoft.com/en-us/reactor/events/26784) | Copilot |
| Apr 14 | [Agentic DevOps Live: Moving Fast Without Breaking Things Using GitHub Code Quality](https://developer.microsoft.com/en-us/reactor/events/26785) | GitHub Platform |
| Apr 16 | [VS Code Live: April Recap of Releases](https://developer.microsoft.com/en-us/reactor/events/26590) | Copilot |

## In-Person Events

| Date | Location | Event |
|------|----------|-------|
| Apr 22 | Las Vegas, NV | [GitHub Social Club at The Oasis](https://github.registration.goldcast.io/events/7e9424cd-3b44-4d43-8c54-a72f4e6cb923) |
| Apr 22-24 | Las Vegas, NV | [GitHub Connect 2026](https://github.com/resources/events/github-gcn2026) |

## Behind the scenes

- Watch the [Copilot Fridays back catalog](https://resources.github.com/copilot-fridays-english-on-demand/), especially the sessions on prompt fundamentals, MLOps and data science, infrastructure engineering, and managed users for Copilot.
- This deterministic candidate set surfaced 21 deep links. After date and relevance screening, 12 in-range sessions remained for `2026-02-14` through `2026-04-16`.
- The GitHub Resources scrape also surfaced late-April follow-on links for [GitHub Connect 2026](https://github.com/resources/events/github-gcn2026) and the [GitHub Social Club at The Oasis](https://github.registration.goldcast.io/events/7e9424cd-3b44-4d43-8c54-a72f4e6cb923). They sit just beyond the pinned capture boundary, but they are the most relevant in-person GitHub events adjacent to this April distribution window.

---

If you have any questions or want to discuss these updates in detail, feel free to reach out. As always, I'm here to help you and your team stay informed and get the most value from GitHub.

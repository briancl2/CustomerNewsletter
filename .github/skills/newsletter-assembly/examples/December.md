# December 2025 Newsletter

This is a personally curated newsletter for my customers, focused on the most relevant GitHub updates this month. Highlights include comprehensive enterprise AI governance with Mission Control for managing autonomous agents at scale, the new GitHub Code Quality product for org-wide visibility into code maintainability, and massive expansion of agentic capabilities including Plan Agent, Custom Agents, and Auto Model Selection across all IDEs. If you have feedback or want to dive deeper into any topic, please let me know. Feel free to share this newsletter with your team. You can find an archive of past newsletters [here](https://github.com/briancl2/CustomerNewsletter).

---

# Enterprise AI Governance

**Mission Control for AI Agents** – GitHub introduces comprehensive enterprise controls for managing autonomous AI workflows at scale, giving organizations the visibility and governance needed to adopt agentic workflows safely.

- **Agent HQ & Enterprise AI Controls (`PREVIEW`)** – A centralized control plane for governing AI agents, including a Mission Control interface to assign, steer, and track Coding Agent tasks. Enterprises can now run coding agents on self-hosted runners for access to private resources and compliance with network policies, and configure the Coding Agent as a bypass actor for repository rulesets to enable fully automated merge workflows. - [Agent Control Plane](https://github.blog/changelog/2025-10-28-enterprise-ai-controls-the-agent-control-plane-are-in-public-preview) | [Mission Control](https://github.blog/changelog/2025-10-28-a-mission-control-to-assign-steer-and-track-copilot-coding-agent-tasks) | [Self-Hosted Runners](https://github.blog/changelog/2025-10-28-copilot-coding-agent-now-supports-self-hosted-runners) | [Ruleset Bypass](https://github.blog/changelog/2025-11-13-configure-copilot-coding-agent-as-a-bypass-actor-for-rulesets) | [Orchestration Guide](https://github.blog/ai-and-ml/github-copilot/how-to-orchestrate-agents-using-mission-control/)

- **Copilot Usage & Code Generation Dashboards (`PREVIEW`)** – Comprehensive reporting tools now track Copilot usage, acceptance rates, and active users via dashboard and API. The Code Generation Dashboard includes metrics for both users and agents, visualizing lines of code suggested and accepted to measure total impact. Includes fine-grain permissions so stakeholders can view ROI reports without full admin access. - [Usage Metrics](https://github.blog/changelog/2025-10-28-copilot-usage-metrics-dashboard-and-api-in-public-preview) | [Permissions](https://github.blog/changelog/2025-11-17-fine-grain-permissions-for-copilot-usage-metrics-now-available) | [Code Gen Docs](https://docs.github.com/en/enterprise-cloud@latest/copilot/reference/copilot-usage-metrics/copilot-usage-metrics#code-generation-dashboard-metrics)

- **Billing & Budget Controls** – New billing API updates allow enterprises to manage budgets and track usage programmatically. Budget tracking for GitHub AI tools provides financial governance and cost visibility. - [Billing API](https://github.blog/changelog/2025-11-03-manage-budgets-and-track-usage-with-new-billing-api-updates) | [Budget Tracking](https://github.blog/changelog/2025-11-03-control-ai-spending-with-budget-tracking-for-github-ai-tools)

- **AI Controls Delegation** – Delegate AI controls management to members of your enterprise, reducing bottlenecks on central admins while maintaining governance. - [Changelog](https://github.blog/changelog/2025-11-03-delegate-ai-controls-management-to-members-of-your-enterprise)

- **Enterprise Bring Your Own Key (BYOK) (`PREVIEW`)** – Connect your own LLM provider API keys to use custom or preferred models within GitHub Copilot. Usage is billed directly by your provider and does not count against GitHub Copilot request quotas, allowing teams to leverage existing contracts. Enterprise and organization admins can centrally manage which models are available. Available in github.com and supported IDEs. - [Changelog](https://github.blog/changelog/2025-11-20-enterprise-bring-your-own-key-byok-for-github-copilot-is-now-in-public-preview) | [Docs](https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-enterprise/use-your-own-api-keys)

- **Copilot Policy Updates** – New policy controls support agent mode in the IDE, ensuring agent usage aligns with corporate policy. Policy updates clarify handling for unconfigured policies. - [Agent Mode Policy](https://github.blog/changelog/2025-11-03-github-copilot-policy-now-supports-agent-mode-in-the-ide) | [Unconfigured Policies](https://github.blog/changelog/2025-11-04-github-copilot-policy-update-for-unconfigured-policies)

- **Enhanced Pre-Release License Terms: Indemnity & DPA Coverage** – GitHub has significantly improved protections for enterprise customers using preview features, addressing a common barrier to adoption:
  - **Defense of Third Party Claims (Indemnity)**: As of July 2025, the Pre-Release License Terms now include indemnity protection for pre-release software and AI-generated outputs, replacing the previous "No Indemnity" section.
  - **DPA-Covered Previews**: As of October 2025, certain preview features that have matured to production-level data handling are now governed by the [GitHub Data Protection Agreement](https://gh.io/dpa) instead of the default pre-release data terms, making the Customer the Data Controller. Currently covered: Copilot CLI, Copilot Usage Metrics Dashboard, and Spark (as of Oct 27, 2025).
  - **AI Data Ownership Clarified**: The June 2025 updates confirm that customers retain ownership of AI inputs, GitHub does not own AI outputs, and GitHub will not use inputs or outputs for model training unless instructed in writing.
  - [Pre-Release License Terms](https://docs.github.com/en/site-policy/github-terms/github-pre-release-license-terms) | [DPA-Covered Previews List](https://docs.github.com/en/site-policy/github-terms/github-dpa-previews) | [Terms Update Changelog](https://github.com/customer-terms/updates)

---

# GitHub Platform Updates

## GitHub Code Quality

**A New Era of Automated Code Quality** – GitHub Code Quality is a new product providing org-wide visibility, governance, and reporting to systematically improve code maintainability, reliability, and test coverage across your organization.

- **GitHub Code Quality (`PREVIEW`)** – Turns every PR into a structured quality checkpoint, reducing reviewer fatigue and enforcing consistent standards at scale. Provides organizational dashboards to track quality metrics and identify improvement opportunities. - [Announcement](https://github.blog/changelog/2025-10-28-github-code-quality-in-public-preview)

- **Copilot Code Review Enhancements and Agent-Specific Instructions (`PREVIEW`)** – Now integrates with GitHub Code Quality and linters to provide AI reviews that consider broader context and static analysis findings, reducing noise and improving review quality, and supports agent-specific instructions in Copilot code review and the coding agent so teams can fine-tune behavior to match their standards. - [Code Review](https://github.blog/changelog/2025-10-28-new-public-preview-features-in-copilot-code-review-ai-reviews-that-see-the-full-picture) | [Linter Integration](https://github.blog/changelog/2025-11-20-linter-integration-with-copilot-code-review-now-in-public-preview) | [Agent Instructions](https://github.blog/changelog/2025-11-12-copilot-code-review-and-coding-agent-now-support-agent-specific-instructions) | [Best Practices](https://github.blog/ai-and-ml/unlocking-the-full-power-of-copilot-code-review-master-your-instructions-files/)

- **Automated Security Remediation (`PREVIEW`)** – Assign code scanning alerts directly to Copilot for automated fixes, drastically reducing time to fix security vulnerabilities. Copilot coding agent now automatically validates code security and quality. - [Auto-Fix](https://github.blog/changelog/2025-10-28-assign-code-scanning-alerts-to-copilot-for-automated-fixes-in-public-preview) | [Auto Validation](https://github.blog/changelog/2025-10-28-copilot-coding-agent-now-automatically-validates-code-security-and-quality)

### GitHub Actions

- **Custom Images for GitHub-Hosted Runners (`PREVIEW`)** – Build custom virtual machine images tailored to your workflow needs, starting from GitHub-curated base images. This is a game-changer for enterprises that could not previously use GitHub Actions due to image restrictions. Benefits include faster workflows (preinstalled tools reduce setup time), hardened security (standardized environments with minimized attack surface), cost optimization (faster job starts mean fewer billed minutes), and enterprise-grade customization (certificates, proxies, monitoring agents). Admins can set lifecycle policies for version retention, unused image cleanup, and maximum age. - [Changelog](https://github.blog/changelog/2025-10-28-custom-images-for-github-hosted-runners-are-now-available-in-public-preview) | [Docs](https://docs.github.com/en/actions/how-tos/manage-runners/larger-runners/manage-larger-runners)

### GHAS & Microsoft Defender for Cloud Integration

- **Code-to-Cloud Risk Visibility with Microsoft Defender for Cloud (`PREVIEW`)** – Integration between GitHub Advanced Security and Microsoft Defender for Cloud provides unified code-to-runtime security visibility. The Virtual Registry makes GitHub a trusted source for artifact metadata, enabling teams to quickly determine if a vulnerability is running in production, exposed to sensitive workloads, or requires immediate action. Security campaigns can now filter alerts by runtime risk (internet exposed, sensitive data), and developers can bulk-assign security alerts to the Copilot coding agent for AI-assisted remediation. Early results show 50% of alerts fixed within the PR with 70% reduction in mean-time-to-remediation. - [Changelog](https://github.blog/changelog/2025-11-18-unified-code-to-cloud-artifact-risk-visibility-with-microsoft-defender-for-cloud-now-in-public-preview) | [Deep Dive](https://techcommunity.microsoft.com/blog/appsonazureblog/security-where-it-matters-runtime-context-and-ai-fixes-now-integrated-in-your-de/4470794)

---

# Copilot

### Latest Releases

- **Copilot Spaces: Public Spaces & Code View (`GA`)** – Copilot Spaces now supports Public Spaces for broader team collaboration and a new Code View for better context visualization. Spaces act as persistent knowledge hubs for projects, enabling faster onboarding and centralized expertise. Knowledge bases can now be converted to Spaces. - [Public Spaces](https://github.blog/changelog/2025-12-01-copilot-spaces-public-spaces-and-code-view-support) | [Convert Knowledge Bases](https://github.blog/changelog/2025-10-17-copilot-knowledge-bases-can-now-be-converted-to-copilot-spaces)

- **Copilot-Generated Commit Messages (`GA`)** – Commit message generation on github.com is now generally available, improving productivity by automating routine documentation. - [Changelog](https://github.blog/changelog/2025-10-15-copilot-generated-commit-messages-on-github-com-are-generally-available)

- **Resolve Merge Conflicts with AI (`GA`)** – New action to resolve git merge conflicts with AI, opening Chat view and starting an agentic flow with merge base and branch changes as context. - [VS Code](https://code.visualstudio.com/updates/v1_105#_resolve-merge-conflicts-with-ai)

### Copilot Agents Expansion

**Agentic Capabilities Everywhere** – A massive rollout of agentic capabilities across all IDEs transforms Copilot from a code completion tool into a proactive partner that can plan, execute, and validate complex tasks.

- **Plan Agent (`GA` in VS Code, `PREVIEW` elsewhere)** – Creates detailed implementation plans before coding. The Plan Agent helps break down complex tasks step-by-step, prompting for clarifying questions and generating a detailed implementation plan for user approval before execution. Now available across VS Code (`GA`), JetBrains, Eclipse, and Xcode (`PREVIEW`). - [VS Code](https://code.visualstudio.com/updates/v1_106#_plan-agent) | [JetBrains/Eclipse/Xcode](https://github.blog/changelog/2025-11-18-plan-mode-in-github-copilot-now-in-public-preview-in-jetbrains-eclipse-and-xcode)

- **Custom Agents & Advanced Orchestration** – A comprehensive suite of features to customize, delegate, and manage agent workflows, enabling teams to define tailored personas and orchestrate complex tasks across environments.
  - **Custom Agents (`GA` in VS Code, `PREVIEW` elsewhere)** – Define tailored team personas in `.github/agents`. Includes a vast ecosystem of Partner-Built Custom Agents for Observability, IaC, and Security (e.g., Dynatrace, Terraform, JFrog) that act as domain experts within the IDE and CLI. - [VS Code](https://code.visualstudio.com/updates/v1_106#_chat-modes-renamed-to-custom-agents) | [JetBrains/Eclipse/Xcode](https://github.blog/changelog/2025-11-18-custom-agents-available-in-github-copilot-for-jetbrains-eclipse-and-xcode-now-in-public-preview) | [Partner Announcement](https://github.blog/news-insights/product-news/your-stack-your-rules-introducing-custom-agents-in-github-copilot-for-observability-iac-and-security/) | [Catalog](https://github.com/github/awesome-copilot/blob/main/collections/partners.md) | [Create Your Own](https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-custom-agents)
  - **Isolated Subagents & Delegation (`GA` in VS Code, `PREVIEW` elsewhere)** – Delegate tasks to specialized sub-agents that operate in their own context window, or use `/delegate` to hand off tasks from the IDE/CLI to the cloud-based Copilot coding agent for background processing. - [VS Code](https://code.visualstudio.com/updates/v1_105#_isolated-subagents) | [JetBrains/Eclipse/Xcode](https://github.blog/changelog/2025-11-18-isolated-subagents-for-jetbrains-eclipse-and-xcode-now-in-public-preview) | [JetBrains /delegate](https://github.blog/changelog/2025-10-28-delegate-tasks-to-copilot-coding-agent-from-jetbrains-ides) | [CLI /delegate](https://github.blog/changelog/2025-10-28-github-copilot-cli-use-custom-agents-and-delegate-to-copilot-coding-agent)
  - **Session Management & Extensions** – The Agent Sessions View (`GA` in VS Code) centralizes management of active local and background tasks. Copilot Extensions (`PREVIEW`) now includes Slack Integration to trigger agent tasks directly from chat channels. - [Sessions View](https://code.visualstudio.com/updates/v1_106#_agent-sessions-view) | [Manage Tasks](https://github.blog/changelog/2025-11-13-manage-copilot-coding-agent-tasks-in-visual-studio-code) | [Copilot Extensions](https://docs.github.com/en/copilot/using-github-copilot/using-extensions-to-integrate-external-tools-with-copilot-chat)
  - **Organization Custom Instructions** – Copilot coding agent supports organization-level custom instructions, allowing enterprises to enforce coding standards and practices across all agent interactions. - [Changelog](https://github.blog/changelog/2025-11-05-copilot-coding-agent-supports-organization-custom-instructions)

- **Copilot CLI & Terminal Experience** – Significant enhancements including support for GPT-5.1-codex and Gemini 3 Pro models, enhanced code search within repositories, image support for error screenshots, and shell-specific prompt optimizations for PowerShell, bash, zsh, and fish. Note: Copilot CLI is covered under the GitHub Data Protection Agreement while in preview. - [Changelog](https://github.blog/changelog/2025-11-18-github-copilot-cli-new-models-enhanced-code-search-and-better-image-support) | [Getting Started](https://github.blog/ai-and-ml/github-copilot/github-copilot-cli-how-to-get-started/) | [DPA Coverage](https://docs.github.com/en/site-policy/github-terms/github-dpa-previews)

- **Web Search for Agents (`GA`)** – Agents can now search the web for up-to-date information, improving accuracy by allowing access to current external information. - [Changelog](https://github.blog/changelog/2025-10-16-copilot-coding-agent-can-now-search-the-web)

- **Assign Issues to Copilot via API** – Enterprises can now programmatically assign issues to the Copilot coding agent using GraphQL and REST APIs, enabling automated workflows and CI/CD integration. Configure target repositories, base branches, custom instructions, and custom agents programmatically. - [Changelog](https://github.blog/changelog/2025-12-03-assign-issues-to-copilot-using-the-api) | [Docs](https://docs.github.com/copilot/how-tos/use-copilot-agents/coding-agent/create-a-pr)

### Model Context Protocol (MCP)

**Deep and Broad MCP Expansion** – Major expansion of the MCP ecosystem enables standardized connections between Copilot and external tools, services, and data sources across all IDEs.

- **Enterprise Governance & Registry Controls** – Admins can now enforce organization-wide policies for MCP servers. MCP Server Access (`GA` in VS Code) allows controlling allowed servers via `chat.mcp.gallery.serviceUrl`, while Registry & Allowlist Controls (`PREVIEW`) extend governance to JetBrains, Eclipse, and Xcode. - [VS Code Access](https://code.visualstudio.com/updates/v1_106#_mcp-server-access-for-your-organization) | [Docs](https://docs.github.com/en/copilot/how-tos/administer-copilot/configure-mcp-server-access) | [Registry Controls](https://github.blog/changelog/2025-10-28-mcp-registry-and-allowlist-controls-for-copilot-in-jetbrains-eclipse-and-xcode-now-in-public-preview)

- **MCP Marketplace & Autostart (`PREVIEW`/`GA`)** – A built-in MCP Marketplace in VS Code simplifies discovery and installation from the GitHub registry. Autostart (`GA`) ensures servers launch automatically when needed, streamlining the user experience. - [Marketplace](https://code.visualstudio.com/updates/v1_105#_mcp-marketplace-preview) | [Registry Guide](https://github.blog/ai-and-ml/generative-ai/how-to-find-install-and-manage-mcp-servers-with-the-github-mcp-registry/) | [Autostart](https://code.visualstudio.com/updates/v1_105#_autostart-mcp-servers)

- **Dynamic OAuth for MCP Servers (`GA`)** – VS Code, JetBrains, Eclipse, and Xcode now support dynamic OAuth setup for third-party authentication. VS Code adds Client ID Metadata Document (CIMD) flow and dynamic scope step-up for secure, scalable MCP authentication. - [VS Code Auth](https://code.visualstudio.com/updates/v1_106) | [Enhanced OAuth](https://github.blog/changelog/2025-11-18-enhanced-mcp-oauth-support-for-github-copilot-in-jetbrains-eclipse-and-xcode)

- **Azure & GitHub Server Updates** – Visual Studio 2026 includes a built-in Azure MCP Server (`GA`) for agentic cloud workflows. The GitHub MCP Server now supports GitHub Projects, server instructions, and improved tools. - [Azure Announcement](https://devblogs.microsoft.com/visualstudio/azure-mcp-server-now-built-in-with-visual-studio-2026-a-new-era-for-agentic-workflows/) | [Projects Support](https://github.blog/changelog/2025-10-14-github-mcp-server-now-supports-github-projects-and-more) | [Server Updates](https://github.blog/changelog/2025-10-29-github-mcp-server-now-comes-with-server-instructions-better-tools-and-more)

### Model Availability Updates

- **Generally Available Models** – Claude Sonnet 4.5 (`GA`, Oct 13), Claude Haiku 4.5 (`GA`, Oct 20), and Grok Code Fast 1 (`GA`, Oct 16) are now generally available across all supported IDEs. These models provide enterprise developers with high-performance options for coding workflows. - [Claude Sonnet 4.5](https://github.blog/changelog/2025-10-13-anthropics-claude-sonnet-4-5-is-now-generally-available-in-github-copilot) | [Claude Haiku 4.5](https://github.blog/changelog/2025-10-20-claude-haiku-4-5-is-generally-available-in-all-supported-ides) | [Grok Code Fast 1](https://github.blog/changelog/2025-10-16-grok-code-fast-1-is-now-generally-available-in-github-copilot)

- **Preview Models** – Claude Opus 4.5 is now available across all major IDEs including Visual Studio, JetBrains, Xcode, and Eclipse (`PREVIEW`). This latest high-reasoning model cuts token usage in half while surpassing internal benchmarks. GPT-5.1, GPT-5.1-Codex, GPT-5.1-Codex-Mini, and GPT-5.1-Codex-Max (`PREVIEW`) provide next-generation reasoning for complex problem-solving and agentic workflows. Gemini 3 Pro (`PREVIEW`, Nov 18) adds Google's latest model to the ecosystem. - [Claude Opus 4.5](https://github.blog/changelog/2025-12-03-claude-opus-4-5-is-now-available-in-visual-studio-jetbrains-ides-xcode-and-eclipse) | [GPT-5.1 Series](https://github.blog/changelog/2025-11-13-openais-gpt-5-1-gpt-5-1-codex-and-gpt-5-1-codex-mini-are-now-in-public-preview-for-github-copilot) | [GPT-5.1-Codex-Max](https://github.blog/changelog/2025-12-04-openais-gpt-5-1-codex-max-is-now-in-public-preview-for-github-copilot) | [Gemini 3 Pro](https://github.blog/changelog/2025-11-18-gemini-3-pro-is-now-available-in-github-copilot-in-public-preview)

- **Auto Model Selection (`PREVIEW`)** – Copilot can now automatically select the best model for each task based on performance and availability, currently routing to GPT-5, GPT-5 mini, GPT-4.1, Sonnet 4.5, and Haiku 4.5. Available in VS Code, Visual Studio, JetBrains, Xcode, and Eclipse. Copilot Business and Enterprise subscribers get a 10% discount on the model multiplier when using Auto. - [VS](https://github.blog/changelog/2025-11-11-auto-model-selection-for-copilot-in-visual-studio-in-public-preview) | [JetBrains/Xcode/Eclipse](https://github.blog/changelog/2025-11-18-auto-model-selection-for-copilot-in-jetbrains-ides-xcode-and-eclipse-in-public-preview)

### Improved IDE Feature Parity

- **Visual Studio 2026 (`GA`)** – A major platform release featuring deep AI integration with specialized agents including the Debugger Agent for unit test diagnostics and the Profiler Agent for performance analysis. Includes built-in Azure MCP Server, Auto Model Selection (`PREVIEW`), Git Context in Copilot Chat, and a completely refreshed user experience. - [Launch Blog](https://devblogs.microsoft.com/visualstudio/visual-studio-2026-is-here-faster-smarter-and-a-hit-with-early-adopters/) | [Release Notes](https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes) | [Profiler Agent](https://devblogs.microsoft.com/visualstudio/delegate-the-analysis-not-the-performance/)

- **JetBrains IDEs** – Gains Agent Mode (`GA`), Plan Mode (`PREVIEW`), Custom Agents (`PREVIEW`), Isolated Subagents (`PREVIEW`), Auto Model Selection (`PREVIEW`), Delegate to Coding Agent (`PREVIEW`), Enhanced MCP OAuth (`PREVIEW`), and GPT-5.1 Models (`PREVIEW`). Note: Most advanced agent features require enabling the "Editor preview features" and "Copilot coding agent" policies. - [Agent Mode GA](https://github.blog/changelog/2025-07-16-agent-mode-for-jetbrains-eclipse-and-xcode-is-now-generally-available) | [Plugin Updates](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable)

- **Eclipse** – Gains Copilot Coding Agent (`PREVIEW`), Plan Mode (`PREVIEW`), Next Edit Suggestions (`PREVIEW`), Custom Agents (`PREVIEW`), Auto Model Selection (`PREVIEW`), and MCP Registry Controls (`PREVIEW`). - [Coding Agent](https://github.blog/changelog/2025-11-18-github-copilot-coding-agent-for-eclipse-now-in-public-preview) | [NES](https://github.blog/changelog/2025-11-18-github-copilot-next-edit-suggestions-nes-now-in-public-preview-for-xcode-and-eclipse)

- **Xcode** – Gains Plan Agent (`PREVIEW`), Custom Agents (`PREVIEW`), Subagent Execution (`PREVIEW`), Next Edit Suggestions (`PREVIEW`), Auto Model Selection (`PREVIEW`), Dynamic OAuth for MCP (`GA`), and support for GPT-5.1, Claude Haiku 4.5, Grok Code Fast 1, Claude Sonnet 4.5, and Claude Opus 4 models. - [v0.45.0](https://github.com/github/CopilotForXcode/blob/main/CHANGELOG.md#0450---november-14-2025) | [v0.44.0](https://github.com/github/CopilotForXcode/blob/main/CHANGELOG.md#0440---october-15-2025)

> Note: Copilot features typically follow a predictable pattern in their release cycle, starting in VS Code (usually in `PREVIEW`), then rolling out to Visual Studio and JetBrains IDEs, followed by Eclipse and Xcode.

## Copilot at Scale

### Enablement & Rollout Strategy

- **Building a Copilot Enablement Program That Works** – A practical blueprint for large Copilot rollouts that goes beyond "turn on licenses." Recommends a phased approach with role-aware training, recurring office hours, show-and-tell sessions, internal champions, and explicit handling of security/compliance concerns. Ideal for platform teams planning 2026 programs. - [Article](https://colinsalmcorner.com/building-copilot-enablement-program/)

- **Teaching Your Team to Think Async-First** – Focuses on mindset change: treating Copilot and agents as async collaborators that handle test generation, documentation, and spike implementations while humans focus on design and review. Includes guidance on adapting standups and code review ceremonies for agentic workflows. - [Article](https://colinsalmcorner.com/teaching-async-thinking-with-copilot/)

- **Fostering AI Learning Opportunities** – GitHub Enterprise guidance on building structured AI learning programs, communities of practice, and safe spaces for experimentation. Connects directly to sustained AI upskilling beyond one-off training. - [GitHub Resources](https://resources.github.com/enterprise/fostering-ai-learning-opportunities/)

### Enterprise Reference Stories

- **VA's Strategy for Adopting High-Impact AI** – The US Department of Veterans Affairs describes their AI strategy combining VA GPT, Teams Premium, and GitHub Copilot. Reports ~10 hours saved per user per month at ~$1.25 per user. A strong governance-aligned reference for healthcare, government, and other regulated enterprises. - [VA.gov](https://department.va.gov/ai/building-the-future-vas-strategy-for-adopting-high-impact-artificial-intelligence-to-improve-services-for-veterans/)

- **GitHub Billing Team Technical Debt Case Study** – Real-world example of how GitHub's billing team uses the Coding Agent to continuously tackle technical debt, showing practical applications for enterprise teams. - [Case Study](https://github.blog/ai-and-ml/github-copilot/how-the-github-billing-team-uses-the-coding-agent-in-github-copilot-to-continuously-burn-down-technical-debt/)

### Developer Resources

- **Awesome Copilot Repo (now with Awesome Agents)** – Community-driven collection of custom instructions, reusable prompts, custom agents, and MCP servers to standardize team guidance and scale consistent outcomes across repos and IDEs. - [Repo](https://github.com/github/awesome-copilot)

- **How to Write a Great agents.md** – Practical guide based on analysis of over 2,500 repositories showing what makes custom agents effective. Covers the six core areas (commands, testing, project structure, code style, git workflow, and boundaries), includes starter templates, and examples of agents worth building (@docs-agent, @test-agent, @lint-agent, @api-agent). - [Article](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/)

- **How to Use Copilot Spaces for Faster Debugging** – Step-by-step guide to using Copilot Spaces as project knowledge bundles for debugging issues. Create a space with the issue, key files, design docs, and security guidelines, then let Copilot reason across everything to generate a grounded implementation plan. Approve the plan and trigger the Copilot coding agent to generate a PR with citations to the exact files that informed each fix. Spaces are also available in your IDE via the GitHub MCP Server. - [Article](https://github.blog/ai-and-ml/github-copilot/how-to-use-github-copilot-spaces-to-debug-issues-faster/) | [Video Demo](https://www.youtube.com/watch?v=noVdaj7sEWA)

- **Spec-Kit for Spec-Driven Development** – A framework for creating structured specifications that improve AI code generation quality and consistency. Use spec-driven development to get better, more predictable results from Copilot and coding agents. - [Repo](https://github.com/github/spec-kit) | [Announcement](https://developer.microsoft.com/blog/spec-driven-development-spec-kit) | [Video](https://www.youtube.com/watch?v=xgnIBh25a5A)

- **Agent Package Manager (APM)** – Package manager for AI agents (like npm for agents) that enables dependency management for agents, prompts, and context. Stop copy-pasting instructions and start packaging reusable AI workflows. Works with GitHub Copilot, Cursor, Claude, and all AGENTS.md adherents. Includes context optimization engine for scalable agent architectures. - [Repo](https://github.com/danielmeppiel/apm) | [Getting Started](https://github.com/danielmeppiel/apm/blob/main/docs/getting-started.md)

- **AI-Assisted Modernization Pattern (Martin Fowler)** – A three-stage "research, review, rebuild" approach to modernizing legacy systems using AI. Highly relevant for healthcare and regulated customers contemplating multi-year modernization of critical systems alongside Copilot and coding agent. - [Article](https://martinfowler.com/articles/research-review-rebuild.html)

### Stay up to date on the latest releases

- [GitHub Copilot Changelog](https://github.blog/changelog/label/copilot/feed/)
- [VS Code Copilot Changelog](https://code.visualstudio.com/updates/#_github-copilot)
- [Visual Studio Copilot Changelog](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes#github-copilot)
- [JetBrains Copilot Changelog](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable)
- [XCode Copilot Changelog](https://github.com/github/CopilotForXcode/blob/main/ReleaseNotes.md)
- [Eclipse Copilot Changelog](https://marketplace.eclipse.org/content/github-copilot#details)

---

# Webinars, Events, and Recordings

Brian's personally curated YouTube playlists, updated monthly: [Copilot Tips and Training Video](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D), [GitHub Enterprise, Actions, and GHAS videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ3wk4atKpN-yOW1FtyxN48W), [How GitHub GitHubs videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1nWhqxi-UQF_O-gYWo5jpG)

### Upcoming Virtual Events

Also, watch the [Copilot Fridays back catalog](https://resources.github.com/copilot-fridays-english-on-demand/): Prompt Fundamentals, Copilot for MLOps/Data Science, Copilot for Infrastructure Engineers, GitHub Enterprise Managed Users for Copilot Users

| Date | Event | Category |
|------|-------|----------|
| Dec 09 | Spark to Rocket Ship: Turbocharging Your MVP with AI-Powered Development | Copilot |
| Dec 10 | AI Dev Days: Building AI Applications | Copilot |
| Dec 11 | AI Dev Days: Using AI to Enhance Developer Productivity | Copilot |
| Dec 11 | VS Code Live: 1.107 Release | Copilot |
| Dec 11 | GitHub Winterfest | GitHub Platform |
| Dec 11 | Securing Your CI/CD Pipelines: Best Practices and Strategies | Enterprise |

---

If you have any questions or want to discuss these updates in detail, feel free to reach out. As always, I'm here to help you and your team stay informed and get the most value from GitHub.

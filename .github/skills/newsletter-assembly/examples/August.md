# August 2025 Newsletter

This is a personally curated newsletter for my customers, focused on the most relevant GitHub updates this month. Highlights include GA MCP support in VS Code for standardized tool access, richer Copilot code review and model updates, a new Copilot activity report for enterprise visibility, billing and cost center improvements, and enhanced legal protections for preview features. You will also find practical playbooks for rollout and enablement, plus developer resources to standardize instructions, chat modes, and agent workflows. If you have feedback or want to dive deeper into any topic, please let me know. Feel free to share this newsletter with your team. You can find an archive of past newsletters [here](https://github.com/briancl2/CustomerNewsletter).

---

# Copilot

### Latest Releases

- **Model Context Protocol in VS Code (GA)** – VS Code delivered Model Context Protocol support and stronger governance, bringing consistent tool integration, improved reliability, and safer automation for enterprise teams. Establish a standard way to connect internal tools and data to Copilot, with autostart, trust controls, and remote client credentials. - [[Docs]](https://code.visualstudio.com/docs/copilot/chat/mcp-servers) [[Release Notes]](https://code.visualstudio.com/updates/v1_103) [[Changelog]](https://github.blog/changelog/2025-07-14-model-context-protocol-mcp-support-in-vs-code-is-generally-available)

- **Admin and customization controls** – Copilot Chat in VS Code is now open source and adds Generate Instructions for your workspace plus per‑mode model selection in custom chat modes, making it easier to standardize team guidance and share reusable configurations. - [[Release Notes]](https://code.visualstudio.com/updates/v1_102)

- **Copilot code review honors `copilot instructions.md` (`GA`)** – Align automated insights with team standards by codifying guidance at the repository level, which improves review quality and reduces rework. - [[Changelog]](https://github.blog/changelog/2025-08-06-copilot-code-review-copilot-instruction-md-support-is-now-generally-available/) [[How to level up code reviews]](https://github.blog/ai-and-ml/github-copilot/how-to-use-github-copilot-to-level-up-your-code-reviews-and-pull-requests/)

- **Copilot Chat on GitHub.com, richer interactions (`GA`)** – Side panel file iteration, instant previews, message edit and reload, and improved attachments are available on GitHub.com for Copilot Chat. - [[Changelog]](https://github.blog/changelog/2025-07-09-new-copilot-chat-features-now-generally-available-on-github)

- **Coding agent custom instructions (`PREVIEW`)** – Repositories can define `AGENTS.md` (with support for nested variants) to guide build, test, and validation steps, and you can auto generate instructions from repository context to reduce setup time. - [[Agent best practices]](https://docs.github.com/enterprise-cloud@latest/copilot/tutorials/coding-agent/get-the-best-results) [[Changelog, AGENTS.md]](https://github.blog/changelog/2025-08-28-copilot-coding-agent-now-supports-agents-md-custom-instructions/) [[Changelog, auto generate]](https://github.blog/changelog/2025-08-06-copilot-coding-agent-automatically-generate-custom-instructions/)

- **Copilot Spaces adds full repository context (`PREVIEW`)** – Add entire repositories to a Space for faster onboarding to unfamiliar services while still prioritizing critical files. - [[Changelog]](https://github.blog/changelog/2025-08-13-add-repositories-to-spaces)

- **Model availability updates (`GA` and `PREVIEW`)** – Completions now use the GPT 4.1 Copilot model (`GA`) and Gemini 2.5 Pro is available for Copilot with admin enablement (`GA`). Preview models include OpenAI GPT 5, GPT 5 mini, Grok Code Fast 1, and Anthropic Claude Opus 4.1. - [[Changelog, completions on GPT 4.1]](https://github.blog/changelog/2025-08-27-copilot-code-completion-now-uses-the-gpt-4-1-copilot-model/) [[Changelog, Gemini 2.5 Pro]](https://github.blog/changelog/2025-08-19-gemini-2-5-pro-is-generally-available-in-copilot) [[Changelog, GPT 5]](https://github.blog/changelog/2025-08-12-openai-gpt-5-is-now-available-in-public-preview-in-visual-studio-jetbrains-ides-xcode-and-eclipse/) [[Changelog, GPT 5 mini]](https://github.blog/changelog/2025-08-13-gpt-5-mini-now-available-in-github-copilot-in-public-preview/) [[Changelog, Grok Code Fast 1]](https://github.blog/changelog/2025-08-26-grok-code-fast-1-is-now-available-in-public-preview-in-github-copilot/)

### Improved IDE Feature Parity

- **Visual Studio 17.14 August update** – Smarter chat, better debugging, and more control, plus bring your own model options. - [[Announcement]](https://devblogs.microsoft.com/visualstudio/the-visual-studio-august-update-is-here-smarter-ai-better-debugging-and-more-control/) [[Changelog]](https://github.blog/changelog/2025-08-28-github-copilot-in-visual-studio-august-update/)

- **Cross-Platform Updates** – JetBrains, Eclipse, and Xcode now have agent mode `GA`, MCP support `GA`, and targeted usability upgrades. JetBrains/Eclipse/Xcode: [agent mode](https://github.blog/changelog/2025-07-16-agent-mode-for-jetbrains-eclipse-and-xcode-is-now-generally-available/), [MCP support](https://github.blog/changelog/2025-08-13-model-context-protocol-mcp-support-for-jetbrains-eclipse-and-xcode-is-now-generally-available/). Eclipse adds one click commit messages, MCP logs, and `@workspace` context: [details](https://github.blog/changelog/2025-07-22-github-copilot-in-eclipse-smarter-faster-and-more-integrated). Xcode now has Copilot code review `GA` with a new admin control: [details](https://github.blog/changelog/2025-08-27-copilot-code-review-generally-available-in-xcode-and-new-admin-control/).

- **JetBrains, Next Edit Suggestions (NES) (`PREVIEW`)** – Proactive inline next edit suggestions to improve, refactor, and fix code as you work. Enable via Settings → GitHub Copilot → Completions, check Enable Next Edit Suggestions (NES), then review and apply inline (Tab or gutter). - [[Changelog]](https://github.blog/changelog/2025-08-29-copilots-next-edit-suggestion-nes-in-public-preview-in-jetbrains/)

> Note: Copilot features typically follow a predictable pattern in their release cycle, starting in VS Code (usually in `PREVIEW`), then rolling out to Visual Studio and JetBrains IDEs, followed by Eclipse and Xcode.

## Copilot at Scale

- **New Copilot activity report with authentication and usage insights** – Enterprise and organization admins can download a refreshed activity report with 30 minute updates, `last_authenticated_at`, detailed `last_surface_used` (IDE versions and GitHub.com features), 90 day retention, and coverage across all GA Copilot surfaces. Use it to track adoption, improve license management, and strengthen compliance reporting. The legacy usage report will sunset on October 23, 2025, plan to transition. - [[Changelog]](https://github.blog/changelog/2025-07-18-new-github-copilot-activity-report-with-enhanced-authentication-and-usage-insights/) [[Metrics data properties]](https://docs.github.com/en/copilot/reference/metrics-data#copilot-activity-report) [[Download activity report]](https://docs.github.com/en/copilot/how-tos/administer/download-activity-report) [[Manage Copilot access]](https://docs.github.com/copilot/how-tos/manage-your-account)

- **Metered billing for Visual Studio subscriptions with GitHub Enterprise (`GA`)** – Simplifies cost allocation and reduces manual reconciliation across Microsoft developer subscriptions. - [[Changelog]](https://github.blog/changelog/2025-08-14-introducing-metered-github-enterprise-billing-for-visual-studio-subscriptions-with-github-enterprise/) [[Visual Studio release notes]](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes)

- **Cost centers, add or move users via UI or API** – Enterprise admins and billing managers can search, add, remove, and reassign users, enabling cleaner chargeback and budget control. - [[Changelog]](https://github.blog/changelog/2025-08-18-customers-can-now-add-users-to-a-cost-center-from-both-the-ui-and-api-2) [[Docs]](https://docs.github.com/enterprise-cloud@latest/billing/tutorials/use-cost-centers)

- **Governance roundup** – Enforce stronger policy and auditability with Actions policy to block unapproved actions and require SHA pinning (`GA`), releases immutability (`PREVIEW`), dependencies on issues (`GA`) for planning, and improved repository creation and ruleset insights (`GA`). - [[Actions policy pinning]](https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/) [[Releases immutability]](https://github.blog/changelog/2025-08-26-releases-now-support-immutability-in-public-preview/) [[Dependencies on issues]](https://github.blog/changelog/2025-08-21-dependencies-on-issues/) [[Repo creation improvements]](https://github.blog/changelog/2025-08-26-improved-repository-creation-generally-available-plus-ruleset-insights-improvements/)

- **Legal protections for pre-release features, volume licensing** – Indemnity coverage now applies to pre-release software and its outputs for customers under a GitHub Customer Agreement or Microsoft volume licensing agreement. The previous no indemnity language was removed, and the usual liability cap does not apply to these indemnity protections. Individual plans are not affected. - [[Announcement]](https://github.blog/changelog/2025-08-08-defense-of-third-party-claims-added-for-volume-licensing-customers/) [[Pre-release license terms]](https://docs.github.com/site-policy/github-terms/github-pre-release-license-terms) [[GitHub Preview Terms Changelog]](https://github.com/customer-terms/updates)

- **Secret risk assessment and push protection custom patterns (`GA`)** – Quantify leaked secret risk across your org and tailor push protection to reduce false positives, then accelerate remediation with better prioritization. - [[Secret risk assessment]](https://github.blog/changelog/2025-08-26-the-secret-risk-assessment-is-generally-available/) [[Push protection patterns]](https://github.blog/changelog/2025-08-19-secret-scanning-configuring-patterns-in-push-protection-is-now-generally-available/) [[Secret scanning docs]](https://docs.github.com/code-security/secret-scanning)

### Developer resources and tooling

- **Awesome GitHub Copilot Customizations** – Community driven custom instructions, reusable prompts, and custom chat modes to standardize team guidance and scale consistent outcomes across repos and IDEs. - [[Announcement]](https://devblogs.microsoft.com/blog/introducing-awesome-github-copilot-customizations-repo) | [[Repo]](https://github.com/github/awesome-copilot)

- **Awesome AI Native, getting started** – A systematic framework for instructions architecture, chat modes with MCP tool boundaries, agentic workflows, and specification templates to operationalize AI safely at scale. - [[Getting started]](https://danielmeppiel.github.io/awesome-ai-native/docs/getting-started/)

- **Agent TODOs for VS Code** – Persistent AI memory for agent mode, adds `todo_read` and `todo_write` tools, workflow state management, and auto sync into `copilot-instructions.md` for better context retention across sessions. - [[Marketplace]](https://marketplace.visualstudio.com/items?itemName=digitarald.agent-todos)

### Resources for rollout, enablement, and governance

- **GitHub Roadmap webinar, Q3 2025 (on demand)** – Walkthrough of latest product updates and roadmap priorities, including agent powered experiences and MCP enhancements, led by GitHub's Chief Product Officer. - [[On demand webinar]](https://resources.github.com/webcasts/github-roadmap-webinar-q3-americas-europe/)

- **GitHub Resources, Enterprise hub** – Curated guidance for leaders and platform teams rolling out Copilot at scale. - [[Enterprise hub]](https://resources.github.com/enterprise/)
  - **AI powered workforce playbook** – Eight pillars to scale AI fluency, with phased measurement for adoption and impact. - [[Playbook]](https://resources.github.com/enterprise/ai-powered-workforce-playbook/)
  - **Activating internal AI champions** – Build and scale a volunteer advocate network in three phases, with cadence and impact measures. - [[Advocates guide]](https://resources.github.com/enterprise/activating-internal-ai-champions/)
  - **Copilot adoption, rollout, and impact** – Subscription choices, policies, networking, access models, and experience enhancers (coding agent, code review, Spaces). - [[Rollout guide]](https://resources.github.com/enterprise/copilot-adoption-rollout-impact/)
  - **Human oversight in modern code reviews** – Balance AI reviews with human judgement, keep changes small, counter confirmation bias. - [[Guide]](https://resources.github.com/enterprise/human-oversight-modern-code-review/)

- **Admin playbook, Premium Request Units (PRUs)** – Enterprise best practices to budget, monitor, and govern premium model usage and advanced features, with KPIs, alerts, cost center patterns, and escalation workflows. - [[PRU admin playbook]](https://wellarchitected.github.com/library/governance/recommendations/copilot-policies-best-practices/copilot_pru_enterprise_admin_playbook/)

- **Self-serve Product Guides hub** – Central access to GitHub product guides that help admins and leaders plan and operationalize adoption. - [[Product guides hub]](https://support.github.com/success/product-guides)

### Stay up to date on the latest releases and legal terms

- [GitHub Previews](https://github.com/features/preview) and [GitHub Preview Terms Changelog](https://github.com/customer-terms/updates)
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
| Sep 02 | Episode 1 - Build Smarter, Ship Faster — with GitHub Copilot Agent Mode | Copilot, Advanced |
| Sep 04 | Copilot Friday: Unlocking Deep Context with Copilot Spaces | Copilot, New Features |
| Sep 10 | Securing the Vibe Coding Era with GitHub and Endor Labs | GHAS, Security |
| Sep 11 | Prompt Like a Pro: Learn Prompt Engineering Techniques to Unlock AI's Full Potential | Copilot, Advanced |
| Sep 11 | AppSec Monthly (GHAS) — September Session | GHAS |
| Sep 11 | VS Code Live: 1.104 Release | Copilot, New Features |
| Sep 18 | Copilot Friday: Which Copilot is right for you? Demystifying the Editions | Copilot |
| Sep 23 | VS Code Dev Days: APAC | Copilot |
| Sep 25 | VS Code Dev Days: Worldwide | Copilot |
| Oct 09 | AppSec Monthly (GHAS) — October Session | GHAS |
| Oct 16 | VS Code Live: 1.105 Release | Copilot, New Features |
| Oct 23 | Python + AI: Model Context Protocol | Copilot, New Features |
| Nov 13 | AppSec Monthly (GHAS) — November Session | GHAS |
| Dec 11 | AppSec Monthly (GHAS) — December Session | GHAS |

### Upcoming In-person Events

- **San Francisco, CA — Oct 28–29** — [GitHub Universe 2025](https://githubuniverse.com/) (Hybrid, virtual attendance available) — Two-day developer event with keynotes, sessions, and product announcements at Fort Mason Center. Categories: Product Roadmap, Developer Productivity.
- **San Francisco, CA — Sep 29–30** — [Git Merge 2025](https://git-merge.com/) (Hybrid, virtual attendance available) — Celebrating 20 years of Git with talks for maintainers and enterprise-scale teams. Categories: Platform, Developer Productivity.
- **Chicago, IL — Sep 25** — [Microsoft AI Tour — Chicago](https://aitour.microsoft.com/flow/microsoft/chicago26/landingpage/page/cityhome) — Free, one-day AI event at McCormick Place with keynotes, breakouts, and hands-on sessions. Categories: Platform, Developer Productivity.
- **Mississauga, ON (Toronto area) — Oct 01** — [Microsoft AI Tour — Toronto](https://aitour.microsoft.com/flow/microsoft/toronto26/landingpage/page/cityhome) — Free, one-day AI event at The International Centre with keynotes and technical sessions. Categories: Platform, Developer Productivity.
- **Frankfurt, Germany — Date TBA** — [Microsoft AI Tour — Frankfurt](https://aitour.microsoft.com/flow/microsoft/frankfurt26/landingpage/page/cityhome) — City page accessible; agenda and date not visible without sign-in at this time. Categories: Platform.

---

If you have any questions or want to discuss these updates in detail, feel free to reach out. I welcome your feedback, and please let me know if you would like to add or remove anyone from this list.

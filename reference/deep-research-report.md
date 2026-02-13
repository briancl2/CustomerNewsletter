# Canonical Sources of Truth Knowledge Base for GitHub Copilot

## Scope and research methodology

AS_OF_DATE and LAST_RUN_DATE for this run are both **2026-02-10** (America/Chicago). This knowledge base is anchored on official documentation and release streams from entity["company","GitHub","software development platform"], entity["company","Microsoft","software company"], entity["company","JetBrains","software company"], entity["company","OpenAI","ai company"], entity["company","Anthropic","ai company"], and entity["organization","Eclipse Foundation","open source foundation"]. citeturn51view1turn22view0turn25view0turn32view0turn54search3turn54search2turn16view0

Canonicality and surface coverage were validated primarily via:
- The Copilot feature matrix (surface and feature anchoring). citeturn51view1turn52view0
- GitHub Docs for customization primitives (custom instructions, agent instruction files, prompt files, and MCP). citeturn28view3turn30view0turn31view1turn27view3
- Per-surface release notes and changelog entries for “what changed” tracking (for example Copilot in VS Code monthly release notes, Copilot in Visual Studio monthly update, metrics API retirement dates). citeturn19view0turn18view1turn21view0
- Distribution channels where version truth lives (GitHub Releases, IDE marketplaces, IDE release notes). citeturn8view0turn47view0turn16view0turn22view0turn25view0

The repo content generated below follows the non-negotiable portability bias: reusable skills and instruction assets are centralized under `.agents/skills` in guidance, while Copilot-specific file conventions are treated as platform artifacts that can be generated or synchronized. Support for `.github/copilot-instructions.md`, `.github/prompts/*.prompt.md`, and agent instruction files like `AGENTS.md` is documented as behavior, but this KB does not recommend `.github/instructions` as a default location (it is documented as a Copilot-supported, but portability-disfavored legacy path). citeturn30view0turn31view1turn28view3

## Key findings for canonical sources and cross-surface portability

The Copilot feature matrix is the best single official anchor for “what features exist by surface,” but it can lag behind marketplace and GitHub Release streams for specific IDE extensions (for example JetBrains and Xcode show newer versions in their own channels than the matrix’s “latest releases” tables). citeturn51view2turn47view0turn36search15

Custom instruction behavior is now explicitly standardized in GitHub Docs across multiple environments: repository-wide instructions in `.github/copilot-instructions.md`, path-specific instructions under `.github/instructions/**/*.instructions.md`, plus “agent instruction” files such as `AGENTS.md`, `CLAUDE.md`, and `GEMINI.md` (support varies by surface and feature). citeturn30view0turn28view3

Prompt files are a distinct customization primitive from instructions: they are Markdown files with the file extension `*.prompt.md`, stored under `.github/prompts`, and are explicitly documented as being in public preview and limited to VS Code, Visual Studio, and JetBrains IDEs. citeturn31view1turn28view3

Recent release signals that materially affect governance and monitoring include:
- Legacy Copilot metrics API retirements with concrete sunset dates (March 2, 2026 and April 2, 2026), and a migration recommendation to newer usage metrics endpoints. citeturn21view0
- Model availability shifts (for example GPT-5.3-Codex rollout across multiple Copilot clients, plus partner coding agents in public preview). citeturn18view2turn21view2
- A new officially supported Copilot surface, OpenCode, announced via GitHub Changelog, which must be monitored as part of the ecosystem inventory. citeturn4search3

## Repo-ready file set

### `/README.md`
```md
# Canonical “Sources of Truth” KB for GitHub Copilot

This repository is a curated, deduplicated knowledge base of canonical “sources of truth” for the GitHub Copilot ecosystem across supported surfaces (web, IDEs, terminal, and adjacent agent workflows).

It is designed to support:
- Staying up to date on Copilot features and releases across surfaces
- Learning how to use those features and releases
- Tracking evolving best practices (prompting, evals, orchestration, governance)
- Discovering adjacent frameworks, standards, and skill repositories that integrate with Copilot workflows
- Generating a monthly “what changed” snapshot and newsletter-ready inputs

Portability bias:
- Default location for reusable skills and instruction assets: `.agents/skills`
- Platform-specific file conventions are documented as exceptions (and labeled)
- This KB does not recommend `.github/instructions` as a default pattern (documented only as Copilot-supported legacy behavior)

Quick links:
- `/kb/KB_INDEX.md`
- `/kb/CURRENT_STATE_SNAPSHOT.md`

Monthly refresh:
- See `/kb/MAINTENANCE_RUNBOOK.md`

License:
- MIT (see `/LICENSE`)
```

### `/LICENSE`
```text
MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### `/kb/KB_INDEX.md`
```md
# KB Index

State:
- AS_OF_DATE: 2026-02-10
- LAST_RUN_DATE: 2026-02-10

Purpose
This KB is a canonical, curated index of “sources of truth” for GitHub Copilot across supported surfaces, plus a portable best-practices library for AI-assisted software development and agentic workflows.

Audiences
- Developers using Copilot across different IDEs and clients
- Engineering enablement and platform teams
- AI governance and security stakeholders
- Tooling teams building repeatable workflows (skills, eval harnesses, prompt assets)

Definitions
- Source of truth: The most authoritative, primary place where a fact should be verified (official docs, official changelog, official release notes, official repository release stream)
- Surface: A Copilot-capable client or environment (web, VS Code, Visual Studio, JetBrains, Xcode, Eclipse, CLI, terminal, OpenCode)
- Canonical vs secondary: Canonical sources are official. Secondary sources are community or practitioner resources that remain useful but should be treated as non-authoritative.
- Feed: A machine-readable update mechanism (RSS, Atom, GitHub Releases Atom, official APIs) or a stable page to poll.

Repo navigation
- TAXONOMY: `/kb/TAXONOMY.md`
- Section A (Primary platforms): `/kb/SECTION_A_PRIMARY_PLATFORMS.md`
- Section B (Frameworks and resources): `/kb/SECTION_B_FRAMEWORKS.md`
- Section C (Portable best practices): `/kb/SECTION_C_BEST_PRACTICES.md`
- Section D (Thought leadership): `/kb/SECTION_D_THOUGHT_LEADERSHIP.md`
- Snapshot: `/kb/CURRENT_STATE_SNAPSHOT.md`
- Sources index (machine-readable): `/kb/SOURCES.yaml`
- Maintenance runbook: `/kb/MAINTENANCE_RUNBOOK.md`
- Research method: `/kb/RESEARCH_METHOD.md`
- Run log (this run): `/kb/RUN_LOG_2026-02-10.md`
- KB changelog: `/kb/CHANGELOG.md`

Governance rules
Inclusion criteria
- Prefer official docs and official release notes streams.
- Include community/practitioner sources only if operationally concrete and clearly labeled as non-canonical.

Dedupe policy
- One “source record” per logical source stream. Multiple URLs for the same stream belong in one record.
- Prefer stable URLs over deep anchors.

Deprecation handling
- If official guidance moves, mark the old source as deprecated in SOURCES.yaml and document the migration path.
- Portability-disfavored platform conventions may be documented as “deprecated (by portability policy)” even if still supported by a given client.

Portability policy summary
Default: `.agents/skills` for reusable skills and instruction assets.
Platform exceptions (documented in Section C and Section A):
- `.github/copilot-instructions.md` is an official Copilot repository-wide instruction file.
- `.github/prompts/*.prompt.md` is the official location for Copilot prompt files.
- `.github/instructions/**/*.instructions.md` is officially supported for path-specific instructions, but this KB treats it as deprecated by portability policy and recommends generating it from `.agents/skills`.

Gaps and unknowns
- agentconfig.org could not be verified this run (site availability and canonical spec status not confirmed).
- OpenCode’s own canonical release stream and machine-readable feed were not confirmed this run (OpenCode support is confirmed via GitHub Changelog, but OpenCode’s distribution/update channel should be re-checked).
- Some marketplace pages (notably JetBrains stable versions list pages) are JS-heavy and not fully parseable in this run; the KB relies on either the JetBrains Marketplace API or search-extracted metadata for “latest known” values.
- The Copilot feature matrix appears to lag behind some per-surface release streams for “latest versions” (example: JetBrains and Xcode). Treat the matrix as the feature anchor, and use per-surface channels for version tracking.

Next iteration goals
- Add automated polling for all GitHub Releases Atom feeds in SOURCES.yaml.
- Add a lightweight “diff generator” (current snapshot vs previous snapshot) for newsletter-ready output.
- Confirm agentconfig.org canonical status and align taxonomy if it is a real cross-agent configuration standard.
```

### `/kb/TAXONOMY.md`
```md
# Taxonomy

This file defines controlled vocabularies used in `/kb/SOURCES.yaml`.

applies_to tags
Use only these values:
- web
- vscode
- visual_studio
- jetbrains
- xcode
- eclipse
- cli
- terminal
- opencode
- mcp
- agents
- skills
- evals
- security
- enterprise
- general

source_type values
Use one or more of:
- docs
- changelog
- release-notes
- repo
- marketplace
- rss
- atom
- api
- standard
- practitioner-guide

stability levels
- high: official, stable URL, long-lived
- medium: official but preview, or known to move, or JS-heavy pages
- low: community, personal blog, or fast-moving, or unclear ownership

portability labels
- portable: reusable across surfaces, not tied to a single vendor’s client conventions
- platform-specific: required by a particular client or distribution channel
- deprecated: no longer recommended (either officially deprecated, or deprecated by this KB’s portability policy)
```

### `/kb/SECTION_A_PRIMARY_PLATFORMS.md`
```md
# Section A: Primary platforms and updates

This section inventories Copilot-supported surfaces and captures:
- Canonical docs hubs
- Canonical release notes and changelog streams
- Distribution channels and versioning pointers
- Machine-readable feeds where available
- Monitoring recipes for monthly refresh
- Feature notes keyed to the Copilot feature matrix

Anchor for cross-surface feature availability:
- Copilot feature matrix: https://docs.github.com/en/copilot/reference/copilot-feature-matrix

Web experiences (GitHub.com)
Overview
- Copilot Chat and agent experiences on GitHub.com are updated continuously.
Canonical docs hubs
- Copilot docs home: https://docs.github.com/en/copilot
Canonical update streams
- GitHub Changelog label stream (Copilot): https://github.blog/changelog/label/copilot/
- RSS (Copilot label): https://github.blog/changelog/label/copilot/feed/
Distribution and versioning
- Server-side, no client version tracking.
Monitoring recipe
- Poll Copilot label page and RSS weekly, summarize monthly.
Feature notes (matrix-linked)
- Use the matrix for feature list; map web-only behaviors via relevant Copilot docs and changelog posts.

VS Code
Overview
- Copilot in VS Code is a combination of client capabilities, extensions, and Copilot service behavior.
Canonical docs hubs
- Copilot docs: Chat in IDE, prompt files, custom instructions, MCP
- VS Code release notes: https://code.visualstudio.com/updates/
Canonical update streams
- GitHub Changelog: “GitHub Copilot in Visual Studio Code” monthly release posts
- VS Code Insiders notes for early signals: https://code.visualstudio.com/updates/v1_110 (example)
Distribution and upgrade
- VS Code updates via VS Code updater or package managers.
- Copilot extension distributed via Visual Studio Marketplace.
Monitoring recipe
- Poll VS Code stable release notes monthly
- Poll VS Code Insiders notes weekly for emerging changes
- Poll GitHub Changelog Copilot posts for Copilot-specific deltas

Visual Studio
Overview
- Copilot features are tracked in Visual Studio release notes plus Copilot changelog posts.
Canonical docs hubs
- Visual Studio release notes (2022): https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes
- Visual Studio release notes (2026): https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes
- Copilot docs: install extension in your environment and chat behaviors
Canonical update streams
- GitHub Changelog monthly Copilot update posts for Visual Studio
Monitoring recipe
- Poll Visual Studio release notes pages monthly
- Poll Copilot label changelog monthly, extract Visual Studio-specific posts

JetBrains IDEs
Overview
- Copilot is distributed as a JetBrains Marketplace plugin.
Canonical docs hubs
- Copilot docs: install extension, custom instructions, prompt files
Distribution and upgrade
- JetBrains Marketplace plugin listing and updates:
  - Human listing: https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable
  - API (nightly example): https://plugins.jetbrains.com/api/plugins/17718/updates?channel=nightly&page=1&size=8
Monitoring recipe
- Poll JetBrains Marketplace stable channel versions and dates
- Poll Copilot changelog posts that reference JetBrains minimum versions for model availability

Xcode
Overview
- Copilot for Xcode ships as a GitHub-hosted project with releases.
Canonical docs hubs
- Copilot docs: install extension
- Project repo: https://github.com/github/CopilotForXcode
Canonical update streams
- GitHub Releases: https://github.com/github/CopilotForXcode/releases
Monitoring recipe
- Poll GitHub Releases monthly, record latest stable release and date

Eclipse
Overview
- Copilot for Eclipse is distributed via Eclipse Marketplace plus an Azure-hosted update site.
Canonical docs hubs
- Eclipse Marketplace listing: https://marketplace.eclipse.org/content/github-copilot
Distribution and upgrade
- Update site URL is published on the marketplace listing (use for install and upgrade).
Monitoring recipe
- Poll marketplace listing monthly for “Date Updated” changes
- Poll Copilot feature matrix for Eclipse feature support changes

Copilot CLI
Overview
- Copilot CLI is distributed as a GitHub repository with GitHub Releases, with official docs for usage and best practices.
Canonical docs hubs
- Copilot CLI docs and quickstart (GitHub Docs Copilot section)
Canonical update streams
- GitHub Releases: https://github.com/github/copilot-cli/releases
Monitoring recipe
- Poll GitHub Releases monthly, record latest tag and date
- Poll Copilot changelog for CLI-impacting changes (models, policies, behavior)

OpenCode
Overview
- OpenCode is an officially supported Copilot surface (announced via GitHub Changelog).
Canonical docs
- GitHub Changelog announcement is the canonical Copilot-side confirmation.
Monitoring recipe
- Poll Copilot changelog monthly for OpenCode related posts
- Identify OpenCode’s own canonical release stream and add it to SOURCES.yaml (pending verification)

Terminal and Windows Terminal
Overview
- Copilot usage in terminal contexts is documented in GitHub Docs and Microsoft Terminal blog posts.
Canonical docs hubs
- GitHub Docs: Chat in Windows Terminal (Copilot docs)
Monitoring recipe
- Poll Copilot changelog for terminal-related updates

NeoVim
Overview
- Official plugin exists in a GitHub repository (tags are used as the version stream).
Canonical sources
- Repo: https://github.com/github/copilot.vim
- Tags: https://github.com/github/copilot.vim/tags
Monitoring recipe
- Poll tags monthly and record latest tag and date

Additional surfaces discovered via official sources
- GitHub Mobile (Copilot features appear in official changelog availability lists)
- GitHub Desktop (documented as a Copilot surface in Copilot docs navigation)
- Azure Data Studio (listed as IDE support on the Copilot product page)
These should be added as defined sources in SOURCES.yaml during the next run if their canonical update streams are confirmed.
```

### `/kb/SECTION_B_FRAMEWORKS.md`
```md
# Section B: Copilot-adjacent frameworks and resources

Inclusion rule
These are included because they either:
- Integrate directly with Copilot workflows (agents, MCP, skills), or
- Provide a packaging or workflow convention that teams can reuse across Copilot surfaces.

GitHub Agentic Workflows (gh-aw)
Definition
- A GitHub CLI extension and workflow system that turns natural language Markdown into GitHub Actions workflows executed by coding agents.
When to use
- Scheduled or repeatable repo automation where you want an agent to run inside CI with explicit guardrails.
When not to use
- Interactive local editing tasks where IDE agent mode is faster and lower-friction.
Maturity signals
- Official GitHub repository, published docs site, companion security projects.
Canonical links
- Repo: https://github.com/github/gh-aw
- Docs site: https://github.github.io/gh-aw/
Relationship to Copilot
- Fits alongside Copilot by relocating agent execution into Actions, enabling governance patterns like network egress control, logging, and locked workflows.

GitHub Spec Kit (spec-driven development)
Definition
- Toolkit for Spec-Driven Development (SDD): produce structured specifications first, then iterate implementation with agents.
When to use
- Large features, migrations, or multi-file refactors where a durable spec reduces drift and improves reviewability.
When not to use
- Tiny changes where a full spec adds overhead.
Maturity signals
- Official repo with releases, high adoption.
Canonical links
- Repo: https://github.com/github/spec-kit
- Releases: https://github.com/github/spec-kit/releases
Copilot workflow connection
- Specs can be created and maintained in-repo, then consumed by Copilot agents or other coding agents depending on environment.

BMad Method
Definition
- A structured method and module library for building and managing agent-assisted planning and execution artifacts.
Canonical links
- Repo: https://github.com/bmad-code-org/BMAD-METHOD
Use cases and cautions
- Use when you need repeatable planning templates and role modules.
- Treat as community guidance, verify fit for your org’s governance.

Agent Skills
Definition
- An open format for packaging reusable “skills” (instructions, scripts, resources) that agents can discover and use.
Canonical links
- Overview: https://agentskills.io/
- Specification: https://agentskills.io/specification
- Reference repository: https://github.com/agentskills/agentskills
Maturity signals
- Published spec and public reference repository.
Copilot workflow connection
- Use `.agents/skills` as the portability-first root, and generate Copilot-specific instruction artifacts as needed.

Agent Skills threat model
Definition
- Security guidance for skills as an extension mechanism (skills can carry instructions and executable code).
Canonical link
- https://safedep.io/agent-skills-threat-model
When to use
- Any time you allow third-party or cross-team skills, treat them like dependencies.

MCP
Definition
- Model Context Protocol, used to connect Copilot agents to tools and services.
Canonical links
- Copilot docs: https://docs.github.com/en/copilot/how-tos/provide-context/use-mcp/extend-copilot-chat-with-mcp
When to use
- Tool integration with explicit allowlists, audit strategies, and least privilege.

copilot-orchestra
- Repo: https://github.com/ShepAlderson/copilot-orchestra
Notes
- Community orchestrator. Evaluate maintenance and security posture before adoption.

loop-agent
- Repo: https://github.com/digitarald/loop-agent
Notes
- Community agent loop framework. Treat as non-canonical.

agentos disambiguation
This name refers to multiple unrelated projects. Two that surfaced:
- agentos-project/agentos (reinforcement learning oriented): https://github.com/agentos-project/agentos
- buildermethods/agent-os (agent workflow/spec system): https://github.com/buildermethods/agent-os
Action
- Do not treat “agentos” as a single canonical thing. Pick and document the one you actually use.
```

### `/kb/SECTION_C_BEST_PRACTICES.md`
```md
# Section C: Portable best practices for AI-assisted development

Portability rule
- Default reusable artifact location: `.agents/skills`
- If a Copilot surface requires a specific convention, treat it as a generated output, not the source of truth.

Prompting and instruction design
Portable recommendations
- Prefer short, testable instruction blocks over long prose.
- Separate “role and goals” from “constraints and checks.”
- Include examples and edge cases (and update them as regressions are discovered).
References
- Claude prompting best practices: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices

Custom instructions and instruction files
Portable approach
- Keep a single “instruction library” under `.agents/skills`.
- Generate:
  - `.github/copilot-instructions.md` (repository-wide Copilot instructions)
  - `.github/prompts/*.prompt.md` (prompt files)
Platform-specific, portability-disfavored (documented only)
- `.github/instructions/**/*.instructions.md` is officially supported by Copilot for path-specific instructions, but this KB treats it as deprecated by portability policy. Generate it from `.agents/skills` only if required for compatibility.

Prompt files
Portable approach
- Treat prompt files as “invocable skills” stored in `.agents/skills`, then export into `.github/prompts`.
Copilot conventions
- Prompt files are `*.prompt.md` stored in `.github/prompts` (public preview).
- Prompt files are only available in VS Code, Visual Studio, and JetBrains IDEs.

Tool use and action safety
Portable recommendations
- Default to read-only tools. Require explicit user confirmation for write actions.
- Use least privilege and allowlists for network and repo access.
- Log tool calls and outputs in a durable run artifact (CI logs or saved session exports).
Notes
- Some clients now expose tool call visibility and export options. Prefer clients that make tool activity inspectable.

Evals and regression testing
Portable recommendations
- Maintain a golden set of tasks and expected outcomes.
- Run prompt and skill evals in CI when changing instructions, skills, or tool wiring.
- Track “failure modes” as first-class artifacts (each miss becomes a test).
References
- OpenAI evaluation flywheel: https://developers.openai.com/cookbook/examples/evaluation/building_resilient_prompts_using_an_evaluation_flywheel/

RAG for codebases
Portable recommendations
- Prefer repo indexing or scoped retrieval strategies that cite file paths and commit SHAs.
- Maintain exclusion rules for sensitive paths and generated artifacts.

Orchestration patterns
Portable recommendations
- Plan then execute: maintain a lightweight plan artifact before code changes.
- Use explicit handoffs: define what “done” means, how to verify, and where to log.
- Separate “skills” (reusable how-to) from “work logs” (per-run).

Operational enablement
Portable recommendations
- Roll out in phases with measurement (adoption, acceptance rate, PR throughput, defect rate).
- Maintain governance playbooks for:
  - model enablement policies
  - skills approval and signing
  - auditing and incident response
```

### `/kb/SECTION_D_THOUGHT_LEADERSHIP.md`
```md
# Section D: Thought leadership and decision support

Inclusion criteria
- Durable frameworks, concrete failure modes, operational guidance.

GitHub Agentic Workflows and Peli’s Agent Factory
Why it matters
- Shows how agent execution can be formalized inside CI with guardrails.
- Encourages treating agent behavior as compileable, reviewable artifacts.
Decisions it informs
- Whether to run agents in CI (Actions) vs local IDE loops
- Governance patterns for repo automation
Canonical link
- https://github.github.io/gh-aw/blog/2026-01-12-welcome-to-pelis-agent-factory/

Turning agent misses into systemic improvements
Why it matters
- Promotes turning failures into tests and reusable instruction assets.
- Emphasizes feedback loops over one-off prompt tweaking.
Decisions it informs
- How to build an eval flywheel and regression discipline
- Where to invest in skills vs prompting
Canonical link
- https://jonmagic.com/posts/turning-agent-misses-into-systemic-improvements/

Claude prompting best practices
Why it matters
- Concrete prompting patterns that remain useful as models evolve.
Decisions it informs
- How to structure instructions and prompts for consistency
Canonical link
- https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices

OpenAI evaluation flywheel
Why it matters
- A practical methodology for making prompts resilient via closed-loop evaluation.
Decisions it informs
- How to operationalize prompt quality and detect regressions
Canonical link
- https://developers.openai.com/cookbook/examples/evaluation/building_resilient_prompts_using_an_evaluation_flywheel/

Spec-Driven Development with GitHub Spec Kit
Why it matters
- Concretizes “spec first” as an agent-friendly workflow with durable artifacts.
Decisions it informs
- When SDD scaffolding is worth the overhead for your team
Canonical link
- https://github.com/github/spec-kit

Agent Skills threat model
Why it matters
- Treats skills like dependencies, clarifies attacker model and mitigations.
Decisions it informs
- How to govern third-party skills and tool execution
Canonical link
- https://safedep.io/agent-skills-threat-model
```

### `/kb/CURRENT_STATE_SNAPSHOT.md`
```md
# Current state snapshot

State:
- AS_OF_DATE: 2026-02-10
- LAST_RUN_DATE: 2026-02-10

This snapshot captures the latest known versions and noteworthy ecosystem changes as of AS_OF_DATE.

Primary surfaces and latest known versions

VS Code
- VS Code stable: 1.109 (release date: 2026-02-04)
  - Reference: https://code.visualstudio.com/updates/v1_109
- VS Code Insiders: 1.110 (last updated: 2026-02-09)
  - Reference: https://code.visualstudio.com/updates/v1_110

Copilot in VS Code (Copilot-specific monthly release notes)
- Latest Copilot in VS Code monthly release post: “v1.109 January Release” (published: 2026-02-04)
  - Reference: https://github.blog/changelog/2026-02-04-github-copilot-in-visual-studio-code-v1-109-january-release/

Visual Studio
- Visual Studio 2026: 18.1.1 (released: 2025-12-16)
  - Reference: https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes
- Visual Studio 2022: 17.14.24 (released: 2026-01-13)
  - Reference: https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes

Copilot in Visual Studio (Copilot-specific monthly update)
- Latest Copilot in Visual Studio monthly update post (published: 2026-02-04)
  - Reference: https://github.blog/changelog/2026-02-04-github-copilot-in-visual-studio-january-update/

JetBrains IDEs
- GitHub Copilot JetBrains plugin stable: latest known 1.5.64-243 (update date: 2026-02-04)
  - Reference (stable versions listing): https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable
  - Reference (API, nightly channel example): https://plugins.jetbrains.com/api/plugins/17718/updates?channel=nightly&page=1&size=8

Xcode
- Copilot for Xcode: 0.47.0 (released: 2026-02-05)
  - Reference: https://github.com/github/CopilotForXcode/releases

Eclipse
- Copilot for Eclipse: version line tracked in Copilot feature matrix (latest listed: 0.14.0)
  - Reference: https://docs.github.com/en/copilot/reference/copilot-feature-matrix
- Eclipse Marketplace listing last updated: 2026-01-27
  - Reference: https://marketplace.eclipse.org/content/github-copilot

Copilot CLI
- Latest Copilot CLI release: 0.0.406 (released: 2026-02-07)
  - Reference: https://github.com/github/copilot-cli/releases

NeoVim
- Official plugin tags: latest tag v1.59.0 (tag date: 2026-01-09)
  - Reference: https://github.com/github/copilot.vim/tags

Cross-surface changes worth noting this month

Models and agents
- GPT-5.3-Codex is now generally available for GitHub Copilot (published: 2026-02-09). Availability includes VS Code, GitHub.com, GitHub Mobile, GitHub CLI, and Copilot coding agent.
  - Reference: https://github.blog/changelog/2026-02-09-gpt-5-3-codex-is-now-generally-available-for-github-copilot/
- Claude and Codex coding agents are available in public preview on GitHub (published: 2026-02-04), with cross-client agent sessions spanning web, mobile, and VS Code.
  - Reference: https://github.blog/changelog/2026-02-04-claude-and-codex-are-now-available-in-public-preview-on-github/

Governance and APIs
- Legacy Copilot metrics APIs (three endpoints) have published sunset dates:
  - Two endpoints sunset 2026-03-02
  - Copilot Metrics API sunsets 2026-04-02
  - Reference: https://github.blog/changelog/2026-01-29-closing-down-notice-of-legacy-copilot-metrics-apis/

New or newly confirmed surface support
- OpenCode is now an officially supported Copilot surface (published: 2026-02-04).
  - Reference: https://github.blog/changelog/2026-02-04-github-copilot-is-now-supported-in-opencode/
```
Snapshot provenance for version and date values is drawn from the linked sources above, including VS Code release notes and Insiders notes citeturn22view0turn24view0, GitHub Changelog posts for Copilot in VS Code and Visual Studio citeturn19view0turn18view1, Copilot CLI releases citeturn8view0, Copilot for Xcode releases citeturn47view0, Eclipse marketplace metadata citeturn16view0, copilot.vim tags citeturn50view0, and the legacy metrics API retirement notice citeturn21view0. JetBrains “latest known” stable metadata is taken from the JetBrains Marketplace listing snippet captured this run citeturn36search15.

### `/kb/MAINTENANCE_RUNBOOK.md`
```md
# Maintenance runbook

Purpose
A repeatable monthly refresh procedure for keeping the KB current.

Monthly refresh procedure
1. Set LAST_RUN_DATE to today in:
   - `/kb/KB_INDEX.md`
   - `/kb/SOURCES.yaml`
   - `/kb/CURRENT_STATE_SNAPSHOT.md`
2. Poll all update_feeds and canonical release streams in `/kb/SOURCES.yaml`.
3. Update `/kb/CURRENT_STATE_SNAPSHOT.md` with:
   - Latest versions and dates per major surface
   - “What changed” bullets only when meaningful, otherwise note “no material change noted”
   - Notable deprecations and migrations impacting canonical guidance
4. Add new sources:
   - New official changelog streams
   - New IDE plugin distribution pages
   - New docs hubs or moved docs
5. Retire dead links:
   - Mark deprecated in SOURCES.yaml
   - Add migration notes in CHANGELOG and the relevant section file
6. Update `/kb/CHANGELOG.md` with a brief summary of KB changes.
7. Create a new run log:
   - `/kb/RUN_LOG_<LAST_RUN_DATE>.md`

Detection checklist for new surfaces and streams
- Check Copilot feature matrix for new columns or feature rows.
- Scan GitHub Changelog (Copilot label) for:
  - “now supported in <surface>”
  - “retired,” “deprecated,” “sunset,” “policy”
- Check major IDE release notes and marketplaces for new Copilot distribution channels.
- Check Copilot model availability posts for minimum client/plugin versions (these often reveal new version baselines).
- Validate whether new portability-impacting file conventions are introduced (and document them as exceptions).

Validation checklist
- Completeness: Section A enumerates all Copilot surfaces substantiated by official sources.
- Canonicality: every record has at least one official canonical URL, or is labeled Community.
- Feeds: include RSS/Atom/GitHub Releases Atom whenever available.
- Dedupe: no duplicates, consolidate streams into one record.
- Portability: `.agents/skills` is the default recommendation, exceptions are labeled.
- Matrix linkage: feature matrix is referenced and major features map back to docs and update streams.
- Link health: record failures in RUN_LOG.
```

### `/kb/RESEARCH_METHOD.md`
```md
# Research method

Principles
- Prefer primary, official sources.
- Treat “what features exist per surface” and “what changed recently” as separate problems:
  - Feature anchor: Copilot feature matrix
  - Change tracking: changelogs, release notes, GitHub Releases, marketplace updates

How canonicality is verified
- Official docs are hosted on a vendor’s official domain.
- Official changelog posts are published on the vendor’s changelog.
- Official release notes are published in:
  - Microsoft Learn (Visual Studio)
  - VS Code updates site
  - GitHub Releases (GitHub-hosted clients)
  - Official marketplaces (JetBrains Marketplace, Visual Studio Marketplace, Eclipse Marketplace)

How duplicates are resolved
- Prefer a single record per logical stream.
- If a source has multiple equivalent URLs, store them in one record.

Inclusion rules
- Section A: only add a surface if confirmed via official docs or official changelog posts.
- Sections B to D: community and practitioner sources are allowed, but must be labeled.

How practitioner sources are handled
- Must be operationally concrete, not only opinion.
- Must remain maintained or evergreen, otherwise downgrade stability or remove.

Portability enforcement
- `.agents/skills` is treated as the “source location.”
- Copilot-specific files are treated as export targets.
- If official sources promote `.github/instructions`, document it as portability-deprecated and provide a portable alternative workflow.
```

### `/kb/RUN_LOG_2026-02-10.md`
```md
# Run log 2026-02-10

State
- AS_OF_DATE: 2026-02-10
- LAST_RUN_DATE: 2026-02-10

Chronological work log
- Confirmed Copilot feature matrix as the cross-surface anchor for feature availability.
- Extracted custom instruction file conventions, including:
  - `.github/copilot-instructions.md`
  - `.github/instructions/**/*.instructions.md`
  - agent instruction files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`)
- Extracted prompt file conventions:
  - `*.prompt.md` under `.github/prompts`
  - Preview status and IDE support scope
- Pulled latest VS Code stable release notes (1.109) and Insiders notes (1.110).
- Pulled Visual Studio 2026 release notes and Visual Studio 2022 (17.14) latest servicing entries.
- Pulled Copilot-specific GitHub Changelog posts for:
  - Copilot in VS Code monthly release
  - Copilot in Visual Studio monthly update
  - Web chat improvements
  - Model availability and agent preview
  - Metrics API retirement notice and dates
  - OpenCode support announcement
- Pulled Copilot for Xcode GitHub Releases for latest version.
- Pulled Copilot CLI GitHub Releases for latest version.
- Pulled Eclipse Marketplace listing for update site URL and “Date Updated.”
- Pulled copilot.vim tags for latest tag and date.
- Located canonical repositories for:
  - github/spec-kit
  - github/gh-aw
  - bmad-code-org/BMAD-METHOD
  - agentskills (spec and repo)

Key decisions
- Portability policy enforced:
  - `.agents/skills` recommended as the default source location.
  - `.github/instructions` documented as officially supported but deprecated by portability policy.
- Copilot feature matrix retained as the feature anchor even where version tables lag behind marketplace/release sources.

Broken links or moving targets
- GitHub Changelog RSS feed for Copilot label could not be fetched by the tooling in this run (URL retained as canonical, but marked “check manually”).
- JetBrains Marketplace stable “versions list” pages are JS-heavy; “latest known” values were captured via the Marketplace metadata and search output, and the API is preferred for automation.

Gaps and unknowns
- agentconfig.org was not confirmed this run.
- OpenCode’s own canonical release stream and machine-readable feed not confirmed this run, only Copilot-side support announcement was confirmed.
- Some secondary surfaces referenced in product pages (for example GitHub Desktop, GitHub Mobile, Windows Terminal) need explicit canonical update streams added in the next run.
```

### `/kb/CHANGELOG.md`
```md
# KB changelog

2026-02-10
- Initial build.
- Added canonical source inventory across key Copilot surfaces, anchored on feature matrix and Copilot changelog.
- Added portability-first best practices, defaulting to `.agents/skills` with platform exceptions documented.
- Added current state snapshot with latest known versions and key ecosystem changes.
```

### `/kb/SOURCES.yaml`
```yaml
version: 1
as_of: "2026-02-10"
last_run_date: "2026-02-10"
sources:
  - id: "gh-docs-copilot-feature-matrix"
    name: "Copilot feature matrix"
    vendor: "GitHub"
    section: "A"
    source_type: ["docs"]
    canonical_urls:
      - "https://docs.github.com/en/copilot/reference/copilot-feature-matrix"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["web","vscode","visual_studio","jetbrains","xcode","eclipse","cli","general"]
    portability: "portable"
    what_it_is: "Official matrix of Copilot feature availability by surface and client/plugin version."
    why_it_matters: "Best single anchor for enumerating Copilot features per surface and tracking feature rollout baselines."
    update_cadence: "irregular"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: ""
      reference_url: "https://docs.github.com/en/copilot/reference/copilot-feature-matrix"
    notes: "Version tables may lag behind per-surface release streams; use as feature anchor."

  - id: "gh-docs-response-customization"
    name: "Response customization (custom instructions and prompt files overview)"
    vendor: "GitHub"
    section: "C"
    source_type: ["docs"]
    canonical_urls:
      - "https://docs.github.com/en/copilot/concepts/prompting/response-customization"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["web","vscode","visual_studio","jetbrains","xcode","eclipse","cli","agents","general"]
    portability: "portable"
    what_it_is: "Official explanation of Copilot response customization primitives (personal, repo, org instructions, prompt files)."
    why_it_matters: "Defines file conventions and precedence rules that impact cross-client behavior and governance."
    update_cadence: "irregular"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: ""
      reference_url: "https://docs.github.com/en/copilot/concepts/prompting/response-customization"
    notes: "Documents `.github/instructions` for path-specific instructions; treated as deprecated by portability policy in this KB."

  - id: "gh-docs-custom-instructions-support"
    name: "Custom instructions support matrix"
    vendor: "GitHub"
    section: "A"
    source_type: ["docs"]
    canonical_urls:
      - "https://docs.github.com/en/copilot/reference/custom-instructions-support"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["web","vscode","visual_studio","jetbrains","xcode","eclipse","cli","agents","general"]
    portability: "portable"
    what_it_is: "Official reference table describing which instruction types are supported by Copilot features across environments."
    why_it_matters: "Prevents assuming instruction behavior is uniform across surfaces."
    update_cadence: "irregular"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: ""
      reference_url: "https://docs.github.com/en/copilot/reference/custom-instructions-support"
    notes: ""

  - id: "gh-docs-prompt-files-tutorial"
    name: "Prompt files tutorial: your first prompt file"
    vendor: "GitHub"
    section: "C"
    source_type: ["docs"]
    canonical_urls:
      - "https://docs.github.com/en/copilot/tutorials/customization-library/prompt-files/your-first-prompt-file"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["vscode","visual_studio","jetbrains","agents","general"]
    portability: "platform-specific"
    what_it_is: "Official tutorial defining Copilot prompt file conventions and usage."
    why_it_matters: "Defines `.github/prompts` location, `*.prompt.md` extension, and preview limitations."
    update_cadence: "irregular"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: ""
      reference_url: "https://docs.github.com/en/copilot/tutorials/customization-library/prompt-files/your-first-prompt-file"
    notes: "Prompt files documented as public preview."

  - id: "gh-docs-mcp-extend"
    name: "Extend Copilot Chat with MCP"
    vendor: "GitHub"
    section: "B"
    source_type: ["docs"]
    canonical_urls:
      - "https://docs.github.com/en/copilot/how-tos/provide-context/use-mcp/extend-copilot-chat-with-mcp"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["web","vscode","visual_studio","jetbrains","xcode","eclipse","mcp","agents","security","general"]
    portability: "portable"
    what_it_is: "Official docs for integrating Copilot Chat with MCP servers."
    why_it_matters: "Canonical reference for tool integration patterns and governance hooks."
    update_cadence: "irregular"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: ""
      reference_url: "https://docs.github.com/en/copilot/how-tos/provide-context/use-mcp/extend-copilot-chat-with-mcp"
    notes: ""

  - id: "gh-changelog-copilot-label"
    name: "GitHub Changelog: Copilot label"
    vendor: "GitHub"
    section: "A"
    source_type: ["changelog","rss"]
    canonical_urls:
      - "https://github.blog/changelog/label/copilot/"
      - "https://github.blog/changelog/label/copilot/feed/"
    update_feeds:
      - type: "rss"
        url: "https://github.blog/changelog/label/copilot/feed/"
    applies_to: ["web","vscode","visual_studio","jetbrains","xcode","eclipse","cli","agents","enterprise","general"]
    portability: "portable"
    what_it_is: "Official changelog stream for Copilot-related product updates."
    why_it_matters: "Primary cross-surface 'what changed' feed for newsletter and snapshot generation."
    update_cadence: "frequent"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: ""
      reference_url: "https://github.blog/changelog/label/copilot/"
    notes: "RSS feed URL is canonical; tooling fetch may fail, verify manually if needed."

  - id: "gh-changelog-vscode-2026-02-04"
    name: "Copilot in VS Code v1.109 January release (GitHub Changelog)"
    vendor: "GitHub"
    section: "A"
    source_type: ["changelog"]
    canonical_urls:
      - "https://github.blog/changelog/2026-02-04-github-copilot-in-visual-studio-code-v1-109-january-release/"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["vscode","agents","security","general"]
    portability: "portable"
    what_it_is: "Monthly Copilot-specific VS Code release notes published on GitHub Changelog."
    why_it_matters: "Captures Copilot UX and agent workflow changes that may not appear in generic VS Code release notes."
    update_cadence: "monthly"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: "v1.109"
      release_date: "2026-02-04"
      reference_url: "https://github.blog/changelog/2026-02-04-github-copilot-in-visual-studio-code-v1-109-january-release/"
    notes: ""

  - id: "ms-vscode-updates"
    name: "VS Code release notes (Updates)"
    vendor: "Microsoft"
    section: "A"
    source_type: ["release-notes"]
    canonical_urls:
      - "https://code.visualstudio.com/updates/"
      - "https://code.visualstudio.com/updates/v1_109"
      - "https://code.visualstudio.com/updates/v1_110"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["vscode","general"]
    portability: "platform-specific"
    what_it_is: "Official VS Code stable and Insiders release notes."
    why_it_matters: "Tracks client changes that impact Copilot UX, agent tools, and extension compatibility."
    update_cadence: "monthly"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: "1.109 (stable), 1.110 (insiders)"
      release_date: "2026-02-04 (stable), 2026-02-09 (insiders last updated)"
      reference_url: "https://code.visualstudio.com/updates/v1_109"
    notes: ""

  - id: "ms-vs-release-notes-2026"
    name: "Visual Studio 2026 release notes"
    vendor: "Microsoft"
    section: "A"
    source_type: ["release-notes"]
    canonical_urls:
      - "https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["visual_studio","general"]
    portability: "platform-specific"
    what_it_is: "Official release notes for Visual Studio 2026."
    why_it_matters: "Tracks Copilot and MCP-related client capability changes and version baselines."
    update_cadence: "monthly"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: "18.1.1"
      release_date: "2025-12-16"
      reference_url: "https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes"
    notes: "Page lists multiple versions; latest known is based on top-of-page ordering."

  - id: "ms-vs-release-notes-2022"
    name: "Visual Studio 2022 release notes"
    vendor: "Microsoft"
    section: "A"
    source_type: ["release-notes"]
    canonical_urls:
      - "https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["visual_studio","general"]
    portability: "platform-specific"
    what_it_is: "Official release notes for Visual Studio 2022, including Copilot section updates."
    why_it_matters: "Useful for enterprises with mixed Visual Studio 2022/2026 deployments."
    update_cadence: "monthly"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: "17.14.24"
      release_date: "2026-01-13"
      reference_url: "https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes"
    notes: "Contains `.github/instructions` mention for instruction files; treated as deprecated by portability policy."

  - id: "gh-changelog-vs-2026-02-04"
    name: "Copilot in Visual Studio January update (GitHub Changelog)"
    vendor: "GitHub"
    section: "A"
    source_type: ["changelog"]
    canonical_urls:
      - "https://github.blog/changelog/2026-02-04-github-copilot-in-visual-studio-january-update/"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["visual_studio","general"]
    portability: "portable"
    what_it_is: "Copilot-specific Visual Studio update post on GitHub Changelog."
    why_it_matters: "Highlights Copilot feature changes that can land independently of Microsoft Learn structured notes."
    update_cadence: "monthly"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: "2026-02-04"
      reference_url: "https://github.blog/changelog/2026-02-04-github-copilot-in-visual-studio-january-update/"
    notes: ""

  - id: "jb-copilot-plugin-stable"
    name: "JetBrains Marketplace: GitHub Copilot plugin (stable channel)"
    vendor: "JetBrains"
    section: "A"
    source_type: ["marketplace"]
    canonical_urls:
      - "https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable"
    update_feeds:
      - type: "api"
        url: "https://plugins.jetbrains.com/api/plugins/17718/updates?channel=stable&page=1&size=8"
      - type: "api"
        url: "https://plugins.jetbrains.com/api/plugins/17718/updates?channel=nightly&page=1&size=8"
    applies_to: ["jetbrains","general"]
    portability: "platform-specific"
    what_it_is: "JetBrains Marketplace listing for GitHub Copilot plugin versions and updates."
    why_it_matters: "Canonical version baseline for Copilot in JetBrains IDEs and compatibility constraints."
    update_cadence: "frequent"
    stability: "medium"
    last_checked: "2026-02-10"
    latest_known:
      version: "1.5.64-243"
      release_date: "2026-02-04"
      reference_url: "https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable"
    notes: "Stable API endpoint may require manual verification in some environments."

  - id: "gh-copilotforxcode-releases"
    name: "Copilot for Xcode releases"
    vendor: "GitHub"
    section: "A"
    source_type: ["release-notes","repo","atom"]
    canonical_urls:
      - "https://github.com/github/CopilotForXcode/releases"
    update_feeds:
      - type: "github_releases_atom"
        url: "https://github.com/github/CopilotForXcode/releases.atom"
    applies_to: ["xcode","general"]
    portability: "platform-specific"
    what_it_is: "Official GitHub Releases stream for the Copilot for Xcode extension."
    why_it_matters: "Canonical source for latest Xcode extension versions and dates."
    update_cadence: "frequent"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: "0.47.0"
      release_date: "2026-02-05"
      reference_url: "https://github.com/github/CopilotForXcode/releases"
    notes: ""

  - id: "eclipse-marketplace-copilot"
    name: "Eclipse Marketplace: GitHub Copilot listing"
    vendor: "Other"
    section: "A"
    source_type: ["marketplace"]
    canonical_urls:
      - "https://marketplace.eclipse.org/content/github-copilot"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["eclipse","general"]
    portability: "platform-specific"
    what_it_is: "Eclipse Marketplace listing including the official update site URL and listing metadata."
    why_it_matters: "Canonical install source pointer for Copilot in Eclipse and a signal for update recency."
    update_cadence: "irregular"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: "0.14.0 (matrix latest shown)"
      release_date: "2026-01-27 (listing updated)"
      reference_url: "https://marketplace.eclipse.org/content/github-copilot"
    notes: "Use Copilot feature matrix for Eclipse version support and features."

  - id: "gh-copilot-cli-releases"
    name: "Copilot CLI releases"
    vendor: "GitHub"
    section: "A"
    source_type: ["release-notes","repo","atom"]
    canonical_urls:
      - "https://github.com/github/copilot-cli/releases"
    update_feeds:
      - type: "github_releases_atom"
        url: "https://github.com/github/copilot-cli/releases.atom"
    applies_to: ["cli","terminal","general"]
    portability: "platform-specific"
    what_it_is: "Official GitHub Releases stream for Copilot CLI."
    why_it_matters: "Canonical version and change tracking for terminal Copilot workflows."
    update_cadence: "frequent"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: "0.0.406"
      release_date: "2026-02-07"
      reference_url: "https://github.com/github/copilot-cli/releases"
    notes: ""

  - id: "gh-copilot-vim-tags"
    name: "copilot.vim tags (NeoVim/Vim plugin version stream)"
    vendor: "GitHub"
    section: "A"
    source_type: ["repo"]
    canonical_urls:
      - "https://github.com/github/copilot.vim"
      - "https://github.com/github/copilot.vim/tags"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["general"]
    portability: "platform-specific"
    what_it_is: "Official Copilot plugin for Vim/NeoVim, tag list is the effective version stream."
    why_it_matters: "Canonical for tracking NeoVim/Vim plugin version baselines."
    update_cadence: "irregular"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: "v1.59.0"
      release_date: "2026-01-09"
      reference_url: "https://github.com/github/copilot.vim/tags"
    notes: "Feature matrix NeoVim version table may lag this tag stream."

  - id: "gh-changelog-opencode-support"
    name: "OpenCode support announcement (GitHub Changelog)"
    vendor: "GitHub"
    section: "A"
    source_type: ["changelog"]
    canonical_urls:
      - "https://github.blog/changelog/2026-02-04-github-copilot-is-now-supported-in-opencode/"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["opencode","general"]
    portability: "portable"
    what_it_is: "Official announcement that Copilot subscriptions are supported in OpenCode."
    why_it_matters: "Establishes OpenCode as an officially supported Copilot surface and triggers monitoring requirements."
    update_cadence: "irregular"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: "2026-02-04"
      reference_url: "https://github.blog/changelog/2026-02-04-github-copilot-is-now-supported-in-opencode/"
    notes: "OpenCode’s own version/update stream should be added once verified."

  - id: "gh-changelog-gpt-5-3-codex-ga"
    name: "GPT-5.3-Codex GA for Copilot (GitHub Changelog)"
    vendor: "GitHub"
    section: "A"
    source_type: ["changelog"]
    canonical_urls:
      - "https://github.blog/changelog/2026-02-09-gpt-5-3-codex-is-now-generally-available-for-github-copilot/"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["web","vscode","cli","agents","general"]
    portability: "portable"
    what_it_is: "Official model availability announcement and rollout scope."
    why_it_matters: "Model availability impacts governance, prompting, eval baselines, and client minimum versions."
    update_cadence: "irregular"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: "GPT-5.3-Codex"
      release_date: "2026-02-09"
      reference_url: "https://github.blog/changelog/2026-02-09-gpt-5-3-codex-is-now-generally-available-for-github-copilot/"
    notes: ""

  - id: "gh-changelog-metrics-api-retirement"
    name: "Legacy Copilot metrics APIs retirement notice"
    vendor: "GitHub"
    section: "A"
    source_type: ["changelog"]
    canonical_urls:
      - "https://github.blog/changelog/2026-01-29-closing-down-notice-of-legacy-copilot-metrics-apis/"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["enterprise","general"]
    portability: "portable"
    what_it_is: "Official retirement notice and sunset dates for legacy Copilot metrics APIs."
    why_it_matters: "Directly impacts enterprise reporting pipelines and governance automation."
    update_cadence: "irregular"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: "2026-01-29"
      reference_url: "https://github.blog/changelog/2026-01-29-closing-down-notice-of-legacy-copilot-metrics-apis/"
    notes: "Includes 2026-03-02 and 2026-04-02 sunset dates."

  - id: "gh-changelog-partner-agents-preview"
    name: "Claude and Codex agents preview on GitHub (GitHub Changelog)"
    vendor: "GitHub"
    section: "A"
    source_type: ["changelog"]
    canonical_urls:
      - "https://github.blog/changelog/2026-02-04-claude-and-codex-are-now-available-in-public-preview-on-github/"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["web","vscode","agents","general"]
    portability: "portable"
    what_it_is: "Official partner-agent preview announcement and enablement steps."
    why_it_matters: "Introduces cross-client multi-agent workflow patterns and policy controls."
    update_cadence: "irregular"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: "2026-02-04"
      reference_url: "https://github.blog/changelog/2026-02-04-claude-and-codex-are-now-available-in-public-preview-on-github/"
    notes: ""

  - id: "github-previews"
    name: "GitHub feature previews"
    vendor: "GitHub"
    section: "A"
    source_type: ["docs"]
    canonical_urls:
      - "https://github.com/features/preview"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["general","enterprise"]
    portability: "portable"
    what_it_is: "GitHub feature previews index page (potential early signal for Copilot-related preview changes)."
    why_it_matters: "Previews can introduce new surfaces, policies, or migration paths before GA."
    update_cadence: "irregular"
    stability: "medium"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: ""
      reference_url: "https://github.com/features/preview"
    notes: "Not fully validated this run."

  - id: "github-customer-terms-updates"
    name: "GitHub customer terms updates"
    vendor: "GitHub"
    section: "A"
    source_type: ["docs"]
    canonical_urls:
      - "https://github.com/customer-terms/updates"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["enterprise","general"]
    portability: "portable"
    what_it_is: "Updates to GitHub customer terms (policy changes can affect Copilot use, telemetry, and governance)."
    why_it_matters: "Material policy changes can shift compliance requirements and what guidance is safe to operationalize."
    update_cadence: "irregular"
    stability: "medium"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: ""
      reference_url: "https://github.com/customer-terms/updates"
    notes: "Not fully validated this run."

  - id: "gh-aw-repo"
    name: "GitHub Agentic Workflows (gh-aw)"
    vendor: "GitHub"
    section: "B"
    source_type: ["repo"]
    canonical_urls:
      - "https://github.com/github/gh-aw"
    update_feeds:
      - type: "github_releases_atom"
        url: "https://github.com/github/gh-aw/releases.atom"
    applies_to: ["agents","security","general"]
    portability: "portable"
    what_it_is: "Markdown-defined agentic workflows compiled into GitHub Actions workflows."
    why_it_matters: "Enables agent execution in CI with guardrails, auditability, and repeatability."
    update_cadence: "frequent"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: ""
      reference_url: "https://github.com/github/gh-aw"
    notes: "Repo uses MIT license; companion projects include firewall and MCP gateway concepts."

  - id: "gh-aw-docs"
    name: "GitHub Agentic Workflows docs site"
    vendor: "GitHub"
    section: "D"
    source_type: ["docs"]
    canonical_urls:
      - "https://github.github.io/gh-aw/"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["agents","security","general"]
    portability: "portable"
    what_it_is: "Documentation site for gh-aw."
    why_it_matters: "Canonical usage and conceptual docs for running agents in Actions."
    update_cadence: "irregular"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: ""
      reference_url: "https://github.github.io/gh-aw/"
    notes: ""

  - id: "spec-kit-repo"
    name: "GitHub Spec Kit"
    vendor: "GitHub"
    section: "B"
    source_type: ["repo"]
    canonical_urls:
      - "https://github.com/github/spec-kit"
    update_feeds:
      - type: "github_releases_atom"
        url: "https://github.com/github/spec-kit/releases.atom"
    applies_to: ["agents","general"]
    portability: "portable"
    what_it_is: "Toolkit for Spec-Driven Development the spec-first workflow for agentic development."
    why_it_matters: "Creates durable spec artifacts that reduce drift and improve reviewability."
    update_cadence: "frequent"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: "0.0.88 (templates release line seen)"
      release_date: ""
      reference_url: "https://github.com/github/spec-kit/releases"
    notes: "Prefer GitHub Releases and docs in repo; consider adding Specify CLI docs during next run."

  - id: "ms-spec-kit-blog"
    name: "Spec-Driven Development with Spec Kit (Microsoft developer blog)"
    vendor: "Microsoft"
    section: "D"
    source_type: ["practitioner-guide"]
    canonical_urls:
      - "https://developer.microsoft.com/blog/spec-driven-development-spec-kit"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["agents","general"]
    portability: "portable"
    what_it_is: "Overview and onboarding narrative for Spec Kit and Spec-Driven Development."
    why_it_matters: "High-signal explanation of why SDD exists and how teams can apply it."
    update_cadence: "irregular"
    stability: "medium"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: "2025-09-15"
      reference_url: "https://developer.microsoft.com/blog/spec-driven-development-spec-kit"
    notes: ""

  - id: "bmad-method-repo"
    name: "BMAD-METHOD"
    vendor: "Community"
    section: "B"
    source_type: ["repo"]
    canonical_urls:
      - "https://github.com/bmad-code-org/BMAD-METHOD"
    update_feeds:
      - type: "github_releases_atom"
        url: "https://github.com/bmad-code-org/BMAD-METHOD/releases.atom"
    applies_to: ["agents","skills","general"]
    portability: "portable"
    what_it_is: "Community method and modules for agent-assisted planning and execution artifacts."
    why_it_matters: "Reusable templates and modules can standardize team workflows if adopted carefully."
    update_cadence: "irregular"
    stability: "medium"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: ""
      reference_url: "https://github.com/bmad-code-org/BMAD-METHOD"
    notes: "Community source, verify governance fit."

  - id: "agentskills-spec"
    name: "Agent Skills specification"
    vendor: "Community"
    section: "C"
    source_type: ["standard"]
    canonical_urls:
      - "https://agentskills.io/specification"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["skills","agents","security","general"]
    portability: "portable"
    what_it_is: "Open specification for packaging agent skills (instructions, metadata, optional resources)."
    why_it_matters: "Enables write-once reuse of skills across tools and agents, aligning with `.agents/skills` default."
    update_cadence: "irregular"
    stability: "medium"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: ""
      reference_url: "https://agentskills.io/specification"
    notes: ""

  - id: "agentskills-repo"
    name: "Agent Skills reference repo"
    vendor: "Community"
    section: "C"
    source_type: ["repo"]
    canonical_urls:
      - "https://github.com/agentskills/agentskills"
    update_feeds:
      - type: "github_releases_atom"
        url: "https://github.com/agentskills/agentskills/releases.atom"
    applies_to: ["skills","agents","general"]
    portability: "portable"
    what_it_is: "Reference repository and documentation for Agent Skills."
    why_it_matters: "Serves as canonical open-source home for the spec and examples."
    update_cadence: "irregular"
    stability: "medium"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: ""
      reference_url: "https://github.com/agentskills/agentskills"
    notes: ""

  - id: "agentskills-threat-model"
    name: "Agent Skills threat model"
    vendor: "Other"
    section: "C"
    source_type: ["practitioner-guide"]
    canonical_urls:
      - "https://safedep.io/agent-skills-threat-model"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["skills","security","agents","general"]
    portability: "portable"
    what_it_is: "Security analysis of risks introduced by skills as an extension mechanism."
    why_it_matters: "Treat skills like dependencies; informs signing, review, sandboxing, and allowlists."
    update_cadence: "irregular"
    stability: "medium"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: "2026-01-23"
      reference_url: "https://safedep.io/agent-skills-threat-model"
    notes: "Practitioner source; validate alignment with your security program."

  - id: "anthropic-claude-prompting-best-practices"
    name: "Claude prompting best practices"
    vendor: "Anthropic"
    section: "C"
    source_type: ["docs"]
    canonical_urls:
      - "https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["general","agents","skills"]
    portability: "portable"
    what_it_is: "Anthropic guidance for writing effective prompts and instructions."
    why_it_matters: "Provides durable instruction design patterns that remain useful across models."
    update_cadence: "irregular"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: ""
      reference_url: "https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices"
    notes: ""

  - id: "openai-eval-flywheel"
    name: "OpenAI eval flywheel cookbook"
    vendor: "OpenAI"
    section: "C"
    source_type: ["docs"]
    canonical_urls:
      - "https://developers.openai.com/cookbook/examples/evaluation/building_resilient_prompts_using_an_evaluation_flywheel/"
    update_feeds:
      - type: "none"
        url: ""
    applies_to: ["evals","agents","general"]
    portability: "portable"
    what_it_is: "OpenAI cookbook guide for building resilient prompts with an evaluation flywheel."
    why_it_matters: "Operationalizes prompt quality as an iterative, testable process."
    update_cadence: "irregular"
    stability: "high"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: "2025-10-06"
      reference_url: "https://developers.openai.com/cookbook/examples/evaluation/building_resilient_prompts_using_an_evaluation_flywheel/"
    notes: ""

  - id: "copilot-orchestra"
    name: "copilot-orchestra"
    vendor: "Community"
    section: "B"
    source_type: ["repo"]
    canonical_urls:
      - "https://github.com/ShepAlderson/copilot-orchestra"
    update_feeds:
      - type: "github_releases_atom"
        url: "https://github.com/ShepAlderson/copilot-orchestra/releases.atom"
    applies_to: ["agents","general"]
    portability: "portable"
    what_it_is: "Community repository for orchestrating Copilot-adjacent workflows."
    why_it_matters: "Potential integration pattern reference, treat as non-canonical."
    update_cadence: "unknown"
    stability: "low"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: ""
      reference_url: "https://github.com/ShepAlderson/copilot-orchestra"
    notes: "Community source."

  - id: "loop-agent"
    name: "loop-agent"
    vendor: "Community"
    section: "B"
    source_type: ["repo"]
    canonical_urls:
      - "https://github.com/digitarald/loop-agent"
    update_feeds:
      - type: "github_releases_atom"
        url: "https://github.com/digitarald/loop-agent/releases.atom"
    applies_to: ["agents","general"]
    portability: "portable"
    what_it_is: "Community agent loop framework."
    why_it_matters: "Reference implementation for agent loop patterns, treat as non-canonical."
    update_cadence: "unknown"
    stability: "low"
    last_checked: "2026-02-10"
    latest_known:
      version: ""
      release_date: ""
      reference_url: "https://github.com/digitarald/loop-agent"
    notes: "Community source."
```
SOURCES.yaml values and “latest_known” fields are compiled from the official pages linked in each record, including the Copilot feature matrix citeturn51view1turn52view0, GitHub Docs for customization conventions citeturn28view3turn30view0turn31view1, GitHub Changelog posts citeturn19view0turn18view1turn21view0turn18view2turn4search3turn21view2, CopilotForXcode releases citeturn47view0, Copilot CLI releases citeturn8view0, VS Code updates citeturn22view0turn24view0, Eclipse marketplace metadata citeturn16view0, spec-kit and gh-aw canonical repos citeturn53search1turn53search0, agentskills spec citeturn53search3turn53search12turn53search6, and best-practices references from Anthropic and OpenAI citeturn54search2turn54search3.

## Validation results and gaps

Validation checklist results for this run:

Completeness: **Partial.** All minimum required surfaces are enumerated, and OpenCode is included based on an official changelog announcement. Additional surfaces are identified but not fully sourced with canonical update streams in this run. citeturn51view1turn4search3turn3view0

Canonicality: **Pass with labels.** Official sources are labeled GitHub, Microsoft, JetBrains, Anthropic, OpenAI. Community and practitioner sources are explicitly labeled. citeturn53search2turn54search2turn54search3turn53search12

Feeds: **Partial.** GitHub Releases Atom feeds are included where applicable. The Copilot RSS feed URL is included as canonical, but tool retrieval failed during this run and is recorded as a link health caveat. citeturn8view0turn47view0turn20view0

Dedupe: **Pass.** Sources are grouped by logical stream and not duplicated.

Portability: **Pass.** `.agents/skills` is the default recommendation in best practices, and `.github/instructions` is documented as portability-deprecated despite official support. citeturn30view0turn31view1

Matrix linkage: **Pass.** The feature matrix is the anchor and is referenced throughout Section A. citeturn51view1turn52view0

Link health: **Partial.** Most canonical URLs were successfully fetched in this run; known tooling issues (RSS fetch, JetBrains JS-heavy pages) are documented in RUN_LOG. citeturn16view0turn24view0turn44view0
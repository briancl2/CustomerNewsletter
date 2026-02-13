# Section A: Primary Platforms

## Scope

This section inventories GitHub Copilot surfaces and their canonical truth locations for docs, release notes/changelogs, install/upgrade paths, machine-readable feeds, deprecations, and monthly monitoring.

## Anchor Reference

- Copilot feature matrix (surface + feature support anchor):
  - https://docs.github.com/en/copilot/reference/copilot-feature-matrix

## Surface Inventory (Canonical-First)

### 1) GitHub.com Web Experiences

- **Overview / users:** developers using Copilot Chat/coding agents on GitHub.com.
- **Canonical docs hub:** https://docs.github.com/en/copilot
- **Canonical changelog stream:** https://github.blog/changelog/label/copilot/feed/
- **Distribution channel:** GitHub.com service rollout (no client installer).
- **Machine-readable feeds:** RSS (Copilot changelog feed).
- **Deprecations/migrations:** track from Copilot changelog and policy pages.
- **Monitoring recipe (monthly):**
  1. Poll `https://github.blog/changelog/label/copilot/feed/`.
  2. Review docs hub landing and feature pages for taxonomy/navigation shifts.
  3. Check `https://github.com/features/preview` and `https://github.com/customer-terms/updates` for policy/legal impacts.
- **Feature notes (matrix keyed):** web rollout often precedes or accompanies IDE release-note entries; matrix plus changelog feed should both be checked.

### 2) VS Code

- **Overview / users:** primary Copilot IDE surface for general software development.
- **Canonical docs hubs:**
  - https://code.visualstudio.com/docs/copilot/overview
  - https://code.visualstudio.com/docs/copilot/setup
  - https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-extension
- **Canonical release/changelog streams:**
  - VS Code updates: https://code.visualstudio.com/updates/
  - Copilot changelog feed: https://github.blog/changelog/label/copilot/feed/
- **Distribution channels and versioning:**
  - VS Code Stable / Insiders installers
  - VS Marketplace extension listing for Copilot Chat: https://marketplace.visualstudio.com/items?itemName=GitHub.copilot-chat
- **Machine-readable feeds/APIs:**
  - Stable releases API: https://update.code.visualstudio.com/api/releases/stable
  - Insiders releases API: https://update.code.visualstudio.com/api/releases/insider
  - Marketplace page includes JSON payload with version history and timestamps.
- **Known deprecations/migrations:**
  - VS Code 1.109 notes state that the standalone Copilot extension was deprecated and Copilot Chat is the active extension path.
- **Monitoring recipe (monthly):**
  1. Poll both VS Code release APIs (`stable`, `insider`).
  2. Read latest VS Code release note page.
  3. Parse Copilot Chat marketplace payload (`Version`, `LastUpdatedDateString`).
  4. Cross-check Copilot changelog RSS entries for VS Code-specific changes.
- **Feature notes (matrix keyed):** agent mode, MCP, prompt files, and indexing updates should be cross-checked between feature matrix, VS Code updates, and Copilot changelog RSS.

### 3) Visual Studio

- **Overview / users:** .NET and enterprise Visual Studio users on Windows.
- **Canonical docs hubs:**
  - https://learn.microsoft.com/en-us/visualstudio/ide/visual-studio-github-copilot-install-and-states
  - https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-extension
- **Canonical release/changelog streams:**
  - https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes
  - https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes#github-copilot
  - Copilot changelog RSS for feature announcements.
- **Distribution channels/versioning:** Visual Studio installer and channel updates.
- **Machine-readable feeds:** no first-party RSS/Atom feed found for Visual Studio release notes in this run.
- **Known deprecations/migrations:** unified built-in Copilot/Copilot Chat component model (from VS 2022 17.10+ documentation context).
- **Monitoring recipe (monthly):**
  1. Check 2026 and 2022 release-notes pages for Copilot sections.
  2. Check Copilot changelog RSS for Visual Studio entries.
  3. Verify install-state docs for entitlement/install changes.
- **Feature notes (matrix keyed):** Visual Studio has strong coverage for chat/completion/code review/agent mode; use matrix + release notes together.

### 4) JetBrains IDEs

- **Overview / users:** IntelliJ/PyCharm and related JetBrains users.
- **Canonical docs hubs:**
  - https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-extension
  - https://plugins.jetbrains.com/plugin/17718-github-copilot
- **Canonical release/changelog streams:**
  - https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable
- **Distribution channels/versioning:** JetBrains Marketplace plugin updates.
- **Machine-readable feeds/APIs:**
  - https://plugins.jetbrains.com/api/plugins/17718/updates?channel=&size=10
- **Known deprecations/migrations:** none explicit in official sources checked this run.
- **Monitoring recipe (monthly):**
  1. Poll JetBrains updates API and stable versions page.
  2. Cross-check matrix release rows for lag.
  3. Check Copilot changelog RSS for JetBrains feature rollout notes.
- **Feature notes (matrix keyed):** MCP/agent-mode/prompt-file support can move independently by plugin version and IDE compatibility range.

### 5) Xcode

- **Overview / users:** Apple-platform developers in Xcode.
- **Canonical docs hubs:**
  - https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-extension
  - https://github.com/github/CopilotForXcode
- **Canonical release/changelog streams:**
  - https://github.com/github/CopilotForXcode/releases
  - https://github.com/github/CopilotForXcode/blob/main/ReleaseNotes.md
- **Distribution channels/versioning:** GitHub releases (DMG), install via app and Xcode source editor extension enablement.
- **Machine-readable feeds:**
  - https://github.com/github/CopilotForXcode/releases.atom
- **Known deprecations/migrations:** none explicit in checked official sources.
- **Monitoring recipe (monthly):**
  1. Poll releases atom.
  2. Compare latest tag with `ReleaseNotes.md` header version.
  3. Cross-check matrix rows for support/lag.
- **Feature notes (matrix keyed):** chat/completion/agent mode/MCP features are matrix-tracked; release notes give operational behavior changes.

### 6) Eclipse

- **Overview / users:** Java and enterprise developers in Eclipse.
- **Canonical docs hubs:**
  - https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-extension
  - https://marketplace.eclipse.org/content/github-copilot#details
- **Canonical release/changelog streams:** Eclipse marketplace listing updates.
- **Distribution channels/versioning:** Eclipse Marketplace and Eclipse update site.
- **Machine-readable feeds:** no robust RSS/Atom source confirmed in this run.
- **Known deprecations/migrations / issues:**
  - Documented update site URL returned HTTP 404 during this run.
- **Monitoring recipe (monthly):**
  1. Check marketplace "Date Updated" and compatibility list.
  2. Validate update-site URL response.
  3. Cross-check Copilot changelog RSS and matrix changes.
- **Feature notes (matrix keyed):** Eclipse support differs from VS Code/Visual Studio; matrix should be treated as canonical feature gate.

### 7) Copilot CLI

- **Overview / users:** terminal-first users of Copilot via CLI workflows.
- **Canonical docs hubs:**
  - https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli
  - https://docs.github.com/en/copilot/how-tos/copilot-cli/install-copilot-cli
  - https://docs.github.com/en/copilot/how-tos/use-copilot-for-common-tasks/use-copilot-in-the-cli
- **Canonical release/changelog streams:**
  - https://github.com/github/copilot-cli/releases
- **Distribution channels/versioning:** GitHub Releases assets / CLI install docs.
- **Machine-readable feeds:**
  - https://github.com/github/copilot-cli/releases.atom
- **Known deprecations/migrations:** none explicit in checked official sources.
- **Monitoring recipe (monthly):**
  1. Poll releases atom.
  2. Confirm latest tag and release date.
  3. Validate install docs for prerequisite/command changes.
- **Feature notes (matrix keyed):** CLI is not represented as an IDE row in feature matrix; pair CLI docs with Copilot changelog.

### 8) OpenCode (Officially Copilot-Supported External Surface)

- **Overview / users:** OpenCode users integrating GitHub Copilot subscriptions in terminal/agent workflows.
- **Canonical docs hubs:**
  - GitHub changelog support announcement: https://github.blog/changelog/2026-01-16-github-copilot-now-supports-opencode/
  - OpenCode docs: https://opencode.ai/docs
  - Active repository: https://github.com/anomalyco/opencode
- **Canonical release/changelog streams:**
  - https://github.com/anomalyco/opencode/releases
- **Distribution channels/versioning:** install script/package managers and GitHub releases.
- **Machine-readable feeds:**
  - https://github.com/anomalyco/opencode/releases.atom
- **Known deprecations/migrations:**
  - `opencode-ai/opencode` is archived; active repo is `anomalyco/opencode`.
- **Monitoring recipe (monthly):**
  1. Poll Copilot changelog RSS for OpenCode support/policy updates.
  2. Poll `anomalyco/opencode` releases atom.
  3. Confirm active/default branch health in canonical repo.
  4. Verify docs site availability.
- **Feature notes (matrix keyed):** OpenCode is not currently a matrix IDE row; use GitHub changelog + OpenCode release channels for canonical updates.

### 9) NeoVim (Additional Official Surface)

- **Overview / users:** terminal/editor users with `copilot.vim`.
- **Canonical docs hubs:**
  - https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-extension
  - https://github.com/github/copilot.vim
- **Canonical release/changelog streams:** tags/commits and matrix release rows.
- **Distribution channels/versioning:** plugin manager installs (`github/copilot.vim`).
- **Machine-readable feeds:** repository commit/tag APIs (no dedicated release stream in current practice).
- **Known deprecations/migrations:** none explicit in checked official sources.
- **Monitoring recipe (monthly):**
  1. Check latest `copilot.vim` tags.
  2. Cross-check matrix NeoVim rows.
  3. Check Copilot changelog RSS for Neovim-specific announcements.
- **Feature notes (matrix keyed):** completion support remains primary; matrix indicates limited support for agentic features.

### 10) GitHub Mobile (Additional Official Surface)

- **Overview / users:** mobile chat interface use cases.
- **Canonical docs hubs:**
  - https://docs.github.com/en/copilot/how-tos/chat-with-copilot/chat-in-mobile
- **Canonical changelog streams:** Copilot changelog RSS.
- **Distribution channels/versioning:** mobile app release channels (App Store/Play) and GitHub service rollout.
- **Machine-readable feeds:** no Copilot-specific mobile feed found.
- **Monitoring recipe (monthly):**
  1. Poll Copilot changelog RSS for mobile entries.
  2. Re-check mobile chat docs for capability/plan changes.
- **Feature notes (matrix keyed):** mobile is not a matrix IDE row; use docs + changelog.

### 11) Windows Terminal Canary (Additional Official Surface)

- **Overview / users:** terminal chat users in Windows Terminal Canary.
- **Canonical docs hubs:**
  - https://docs.github.com/en/copilot/how-tos/chat-with-copilot/chat-in-windows-terminal
- **Canonical changelog streams:** Copilot changelog RSS.
- **Distribution channels/versioning:** Windows Terminal Canary release channels.
- **Machine-readable feeds:** no Copilot-specific terminal feed found.
- **Monitoring recipe (monthly):**
  1. Poll Copilot changelog RSS for terminal entries.
  2. Re-check terminal chat docs for setup/model/policy updates.
- **Feature notes (matrix keyed):** terminal is outside IDE matrix rows.

### 12) Azure Data Studio (Additional Official Surface)

- **Overview / users:** SQL/data tooling users.
- **Canonical docs hubs:**
  - https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-extension
  - https://learn.microsoft.com/en-us/azure-data-studio/extensions/github-copilot-extension-overview
- **Canonical changelog streams:** Azure Data Studio extension docs and Copilot changelog RSS.
- **Distribution channels/versioning:** Azure Data Studio extension installation flow.
- **Machine-readable feeds:** none identified in this run.
- **Monitoring recipe (monthly):**
  1. Re-check Azure Data Studio extension overview page.
  2. Cross-check Copilot changelog RSS.
- **Feature notes (matrix keyed):** not represented in matrix IDE rows.

## Cross-Cutting Canonical Streams (Customization and Governance)

These are not single-surface release channels but materially affect how teams use Copilot across surfaces.

1. **Custom instruction support matrix**
   - https://docs.github.com/en/copilot/reference/custom-instructions-support
   - Tracks support for `.github/copilot-instructions.md`, `.github/instructions/**/*.instructions.md`, and agent files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`) by environment/feature.
2. **Response customization (includes prompt files)**
   - https://docs.github.com/en/copilot/concepts/prompting/response-customization
   - Tracks prompt file behavior and customization semantics across tools.
3. **Prompt files tutorial and constraints**
   - https://docs.github.com/en/copilot/tutorials/customization-library/prompt-files/your-first-prompt-file
   - Confirms `.github/prompts`, `*.prompt.md`, public-preview status, and client support notes.
4. **Legacy metrics API retirement notice**
   - https://github.blog/changelog/2026-01-29-closing-down-notice-of-legacy-copilot-metrics-apis/
   - Includes published sunset dates and migration guidance to newer usage metrics APIs.
5. **Copilot usage metrics concepts and API**
   - https://docs.github.com/en/copilot/concepts/copilot-usage-metrics/copilot-metrics
   - https://docs.github.com/en/rest/copilot/copilot-usage-metrics
   - Canonical references for current metrics model and programmatic usage streams.

## Matrix-Linked Feature Areas (Canonical Mappings)

Use these as stable "feature-area" mappings when row-level version matrices lag operational releases.

1. **Agent mode**
   - Matrix anchor: `copilot-feature-matrix`
   - Canonical docs: https://docs.github.com/en/copilot/tutorials/enhance-agent-mode-with-mcp
   - Update stream: https://github.blog/changelog/label/copilot/feed/
2. **MCP**
   - Matrix anchor: `copilot-feature-matrix`
   - Canonical docs: https://docs.github.com/en/copilot/how-tos/provide-context/use-mcp/extend-copilot-chat-with-mcp
   - Update streams: Copilot changelog RSS + per-surface release notes
3. **Prompt files / custom instructions**
   - Matrix anchor: `copilot-feature-matrix`
   - Canonical docs:
     - https://docs.github.com/en/copilot/reference/custom-instructions-support
     - https://docs.github.com/en/copilot/concepts/prompting/response-customization
     - https://docs.github.com/en/copilot/tutorials/customization-library/prompt-files/your-first-prompt-file
   - Update streams: Copilot changelog RSS + VS Code/IDE release notes
4. **Code completion**
   - Matrix anchor: `copilot-feature-matrix`
   - Canonical docs: https://docs.github.com/en/copilot/how-tos/get-code-suggestions/get-ide-code-suggestions
   - Update streams: per-surface release notes/channels
5. **Copilot code review**
   - Matrix anchor: `copilot-feature-matrix`
   - Canonical docs: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/request-a-code-review/use-code-review
   - Update stream: Copilot changelog RSS
6. **Workspace indexing**
   - Matrix anchor: `copilot-feature-matrix`
   - Canonical docs: https://docs.github.com/en/copilot/concepts/context/repository-indexing
   - Update stream: Copilot changelog RSS + IDE release notes
7. **Copilot usage metrics**
   - Canonical docs:
     - https://docs.github.com/en/copilot/concepts/copilot-usage-metrics/copilot-metrics
     - https://docs.github.com/en/rest/copilot/copilot-usage-metrics
   - Retirement/migration notice:
     - https://github.blog/changelog/2026-01-29-closing-down-notice-of-legacy-copilot-metrics-apis/
   - Update stream: Copilot changelog RSS

## Entitlement/Plan Notes (Only Material Availability Impacts)

- Some features are plan-gated (for example coding-agent capabilities). Canonical plan reference:
  - https://docs.github.com/en/copilot/get-started/plans
- Use matrix + plan docs together before marking feature availability as generally available.

# Copilot CLI Source Intelligence

> Calibrated from February 2026 cycle. CLI releases v0.0.399–v0.0.408.

## Extraction Profile

- **Primary source URL**: `https://github.com/github/copilot-cli/releases`
- **Atom feed**: `https://github.com/github/copilot-cli/releases.atom`
- **Content model**: GitHub Releases with bullet-point changelogs per version
- **Release cadence**: Daily (sometimes multiple per day). Pre-releases have `-N` build suffixes (e.g., `v0.0.404-0`, `v0.0.404-1`); stable releases have no suffix after the final digit (e.g., `v0.0.408`).
- **CRITICAL**: The GitHub blog changelog (`github.blog/changelog/`) only publishes occasional summary posts (2-3 per month) that aggregate multiple releases. These blog posts lag behind by days/weeks and miss many features. **The releases page is the source of truth for feature discovery.** Blog posts are useful as supplementary links for narrative context on major features.
- **Items per release**: ~3-8 items per stable release (mix of Added, Improved, Fixed) (initial calibration — refine after 2-3 cycles)
- **Newsletter period volume**: A 30-day period includes ~30 stable releases; a 60-day period includes ~60. Feature aggregation across releases is essential. (initial calibration — refine after 2-3 cycles)
- **Feature matrix**: CLI is NOT represented in the [Copilot feature matrix](https://docs.github.com/en/copilot/reference/copilot-feature-matrix). Features must be tracked via the releases page.

## Extraction Strategy

1. Fetch the releases page and identify all **stable releases** (no `-0`, `-1` suffix) within DATE_RANGE
2. Aggregate all features into a **single feature-centric list** — never produce per-version bullets
3. Categorize by type:
   - **Major capabilities**: Plan mode, background agents/delegate, plugins/marketplace, autopilot, ACP protocol
   - **Platform integrations**: MCP server support, SDK, workspace-local config, ACP
   - **Customization**: Skills, hooks, custom agents, instructions, slash commands
   - **Quality-of-life**: Themes, permissions, keyboard shortcuts, diff mode
   - **Bug fixes**: Skip unless security-related
4. Cross-reference blog changelog for richer narrative descriptions of major features
5. Output is one consolidated bullet in the newsletter, not per-release entries

## What Survives (High Signal)

These CLI feature types consistently make the newsletter:
- **Agent orchestration**: Background agents, delegate, subagents, custom agents (100% survival)
- **Major new modes**: Plan mode, autopilot mode, review mode (100% survival)
- **Protocol/SDK**: ACP, MCP, Copilot SDK (100% survival)
- **Plugin ecosystem**: Marketplace, plugin hooks, skills integration (high survival)
- **Memory/context**: Repository memory, auto-compaction, sessions (high survival)

## What Gets Cut (Low Signal)

- **Keyboard shortcuts and bindings**: Ctrl+X, Ctrl+P remaps (0% survival)
- **Theme/visual polish**: Color themes, styling (0% survival)
- **Bug fixes**: Crash fixes, rendering issues (0% survival unless security-related)
- **ACP implementation details**: Client protocol internals (0% survival)
- **Windows-specific fixes**: Path handling, MSI improvements (0% survival)

## Treatment Patterns

- **Single bullet**: CLI always appears as one consolidated bullet in the "Copilot Everywhere" section
- **Velocity narrative**: The bullet should convey the daily shipping cadence as part of the platform story
- **SDK separate**: The Copilot SDK is included in the same bullet but could be broken out if it grows
- **Legal notice**: MUST include DPA and Pre-Release License Terms links per editorial-intelligence rules
- **Cross-references**: Blog posts used as links for major features; releases page as the primary "See also" link

## Cross-Referencing

- Blog changelog posts: Use as supplementary narrative links for major features
- VS Code terminal features: Some overlap with CLI features (terminal sandboxing, auto-approve rules)
- OpenCode: Competitive framing context (CLI vs Claude Code vs OpenCode)

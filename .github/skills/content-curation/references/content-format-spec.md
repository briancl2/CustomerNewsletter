# Content Format Specification

Formatting rules for Phase 3 curated newsletter content.

## Bullet Format

### Single Item
```markdown
-   **[Feature Name] (GA/PREVIEW)** - Description focusing on enterprise impact (1-2 sentences). - [Announcement](URL) | [Docs](URL)
```

### Multi-Item (Parity Style)
```markdown
-   **Improved IDE Feature Parity**
    - **Visual Studio Major Update** - Key GA features, then PREVIEW. - [Announcement](URL)
    - **Cross-Platform Updates** - JetBrains adds [feature](URL), Eclipse now has [feature](URL), and Xcode gains [feature](URL)
```

## Link Label Mapping (by URL Pattern)

Use the label that matches the URL domain, NOT a generic label:

| URL contains | Required label | NEVER use |
|-------------|---------------|----------|
| `github.blog/changelog/` | `[Changelog]` | `[Announcement]` |
| `github.blog/news-insights/` | `[GitHub Blog]` | `[CPO Blog]`, `[CEO Blog]`, `[Announcement]` |
| `github.blog/` (other paths) | `[GitHub Blog]` | `[Blog Post]`, `[CPO Blog]` |
| `code.visualstudio.com/updates` | `[Release Notes]` | `[Changelog]` |
| `learn.microsoft.com/` | `[Docs]` | `[Article]` |
| `docs.github.com/` | `[Docs]` | `[Article]` |
| `plugins.jetbrains.com/` | `[JetBrains Plugin]` | `[Changelog]` |
| `github.com/.../releases` | `[Release Notes]` | `[Changelog]` |

**No internal role titles in link labels.** Readers do not know who the CPO is. `CPO Blog`, `CEO Blog`, `VP Blog` are always `[GitHub Blog]`.

## Link Density and Format

Default: 2-3 pipe-separated links at the end of the bullet.

**Link labels must NEVER include status text (L68).** Status belongs in the bullet text as `` (`GA`) `` or `` (`PREVIEW`) ``, never in the link label. Use just the item name.
- **Wrong**: `[GPT-5.1 GA](URL)` — status leaked into link label
- **Right**: `[GPT-5.1](URL)` — clean label, status in bullet text

**Every feature bullet should include at least one docs/implementation link (L68).** Changelog links tell the reader WHAT changed. Docs links tell them HOW to use it. Enterprise readers need both. When a changelog entry has a corresponding VS Code release notes section or GitHub Docs page, add that link. Example: Agentic Memory gets [Changelog] + [GitHub Blog] + [VS Code Setup] + [Memory Docs].

**Threshold-based link format (L67):**
- **1-3 links**: Inline pipe-separated at end of bullet: `- [Changelog](URL) | [Docs](URL)`
- **4-6 links**: Inline pipe-separated, may wrap to next line. Still at end of bullet.
- **7+ links**: Use **inline feature linking** where feature names within the description text ARE the links. No separate link block at end. This is the most natural reading format.

**Inline feature linking example (7+ links):**
```markdown
-   **Copilot CLI (`PREVIEW`)** -- [Plan mode](URL) for structured task planning, [/review](URL) for code review in the terminal, [repository memory](URL) across sessions, [ACP protocol support](URL) for agent orchestration, and [direct installation from gh](URL). The new [Copilot SDK](URL) provides libraries for Node.js, Python, Go, and .NET. Covered under the [DPA](URL) and [Pre-Release Terms](URL) while in preview.
```

**Wrong** (sub-bullet link list):
```markdown
-   **Feature** -- Description...
    - [Link 1](URL)
    - [Link 2](URL)
    - [Link 3](URL)
```

Sub-bullet links are NEVER used for source reference links. Sub-bullets are only for nested content items (e.g., JetBrains version features, legal sub-bullets).

## Release Labels

- **(GA)**: Generally Available, production-ready
- **(PREVIEW)**: All pre-release stages (Beta, Experimental, Private Preview)
- When both GA and PREVIEW components exist: **include both, GA first**
- **Default to PREVIEW when status is ambiguous (L67)**. Only use `GA` when a source EXPLICITLY says "generally available" or "GA". Extension announcements ("X is now available in Y IDEs") do NOT imply GA. This prevents cross-section label conflicts.
- **Every model and feature name MUST have its own individual backtick label** immediately after the name: `GPT-5.3-Codex (`GA`)`, not prose grouping like "Now GA: GPT-5.3-Codex, GPT-5.2". Never use bold grouping headers (`**Now GA**:`) within bullets.
- Use `[Text](URL)` format only (never `[[Text]](URL)`)

## Commercial Context Rule (L68)

When a feature has incremental cost implications (or explicitly no incremental cost), add a brief commercial note. Enterprise readers always ask about cost. Examples:
- Third-party agents: "no additional cost, existing terms apply"
- BYOK: "usage billed directly by your provider"
- Auto Model Selection: "10% discount on model multiplier"
- New surfaces (OpenCode, CLI): "no additional configuration, existing subscription"

## Intra-Section Ordering Rule (L68)

Within each section, order items by **revenue impact and enterprise value**, not by date or alphabetical order:
1. **Revenue-positive features first** — features that drive PRU adoption, exec buy-in, or license expansion (Copilot Code Review, metrics dashboards)
2. **GA features before PREVIEW** — production-ready items are more actionable
3. **Security/compliance features** — regulated-industry urgency
4. **Experimental/terminal/polish features last** — interesting but not decision-driving

## Same-Domain Consolidation Rule (L68)

When two or more items in the same section share the same domain topic, ALWAYS consolidate into a single bullet. Never have two separate bullets about the same feature area. Examples:
- Two secret scanning entries → one "Secret Scanning Updates" bullet
- Code scanning alerts + Security Lab Taskflow Agent → one "Code Scanning and AI Triage" bullet
- Copilot metrics dashboard + metrics API deprecation → one bullet covering both
- Copilot Code Review without license + Code Review in DR → one "Copilot Code Review" bullet

## Multi-Surface Feature Consolidation Rule (L68)

When the same feature or capability spans multiple surfaces (VS Code + github.com, or IDE + CLI), consolidate into a single bullet that covers all surfaces. Never have separate bullets for the same feature on different surfaces. Examples:
- Agents Tab (github.com) + Multi-Agent Session Management (VS Code) → one "Multi-Agent Management" bullet covering both surfaces
- Copilot Code Review (github.com) + Code Review in DR → one bullet
- CLI memory + VS Code memory → one "Agentic Memory" bullet

## Enterprise Governance Consolidation Rule (L68)

ALL governance/admin items (budgets, custom properties, Teams APIs, app controls, policy enforcement, admin restrictions, team limits, metrics, dashboards) consolidate into the Enterprise and Security section. Copilot at Scale contains ONLY the standard changelog links footer, no content bullets. Within Enterprise and Security, group all governance items into a single "Enterprise Governance Roundup" bullet.

## Model Consolidation

**Cross-cycle validated (100% consistency across Dec, Aug, Jun, May):**

When ANY number of model rollouts occur, ALWAYS compress into a single bullet. No exceptions per curator guidance: models are commodity updates. List GA first, then PREVIEW. **Every model name MUST have its own individual backtick label**:
```markdown
-   **Model availability updates** -- GPT-5.3-Codex (`GA`), GPT-5.2 (`GA`), Claude Opus 4.6 (`GA`), Claude Opus 4.6 Fast (`PREVIEW`), Gemini 3 Flash (`PREVIEW`). Extended to all IDEs. Select older models being deprecated. - [GPT-5.3](URL) | [Claude 4.6](URL) | [Deprecations](URL)
```

**Wrong** (prose grouping): `**Now GA**: GPT-5.3, GPT-5.2. **In Preview**: Gemini 3 Flash.`
**Right** (per-model labels): `GPT-5.3-Codex (`GA`), GPT-5.2 (`GA`), Gemini 3 Flash (`PREVIEW`).`

## Governance Bundling

**Cross-cycle validated (3 of 4 cycles):**

When 3+ related governance/platform items exist, bundle into a single enriched bullet:
```markdown
-   **Enterprise Governance Updates** - Org custom properties for repo classification (GA), supply chain traceability with SLSA L3, and Dependabot OIDC for private registries. - [Custom Props](URL1) | [Supply Chain](URL2) | [OIDC](URL3)
```
## IDE Parity Format (Gold Standard from December 2025)

The IDE parity section uses **feature-centric**, **per-IDE paragraph** format with comprehensive labeling:

```markdown
-   **Visual Studio -- [Month] Update** -- Feature A (`GA`), Feature B (`PREVIEW`). Description. - [Changelog](URL) | [Blog](URL)

-   **JetBrains IDEs** -- Gains Feature A (`GA`), Feature B (`PREVIEW`), Feature C (`PREVIEW`). Note about policies. - [Plugin Updates](URL)

-   **Eclipse** -- Gains Feature A (`PREVIEW`), Feature B (`PREVIEW`). - [Changelog](URL)

-   **Xcode** -- Gains Feature A (`PREVIEW`), Feature B (`GA`), model support. - [Release Notes](URL)
```

**Critical rules for IDE parity**:
- Every feature has an explicit `GA`/`PREVIEW` label -- no exceptions
- Feature-centric listing ("Gains Agent Skills (`PREVIEW`), MCP Registry (`PREVIEW`)"), NOT version-by-version ("v1.5.60: Custom Agents, v1.5.62: MCP Registry")
- All 4 non-VS-Code IDEs that had updates MUST appear
- VS Code content NEVER appears in IDE parity -- it belongs in Latest Releases
- Standard rollout note at the bottom

## VS Code Version Number Rule (L66)

Never reference specific VS Code version numbers (v1.108, v1.109, etc.) in newsletter body text. With weekly releases, version numbers are meaningless to readers. Features are attributed to "VS Code" generically. Version URLs appear in links only (e.g., `[Release Notes](https://code.visualstudio.com/updates/v1_109#_agent-skills)`).
## IDE Parity Bundling

**Cross-cycle validated (100% consistency across all 4 cycles):**

ALL IDE parity items ALWAYS nest under a single parent bullet. JetBrains and Xcode items NEVER get standalone bullets (they are parity sources). Notable unique IDE features (not parity) get their own standalone bullet outside the parity section per curator guidance.

## Governance and Legal

ALWAYS expand legal/indemnity changes with sub-bullets per curator guidance: the audience under-discovers legal changes and they remove enterprise adoption barriers. Surface under Copilot at Scale:
```markdown
-   **Updated IP indemnity coverage** - Copilot's IP indemnity now extends to agent mode outputs and MCP tool results for enterprise customers. - [Announcement](URL) | [Terms](URL)
```

## Standard Changelog Links

Always include in Copilot at Scale section:
```markdown
### Stay up to date on the latest releases
- [GitHub Copilot Changelog](https://github.blog/changelog/label/copilot/feed/)
- [VS Code Copilot Changelog](https://code.visualstudio.com/updates/#_github-copilot)
- [Visual Studio Copilot Changelog](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes#github-copilot)
- [JetBrains Copilot Changelog](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable)
- [XCode Copilot Changelog](https://github.com/github/CopilotForXcode/blob/main/ReleaseNotes.md)
- [Eclipse Copilot Changelog](https://marketplace.eclipse.org/content/github-copilot#details)
```

## Factual Framing Rules

Never use "any" as a universal quantifier for platform capabilities (e.g., "any agent", "any model", "any surface"). Use "more" or specific counts. The VALUE PROP for platform openness is always: "one set of terms, one payment, one platform to manage users, set budgets, and govern policies" -- not a capability claim that may overclaim.

## Enumerable Taxonomy Rule

When a feature introduces a taxonomy (N agent types, N model tiers, N security levels), list ALL members explicitly. Never summarize with vague phrasing like "improved agent management" or "enhanced model support". Enterprise admins need the complete picture to evaluate what to enable. Example: "5 agent types: local, cloud, background, Claude, and partner agents" -- not "agent session management".

## Related Feature Stacking Rule

When a feature is an add-on/extension to another feature (not independently useful), merge into the parent feature's bullet. Stack multiple release links chronologically to show velocity. Never give an add-on its own top-level bullet if the parent feature exists in the same newsletter.

## Formatting Rules

- **Bold** product names, feature names, headlines
- **No em dashes**: Use commas, parentheses, or rephrase
- **No raw URLs**: All links embedded as `[Descriptive Text](URL)`
- **Bullet points** for lists
- **Professional but conversational** tone
- Enterprise-focused language throughout
- Strip all metadata (dates, relevance scores, IDE support fields) from final output

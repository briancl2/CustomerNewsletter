# Editorial Intelligence

> Accumulated editorial knowledge from analysis of 14 published newsletters, 4 rich intermediate cycles, and 339 benchmark files. Data-driven, not aspirational.

## 1. Theme Detection Rules

### When to Create a Lead Section

A lead section appears in ~29% of newsletters (4 of 14). Create one when ANY trigger fires:

| Trigger | Example | Detection Signal |
|---------|---------|------------------|
| **Competitive positioning** | Feb 2026: "Copilot Everywhere" (CLI + OpenCode + 3P agents + BYOK) | Multiple items signaling platform openness or competitive wins against rival tools |
| **High-count governance clustering** | Dec 2025: "Enterprise AI Governance" (7 items) | >=5 items on governance/security/compliance/admin that form a coherent narrative |
| **Single blockbuster launch** | Jun 2025: "GitHub Coding Agent Launch" | A new product category or platform capability so significant it redefines the landscape |
| **Hot-topic urgency** | Jan 2025: "o3-mini and r1 Models Update" | External event with high industry attention that customers will ask about |
| **Strategic positioning** | Dec 2024: "Azure DevOps Messaging from Microsoft" | Platform-level strategic shift that frames how customers should think about their toolchain |

### When NOT to Create a Lead Section

- Multiple topics of similar weight (no dominant cluster)
- Low-content months
- Conference months where events structure dominates
- When Copilot features are numerous but don't form a meta-narrative

### Decision Logic

```
IF new_product_category_launch → lead = product name
ELIF governance_security_cluster >= 5 items → lead = governance narrative title
ELIF hot_topic_with_high_external_attention → lead = topic name
ELIF strategic_platform_positioning → lead = strategic frame
ELSE → no lead section; start with Copilot Latest Releases
```

## 2. Selection Priority Weights (Calibrated)

Based on actual content distribution across 5 agentic-era newsletters (116 bullets analyzed), plus Feb 2026 corrections.

| Priority | Category | Weight | Evidence |
|----------|----------|--------|----------|
| 1 | **Competitive Positioning** (features that counter rival tools: CLI vs Claude Code, OpenCode vs alternatives, 3P agent support, BYOK/platform openness) | **3.5x** | Feb 2026 correction: Agent HQ 3P, OpenCode, CLI were THE story. Competitive context drives lead sections. |
| 2 | **Governance/Admin** (policies, controls, billing, metrics, dashboards) | **3.0x** | 16% of content, always expanded, drives lead sections. Q1=A confirmed. |
| 3 | **Security/Compliance** (scanning, GHAS, Dependabot, CVEs, supply chain) | **2.5x** | 10% of content, drives lead sections, regulated-industry critical |
| 4 | **GA Status** (any feature reaching General Availability) | **2.0x** | GA items always listed first in their section |
| 5 | **Novelty** (underappreciated items, new categories, legal changes) | **2.0x** | 3% of content but 100% expansion rate when present. Q3=A: legal always expanded. |
| 6 | **Platform Openness** (BYOK, 3P integrations, multi-surface support) | **2.0x** | BYOK is BIDIRECTIONAL: (1) bring your Copilot subscription OUT to more surfaces (OpenCode, CLI, 3P tools), AND (2) bring your own API keys INTO GitHub for custom models. Always frame both directions. Feb 2026: "take your subscription anywhere or bring any subscription to GitHub" |
| 7 | **IDE Parity** (cross-IDE feature rollout) | **1.5x** | 11% of content, formalized nested-bullet pattern. Q7=B: unique features get standalone bullets. |
| 8 | **Copilot Features** (agents, chat, completions, MCP) | **1.0x** (baseline) | 34% of content, largest category |
| 9 | **Platform** (Actions, repos, PRs, Code Quality) | **1.0x** | 9% of content |
| 10 | **Developer Productivity** (workflow improvements) | **0.8x** | Lower priority for EM/IT leadership audience |

### Mandatory Exclusions (unchanged)
- Copilot Free/Individual/Pro/Pro+ features
- Consumer/personal-account features
- Minor bug fixes (unless security CVEs)
- Community/open-source-focused content (not enterprise-relevant)

### Enterprise Signal Keywords

**High survival signal**: `governance`, `enterprise`, `admin`, `policy`, `compliance`, `GA`, `security`, `dashboard`, `metrics`, `budget`, `indemnity`, `DPA`, `agent`, `control plane`, `allowlist`, `regulated`, `CLI`, `competitive`, `opencode`, `BYOK`, `third-party`, `3P`, `platform`

**Low survival signal**: `blog`, `open source`, `community`, `bug fix`, `improvement`, `minor`, `maintenance`, `mobile`, `personal`

## 3. Expansion Triggers

An item gets expanded treatment (sub-bullets, 3+ lines) when:

| Trigger | Treatment | Example |
|---------|-----------|---------|
| **New product category** | Own section with framing intro | Code Quality, Coding Agent |
| **>=3 distinct sub-capabilities** admins evaluate separately | Indented sub-bullets | MCP ecosystem (6 features), Agent HQ (5 capabilities) |
| **Novel/underappreciated** by audience | Full explanation with context | Indemnity/DPA changes (7 lines) |
| **Cross-IDE with different features per IDE** | Nested parity bullet + rollout note | IDE Parity pattern |
| **Cross-product integration** with measurable impact | Integration details + metrics | Defender for Cloud (50% fix rate) |
| **DPA/legal coverage available** for a PREVIEW feature | ALWAYS add Note with links to BOTH DPA and indemnity/IP terms pages. Enterprise customers need this for legal approval. Missing DPA links is a blocker for regulated industries. | Copilot CLI: link to DPA-Covered Previews page AND Pre-Release License Terms (indemnity). Feb 2026: CLI still missing DPA + indemnity links in V1 |
| **Feature description ambiguous from changelog title** | Cross-check against official docs page before publishing | BYOK: changelog says "encryption keys" but docs say "LLM API keys" |
| **New consumption/billing model** (3P agents, new model access, new surface) | Add explicit cost note: "covered by existing subscriptions consuming the same PRUs" or equivalent. Enterprise readers always ask about incremental cost. | Feb 2026: 3P agents needed explicit PRU coverage note |
| **Partnership/integration with competitor-adjacent tool** | Frame as "official partnership" with competitive context (name the rivals). Show why this matters vs alternatives. Never present as just "Copilot supports X". | Feb 2026: OpenCode needed "vs Claude Code, Codex CLI" framing |
## 4. Compression Rules

An item gets compressed (single bullet, consolidated) when:

| Trigger | Treatment | Example |
|---------|-----------|---------|
| **Model availability** (any count) | ALWAYS single "Model availability updates" bullet; GA first, PREVIEW second. No exceptions. (Curator confirmed: Q2=A, models are commodity.) | GPT-5.1 + Gemini + Claude = 1 bullet |
| **Same-type group** (2+ related announcements from the same feature area) | Single bullet with combined links | Billing API + Budget Tracking = 1 bullet |
| **Simple admin feature** with no complexity | Single sentence, one link | "AI Controls Delegation (GA)" |
| **Training/evergreen resource** | Include ONLY when new resources published (Q4=B). Do not pad with stale evergreen. | New adoption guide = include; existing playlists = skip unless new |

### Cross-Category Governance Bundling (G5)

When >=3 items from different categories share a governance theme, consolidate into a single named roundup bullet (e.g., "Enterprise Governance Roundup"). This prevents governance items from being scattered across sections and emphasizes their collective narrative.

### Context-Dependent Exclusion (G6)

In months with >=25 discoveries and a strong lead section, exclude incremental improvements even from high-weight categories. A strong lead absorbs reader attention; each additional item past ~20 bullets dilutes impact. Prioritize depth over breadth when content is rich.

### Metric Confidence Filtering

Only include quantitative metrics directly stated in source material. Remove derived calculations and per-unit cost extrapolations. Example: "~10 hours saved per user per month" (directly stated at VA.gov) is fine. "~$1.25 per user" (calculated, not directly stated) must be removed.

### Status Label Accuracy (from Polishing Data)

NEVER assume a feature is GA in one IDE because it is GA in another. For JetBrains, Eclipse, and Xcode features, check each IDE's specific changelog independently. **Only apply GA/PREVIEW labels when the source text contains exact status language** ("generally available", "public preview", "technical preview", "experimental", "beta"). If the source says "now available", "now supports", or uses RELEASE tagging without an explicit status qualifier, **omit the label entirely**. Common over-claims to guard against: BYOK was labeled GA but was actually public preview; OpenCode support had no status label but was given GA; VS Code features often lack explicit labels. Use qualified labels when status varies by IDE: `` (`GA` in VS Code, `PREVIEW` elsewhere) ``. Add policy notes when features require admin enablement.

## 5. Audience-Specific Signals

### Healthcare/Manufacturing/Financial Services Emphasis

These items always score higher for this audience:
- Data residency and key management (BYOK)
- Compliance and audit capabilities
- Indemnity and legal protections for AI outputs
- Policy enforcement and governance controls
- Self-hosted runners (network policy compliance)

### Conference Month Behavior

During GitHub Universe, Microsoft Build, or Microsoft Ignite months:
- Restructure events section with detailed session tables
- Conference content may justify a lead section
- Session recommendations filtered for enterprise relevance

## 6. Blind Spots (Current Rules Miss These)

| # | Pattern | Evidence | Rule Needed |
|---|---------|----------|-------------|
| 1 | Evergreen training resources included every month | Copilot at Scale always has guides/playlists | "Include 2-3 training items monthly regardless of recency" |
| 2 | New product categories get own sections | Code Quality, Coding Agent | "New product categories → own ## section, not nested" |
| 3 | Legal changes always expanded | Indemnity got 7 lines | "Legal protections → always expand with sub-bullets" |
| 4 | Cross-product integrations prioritized | Defender, Azure MCP | "GitHub × customer stack integrations get priority" |
| 5 | Conference months restructure | Build tables, Universe taxonomy | "Major conference → restructure events with session tables" |
| 6 | Magnitude overrides category | VS 2026 GA in Announcements, not IDE Parity | "Exceptionally significant items can be recategorized upward" |
| 7 | Ecosystem maturity signals included | Slack, Linear, Mobile integrations | "Integrations showing Copilot maturity get included even if not enterprise-critical" |

## 7. Cross-Cycle Patterns

### Structural Constants (every recent newsletter)
- Introduction with "personally curated" + archive link
- Copilot section with Latest Releases
- Copilot at Scale with changelog links (6 IDEs) + GitHub Previews + Preview Terms Changelog
- Events section with YouTube playlists (3)
- Closing section with list management offer ("add or remove anyone from this list")
- Link density: 1.3-3.0 links per bullet
- Content: 15-42 bullets (varies by month richness)
- Multi-item sections open with bold framing intro: **Theme Name** -- Enterprise value sentence
- Bullet anatomy: `-   **Feature Name (`STATUS`)** -- Description. - [Label](URL) | [Label2](URL2)`
- Bold rules: product names, feature titles, technical standards, model names = bold. Status labels = backtick. Generic nouns = never bold.
- Link format: `[Label](URL)` with ` | ` pipe separator for multiple links. Never `[[Label]](URL)` double-bracket.

### Conditional Patterns
- Lead section: 4 triggers (see §1)
- IDE Parity nested bullet: when cross-IDE updates exist
- Conference session tables: conference months only
- Additional sections (Security, Actions, GHAS): when content justifies
- In-person events: when events exist

### Quality Trend
- Pre-agentic: raw URLs, no labels, no structure
- Transition (Apr 2025): bullets, GA labels, closing section
- Agentic (Jun 2025+): events tables, Copilot at Scale, IDE parity
- Mature agentic (Dec 2025): lead sections, PREVIEW labels, cross-product integration

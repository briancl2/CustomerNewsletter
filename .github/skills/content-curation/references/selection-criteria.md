# Selection Criteria

> Calibrated from analysis of 116 bullets across 5 agentic-era newsletters (Apr-Dec 2025).
> See `reference/editorial-intelligence.md` for full methodology and evidence.

## Weighted Priority Order

Weights reflect actual editorial practice, not generic enterprise relevance. Synced with `reference/editorial-intelligence.md` Section 2.

| Priority | Category | Weight | Evidence |
|----------|----------|--------|----------|
| 1 | **Competitive Positioning** (features that counter rival tools: CLI vs Claude Code, OpenCode vs alternatives, 3P agent support, BYOK/platform openness) | **3.5x** | Feb 2026 correction: Agent HQ 3P, OpenCode, CLI were THE story. Competitive context drives lead sections. |
| 2 | **Governance/Admin** (policies, controls, billing, metrics, dashboards) | **3.0x** | 16% of content, always expanded, drives lead sections |
| 3 | **Security/Compliance** (scanning, GHAS, Dependabot, CVEs, audit) | **2.5x** | 10% of content, drives lead sections, regulated-industry critical |
| 4 | **GA Status** (any feature reaching General Availability) | **2.0x** | GA items always listed first in their section |
| 5 | **Novelty** (underappreciated items, new product categories, legal changes) | **2.0x** | 3% of content but 100% expansion rate when present |
| 6 | **Platform Openness** (BYOK, 3P integrations, multi-surface support) | **2.0x** | Feb 2026: "take your subscription anywhere or bring any subscription to GitHub" is a top theme |
| 7 | **IDE Parity** (cross-IDE feature rollout) | **1.5x** | 11% of content, formalized nested-bullet pattern |
| 8 | **Copilot Features** (agents, chat, completions, MCP) | **1.0x** (baseline) | 34% of content, largest category |
| 9 | **Platform** (Actions, repos, PRs, Code Quality) | **1.0x** | 9% of content |
| 10 | **Developer Productivity** (workflow improvements, tips) | **0.8x** | Lower priority for EM/IT leadership audience |

### Recency Gate (Pre-Filter)
All items must be within the specified DATE_RANGE. Items outside the range are excluded regardless of weight.

### GA Over PREVIEW (Cross-Cutting)
When both GA and PREVIEW components exist for the same feature, always include both with GA listed first. GA status provides a 2.0x boost to any category.

### Revenue-First Ordering Within Sections (L68)
Within each section, order items by enterprise revenue impact:
1. Revenue-positive features (Code Review, metrics dashboards, features that drive PRU adoption)
2. GA features (production-ready, actionable)
3. Security/compliance (regulated-industry urgency)
4. PREVIEW features (interesting, less urgent)
5. Experimental/polish features (lowest priority)

## Expansion Triggers

Expand an item (sub-bullets, 3+ lines) when:

1. **New product category**: Give it its own section with framing intro
2. **>=3 distinct sub-capabilities** that admins evaluate separately: List as indented sub-bullets
3. **Novel/underappreciated** by audience: Full explanation with context
4. **Cross-IDE with different features per IDE**: Nested parity bullet + rollout note
5. **Cross-product integration** with measurable impact: Include metrics
6. **Legal protection changes** (indemnity, DPA, terms): Always expand with sub-bullets explaining each protection

## Compression Triggers

Compress an item (single bullet, consolidated) when:

1. **Model availability** (any number of models): ALWAYS single "Model availability updates" bullet, GA first then PREVIEW. No exceptions. Models are commodity. (Q2=A)
2. **Same-type group** (2+ related announcements from the same feature area): Single bullet with combined links
3. **Simple admin feature** with no complexity: Single sentence, one link
4. **Training/evergreen resource**: Include under Copilot at Scale ONLY when new resources were published that month. Do not include stale/evergreen training content. (Q4=B)

### Cross-Category Governance Bundling (G5)

When >=3 items from different categories share a governance theme, consolidate into a single named roundup bullet (e.g., "Enterprise Governance Roundup"). This prevents governance items from being scattered across sections and emphasizes their collective narrative.

### Context-Dependent Exclusion (G6)

In months with >=25 discoveries and a strong lead section, exclude incremental improvements even from high-weight categories. A strong lead absorbs reader attention; each additional item past ~20 bullets dilutes impact. Prioritize depth over breadth.

## Lead Section Detection

Create a lead section when ANY trigger fires:
- **Competitive positioning**: Multiple items signaling platform openness or competitive wins against rival tools
- **Governance clustering**: >=5 items on governance/security/compliance forming a narrative
- **Blockbuster launch**: New product category that redefines the landscape
- **Hot-topic urgency**: High external attention event customers will ask about
- **Strategic positioning**: Platform-level strategic shift

Otherwise: no lead section; start with Copilot Latest Releases.

## Enterprise Signal Keywords

**High survival signal**: `governance`, `enterprise`, `admin`, `policy`, `compliance`, `GA`, `security`, `dashboard`, `metrics`, `budget`, `indemnity`, `DPA`, `agent`, `control plane`, `allowlist`, `regulated`

**Low survival signal**: `blog`, `open source`, `community`, `bug fix`, `improvement`, `minor`, `maintenance`, `mobile`, `personal`

## Enterprise Filter

### Always Include
- GA features for enterprise plans
- High-impact preview features with broad enterprise value
- Security, compliance, and audit features
- Administration, governance, and policy features
- IDE feature parity updates
- Evergreen training resources only when new items are published that month, up to 2-3 in Copilot at Scale (Q4=B)
- Cross-product integrations (especially Azure, Microsoft 365, security toolchain)
- Legal/indemnity changes (always expanded)

### Always Exclude
- Copilot Free/Individual/Pro/Pro+ specific features
- Consumer-focused features
- Minor bug fixes (unless security CVEs)
- Features only for personal accounts
- Community/open-source-focused content
- Individual developer workflow tweaks without enterprise value

## Audience-Specific Boosts (Healthcare/Manufacturing/FinServ)

These items score even higher for this specific audience:
- Data residency and encryption key management (BYOK)
- Compliance, audit, and regulatory capabilities
- Indemnity and legal protections for AI outputs (ALWAYS expand with sub-bullets, per Q3=A)
- Policy enforcement and governance controls
- Self-hosted runners (network policy compliance)
- Azure/M365 integrations (highest integration priority, per Q5=A)

## Newsletter Length Target

- **Sweet spot**: 120-150 lines (per Q6=A)
- **Rich months**: Up to 175 lines acceptable when content justifies
- **Under 120**: Too thin; likely missing important items
- **Over 175**: Likely needs tighter compression or item cuts

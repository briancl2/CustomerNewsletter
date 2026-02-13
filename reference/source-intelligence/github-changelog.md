# GitHub Changelog Source Intelligence

> Calibrated from December 2025 cycle. github.blog/changelog/2025/10/, /11/, /12/.

## Extraction Profile

- **Primary source**: `https://github.blog/changelog/YYYY/MM/` (monthly archives)
- **Secondary source**: `https://github.blog/news-insights/company-news/` (major strategic announcements — NOT in Changelog feed)
- **Content model**: Dated entries with type (RELEASE/IMPROVEMENT/RETIRED), labels (COPILOT, ACTIONS, etc.), URLs
- **Volume**: 40-60 entries per month

## CRITICAL: Dual-Feed Scanning

The GitHub Changelog is the **richest source** but has a critical blind spot:
- **Changelog** (`/changelog/`) — technical release entries (most items)
- **News & Insights** (`/news-insights/company-news/`) — strategic CPO/CEO posts, product vision

BOTH must be scanned. The Feb 2026 Agent HQ 3P launch (CPO blog post) was ONLY on news-insights.

## Survival Rates (December 2025, top 30 enterprise items)

| Stage | Count | Rate |
|-------|-------|------|
| Raw items traced | 30 | 100% |
| Survived to discoveries | 18 | 60% |
| Survived to published | 17 | 57% |
| Discovery-to-publish drop | 1 | 3% |

## Full Source: 98 items → ~40 published (41% overall survival)

## What Survives (High Signal)

**Near 100% survival**: 
- Enterprise governance: Agent HQ, AI controls, BYOK, policy updates, billing controls
- Copilot features: Code review, coding agent, custom agents, model updates
- Major product launches: Code Quality, Coding Agent (get own sections)
- Cross-product integrations: Defender for Cloud, Azure MCP

**~50% survival**:
- Platform features: Actions custom images, secret scanning major updates
- Administration: License management, fine-grained permissions

**~20% survival**:
- Security updates: Secret scanning monthly updates, CodeQL improvements
- General platform: Code search, issues improvements

## What Gets Cut (Low Signal)

- **Community/OSS blog posts**: Open source spotlights, maintainer stories (0% survival)
- **GHES releases**: On-premise releases dropped even at 10/10 relevance score (editorial choice)
- **Secret scanning monthly updates**: Incremental improvements consistently dropped
- **Enterprise code search features**: Too narrow for newsletter scope
- **Required reviews for rulesets**: Despite 9/10 score, dropped (admin-specific)
- **License consumption reporting**: Administrative but too granular

## Treatment Patterns

- **Expanded (standalone)**: Agent HQ, BYOK, Code Quality, Defender, Code Review — items that represent new capabilities or governance controls
- **Bundled**: Policy updates (2-3 policy items → 1 bullet), billing controls (2 items → 1 bullet), model availability
- **Compressed**: AI controls delegation (1 line), Copilot Spaces (1 line)

## Cross-Cycle Validation (Aug + Jun + May)

August: 18 GH Changelog items discovered, 18 survived (100%). 8 additional items added during curation.
June: 11 GH Changelog items discovered, 11 survived (100%). 6 additional items added during curation.
May: 8 GH Changelog items in published newsletter. No separate discoveries available.

**Cross-cycle pattern**: GitHub Changelog items are NEVER cut. The editorial process only ADDS to them.

## Under-Discovery Gaps (items always added during curation)

- Visual Studio devblogs (devblogs.microsoft.com/visualstudio) — every cycle
- Azure ecosystem (devblogs.microsoft.com/devops, Copilot for Azure) — Jun, Aug
- Enablement resources (resources.github.com, training links) — every cycle
- Strategic blog posts (github.blog/news-insights/) — Feb 2026
- Legal/terms updates — when applicable

# February 2026 Editorial Corrections

> Captured 2026-02-10. These corrections feed back into editorial-intelligence.md and selection-criteria.md.

## Critical Miss: Agent HQ 3P Platform (Claude + Codex)
- **URL**: https://github.blog/news-insights/company-news/pick-your-agent-use-claude-and-codex-on-agent-hq/
- **Why missed**: Fetched only from github.blog/changelog/, not github.blog/news-insights/. Blog posts from news-insights/company-news are NOT in the changelog feed.
- **Fix needed**: Phase 1A url-manifest must include github.blog/news-insights/ pages, not just changelog. Add blog homepage scan to catch major announcements.
- **Severity**: Critical. This is the most impactful announcement of the month (CPO blog post).

## Theme Correction: Lead Should Be "Copilot Everywhere"
Human's preferred lead theme: **More Support for More Surfaces**
- Copilot CLI rapid development (look deeper for innovative features)
- OpenCode support (competitive win vs Claude Code, ecosystem breadth signal)
- Claude + Codex in Agent HQ (3P agents on GitHub platform)
- BYOK (bring your subscription to GitHub or bring GitHub to your subscription)

The connecting narrative: **You can take your GitHub subscription anywhere, or bring your AI subscription into GitHub.** This is about platform openness and competitive positioning.

My V1 lead ("Copilot Platform Maturation") was too abstract and missed the competitive angle entirely.

## Competitive Intelligence Gap
The human sees competitive pressure from Claude Code. This context should inform:
- CLI features get higher weight (direct Claude Code competitor)
- OpenCode support is NOT niche, it's a competitive win signal
- 3P agent support (Claude, Codex in Agent HQ) is THE story of the month
- BYOK is about customer choice and platform lock-in avoidance

Current selection criteria have NO competitive positioning weight. This is a blind spot.

## Specific Item Corrections

| Item | V1 Rating | Corrected Rating | Learning |
|------|-----------|-----------------|----------|
| Agent HQ: Claude + Codex | MISSING | Include/Expand/Lead | Must scan blog homepage, not just changelog |
| OpenCode Support | Borderline/Compress/Back | Include/Standard/Lead | Competitive win signal. Not niche. |
| Copilot CLI features | Include/Standard/Body | Include/Expand/Lead | CLI is a competitive surface. Look deeper. |
| Copilot SDK | Include/Standard/Lead | Include/Standard/Lead (bundled) | Bundle with MCP Server in Lead section |
| Agentic Memory | Include/Expand/Lead | Include/Expand/Lead | Keep but reframe under broader theme |
| BYOK Enhancements | Include/Standard/Body | Include/Standard/Lead | Platform choice narrative |
| Dependabot OIDC Auth | Include/Standard/Body | Exclude (or bundle) | Bundle with supply chain if included |
| CodeQL Improvements | Include/Compress/Body | Exclude | Not newsletter-worthy this month |
| Supply Chain + Org Custom Props + Dependabot | Separate items | Bundle into one enterprise governance bullet | Consolidate related governance features |
| All deprecations | 2 separate items | Bundle into one "Migration Notices" entry | Single deprecation bullet |
| VS Code v1.109 | Include/Compress/Body | Include/Standard/Body (dig deeper) | VS Code changelogs hide important features. Read the actual release notes page. |

## Bundling Corrections

| Bundle | Items Combined | Treatment |
|--------|---------------|-----------|
| Lead: "Copilot Everywhere" | Agent HQ 3P, CLI features, OpenCode, BYOK | Expand. Lead section. |
| Enterprise Governance | Supply chain traceability, Org custom props, Dependabot OIDC | Standard. Single body bullet. |
| Deprecation Notices | Legacy metrics API, model deprecations, Dependabot PR comments | Compress. Single Back bullet. |

## Process Fixes Required

1. **url-manifest skill**: Add github.blog/news-insights/ scan (not just changelog)
2. **selection-criteria.md**: Add competitive positioning weight (CLI, OpenCode, 3P agents)
3. **Phase 1B content-retrieval**: Deep-read VS Code release notes page, not just the changelog entry
4. **editorial-intelligence.md**: Add competitive awareness as a signal dimension
5. **Review loop**: Must be built into the core process, not manual

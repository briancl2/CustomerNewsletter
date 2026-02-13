# Consolidation Rules

> Deduplication logic, enrichment patterns, and category taxonomy for Phase 1C.
> Cross-cycle validated: these patterns are 100% consistent across Dec, Aug, Jun, May 2025.

## Key Finding: Consolidation = Enrichment + Dedup

Cross-cycle meta-analysis (see `reference/source-intelligence/meta-analysis.md`) shows the pipeline does NOT cut items. The consolidation phase should:
1. **Deduplicate** cross-source items (same feature from GitHub + VS Code + JetBrains)
2. **Enrich** by adding items from under-discovered sources (Visual Studio devblogs, Azure ecosystem, GitHub news-insights, enablement resources)
3. **Pre-bundle** by grouping related items that will be compressed in Phase 3 (models, governance, parity)

## Deduplication Rules

### Rule 1: Same Feature, Multiple Sources
When the same feature appears in multiple interim files:
- Merge into a **single item**
- Keep the **earliest** announcement date
- Combine **all source URLs** (prioritize: Changelog > Blog > Release Notes > Docs)
- Note **IDE support breadth** (which IDEs have the feature)

**Example**: "Agent mode" appears in GitHub Changelog, VS Code notes, Visual Studio notes, JetBrains plugin
- Result: One "Agent mode" entry with all 4 source URLs and IDE matrix showing all 4 IDEs

### Rule 2: Same Feature, Different Dates (Rollout)
When the same feature appears at different dates across sources:
- Keep as a **single item** with date range
- Note rollout progression (e.g., "VS Code Oct 15, JetBrains Nov 18")
- Use earliest date as the primary date

### Rule 3: Similar but Distinct Features
When features are related but not identical:
- Keep as **separate items**
- Note the relationship in descriptions
- Example: "Custom agents for VS Code (GA)" and "Custom agents for JetBrains (PREVIEW)" are separate

### Rule 4: Cross-Reference Validation
For major announcements, verify presence across expected sources:
- Model releases: should appear in Changelog + at least 1 IDE release note
- Feature GA: should appear in Blog + Changelog
- Security fixes: should include CVE references

## Enterprise Relevance Scoring (1-10)

| Score | Meaning | Action |
|-------|---------|--------|
| 9-10 | Must include | Always include. GA enterprise features, major security, platform-wide. |
| 7-8 | Strong candidate | Include. Significant IDE updates, admin features, governance. |
| 5-6 | Space permitting | Include if category has room. Preview features, minor improvements. |
| 1-4 | Exclude | Do not include. Consumer features, bug fixes, minor UI tweaks. |

### Scoring Dimensions

- **Adoption**: Helps enterprises adopt Copilot (+2)
- **Administration**: Helps admins manage Copilot (+2)
- **Security**: Addresses enterprise security concerns (+2)
- **Productivity**: Improves developer productivity at scale (+2)
- **Integration**: Improves enterprise toolchain integration (+2)

### Mandatory Exclusions

- Copilot Free plan features
- Copilot Individual plan features
- Copilot Pro/Pro+ specific features
- Consumer-focused features (personal accounts only)
- Minor bug fixes (unless security CVEs)

## Category Taxonomy

### Monthly Announcement Candidates (3-5 items)
- Platform-wide announcements with broad enterprise impact
- Major feature launches (new product categories)
- Conference/Universe announcements
- Enterprise-impacting policy changes

### Copilot Latest Releases (8-12 items)
- New model availability (GA and PREVIEW)
- IDE feature updates (agents, chat, completions)
- Code completion and suggestion improvements
- New capabilities (MCP, custom agents, plan agent)

### Copilot at Scale (4-6 items)
- Enterprise administration features
- Policy management and governance
- Usage metrics and reporting
- Adoption enablement and training resources
- Custom instructions and customization
- Billing and license management
- Legal/indemnity changes

### GitHub Platform Updates (5-10 items)
- GitHub Advanced Security (GHAS) features
- Actions improvements
- Code Search enhancements
- Pull Request features
- General platform features
- Secret scanning, Dependabot updates

### Deprecations and Migrations (0-3 items)
- Deprecated features with timelines
- Migration requirements
- End-of-life notices

## IDE Support Matrix Format

For Copilot features, include IDE support status:

| IDE | Status |
|-----|--------|
| VS Code | One of: available, coming, not planned |
| Visual Studio | One of: available, coming, not planned |
| JetBrains | One of: available, coming, not planned |
| Xcode | One of: available, coming, not planned |
| Eclipse | One of: available, coming, not planned |

## Output Format Checklist

- [ ] No em dashes used (use commas or parentheses)
- [ ] All links are descriptive markdown: `[Text](URL)`
- [ ] Bold formatting for product/feature names
- [ ] ISO dates (YYYY-MM-DD)
- [ ] GA/PREVIEW labels on all items where known

---
name: content-consolidation
description: "Merges, deduplicates, and filters 5 interim files for enterprise relevance. Use when running Phase 1C of the newsletter pipeline. Takes 5 source-specific interim files from Phase 1B, consolidates into 30-50 enterprise-relevant discoveries. Keywords: consolidation, phase 1c, deduplication, enterprise filter, discoveries."
metadata:
  category: domain
  phase: "1C"
---

# Content Consolidation

Merge, deduplicate, and filter 5 Phase 1B interim files into a single discoveries document.

## Quick Start

1. Read all 5 interim files from Phase 1B
2. Aggregate items into a working list with source tracking
3. Deduplicate: same feature from multiple sources becomes one item
4. Categorize into 5 taxonomy categories
5. Filter for enterprise relevance (score 5+)
6. Write output to `workspace/newsletter_phase1a_discoveries_YYYY-MM-DD_to_YYYY-MM-DD.md`

## Inputs

All 5 Phase 1B interim files (required):
- `workspace/newsletter_phase1b_interim_github_*.md`
- `workspace/newsletter_phase1b_interim_vscode_*.md`
- `workspace/newsletter_phase1b_interim_visualstudio_*.md`
- `workspace/newsletter_phase1b_interim_jetbrains_*.md`
- `workspace/newsletter_phase1b_interim_xcode_*.md`

## Output

- **File**: `workspace/newsletter_phase1a_discoveries_YYYY-MM-DD_to_YYYY-MM-DD.md`
- **Target**: 20-40 items with balanced category distribution

> **Legacy naming note**: The output filename uses `phase1a_discoveries` despite being produced by Phase 1C. This is a historical convention preserved for compatibility with benchmark data, archived intermediates, and downstream prompt references. All downstream consumers (content-curation, prompts, agent) reference this exact name pattern.

## Core Workflow

> **Key finding** (see `reference/source-intelligence/meta-analysis.md`): Cross-cycle analysis shows the pipeline does NOT cut items. 100% discovery survival in Aug+Jun+May 2025. The real editorial value is in ADDITIONS (Azure, devblogs, resources), BUNDLING (models, parity, governance), and EXPANSION (flagships). This phase should ENRICH and CONSOLIDATE, not just filter.

### Step 1: Aggregate

Read all 5 interim files. For each item, record: source file, date, title, URLs, status (GA/PREVIEW), relevance score, IDE support.

### Step 1.5: Enrich (Gap-Filling)

Check for known under-discovery gaps (L29, L30, L31). These sources are consistently missing from Phase 1B output but always appear in published newsletters:

- **Visual Studio devblogs**: Search GitHub Changelog for entries containing "Visual Studio". Check devblogs.microsoft.com/visualstudio/ for monthly Copilot updates.
- **Azure ecosystem**: Check devblogs.microsoft.com/devops/ for Azure DevOps migration content, Azure MCP Server, Copilot for Azure updates.
- **GitHub news-insights**: Check github.blog/news-insights/company-news/ for strategic CPO/CEO announcements not in the changelog feed.
- **Enablement resources**: Check resources.github.com for new rollout playbooks, training content, Copilot Fridays additions.

### Step 2: Deduplicate

See [consolidation-rules.md](references/consolidation-rules.md) for full dedup logic.

**Key rules**:
- Same feature from multiple sources: merge into single item, keep earliest date, combine all URLs, note IDE support breadth
- Same feature with different dates: single item with rollout timeline
- Similar but distinct features (e.g., "Auto model for VS Code" vs "Auto model for JetBrains"): keep separate but note relationship

### Step 3: Categorize

Apply the 5-category taxonomy with target counts:

| Category | Target Count | Scope |
|----------|-------------|-------|
| Monthly Announcement Candidates | 3-5 | Platform-wide, major launches, enterprise-impacting |
| Copilot Latest Releases | 8-12 | Models, IDE features, chat/agent enhancements |
| Copilot at Scale | 4-6 | Admin, policy, metrics, adoption, customization |
| GitHub Platform Updates | 5-10 | GHAS, Actions, Code Search, PRs, general platform |
| Deprecations and Migrations | 0-3 | End-of-life, migration requirements |

### Step 4: Enterprise Relevance Filter

Apply relevance scoring (1-10 scale):
- **9-10**: Must include (GA enterprise features, major security)
- **7-8**: Strong candidate (significant updates)
- **5-6**: Include if space permits
- **1-4**: Exclude

**Always exclude**: Copilot Free/Individual/Pro/Pro+ features, consumer-only features, minor bug fixes.

### Step 5: Label and Validate

- Apply consistent status labels: (GA), (PREVIEW), (EXPERIMENTAL), (DEPRECATED), (RETIRING)
- Add IDE support matrix using checkmarks
- Cross-reference: model releases should appear in Changelog + IDE notes; feature GA should appear in Blog + Changelog
- Verify all items are within DATE_RANGE and Reference Year

### Step 5.5: Coverage Audit

Check that ALL standard newsletter categories have been assessed. If a category that appeared in recent newsletters has ZERO items, explicitly note: `[Category]: No updates found in DATE_RANGE (verified: checked [sources])`. This prevents silent omission of recurring sections.

Standard categories to audit: Security Updates, Code Quality, Platform Updates, Enterprise Admin, IDE Updates, Copilot Features, Deprecations.

### Step 6: Write Output

Write the discoveries file with:
- Coverage summary table (source, item count, date range)
- Items organized by category
- Each item with full metadata
- Validation results checklist

## Reference

- [Consolidation Rules](references/consolidation-rules.md) - Dedup logic, scoring, taxonomy
- [Editorial Intelligence](../../../reference/editorial-intelligence.md) - Theme detection, selection weights, expansion/compression rules
- [Benchmark Example](examples/) - Known-good Dec 2025 discoveries

## Done When

- [ ] Discoveries file exists at `workspace/newsletter_phase1a_discoveries_*.md`
- [ ] Total items: 20-40
- [ ] Category distribution within target ranges
- [ ] Zero duplicate items across sources
- [ ] No consumer-plan items included
- [ ] All items have source URLs (markdown links)
- [ ] All items within DATE_RANGE
- [ ] IDE coverage from all 5 sources represented

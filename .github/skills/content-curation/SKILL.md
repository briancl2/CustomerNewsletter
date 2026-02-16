---
name: content-curation
description: "Transforms raw discoveries into polished, newsletter-ready content sections. Use when running Phase 3 of the newsletter pipeline. Selects and structures high-value items from 30-50 discoveries, applies GA/PREVIEW labels, and prepares complete section material for assembly. Keywords: content curation, phase 3, selection, formatting, enterprise relevance."
metadata:
  category: domain
  phase: "3"
---

# Content Curation

Transform Phase 1C discoveries into polished, newsletter-ready content sections.

## Quick Start

1. Read Phase 1C discoveries from `workspace/newsletter_phase1a_discoveries_*.md`
2. Select items using selection criteria with range-aware depth targets
3. Organize into full newsletter sections: Lead (optional), Copilot (Latest + IDE Parity), Enterprise and Security, Platform, Resources and Best Practices
4. Apply formatting: bold terms, GA/PREVIEW labels, embedded links, strip metadata
5. Write output to `workspace/newsletter_phase3_curated_sections_YYYY-MM-DD.md`

## Inputs

- **Phase 1C Discoveries**: `workspace/newsletter_phase1a_discoveries_*.md` (required)

## Output

- **File**: `workspace/newsletter_phase3_curated_sections_YYYY-MM-DD.md`
- **Target**: range-aware depth
  - >=60-day range: 24+ curated bullets
  - >=30-day range: 18+ curated bullets
  - <30-day range: 12+ curated bullets
- **Content**: Full section-ready material (no final intro/closing text)

## Core Workflow

### Step 1: Analyze Discoveries

Read Phase 1C input. Inventory candidates by:
- Enterprise relevance and impact
- Recency within DATE_RANGE
- Thematic clusters that could drive a lead section
- Overlapping/duplicate items needing consolidation

### Step 2: Select and Bundle Items

Apply selection criteria in priority order. See [selection-criteria.md](references/selection-criteria.md).

> **Key finding** (see `reference/source-intelligence/meta-analysis.md`): Cross-cycle analysis shows discoveries have ~100% survival rate. The curation job is NOT selection (nearly everything survives). It is:
> 1. **Bundling**: Models → single bullet. IDE parity → nested bullet. Governance cluster → single enriched bullet.
> 2. **Flagship detection**: 1-2 items per cycle get expanded dedicated sections.
> 3. **Gap-filling**: Add Azure, devblogs, enablement content the pipeline missed.
> 4. **Competitive framing**: Identify competitive positioning signals (CLI vs Claude Code, 3P agents, OpenCode, BYOK = platform openness).

Priority weights:
1. **Competitive positioning** (3.5x) — features that counter rival tools
2. **Governance/Admin** (3.0x) — policies, controls, billing, metrics
3. **Security/Compliance** (2.5x) — scanning, GHAS, supply chain
4. **GA Status** (2.0x) — GA always leads
5. **Novelty** (2.0x) — underappreciated items, new categories, legal changes
6. **Platform openness** (2.0x) — BYOK, 3P integrations, multi-surface
7. **IDE Parity** (1.5x) — cross-IDE rollout
8. **Copilot Features** (1.0x baseline)

### Step 3: Organize Into Sections

**Lead Section** (optional): Only when discoveries show a clear theme (major launch, vision update). Derive title from content cluster, not generic label.

**Copilot (H1) + Latest Releases (H2)**: Use `# Copilot` then `## Latest Releases`. New features, model updates, and agent capabilities go here. VS Code features are grouped by feature theme (not by version number). Never reference specific VS Code version numbers in bullet text; version numbers appear only in links.

**Enterprise and Security Updates**: Governance, billing, compliance, security controls, deprecations.

**GitHub Platform Updates**: Actions, Projects, PR workflows, repository/platform improvements.
> **Benchmark override:** When `BENCHMARK_MODE=feb2026_consistency`, fold these into Enterprise and Security instead of a standalone H1.

**Resources and Best Practices**: Enablement assets, implementation guides, adoption assets, operator tips.

**Events handoff stubs**: Curate references that should feed into event framing, including virtual, in-person, and behind-the-scenes cues.

**Copilot CLI placement (mandatory)**:
- Keep the consolidated Copilot CLI bullet in `# Copilot Everywhere: ...`, not under Enterprise/Platform.
- The CLI bullet must include legal links while in preview:
  - `https://docs.github.com/en/site-policy/github-terms/github-dpa-previews`
  - `https://docs.github.com/en/site-policy/github-terms/github-pre-release-license-terms`
- Include `https://github.com/github/copilot-cli/releases` in the same bullet or its immediate "See also" links.

### Step 3.5: Build Cross-IDE Feature Alignment Matrix (L66)

Before writing the IDE parity section, build a feature alignment matrix. This is the single most important step for IDE parity quality.

**Procedure**:
1. List ALL features that appeared in ANY non-VS-Code IDE during the period (Visual Studio, JetBrains, Eclipse, Xcode)
2. For each feature, check its **end-of-period status** in EACH IDE:
   - `GA` = Generally Available
   - `PREVIEW` = Public Preview / Experimental
   - `—` = Not available in this IDE
3. Cross-reference with VS Code status (from Latest Releases) to identify parity vs. unique features
4. Record the matrix in a working table:

```
| Feature | VS Code | Visual Studio | JetBrains | Eclipse | Xcode |
|---------|---------|--------------|-----------|---------|-------|
| Agent Skills | GA | — | PREVIEW | — | — |
| MCP Registry | GA | — | PREVIEW | — | PREVIEW |
```

5. Use this matrix to generate the IDE parity section:
   - **Every IDE that had ANY update MUST appear** (all 4 non-VS-Code IDEs if they had updates)
   - **Every feature MUST have a GA/PREVIEW label** per IDE (never omit labels)
   - **Feature-centric format** (list features per IDE, not versions per IDE)
   - JetBrains: list features with labels, NOT version-by-version changelogs
   - Include the standard rollout note at the bottom

**Gate**: If Eclipse or Xcode had releases in the period but do not appear in the parity section, STOP and add them.

### Step 4: Format

See [content-format-spec.md](references/content-format-spec.md) for complete formatting rules.

Key rules:
- Strip all raw metadata (dates, scores, IDE fields) from output
- Merge duplicates into single consolidated entry
- Bold key terms, no em dashes, no raw URLs
- GA/PREVIEW labels when known, omit when ambiguous
- Link priority: [Announcement] > [Docs] > [Release Notes] > [Changelog]
- Consolidate model rollouts into single "Model availability updates" bullet
- Surface governance/legal under Copilot at Scale

### Step 5: Quality Check

Before writing output:
- [ ] Lead section included only when clear theme exists
- [ ] Copilot section has Latest Releases + IDE Parity grouping
- [ ] Copilot at Scale includes enterprise items + changelog links
- [ ] GA before PREVIEW when both exist for same feature
- [ ] Labels omitted when ambiguous
- [ ] No Copilot Free/Individual/Pro/Pro+ mentions
- [ ] Metadata stripped from final bullets
- [ ] All links use `[Text](URL)` format (never `[[Text]](URL)`)
- [ ] Status labels verified per-IDE (never assume GA because another IDE is GA)
- [ ] PREVIEW features with DPA coverage have a Note with link
- [ ] Quantitative metrics are directly from source (no derived calculations)
- [ ] Sections with 3+ items have a bold framing intro: **Theme** -- Enterprise context
- [ ] Feature descriptions cross-checked against docs, not just changelog titles
- [ ] Range-aware depth floor met (24+/18+/12+ bullets)
- [ ] `Resources and Best Practices` material present when enablement sources exist
- [ ] At least one curator-note signal (if notes exist) is reflected in curated sections

## Reference

- [Selection Criteria](references/selection-criteria.md) - Priority hierarchy, enterprise filter, audience weights
- [IDE Parity Rules](references/ide-parity-rules.md) - Parity bullet format, rollout note
- [Content Format Spec](references/content-format-spec.md) - Bullet format, link priority, governance rules
- [Editorial Intelligence](../../../reference/editorial-intelligence.md) - Theme detection, expansion triggers, competitive positioning
- [Benchmark Example](examples/) - Known-good Dec 2025 curated sections

## Key Signals to Watch For

Before curating, check for these high-weight signals in the discoveries:
1. **Competitive positioning**: CLI features (vs Claude Code), 3P agent support, OpenCode, BYOK (platform openness)
2. **Governance clustering**: >=5 admin/policy/compliance items forming a narrative
3. **Blog posts from news-insights/**: Major strategic announcements (CPO/CEO posts) that may not be in the changelog
4. **VS Code hidden features**: Read the actual release notes page, not just the changelog entry summary

## Done When

- [ ] Curated sections file exists at `workspace/newsletter_phase3_curated_sections_*.md`
- [ ] Range-aware depth floor is met (24+/18+/12+ bullets by window size)
- [ ] Proper section structure is present (Lead if warranted, Copilot, Enterprise and Security, Platform, Resources and Best Practices)
- [ ] GA/PREVIEW labels present where known
- [ ] IDE Parity pattern with rollout note included
- [ ] Standard changelog links in Copilot section footer
- [ ] Copilot CLI consolidated bullet is under Copilot Everywhere and includes DPA + Pre-Release Terms links
- [ ] No raw metadata, no em dashes, no raw URLs
- [ ] Enterprise focus throughout

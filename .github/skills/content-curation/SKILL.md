---
name: content-curation
description: "Transforms the compiled Phase 3 working set into polished, newsletter-ready content sections, with Phase 1C discoveries used only as a missing-data fallback. Use when running Phase 3 of the newsletter pipeline. Selects and structures high-value items, applies GA/PREVIEW labels, and prepares complete section material for assembly. Keywords: content curation, phase 3, selection, formatting, enterprise relevance."
metadata:
  category: domain
  phase: "3"
---

# Content Curation

Transform the Phase 3 working set into polished, newsletter-ready content sections, using Phase 1C discoveries only when the working set flags missing data.

## Quick Start

1. In orchestrated runs, first generate `workspace/newsletter_phase3_working_set_YYYY-MM-DD.md` with `python3 tools/build_phase3_working_set.py START END`
2. If `workspace/newsletter_phase3_curated_sections_YYYY-MM-DD.md` does not exist yet, create the canonical scaffold with `python3 tools/init_phase3_curated_sections.py START END`
3. Always edit the canonical scaffold in place. Do not create the curated sections artifact ad hoc through a generic create-file flow
4. If the working set exists, use it as the primary Phase 3 input and do not reread raw discoveries, interim IDE files, or long reference docs unless it explicitly flags missing data
5. Read Phase 1C discoveries from `workspace/newsletter_phase1a_discoveries_*.md` when no working set exists or the working set flags missing data
6. Select items using selection criteria with range-aware depth targets
7. Organize into full newsletter sections: Lead (optional), Copilot (Latest + IDE Parity), Enterprise and Security, Platform, Resources and Best Practices
8. Apply formatting: bold terms, GA/PREVIEW labels, embedded links, strip metadata
9. Validate the edited artifact with `python3 tools/validate_phase3_curated.py START END workspace/newsletter_phase3_curated_sections_YYYY-MM-DD.md`

## Inputs

- **Phase 3 Working Set**: `workspace/newsletter_phase3_working_set_*.md` (primary input in orchestrated mode)
- **Phase 1C Discoveries**: `workspace/newsletter_phase1a_discoveries_*.md` (fallback only when the working set is absent or flags missing data)

## Output

- **File**: `workspace/newsletter_phase3_curated_sections_YYYY-MM-DD.md`
- **Target**: range-aware depth
  - >=60-day range: 24+ curated bullets
  - >=30-day range: 18+ curated bullets
  - <30-day range: 12+ curated bullets
- **Content**: Full section-ready material (no final intro/closing text)

## Core Workflow

### Step 0: Initialize the Canonical Artifact

If `workspace/newsletter_phase3_curated_sections_YYYY-MM-DD.md` is absent, run:

```bash
python3 tools/init_phase3_curated_sections.py START END
```

Then edit that scaffold in place for the remainder of Phase 3. Do not switch to a different filename or try to recreate the artifact via a generic create-file action.

### Step 1: Analyze Working Set First

Read the compiled Phase 3 working set first. Only fall back to Phase 1C discoveries if the working set is absent or its Missing Data Gate explicitly says data is missing. Inventory candidates by:
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

**Lead Section** (optional): Only when the working set bundles show a clear theme (major launch, vision update). If you must fall back to discoveries, derive the title from that same dominant cluster rather than a generic label.

**Copilot (H1) + Latest Releases (H2)**: Use `# Copilot` then `## Latest Releases`. New features, model updates, and agent capabilities go here. VS Code features are grouped by feature theme (not by version number). Never reference specific VS Code version numbers in bullet text; version numbers appear only in links.

**Enterprise and Security Updates**: Governance, billing, compliance, security controls, deprecations.

**Legal venue routing (May 2026 guard)**: Standalone legal-readiness items such as Customer Copyright Commitment, CCC, Duplicate Detection, IP indemnity, legal terms changes, and required legal mitigations route to Enterprise and Security unless the lead theme itself is explicitly legal/compliance. Supporting DPA or Pre-Release Terms links may remain inside product/preview bullets when they document the status boundary; those supporting links do not drive the section venue. Do not place standalone legal-readiness content in UBB, cost, model-policy, or general rollout-readiness leads.

**High-velocity release streams (May 2026 guard)**: If a surface has >=10 stable releases, >=5 major capability families, or an operator requests exhaustive release review, do not synthesize from a category summary alone. Require a release inventory and capability-to-link map before final prose. Canonical artifacts are `workspace/copilot_cli_release_inventory_START_to_END.md`, `workspace/copilot_app_release_inventory_START_to_END.md` when applicable, and `workspace/newsletter_phase3_capability_map_START_to_END.json`. Dense prose is acceptable only when it names concrete commands/features and links representative capabilities inline; source-tail links alone do not satisfy the gate.

**Technical-preview app/product launches (May 2026 guard)**: Treat a new app/workflow surface as a product-category launch, not a routine feature. If release evidence exists, final prose must explain what users can do and link at least five major customer-visible capability clusters inline with public-safe targets. Authenticated release evidence can inform synthesis, but private release URLs and process notes stay out of customer-facing prose.

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
- [ ] Legal/CCC content appears under Enterprise and Security unless the lead is explicitly legal
- [ ] High-volume CLI/App bullets have release inventory evidence, a capability map, and enough inline capability links
- [ ] VS Code prose is organized by feature themes, not inline version sequences
- [ ] Authenticated/private release-process notes are absent from customer-facing prose

## Reference

- [Selection Criteria](references/selection-criteria.md) - Priority hierarchy, enterprise filter, audience weights
- [IDE Parity Rules](references/ide-parity-rules.md) - Parity bullet format, rollout note
- [Content Format Spec](references/content-format-spec.md) - Bullet format, link priority, governance rules
- [Editorial Intelligence](../../../reference/editorial-intelligence.md) - Theme detection, expansion triggers, competitive positioning
- [Benchmark Example](examples/) - Known-good Dec 2025 curated sections

## Key Signals to Watch For

Before curating, check for these high-weight signals in the working set bundles, then use Phase 1C only if the working set explicitly says data is missing:
1. **Competitive positioning**: CLI features (vs Claude Code), 3P agent support, OpenCode, BYOK (platform openness)
2. **Governance clustering**: >=5 admin/policy/compliance items forming a narrative
3. **Blog posts from news-insights/**: Major strategic announcements (CPO/CEO posts) that may not be in the changelog
4. **VS Code hidden features**: Read the actual release notes page, not just the changelog entry summary

## Done When

- [ ] Curated sections file exists at `workspace/newsletter_phase3_curated_sections_*.md`
- [ ] Canonical scaffold was initialized first when the curated file was absent
- [ ] Range-aware depth floor is met (24+/18+/12+ bullets by window size)
- [ ] Proper section structure is present (Lead if warranted, Copilot, Enterprise and Security, Platform, Resources and Best Practices)
- [ ] GA/PREVIEW labels present where known
- [ ] IDE Parity pattern with rollout note included
- [ ] Standard changelog links in Copilot section footer
- [ ] Copilot CLI consolidated bullet is under Copilot Everywhere and includes DPA + Pre-Release Terms links
- [ ] No raw metadata, no em dashes, no raw URLs
- [ ] Enterprise focus throughout
- [ ] `python3 tools/validate_phase3_curated.py START END <artifact>` passes

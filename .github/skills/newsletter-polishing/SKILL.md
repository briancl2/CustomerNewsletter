---
name: newsletter-polishing
description: "Applies automated polishing rules to a Phase 4 newsletter before human review. Runs deterministic structural fixes, content-aware normalization, and editorial guidelines mined from 132 actual polishing edits across 14 newsletters. Use as Phase 4.5 between assembly and editorial review. Keywords: polishing, phase 4.5, formatting, normalization, quality, post-assembly."
metadata:
  category: domain
  phase: "4.5"
---

# Newsletter Polishing

Apply automated polishing rules to a Phase 4 newsletter, eliminating ~34% of manual post-publication edits.

## Quick Start

1. Read the Phase 4 newsletter from `output/YYYY-MM_month_newsletter.md`
2. Apply Tier 1 structural fixes (zero-risk, deterministic)
3. Apply Tier 2 content-aware fixes (normalization)
4. Apply Tier 3 editorial guidelines (LLM-assisted)
5. Validate the polished newsletter
6. Write polished output back to `output/YYYY-MM_month_newsletter.md`

## Inputs

- **Phase 4 Newsletter**: `output/YYYY-MM_month_newsletter.md` (required)
- **Polishing Intelligence**: `reference/polishing-intelligence.md` (context)

## Output

- **Polished Newsletter**: `output/YYYY-MM_month_newsletter.md` (overwrite in place)
- Polishing report with changes applied

## Core Workflow

### Step 1: Tier 1 Structural Fixes (Zero-Risk)

Apply these deterministic fixes automatically. They eliminate formatting errors that appear in 34% of historical diffs.

| # | Rule | Action |
|---|------|--------|
| 1 | **Heading space** | Insert space after `#` in headings: `###Title` becomes `### Title` |
| 2 | **Bullet normalization** | Replace `•`, `*` (non-bold), and `**` (used as bullets) with `-` at top level |
| 3 | **Unicode cleanup** | Remove U+FFFC, U+200B, U+FEFF and other control characters |
| 4 | **Double spaces** | Collapse multiple spaces to single (except indentation) |
| 5 | **Space before paren** | Remove spaces before `)` |
| 6 | **Month abbreviations** | Use 3-letter abbreviations in event dates: `January` to `Jan`, etc. |
| 7 | **Heading hierarchy** | Validate: no `#` headings after the lead section; `###` must have a parent `##` |

### Step 2: Tier 2 Content-Aware Fixes

Apply these with review. They address naming consistency and label formatting.

| # | Rule | Action |
|---|------|--------|
| 8 | **Product name capitalization** | Apply canonical dictionary (see [product-names.md](references/product-names.md)). Common fixes: `coding agent` to `Coding Agent`, `agent mode` to `Agent Mode`, `copilot spaces` to `Copilot Spaces` |
| 9 | **Status label format** | Normalize to `` (`GA`) `` and `` (`PREVIEW`) ``. Never nest bold inside backticks. Remove inconsistent formats like `(GA)`, `(**GA**)`, `(Preview)` |
| 10 | **Link syntax validation** | Verify all `[text](url)` render correctly. No broken `](` patterns, no double brackets `[[text]](url)` unless intended |
| 11 | **Chronological event sorting** | Sort virtual and in-person events by date ascending |
| 12 | **Sub-bullet format** | Convert inline paragraphs under bullets to nested `    - ` sub-bullets. Max 3 sub-bullets per parent |
| 12b | **Link label audit** | Verify link labels match URL-to-label mapping: `github.blog/changelog/` = `[Changelog]` (never `[Announcement]`), `github.blog/news-insights/` = `[GitHub Blog]` (never `[CPO Blog]`), `code.visualstudio.com/updates` = `[Release Notes]`. No internal role titles (CPO, CEO, VP) in labels |
| 12c | **Deprecations consolidation** | Ensure all deprecation/sunset/migration notices appear exactly once as a single bundled bullet under **Enterprise and Security Updates**. Remove any standalone `# Migration Notices` section and remove duplicated deprecation links from other sections. |

### Step 3: Tier 3 Editorial Guidelines

Apply these using editorial judgment. They address content quality patterns.

| # | Rule | Action |
|---|------|--------|
| 13 | **Introduction accuracy** | Verify the highlights summary in the intro matches the actual content below. If it doesn't, rewrite the highlights to reflect the 2-3 most impactful items in the body |
| 14 | **Enterprise context check** | Every major bullet should have a "so what" phrase explaining enterprise relevance. Flag items that are purely descriptive with no enterprise value statement |
| 15 | **Link text accuracy** | Verify link labels match the source type: `[Changelog]` for changelog entries, `[Announcement]` for blog posts, `[Release Notes]` for release pages, `[Docs]` for documentation |
| 16 | **Wording precision scan** | Flag and review: `e.g.` vs `i.e.` usage, passive constructions, redundant qualifiers, pronoun ambiguity |
| 17 | **Superlative audit** | Flag universal quantifiers (`any`, `every`, `all`) applied to platform capabilities. Replace with specific or comparative framing (`more`, specific counts, `expanding`). "any agent" becomes "more agents". "all models" becomes specific model names |
| 18 | **Surface attribution audit** | For each bullet, verify the feature belongs in the section it is placed in. github.com features go under Platform/github.com sections, NOT under an IDE section. Common misattributions: Agents Tab = github.com (not VS Code), ACP = CLI (not VS Code). Check the feature's actual URL/docs to confirm |
| 19 | **Cross-section label consistency audit (L67)** | Scan for every model name and feature name that appears in MORE THAN ONE section (e.g., model bullet + IDE parity, or lead section + Latest Releases). Verify the `GA`/`PREVIEW` label is IDENTICAL in each occurrence. If conflicting, use the label from the official changelog announcement. Common conflict: model extensions to new IDEs get labeled `GA` in IDE parity but `PREVIEW` in model bullet. |

### Step 4: Validate

Run the standard validation:
```bash
bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh output/YYYY-MM_month_newsletter.md
```

Verify:
- [ ] 0 errors, 0 warnings
- [ ] Line count in expected range (100-170 lines)
- [ ] All Tier 1 fixes applied (no heading space issues, no bullet format issues)
- [ ] Product names match canonical dictionary
- [ ] Status labels in standard format
- [ ] Introduction highlights match body content

### Step 5: Report Changes

Produce a brief polishing report:
```
Polishing Report:
  Tier 1 fixes: N (heading space: X, bullet: Y, unicode: Z, ...)
  Tier 2 fixes: N (product names: X, labels: Y, links: Z, ...)
  Tier 3 review items: N (intro accuracy, enterprise context, ...)
  Validation: PASS/FAIL
```

## Reference

- [Product Names Dictionary](references/product-names.md) - Canonical product name forms
- [Polishing Intelligence](../../../reference/polishing-intelligence.md) - 13 patterns mined from 132 edits across 14 newsletters
- [Polishing Benchmark Data](../../../benchmark/polishing/) - Full edit history extraction

## Done When

- [ ] All Tier 1 rules applied (zero structural formatting issues)
- [ ] Product names match canonical dictionary
- [ ] Status labels in standard format
- [ ] Introduction highlights match body content
- [ ] Validation passes (0 errors)
- [ ] Polishing report produced

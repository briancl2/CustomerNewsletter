---
mode: agent
description: "Run the full newsletter pipeline from URL discovery through final assembly, validation, and editorial review. Orchestrates all 6 phases with phase gates."
---

# Newsletter Pipeline: Full Run

Generate a monthly customer newsletter by executing the skills-based pipeline end to end.

## Required Inputs

Before starting, you need:
- **DATE_RANGE**: `{{startDate}}` to `{{endDate}}`
- **Event URLs** (optional): URLs for upcoming events and webinars

## Execution Plan

Execute each phase in order. After each phase, verify the output file exists and has content before proceeding.

### Phase 0: Feed-Forward Learnings and Scope Contract

1. Read `LEARNINGS.md` for feed-forward lessons from previous runs
2. Note any lessons relevant to the current date range and content cycle
3. Apply relevant lessons throughout the pipeline (e.g., source gaps, bundling rules, deep-read requirements)
4. Read `.github/skills/scope-contract/SKILL.md` and generate the pre-pipeline scope manifest
5. Output: `workspace/newsletter_scope_contract_{{endDate}}.json`
6. **Gate**: Scope manifest exists, date range gap flagged if any, expected versions listed

### Phase 1A: URL Manifest

1. Read `.github/skills/url-manifest/SKILL.md`
2. Input: DATE_RANGE and `kb/SOURCES.yaml`
3. Output: `workspace/newsletter_phase1a_url_manifest_{{startDate}}_to_{{endDate}}.md`
4. **Gate**: File exists and has > 20 lines

### Phase 1B: Content Retrieval

1. Read `.github/skills/content-retrieval/SKILL.md`
2. Input: URL manifest from Phase 1A
3. Output: 5 interim files in `workspace/` (one per source)
4. **Gate**: All 5 expected interim files exist in `workspace/` (one per configured source; see `.github/skills/content-retrieval/SKILL.md` for expected filenames/patterns) and each has content

### Phase 1C: Content Consolidation

1. Read `.github/skills/content-consolidation/SKILL.md`
2. Input: Interim files from Phase 1B
3. Output: `workspace/newsletter_phase1a_discoveries_{{startDate}}_to_{{endDate}}.md`
4. **Gate**: File exists and has 30-50 items

### Phase 2: Events Extraction (can run after 1A)

1. Read `.github/skills/events-extraction/SKILL.md`
2. Input: Event URLs from github.com/resources/events and resources.github.com
3. Output: `workspace/newsletter_phase2_events_{{endDate}}.md`
4. **Gate**: File exists with virtual and/or in-person events

### Phase 1.5: Curator Notes Processing (optional, after 1C)

1. Read `.github/skills/curator-notes/SKILL.md`
2. Check for `workspace/curator_notes_*.md` or `workspace/<Month>.md` brain dump file
3. If no file exists: SKIP entirely, continue to Phase 3
4. If file exists: Parse, classify, visit URLs, cross-reference with Phase 1C discoveries
5. Output: `workspace/curator_notes_processed_*.md` + `workspace/curator_notes_editorial_signals_*.md`
6. **Gate**: If notes file existed, both output files exist. Processed items feed into Phase 3.

### Phase 3: Content Curation

1. Read `.github/skills/content-curation/SKILL.md`
2. Read `reference/editorial-intelligence.md` for selection weights and theme detection
3. Read `reference/source-intelligence/meta-analysis.md` for pipeline patterns
4. Input: Discoveries from Phase 1C + Curator notes processed items from Phase 1.5 (if available)
5. Output: `workspace/newsletter_phase3_curated_sections_{{endDate}}.md`
6. **Gate**: File exists with 15-20 curated items, proper section structure

### Phase 4: Newsletter Assembly

1. Read `.github/skills/newsletter-assembly/SKILL.md`
2. Input: Curated sections from Phase 3 + Events from Phase 2
3. Output: `output/YYYY-MM_month_newsletter.md`
4. **Gate**: File exists with 100-170 lines

### Post-Assembly: Validation

1. Run: `bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh output/YYYY-MM_month_newsletter.md`
2. **Gate**: Exit code 0, 0 errors

### Phase 4.5: Automated Polishing

1. Read `.github/skills/newsletter-polishing/SKILL.md`
2. If the newsletter contains any deprecation/sunset/migration notice content, read `.github/skills/deprecation-consolidation/SKILL.md` and apply it (single bundled bullet under **Enterprise and Security**, no standalone `# Migration Notices` section)
3. Read `reference/polishing-intelligence.md` for 13 polishing patterns
4. Apply Tier 1 structural fixes (heading space, bullets, unicode, double spaces)
5. Apply Tier 2 content-aware fixes (product names, status labels, link validation, event sorting)
6. Apply Tier 3 editorial guidelines (intro accuracy, enterprise context, wording scan)
7. Re-validate with validate_newsletter.sh
8. **Gate**: 0 errors, polishing report produced

### Phase 4.6: Video Matching

1. Read `.github/skills/video-matching/SKILL.md`
2. Fetch YouTube RSS feeds from VS Code (@code) and GitHub (@GitHub) channels
3. Match videos to newsletter entries by topic (HIGH confidence only)
4. Add `[Video (Xm)](URL)` links to matched entries with estimated duration
5. **Gate**: At least 3 video links added (typical range: 3-8 per newsletter)

### Post-Assembly: Scope Contract Validation

1. Read `.github/skills/scope-contract/SKILL.md` (post-pipeline section)
2. Read scope manifest from `workspace/newsletter_scope_contract_*.json`
3. Validate the final newsletter against all 6 scope checks
4. Output: `workspace/newsletter_scope_results_{{endDate}}.md`
5. **Gate**: All checks pass, or failures documented with fix recommendations

### Post-Assembly: Editorial Review Artifact

1. Produce `workspace/YYYY-MM_editorial_review.md` with per-item ratings
2. Format: table with columns (Item, Include/Borderline/Exclude, Expand/Standard/Compress, Lead/Body/Back, Rationale)
3. This artifact enables the human to provide corrections

## Phase 5: Editorial Review Loop (After Human Feedback)

When the human provides corrections at `workspace/YYYY-MM_editorial_corrections.md`:

1. Read `.github/skills/editorial-review/SKILL.md`
2. Apply all corrections to the newsletter
3. Re-validate with validate_newsletter.sh
4. Update intelligence files if corrections reveal patterns
5. Capture learnings in LEARNINGS.md
6. Report V1 vs V2 score comparison

## Post-Completion: Archive

After the newsletter is finalized:
```bash
bash tools/archive_workspace.sh YYYY-MM
```

## Key References

Read these before starting if this is your first run:
- `reference/editorial-intelligence.md` -- Theme detection, selection weights, treatment patterns
- `reference/source-intelligence/meta-analysis.md` -- Cross-cycle findings, pipeline behaviors
- `LEARNINGS.md` -- Feed-forward lessons from previous runs
- `HYPOTHESES.md` -- What we know and what we're testing

## Quality Standards

- Every item needs a source URL -- no hallucinated links
- Use GA / PREVIEW labels from official sources
- No em dashes, no wikilinks, no consumer plan mentions
- Enterprise focus: Healthcare, Manufacturing, Financial Services audience
- Professional but conversational tone

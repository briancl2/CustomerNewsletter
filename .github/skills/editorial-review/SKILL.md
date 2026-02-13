---
name: editorial-review
description: "Applies human editorial corrections to a generated newsletter and produces an updated version. Use as Phase 5 after the human provides corrections. Reads corrections file, applies changes to newsletter, updates intelligence files, captures learnings. Keywords: editorial review, phase 5, corrections, iteration, review loop."
metadata:
  category: domain
  phase: "5"
---

# Editorial Review Loop

Apply human editorial corrections to a Phase 4 newsletter and produce an updated version.

## Quick Start

1. Read the corrections file at `workspace/YYYY-MM_editorial_corrections.md`
2. Read the current newsletter at `output/YYYY-MM_month_newsletter.md`
3. Read `reference/editorial-intelligence.md` for calibrated rules
4. Apply each correction to the newsletter
5. Update intelligence files with new patterns
6. Validate the updated newsletter
7. Capture learnings in LEARNINGS.md

## Inputs

- **Corrections File**: `workspace/YYYY-MM_editorial_corrections.md` (required)
- **Current Newsletter**: `output/YYYY-MM_month_newsletter.md` (required)
- **Editorial Intelligence**: `reference/editorial-intelligence.md` (context)
- **Source Intelligence**: `reference/source-intelligence/meta-analysis.md` (context)

## Output

- **Updated Newsletter**: `output/YYYY-MM_month_newsletter.md` (overwrite in place)
- **Updated Intelligence**: Changes to `reference/editorial-intelligence.md` if corrections reveal new patterns
- **New Learnings**: Appended to `LEARNINGS.md`

## Corrections File Format

The human writes corrections to `workspace/YYYY-MM_editorial_corrections.md`. The required structure, sections, and per-item table format are defined in the single authoritative spec: [correction-format.md](references/correction-format.md). Use that document as the source of truth for how to structure and label all corrections.

When running this skill, assume the corrections file strictly follows `references/correction-format.md` and treat any deviations as format errors to be surfaced back to the human editor.
- Item name, what to do with it (remove / compress / bundle)

## Bundling Corrections
[Items that should be combined or separated]
| Bundle | Items | Treatment |

## Depth Corrections
[Items that need more or less detail]
- Item name: expand / compress, what detail to add/remove

## Tone/Framing Corrections
[Narrative or framing changes needed]
```

## Core Workflow

### Step 1: Parse Corrections

Read the corrections file and categorize each correction:

| Type | Action |
|------|--------|
| **Theme correction** | Rewrite lead section with new theme |
| **Missing item** | Add item with source URL and appropriate detail |
| **Wrong item** | Remove, compress, or bundle as specified |
| **Bundling correction** | Combine items or split them per instructions |
| **Depth correction** | Expand or compress specific items |
| **Tone/framing** | Rewrite affected sections |

### Step 2: Apply Corrections to Newsletter

For each correction, modify the newsletter in place:

1. **Theme changes**: Replace the lead section title, framing paragraph, and reorganize lead items
2. **Additions**: Insert new items in the appropriate section, following the content-format-spec
3. **Removals**: Delete the item entirely or compress into a bundle
4. **Bundling**: Merge items into a single bullet with sub-items, or split a bundle into separate bullets
5. **Depth changes**: Expand with sub-bullets or compress to a single line
6. **Tone changes**: Rewrite the affected paragraph(s)

### Step 3: Validate Updated Newsletter

Run validation:
```bash
bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh output/YYYY-MM_month_newsletter.md
```

Check:
- [ ] All corrections applied (count corrections vs changes made)
- [ ] Validation passes (0 errors)
- [ ] Line count in expected range (100-170 lines)
- [ ] No new forbidden patterns introduced
- [ ] All new items have source URLs

### Step 4: Update Intelligence Files

If corrections reveal new editorial patterns, update:

1. **`reference/editorial-intelligence.md`**: Add new theme triggers, adjust selection weights, add expansion/compression rules
2. **`reference/source-intelligence/meta-analysis.md`**: Note new source gaps or patterns
3. **Selection criteria**: If the correction shows a weight was miscalibrated

Only update when the correction reveals a PATTERN, not a one-off preference.

### Step 5: Capture Learnings

Append to `LEARNINGS.md`:
- One learning per correction type that reveals a generalizable pattern
- Include: ID, Lesson, Evidence (the specific correction), Fix (what to change in the system)

### Step 6: Score V1 vs V2

If a scoring rubric exists for this month (`tools/score-v2-rubric.sh`), run it on the updated newsletter and compare to the pre-correction score.

Report:
- V1 score (pre-correction)
- V2 score (post-correction)
- Dimensions that improved
- Rework cycles used

## Reference

- [Correction Format](references/correction-format.md) - Standard correction file format and examples
- [Editorial Intelligence](../../../reference/editorial-intelligence.md) - Theme detection, selection weights, treatment patterns
- [Source Intelligence](../../../reference/source-intelligence/meta-analysis.md) - Cross-cycle findings

## Done When

- [ ] All corrections from the corrections file have been applied
- [ ] Updated newsletter passes validate_newsletter.sh
- [ ] Intelligence files updated (if patterns detected)
- [ ] Learnings captured in LEARNINGS.md
- [ ] V1 vs V2 comparison reported

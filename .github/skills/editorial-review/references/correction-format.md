# Correction Format Specification

> Standard format for human editorial corrections. Written by the human after reviewing a Phase 4 newsletter.

## File Location

`workspace/YYYY-MM_editorial_corrections.md`

## Required Sections

### Header
```markdown
# [Month Year] Editorial Corrections

> Captured YYYY-MM-DD. These corrections feed back into editorial-intelligence.md and selection-criteria.md.
```

### Theme Correction (optional)
When the lead theme is wrong or missing:
```markdown
## Theme Correction: Lead Should Be "[Correct Theme]"
Human's preferred lead theme: **[Theme Name]**
- [Item 1 that belongs in lead]
- [Item 2 that belongs in lead]
- [Item 3 that belongs in lead]

The connecting narrative: [1-2 sentences explaining the theme]
```

### Missing Items (optional)
Items the pipeline missed entirely:
```markdown
## Critical Miss: [Item Name]
- **URL**: [source URL]
- **Why missed**: [explanation of why the pipeline didn't find it]
- **Fix needed**: [what to change in the pipeline to prevent future misses]
- **Severity**: Critical / Important / Nice-to-have
```

### Item-Level Corrections (optional)
Per-item rating overrides:
```markdown
## Specific Item Corrections

| Item | V1 Rating | Corrected Rating | Learning |
|------|-----------|-----------------|----------|
| [Item Name] | [Include/Borderline/Exclude, Expand/Standard/Compress, Lead/Body/Back] | [Corrected ratings] | [What this teaches] |
```

### Bundling Corrections (optional)
Items that should be combined or separated:
```markdown
## Bundling Corrections

| Bundle | Items Combined | Treatment |
|--------|---------------|-----------|
| [Bundle Name] | [Item 1, Item 2, Item 3] | [Expand/Standard/Compress. Section location.] |
```

### Process Fixes (optional)
Changes needed to skills, sources, or pipeline:
```markdown
## Process Fixes Required

1. **[skill name]**: [What to change and why]
2. **[reference file]**: [What to update]
```

## Example

See `workspace/archived/2026-02_editorial_corrections.md` for a complete example from the February 2026 cycle.

## Integration Points

When the agent reads this file as Phase 5 input:
1. Each section maps to a correction type in the editorial-review skill
2. Theme Correction -> rewrite lead section
3. Critical Miss -> add item with URL
4. Item Corrections -> adjust ratings/treatment
5. Bundling Corrections -> merge or split bullets
6. Process Fixes -> update skills/references (not the newsletter itself)

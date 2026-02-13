---
name: scope-contract
description: "Generates a scope manifest at pipeline start and validates against it at pipeline end. The scope contract declares expected versions, sources, date boundaries, and categories -- then post-generation testing verifies all expectations were met. Use at the beginning and end of each newsletter pipeline run. Keywords: scope contract, QA, validation, date range, version scope, pre-generation, post-generation."
metadata:
  category: domain
  phase: "0/post"
---

# Scope Contract

Generate a testable scope manifest before the pipeline runs, then validate the newsletter output against it after assembly.

## Quick Start

### Pre-Pipeline (Phase 0)
1. Read DATE_RANGE and `kb/SOURCES.yaml`
2. Check `archive/` for previous newsletter end date (verify no gaps)
3. Generate scope manifest: expected versions, sources, categories
4. Write to `workspace/newsletter_scope_contract_YYYY-MM-DD.json`

### Post-Pipeline (after Phase 4.5)
1. Read scope manifest
2. Read final newsletter
3. Run validation checks
4. Write test results to `workspace/newsletter_scope_results_YYYY-MM-DD.md`

## Scope Manifest Format

```json
{
  "date_range": {
    "start": "YYYY-MM-DD",
    "end": "YYYY-MM-DD",
    "previous_newsletter_end": "YYYY-MM-DD",
    "gap_days": 0
  },
  "expected_versions": {
    "vscode": ["v1.108", "v1.109"],
    "visual_studio": ["18.2.x"],
    "jetbrains": ["1.5.60", "1.5.61", "1.5.62", "1.5.63", "1.5.64"],
    "xcode": ["0.46.0", "0.47.0"],
    "copilot_cli": ["v0.0.400+"]
  },
  "expected_sources": [
    "github.blog/changelog/YYYY/MM/",
    "github.blog/news-insights/company-news/",
    "code.visualstudio.com/updates/v1_NNN",
    "plugins.jetbrains.com/api/plugins/17718/updates",
    "github.com/github/CopilotForXcode/releases",
    "devblogs.microsoft.com/visualstudio/",
    "resources.github.com/events/"
  ],
  "expected_categories": [
    "Security & Compliance",
    "AI & Automation",
    "Platform & DevEx",
    "Enterprise Administration",
    "Code Quality",
    "IDE Updates"
  ],
  "expected_event_date_range": {
    "earliest": "YYYY-MM-DD",
    "latest": "YYYY-MM-DD"
  }
}
```

## Pre-Pipeline Workflow

### Step 1: Determine Date Range Boundaries

1. Read the requested DATE_RANGE (start, end)
2. Find the previous newsletter in `archive/` by examining filenames
3. Determine the previous newsletter's coverage end date (from its content or filename)
4. Calculate gap: if `start - previous_end > 1 day`, flag the gap and recommend extending start date
5. Record in manifest

### Step 2: Determine Expected Versions

For each IDE source in `kb/SOURCES.yaml`:
1. Read `latest_known.version` and `latest_known.release_date`
2. Determine which versions fall within DATE_RANGE
3. **For VS Code: MUST fetch `code.visualstudio.com/updates` index page** and parse every version's actual release date. VS Code ships weekly releases (L66), so a 30-day range typically includes 4-5 versions; a 60-day range includes 8-10. List ALL versions whose actual release date falls within DATE_RANGE. Do NOT rely on SOURCES.yaml `latest_known` alone -- it only has the newest version.
4. For JetBrains: check API for releases within DATE_RANGE (`cdate` field)
5. For Xcode: check releases page for versions within DATE_RANGE
6. Record all expected versions in manifest

**GATE**: The vscode list MUST contain >=4 entries for any DATE_RANGE spanning 30+ days (weekly cadence), or explicitly document why fewer exist (e.g., holiday weeks). If only 1-2 versions are listed, re-check the updates index page.

### Step 3: Enumerate Expected Sources

List every URL that MUST be checked based on SOURCES.yaml and the date range:
- GitHub Changelog monthly archives for each month in range
- GitHub Blog news-insights page
- VS Code release notes for each expected version
- Visual Studio release notes / devblogs
- JetBrains plugin API
- Xcode releases
- Events pages

### Step 4: List Expected Categories

All standard newsletter categories. Mark any that had zero items in the previous newsletter (higher scrutiny).

### Step 5: Write Manifest

Write the JSON manifest to `workspace/newsletter_scope_contract_YYYY-MM-DD.json`.

## Post-Pipeline Validation

### Check 1: Date Range Coverage
- [ ] All items in the newsletter are within DATE_RANGE
- [ ] No items from versions prior to the expected range
- [ ] No date gap with previous newsletter (or gap was explicitly closed)

### Check 2: Version Coverage
- [ ] Every expected VS Code version is mentioned
- [ ] Every expected JetBrains version range is covered
- [ ] Expected Xcode versions are mentioned
- [ ] Visual Studio update is mentioned
- [ ] CLI updates are mentioned

### Check 3: Source Coverage
- [ ] GitHub Changelog items present
- [ ] GitHub Blog/news-insights items present (if any existed in date range)
- [ ] VS Code release notes deep-read content present
- [ ] JetBrains granular version content present
- [ ] Xcode content present
- [ ] Events from events page present

### Check 4: Category Coverage
- [ ] Each expected category has at least 1 item OR is explicitly noted as "no updates in scope"
- [ ] No category silently omitted

### Check 5: Event Date Range
- [ ] All events are within a reasonable future window (not past events, not >6 months out)
- [ ] Events sorted chronologically

### Check 6: Structural Integrity
- [ ] Run validate_newsletter.sh -> 0 errors
- [ ] Line count in expected range
- [ ] All links resolve to expected domains

## Output

### Pre-Pipeline
- `workspace/newsletter_scope_contract_YYYY-MM-DD.json`

### Post-Pipeline
- `workspace/newsletter_scope_results_YYYY-MM-DD.md` with:
  - Pass/Fail per check
  - Missing items list
  - Out-of-scope items list
  - Recommended fixes

## Done When

**Pre-Pipeline:**
- [ ] Scope manifest exists with all fields populated
- [ ] Date range gap flagged if present
- [ ] Expected versions listed for all 5 IDE sources

**Post-Pipeline:**
- [ ] All 6 checks evaluated
- [ ] Results file written
- [ ] Any failures documented with specific fix recommendations

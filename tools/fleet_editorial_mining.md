# Fleet: Editorial Intelligence Mining (Parallel)

You are orchestrating parallel editorial intelligence extraction across the newsletter benchmark data. Each sub-agent analyzes a different aspect of the editorial history to produce findings that feed into improved content selection skills.

## Critical Rules

1. **Trust disk, not self-reports.** After all agents complete, verify every output file exists with `wc -l`.
2. **Partition files strictly.** Each agent writes ONLY to its assigned output path.
3. **Evidence-grounded findings.** Every finding must cite specific files, lines, or text. No speculation without evidence.
4. **Stop rules:** Each agent produces max 200 lines of output. Focus on highest-signal findings.

## Dispatch Plan

Dispatch 6 parallel sub-agents using @editorial-analyst. All write to `runs/editorial-intelligence/` subdirectories.

---

### Agent 1: Theme Detection Across All Published Newsletters
**Write to:** `runs/editorial-intelligence/themes/theme-detection.md`
**Read these files:**
- All 14 newsletters in `archive/2024/*.md` and `archive/2025/*.md`
- `runs/editorial-intelligence/phase-a/analysis.md` (structural metrics)

**Task:** For each of the 14 published newsletters, identify:
1. Does it have a lead/dominant theme? If yes, what is it?
2. What items cluster together to form that theme?
3. What makes a month "theme-worthy" vs. "no lead section"?
4. Produce a **Theme Pattern Catalog**: conditions under which a lead section should be created

**Output format:**
```markdown
# Theme Detection Findings
## Per-Newsletter Theme Analysis
### [Year/Month]
- Lead theme: [theme or "none"]
- Theme items: [list of items forming the theme]
- Theme trigger: [what made this theme dominate]
## Theme Pattern Catalog
[Generalized rules for when to create lead sections]
## Hypotheses Tested
- EH-2: [result and evidence]
```

---

### Agent 2: Selection Funnel Analysis (December 2025)
**Write to:** `runs/editorial-intelligence/selection/december-selection-analysis.md`
**Read these files:**
- `benchmark/2025-12_december/intermediates/phase1b_interim_github.md` (raw input, first 200 lines)
- `benchmark/2025-12_december/intermediates/phase1b_interim_vscode.md`
- `benchmark/2025-12_december/intermediates/phase1a_discoveries_v4.md` (consolidated)
- `benchmark/2025-12_december/intermediates/phase3_curated_sections.md` (curated)
- `benchmark/2025-12_december/final/december_2025_newsletter_published.md` (published)

**Task:** Trace the selection funnel for December 2025:
1. Pick 10 items that MADE IT from raw to published. For each: why did it survive?
2. Pick 10 items from phase1b raw that were EXCLUDED. For each: why was it cut?
3. Pick 5 items that were EXPANDED (got sub-bullets or extra detail). Why?
4. Pick 5 items that were COMPRESSED (consolidated). Why?
5. Identify the **enterprise signal keywords** that predict inclusion vs. exclusion
6. Identify decisions that no simple rule could capture (requires editorial judgment)

**Output format:**
```markdown
# December 2025 Selection Funnel Analysis
## Included Items (10)
## Excluded Items (10)
## Expanded Items (5)
## Compressed Items (5)
## Enterprise Signal Keywords
## Editorial Judgment Calls (beyond rules)
## Hypotheses Tested
- EH-8: [result]
- EH-10: [result]
```

---

### Agent 3: Selection Funnel Analysis (August 2025)
**Write to:** `runs/editorial-intelligence/selection/august-selection-analysis.md`
**Read these files:**
- `benchmark/2025-08_august/intermediates/phase1a_discoveries_jul01-aug28.md`
- `benchmark/2025-08_august/intermediates/phase2_draft_sections_august_e47ead50.md` (latest draft)
- `archive/2025/August.md` (published)
- `workspace/archived/newsletter_phase1b_events_2025-08-28.md` (events)

**Task:** Same selection funnel analysis as Agent 2 but for August 2025. Compare the selection patterns to see if December's patterns generalize.

---

### Agent 4: Era Evolution and Structural Patterns
**Write to:** `runs/editorial-intelligence/evolution/era-evolution.md`
**Read these files:**
- `runs/editorial-intelligence/phase-a/analysis.md` (structural metrics)
- `runs/editorial-intelligence/phase-a/metrics.csv`
- `benchmark/_cycle_analysis.md` (first 200 lines)
- All 14 newsletters (scan headers and structure, not full content)

**Task:**
1. Identify exactly when structural breakpoints occurred (which month-to-month shows biggest jumps in lines, sections, bullets, links)
2. Quantify the pre-agentic → transition → agentic era boundaries with metrics
3. Track which features appeared when: events table, lead sections, GA/PREVIEW labels, IDE parity, Copilot at Scale, changelogs, playlists, closing section
4. Identify which structural patterns are now **stable** (appear in every recent newsletter) vs. **conditional** (appear only sometimes)
5. Detect any **regression** patterns (features that appeared then disappeared)

**Output format:**
```markdown
# Era Evolution Analysis
## Structural Breakpoints
## Era Boundaries (with evidence)
## Feature Adoption Timeline
## Stable vs. Conditional Patterns
## Regression Patterns
## Hypotheses Tested
- EH-1: [result]
- EH-3: [result]
```

---

### Agent 5: Expansion and Compression Pattern Mining
**Write to:** `runs/editorial-intelligence/patterns/expansion-compression.md`
**Read these files:**
- `archive/2025/December.md` (published, richest)
- `archive/2025/August.md` (published)
- `archive/2025/June.md` (published)
- `archive/2025/May.md` (published)
- `archive/2025/January.md` (published)
- `benchmark/2025-12_december/intermediates/phase3_curated_sections.md`

**Task:**
1. Identify EVERY bullet that has sub-bullets or takes >2 lines in the agentic-era newsletters. What makes an item "expansion-worthy"?
2. Identify EVERY instance of item consolidation (multiple things merged into one bullet). What triggers consolidation?
3. Produce a **decision tree**: Given an item's characteristics, should it be expanded, compressed, or standard (1-2 lines)?
4. Identify the **information density** sweet spot — how many items per section seems right?

**Output format:**
```markdown
# Expansion/Compression Pattern Analysis
## Expanded Items Catalog (with reasons)
## Compressed Items Catalog (with reasons)
## Decision Tree
## Information Density Patterns
## Hypotheses Tested
- EH-5: [result]
- EH-7: [result]
```

---

### Agent 6: Audience Weight Calibration
**Write to:** `runs/editorial-intelligence/weights/audience-calibration.md`
**Read these files:**
- `archive/2025/December.md`
- `archive/2025/August.md`
- `archive/2025/June.md`
- `archive/2025/April.md`
- `archive/2025/January.md`
- `benchmark/2025-12_december/intermediates/phase1a_discoveries_v4.md` (raw pool)
- `.github/skills/content-curation/references/selection-criteria.md` (current rules)

**Task:**
1. Tag every bullet in the 5 published newsletters with ONE primary category: Governance, Security, Admin, Productivity, IDE-Parity, Platform, Other
2. Calculate the actual category distribution across all 5 newsletters (what % of published bullets are each category?)
3. Compare actual distribution against the current equal-weight selection criteria
4. Propose an **audience-weighted scoring model** with specific multipliers derived from the data
5. Identify items that the human consistently includes that a generic enterprise filter would miss (blind spots in current rules)
6. Identify what questions you would ask the human curator to resolve ambiguous selection decisions

**Output format:**
```markdown
# Audience Weight Calibration
## Category Distribution (actual from 5 newsletters)
## Current Rules vs. Actual (gap analysis)
## Proposed Weighted Scoring Model
## Blind Spots (items human includes that rules miss)
## Questions for Human Curator
## Hypotheses Tested
- EH-4: [result]
- EH-9: [partial — proposed model, not yet tested]
```

---

## Post-Fleet Verification

After all 6 agents complete, run:
```bash
for f in runs/editorial-intelligence/themes/theme-detection.md \
         runs/editorial-intelligence/selection/december-selection-analysis.md \
         runs/editorial-intelligence/selection/august-selection-analysis.md \
         runs/editorial-intelligence/evolution/era-evolution.md \
         runs/editorial-intelligence/patterns/expansion-compression.md \
         runs/editorial-intelligence/weights/audience-calibration.md; do
  if [ -f "$f" ]; then
    echo "OK: $f ($(wc -l < "$f" | tr -d ' ') lines)"
  else
    echo "MISSING: $f"
  fi
done
```

## Synthesis (after verification)

After all 6 reports exist, create a synthesis that:
1. Resolves hypotheses EH-1 through EH-10
2. Produces `reference/editorial-intelligence.md` — the accumulated editorial knowledge
3. Updates `.github/skills/content-curation/references/selection-criteria.md` with calibrated weights
4. Creates `reference/editorial-questions.md` — questions for the human curator to answer
5. Updates HYPOTHESES.md and LEARNINGS.md

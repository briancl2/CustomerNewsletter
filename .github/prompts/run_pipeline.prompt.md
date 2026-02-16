---
mode: agent
description: "Run the full newsletter pipeline from URL discovery through final assembly, validation, and editorial review. Orchestrates all 6 phases with phase gates."
---

# Newsletter Pipeline: Full Run

Generate a monthly customer newsletter by executing the skills-based pipeline end to end.

## Non-Negotiable Rules

1. Do not compress or skip phases. Run every phase in order. Phase 1.5 is conditional, but mandatory when notes exist.
2. Use only canonical filenames defined in this prompt and skill docs.
3. Do not write shortcut files like `fresh_phase*` for production runs.
4. Do not reuse prior cycle artifacts for a "from-scratch" run. If the user asks for from-scratch, run:
   - `bash tools/prepare_newsletter_cycle.sh {{startDate}} {{endDate}} --no-reuse`
5. Before declaring completion, run strict contract validation:
   - `bash tools/validate_pipeline_strict.sh {{startDate}} {{endDate}}`
   - For from-scratch runs: `bash tools/validate_pipeline_strict.sh {{startDate}} {{endDate}} --require-fresh`
   - For benchmark-consistency runs: `bash tools/validate_pipeline_strict.sh {{startDate}} {{endDate}} --require-fresh --benchmark-mode feb2026_consistency`
6. If strict validation fails, stop and fix before reporting completion.
7. After writing each canonical artifact, immediately record a phase receipt with:
   - `bash tools/record_phase_receipt.sh {{startDate}} {{endDate}} <phase_id> <artifact_path>`
8. Do not batch receipt writes at the end; receipts must be recorded phase-by-phase during execution.
9. Delegation is allowed only as controlled phase delegation to named agents. Do not delegate to generic or "general-purpose" subagents.
10. Delegate one phase at a time with explicit stop conditions and canonical artifact + receipt checks.
11. Never delete `workspace/newsletter_phase_receipts_{{endDate}}.json` during an active run.
12. Curator note discovery must include both patterns:
   - `workspace/curator_notes_*.md`
   - `workspace/[A-Za-z]*.md` (for example `workspace/Jan.md`), excluding generated files like `curator_notes_processed_*` and `curator_notes_editorial_signals_*`.
13. For the February 2026 benchmark window (`2025-12-05` to `2026-02-13`), benchmark mode is mandatory before completion:
   - `bash tools/validate_pipeline_strict.sh {{startDate}} {{endDate}} --require-fresh --benchmark-mode feb2026_consistency`
14. If benchmark mode fails, keep iterating until it passes.
15. Phase 2 must emit both artifacts in this order:
   - `workspace/newsletter_phase2_event_sources_{{endDate}}.json`
   - `workspace/newsletter_phase2_events_{{endDate}}.md`

## Required Inputs

Before starting, you need:
- **DATE_RANGE**: `{{startDate}}` to `{{endDate}}`
- **Deterministic event-source extraction** via `python3 tools/extract_event_sources.py {{startDate}} {{endDate}}`

## Execution Plan

Execute each phase in order. After each phase, verify the output file exists and has content before proceeding.

### Phase 0: Feed-Forward Learnings and Scope Contract

1. Read `LEARNINGS.md` for feed-forward lessons from previous runs
2. Note any lessons relevant to the current date range and content cycle
3. Apply relevant lessons throughout the pipeline (e.g., source gaps, bundling rules, deep-read requirements)
4. Read `.github/skills/scope-contract/SKILL.md` and generate the pre-pipeline scope manifest
5. Output: `workspace/newsletter_scope_contract_{{endDate}}.json`
6. **Gate**: Scope manifest exists, date range gap flagged if any, expected versions listed
7. Record receipt:
   - `bash tools/record_phase_receipt.sh {{startDate}} {{endDate}} phase0_scope_contract workspace/newsletter_scope_contract_{{endDate}}.json`

### Phase 1A: URL Manifest

1. Read `.github/skills/url-manifest/SKILL.md`
2. Input: DATE_RANGE and `kb/SOURCES.yaml`
3. Output: `workspace/newsletter_phase1a_url_manifest_{{startDate}}_to_{{endDate}}.md`
4. **Gate**: File exists and has > 20 lines
5. Record receipt:
   - `bash tools/record_phase_receipt.sh {{startDate}} {{endDate}} phase1a_manifest workspace/newsletter_phase1a_url_manifest_{{startDate}}_to_{{endDate}}.md`
6. Use `phase1a_manifest` exactly. Do not abbreviate (for example `phase1a` is invalid).

### Phase 1B: Content Retrieval

1. Read `.github/skills/content-retrieval/SKILL.md`
2. Input: URL manifest from Phase 1A
3. Output: 5 interim files in `workspace/` (one per source)
4. **Gate**: All 5 expected interim files exist in `workspace/` (one per configured source; see `.github/skills/content-retrieval/SKILL.md` for expected filenames/patterns) and each has content
5. Record receipts:
   - `bash tools/record_phase_receipt.sh {{startDate}} {{endDate}} phase1b_github workspace/newsletter_phase1b_interim_github_{{startDate}}_to_{{endDate}}.md`
   - `bash tools/record_phase_receipt.sh {{startDate}} {{endDate}} phase1b_vscode workspace/newsletter_phase1b_interim_vscode_{{startDate}}_to_{{endDate}}.md`
   - `bash tools/record_phase_receipt.sh {{startDate}} {{endDate}} phase1b_visualstudio workspace/newsletter_phase1b_interim_visualstudio_{{startDate}}_to_{{endDate}}.md`
   - `bash tools/record_phase_receipt.sh {{startDate}} {{endDate}} phase1b_jetbrains workspace/newsletter_phase1b_interim_jetbrains_{{startDate}}_to_{{endDate}}.md`
   - `bash tools/record_phase_receipt.sh {{startDate}} {{endDate}} phase1b_xcode workspace/newsletter_phase1b_interim_xcode_{{startDate}}_to_{{endDate}}.md`
6. Use the five canonical `phase1b_*` IDs exactly as listed.

### Phase 1C: Content Consolidation

1. Read `.github/skills/content-consolidation/SKILL.md`
2. Input: Interim files from Phase 1B
3. Output: `workspace/newsletter_phase1a_discoveries_{{startDate}}_to_{{endDate}}.md`
4. **Gate**: File exists and has 30-50 items
5. **Gate**: Expected VS Code versions from scope contract are represented in discoveries (version text or `v1_xxx` URL evidence)
6. Record receipt:
   - `bash tools/record_phase_receipt.sh {{startDate}} {{endDate}} phase1c_discoveries workspace/newsletter_phase1a_discoveries_{{startDate}}_to_{{endDate}}.md`

### Phase 2: Events Extraction (can run after 1A)

1. Read `.github/skills/events-extraction/SKILL.md`
2. Run deterministic source extraction:
   - `python3 tools/extract_event_sources.py {{startDate}} {{endDate}}`
3. Output (sources): `workspace/newsletter_phase2_event_sources_{{endDate}}.json`
4. Record receipt:
   - `bash tools/record_phase_receipt.sh {{startDate}} {{endDate}} phase2_event_sources workspace/newsletter_phase2_event_sources_{{endDate}}.json`
5. Use `candidate_urls` from the JSON artifact as primary Phase 2 input set.
6. Output (events): `workspace/newsletter_phase2_events_{{endDate}}.md`
7. **Gate**: File exists with virtual and in-person coverage where available
8. **Gate**: Event count floor by range length:
   - >=60 day range: at least 12 events
   - >=30 day range: at least 8 events
   - <30 day range: at least 4 events
9. **Gate**: Event row links are deep links (no generic landing/search URLs).
10. Record receipt:
   - `bash tools/record_phase_receipt.sh {{startDate}} {{endDate}} phase2_events workspace/newsletter_phase2_events_{{endDate}}.md`

### Phase 1.5: Curator Notes Processing (conditional mandatory, after 1C)

1. Read `.github/skills/curator-notes/SKILL.md`
2. Check for notes using both glob classes:
   - `workspace/curator_notes_*.md`
   - `workspace/[A-Za-z]*.md` (for example `workspace/Jan.md`, `workspace/February.md`)
   - Exclude generated files: `workspace/curator_notes_processed_*.md`, `workspace/curator_notes_editorial_signals_*.md`, and all `workspace/newsletter_*.md`
3. If no file exists: SKIP entirely, continue to Phase 3
4. If file exists: Parse, classify, visit URLs, cross-reference with Phase 1C discoveries
5. Output: `workspace/curator_notes_processed_YYYY-MM.md` + `workspace/curator_notes_editorial_signals_YYYY-MM.md`
6. **Gate**: If notes file existed, both output files exist and are freshly generated for this cycle.
7. **Gate**: If processed notes include extractable URLs, at least one is reflected in curated sections or final output.
8. Record receipts:
   - `bash tools/record_phase_receipt.sh {{startDate}} {{endDate}} phase1_5_curator_processed workspace/curator_notes_processed_YYYY-MM.md`
   - `bash tools/record_phase_receipt.sh {{startDate}} {{endDate}} phase1_5_curator_signals workspace/curator_notes_editorial_signals_YYYY-MM.md`

### Phase 3: Content Curation

1. Read `.github/skills/content-curation/SKILL.md`
2. Read `reference/editorial-intelligence.md` for selection weights and theme detection
3. Read `reference/source-intelligence/meta-analysis.md` for pipeline patterns
4. Input: Discoveries from Phase 1C + Curator notes processed items from Phase 1.5 (required if notes were present)
5. Output: `workspace/newsletter_phase3_curated_sections_{{endDate}}.md`
6. **Gate**: File exists with section-complete structure
7. **Gate**: Item count floor by range length:
   - >=60 day range: at least 24 curated bullets before final assembly
   - >=30 day range: at least 18 curated bullets before final assembly
   - <30 day range: at least 12 curated bullets before final assembly
8. **Gate**: Include curation material for:
   - Copilot releases
   - Enterprise and security updates
   - Platform updates
   - Resources and best practices
   - Event framing references only (virtual + in-person + behind-the-scenes). Actual event extraction stays in Phase 2.
9. Record receipt:
   - `bash tools/record_phase_receipt.sh {{startDate}} {{endDate}} phase3_curated workspace/newsletter_phase3_curated_sections_{{endDate}}.md`

### Phase 4: Newsletter Assembly

1. Read `.github/skills/newsletter-assembly/SKILL.md`
2. Input: Curated sections from Phase 3 + Events from Phase 2
3. Output: `output/YYYY-MM_month_newsletter.md`
4. **Gate**: File exists with complete section coverage and density
5. **Gate**: For >=60 day range, output should target:
   - >=3000 words
   - >=110 markdown links
   - major section headings as H1: `# Copilot Everywhere...`, `# Copilot`, `# Enterprise and Security Updates`, `# Resources and Best Practices`, `# Webinars, Events, and Recordings`
   - note: `# Copilot Everywhere...` is the monthly lead framing; `# Copilot` is the dedicated release section
   - Copilot subsection heading: `## Latest Releases`
   - events subheadings as H2: `## Virtual Events`, `## In-Person Events`, `## Behind the scenes`
6. Record receipt:
   - `bash tools/record_phase_receipt.sh {{startDate}} {{endDate}} phase4_output output/YYYY-MM_month_newsletter.md`

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
6. Record receipt:
   - `bash tools/record_phase_receipt.sh {{startDate}} {{endDate}} phase4_scope_results workspace/newsletter_scope_results_{{endDate}}.md`

### Post-Assembly: Editorial Review Artifact

1. Produce `workspace/YYYY-MM_editorial_review.md` with per-item ratings
2. Format: table with columns (Item, Include/Borderline/Exclude, Expand/Standard/Compress, Lead/Body/Back, Rationale)
3. This artifact enables the human to provide corrections

### Final Gate: Strict Pipeline Contract

1. Run strict contract validator:
   - `bash tools/validate_pipeline_strict.sh {{startDate}} {{endDate}}`
2. For from-scratch requests, require fresh marker enforcement:
   - `bash tools/validate_pipeline_strict.sh {{startDate}} {{endDate}} --require-fresh`
3. For benchmark consistency runs, enforce benchmark mode:
   - `bash tools/validate_pipeline_strict.sh {{startDate}} {{endDate}} --require-fresh --benchmark-mode feb2026_consistency`
4. For `2025-12-05` to `2026-02-13`, benchmark mode is mandatory (not optional).
5. Do not report success if this gate fails.

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

---
name: "customer_newsletter"
description: "Generates monthly customer newsletters via a skills-based pipeline. Orchestrates 6 phases from URL discovery through final assembly and validation."
model: "claude-opus-4.6"
tools: ['execute/getTerminalOutput', 'execute/runTask', 'execute/getTaskOutput', 'execute/createAndRunTask', 'execute/runInTerminal', 'read/terminalSelection', 'read/terminalLastCommand', 'read/readFile', 'edit/createDirectory', 'edit/createFile', 'edit/editFiles', 'search/changes', 'search/codebase', 'search/fileSearch', 'search/listDirectory', 'search/searchResults', 'search/textSearch', 'web/fetch', 'agent', 'todo']
infer: true
---

<mission>
Generate monthly customer newsletters by orchestrating a skills-based pipeline. Each phase delegates to a dedicated skill. Domain logic lives in skills, not here.
</mission>

## Non-Negotiable Execution Rules

1. Do not compress phases. Phase 1A -> 1B -> 1C -> 2 -> 3 -> 4 -> 4.5 must be materially executed.
2. Phase 1.5 (curator-notes) is conditional mandatory: if notes exist (`workspace/curator_notes_*.md` or `workspace/<Month>.md`), execute it before Phase 3.
3. Canonical artifact paths are mandatory. Do not create or rely on `fresh_phase*` shortcuts.
4. Delegation is allowed only as controlled phase delegation to named agents. Never delegate to generic or "general-purpose" subagents.
5. Use one delegation unit per phase. Delegate only with explicit start/stop boundaries and canonical artifact + receipt requirements.
6. Preferred delegation map:
   - `customer_newsletter`: Phase 0, 1A, 1B, 2, 4, 4.5
   - `editorial-analyst`: Phase 1C, 1.5, 3
   - `skill-builder`: skill-authoring tasks only (not newsletter generation phases)
7. Do not delete `workspace/newsletter_phase_receipts_<END>.json` during an active run.
8. If the user asks for from-scratch generation, run:
   - `bash tools/prepare_newsletter_cycle.sh <START> <END> --no-reuse`
9. Before reporting completion, run strict validation:
   - `bash tools/validate_pipeline_strict.sh <START> <END>`
   - From-scratch: `bash tools/validate_pipeline_strict.sh <START> <END> --require-fresh`
   - Benchmark consistency: `bash tools/validate_pipeline_strict.sh <START> <END> --require-fresh --benchmark-mode feb2026_consistency`
10. If strict validation fails, continue fixing until it passes or explicitly report the blocker.
11. Record phase receipts immediately after each artifact write:
   - `bash tools/record_phase_receipt.sh <START> <END> <phase_id> <artifact_path>`
12. Do not defer receipts until the end of the run.
13. Use canonical `phase_id` values only:
   - `phase0_scope_contract`
   - `phase1a_manifest`
   - `phase1b_github`
   - `phase1b_vscode`
   - `phase1b_visualstudio`
   - `phase1b_jetbrains`
   - `phase1b_xcode`
   - `phase1c_discoveries`
   - `phase1_5_curator_processed`
   - `phase1_5_curator_signals`
   - `phase2_event_sources`
   - `phase2_events`
   - `phase3_curated`
   - `phase4_output`
   - `phase4_scope_results`
14. Curator-note discovery must include both:
   - `workspace/curator_notes_*.md`
   - `workspace/[A-Za-z]*.md` (for example `workspace/Jan.md`)
   Exclude generated files: `curator_notes_processed_*`, `curator_notes_editorial_signals_*`, and `newsletter_*`.
15. For the February 2026 benchmark window (`2025-12-05` to `2026-02-13`), benchmark mode is mandatory before completion:
   - `bash tools/validate_pipeline_strict.sh <START> <END> --require-fresh --benchmark-mode feb2026_consistency`
16. If benchmark mode fails, keep iterating until it passes.
17. In Phase 2, generate `workspace/newsletter_phase2_event_sources_<END>.json` before `workspace/newsletter_phase2_events_<END>.md`, and record both receipts (`phase2_event_sources`, `phase2_events`).

## Audience

**Primary**: Engineering Managers, DevOps Leads, IT Leadership in large regulated enterprises (Healthcare, Manufacturing, Financial Services).
**Secondary**: Developers. Content appeals to both, but distribution is primarily leadership and platform engineering roles.

## Pipeline

| Phase | Skill | Input | Output |
|-------|-------|-------|--------|
| 1A | [url-manifest](.github/skills/url-manifest/SKILL.md) | DATE_RANGE, kb/SOURCES.yaml | `workspace/newsletter_phase1a_url_manifest_*.md` |
| 1B | [content-retrieval](.github/skills/content-retrieval/SKILL.md) | URL manifest | 5 interim files in `workspace/` |
| 1C | [content-consolidation](.github/skills/content-consolidation/SKILL.md) | 5 interim files | `workspace/newsletter_phase1a_discoveries_*.md` |
| 1.5 | [curator-notes](.github/skills/curator-notes/SKILL.md) | Curator notes file + discoveries | `workspace/curator_notes_processed_YYYY-MM.md`, `workspace/curator_notes_editorial_signals_YYYY-MM.md` |
| 2 | [events-extraction](.github/skills/events-extraction/SKILL.md) | `kb/EVENT_SOURCES.yaml` + optional curator notes | `workspace/newsletter_phase2_event_sources_*.json`, `workspace/newsletter_phase2_events_*.md` |
| 3 | [content-curation](.github/skills/content-curation/SKILL.md) | Discoveries | `workspace/newsletter_phase3_curated_sections_*.md` |
| 4 | [newsletter-assembly](.github/skills/newsletter-assembly/SKILL.md) | Curated + Events | `output/YYYY-MM_month_newsletter.md` |
| Post | [newsletter-validation](.github/skills/newsletter-validation/SKILL.md) | Newsletter file | Pass/fail report |
| 4.5 | [newsletter-polishing](.github/skills/newsletter-polishing/SKILL.md) | Newsletter file | Polished newsletter |
| 5 | [editorial-review](.github/skills/editorial-review/SKILL.md) | Corrections + Newsletter | Updated newsletter |
| Utility | [kb-maintenance](.github/skills/kb-maintenance/SKILL.md) | kb/SOURCES.yaml | Delta + health reports |

**Execution order**: 1A, 1B, 1C run sequentially. Phase 2 can run in parallel. If notes file exists, run 1.5 before Phase 3. Phase 4 depends on 3 and 2.

## Category Taxonomy

All items are classified into exactly one category:

- **Security & Compliance**: Secret protection, code scanning, Dependabot, supply chain, audit logs
- **AI & Automation**: Copilot (all IDEs), Extensions, AI-powered features, Actions AI
- **Platform & DevEx**: Repos, PRs, Issues, Projects, Actions, Packages, Codespaces
- **Enterprise Administration**: EMU, SCIM, policies, billing, license management, GHEC/GHES

## Key Formatting Rules

- Bold product names, feature names, dates
- All links as `[Descriptive Text](URL)`, never raw URLs, never `[[Text]](URL)`
- No em dashes; use commas, parentheses, or rephrase
- GA/PREVIEW labels in uppercase; omit when ambiguous
- Never mention Copilot Free/Individual/Pro/Pro+ plans
- Use `reference/github_common_jargon.md` for standard terminology

## Standard Templates

**Introduction**:
"This is a personally curated newsletter for my customers, focused on the most relevant updates and resources from GitHub this month. Highlights for this month include [2-3 highlights]. If you have any feedback or want to dive deeper into any topic, please let me know. Feel free to share this newsletter with others on your team as well. You can find an archive of past newsletters [here](https://github.com/briancl2/CustomerNewsletter)."

**Closing**:
"If you have any questions or want to discuss these updates in detail, feel free to reach out. As always, I'm here to help you and your team stay informed and get the most value from GitHub."

## Prompt Files

| Phase | Prompt |
|-------|--------|
| 1A | `.github/prompts/phase_1a_url_manifest.prompt.md` |
| 1B | `.github/prompts/phase_1b_content_retrieval.prompt.md` |
| 1C | `.github/prompts/phase_1c_consolidation.prompt.md` |
| 2 | `.github/prompts/phase_2_events_extraction.prompt.md` |
| 3 | `.github/prompts/phase_3_content_curation.prompt.md` |
| 4 | `.github/prompts/phase_4_final_assembly.prompt.md` |

## Workflow

0. Read `LEARNINGS.md`. Note lessons relevant to the current cycle.
1. Read the skill for the current phase
2. Read the relevant source intelligence files in `reference/source-intelligence/` for per-source extraction guidance
3. Read `reference/editorial-intelligence.md` for theme detection, selection weights, and treatment patterns
4. Follow the skill's workflow
5. Verify output exists on disk before proceeding to next phase
6. In Phase 2, generate deterministic event candidates first: `python3 tools/extract_event_sources.py <START> <END>`, then record `phase2_event_sources`.
7. Record a phase receipt for each canonical phase artifact using `tools/record_phase_receipt.sh`
8. After Phase 4, run newsletter-validation to confirm quality
9. Produce an editorial review artifact at `workspace/YYYY-MM_editorial_review.md` with per-item ratings (Include/Borderline/Exclude, Expand/Standard/Compress, Lead/Body/Back) for human calibration
10. Run `tools/validate_pipeline_strict.sh` before completion

## Done When

- Newsletter written to `output/YYYY-MM_month_newsletter.md`
- All mandatory sections present (Introduction, Copilot, Events, Closing)
- `validate_newsletter.sh` passes
- Enterprise focus maintained throughout

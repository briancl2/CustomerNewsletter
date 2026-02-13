---
name: "customer_newsletter"
description: "Generates monthly customer newsletters via a skills-based pipeline. Orchestrates 6 phases from URL discovery through final assembly and validation."
tools: ['execute/getTerminalOutput', 'execute/runTask', 'execute/getTaskOutput', 'execute/createAndRunTask', 'execute/runInTerminal', 'read/terminalSelection', 'read/terminalLastCommand', 'read/readFile', 'edit/createDirectory', 'edit/createFile', 'edit/editFiles', 'search/changes', 'search/codebase', 'search/fileSearch', 'search/listDirectory', 'search/searchResults', 'search/textSearch', 'web/fetch', 'agent', 'todo']
infer: true
---

<mission>
Generate monthly customer newsletters by orchestrating a skills-based pipeline. Each phase delegates to a dedicated skill. Domain logic lives in skills, not here.
</mission>

## Configuration Source of Truth

Read `config/profile.yaml` before running any generation phase.

Use it for:
- Curator voice and name
- Audience targeting
- Timezone defaults
- Archive URL
- YouTube playlist links
- Optional personal corner settings

## Audience

**Primary**: Engineering Managers, DevOps Leads, IT Leadership in large regulated enterprises (default: Healthcare, Manufacturing, Financial Services, configurable in `config/profile.yaml`).
**Secondary**: Developers. Content appeals to both, but distribution is primarily leadership and platform engineering roles.

## Pipeline

| Phase | Skill | Input | Output |
|-------|-------|-------|--------|
| 1A | [url-manifest](.github/skills/url-manifest/SKILL.md) | DATE_RANGE, kb/SOURCES.yaml | `workspace/newsletter_phase1a_url_manifest_*.md` |
| 1B | [content-retrieval](.github/skills/content-retrieval/SKILL.md) | URL manifest | 5 interim files in `workspace/` |
| 1C | [content-consolidation](.github/skills/content-consolidation/SKILL.md) | 5 interim files | `workspace/newsletter_phase1a_discoveries_*.md` |
| 2 | [events-extraction](.github/skills/events-extraction/SKILL.md) | Event URLs | `workspace/newsletter_phase2_events_*.md` |
| 3 | [content-curation](.github/skills/content-curation/SKILL.md) | Discoveries | `workspace/newsletter_phase3_curated_sections_*.md` |
| 4 | [newsletter-assembly](.github/skills/newsletter-assembly/SKILL.md) | Curated + Events | `output/YYYY-MM_month_newsletter.md` |
| Post | [newsletter-validation](.github/skills/newsletter-validation/SKILL.md) | Newsletter file | Pass/fail report |
| 4.5 | [newsletter-polishing](.github/skills/newsletter-polishing/SKILL.md) | Newsletter file | Polished newsletter |
| 5 | [editorial-review](.github/skills/editorial-review/SKILL.md) | Corrections + Newsletter | Updated newsletter |
| Utility | [kb-maintenance](.github/skills/kb-maintenance/SKILL.md) | kb/SOURCES.yaml | Delta + health reports |

**Execution order**: 1A, 1B, 1C run sequentially. Phase 2 can run in parallel. Phase 3 depends on 1C. Phase 4 depends on 3 and 2.

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
"Use the configured curator voice from `config/profile.yaml`, include 2-3 monthly highlights, and use `publishing.archive_url` for the archive link."

**Closing**:
"Use the configured curator voice from `config/profile.yaml` and close with a direct invitation for follow-up and feedback."

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

0. Read `config/profile.yaml` and apply it throughout all phases.
1. Read `LEARNINGS.md`. Note lessons relevant to the current cycle.
2. Read the skill for the current phase.
3. Read the relevant source intelligence files in `reference/source-intelligence/` for per-source extraction guidance.
4. Read `reference/editorial-intelligence.md` for theme detection, selection weights, and treatment patterns.
5. Follow the skill's workflow.
6. Verify output exists on disk before proceeding to the next phase.
7. After Phase 4, run newsletter-validation to confirm quality.
8. Produce an editorial review artifact at `workspace/YYYY-MM_editorial_review.md` with per-item ratings (Include/Borderline/Exclude, Expand/Standard/Compress, Lead/Body/Back) for human calibration.

## Done When

- Newsletter written to `output/YYYY-MM_month_newsletter.md`
- All mandatory sections present (Introduction, Copilot, Events, Closing)
- `validate_newsletter.sh` passes
- Enterprise focus maintained throughout

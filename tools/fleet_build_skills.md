# Fleet: Build All 8 Pipeline Skills in Parallel

You are orchestrating the parallel construction of 8 newsletter pipeline skills. Each skill extracts domain logic from the monolithic agent file into a standalone, testable skill package.

## Critical Rules

1. **Trust disk, not self-reports.** After all agents complete, verify every file exists with `wc -l`. Do not accept agent claims of completion without checking.
2. **Partition files strictly.** Each agent writes ONLY to its assigned `.github/skills/<name>/` directory. Zero overlap.
3. **Stop rules per agent:** SKILL.md must be 80-300 lines. Each reference file must be 20-150 lines. No agent should produce more than 500 total lines.
4. **Named agent execution.** All sub-agents use `@skill-builder`. If you need explicit model control, pass it through the CLI (`MODEL=...`) rather than hardcoding it in agent files.

## Instructions

Dispatch 8 parallel sub-agents using @skill-builder. Each builds one skill. All agents can run simultaneously since they write to distinct directories with no shared state.

After all 8 complete, verify ON DISK (not from agent claims):
```bash
make validate-all-skills
```

Then verify each skill has a SKILL.md with at least 50 lines and at least 1 reference file:
```bash
for skill in url-manifest content-retrieval content-consolidation events-extraction content-curation newsletter-assembly newsletter-validation kb-maintenance; do
  lines=$(wc -l < .github/skills/$skill/SKILL.md)
  refs=$(find .github/skills/$skill/references -type f -name '*.md' | wc -l)
  echo "$skill: SKILL.md=${lines}L, refs=${refs}"
done
```

## Skill Assignments

### 1. url-manifest (Phase 1A)
**Agent:** @skill-builder
**Write to:** `.github/skills/url-manifest/`
**Read these files:**
- `.github/skills/building-skill/SKILL.md` (the skill creation spec)
- `.github/agents/customer_newsletter.agent.md` (Phase 1A section: "Phase 1A: URL Manifest")
- `.github/prompts/phase_1a_url_manifest.prompt.md` (full prompt logic)
- `.github/skills/url-manifest/examples/` (benchmark example)
- `kb/SOURCES.yaml` (first 100 lines for structure understanding)

**Key logic to extract into SKILL.md + references:**
- URL generation patterns per source (VS Code versions, GitHub Changelog months, JetBrains API, Visual Studio release notes, Xcode changelog)
- Date boundary validation (Named Month vs Actual Release Date)
- SOURCES.yaml as canonical URL input (key innovation over hardcoded patterns)
- Token budget target (10k-20k)
- Output: `workspace/newsletter_phase1a_url_manifest_YYYY-MM-DD_to_YYYY-MM-DD.md`

**Reference files to create:**
- `references/url-patterns.md` — URL generation rules per source

---

### 2. content-retrieval (Phase 1B)
**Agent:** @skill-builder
**Write to:** `.github/skills/content-retrieval/`
**Read these files:**
- `.github/skills/building-skill/SKILL.md`
- `.github/agents/customer_newsletter.agent.md` (Phase 1B section)
- `.github/prompts/phase_1b_content_retrieval.prompt.md`
- `.github/skills/content-retrieval/examples/` (5 benchmark interim files)

**Key logic to extract:**
- 5-chunk sequential processing (GitHub → VS Code → Visual Studio → JetBrains → Xcode)
- Anchor unit = feature not version (critical for downstream dedup)
- Universal extraction format (title, date, description, links, relevance score, IDE tag, enterprise impact)
- Copilot-only filtering for VS Code and Visual Studio
- Cross-referencing rules (JetBrains vs Changelog ±3 days, VS Code vs Changelog)
- Status markers: (GA), (PREVIEW), (RETIRED/DEPRECATED)
- Output: 5 interim files in `workspace/`

**Reference files to create:**
- `references/extraction-format.md` — Universal extraction format spec with field definitions

---

### 3. content-consolidation (Phase 1C)
**Agent:** @skill-builder
**Write to:** `.github/skills/content-consolidation/`
**Read these files:**
- `.github/skills/building-skill/SKILL.md`
- `.github/agents/customer_newsletter.agent.md` (Phase 1C section)
- `.github/prompts/phase_1c_consolidation.prompt.md`
- `.github/skills/content-consolidation/examples/` (benchmark discoveries)

**Key logic to extract:**
- Merge/dedup across 5 sources (same feature → single item, earliest date, combined URLs, IDE breadth)
- 5-category taxonomy with target counts: Monthly Announcements (3-5), Copilot Latest (8-12), Copilot at Scale (4-6), Platform (5-10), Deprecations (0-3)
- Enterprise relevance scoring (1-10 scale with inclusion thresholds)
- IDE support matrix (✅/⏳/❌ per IDE)
- Cross-reference validation rules
- Target: 20-40 items
- Output: `workspace/newsletter_phase1a_discoveries_YYYY-MM-DD_to_YYYY-MM-DD.md`

**Reference files to create:**
- `references/consolidation-rules.md` — Dedup logic, scoring criteria, category taxonomy with targets

---

### 4. events-extraction (Phase 2)
**Agent:** @skill-builder
**Write to:** `.github/skills/events-extraction/`
**Read these files:**
- `.github/skills/building-skill/SKILL.md`
- `.github/agents/customer_newsletter.agent.md` (Phase 2 section + Events format section)
- `.github/prompts/phase_2_events_extraction.prompt.md`
- `.github/skills/events-extraction/examples/` (benchmark events)

**Key logic to extract:**
- Runs independently/parallel with Phases 1A-1C
- Event classification: Virtual, In-person, Hybrid
- Canonical categories (max 2, prefer 1): Copilot, GitHub Platform, Developer Experience, Enterprise
- Time normalization to Central Time (CT); virtual events date-only
- Table formats: virtual (Date/Event/Categories), in-person (bullets with location), conference sessions (Date/Time CT/Session/Description)
- VS Code → Copilot implicit mapping
- Standard content blocks: Copilot Fridays link, YouTube playlists
- Skill level only when explicitly stated
- Output: `workspace/newsletter_phase2_events_YYYY-MM-DD.md`

**Reference files to create:**
- `references/events-formatting.md` — Table specs, category mapping, timezone rules, standard content blocks

---

### 5. content-curation (Phase 3)
**Agent:** @skill-builder
**Write to:** `.github/skills/content-curation/`
**Read these files:**
- `.github/skills/building-skill/SKILL.md`
- `.github/agents/customer_newsletter.agent.md` (Phase 3 section + Content Selection Criteria + Copilot Updates section)
- `.github/prompts/phase_3_content_curation.prompt.md`
- `.github/skills/content-curation/examples/` (benchmark curated sections)

**Key logic to extract:**
- Selection hierarchy: recency → GA over PREVIEW → enterprise relevance → feature maturity → information density
- Section structure: Optional Lead Section → Copilot (Latest + IDE Parity) → Copilot at Scale → Additional Sections
- IDE Parity pattern: "Improved IDE Feature Parity" parent bullet with nested per-IDE bullets + rollout note
- Model consolidation: merge model rollouts into single "Model availability updates" bullet
- Governance/Legal: surface under Copilot at Scale
- Link priority: Announcement > Docs > Release Notes > Changelog
- Content format: bold + GA/PREVIEW label + description + links
- Strip all metadata (dates, scores) from output
- Never mention Free/Individual/Pro/Pro+ plans
- Target: 15-20 curated items
- Output: `workspace/newsletter_phase3_curated_sections_YYYY-MM-DD.md`

**Reference files to create:**
- `references/selection-criteria.md` — Priority hierarchy, enterprise filter, plan exclusions
- `references/ide-parity-rules.md` — IDE rollout pattern, parity bullet format, rollout note
- `references/content-format-spec.md` — Bullet format, link priority, model consolidation, governance rules

---

### 6. newsletter-assembly (Phase 4)
**Agent:** @skill-builder
**Write to:** `.github/skills/newsletter-assembly/`
**Read these files:**
- `.github/skills/building-skill/SKILL.md`
- `.github/agents/customer_newsletter.agent.md` (Phase 4 section + Structure & Formatting + Introduction/Closing templates)
- `.github/prompts/phase_4_final_assembly.prompt.md`
- `.github/skills/newsletter-assembly/examples/` (December.md and August.md)

**Key logic to extract:**
- Section order: Introduction → Monthly Announcement (if present) → Copilot → Additional Sections → Events → Closing
- Fixed templates: Introduction (with 2-3 dynamic highlights), Closing
- NO Dylan's Corner — section is removed entirely (Decision D11)
- Mandatory elements: changelog links (6 IDEs), YouTube playlists (3)
- Quality gates: no raw URLs, no em dashes, bold formatting, no Free/Individual/Pro/Pro+ mentions
- Section dividers with `---`
- Output: `output/YYYY-MM_month_newsletter.md`

**Reference files to create:**
- `references/section-ordering.md` — Mandatory section order, conditional sections
- `references/tone-guidelines.md` — Personal curator voice, enterprise tone, formatting no-nos
- `references/quality-checklist.md` — Pre-delivery quality gates, mandatory content blocks (templates, changelogs, playlists)

---

### 7. newsletter-validation (Post-Pipeline)
**Agent:** @skill-builder
**Write to:** `.github/skills/newsletter-validation/`
**Read these files:**
- `.github/skills/building-skill/SKILL.md`
- `.github/agents/customer_newsletter.agent.md` (entire file for quality rules scattered throughout)
- `.github/skills/newsletter-validation/examples/` (December.md and August.md — known-good outputs)

**Key logic to extract — this skill is unique because it VALIDATES, not generates:**
- Automated checks: required sections present, no raw URLs, no wikilinks, no em dashes, no consumer plans, no placeholders (except intended ones), GA/PREVIEW uppercase, events table has Date column, output file exists
- Forbidden patterns: `[[`, raw `http://` or `https://` not in markdown link, `—`, `Copilot Free`, `Copilot Individual`, `Copilot Pro`, `Dylan` (D11)
- Required sections: Introduction, Copilot Updates (Latest Releases + Copilot at Scale), Events, Closing
- Required content blocks: changelog links, YouTube playlists
- Manual review rubric: tone, enterprise relevance, link validity, section balance

**Files to create:**
- `references/validation-rubric.md` — Checklist with automated + manual checks
- `scripts/validate_newsletter.sh` — Bash script implementing automated checks (exit 0 pass, exit 1 fail with details)

---

### 8. kb-maintenance (Utility)
**Agent:** @skill-builder
**Write to:** `.github/skills/kb-maintenance/`
**Read these files:**
- `.github/skills/building-skill/SKILL.md`
- `kb/SOURCES.yaml` (first 100 lines for structure)
- `kb/MAINTENANCE_RUNBOOK.md`
- `kb/KB_INDEX.md`

**Key logic to extract — this is a utility skill, not a pipeline phase:**
- Monthly maintenance workflow: poll feeds → check link health → update SOURCES.yaml → update CURRENT_STATE_SNAPSHOT.md
- Feed polling: read SOURCES.yaml update_feeds, fetch RSS/Atom, identify new entries since last run
- Link health: validate canonical_urls and reference_urls, report dead links
- Delta report: what's new, what's broken, what needs manual review

**Files to create:**
- `references/maintenance-procedure.md` — Monthly workflow, feed types, update cadence expectations
- `scripts/poll_sources.py` — Python script to poll RSS/Atom feeds from SOURCES.yaml, emit delta report
- `scripts/check_link_health.py` — Python script to validate URLs from SOURCES.yaml, emit health report

## Dependencies

None between skills — all 8 are independent writes. Dispatch all simultaneously.

## Completion Criteria

All 8 skills must:
1. Pass `make validate-skill SKILL=.github/skills/<name>`
2. Have SKILL.md > 50 lines
3. Have at least 1 reference file in `references/`
4. newsletter-validation must have `scripts/validate_newsletter.sh`
5. kb-maintenance must have `scripts/poll_sources.py` and `scripts/check_link_health.py`

## Post-Completion Disk Verification (MANDATORY)

After all agents report done, run these commands yourself and report the ACTUAL numbers:

```bash
# 1. Line counts (every SKILL.md must be >50)
for skill in url-manifest content-retrieval content-consolidation events-extraction content-curation newsletter-assembly newsletter-validation kb-maintenance; do
  wc -l .github/skills/$skill/SKILL.md
done

# 2. Reference files exist with content (every skill must have >=1 ref >=20 lines)
for skill in url-manifest content-retrieval content-consolidation events-extraction content-curation newsletter-assembly newsletter-validation kb-maintenance; do
  for ref in .github/skills/$skill/references/*.md; do
    [ -f "$ref" ] && wc -l "$ref"
  done
done

# 3. Required scripts exist and parse
bash -n .github/skills/newsletter-validation/scripts/validate_newsletter.sh && echo "validate_newsletter.sh: syntax OK"
python3 -c "import ast; ast.parse(open('.github/skills/kb-maintenance/scripts/poll_sources.py').read())" && echo "poll_sources.py: syntax OK"
python3 -c "import ast; ast.parse(open('.github/skills/kb-maintenance/scripts/check_link_health.py').read())" && echo "check_link_health.py: syntax OK"

# 4. No forbidden content
grep -ri "Dylan" .github/skills/ | grep -v "examples/" | wc -l

# 5. Full validation
make validate-all-skills
```

If ANY check fails, identify the failing skill and dispatch a targeted fix agent. Do not report success until disk verification passes.

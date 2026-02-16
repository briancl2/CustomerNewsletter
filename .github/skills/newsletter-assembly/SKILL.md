---
name: newsletter-assembly
description: "Assembles all pipeline components into the complete, polished newsletter. Use when running Phase 4 of the newsletter pipeline. Combines Phase 3 curated sections with Phase 2 events, adds introduction and closing, enforces section ordering and quality checks. Keywords: newsletter assembly, phase 4, final assembly, newsletter generation."
metadata:
  category: domain
  phase: "4"
---

# Newsletter Assembly

Assemble Phase 3 curated sections and Phase 2 events into a complete newsletter.

## Quick Start

1. Read Phase 3 curated sections from `workspace/newsletter_phase3_curated_sections_*.md`
2. Read Phase 2 events from `workspace/newsletter_phase2_events_*.md`
3. Create introduction with 2-3 key highlights
4. Assemble sections in mandatory order
5. Add standard closing, changelog links, YouTube playlists
6. Enforce heading structure and density targets for long windows
7. Write output to `output/YYYY-MM_month_newsletter.md`

## Inputs

- **Phase 3 Curated Sections**: `workspace/newsletter_phase3_curated_sections_*.md` (required)
- **Phase 2 Events**: `workspace/newsletter_phase2_events_*.md` (required)

## Output

- **File**: `output/YYYY-MM_month_newsletter.md`
- Complete newsletter ready for distribution

## Core Workflow

### Step 1: Create Introduction

Use the standard template with 2-3 dynamic highlights:

```
This is a personally curated newsletter for my customers, focused on the most
relevant updates and resources from GitHub this month. Highlights for this month
include [2-3 key highlights]. If you have any feedback or want to dive deeper
into any topic, please let me know. Feel free to share this newsletter with
others on your team as well. You can find an archive of past newsletters
[here](https://github.com/briancl2/CustomerNewsletter).
```

Select highlights from the most impactful GA features or major enterprise announcements in the curated sections.

### Step 2: Assemble in Mandatory Order

See [section-ordering.md](references/section-ordering.md) for the required section sequence.

1. **Introduction** (with highlights)
2. **Monthly Announcement / Lead Section** (if present in Phase 3)
3. **Copilot** (mandatory heading shape: `# Copilot` with `## Latest Releases`, plus Copilot at Scale with changelogs)
4. **Enterprise and Security Updates** (H1 for Feb benchmark-style runs)
5. **Resources and Best Practices** (H1 when sources exist)
6. **Webinars, Events, and Recordings** (H1, with H2 subheadings from Phase 2)
7. **Closing**

Use `---` dividers between major sections.

### Step 3: Mandatory Content Blocks

Verify these are present in the assembled newsletter:

**In Copilot at Scale**: Standard tracking links. See [quality-checklist.md](references/quality-checklist.md).
When `BENCHMARK_MODE=feb2026_consistency`, expand this to the full tracking set:
- Copilot Feature Matrix
- GitHub Copilot Changelog
- VS Code Release Notes
- Visual Studio Release Notes
- JetBrains Plugin
- Xcode Releases
- Copilot CLI Releases
- GitHub Previews
- Preview Terms Changelog

**In Events section**: Brian's YouTube playlists at the beginning.

### Step 4: Add Closing

```
If you have any questions or want to discuss these updates in detail, feel free
to reach out. As always, I'm here to help you and your team stay informed and
get the most value from GitHub. I welcome your feedback, and please let me know
if you would like to add or remove anyone from this list.
```

### Step 5: Quality Checks

See [quality-checklist.md](references/quality-checklist.md) for the full pre-delivery checklist.

Run through:
- [ ] No raw URLs (all embedded as markdown links)
- [ ] No em dashes
- [ ] Bold formatting on product names and feature names
- [ ] No Copilot Free/Individual/Pro/Pro+ references
- [ ] GA/PREVIEW labels properly formatted
- [ ] Enterprise focus maintained throughout
- [ ] Section dividers with `---`
- [ ] Professional but conversational tone
- [ ] For >=60-day ranges, newsletter has >=3000 words and >=110 markdown links
- [ ] H1 headings include:
  - `# Copilot Everywhere: ...`
  - `# Copilot`
  - `# Enterprise and Security Updates`
  - `# Resources and Best Practices`
  - `# Webinars, Events, and Recordings`
- [ ] Copilot release section uses `## Latest Releases` (not `# Copilot - Latest Releases`)
- [ ] No standalone `# GitHub Platform Updates` section for Feb 2026 benchmark consistency
- [ ] Event subheadings are H2:
  - `## Virtual Events`
  - `## In-Person Events`
  - `## Behind the scenes`

## Reference

- [Section Ordering](references/section-ordering.md) - Mandatory section order
- [Tone Guidelines](references/tone-guidelines.md) - Voice, style, formatting rules
- [Quality Checklist](references/quality-checklist.md) - Pre-delivery quality gates
- [Editorial Intelligence §1](../../../reference/editorial-intelligence.md) - Theme detection rules for lead section decisions
- [Benchmark Examples](examples/) - December and August 2025 newsletters

## Done When

- [ ] Newsletter file exists at `output/YYYY-MM_month_newsletter.md`
- [ ] Introduction with 2-3 highlights present
- [ ] All mandatory sections in correct order
- [ ] Changelog links in Copilot at Scale
- [ ] YouTube playlists in Events section
- [ ] No raw URLs, no em dashes, no consumer plan mentions
- [ ] Professional tone throughout
- [ ] Ready for distribution

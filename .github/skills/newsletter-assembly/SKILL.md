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

1. Read personalization from `config/profile.yaml`
2. Read Phase 3 curated sections from `workspace/newsletter_phase3_curated_sections_*.md`
3. Read Phase 2 events from `workspace/newsletter_phase2_events_*.md`
4. Create introduction with 2-3 key highlights
5. Assemble sections in mandatory order
6. Add standard closing, changelog links, YouTube playlists
7. Write output to `output/YYYY-MM_month_newsletter.md`

## Inputs

- **Profile Configuration**: `config/profile.yaml` (required)
- **Phase 3 Curated Sections**: `workspace/newsletter_phase3_curated_sections_*.md` (required)
- **Phase 2 Events**: `workspace/newsletter_phase2_events_*.md` (required)

## Output

- **File**: `output/YYYY-MM_month_newsletter.md`
- Complete newsletter ready for distribution

## Core Workflow

### Step 1: Create Introduction

Use the standard template with 2-3 dynamic highlights, with values from `config/profile.yaml`:

```
This is a personally curated newsletter for my customers, focused on the most
relevant updates and resources from GitHub this month. Highlights for this month
include [2-3 key highlights]. If you have any feedback or want to dive deeper
into any topic, please let me know. Feel free to share this newsletter with
others on your team as well. You can find an archive of past newsletters
[here](<publishing.archive_url from config/profile.yaml>).
```

Select highlights from the most impactful GA features or major enterprise announcements in the curated sections.

### Step 2: Assemble in Mandatory Order

See [section-ordering.md](references/section-ordering.md) for the required section sequence.

1. **Introduction** (with highlights)
2. **Monthly Announcement / Lead Section** (if present in Phase 3)
3. **Copilot** (mandatory: Latest Releases + Copilot at Scale with changelogs)
4. **Additional sections** (Security, Platform Updates, etc. as warranted)
5. **Webinars, Events, and Recordings** (from Phase 2, with YouTube playlists)
6. **Closing**

Use `---` dividers between major sections.

### Step 3: Mandatory Content Blocks

Verify these are present in the assembled newsletter:

**In Copilot at Scale**: Standard changelog links (6 IDEs). See [quality-checklist.md](references/quality-checklist.md).

**In Events section**: YouTube playlists from `links.youtube_playlists` in `config/profile.yaml` at the beginning.

### Step 4: Add Closing

```
If you have any questions or want to discuss these updates in detail, feel free
to reach out. As always, I'm here to help you and your team stay informed and
get the most value from GitHub. I welcome your feedback.
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

## Reference

- [Section Ordering](references/section-ordering.md) - Mandatory section order
- [Tone Guidelines](references/tone-guidelines.md) - Voice, style, formatting rules
- [Quality Checklist](references/quality-checklist.md) - Pre-delivery quality gates
- `config/profile.yaml` - Curator voice, audience, links, and optional section settings
- [Editorial Intelligence §1](../../../reference/editorial-intelligence.md) - Theme detection rules for lead section decisions
- [Benchmark Examples](examples/) - December and August 2025 newsletters

## Done When

- [ ] Newsletter file exists at `output/YYYY-MM_month_newsletter.md`
- [ ] `config/profile.yaml` fields are reflected in intro/closing and links
- [ ] Introduction with 2-3 highlights present
- [ ] All mandatory sections in correct order
- [ ] Changelog links in Copilot at Scale
- [ ] YouTube playlists in Events section
- [ ] No raw URLs, no em dashes, no consumer plan mentions
- [ ] Professional tone throughout
- [ ] Ready for distribution

# Curator Notes Intelligence

> Mined from 10 benchmark cycles (Sep 2024 - Dec 2025) containing notes/links files.
> Traces the transformation from raw human-curated links to published newsletter content.

## 1. Inventory of Notes Files Across Cycles

| Cycle | Notes File | Links | Structure | Role |
|-------|-----------|------:|-----------|------|
| Aug 2024 | `next_month_links_from_july.md` | 4 | Minimal carry-forward list | Parking lot |
| Sep 2024 | `september_links_raw.md` | 38 | "Next Month" scratch + full newsletter draft | Draft + parking lot |
| Oct 2024 | `october_links_raw.md` | 38 | Same two-part structure | Draft + parking lot |
| Dec 2024 | `november_links_raw.md` | 57 | Scratch pad + full newsletter draft | Draft + parking lot |
| Jan 2025 | `raw_links.md` | 54 | Scratch pad (Slack/internal) + full newsletter draft | Draft + parking lot |
| Feb 2025 | `raw_links.md` | 50 | Scratch pad + full newsletter draft | Draft + parking lot |
| May 2025 | `Newsletter_May_initial_321b220f.md` | ~20 | Full draft (spaces backfill era) | Draft |
| Jun 2025 | `june_links_96dbb33c.md` | 5 | Raw URL dump | Seeds for pipeline |
| Aug 2025 | `july_links_a19524df.md` | 11 | Raw URL dump | Seeds for pipeline |
| Sep 2025 | `september_links_a219841e.md` | 1 | Single URL | Minimal seed |
| Dec 2025 | `september_newsletter_links.md` | 40 | URL dump + structured Universe sections | Hybrid seed + editorial priority |

**Key finding: Two distinct eras.**

### Pre-Agentic (2024 - Apr 2025)
The notes file IS the newsletter. The human writes the full draft directly in the file. A "Next Month" scratch section at the top collects carry-forward items for the next cycle. 100% of final content comes from the notes file. No pipeline.

### Agentic Era (Jun 2025+)
The notes file is a seed -- a minimal brain dump of 5-40 raw URLs. The agentic pipeline generates 80-90% of the final content by scanning changelogs, blogs, and release notes. The notes file contributes ~10-18% of unique content that the pipeline cannot discover.

## 2. Link Type Taxonomy and Survival Rates

| Link Type | Count (across all seed files) | Survival Rate | Treatment |
|-----------|----:|:---:|---|
| **GitHub Changelog** | 6 | 67% | INCLUDED or SUPERSEDED by newer entry on same topic |
| **Named feature hints** (text, no URL) | 4 | 100% | Become section themes and lead decisions |
| **Community resources** (awesome-lists, extensions) | 3 | 100% | INCLUDED -- pipeline can't find these |
| **Team member content** (gists, guides) | 2 | 100% | INCLUDED -- personal curation uniqueness |
| **Microsoft DevBlog** | 2 | 50% | Depends on GitHub-specificity |
| **GitHub Blog news-insights** | 2 | 100% | Major announcements always survive |
| **Industry thought leadership** (HBR, Substack, Substack, etc.) | 8 | 0% | ALWAYS EXCLUDED from newsletter body. But may inform framing |
| **Internal links** (Slack, Google Docs, GH Discussions, project boards) | 12 | 0% | ALWAYS EXCLUDED. Serve as "something is happening" signals |
| **YouTube videos** | 4 | 25% | Only conference keynotes survive; standalone explainers drop |
| **Analyst reports** (Forrester, Gartner) | 1 | 0% | Paywalled, never linked directly |
| **Event registrations** | 3 | 33% | Only future events within newsletter window survive |
| **Text notes** (no URL, vague) | 4 | 0% | "ESSP", "Well architected" -- too vague to act on |

### Survival Rules

**100% survival** (always include):
- Named feature hints (Copilot Spaces, Coding Agent, etc.)
- Community resources with public URLs
- Team member guides and gists
- GitHub Blog strategic announcements

**Conditional survival** (~50%):
- GitHub Changelog entries in the date range
- Microsoft DevBlog posts specifically about GitHub features
- YouTube videos of major conference sessions (Build, Universe, Ignite)

**0% survival** (always filter):
- Internal links (Slack, Google Docs, GH Discussions, project boards)
- Industry thought leadership (HBR, Pragmatic Engineer, Substack newsletters)
- Analyst reports behind paywalls
- Vague text notes without URLs
- Competitor content (Cloudflare, SonarSource)

## 3. Transformation Patterns

### Pattern A: URL Supersession
A changelog entry in the notes gets replaced by a newer, more comprehensive entry.
- Notes: `changelog/2025-06-30-managing-cost-center-via-api`
- Final: `changelog/2025-08-18-customers-can-now-add-users-to-a-cost-center-...`
- *Same feature, newer announcement with broader scope*

### Pattern B: Source Promotion
A blog post gets replaced by the official release notes.
- Notes: `code.visualstudio.com/blogs/.../openSourceAIEditorFirstMilestone`
- Final: `code.visualstudio.com/updates/v1_102`
- *Blog was the announcement; release notes are the authoritative source*

### Pattern C: Concept Absorption
A bare text hint expands into a full section.
- Notes: "Copilot Spaces" (two words)
- Final: Full section with 3 URLs (Launch, Issues/PR Support, Deep Dive)
- *The hint signals editorial priority; pipeline fills in the detail*

### Pattern D: Internal-to-Public Translation
An internal link signals a topic; the pipeline finds the public-facing content.
- Notes: `github.slack.com/archives/C08HSF91484/p1767813904555639`
- Final: The feature discussed in Slack appears as a changelog-sourced item
- *The Slack link was a "watch this space" signal*

## 4. The Two Unique Contributions of Notes Files

### 4A: Content the Pipeline Cannot Discover

These items exist ONLY because the human dropped them in the notes file:

| Type | Examples | Why Pipeline Misses It |
|------|----------|----------------------|
| Team member gists | Dylan's PRU Budgeting Guide | Personal gists aren't on any changelog/blog feed |
| VS Code extensions | Agent TODOs by digitarald | Third-party marketplace not scanned |
| Community awesome lists | awesome-ai-native, awesome-copilot | Personal GitHub Pages not scanned |
| Conference session videos | MS Build specific talks | YouTube is not a pipeline source |
| Internal knowledge signals | Slack links, GH Discussions | Not public; translate to public references |

### 4B: Editorial Priority Signals

Even when the pipeline WOULD find the same content, the notes file determines how prominent it is:

| Signal Type | Example | Effect on Newsletter |
|-------------|---------|---------------------|
| Named in notes as text hint | "Coding Agent Preview" | Becomes the LEAD section |
| First item in notes file | Agent HQ / Universe content | Becomes the opening story |
| Multiple related links clustered | 5 Universe governance links | Triggers governance cluster lead |
| Presence of webinar links | KUWC series registration | Drives events section structure |

## 5. Notes File Evolution Pattern

```
Aug 2024:  4 links   (minimal carry-forward)
Sep 2024: 38 links   (full draft + scratch)
Oct 2024: 38 links   (full draft + scratch)
Dec 2024: 57 links   (full draft + scratch)  ← peak of manual era
Jan 2025: 54 links   (full draft + scratch)
Feb 2025: 50 links   (full draft + scratch)
------- AGENTIC TRANSITION -------
Jun 2025:  5 links   (seed only)             ← pipeline takes over
Aug 2025: 11 links   (seed only)
Sep 2025:  1 link    (minimal)
Dec 2025: 40 links   (hybrid: seed + structured Universe sections)
Feb 2026: ~20 links  (Jan.md from user: seed + scattered notes)
```

The Dec 2025 file is a hybrid because the Universe event generated a large structured notes dump that the human organized before the pipeline ran. This suggests: **high-event months produce structured notes; normal months produce minimal seeds.**

## 6. Recommendations for Curator Notes Skill

### Input Format

The skill should accept a `workspace/curator_notes_YYYY-MM.md` file that can be in ANY of these formats:
1. **Raw URL dump** (5-40 URLs, one per line)
2. **URL dump with text notes** (URLs + cryptic labels like "ESSP")
3. **Structured sections** (Universe-style: URLs grouped by theme with descriptions)
4. **Hybrid** (scratch URLs at top + structured content below)

### Processing Steps

1. **Parse and classify each item** using the link type taxonomy
2. **Filter internal links** (Slack, Google Docs, GH Discussions, project boards) -- mark as "editorial signals only"
3. **Filter industry content** (third-party blogs, analyst reports) -- mark as "framing context only, do not link"
4. **Visit surviving public URLs** to extract content (title, description, dates)
5. **Cross-reference with Phase 1A URL manifest** -- identify overlap (pipeline already has it) vs unique additions
6. **Output**: Two artifacts:
   - `workspace/curator_notes_processed_YYYY-MM.md` -- extracted items in universal extraction format
   - `workspace/curator_notes_editorial_signals_YYYY-MM.md` -- priority hints, theme suggestions, internal context

### Integration Point

Inject between Phase 1C (consolidation) and Phase 3 (curation). The curator notes processed items become additional discoveries. The editorial signals inform Phase 3's lead section decision and item prioritization.

### No-File Behavior

If no `curator_notes_YYYY-MM.md` exists, the pipeline runs normally with zero impact. The skill is additive, never blocking.

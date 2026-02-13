---
name: curator-notes
description: "Processes the human curator's monthly notes file into pipeline-ready content. Reads raw URLs, text hints, and structured sections from the curator's brain dump, classifies each item, filters internal/industry content, visits surviving URLs, and outputs processed items + editorial signals. Use between Phase 1C and Phase 3 when a curator notes file exists. Keywords: curator notes, brain dump, links file, monthly notes, human curation, editorial signals."
metadata:
  category: domain
  phase: "1.5"
---

# Curator Notes Processing

Process the human curator's monthly notes file into pipeline-ready content and editorial signals.

## Quick Start

1. Check for `workspace/curator_notes_YYYY-MM.md` (or known variants)
2. If no file exists, skip this phase entirely -- pipeline continues normally
3. Parse and classify every item using the link type taxonomy
4. Filter: internal links become editorial signals; public links get visited
5. Output processed items + editorial signals
6. Items feed into Phase 3 curation alongside Phase 1C discoveries

## Inputs

- **Curator notes file** (optional): `workspace/curator_notes_YYYY-MM.md`
  - May also appear as: `workspace/<month>.md`, `workspace/<Month>.md`, `workspace/Jan.md`, etc.
  - Check for any `.md` file in `workspace/` that looks like a brain dump of links
- **Phase 1C Discoveries**: For cross-reference (avoid duplicates)

## Output

- `workspace/curator_notes_processed_YYYY-MM.md` -- Items in universal extraction format, ready for Phase 3
- `workspace/curator_notes_editorial_signals_YYYY-MM.md` -- Priority hints, theme suggestions, internal context

## Core Workflow

### Step 0: Locate the Notes File

Check these paths in order:
1. `workspace/curator_notes_YYYY-MM.md` (canonical)
2. `workspace/<Month>.md` (e.g., `workspace/Jan.md`, `workspace/February.md`)
3. Any `.md` file in `workspace/` containing 3+ URLs that isn't a pipeline output

If no file found: **SKIP. Output nothing. Pipeline continues.**

### Step 1: Parse and Classify

For each line/item in the notes file, classify into one of these types:

| Type | Detection Pattern | Action |
|------|-------------------|--------|
| **GitHub Changelog** | `github.blog/changelog/` | PROCESS: visit URL, extract item |
| **GitHub Blog** | `github.blog/news-insights/` or `github.blog/ai-and-ml/` | PROCESS: visit URL, extract item |
| **VS Code Release Notes** | `code.visualstudio.com/updates/` | PROCESS: visit URL, extract features |
| **Microsoft DevBlog** | `devblogs.microsoft.com/` | PROCESS: visit if GitHub-specific |
| **Community resource** | `github.com/<user>/`, personal sites, awesome-lists | PROCESS: visit URL, extract description |
| **VS Code extension** | `marketplace.visualstudio.com/` | PROCESS: visit URL, extract description |
| **YouTube video** | `youtube.com/watch`, `youtu.be/` | PROCESS: visit, extract title and context |
| **Event registration** | `registration.goldcast.io/`, `github.com/resources/events/` | PROCESS: extract event details |
| **Named feature hint** | Text line without URL referencing a product name | SIGNAL: flag as editorial priority |
| **Internal link** | Internal collaboration URLs (chat, docs, private repos, project boards) | SIGNAL: translate topic to public reference |
| **Industry content** | `hbr.org/`, `substack.com/`, `medium.com/`, `martinfowler.com/`, analyst reports | SIGNAL: framing context only |
| **Competitor content** | `blog.cloudflare.com/`, `sonarsource.com/`, etc. | SIGNAL: competitive context only |
| **Text note** (vague) | Bare text, no URL, no product name | SIGNAL: note for context |

### Step 2: Filter and Route

**PROCESS items** (visit, extract, output as discoveries):
- GitHub Changelog, Blog, VS Code, DevBlog, Community, Extensions, Videos, Events
- Visit each URL and extract: title, date, description, enterprise relevance

**SIGNAL items** (output as editorial signals):
- Internal links: identify the topic and note "watch for public announcement about [topic]"
- Industry content: summarize the thesis for framing context
- Named feature hints: flag as lead section candidates
- Competitor content: note competitive positioning opportunity

### Step 3: Cross-Reference with Phase 1C

For each PROCESS item, check if Theme 1C discoveries already cover it:
- **Already covered**: Mark as "REINFORCEMENT" (human agreed this is important -- boost priority in Phase 3)
- **Not covered**: Mark as "ADDITION" (unique content from curator -- must include in Phase 3)

### Step 4: Visit and Extract

For each PROCESS item not already covered by Phase 1C:
1. Fetch the URL
2. Extract: title, date, description (2-3 sentences), enterprise relevance (1-10)
3. Format in universal extraction format
4. Assign category from the newsletter taxonomy

### Step 5: Write Outputs

**Processed items** (`workspace/curator_notes_processed_YYYY-MM.md`):
```markdown
## Curator Notes: Processed Items

### Additions (not in Phase 1C)
- **[Item Title]** -- Description. - [Label](URL)
  - Source: Curator notes
  - Enterprise Relevance: N/10

### Reinforcements (also in Phase 1C -- boost priority)
- **[Item Title]** -- Already in discoveries. Curator explicitly flagged.
```

**Editorial signals** (`workspace/curator_notes_editorial_signals_YYYY-MM.md`):
```markdown
## Editorial Signals from Curator Notes

### Lead Section Candidates
- [Feature hint]: Curator named this explicitly. Consider for lead.

### Priority Boosts
- [Topic]: Curator linked N items about this topic. Strong signal.

### Framing Context
- [Industry article summary]: Useful for newsletter introduction framing.

### Internal Signals (not linkable)
- [Internal thread topic]: Something is happening around [X]. Watch for public announcement.
```

## Integration with Pipeline

- **Phase 1C -> Phase 1.5 (this skill) -> Phase 3**
- Phase 3 (content-curation) reads BOTH Phase 1C discoveries AND curator notes processed items
- Editorial signals inform Phase 3's lead section decision and item prioritization
- If a named feature hint matches a Phase 1C discovery, it gets 2.0x priority boost

## Link Type Survival Intelligence

From analysis of 10 benchmark cycles (see `reference/curator-notes-intelligence.md`):

| Type | Survival Rate | Notes |
|------|:---:|---|
| Named feature hints | 100% | Always become sections/leads |
| Community resources | 100% | Pipeline can't find these |
| Team member content | 100% | Personal curation uniqueness |
| GitHub Changelog | 67% | May be superseded |
| Microsoft DevBlog | 50% | Only if GitHub-specific |
| YouTube videos | 25% | Only major conference sessions |
| Internal links | 0% | Translate to public references |
| Industry blogs | 0% | Framing context only |
| Analyst reports | 0% | Never linked directly |

## Reference

- [Curator Notes Intelligence](../../../reference/curator-notes-intelligence.md) -- Full analysis from 10 benchmark cycles
- [Content Format Spec](../content-curation/references/content-format-spec.md) -- Output formatting rules

## Done When

- [ ] Notes file located (or confirmed absent)
- [ ] All items classified by type
- [ ] Public URLs visited and extracted
- [ ] Cross-referenced with Phase 1C discoveries
- [ ] Processed items file exists (if notes file existed)
- [ ] Editorial signals file exists (if notes file existed)
- [ ] No internal links leaked to processed items output

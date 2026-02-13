---
name: video-matching
description: "Matches newsletter entries to official YouTube videos from VS Code and GitHub channels. Fetches RSS feeds, matches by topic, and adds [Video (Xm)](URL) links to relevant newsletter bullets. Use as Phase 4.6 after polishing and before editorial review. Keywords: video matching, youtube, video links, phase 4.6, enrichment."
metadata:
  category: domain
  phase: "4.6"
---

# Video Matching

Enrich newsletter entries with links to matching official YouTube videos from the VS Code and GitHub channels.

## Quick Start

1. Read the assembled newsletter from `output/YYYY-MM_month_newsletter.md`
2. Fetch RSS feeds from VS Code and GitHub YouTube channels
3. Match videos to newsletter entries by topic
4. Add `[Video (Xm)](URL)` links to matched entries
5. Write enriched newsletter back to `output/YYYY-MM_month_newsletter.md`

## Inputs

- **Newsletter**: `output/YYYY-MM_month_newsletter.md` (required)
- **YouTube RSS feeds** (fetch these):
  - VS Code channel: `https://www.youtube.com/feeds/videos.xml?channel_id=UCs5Y5_7XK8HLDX0SLNwkd3w`
  - GitHub channel: `https://www.youtube.com/feeds/videos.xml?channel_id=UC7c3Kb6jYCRj4JOHHZTxKsQ`

## Output

- **Enriched Newsletter**: `output/YYYY-MM_month_newsletter.md` (overwrite in place)
- Video matching report (inline with work)

## Core Workflow

### Step 1: Fetch Video Feeds

Fetch both YouTube RSS feeds. Each returns the 15 most recent videos with:
- `<title>` — Video title
- `<link>` — YouTube URL (format: `https://www.youtube.com/watch?v=VIDEO_ID` or `/shorts/VIDEO_ID`)
- `<published>` — Publication date
- `<media:description>` — Full description with chapters, links, and speaker info

Parse both feeds and build a combined video inventory.

### Step 2: Filter Videos

**INCLUDE** videos that are:
- Published within the newsletter's DATE_RANGE (or up to 2 weeks before/after)
- About GitHub Copilot, VS Code, agents, MCP, security, or enterprise features
- Full-length videos (>2 minutes) or Shorts that directly demonstrate a named feature

**EXCLUDE**:
- Shorts that are generic teasers without specific feature content
- Open Source Friday episodes about non-GitHub projects
- Non-English content
- General tutorials not tied to a specific feature in the newsletter

### Step 3: Match Videos to Newsletter Entries

For each video, attempt to match it to a newsletter entry using these signals (in priority order):

1. **Title keyword match**: Video title contains a key phrase from the newsletter entry (e.g., "Subagents" matches "Parallel Subagents (`GA`)")
2. **Description link match**: Video description links to the same changelog/release-notes URL as the newsletter entry
3. **Topic overlap**: Video covers the same feature area (e.g., a video about "MCP Apps" matches the "MCP Ecosystem Expansion" bullet)

**Confidence levels**:
- **HIGH (90%+)**: Title directly references the feature name OR description links to the same changelog URL. Add the link.
- **MEDIUM (60-80%)**: Topic overlap but not a direct title/URL match. Add only if no HIGH match exists for that entry.
- **LOW (<60%)**: Tangential connection. Do NOT add.

### Step 4: Estimate Video Duration

The RSS feed does NOT include video duration. Estimate using these heuristics:
- **Shorts** (`/shorts/` in URL): Label as `(1m)`
- **VS Code Live / livestream**: Label as `(60m)` (typically 1-2 hours, but 60m is a safe estimate)
- **Podcast episodes**: Label as `(25m)`
- **Regular videos**: Label as `(5m)` unless description chapters suggest longer (sum chapter timestamps)
- If the description contains chapter timestamps (e.g., "14:56 In summary"), use the last timestamp rounded up to estimate duration

### Step 5: Add Video Links

For each matched entry, append a `[Video (Xm)](URL)` link. Place it alongside existing links using the standard pipe separator:

**Before**:
```markdown
-   **Parallel Subagents (`GA`)** -- Description. - [Release Notes](URL) | [Docs](URL)
```

**After**:
```markdown
-   **Parallel Subagents (`GA`)** -- Description. - [Release Notes](URL) | [Docs](URL) | [Video (25m)](https://www.youtube.com/watch?v=GMAoTeD9siU)
```

For inline-linked entries (7+ links), add the video link at the end of the "See also:" line or as the last inline link.

### Step 6: Validate

- [ ] All added video links are valid YouTube URLs
- [ ] Video durations are reasonable estimates
- [ ] No duplicate video links (same video linked to multiple entries)
- [ ] Only HIGH confidence matches were added
- [ ] Links use the format `[Video (Xm)](URL)`

## Reference

- [Video Sources](references/video-sources.md) — Channel IDs, RSS feed URLs, matching heuristics
- [Content Format Spec](../content-curation/references/content-format-spec.md) — Link format rules

## Done When

- [ ] Both RSS feeds fetched and parsed
- [ ] Videos matched to newsletter entries (HIGH confidence only)
- [ ] `[Video (Xm)]` links added to matched entries
- [ ] All links validated
- [ ] Enriched newsletter written to disk

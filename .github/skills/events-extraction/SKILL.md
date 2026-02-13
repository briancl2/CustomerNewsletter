---
name: events-extraction
description: "Extracts and formats upcoming events and webinars from provided URLs. Use when running Phase 2 of the newsletter pipeline. Fetches event pages, classifies into canonical categories, formats virtual and in-person event tables. Can run in parallel with Phases 1A-1C. Keywords: events extraction, phase 2, webinars, conferences, event formatting."
metadata:
  category: domain
  phase: "2"
---

# Events Extraction

Extract, classify, and format upcoming events and webinars for the newsletter.

## Quick Start

1. Read `config/profile.yaml` for timezone and playlist defaults
2. Receive list of event URLs (5-15 typical)
3. Fetch each URL and extract event details
4. Classify: Virtual, In-person, or Hybrid
5. Assign canonical categories (max 2, prefer 1)
6. Format into tables and bullet lists
7. Write output to `workspace/newsletter_phase2_events_YYYY-MM-DD.md`

**Independence**: This phase runs independently of Phases 1A-1C and can execute in parallel.

## Inputs

- **Profile Configuration**: `config/profile.yaml` (required for timezone and playlist links)
- **Event source URLs** (mandatory, scan ALL of these):
  - `https://github.com/resources/events` — GitHub's official events page (in-person + virtual)
  - `https://developer.microsoft.com/en-us/reactor/?search=github` — Microsoft Reactor events filtered for GitHub (virtual webinars, series, hackathons)
  - `https://aitour.microsoft.com/` — Microsoft AI Tour in-person events
  - Curator notes file (workspace/Jan.md or similar) for manually added events
- **COLLECTION_DATE**: Date for filename (defaults to today)

## Output

- **File**: `workspace/newsletter_phase2_events_YYYY-MM-DD.md`

## Core Workflow

### Step 1: Discovery

Scan ALL mandatory source URLs:

**GitHub Resources Events** (`github.com/resources/events`):
- Fetch the page, extract all upcoming events
- These are primarily in-person events (AI Tour, GitHub Connect, conferences) and KUWC virtual series

**Microsoft Reactor** (`developer.microsoft.com/en-us/reactor/?search=github`):
- Search for "github" to filter the full Reactor catalog
- This returns 20-30 events; apply the inclusion/exclusion filter below to select 10-15
- Follow series links (e.g., S-1625 Agentic DevOps Live) to get all sessions

**Microsoft AI Tour** (`aitour.microsoft.com`):
- Check for cities where GitHub has a confirmed booth/presence
- Cross-reference with github.com/resources/events (AI Tour events appear on both)

**Curator notes**: Check for manually added event URLs or KUWC series entries

### Step 1.5: Reactor Event Filtering (L69)

The Reactor catalog contains many events. Apply these filters:

**INCLUDE** (all must be true):
- Event is in English
- Event involves GitHub, Copilot, GHAS, VS Code, or Azure DevOps with GitHub integration
- Event is relevant to enterprise engineering leaders (not consumer/hobbyist)
- Event provides actionable training, product updates, or security guidance

**INCLUDE event types**:
- Agentic DevOps Live series (GitHub + Azure integration, modernization, security)
- VS Code Live release events (product updates)
- AI Dev Days with GitHub/Azure tracks (hackathons with enterprise prizes)
- Security sessions using GHAS + Defender for Cloud
- App modernization with Copilot agents (Java, .NET)
- GitHub + Azure DevOps workflow sessions

**EXCLUDE**:
- Non-English language events (Spanish, Portuguese, etc.)
- Competition/gaming formats ("Agents League Battle", esports-inspired)
- Generic AI framework tutorials without GitHub integration (LangChain4j, generic Python AI)
- Beginner-level series on non-GitHub tools
- Events with no GitHub speaker or GitHub product involvement

**Key signal**: Check the event tags. Events tagged with `Github`, `GitHub Copilot`, `Agentic DevOps`, or `VS Code` are strong candidates. Events tagged only with `AI` or generic topics without GitHub involvement should be excluded.

### Step 2: Extraction

Extract required fields per event:
- Event title (exact from source)
- Date (normalize to date only for virtual; include local configured timezone times only for conference sessions)
- Format: Virtual, In-person, or Hybrid
- Registration URL (direct sign-up link)

Optional but recommended:
- Location (City, ST, Country for in-person)
- Description (1-2 sentences, enterprise value focused)
- Speakers (if available)
- Series information

### Step 3: Classification

See [events-formatting.md](references/events-formatting.md) for complete formatting rules.

**Canonical categories** (use ONLY these, prefer 1, max 2):
- **Copilot**: All GitHub Copilot related sessions (VS Code AI events implicitly map here)
- **GitHub Platform**: Core platform, Actions, general feature launches
- **Developer Experience**: Workflows, training, productivity enablement
- **Enterprise**: Compliance, governance, administration, security policy

**Skill level**: Include only "Introductory" or "Advanced" when explicitly stated. Omit otherwise.

### Step 4: Formatting

**Virtual events**: Table with Date + Event + Categories (NO times)
**In-person events**: Bullet points with location
**Hybrid events**: List under In-person with "(Hybrid, virtual attendance available)"
**Conference sessions**: Detailed tables with Date + Time (CT) + Session + Description

### Step 5: Standard Content

Always include these blocks in the output:
- Copilot Fridays back catalog link from `links.copilot_fridays_catalog_url` in `config/profile.yaml`
- YouTube playlists from `links.youtube_playlists` in `config/profile.yaml`

### Step 6: Validation

Before writing output:
- [ ] Title, date, and registration URL present for all events
- [ ] Conference session times converted to `time.timezone` from `config/profile.yaml`
- [ ] All links embedded as markdown (no raw URLs)
- [ ] Hybrid listed under In-person with virtual note
- [ ] Categories use canonical taxonomy: `Copilot`, `GitHub Platform`, `Developer Experience`, `Enterprise`
- [ ] Enterprise relevance satisfied

## Reference

- [Events Formatting](references/events-formatting.md) - Table specs, category mapping, timezone rules
- [Benchmark Example](examples/) - Known-good Dec 2025 events

## Done When

- [ ] Events file exists at `workspace/newsletter_phase2_events_*.md`
- [ ] `config/profile.yaml` timezone and playlist links are applied
- [ ] All provided URLs processed
- [ ] Virtual events in table format (date only, no times)
- [ ] In-person events in bullet format with locations
- [ ] Canonical categories only (Copilot, GitHub Platform, Developer Experience, Enterprise)
- [ ] Standard content blocks included (Copilot Fridays, YouTube playlists)
- [ ] No raw URLs in output

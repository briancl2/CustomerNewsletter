# Events Formatting Reference

Table specifications, category mapping, timezone rules, and standard content blocks for Phase 2 events extraction.

## Event Type Formats

### Virtual Events (webinars, online training)

Use a table with Date + Event + Categories. **Never include times for virtual events.**

```markdown
| Date | Event | Categories |
|------|-------|-----------|
| Feb 12 | [Event Title](https://registration-url.com) | Copilot |
| Feb 19 | [Another Event](https://registration-url.com) | Developer Experience |
```

### In-person Events (conferences, meetups)

Use bullet points with location:

```markdown
* City, ST - **Month Day** - [Event Name](https://registration-url.com)
  Brief description (1 sentence, optional)
```

### Hybrid Events

List under In-person with a parenthetical note:

```markdown
* City, ST - **Month Day** - [Event Name](https://registration-url.com) (Hybrid, virtual attendance available)
  Brief description (1 sentence, optional)
```

### Conference Sessions (major conferences only)

Use detailed tables with CT times. Only include when a major conference occurs in the cycle.

#### Keynotes
```markdown
| Date | Time (CT) | Session | Speakers | Description |
|------|-----------|---------|----------|-------------|
| May 19 | 9:05 AM - 10:30 AM | [Session Title](URL) | Speaker Names | Brief description |
```

#### Topic Sessions
```markdown
| Date | Time (CT) | Session | Description |
|------|-----------|---------|-------------|
| May 19 | 11:45 AM - 12:45 PM | [Session Title](URL) | Brief description |
```

## Canonical Category Taxonomy

Use ONLY these categories. Prefer 1 category; use 2 only when both clearly apply.

| Category | Scope | Mapping Rules |
|----------|-------|---------------|
| **Copilot** | All GitHub Copilot related items | VS Code branded events about AI/Copilot map here |
| **GitHub Platform** | Core platform, security, Actions, ecosystem | General feature launches, infrastructure |
| **Developer Experience** | Workflows, best practices, productivity | Training, enablement, skill advancement |
| **Enterprise** | Compliance, governance, administration | Security/compliance/indemnity content maps here |

### Category Mapping Examples

- "VS Code Dev Day - AI Features" -> Copilot
- "GitHub Actions Best Practices Workshop" -> GitHub Platform, Developer Experience
- "Securing Your Supply Chain" -> Enterprise
- "Copilot for Infrastructure Engineers" -> Copilot, Developer Experience
- "Enterprise Managed Users Deep Dive" -> Enterprise

### Skill Level

- Include only "Introductory" or "Advanced" when **explicitly stated** in the source
- **Omit** skill level when not explicitly stated (do NOT infer)
- Do NOT put skill level in the Categories column

## Timezone Rules

- **Virtual events**: Date only. Never show times or time zones.
- **Conference sessions**: Convert all times to Central Time (CT)
- **Default**: If source timezone is missing, assume CT
- **In-person events**: Date only (no times)

## Standard Content Blocks

### Copilot Fridays (include when relevant)

```markdown
Also, watch the [Copilot Fridays back catalog](https://resources.github.com/copilot-fridays-english-on-demand/): Prompt Fundamentals, Copilot for MLOps/Data Science, Copilot for Infrastructure Engineers, GitHub Enterprise Managed Users for Copilot Users
```

### Brian's YouTube Playlists (always include)

```markdown
Brian's personally curated YouTube playlists, updated monthly: [Copilot Tips and Training Video](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D), [GitHub Enterprise, Actions, and GHAS videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ3wk4atKpN-yOW1FtyxN48W), [How GitHub GitHubs videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1nWhqxi-UQF_O-gYWo5jpG)
```

## Enterprise Focus

Prioritize events that:
1. Target enterprise audiences (not hobbyist/individual)
2. Provide business value for Engineering Managers and IT Leadership
3. Offer actionable training on GitHub enterprise features
4. Focus on compliance, security, or scale considerations
5. Feature GitHub speakers or GitHub product involvement
6. Are part of established series (Agentic DevOps Live, VS Code Live, KUWC, AppSec Monthly)

## Event Source Intelligence (L69)

| Source | URL | Content Type | Scan Method |
|--------|-----|--------------|-------------|
| GitHub Resources Events | `github.com/resources/events` | In-person (AI Tour, Connect, conferences) + KUWC virtual | Full page scan |
| Microsoft Reactor | `developer.microsoft.com/en-us/reactor/?search=github` | Virtual webinars, series, hackathons | Search "github", filter |
| Microsoft AI Tour | `aitour.microsoft.com` | In-person city events | Cross-ref with GitHub Resources |
| Curator Notes | `workspace/*.md` | Manually added events | Check for event URLs |

### Reactor Series to Track

These Reactor series consistently produce GitHub-relevant events:
- **Agentic DevOps Live** (S-1625): GitHub + Azure modernization, security, agents
- **VS Code Live** (S-1521): Monthly VS Code release events with Copilot demos
- **AI Dev Days**: Annual hackathon with GitHub/Azure tracks

## Output File Structure

```markdown
# Webinars, Events, and Recordings

Brian's personally curated YouTube playlists...

### [Conference Sessions Guide - if applicable]
[Detailed conference tables]

### Upcoming Virtual Events

Also, watch the Copilot Fridays back catalog...

| Date | Event | Categories |
|------|-------|-----------|
[virtual events rows]

### Upcoming In-person Events

[bullet point list with locations]
```

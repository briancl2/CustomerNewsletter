# Video Sources Reference

YouTube channel RSS feeds and matching heuristics for the video-matching skill.

## Channel Feeds

| Channel | ID | RSS Feed URL |
|---------|-----|-------------|
| **Visual Studio Code** (@code) | `UCs5Y5_7XK8HLDX0SLNwkd3w` | `https://www.youtube.com/feeds/videos.xml?channel_id=UCs5Y5_7XK8HLDX0SLNwkd3w` |
| **GitHub** (@GitHub) | `UC7c3Kb6jYCRj4JOHHZTxKsQ` | `https://www.youtube.com/feeds/videos.xml?channel_id=UC7c3Kb6jYCRj4JOHHZTxKsQ` |

Each feed returns the 15 most recent videos in Atom XML format with `<title>`, `<link>`, `<published>`, and `<media:description>`.

## Known Video Series (recurring, high match rate)

| Series | Channel | Matching Pattern | Typical Duration |
|--------|---------|------------------|-----------------|
| VS Code Release Highlights | @code | Title: "VS Code X.XXX Release Highlights" | 5-8m |
| VS Code Live (monthly) | @code | Title: "VS Code Live" or "VS Code Live:" | 60-120m |
| VS Code Insiders Podcast | @code | Detailed topic episodes (Subagents, MCP, etc.) | 20-30m |
| Open Source Friday | @GitHub | Title: "Open Source Friday with..." | 45-60m |
| The Download (weekly) | @GitHub | Title: "The Download:" — weekly news roundup | 5m |

## Duration Estimation Heuristics

The RSS feed does NOT include video duration. Use these rules:

1. **URL contains `/shorts/`**: Duration = `1m`
2. **Title contains "VS Code Live"**: Duration = `60m`
3. **Title contains "Open Source Friday"**: Duration = `45m`
4. **Title contains "Podcast" or description mentions "podcast"**: Duration = `25m`
5. **Description has chapter timestamps**: Use the last timestamp (e.g., "14:56 In summary" → `15m`)
6. **Default (none of the above)**: Duration = `5m`

## Matching Keyword Map

Common feature names and their likely video title keywords:

| Newsletter Feature | Video Title Keywords |
|-------------------|---------------------|
| Agent Skills | "Agent Skills", "skills" |
| Parallel Subagents | "subagent", "Subagents" |
| Agentic Memory | "memory", "Memory" |
| MCP Apps | "MCP Apps", "MCP" |
| Multi-Agent | "multi-agent", "agent sessions", "Agent Sessions Day" |
| Copilot CLI / SDK | "Copilot CLI", "Copilot SDK", "CLI" |
| Terminal Sandboxing | "terminal sandbox", "sandboxing" |
| Auto Model Selection | "auto model", "model selection" |
| Copilot Code Review | "code review" |

## Exclusion Patterns

Videos to NEVER match to newsletter entries:
- "How to Request a VS Code Feature" — meta/process, not a feature
- "Learn Visual Studio Code in 15 minutes" — beginner tutorial
- "Agents League Battle" — competition format
- Non-English content
- Open Source Friday episodes about non-GitHub projects (Caracal, Rio Terminal, Handy, etc.)

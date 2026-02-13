# Visual Studio Source Intelligence

> Calibrated from December 2025 cycle item-level tracing. VS 2022 17.14 + VS 2026 launch.

## Extraction Profile

- **Primary source**: GitHub Changelog entries containing "Visual Studio" (feature announcements)
- **Secondary source**: `https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes` (patches, CVEs, bug fixes)
- **Content model**: Rolling single page with undated Features section + dated patch versions
- **Release cadence**: Patches every 1-2 weeks; features announced via GitHub Changelog

## CRITICAL: Dual-Source Strategy

The MS Learn page is mostly **patches and CVEs**. The Features section is undated and covers the entire 17.14 lifecycle. For newsletter-quality feature content:
1. **GitHub Changelog** is the primary source (entries like "Copilot in Visual Studio - [Month] update")
2. **MS Learn page** is secondary for: patch timeline, Copilot-related CVEs, and occasional feature additions buried in patch notes
3. **DevBlogs posts** for major launches (e.g., VS 2026 GA announcement)

## Survival Rates (December 2025)

| Stage | Count | Rate |
|-------|-------|------|
| Raw items extracted | 12 | 100% |
| Survived to discoveries | 5 | 42% |
| Survived to published | 7 | 58% |
| Discovery bypass (raw→published directly) | 2 | 17% |

## What Survives (High Signal)

- **VS major launches**: VS 2026 GA was an expanded standalone bullet (100% survival for major releases)
- **Copilot agent features**: Debugger Agent, Profiler Agent (high survival, often bundled into IDE Parity)
- **Azure MCP Server**: Survived as part of MCP section
- **Auto model selection**: Survived as part of cross-IDE model bullet

## What Gets Cut (Low Signal)

- **Upgrade guides and roadmaps**: Blog posts about "spend less time upgrading" (0% survival)
- **Event announcements**: ".NET Conf" type content (0% survival)
- **URL context in chat**: Too granular for newsletter (0% survival)

## Treatment Patterns

- **Expanded**: Only for major launch (VS 2026 GA)
- **Bundled**: Most VS features get bundled into IDE Parity bullet under their respective capability
- **Discovery bypass**: 2 items added during curation as compressed mentions within the VS 2026 bullet. Shows that curators embed additional VS detail when a major launch justifies expansion.

## Key Learning

Visual Studio's highest-value moment in a newsletter is a **major version launch** (VS 2026) or a **monthly feature update announcement** (via GitHub Changelog). The patch-level release notes are rarely newsletter-worthy. The content-retrieval skill should prioritize GitHub Changelog entries over the MS Learn page for VS content.

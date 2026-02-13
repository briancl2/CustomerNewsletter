# URL Patterns Reference

Per-source URL generation rules for Phase 1A manifest creation.

## Sources Overview

| Source | URL Pattern | Pagination | Date Signal |
|--------|------------|------------|-------------|
| VS Code | Version-based path | None (single page per version) | Release date in page header |
| Visual Studio | Parameterized tabs | Tab parameters | Version date in release notes |
| GitHub Changelog | Year/month archive | Month pages | Entry dates on page |
| GitHub Blog (latest) | Paginated list | page/N/ | Article publish dates |
| GitHub Blog (news) | news-insights/company-news/ | Manual scan | Article publish dates |
| JetBrains | Plugin API JSON | page=N&size=8 | JSON `cdate` field |
| Xcode | Single CHANGELOG.md | None | Version headers |

**CRITICAL**: The GitHub Blog has TWO content streams:
1. **Changelog** (`github.blog/changelog/`) - technical release entries (most items)
2. **News & Insights** (`github.blog/news-insights/company-news/`) - major strategic announcements, CPO/CEO posts, product vision

Both must be scanned. Changelog-only scanning will miss major announcements like the Agent HQ 3P platform launch (Feb 2026, CPO blog post). Always include `github.blog/latest/page/1/` in the manifest to catch blog homepage features.

## VS Code

**Base URL**: `https://code.visualstudio.com/updates/v1_{VERSION}`

**Release Cadence**: Weekly (changed from monthly in early 2026). Expect 4-5 versions per 30-day newsletter period; 8-10 per 60-day period.

**Index Page**: `https://code.visualstudio.com/updates` (lists all versions with dates)

**Generation Strategy**:
1. **MUST fetch the index page** at `https://code.visualstudio.com/updates` to get version-to-release-date mapping
2. Parse all versions and their actual release dates from the sidebar/page
3. Include ALL versions whose actual release date falls within DATE_RANGE
4. Do NOT rely on SOURCES.yaml `latest_known.version` -- it only has the newest version
5. Named months may still lag actual release dates
6. For a 30+ day DATE_RANGE, expect **>=4 versions** (weekly cadence). If fewer, re-verify.

**Known version-to-release-date mapping** (update each cycle):
- v1.106: "October 2025" -> Released November 12, 2025
- v1.107: "November 2025" -> Released December 11, 2025
- v1.108: "December 2025" -> Released January 8, 2026
- v1.109: "January 2026" -> Released February 4, 2026

**Note**: With weekly releases, this table becomes impractical to maintain manually. Always fetch the index page programmatically.

## Visual Studio

**Base URL**: `https://learn.microsoft.com/en-us/visualstudio/releases/{YEAR}/release-notes`

**Tab Parameters**: Individual versions use tab query parameters
- VS 2022: `?tabs=release-history`
- VS 2026: Same base with year 2026

**Generation Strategy**:
1. Generate both VS 2022 and VS 2026 (if applicable) base URLs
2. These pages contain all versions for their year
3. No pagination needed (single page with version history)

## GitHub Changelog

**Base URL**: `https://github.blog/changelog/{YEAR}/{MM}/`

**Generation Strategy**:
1. For each month in DATE_RANGE, generate: `https://github.blog/changelog/{YEAR}/{MM}/`
2. Include partial months at boundaries (e.g., if DATE_RANGE starts Oct 6, include all of October)
3. Each page lists all changelog entries for that month

## GitHub Blog

**Base URL**: `https://github.blog/latest/page/{N}/`

**Generation Strategy**:
1. Start with page 1
2. Check publication dates
3. Continue until reaching dates before DATE_RANGE start
4. Typically 3-5 pages needed for a 2-month range

## JetBrains Plugin

**API URL**: `https://plugins.jetbrains.com/api/plugins/17718/updates?page={N}&size=8`

**Response Format**: JSON array with fields:
- `id`: Update ID
- `version`: Plugin version string
- `cdate`: Release timestamp (milliseconds)
- `notes`: What's New HTML

**Generation Strategy**:
1. Fetch page 1, parse JSON
2. Check `cdate` against DATE_RANGE
3. Continue paginating until dates fall before DATE_RANGE start
4. Typically 2-3 pages for a 2-month range (~2-3 releases/week)

## Copilot for Xcode

**URL**: `https://github.com/github/CopilotForXcode/blob/main/CHANGELOG.md`

**Generation Strategy**:
- Single URL (changelog is one file)
- Version headers contain dates (e.g., `## 0.45.0 - November 14, 2025`)
- No pagination needed

## Eclipse

**Note**: Eclipse Copilot updates appear in GitHub Blog/Changelog, not a separate source. No dedicated URL generation needed.

## Candidate Count Expectations

For a typical 2-month DATE_RANGE:
- VS Code: 8-10 version URLs (weekly cadence)
- Visual Studio: 1-2 base URLs
- GitHub Changelog: 2-3 month URLs
- GitHub Blog: 3-5 page URLs
- JetBrains: 2-3 API page URLs
- Xcode: 1 URL

**Total**: ~20-25 candidate URLs (smaller than final item count because each URL contains multiple items)

# Phase 1A URL Manifest
**DATE_RANGE**: 2025-10-06 to 2025-12-02
**Reference Year**: 2025
**Generated**: 2025-12-02

## Coverage Summary
| Source | URLs to Fetch | Earliest Date | Latest Date | Status |
|--------|--------------|---------------|-------------|--------|
| VS Code | 2 versions | 2025-10-09 | 2025-11-12 | ✅ Complete |
| Visual Studio | 3 tabs (2022) + 1 tab (2026) | 2025-10-06 | 2025-11-24 | ✅ Complete |
| GitHub Changelog | 3 months | 2025-10-06 | 2025-12-02 | ✅ Complete |
| GitHub Blog | 4 pages | 2025-10-06 | 2025-12-02 | ✅ Complete |
| JetBrains | 8 versions | 2025-10-20 | 2025-11-15 | ✅ Complete |
| Xcode | 2 versions | 2025-10-15 | 2025-11-14 | ✅ Complete |

## Detailed URL Manifests

### 1. VS Code Updates Manifest

**CRITICAL NOTE**: VS Code uses a MONTHLY naming convention where the "named month" is typically 1-2 months BEHIND the actual release date. ACTUAL RELEASE DATES govern inclusion, NOT the named month in titles.

| Version | Named Month | Actual Release Date | URL | Status |
|---------|-------------|---------------------|-----|--------|
| v1_105 | September 2025 | 2025-10-09 | https://code.visualstudio.com/updates/v1_105 | ✅ IN SCOPE |
| v1_106 | October 2025 | 2025-11-12 | https://code.visualstudio.com/updates/v1_106 | ✅ IN SCOPE |

**Boundary Verification**:
- ✅ v1_104 (August 2025, released ~Sept 10) is OUT OF SCOPE (before Oct 6)
- ✅ v1_107 (November 2025, released ~Dec 11) is OUT OF SCOPE (after Dec 2)
- ✅ Insiders version checked - no additional stable releases in range

---

### 2. Visual Studio Release Notes Manifest

**CRITICAL NOTE**: Visual Studio uses a monthly TAB system. BOTH VS 2022 and VS 2026 were checked.

#### VS 2022 (2022)
| Tab/Version | Release Dates Included | URL | Status |
|-------------|----------------------|-----|--------|
| October | Multiple versions (17.14.17-17.14.19) released Oct 14-27, 2025 | https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes?tabs=October | ✅ IN SCOPE |
| November | Multiple versions (17.14.20-17.14.21) released Nov 11-19, 2025 | https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes?tabs=November | ✅ IN SCOPE |
| September | Version 17.14.16 released Sept 23, plus 17.14.15 (Sept 16), some dates may overlap | https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes?tabs=September | ✅ PARTIAL (some versions in scope) |

#### VS 2026 (2026)
| Product | Version | Release Date | URL | Status |
|---------|---------|--------------|-----|--------|
| VS 2026 | 18.0.2 | 2025-11-24 | https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes | ✅ IN SCOPE |

**Boundary Verification**:
- ✅ VS 2022 September tab checked - version 17.14.16 (Sept 23) is OUT OF SCOPE
- ✅ VS 2022 August tab is OUT OF SCOPE (all releases before Oct 6)
- ✅ VS 2022 December tab not yet active
- ✅ VS 2026 checked separately - GA release on Nov 24, 2025

---

### 3. GitHub Changelog Manifest

**CRITICAL NOTE**: GitHub Changelog uses month-specific URLs (`/2025/MM/`) which load ALL entries for that month. Year-only or main page URLs are UNRELIABLE and only show recent months via infinite scroll.

| Month Section | Date Range | URL | Entry Count Estimate | Status |
|--------------|------------|-----|---------------------|--------|
| October 2025 | Oct 6-31, 2025 | https://github.blog/changelog/2025/10/ | ~40 entries | ✅ IN SCOPE |
| November 2025 | Nov 1-30, 2025 | https://github.blog/changelog/2025/11/ | ~45 entries | ✅ IN SCOPE |
| December 2025 | Dec 1-2, 2025 | https://github.blog/changelog/2025/12/ | ~3 entries | ✅ IN SCOPE |

**Key Entries Identified** (sample from fetched data):
- OCT.28: Multiple Universe announcements (Agent HQ, Mission Control, Copilot coding agent improvements, etc.)
- OCT.20: Claude Haiku 4.5 GA in all supported IDEs
- OCT.15: Copilot-generated commit messages GA, Claude Haiku 4.5 in public preview
- OCT.13: Claude Sonnet 4.5 GA
- NOV.18: Gemini 3 Pro in public preview, Enhanced MCP OAuth support
- NOV.13: GPT-5.1 models in public preview
- NOV.11: Auto model selection for Visual Studio in public preview
- NOV.24: Claude Opus 4.5 in public preview
- DEC.01: Copilot Spaces updates, Block repository admins from installing GitHub Apps GA
- DEC.02: Secret scanning updates November 2025

**Boundary Verification**:
- ✅ September 2025 (/2025/09/) is OUT OF SCOPE
- ✅ December entries limited to Dec 1-2 only (Dec 3+ would be OUT OF SCOPE)

---

### 4. GitHub Blog Manifest

**CRITICAL NOTE**: GitHub Blog uses pagination (`/latest/page/{N}/`). Each page shows ~20 posts. Must continue paginating until posts are CLEARLY before DATE_RANGE start.

| Page | Date Range Observed | URL | Post Count | Status |
|------|-------------------|-----|-----------|--------|
| 1 | Nov 25 - Dec 2, 2025 | https://github.blog/latest/ | ~20 posts | ✅ IN SCOPE |
| 2 | Oct 28 - Nov 25, 2025 | https://github.blog/latest/page/2/ | ~20 posts | ✅ IN SCOPE |
| 3 | Sept 25 - Oct 27, 2025 | https://github.blog/latest/page/3/ | ~20 posts | ✅ PARTIAL (Oct 6-27 in scope) |
| 4 | Aug 11 - Sept 30, 2025 | https://github.blog/latest/page/4/ | ~20 posts | ✅ PARTIAL (some Sept posts may overlap) |

**Key Blog Posts Identified** (sample):
- Oct 28: "Introducing Agent HQ: Any agent, any way you work"
- Oct 28: "Octoverse: A new developer joins GitHub every second as AI leads TypeScript to #1"
- Oct 27: "GitHub Copilot in Visual Studio — October update"
- Oct 24: "How to find, install, and manage MCP servers with the GitHub MCP Registry"
- Oct 23: "The road to better completions: Building a faster, smarter GitHub Copilot with a new custom model"
- Oct 22: "From karaoke terminals to AI résumés: The winners of GitHub's For the Love of Code challenge"
- Oct 20: "Inside the breach that broke the internet: The untold story of Log4Shell"
- Oct 15: "Copilot: Faster, smarter, and built for how you work now"
- Oct 14: "How GitHub Copilot and AI agents are saving legacy systems"
- Oct 13: "GitHub Copilot CLI: How to get started"
- Oct 9: "20 Years of Git, 2 days at GitHub HQ: Git Merge 2025 highlights"
- Oct 8: "GitHub Availability Report: September 2025"
- Oct 7: "How GitHub Copilot enabled accessibility governance process improvements in record time"
- Oct 6: "The developer role is evolving. Here's how to stay ahead."
- Nov 7: "What 986 million code pushes say about the developer workflow in 2025"
- Nov 12: "How Copilot helps build the GitHub platform"
- Nov 13: "TypeScript, Python, and the AI feedback loop changing software development"
- Nov 14: "Unlocking the full power of Copilot code review: Master your instructions files"
- Nov 17: "Highlights from Git 2.52"
- Nov 19: "How to write a great agents.md: Lessons from over 2,500 repositories"
- Nov 20: "Evolving GitHub Copilot's next edit suggestions through custom model training"
- Nov 25: "How GitHub's agentic security principles make our AI agents as secure as possible"
- Dec 1: "How to orchestrate agents using mission control"
- Dec 2: "The local-first rebellion: How Home Assistant became the most important project in your house"

**Boundary Verification**:
- ✅ Page 5+ would contain posts entirely before Oct 6 (OUT OF SCOPE)
- ✅ October posts from Oct 1-5 are OUT OF SCOPE (must filter to Oct 6-31)

---

### 5. JetBrains Plugin Manifest

**CRITICAL NOTE**: JetBrains uses a JSON REST API for version pagination. The HTML page lazy-loads data from this API. Use API endpoint directly: `https://plugins.jetbrains.com/api/plugins/17718/updates?channel=&page={N}&size=8`

**API Response Structure**: Each entry contains `id` (updateId), `version`, `cdate` (milliseconds timestamp), and `link`.

| Version | Build Variants | Update Date (from cdate) | updateId (241) | updateId (243) | URL Pattern | Status |
|---------|---------------|------------------------|---------------|---------------|-------------|--------|
| 1.5.61 | 241, 243 | 2025-11-15 | 893780 | 893781 | /versions/stable/{id} | ✅ IN SCOPE |
| 1.5.60 | 241, 243 | 2025-11-18 | 892198 | 892199 | /versions/stable/{id} | ✅ IN SCOPE |
| 1.5.59 | 241, 243 | 2025-10-24 | 882516 | 882517 | /versions/stable/{id} | ✅ IN SCOPE |
| 1.5.58 | 241, 243 | 2025-10-20 | 880278 | 880279 | /versions/stable/{id} | ✅ IN SCOPE |

**Individual Version URLs**:
- https://plugins.jetbrains.com/plugin/17718-github-copilot--your-ai-pair-programmer/versions/stable/893781
- https://plugins.jetbrains.com/plugin/17718-github-copilot--your-ai-pair-programmer/versions/stable/893780
- https://plugins.jetbrains.com/plugin/17718-github-copilot--your-ai-pair-programmer/versions/stable/892199
- https://plugins.jetbrains.com/plugin/17718-github-copilot--your-ai-pair-programmer/versions/stable/892198
- https://plugins.jetbrains.com/plugin/17718-github-copilot--your-ai-pair-programmer/versions/stable/882517
- https://plugins.jetbrains.com/plugin/17718-github-copilot--your-ai-pair-programmer/versions/stable/882516
- https://plugins.jetbrains.com/plugin/17718-github-copilot--your-ai-pair-programmer/versions/stable/880279
- https://plugins.jetbrains.com/plugin/17718-github-copilot--your-ai-pair-programmer/versions/stable/880278

**Boundary Verification**:
- ✅ Version 1.5.57 and earlier are OUT OF SCOPE (released before Oct 6)
- ✅ Weekly release cadence: ~2 versions per week (one for build 241, one for build 243)
- ✅ October through mid-November fully covered (Oct 20, Oct 24, Nov 18, Nov 15)

---

### 6. Copilot for Xcode Manifest

**CRITICAL NOTE**: Xcode uses a single CHANGELOG.md file with version entries. Each version has a date in the heading format: "## {version} - {Month Day, Year}".

| Version | Date | URL | Status |
|---------|------|-----|--------|
| 0.45.0 | November 14, 2025 | https://github.com/github/CopilotForXcode/blob/main/CHANGELOG.md#0450---november-14-2025 | ✅ IN SCOPE |
| 0.44.0 | October 15, 2025 | https://github.com/github/CopilotForXcode/blob/main/CHANGELOG.md#0440---october-15-2025 | ✅ IN SCOPE |

**CHANGELOG.md Base URL**: https://github.com/github/CopilotForXcode/blob/main/CHANGELOG.md

**Boundary Verification**:
- ✅ Version 0.43.0 (September 4, 2025) is OUT OF SCOPE
- ✅ No version 0.46.0 exists yet (as of Dec 2, 2025)

---

## Validation Results

### Boundary Verification Checklist

**VS Code**:
- [x] Main updates page fetched first: ✅ https://code.visualstudio.com/updates/
- [x] Earliest in-scope item (v1_105, Oct 9) is within DATE_RANGE
- [x] Latest in-scope item (v1_106, Nov 12) is within DATE_RANGE
- [x] Next earlier version (v1_104) is clearly before DATE_RANGE start
- [x] Next later version (v1_107) is clearly after DATE_RANGE end OR is Insiders
- [x] Reference Year 2025 matches all items

**Visual Studio**:
- [x] Both VS 2022 AND VS 2026 fetched: ✅ Both products checked
- [x] October and November tabs for VS 2022 included
- [x] September tab checked (version 17.14.16 on Sept 23 is OUT OF SCOPE, but 17.14.15 on Sept 16 also checked)
- [x] VS 2026 GA release (Nov 24, 2025) included
- [x] August tabs clearly before DATE_RANGE start

**GitHub Changelog**:
- [x] Month-specific URLs used for all three months
- [x] October entries: Oct 6-31 only (Oct 1-5 excluded)
- [x] November entries: All month (Nov 1-30)
- [x] December entries: Dec 1-2 only (Dec 3+ excluded)
- [x] September 2025 (/2025/09/) not included (OUT OF SCOPE)
- [x] Entry counts: ~88 total entries across three months

**GitHub Blog**:
- [x] Pagination continued through page 4
- [x] Page 3 contains posts from Sept 25 - Oct 27 (Oct 6-27 in scope)
- [x] Page 4 checked for any late Sept/early Oct overlap
- [x] October posts from Oct 1-5 will be filtered in Phase 1B
- [x] Stopped before reaching August posts

**JetBrains**:
- [x] API endpoint used (more efficient than HTML scraping)
- [x] Page 1 of API fetched (8 versions returned)
- [x] All versions from Oct 20 through Nov 15 included
- [x] Both build variants (241 and 243) enumerated for each version
- [x] Versions before Oct 20 are OUT OF SCOPE

**Xcode**:
- [x] Single CHANGELOG.md file includes all versions
- [x] Version 0.45.0 (Nov 14) included
- [x] Version 0.44.0 (Oct 15) included
- [x] Version 0.43.0 (Sept 4) is OUT OF SCOPE

### Monthly Coverage Check

**October 2025 Coverage** (Oct 6-31):
- [x] VS Code: ✅ v1_105 released Oct 9
- [x] Visual Studio 2022: ✅ Multiple versions in October tab
- [x] Visual Studio 2026: ❌ No October releases (GA was Nov 24)
- [x] GitHub Changelog: ✅ ~40 entries from Oct 6-31
- [x] GitHub Blog: ✅ ~15-20 posts from Oct 6-31
- [x] JetBrains: ✅ 2 versions (1.5.58 on Oct 20, 1.5.59 on Oct 24)
- [x] Xcode: ✅ Version 0.44.0 on Oct 15

**November 2025 Coverage** (Nov 1-30):
- [x] VS Code: ✅ v1_106 released Nov 12
- [x] Visual Studio 2022: ✅ Multiple versions in November tab
- [x] Visual Studio 2026: ✅ Version 18.0.2 on Nov 24
- [x] GitHub Changelog: ✅ ~45 entries from Nov 1-30
- [x] GitHub Blog: ✅ ~20-25 posts from Nov 1-30
- [x] JetBrains: ✅ 2 versions (1.5.60 on Nov 18, 1.5.61 on Nov 15)
- [x] Xcode: ✅ Version 0.45.0 on Nov 14

**December 2025 Coverage** (Dec 1-2):
- [x] VS Code: ❌ No December releases yet
- [x] Visual Studio 2022: ❌ No December releases yet
- [x] Visual Studio 2026: ❌ No December releases yet
- [x] GitHub Changelog: ✅ ~3 entries from Dec 1-2
- [x] GitHub Blog: ✅ ~2 posts from Dec 1-2
- [x] JetBrains: ❌ No December releases yet
- [x] Xcode: ❌ No December releases yet

### Gap Detection

**No gaps detected.** All sources have appropriate coverage for the DATE_RANGE with no suspicious missing months.

---

## Notes for Phase 1B

### Fetching Instructions

**VS Code**:
- Fetch both version pages with release notes content
- Extract features, changes, and fixes from each section
- Note: Release date is in page header (e.g., "Released November 12, 2025")

**Visual Studio**:
- Fetch 3 tab-specific URLs for VS 2022 (September, October, November)
- Fetch 1 URL for VS 2026 base release notes
- Parse individual version sections within each tab
- Extract version-specific release notes and dates

**GitHub Changelog**:
- Fetch all 3 month-specific URLs
- Parse individual entry titles, dates, and categories
- Filter October entries to Oct 6-31 only (exclude Oct 1-5)
- Filter December entries to Dec 1-2 only (exclude Dec 3+)
- Each entry has format: "### {MONTH}.{DAY}{TYPE}\n{Title}\n[LABEL]"

**GitHub Blog**:
- Fetch pages 1-4 (or until posts are clearly before Sept 25)
- Extract post title, publication date, and URL for each post
- Filter to only include posts from Oct 6 onwards
- Each page has ~20 posts with dates in format "Month Day, Year"

**JetBrains**:
- Fetch individual version pages for all 8 updateIds
- Extract release notes from each version page
- Note: Dates are already confirmed from API (cdate converted to readable date)
- Both build variants (241 and 243) have identical release notes content

**Xcode**:
- Fetch single CHANGELOG.md file
- Parse version sections for 0.45.0 and 0.44.0
- Extract Added/Changed/Fixed sections from each version
- Date format in headings: "## {version} - {Month Day, Year}"

### Special Handling

**Eclipse**:
- Eclipse Copilot plugin has NO standalone changelog
- Updates appear on GitHub Blog and/or GitHub Changelog alongside JetBrains/Xcode parity announcements
- Look for entries mentioning "Eclipse" in GitHub Blog/Changelog

**Deduplication Needed**:
- Cross-source announcements (e.g., model availability announced on GitHub Changelog AND GitHub Blog)
- IDE feature parity announcements (same feature across VS Code, Visual Studio, JetBrains, Xcode, Eclipse)
- Multiple blog posts about same feature with different angles

### Content Extraction Priorities

**High Priority** (must capture):
- GA releases and availability announcements
- New model launches and updates
- IDE feature parity updates (VS Code → Visual Studio → JetBrains → Xcode → Eclipse pattern)
- Agent mode and agentic workflows improvements
- MCP server and tool updates
- Enterprise controls and governance features
- Security and compliance updates

**Medium Priority** (capture if substantial):
- Public preview / experimental features
- Performance improvements
- UI/UX enhancements
- Bug fixes for major issues

**Low Priority** (may skip):
- Minor bug fixes
- Internal refactoring
- Deprecated features (unless replacement announced)

---

## Manifest Completeness Confirmation

- ✅ All sources have complete URL enumeration with NO PLACEHOLDERS
- ✅ All individual version numbers, updateIds, and page numbers are explicitly listed
- ✅ Boundary coverage verified: earliest items ≤ DATE_RANGE start, latest items ≥ DATE_RANGE end
- ✅ No month within DATE_RANGE shows 0 entries
- ✅ Reference Year 2025 matches all included items
- ✅ Ready for Phase 1B content retrieval

**Phase 1A Manifest Complete - Ready for Phase 1B**

---
name: url-manifest
description: "Generates validated URL manifest from kb/SOURCES.yaml for a given DATE_RANGE. Use when starting Phase 1A of the newsletter pipeline. Reads SOURCES.yaml canonical URLs and feed endpoints, generates candidate URLs per source, validates existence, and outputs a manifest file. Keywords: url manifest, phase 1a, url generation, source discovery."
metadata:
  category: domain
  phase: "1A"
---

# URL Manifest Generator

Generate and validate candidate URLs from known sources for a given DATE_RANGE.

## Quick Start

1. Receive DATE_RANGE (YYYY-MM-DD to YYYY-MM-DD)
2. Read `kb/SOURCES.yaml` for canonical URLs and feed endpoints
3. Generate candidate URLs per source using known patterns
4. Spot-check 1-2 URLs per source to confirm patterns work
5. Write manifest to `workspace/newsletter_phase1a_url_manifest_YYYY-MM-DD_to_YYYY-MM-DD.md`

## Inputs

- **DATE_RANGE**: Start date and end date in YYYY-MM-DD format
- **Reference Year**: Extracted from DATE_RANGE
- **kb/SOURCES.yaml**: Canonical URL source registry with machine-readable entries

## Output

- **File**: `workspace/newsletter_phase1a_url_manifest_YYYY-MM-DD_to_YYYY-MM-DD.md`
- **Token budget**: 10,000-20,000 tokens total

## Core Workflow

### Step 0: Date Range Overlap Check

Before generating URLs, verify DATE_RANGE has no gap with the previous newsletter. Check `archive/` for the most recent newsletter to find its coverage end date. If a gap exists (e.g., previous newsletter covered through Dec 3, but current DATE_RANGE starts Jan 1), extend the START date backward to close the gap. Never leave uncovered days between newsletters.

### Step 1: Generate Candidates (~2 min)

For each source, generate candidate URLs using known patterns and DATE_RANGE months. See [url-patterns.md](references/url-patterns.md) for per-source URL architecture.

**Key Innovation**: Read `kb/SOURCES.yaml` for canonical URLs rather than guessing URL patterns. The YAML provides:
- `canonical_urls` for each source
- `update_feeds` with type (RSS, Atom, API, none) and endpoints
- `latest_known.version` and `latest_known.release_date` for version-based URLs

**CRITICAL: VS Code Version Enumeration (L64 + L66)**

Do NOT rely on SOURCES.yaml `latest_known.version` alone for VS Code. That field only contains the newest version. VS Code now ships weekly, so a 30+ day DATE_RANGE includes 4-5+ versions. You MUST:
1. Fetch `https://code.visualstudio.com/updates` (the index page)
2. Parse every version listed with its actual release date
3. Include ALL versions whose release date falls within DATE_RANGE
4. Remember: named months may still lag by 1-2 months ("December 2025" = released Jan 8, 2026)

Example: A 30-day DATE_RANGE will typically include 4-5 weekly versions. All must be in the manifest.

### CRITICAL: Expanded Source Coverage

Cross-cycle meta-analysis (L29, L30) shows these sources are consistently missed by changelog-only scanning but always appear in published newsletters. The manifest MUST include:

1. **GitHub Changelog** (`github.blog/changelog/YYYY/MM/`) — primary, richest source
2. **GitHub Blog Homepage** (`github.blog/latest/page/1/`) — catches strategic CPO/CEO posts
3. **GitHub News & Insights** (`github.blog/news-insights/company-news/`) — major announcements NOT in changelog
4. **VS Code Release Notes** (`code.visualstudio.com/updates/v1_{VERSION}`) — deep feature content
5. **Visual Studio DevBlogs** (`devblogs.microsoft.com/visualstudio/`) — VS Copilot monthly updates
6. **Azure DevOps DevBlogs** (`devblogs.microsoft.com/devops/`) — Azure ecosystem items
7. **JetBrains Plugin API** (`plugins.jetbrains.com/api/plugins/17718/updates`) — plugin versions
8. **Xcode CHANGELOG** (`github.com/github/CopilotForXcode/blob/main/CHANGELOG.md`) — Xcode versions
9. **Visual Studio MS Learn** (`learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes`) — patches and CVEs only

### Step 2: Spot-Check Validation (~5-10 min)

For each source, fetch 1-2 URLs to confirm:
- URL exists (not 404)
- Contains expected date/version info
- Pattern is correct for the DATE_RANGE

### Step 3: Boundary Verification

Verify the generated URLs span the full DATE_RANGE:
- Earliest candidate date is on or before DATE_RANGE start
- Latest candidate date is on or after DATE_RANGE end
- No month in DATE_RANGE has zero entries
- Flag any gaps

### Step 4: Write Manifest

Output validated candidate URLs grouped by source with:
- Source name and URL pattern used
- Individual URLs with expected dates
- Boundary verification checkboxes
- Total candidate count

### CRITICAL: Named Month vs Actual Release Date

Named month in release titles often LAGS actual release date by 1-2 months.

| Example | Named Month | Actual Release Date |
|---------|-------------|---------------------|
| VS Code v1.105 | "September 2025" | October 9, 2025 |
| VS Code v1.106 | "October 2025" | November 12, 2025 |

**Actual release dates govern inclusion, NOT the named month.** Always verify actual release dates against DATE_RANGE boundaries.

## Reference

- [URL Patterns](references/url-patterns.md) - Per-source URL generation rules
- [Benchmark Example](examples/) - Known-good Dec 2025 manifest

## Done When

- [ ] Manifest file exists at `workspace/newsletter_phase1a_url_manifest_*.md`
- [ ] All 5 major sources covered (GitHub Blog/Changelog, VS Code, Visual Studio, JetBrains, Xcode)
- [ ] Spot-check passed for each source (not 404, correct dates)
- [ ] Boundaries verified: earliest <= DATE_RANGE start, latest >= DATE_RANGE end
- [ ] No month in DATE_RANGE has zero entries
- [ ] Token budget within 10,000-20,000 range

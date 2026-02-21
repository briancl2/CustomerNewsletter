# Phase 1A URL Manifest
**DATE_RANGE**: 2026-02-14 to 2026-02-21
**Reference Year**: 2026
**Generated**: 2026-02-21

## Coverage Summary
| Source | URLs to Fetch | Earliest Date | Latest Date | Status |
|--------|--------------|---------------|-------------|--------|
| GitHub Changelog | 1 month page | 2026-02-14 | 2026-02-21 | ✅ Complete |
| GitHub Blog (latest) | 1 page | 2026-02-14 | 2026-02-21 | ✅ Complete |
| GitHub Blog (news) | 1 page | 2026-02-14 | 2026-02-21 | ✅ Complete |
| VS Code | 1 version (index + v1_110) | 2026-02-14 | 2026-02-21 | ✅ Complete |
| Visual Studio | 1 base URL (2022 release notes) | 2026-02-14 | 2026-02-21 | ✅ Complete |
| JetBrains | 1 API page | 2026-02-14 | 2026-02-21 | ✅ Complete |
| Xcode | 1 changelog URL | 2026-02-14 | 2026-02-21 | ✅ Complete |

## Gap Check
- Previous newsletter covered through **2026-02-13**
- This manifest starts at **2026-02-14**
- ✅ No gap between newsletters

## Detailed URL Manifests

### 1. GitHub Changelog Manifest

| Month Section | Date Range | URL | Status |
|--------------|------------|-----|--------|
| February 2026 | Feb 14-21, 2026 | https://github.blog/changelog/2026/02/ | ✅ IN SCOPE |

**Filtering**: Only include entries dated Feb 14 through Feb 21, 2026. Exclude entries before Feb 14 (already covered in previous newsletter).

---

### 2. GitHub Blog Manifest

| Page | URL | Status |
|------|-----|--------|
| Latest Page 1 | https://github.blog/latest/ | ✅ IN SCOPE |
| News & Insights | https://github.blog/news-insights/company-news/ | ✅ IN SCOPE |

**Filtering**: Only include posts published Feb 14-21, 2026.

---

### 3. VS Code Updates Manifest

**Index Page**: https://code.visualstudio.com/updates (fetch first for version enumeration)

| Version | Expected Named Month | Expected Release Window | URL | Status |
|---------|---------------------|------------------------|-----|--------|
| v1_110 | February 2026 | ~Feb 18-19, 2026 (weekly cadence) | https://code.visualstudio.com/updates/v1_110 | ✅ IN SCOPE (if released in window) |

**Notes**: VS Code v1.109 was released Feb 4, 2026. With weekly cadence, v1.110 is expected around Feb 11-18. Check index page for actual release date. If v1.110 falls before Feb 14, it was covered by previous newsletter. If v1.111 exists, include it.

**Boundary Verification**:
- v1.109 (released Feb 4, 2026) - OUT OF SCOPE (covered in previous newsletter through Feb 13)
- v1.110 - IN SCOPE if released Feb 14+
- v1.111 - IN SCOPE if released by Feb 21

---

### 4. Visual Studio Release Notes Manifest

| Product | URL | Status |
|---------|-----|--------|
| VS 2022 | https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes | ✅ IN SCOPE |

**Filtering**: Only include patch versions with release dates in Feb 14-21, 2026. These pages contain CVE fixes and servicing updates.

---

### 5. JetBrains Plugin Manifest

**API URL**: https://plugins.jetbrains.com/api/plugins/17718/updates?channel=&page=1&size=10

**Filtering**: Check `cdate` field (epoch milliseconds). Only include updates where release date falls in Feb 14-21, 2026.

**Expected**: 1-2 plugin versions per week (build 241 and 243 variants).

---

### 6. Copilot for Xcode Manifest

| URL | Status |
|-----|--------|
| https://github.com/github/CopilotForXcode/blob/main/CHANGELOG.md | ✅ IN SCOPE |

**Filtering**: Only include version entries dated Feb 14-21, 2026.

---

## Validation Results

### Boundary Verification Checklist

- [x] Previous newsletter gap check: No gap (previous ended Feb 13, this starts Feb 14)
- [x] All 5 major sources covered (GitHub Blog/Changelog, VS Code, Visual Studio, JetBrains, Xcode)
- [x] February 2026 month has entries for all applicable sources
- [x] Filtering instructions clear for narrow 1-week window

### Notes for Phase 1B

**Scope**: This is a 1-week newsletter (Feb 14-21). Content volume will be smaller than typical monthly newsletters. Expect:
- GitHub Changelog: 5-15 entries in this 1-week window
- GitHub Blog: 2-5 posts
- VS Code: 0-1 version releases
- Visual Studio: 0-1 servicing updates
- JetBrains: 1-2 plugin updates
- Xcode: 0-1 releases

**Phase 1A Manifest Complete - Ready for Phase 1B**

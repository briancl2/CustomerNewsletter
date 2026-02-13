# KB Changelog

## 2026-02-10 (Sprint: Pipeline Hardening)

- Added 3 new sources to SOURCES.yaml per cross-cycle gap analysis (L19, L29, L30):
  - `vs_devblogs`: devblogs.microsoft.com/visualstudio/ (VS feature content gap)
  - `azure_devops_devblogs`: devblogs.microsoft.com/devops/ (Azure ecosystem gap)
  - `gh_blog_news_insights`: github.blog/news-insights/ (strategic announcements gap)
- Expanded SOURCES.yaml from 69 to 72 records.

## 2026-02-10

- Initial build of canonical Copilot sources-of-truth KB.
- Added full section set (`A-D`), taxonomy, runbook, research method, and current-state snapshot.
- Added `SOURCES.yaml` with 62 deduplicated source records and machine-readable feed metadata.
- Completed link-health validation (`67/68` URLs passing, one known Eclipse update-site 404).
- Captured portability policy (`.agents/skills` default) and platform-specific exception handling.
- Patched KB after comparative audit:
  - Added missing canonical sources for custom instructions support, response customization, prompt files, legacy metrics API retirement, Copilot usage metrics, and OpenCode support announcement.
  - Updated OpenCode classification to an officially Copilot-supported external surface with community-managed release channels.
  - Updated maintenance method/checklists for deprecation and customization-source sweeps.
  - Expanded `SOURCES.yaml` from 62 to 69 records.
  - Re-ran canonical URL health checks after patch (`75/76` URLs passing, one known Eclipse update-site 404).

---
name: kb-maintenance
description: "Maintains kb/ knowledge base through automated polling and health checks. Use for monthly kb/ refresh, link health validation, and SOURCES.yaml updates. Polls RSS/Atom feeds for new content, validates canonical URLs, generates delta reports. Keywords: kb maintenance, knowledge base, link health, sources refresh, monthly maintenance."
metadata:
  category: domain
  phase: utility
---

# KB Maintenance

Keep the knowledge base current through automated polling and health checks.

## Quick Start

1. Poll feeds: `python3 .github/skills/kb-maintenance/scripts/poll_sources.py [--dry-run]`
2. Check links: `python3 .github/skills/kb-maintenance/scripts/check_link_health.py [--dry-run] [--sample N]`
3. Review delta report and fix broken links
4. Update `kb/SOURCES.yaml` and `kb/CURRENT_STATE_SNAPSHOT.md`

## Inputs

- **kb/SOURCES.yaml**: Primary data source (47 entries with canonical URLs and feeds)
- **kb/CURRENT_STATE_SNAPSHOT.md**: Current state documentation

## Output

- Delta report: what's new since last poll
- Health report: broken links, redirects, status changes
- Updated SOURCES.yaml (if fixes needed)

## Core Workflow

### Monthly Maintenance Cycle

1. **Poll feeds** - Read SOURCES.yaml `update_feeds`, fetch RSS/Atom/API endpoints, identify new entries since `last_checked` date
2. **Check link health** - Validate `canonical_urls` and `latest_known.reference_url`, report dead links and redirects
3. **Generate delta report** - What's new, what's broken, what needs manual review
4. **Update sources** - Fix broken URLs, update `last_checked`, add new sources if discovered
5. **Update snapshot** - Refresh `CURRENT_STATE_SNAPSHOT.md` with current state

### Feed Types

| Type | How to Poll | Example |
|------|------------|---------|
| RSS/Atom | Fetch XML, parse entries after `last_checked` | GitHub Blog RSS |
| API | Fetch JSON, filter by date | JetBrains plugin API |
| none | Manual check required | Docs pages (no feed) |

See [maintenance-procedure.md](references/maintenance-procedure.md) for full workflow details.

## Scripts

- [poll_sources.py](scripts/poll_sources.py) - Poll RSS/Atom feeds, emit delta report
- [check_link_health.py](scripts/check_link_health.py) - Validate URLs, emit health report

## Reference

- [Maintenance Procedure](references/maintenance-procedure.md) - Monthly workflow, feed types, cadence

## Done When

- [ ] Feed polling completed (or --dry-run passed)
- [ ] Link health check completed (or --dry-run passed)
- [ ] Delta report generated
- [ ] Broken links documented
- [ ] SOURCES.yaml updated with `last_checked` dates

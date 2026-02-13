# KB Index

## State Header

- **AS_OF_DATE:** 2026-02-10
- **LAST_RUN_DATE:** 2026-02-10

## Purpose

This knowledge base documents canonical "sources of truth" for GitHub Copilot across major surfaces, then layers portable best practices for agentic software delivery.

## Primary Audiences

- Engineering enablement teams
- Developer productivity/platform teams
- AI governance and security stakeholders
- Technical writers and internal newsletter/program owners

## How to Use This KB

1. Start with `CURRENT_STATE_SNAPSHOT.md` for current release/changes.
2. Use `SECTION_A_PRIMARY_PLATFORMS.md` for canonical docs/changelog/feed locations.
3. Use `SECTION_C_BEST_PRACTICES.md` for reusable, portable delivery patterns.
4. Use `SOURCES.yaml` for machine-readable automation and monthly polling.

## Definitions

- **Source of truth:** the most authoritative, first-party location for a fact.
- **Surface:** where Copilot functionality is delivered (for example VS Code, Visual Studio, GitHub.com).
- **Canonical source:** official vendor-owned doc, changelog, release note, API, or feed.
- **Secondary source:** community or practitioner source; useful but non-authoritative.
- **Feed:** machine-readable update endpoint (RSS, Atom, API, releases feed).

## Sections

- `TAXONOMY.md`
- `SECTION_A_PRIMARY_PLATFORMS.md`
- `SECTION_B_FRAMEWORKS.md`
- `SECTION_C_BEST_PRACTICES.md`
- `SECTION_D_THOUGHT_LEADERSHIP.md`
- `CURRENT_STATE_SNAPSHOT.md`
- `MAINTENANCE_RUNBOOK.md`
- `RESEARCH_METHOD.md`
- `RUN_LOG_2026-02-10.md`
- `CHANGELOG.md`
- `SOURCES.yaml`

## Governance Rules

### Inclusion Criteria

- Prefer first-party vendor docs/release/changelog/feed sources.
- Include community sources only when operationally concrete and clearly labeled.
- Include only sources with clear Copilot or Copilot-adjacent workflow relevance.

### Canonical vs Secondary

- Every platform/source entry should include at least one canonical URL.
- Secondary/practitioner sources are explicitly tagged in taxonomy and `SOURCES.yaml`.

### Deprecations and Migrations

- Keep deprecated items in the KB until at least one full monthly cycle confirms replacement stability.
- Mark deprecated sources and preserve migration path notes.

### Dedupe Policy

- One source record per unique source stream.
- Aggregate related URLs in `canonical_urls`.
- Do not duplicate entries for the same feed under multiple names.

## Portability Policy Summary

- Portable-first is mandatory for reusable assets.
- Default reusable location: `.agents/skills`.
- Platform-specific conventions are documented as explicit exceptions.
- `.github/instructions` is treated in this KB as a **legacy platform-specific pattern** for historical compatibility context only; reusable guidance defaults to `.agents/skills`.

## Operational Pointers

- Monthly process: `MAINTENANCE_RUNBOOK.md`
- Method and canonicality checks: `RESEARCH_METHOD.md`

## Gaps and Unknowns

- **OpenCode source-of-truth split:** GitHub Changelog confirms Copilot support for OpenCode, but OpenCode version/distribution truth still lives in community-managed channels (`opencode.ai`, `anomalyco/opencode`).
- **Eclipse update site health:** the update site URL listed in GitHub Docs (`https://azuredownloads-g3ahgwb5b8bkbxhd.b01.azurefd.net/github-copilot/`) returned HTTP 404 on 2026-02-10.
- **Feature matrix lag:** matrix "latest releases" values can lag behind marketplace/release channels for some surfaces.
- **AgentOS naming collision:** multiple projects share the name; this KB records both with disambiguation.
- **Prompt file support drift risk:** prompt files are public preview and support can change by IDE/client.

### Recommended Next Iteration Goals

1. Automate feed polling from `SOURCES.yaml` into a delta report generator.
2. Add a matrix-drift detector that compares feature matrix versions vs marketplace/release latests.
3. Add optional signed URL checks and per-source SLA tracking for link health.
4. Add automatic deprecation/retirement scanners for changelog keywords and metrics API sunset notices.

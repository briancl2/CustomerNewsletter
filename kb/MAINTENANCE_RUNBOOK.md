# Maintenance Runbook

## Purpose

Repeatable monthly refresh process for this knowledge base.

## Frequency

- Monthly minimum
- Additional run after major Copilot announcements or policy shifts

## Monthly Refresh Procedure

1. **Update run date**
   - Set `LAST_RUN_DATE` in `SOURCES.yaml`, `KB_INDEX.md`, and `CURRENT_STATE_SNAPSHOT.md`.
2. **Poll all update feeds and canonical release streams**
   - Iterate every `update_feeds` entry in `SOURCES.yaml`.
   - Check Copilot changelog RSS, GitHub release atoms, marketplace/API endpoints, and primary release note pages.
3. **Update `CURRENT_STATE_SNAPSHOT.md`**
   - Record latest version/date/reference per major surface.
   - Add "what changed" bullets for meaningful deltas.
   - If no meaningful change, write "no material change noted."
4. **Maintain source catalog**
   - Add new canonical sources as they appear.
   - Retire dead links or mark deprecated with notes.
   - Update `latest_known` and `last_checked` fields.
5. **Update `CHANGELOG.md`**
   - Add dated KB update summary.
6. **Run validation checklist**
   - Execute and record pass/fail results in the new run log.

## Detection Checklist (New Surfaces / New Streams)

1. Review Copilot feature matrix for new rows/features:
   - https://docs.github.com/en/copilot/reference/copilot-feature-matrix
2. Check GitHub Docs search for new "Copilot in <surface>" pages.
3. Scan Copilot changelog RSS for new product/surface labels.
4. Scan changelog entries for keywords: `deprecated`, `retired`, `sunset`, `closing down notice`.
5. Re-check customization sources for support/behavior changes:
   - `custom-instructions-support`
   - `response-customization`
   - `prompt-files` guidance
6. Check `what-is-github-copilot` docs page for newly listed interfaces.
7. Validate marketplace listings and release repos for new official integrations.
8. Check policy/legal pages for source-of-truth location changes:
   - https://github.com/features/preview
   - https://github.com/customer-terms/updates

## Validation Checklist

- **Completeness:** Section A includes all substantiated Copilot surfaces from official docs/changelog.
- **Canonicality:** each entry has at least one official canonical URL, or explicit community/practitioner labeling.
- **Feeds:** RSS/Atom/GitHub releases feed/API included when available.
- **Dedupe:** no duplicate source records for same stream.
- **Portability:** portable guidance first; exceptions explicitly labeled.
- **Matrix linkage:** feature matrix referenced; major feature areas mapped to docs/updates.
- **Link health:** canonical URLs resolve; failures captured in run log.

## Suggested Automation Pattern

1. Load `SOURCES.yaml`.
2. Poll each source feed/API.
3. Compare with previous snapshot values.
4. Emit `delta.json` and human-readable markdown summary.
5. Open PR with updated snapshot, run log, and changelog.

## Escalation Rules

- If a canonical source disappears unexpectedly, mark source `stability: low` and open investigation issue.
- If legal/policy URLs change, prioritize updates to Section A and KB governance sections.
- If matrix and platform release channels diverge repeatedly, add explicit drift notes and treat platform release channel as current-state source.

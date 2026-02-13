---
name: deprecation-consolidation
description: "Consolidates all deprecation, sunset, revocation, and migration-notice content into a single bundled update under Enterprise and Security Updates, and removes any standalone Migration Notices section. Use when assembling or polishing a newsletter, or when you see duplicated deprecation notes across multiple sections (models, metrics, runner enforcement, token revocations, syntax changes). Keywords: deprecation, deprecated, sunset, migration notice, breaking change, enforcement, revoked, revocation, end-of-life, EOL, retiring."
metadata:
  category: domain
  phase: "4.5"
---

# Deprecation Consolidation

Ensure deprecations and migration notices are **not duplicated** across the newsletter and are **presented once** in the right place.

## Quick Start

1. Read the assembled newsletter file at `output/YYYY-MM_month_newsletter.md`.
2. Find all deprecation/migration/sunset content anywhere in the document.
3. Move it into a **single bundled bullet** under **Enterprise and Security Updates**.
4. Delete any standalone `# Migration Notices` section.
5. Re-run validation: `bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh output/YYYY-MM_month_newsletter.md`.

## Core Rules (Hard Requirements)

### Rule 1: Single bundled update

All of these belong in **one** bullet (one paragraph) under **Enterprise and Security Updates**:

- Deprecations (models/features/SDKs)
- Sunsets / API shutdowns
- Token revocations
- Minimum version enforcement
- Syntax changes that can break workflows (e.g., comment commands)

Use a title like:
- `**Deprecations and Migration Notices** -- ...`

### Rule 2: No bottom-of-newsletter migration section

Do **not** end the newsletter with a standalone section like:
- `# Migration Notices`

If it exists, it must be removed and its content merged into the Enterprise & Security bullet.

### Rule 3: Remove duplicate mentions elsewhere

If deprecation content appears in other bullets (common places: model availability bullets, metrics bullets), do one of:

- Remove the deprecation sentence/link entirely, OR
- Replace it with a short pointer: "See Deprecations and Migration Notices in Enterprise and Security Updates."

Prefer removal over pointers unless the section would otherwise become misleading.

## Editing Workflow

1. **Inventory**: Identify every deprecation/migration statement and every link that implies deprecation (e.g., `upcoming-deprecation`, `closing-down-notice`, `revoked`, `minimum-version-enforcement`).
2. **Choose canonical placement**: Under **Enterprise and Security Updates**, immediately after the most related bullet (often metrics/governance).
3. **Bundle**: Write one bullet that lists the items as **bolded phrases** in a single sentence/paragraph.
4. **Linking**: Include the authoritative links (usually changelog entries) as pipe-separated links at the end.
5. **Delete old section**: Remove `# Migration Notices` heading and its bullet(s).
6. **Re-scan for dupes**: Ensure the same deprecation link doesn’t appear in multiple sections.

## Optional Helper

Run the helper script to surface candidates:

```bash
python3 .github/skills/deprecation-consolidation/scripts/find_deprecations.py output/YYYY-MM_month_newsletter.md
```

## Done When

- [ ] Newsletter contains **no** `# Migration Notices` section
- [ ] Exactly one bundled deprecations/migration bullet exists under Enterprise & Security
- [ ] Deprecation/sunset links are not duplicated in other sections
- [ ] `validate_newsletter.sh` exits 0

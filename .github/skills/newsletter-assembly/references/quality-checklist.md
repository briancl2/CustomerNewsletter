# Quality Checklist

Pre-delivery quality gates for the assembled newsletter.

## Mandatory Content Checks

- [ ] **Introduction** present with standard template and 2-3 highlights
- [ ] **Copilot section** present with Latest Releases subsection
- [ ] **Copilot changelog links footer** present (inline paragraph, no `## Copilot at Scale` heading)
- [ ] **Changelog links** present in Copilot section footer (all 6 IDEs):
  - GitHub Copilot Changelog
  - VS Code Copilot Changelog
  - Visual Studio Copilot Changelog
  - JetBrains Copilot Changelog
  - Xcode Copilot Changelog
  - Eclipse Copilot Changelog
- [ ] **No orphaned section headings** — every `#` or `##` heading has content below it. A heading with only links and no bullets is orphaned.
- [ ] **YouTube playlists** present at start of Events section (all 3):
  - Copilot Tips and Training
  - GitHub Enterprise, Actions, and GHAS
  - How GitHub GitHubs
- [ ] **Events section** present (virtual table + in-person bullets as applicable)
- [ ] **Closing** present with standard template
- [ ] **Newsletter archive link** present in introduction

## Formatting Checks

- [ ] No raw URLs in text (all embedded as markdown links)
- [ ] No em dashes (search for the character)
- [ ] No double-bracket links `[[Text]](URL)`
- [ ] Bold formatting on product names and feature names
- [ ] GA/PREVIEW labels in uppercase where applicable
- [ ] Section dividers (`---`) between major sections
- [ ] Consistent bullet formatting (`-` or `*`)
- [ ] Proper `#` hierarchy in headers

## Content Quality Checks

- [ ] No Copilot Free/Individual/Pro/Pro+ plan mentions
- [ ] No placeholder text remaining
- [ ] Enterprise focus maintained throughout
- [ ] Professional but conversational tone
- [ ] 2-3 introduction highlights are accurate and compelling
- [ ] IDE rollout note included when parity bullet is present
- [ ] Events table uses date-only (no times) for virtual events
- [ ] Deprecations and migration notices consolidated into a single bullet under **Enterprise and Security Updates** (no `# Migration Notices` section)

## IDE Parity Quality Checks (L66)

- [ ] **All 4 non-VS-Code IDEs** present in IDE section if they had updates (Visual Studio, JetBrains, Eclipse, Xcode)
- [ ] **Every feature in IDE section** has explicit `GA` or `PREVIEW` label -- no unlabeled features
- [ ] **Feature-centric format** used ("Gains Feature A (`GA`), Feature B (`PREVIEW`)"), NOT version-by-version changelogs
- [ ] **No VS Code version numbers** in newsletter body text (only in link URLs). grep for `v1\.\d{3}` in body text returns 0 matches
- [ ] **VS Code content NOT in IDE parity section** -- VS Code features belong in Latest Releases only
- [ ] **Standard rollout note** present at bottom of IDE parity section
- [ ] **VS Code features organized by theme**, not by version (no "v1.108 introduced..." bullets)

## Cross-Section Consistency Checks (L67)

- [ ] **No model or feature has conflicting labels** across sections (e.g., Gemini 3 Flash cannot be `PREVIEW` in model bullet and `GA` in IDE parity)
- [ ] **Every model name has per-model backtick label**: `ModelName (`GA`)` format, NOT prose grouping ("Now GA: X, Y, Z")
- [ ] **No sub-bullet link lists** for source references (only inline pipe-separated or inline feature links). Sub-bullets allowed only for nested content items.
- [ ] **Link labels do not contain status text** (no `[GPT-5.1 GA]`, just `[GPT-5.1]`)

## Surface Attribution and Section Placement (L68)

- [ ] **github.com features** (Agents Tab, repository dashboard, PR features) are NOT in VS Code Latest Releases. They belong in Copilot section only if Copilot-specific, otherwise in Platform/Enterprise section.
- [ ] **Non-Copilot enterprise items** (GHEC DR, GHES releases, enterprise governance) are NOT in Copilot at Scale. They belong in Enterprise and Security section.
- [ ] **Revenue-positive items** (Code Review, metrics) are ordered first within their sections
- [ ] **Same-domain items consolidated** (no two bullets about the same feature area)
- [ ] **Commercial context** present on features with cost implications ("no additional cost", "existing terms apply")

## Final Verification

- [ ] Output file exists at expected path
- [ ] File length: 120-150 lines ideal; up to 175 for rich months; flag if <120 or >175
- [ ] All sections are in mandatory order (Intro, Lead?, Copilot, Additional?, Events, Closing)
- [ ] Legal/indemnity items are expanded with sub-bullets (never compressed)
- [ ] Model availability is always a single consolidated bullet
- [ ] Azure/M365 integrations prioritized over other integrations
- [ ] Training resources included only when new (no stale evergreen)
- [ ] IDE-unique features (not parity) have standalone bullets outside parity section

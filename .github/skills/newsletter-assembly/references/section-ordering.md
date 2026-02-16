# Section Ordering

Mandatory section order for the assembled newsletter.

## Required Order

1. **Introduction** - Standard template with 2-3 dynamic highlights
2. **Monthly Announcement / Lead Section** (conditional) - Only when Phase 3 includes a content-driven lead
3. **Copilot** (mandatory) - Contains:
   - Latest Releases subsection (VS Code features organized by theme, NOT by version number)
     - Order by revenue impact: revenue-positive features first (Code Review, metrics), then GA features, then PREVIEW, then experimental last
     - github.com features (Agents Tab, repository features) belong here only if Copilot-specific. General platform features go to Enterprise & Security.
   - IDE Parity grouping (when applicable) with:
     - All 4 non-VS-Code IDEs that had updates (Visual Studio, JetBrains, Eclipse, Xcode)
     - Every feature labeled with `GA`/`PREVIEW`
     - Feature-centric format (not version-by-version)
     - Standard rollout note at the bottom
   - Copilot at Scale changelog links footer:
     - Standard tracking links as an inline paragraph at the bottom of the Copilot section
     - NO `## Copilot at Scale` heading — this is a footer, not a section
     - Format: "Stay current with the latest changes:" followed by pipe-separated links
     - Include: Copilot Feature Matrix, GitHub Copilot Changelog, VS Code Release Notes, Visual Studio Release Notes, JetBrains Plugin, Xcode Releases, Copilot CLI Releases, GitHub Previews, Preview Terms Changelog
     - NO content bullets. All governance items belong in Enterprise and Security section.
4. **Additional Sections** (conditional) - As warranted by content:
   - **Enterprise and Security Updates** (preferred name when both enterprise platform and security items exist)
   - GitHub Platform Updates
   - DevOps and Integrations
   - GitHub Actions
   - Learning Resources
5. **Resources and Best Practices** (preferred when enablement content exists)
6. **Webinars, Events, and Recordings** (mandatory) - From Phase 2, preceded by YouTube playlists
   - Use `## Virtual Events`
   - Use `## In-Person Events`
   - Use `## Behind the scenes`
7. **Closing** - Standard template

## Section Dividers

Use `---` (horizontal rule) between major sections for visual separation.

## Conditional Section Rules

- **Lead Section**: Include only when Phase 3 output has one. Do not invent a lead section.
- **Additional Sections**: Include only when Phase 3 output contains items for them. Do not create empty sections.
- **Feb 2026 benchmark consistency**: Do not emit a standalone `# GitHub Platform Updates` section. Fold any essential platform items into Enterprise and Security.
- **Heading level consistency**: For benchmark-style long-range runs, use `#` for major sections and `##` for event subsections.
- **Deprecations and migrations**: Consolidate into a single bundled bullet under **Enterprise and Security Updates**. Do not create a standalone `# Migration Notices` section.
- **Conference Sessions**: Only when a major conference occurs in the newsletter cycle.

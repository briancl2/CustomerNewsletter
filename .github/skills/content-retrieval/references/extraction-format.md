# Universal Extraction Format

Every interim file entry must follow this standardized format regardless of source.

## Required Fields

```markdown
### [Feature/Update Title] (GA/PREVIEW/RETIRED)
- **Date**: YYYY-MM-DD (actual release date, not announcement date)
- **Description**: 2-4 sentences with technical details, not marketing copy
- **Links**: [Source1](url1) | [Source2](url2) | [Docs](url3)
- **Relevance Score**: X/10 (enterprise relevance)
- **IDE Support**: Specific IDE(s) or "All IDEs" or "GitHub.com"
- **Enterprise Impact**: 1-2 sentences on specific business value
```

## Field Definitions

### Title
- Include the feature name and affected IDE/platform
- Append status marker: (GA), (PREVIEW), or (RETIRED/DEPRECATED)
- Be specific: "Agent mode for JetBrains IDEs (GA)" not "New feature"

### Date
- Use ISO format: YYYY-MM-DD
- Always use the **actual release date**, not announcement date
- If ambiguous, default to most recent interpretation

### Description
- 2-4 sentences of technical detail
- Explain what changed, why it matters, how it works
- Avoid marketing language
- Include prerequisites or configuration if relevant

### Links (Priority Order)
1. GitHub Changelog entry (if exists)
2. Official release notes/announcement
3. Documentation (if exists)
4. Related blog posts or guides

### Relevance Score
- **9-10**: Must include, high enterprise impact (GA enterprise features, major security)
- **7-8**: Strong candidate (significant IDE updates, admin features)
- **5-6**: Include if space permits (preview features, minor improvements)
- **1-4**: Exclude unless exceptional

### IDE Support
- Name specific IDEs: "VS Code", "Visual Studio", "JetBrains IDEs", "Xcode", "Eclipse"
- Use "All IDEs" only when confirmed across all platforms
- Use "GitHub.com" for web/platform features

### Enterprise Impact
- 1-2 sentences explaining specific business value
- Focus on: adoption, administration, security, productivity at scale, integration
- Avoid restating the feature description

## Filtering Rules

### Include
- New features and significant updates
- Model availability changes
- GA releases and significant previews
- IDE parity announcements
- Enterprise/governance features
- Security updates

### Exclude
- Bug fixes (unless security CVEs)
- Generic "performance improvements"
- Minor UI tweaks
- Routine maintenance updates
- Copilot Free/Individual/Pro/Pro+ specific features

## Interim File Structure

```markdown
# Phase 1B Interim: {Source Name}
**DATE_RANGE**: YYYY-MM-DD to YYYY-MM-DD
**Reference Year**: YYYY
**Generated**: YYYY-MM-DD
**URLs Processed**: {count}

## Coverage Validation
- Earliest item date: YYYY-MM-DD
- Latest item date: YYYY-MM-DD
- Total items extracted: {count}

## Extracted Items

### [Feature Title 1] (GA/PREVIEW)
[full metadata block]

### [Feature Title 2] (GA/PREVIEW)
[full metadata block]

---

## Processing Notes
- Issues encountered
- Failed URLs
- Recommendations for Phase 1C
```

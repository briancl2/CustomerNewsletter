# IDE Parity Rules

How to format IDE feature parity updates in the newsletter.

## The IDE Rollout Pattern

Copilot features follow a predictable release cycle:
1. **VS Code** (usually in PREVIEW first)
2. **Visual Studio** and **JetBrains** IDEs
3. **Eclipse** and **Xcode**

This pattern should be communicated in the newsletter when parity updates exist.

## Cross-IDE Feature Alignment Matrix (Required)

Before writing the IDE parity section, **ALWAYS build a feature alignment matrix** (see content-curation SKILL.md Step 3.5). The matrix is the source of truth for:
- Which IDEs to include (ALL that had updates)
- What GA/PREVIEW labels to apply (from the matrix cells)
- Which features to highlight (features that are GA in multiple IDEs are highest priority)

## Parity Section Format (Gold Standard)

The gold standard format gives **each IDE its own paragraph-length bullet** with:
- IDE name and version/update name in bold
- **Every feature listed with explicit `GA`/`PREVIEW` label** (NEVER omit labels)
- Feature-centric listing (not version-by-version changelog)
- Links at the end of the bullet
- Standard rollout note at the bottom

```markdown
### Improved IDE Feature Parity

-   **Visual Studio -- [Month] Update** -- Feature A (`GA`), Feature B (`PREVIEW`), Feature C (`GA`). Description of notable updates. - [Changelog](URL) | [Blog](URL)

-   **JetBrains IDEs** -- Gains Feature A (`GA`), Feature B (`PREVIEW`), Feature C (`PREVIEW`), Feature D (`PREVIEW`). Note: Most advanced features require enabling the "Editor preview features" policy. - [Plugin Updates](URL)

-   **Eclipse** -- Gains Feature A (`PREVIEW`), Feature B (`PREVIEW`). - [Changelog](URL)

-   **Xcode** -- Gains Feature A (`PREVIEW`), Feature B (`GA`), and support for Model X, Model Y. - [Release Notes](URL)

> Note: **Copilot** features typically follow a predictable pattern in their release cycle, starting in **VS Code** (usually in **`PREVIEW`**), then rolling out to **Visual Studio** and **JetBrains** IDEs, followed by **Eclipse** and **Xcode**.
```

## Rules

1. **ALWAYS build the feature alignment matrix** before writing parity content
2. **ALWAYS include all 4 non-VS-Code IDEs** that had any updates in the period (Visual Studio, JetBrains, Eclipse, Xcode). Never silently drop an IDE.
3. **ALWAYS label every feature** with `GA` or `PREVIEW` per IDE. The "when applicable" qualifier is removed -- labels are ALWAYS required.
4. **ALWAYS use feature-centric format**. List features with labels, NOT version-by-version changelogs. "Gains Agent Skills (`PREVIEW`), MCP Registry (`PREVIEW`)" is correct. "v1.5.60: Custom Agents, v1.5.62: MCP Registry" is wrong.
5. **ALWAYS include the rollout note** (the `> Note:` block above)
6. **NEVER place VS Code content in the IDE parity section**. VS Code features belong in Latest Releases.
7. Lead with the **most impactful** IDE update (typically Visual Studio)
8. **Notable unique IDE features** (not just parity updates) get their **own standalone bullet outside** the parity section

## When to Escalate to Own Section

Escalate from a nested bullet to a `## IDE Updates` or `### Improved IDE Feature Parity` section when:
- JetBrains had >=3 plugin releases in the date range
- Any non-VS-Code IDE has a feature significant enough for its own bullet
- Total IDE parity items >= 5

## When NOT to Use

Skip the parity bullet when:
- Only one IDE has updates this month
- Updates are minor (single bug fix or small improvement)
- No cross-IDE features to highlight

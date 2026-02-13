# JetBrains Source Intelligence

> Calibrated from December 2025 cycle. JetBrains Copilot plugin versions in DATE_RANGE.

## Extraction Profile

- **Primary source**: Plugin API at `https://plugins.jetbrains.com/api/plugins/17718/updates?page=N&size=8`
- **Cross-reference**: GitHub Changelog entries mentioning "JetBrains" (within +/-3 days of plugin release)
- **Content model**: JSON API with version, date (cdate), terse HTML notes
- **Release cadence**: ~2-3 versions per month

## CRITICAL: Cross-Reference Required

JetBrains plugin notes are **extremely terse** (often just a few bullet points). The actual feature descriptions live in the GitHub Changelog. Always cross-reference JetBrains plugin release dates with GitHub Changelog entries containing "JetBrains."

## Survival Rates (December 2025)

| Stage | Count | Rate |
|-------|-------|------|
| Raw items extracted | 13 | 100% |
| Survived to discoveries | 10 | 77% |
| Survived to published | 9 | 69% |
| Discovery-to-publish drop | 1 | 8% |

## Highest Survival Rate of Any Source

JetBrains has the highest discovery rate (77%) because:
- Plugin scope is already Copilot-only (no non-Copilot features to filter out)
- Most items are high-impact cross-IDE features (Plan Agent, Custom Agents, etc.)
- Items naturally map to the IDE Parity bullet pattern

## What Survives (High Signal)

- **Cross-IDE agent features**: Plan Agent, Custom Agents, Subagents (100% survival — always bundle into parity)
- **Model availability**: GPT-5.1, GPT-5-Codex (100% — bundled into model bullet)
- **MCP features**: OAuth, server management (high survival — bundled into MCP bullet)
- **Code review**: Inline review when it's a GA milestone (moderate)

## What Gets Cut (Low Signal)

- **Prompt file/instruction support**: Too granular for newsletter scope
- **Context features**: # context support, drag-to-context (experimental, low impact)
- **Inline code review**: Already covered by GitHub Changelog announcement

## Treatment Patterns

- **Almost always bundled**: JetBrains items nearly always become part of cross-IDE bullets under IDE Parity, never standalone
- **The one drop**: "Drag File to Context" survived to discoveries but was experimental and dropped before publication

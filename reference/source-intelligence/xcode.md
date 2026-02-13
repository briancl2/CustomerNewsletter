# Xcode Source Intelligence

> Calibrated from December 2025 cycle. CopilotForXcode CHANGELOG versions 0.44.0 + 0.45.0.

## Extraction Profile

- **Source URL**: `https://github.com/github/CopilotForXcode/blob/main/CHANGELOG.md`
- **Content model**: Single file, all versions. "Added", "Changed", "Fixed" sections per version.
- **Release cadence**: ~1-2 versions per month

## Survival Rates (December 2025)

| Stage | Count | Rate |
|-------|-------|------|
| Raw items extracted | 19 | 100% |
| Survived to discoveries | 7 | 37% |
| Survived to published | 7 | 37% |

## Lowest Survival Rate — Heavy UI Polish

Xcode has the lowest survival rate because the CHANGELOG contains many small UI and settings changes that aren't enterprise-relevant:
- Font size adjustments, chat layout changes, button toggles → 0% survival
- Settings (max tool requests, disable buttons, OAuth app rename) → 0% survival

## What Survives (High Signal)

- **Cross-IDE features**: Plan Agent, Custom Agents, Subagents, NES (100% when launched)
- **Model availability**: New model support (100% — bundled into model bullet)
- **MCP features**: Dynamic OAuth (100% — bundled into MCP/Xcode parity bullet)

## What Gets Cut (Low Signal)

- **UI polish**: 12 of 19 items were UI changes (font, layout, messaging) → 0% survival
- **Settings additions**: Max tool requests, disable error button → 0% survival
- **Auth plumbing**: OAuth app rename → 0% survival
- **Security fixes**: Even the Command Injection CVE fix was dropped (surprising)

## Treatment Patterns

- **Always bundled**: Xcode items always become part of the IDE Parity nested bullet. Never standalone.
- **No expansion**: No Xcode item has ever been expanded in any published newsletter.

## Key Learning

For Xcode, extract ONLY "Added" items that match cross-IDE features (agent, plan, MCP, models, NES). Everything else in the CHANGELOG is noise for newsletter purposes. The "Changed" section occasionally has MCP/OAuth items worth including. "Fixed" is always excluded.

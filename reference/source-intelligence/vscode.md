# VS Code Source Intelligence

> Calibrated from December 2025 cycle item-level tracing. VS Code v1.105 + v1.106.

## Extraction Profile

- **Source URL**: `https://code.visualstudio.com/updates/v1_{VERSION}`
- **Content model**: Versioned pages with rich feature descriptions, screenshots, settings
- **Release cadence**: Weekly (changed from monthly in early 2026)
- **CRITICAL (L64 + L66)**: Named months lag release dates by 1-2 months. With weekly cadence, a 30-day newsletter period includes 4-5 versions; 60-day includes 8-10. ALWAYS check the updates index page (`code.visualstudio.com/updates`) for actual release dates. Use the **diff-based multi-release extraction strategy**: read newest version fully, diff earlier versions for status changes and first-appearance dates only. Never produce version-summary bullets. Never reference version numbers in newsletter body text.
- **Items per release**: ~5-8 features per weekly version (lower per-release than monthly, but cumulative across 4-10 weekly releases is comparable)
- **Key weekly-release behavior**: Features iterate across versions (EXPERIMENTAL in week 1, improved in week 2-3, GA in week 4). The same feature will appear on 2-4 version pages with evolving descriptions. The newest page always has the most complete description.

## Survival Rates (December 2025)

| Stage | Count | Rate |
|-------|-------|------|
| Raw items extracted | 24 | 100% |
| Survived to discoveries | 12 | 50% |
| Survived to published | 13 | 54% |
| Discovery bypass (raw→published directly) | 1 | 4% |

## What Survives (High Signal)

These VS Code feature types consistently make the newsletter:
- **Agent-related**: Plan Agent, Custom Agents, Subagents, Agent Sessions (100% survival)
- **MCP features**: Server access, marketplace, org controls (100% survival)
- **Cross-IDE parity items**: Features that ship in VS Code first then roll to other IDEs (high survival because they feed the IDE Parity bullet)
- **Model availability**: Always survives but always compressed into single bullet
- **Terminal agent improvements**: Survive when bundled into CLI/Terminal bullet

## What Gets Cut (Low Signal)

- **Experimental/Insiders features**: Reasoning, chain-of-thought, inline chat v2 (0% survival)
- **UI polish**: Language models editor, save conversation, sign-in options (0% survival)
- **Language-specific**: Python docstring generation, coverage tools (0% survival)
- **General IDE improvements**: Open source inline suggestions, test coverage (0% survival)

## Treatment Patterns

- **Expanded**: Only for major new capabilities (Plan Agent as standalone, MCP org controls)
- **Bundled**: Most common treatment. Agent features bundled into cross-IDE bullets. Terminal features bundled into CLI bullet.
- **Discovery bypass**: 1 item (Resolve Merge Conflicts) added during curation, not during extraction. Shows that the curator catches items the extractor misses.

## Deep-Read Signal

VS Code release notes are VERY rich. The human flagged that "VS Code updates usually has really important functionality hidden in the changelog." Key sections to always deep-read:
- Chat UX section: Often contains enterprise-relevant agent improvements
- Agent section: Nearly 100% survival rate
- MCP section: Nearly 100% survival rate
- Terminal section: Moderate survival (only when Copilot-integrated)
- Experimental section: Low survival but occasionally contains preview features worth flagging

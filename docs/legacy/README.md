# Legacy Mapping

This repository preserves pre-overhaul public artifacts to show the transformation path.

Legacy location:
- `legacy/2026-02_pre-overhaul/`

## Mapping: Legacy -> Current

| Legacy Artifact | Current Equivalent |
|---|---|
| `chatmodes/customer_newsletter.md` | `.github/agents/customer_newsletter.agent.md` + phase skills |
| `agentic_newsletter_phase_1a_updates_discovery.prompt.md` | `.github/prompts/phase_1a_url_manifest.prompt.md` + `.github/skills/url-manifest/` |
| `agentic_newsletter_phase_1b_events_extraction.prompt.md` | `.github/prompts/phase_2_events_extraction.prompt.md` + `.github/skills/events-extraction/` |
| `agentic_newsletter_phase_2_content_curation.prompt.md` | `.github/prompts/phase_3_content_curation.prompt.md` + `.github/skills/content-curation/` |
| `newsletter_template.md` | `.github/skills/newsletter-assembly/` + references |

## Why Preserve Legacy

- Clear before/after architecture comparison
- Reproducible evolution story for customers
- Teaching artifact for prompt-to-skill migration patterns

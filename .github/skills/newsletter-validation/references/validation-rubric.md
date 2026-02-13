# Validation Rubric

Complete checklist for newsletter quality validation, both automated and manual.

## Automated Checks (run via validate_newsletter.sh)

### Required Sections (5 checks)
- [ ] Introduction section present (contains "personally curated" or "archive")
- [ ] Copilot section present (header contains "Copilot")
- [ ] Copilot at Scale subsection present
- [ ] Events section present (contains "Events" or "Webinars")
- [ ] Closing section present (contains "reach out" or "feel free")

### Required Content Blocks (3 checks)
- [ ] Changelog links present (at least 4 of 6 IDE changelogs)
- [ ] YouTube playlists present (at least 2 of 3 playlists)
- [ ] Newsletter archive link present

### Forbidden Patterns (5 checks)
- [ ] No em dashes (the character)
- [ ] No `[[` double-bracket links
- [ ] No "Copilot Free" or "Copilot Individual" or "Copilot Pro" mentions
- [ ] No raw URLs outside of markdown link syntax
- [ ] No remaining TODO/PLACEHOLDER markers

### Format Checks (3 checks)
- [ ] GA/PREVIEW labels in uppercase
- [ ] File is at least 100 lines long
- [ ] Virtual events table uses date only (no times in virtual section)

## Manual Review Checks

### Tone and Voice
- [ ] Personal curator voice (feels like Brian wrote it)
- [ ] Professional but conversational
- [ ] Not robotic or automated-sounding
- [ ] Enterprise-appropriate language

### Enterprise Relevance
- [ ] All items relevant to Engineering Managers, DevOps Leads, IT Leadership
- [ ] No consumer/hobbyist content
- [ ] Healthcare and Manufacturing relevance clear
- [ ] Business value articulated for key items

### Link Quality (spot-check 5-10)
- [ ] Links go to expected pages (not 404)
- [ ] Link text is descriptive (not "click here")
- [ ] Mix of announcement, docs, and changelog links

### Section Balance
- [ ] No single section dominates the newsletter
- [ ] Content variety across categories
- [ ] Events section has reasonable number of events (3-15)
- [ ] Copilot at Scale has substance (not just changelog links)

### Introduction Quality
- [ ] 2-3 highlights accurately reflect newsletter content
- [ ] Highlights are compelling and enterprise-focused
- [ ] Archive link present and correct

---
name: newsletter-validation
description: "Validates newsletter output against quality standards. Use after Phase 4 assembly to verify the newsletter meets all requirements. Runs automated checks for required sections, link format, forbidden patterns, and structural compliance. Keywords: newsletter validation, quality check, post-pipeline, validation rubric."
metadata:
  category: domain
  phase: post
---

# Newsletter Validation

Validate newsletter output against quality standards.

## Quick Start

1. Run automated validation: `bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh <newsletter_file>`
2. Review results: exit 0 = pass, exit 1 = fail with details
3. If automated checks pass, perform manual review using the rubric
4. Fix any issues and re-validate

## Inputs

- **Newsletter file**: Path to the assembled newsletter markdown (e.g., `output/YYYY-MM_month_newsletter.md`)

## Output

- Exit code 0 (pass) or 1 (fail) with detailed report on stdout

## Automated Checks

The [validate_newsletter.sh](scripts/validate_newsletter.sh) script checks:

### Required Sections
- Introduction with archive link
- Copilot section with Latest Releases
- Copilot at Scale with changelog links
- Events section with YouTube playlists
- Closing section

### Forbidden Patterns
- Raw URLs not in markdown links
- Em dashes
- Double-bracket links `[[`
- Copilot Free/Individual/Pro/Pro+ plan mentions
- Wikilink format

### Format Compliance
- GA/PREVIEW labels in uppercase
- Events table has Date column
- File exists and has content (minimum 100 lines)

## Manual Review Rubric

After automated checks pass, review by hand:

See [validation-rubric.md](references/validation-rubric.md) for the complete rubric.

Key manual checks:
- **Tone**: Personal curator voice, professional but conversational
- **Enterprise relevance**: All items relevant to target audience
- **Link validity**: Spot-check 5-10 links for 404s
- **Section balance**: No section dominates, good variety
- **Highlight accuracy**: Introduction highlights match actual content

## Reference

- [Validation Rubric](references/validation-rubric.md) - Full manual + automated checklist
- [Benchmark Examples](examples/) - Known-good newsletters for comparison

## Done When

- [ ] `validate_newsletter.sh` exits with code 0
- [ ] Manual review completed (tone, relevance, links)
- [ ] No required sections missing
- [ ] No forbidden patterns found
- [ ] Newsletter is ready for distribution

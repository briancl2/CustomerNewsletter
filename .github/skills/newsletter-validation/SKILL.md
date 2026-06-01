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
- Customer-facing Copilot App release-process leakage (`github/github-app`, anonymous fetch/404, private tags, authenticated release notes, `[truncated]`)
- Legal/CCC content outside the active Enterprise/Security/Governance/Legal/Compliance heading path unless the issue is explicitly legal-led
- VS Code body-prose sequences with 3+ `1.xxx` version numbers
- Under-linked release-inventory bullets for Copilot App and high-volume Copilot CLI, using generic release-count/release-stream triggers rather than one month-specific count

### Strict Pipeline Artifact Contract

When running `tools/validate_pipeline_strict.sh --production-artifacts`, high-volume final-output claims also require upstream artifacts:

- `workspace/copilot_cli_release_inventory_START_to_END.md` for triggered Copilot CLI release-inventory prose
- `workspace/copilot_app_release_inventory_START_to_END.md` for triggered Copilot App release-stream prose
- `workspace/newsletter_phase3_capability_map_START_to_END.json` when either App or CLI inventory-backed prose is triggered
- `workspace/newsletter_phase1b_vscode_theme_summary_START_to_END.md` when dense VS Code release scope is present

The capability map must contain at least one usable capability row with evidence sources, a public-safe link target, and final/newsletter prose treatment. The retained May 2026 run can use its legacy Markdown inventory/map names as positive examples; future runs should emit the canonical `START_to_END` paths, and no-reuse prep archives retained legacy names before clean reruns.

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
- **Claim discipline**: Billing, pricing, model status, legal/preview, BYOK, OpenTelemetry, and optimization claims have the right source class and evidence label. Provider API docs are not Copilot billing proof.
- **Actionability**: Major sections include a recommended action, owner cue, or explicit awareness-only treatment.
- **Scope-sensitive wording**: Generic `BYOK token usage`, broad OpenTelemetry claims, and optimization claims like `gives teams evidence` are scoped or hedged unless the source supports stronger wording.

### Manual Risk Review Candidates

These are not all deterministic validator failures because wording can be legitimate in the right context, but they must be reviewed before publication:

- UBB, AI Credits, pricing, budgets, or model-cost language without GitHub billing/budget source support
- Model availability/status claims without current GitHub supported-models or GitHub Changelog support
- Legal, DPA, CCC, indemnity, preview, or pre-release claims outside Enterprise/Security/Governance/Legal/Compliance context
- Generic `BYOK token usage` without surface and billing/reporting scope
- OpenTelemetry claims that imply full traces for standard IDE/CLI usage when only SDK or instrumented workflow sources apply
- Cost-optimization claims that imply billing proof, durable savings, model superiority, or fleet readiness from internal telemetry
- UBB-heavy newsletters missing developer caveats for code completions/Next Edit Suggestions and Copilot code review billing

## Reference

- [Validation Rubric](references/validation-rubric.md) - Full manual + automated checklist
- [Benchmark Examples](examples/) - Known-good newsletters for comparison

## Done When

- [ ] `validate_newsletter.sh` exits with code 0
- [ ] Manual review completed (tone, relevance, links)
- [ ] No required sections missing
- [ ] No forbidden patterns found
- [ ] Newsletter is ready for distribution

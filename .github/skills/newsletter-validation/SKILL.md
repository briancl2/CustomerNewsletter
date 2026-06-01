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
- Specific-labeled inline links that point to a generic landing page instead of the deep/anchored source (WARN; see Link Specificity)

### Link Specificity (Inline Deep-Link Policy)

Applies to **inline contextual links in prose** -- a link whose label names a specific feature, capability, or claim. Such a link must point to the most specific source that documents that exact thing: a section anchor, a dated changelog post, or a deep doc page. It must not point to a generic landing page, a bare version page, or a blog root.

- Correct: a sentence about OpenTelemetry signals for agents links to `code.visualstudio.com/updates/v1_122#_richer-opentelemetry-signals-for-agents`, not to `code.visualstudio.com/updates/v1_122` or a blog index.
- Duplicate inline links to the same **deep, anchored** URL are allowed when each use is the direct, specific source for its surrounding claim.
- **No repeated generic page in one breath.** A non-anchored or generic page (a tutorial root, doc landing, or bare version page with no `#` anchor) must appear at most once per bullet, table row, or sentence. Do not link the same generic page from several phrases in a row: link it once on the most specific phrase and keep a single trailing/source pointer. Repeating one generic page across multiple claims adds visual noise without adding specificity, and is the most common form of low-value link duplication.
- In role/action tables, the `Source` column is the row's canonical pointer; do not also link that same generic URL from the `Action` and `Why` columns. Reserve inline links in those columns for a *different*, more specific source.
- Exemption: aggregated reference/source-list sections (for example a `Source Links` section or a consolidated public-sources file) and generically labeled pointers (`[Release Notes]`, `[Changelog]`, `[Docs]`, `[GitHub Blog]`) may use stable canonical landing pages. The label-to-URL mapping in the manual rubric still applies there.
- If no deep source exists for a specific claim, narrow the link label so it accurately describes the landing page, and record the exception.

The `validate_newsletter.sh` check is WARN-level. It flags: (1) specific-labeled inline links to bare VS Code version pages (no `#` anchor) and to blog roots; (2) a non-anchored URL repeated 3+ times in a single line (one inline use plus one trailing/source pointer is fine -- more than that is the repeated-generic-page pattern); and (3) specific-labeled inline links to bare `docs.github.com` section indices (for example `.../copilot` or `.../copilot/reference` with no article). Generic labels are exempt. WARN does not block, but each flag must be resolved or justified before publication.

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

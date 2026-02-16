---
name: content-retrieval
description: "Fetches and extracts content from Phase 1A URL manifest into 5 interim files by source. Use when running Phase 1B of the newsletter pipeline. Processes URLs sequentially by source, extracts relevant items using universal extraction format, outputs one interim file per source. Keywords: content retrieval, phase 1b, web extraction, interim files."
metadata:
  category: domain
  phase: "1B"
---

# Content Retrieval

Fetch content from Phase 1A URLs and extract items into 5 interim files (one per source).

## Quick Start

1. Read the Phase 1A URL manifest from `workspace/newsletter_phase1a_url_manifest_*.md`
2. Process sources sequentially: GitHub, VS Code, Visual Studio, JetBrains, Xcode
3. For each source: fetch URLs, extract features, write interim file, checkpoint
4. Output: 5 files in `workspace/newsletter_phase1b_interim_{source}_*.md`

## Inputs

- **Phase 1A Manifest**: `workspace/newsletter_phase1a_url_manifest_*.md` (required)
- **DATE_RANGE**: Inherited from manifest
- **Reference Year**: Inherited from manifest

## Output

5 interim files in `workspace/`:
- `newsletter_phase1b_interim_github_YYYY-MM-DD_to_YYYY-MM-DD.md`
- `newsletter_phase1b_interim_vscode_YYYY-MM-DD_to_YYYY-MM-DD.md`
- `newsletter_phase1b_interim_visualstudio_YYYY-MM-DD_to_YYYY-MM-DD.md`
- `newsletter_phase1b_interim_jetbrains_YYYY-MM-DD_to_YYYY-MM-DD.md`
- `newsletter_phase1b_interim_xcode_YYYY-MM-DD_to_YYYY-MM-DD.md`

## Core Workflow

### Sequential 5-Chunk Processing

Process sources one at a time to manage context window. After each chunk: write file, confirm, clear working memory.

```
Chunk 1: GitHub Blog + Changelog -> Write interim -> Checkpoint
Chunk 2: VS Code (Copilot only) -> Write interim -> Checkpoint
Chunk 3: Visual Studio (Copilot only) -> Write interim -> Checkpoint
Chunk 4: JetBrains Plugin -> Write interim -> Checkpoint
Chunk 5: Xcode CHANGELOG -> Write interim -> Complete
```

### Runtime Constraint: Controlled Delegation Only

During CLI pipeline runs in this repo, unbounded or generic delegation can deadlock Phase 1B after retrieval and before interim file creation.

Hard rules:
- Do not delegate to generic or "general-purpose" subagents.
- If delegation is used, delegate only to a named agent with a strict Phase 1B boundary and explicit stop condition.
- Always verify that all 5 interim files are written before exiting Phase 1B.

### CRITICAL: Anchor Unit = Feature, NOT Version

The primary organizing unit is a **feature or update**, NOT a plugin/IDE version. Even when source material groups content by version, decompose each version into individual feature entries. This is critical for Phase 1C deduplication.

**Wrong** (version-based): "JetBrains 1.5.60 added X, Y, Z"
**Right** (feature-based): Separate entries for X, Y, and Z with full metadata each

### CRITICAL: IDE Monthly Update Deep-Read (G4)

When an IDE monthly update is detected (VS Code release notes, Visual Studio monthly update, JetBrains plugin version), **deep-read the full release notes page**, not just the changelog summary. IDE release notes pages contain 10-20x more detail than changelog entries. Extract ALL sections; downstream curation will filter. This is the single highest-value extraction action per L20 and L34.

### CRITICAL: VS Code Multi-Release Extraction (L64 + L66)

VS Code now ships weekly releases. A 30-day newsletter period typically includes 4-5 releases; a 60-day period includes 8-10. The extraction MUST be **feature-centric, not version-centric**.

**Diff-Based Strategy (read newest first, diff earlier)**:
1. Get the full list of VS Code versions in scope from the scope contract
2. **Read the NEWEST version page first and fully** -- this represents the most mature state of every feature. Extract all Copilot-relevant features from this page as the primary feature set.
3. **For each EARLIER version page** (working backward chronologically), scan and extract ONLY:
   a. **Features that don't appear in the newer version** (removed, renamed, or one-time announcements)
   b. **Status changes** -- the key signal is a feature moving from EXPERIMENTAL to PREVIEW to GA across versions. Record the version where each transition happened.
   c. **First-appearance dates** -- note which version first introduced each feature
4. **Output a single unified feature list** with evolution metadata per item:
   - Feature name and current (latest) status
   - First-appeared version and date
   - GA version (if the feature went GA during this period)
   - Links to the MOST RELEVANT version page (the one where the feature description is richest)
   - Evolution note only when status changed across versions (e.g., "experimental in v1.108, GA in v1.109")
5. **NEVER output version-summary bullets** ("v1.108 introduced X, Y, Z"). The output is features, not versions.
6. **NEVER reference VS Code version numbers in feature descriptions**. Version numbers appear only in link URLs and evolution metadata. The newsletter period is the unit, not any individual version.

**Why newest-first**: Weekly releases have heavy feature overlap. The newest page has the most mature description of each feature. Earlier pages only need to be scanned for deltas (new features, status transitions).

**Gate**: If scope contract lists N versions and extraction only processed fewer than N, STOP and re-check. Missing a version means missing status transitions.

When JetBrains has multiple plugin releases in the date range, extract EACH version separately with its features. Do not collapse multiple versions into one entry. Downstream curation needs the granularity to decide whether IDE Updates warrants its own section.

### CRITICAL: Surface Attribution

When extracting features, verify which SURFACE the feature actually lives on. A feature announced in the same changelog entry as VS Code features may actually be a github.com feature (e.g., Agents Tab is on github.com, not VS Code). Check the feature's actual URL/documentation to confirm the surface. Common misattributions: Agents Tab = github.com, ACP = CLI, Enterprise Teams API = github.com admin.

### CRITICAL: Status Label Verification

Never infer GA status from feature maturity or adoption. Check the EXACT changelog entry or docs page for the explicit status label. A label is only justified when the source text contains the exact words "generally available", "public preview", "technical preview", "experimental", or "beta". If the source says "now available" or "now supports" without an explicit status qualifier, **omit the label entirely** rather than guessing. Common over-claims to avoid: BYOK (was PREVIEW, pipeline labeled GA), OpenCode support (was unlabeled announcement, pipeline added GA), CLI tools (often PREVIEW long after launch), VS Code features without explicit labels, new IDE integrations, 3P platform features.

### Extraction Format

Every item must follow the universal extraction format. See [extraction-format.md](references/extraction-format.md) for the complete field specification.

### Source-Specific Extraction Strategies

Each source has a fundamentally different data model. Use source-specific approaches:

- **VS Code**: Apply the **Multi-Release Extraction** strategy above (L64 + L66). Read the newest version page fully, then diff earlier versions for status changes and new features. VS Code changelogs hide important features behind terse summaries -- always deep-read the actual release notes pages. Extract ALL sections from the newest page; learn what survives downstream. Copilot Chat UX, Agent, MCP, and Security sections have highest survival rates, but editor/terminal features sometimes contain Copilot-integrated items worth including. With weekly releases, expect 4-10 version pages per newsletter period -- the diff-based strategy prevents redundant extraction.

- **Visual Studio**: The MS Learn release notes page (`learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes`) is a rolling patch page (17.14.1 through 17.14.26+). The Features section at top is undated and covers the entire 17.14 lifecycle. Individual patch versions are mostly bug fixes and CVEs. **PRIMARY source for VS Copilot features is the GitHub Changelog** (entries like "GitHub Copilot in Visual Studio - [Month] update", "Agent mode is now GA in Visual Studio"). Cross-reference the MS Learn page for patch-specific Copilot fixes. For VS 2026 (launched Nov 24, 2025), use the separate release notes page.

- **GitHub Blog/Changelog**: Richest source overall. Monthly archives at `github.blog/changelog/YYYY/MM/`. **ALSO scan `github.blog/news-insights/company-news/`** for major strategic announcements (CPO/CEO blog posts) that do NOT appear in the changelog feed. Missing these is a critical gap (e.g., Agent HQ 3P platform launch was only on news-insights).

- **JetBrains**: Plugin API returns terse "What's New" notes. Cross-reference with GitHub Changelog entries mentioning "JetBrains" within ±3 days of plugin release date for feature detail. The Changelog is where the narratives live.

- **Xcode**: Single CHANGELOG.md on GitHub. "Added" and "Changed" sections are the primary content. Skip "Fixed" unless security-related. Cross-reference with GitHub Changelog for Xcode-specific announcements.

- **Copilot CLI**: The **primary source is `github.com/github/copilot-cli/releases`**, NOT the GitHub blog changelog. The CLI ships daily releases (sometimes multiple per day), so a 30-day newsletter period can include 30+ releases. The blog changelog only publishes occasional summary posts that lag behind and miss most features. **Extraction strategy**: (1) Fetch the releases page and scan all stable releases (skip pre-releases with `-N` build suffixes appended to the version number, e.g., `v0.0.404-0`, `v0.0.404-1`; stable releases have no suffix after the final digit) whose date falls within DATE_RANGE. (2) Aggregate features across all releases into a single feature-centric list — never produce per-version bullets. (3) Categorize features by type: major capabilities (plan mode, background agents, plugins), platform integrations (ACP, MCP, SDK), quality-of-life (slash commands, permissions, themes), and bug fixes (skip unless security-related). (4) Cross-reference with GitHub blog changelog posts for richer narrative descriptions of major features — blog posts are supplementary links, not the discovery source. (5) The CLI is NOT in the Copilot feature matrix; pair CLI features with blog changelog links where available.

### Copilot CLI Command Block (Benchmark Override)

Run these explicit commands during Phase 1B when benchmarking against February 2026 fidelity:

```bash
# 1) Pull releases feed and keep stable tags only (exclude pre-release suffixes like -0 / -1)
curl -sL "https://github.com/github/copilot-cli/releases.atom" \
| rg -o 'v[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?' \
| rg -v -- '-[0-9]+$' \
| python3 -c "import re, sys; tags=sorted(set(sys.stdin.read().split()), key=lambda t: tuple(int(x) for x in re.findall(r'\\d+', t)[:3])); print('\\n'.join(tags))" \
> /tmp/copilot_cli_stable_tags.txt

# 2) Fetch recent stable release pages (latest 5 from the feed)
tail -n 5 /tmp/copilot_cli_stable_tags.txt | while read -r tag; do
  curl -sL "https://github.com/github/copilot-cli/releases/tag/${tag}" \
    > "/tmp/copilot_cli_${tag}.html" || true
done

# 3) Feb 2026 anchor tags (fetch only if present in the stable tag list)
for tag in v0.0.400 v0.0.404 v0.0.406; do
  if rg -qx "$tag" /tmp/copilot_cli_stable_tags.txt; then
    curl -sL "https://github.com/github/copilot-cli/releases/tag/${tag}" \
      > "/tmp/copilot_cli_${tag}.html" || true
  fi
done

# 4) Ensure interim output includes:
#    - releases index URL
#    - at least 2 release tag URLs
#    - extracted capability bullets (delegate/background agents/plugins/autopilot)
```

If `rg` is unavailable, use `grep -oE` as a fallback for the tag extraction step.

Minimum output requirement in `workspace/newsletter_phase1b_interim_github_*.md`:
- `https://github.com/github/copilot-cli/releases`
- At least two `https://github.com/github/copilot-cli/releases/tag/<tag>` URLs
- A consolidated CLI capability summary grounded in those tag pages

### Cross-Referencing

- JetBrains plugin versions: cross-reference with GitHub Changelog (plus/minus 3 days)
- VS Code features: cross-reference with GitHub Changelog for matching announcements
- Include all discovered URLs in each item's Links field

### Status Markers

- **(GA)**: Generally available, production-ready
- **(PREVIEW)**: Public preview, experimental, or beta
- **(RETIRED/DEPRECATED)**: Being removed or replaced

### Per-Chunk Validation

Before moving to next chunk, verify:
- [ ] All manifest URLs for this source were processed
- [ ] Output is feature-based, not version-based
- [ ] Each entry has date, description, links, relevance score, IDE tag
- [ ] All dates within DATE_RANGE
- [ ] Interim file written and confirmed on disk

## Reference

- [Extraction Format](references/extraction-format.md) - Universal extraction format specification
- [Benchmark Examples](examples/) - 5 known-good Dec 2025 interim files
- [VS Code Intelligence](../../../reference/source-intelligence/vscode.md) - 50% discovery rate; Agent/MCP/Chat UX survive; experimental and UI polish drop
- [Visual Studio Intelligence](../../../reference/source-intelligence/visualstudio.md) - Dual-source: GH Changelog for features, MS Learn for patches. 42% discovery rate.
- [JetBrains Intelligence](../../../reference/source-intelligence/jetbrains.md) - Highest survival (77%); always bundled into IDE Parity bullets
- [Xcode Intelligence](../../../reference/source-intelligence/xcode.md) - Lowest survival (37%); most items are UI polish; only cross-IDE features survive
- [GitHub Changelog Intelligence](../../../reference/source-intelligence/github-changelog.md) - Richest source; COPILOT-labeled items survive at 80%; scan news-insights/ too

## Done When

- [ ] All 5 interim files exist in `workspace/`
- [ ] All files use feature-based format (not version-based)
- [ ] VS Code and Visual Studio contain ONLY Copilot-related features
- [ ] Total item count is reasonable (expect 40-100 items across all sources)
- [ ] No unresolved fetch failures

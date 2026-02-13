# Polishing Intelligence — Patterns from 132 Newsletter Edits

_Extracted from 14 discussion edit histories (May 2024 – December 2025)._

---

## 1. Summary Statistics

| Metric | Value |
|--------|-------|
| Total discussions analyzed | 14 (discussions #2–#15) |
| Total diffs analyzed | 132 |
| Discussions with edits | 13 (discussion #7 had 0 edits) |
| Richest discussion | #13 Jun 2025 (28 diffs) |
| Second richest | #4 Jul 2024 (26 diffs) |
| Median diffs per discussion | 7 |

### Change Type Distribution

| Type | Count | % |
|------|-------|---|
| rewrite | 89 | 67% |
| addition | 13 | 10% |
| expansion | 8 | 6% |
| removal | 5 | 4% |
| mixed | 2 | 2% |
| compression | 1 | 1% |
| (initial paste) | 14 | 11% |

**Key insight:** Two-thirds of all polishing edits are single-line rewrites — fine-grained wording, formatting, or label corrections applied one at a time. Content additions and expansions cluster early in the editing session; rewrites dominate the middle and late passes.

---

## 2. Recurring Patterns

### Pattern 1: Heading Space After Hash

**Description:** `###Title` is written without a space after `###`, then corrected to `### Title` in the next edit. Happens because rapid markdown authoring in the GitHub discussion editor omits the required space for proper rendering.

**Evidence:**
- **Discussion #4** (Jul 2024): diffs 00→01 and 01→02 — 6 headings fixed across both diffs (`###Copilot Enterprise` → `### Copilot Enterprise`, `###The future` → `### The future`, `###GenAI` → `### GenAI`, `###Other` → `### Other`, `###Upcoming Webinars` → `### Upcoming Webinars`, `###Upcoming In-person` → `### Upcoming In-person`)
- **Discussion #3** (Jun 2024): diffs 01→02 and 02→03 — 6 headings fixed identically (`###Measuring` → `### Measuring`, `###GitHub and JFrog` → `### GitHub and JFrog`, `###Microsoft Build` → `### Microsoft Build`, `###Other` → `### Other`, `###Upcoming Webinars` → `### Upcoming Webinars`, `###Upcoming In-person` → `### Upcoming In-person`)

**Frequency:** 2/13 discussions (15%), but those 2 discussions spent 2 full diffs each fixing this. The pattern disappeared in later newsletters (2025) as the author learned the syntax.

**Proposed rule:** After assembly, scan all headings with regex `^(#{1,6})\S` and insert a space: `$1 $2`. This is a zero-risk structural fix.

---

### Pattern 2: Bullet Style Normalization

**Description:** Bullet characters oscillate between `*`, `•`, `**`, and `-` across multiple edits before settling on a consistent style. Nested bullets go through particularly chaotic formatting sequences.

**Evidence:**
- **Discussion #4** (Jul 2024): diffs 02→03 through 06→07 — Sub-bullets for a podcast topics list went through 5 revisions: `* *` → `**` → mixed `- ` / `**` → `  - ` consistently. Took 5 consecutive diffs to normalize.
- **Discussion #9** (Jan 2025): diffs 03→04, 04→05, 06→07 — Top-level bullets oscillated between `•` and `-` three times before settling on `-`.

**Frequency:** 3/13 discussions (23%). Especially prevalent in longer, list-heavy newsletters.

**Proposed rule:** Normalize all top-level bullets to `-` and nested bullets to `  -` (2-space indent). Replace `•`, `*` (non-bold), and `**` (used as bullets) with the standard `-` character. Apply after all content additions are complete.

---

### Pattern 3: Status Label Format Iteration

**Description:** GA/PREVIEW labels go through multiple formatting variations: `(GA)` → `` (`GA`) `` → `` (**`GA`**) `` → back to `` (`GA`) ``. The author experiments with nested bold and backtick combinations before settling on a preferred format.

**Evidence:**
- **Discussion #13** (Jun 2025): diff 07→08 — `Agent mode` becomes `Agent mode (\`GA\`)` (label added). diff 08→09 — `` (`GA`) `` becomes `` (**`GA`**) `` (bold-wrapped). diffs 21→22 / 22→23 — Oscillation between `` `**PREVIEW**` `` and `` **`PREVIEW`** `` before settling on `` **`PREVIEW`** ``.
- **Discussion #9** (Jan 2025): diffs 03→04 — `(PREVIEW)` to `` (PREVIEW) `` to back to `(Preview)` in later diffs.
- **Discussion #15** (Dec 2025): diff 08→09 — `` (`GA` in VS Code/JetBrains, `PREVIEW` elsewhere) `` corrected to `` (`GA` in VS Code, `PREVIEW` elsewhere) `` — narrowing incorrect GA scope claims.

**Frequency:** 4/13 discussions (31%). Every newsletter with GA/PREVIEW labels gets at least one label format edit.

**Proposed rule:** Standardize on `` (`GA`) ``, `` (`PREVIEW`) ``, `` (`GA`/`PREVIEW`) `` format. Never nest bold inside backticks or vice versa. Validate label accuracy against source changelogs before publishing.

---

### Pattern 4: Product Name Capitalization Standardization

**Description:** GitHub product feature names get incrementally capitalized and bolded to match official naming conventions. Common corrections: `issues` → `Issues`, `coding agent` → `Coding Agent`, `agent mode` → `Agent Mode`, `next edit suggestions` → `Next Edit Suggestions (NES)`.

**Evidence:**
- **Discussion #13** (Jun 2025): diff 16→17 — `**GitHub** issues` → `**GitHub Issues**` (capitalize product name). diff 18→19 — `**coding agent**` → `**Coding Agent**`, `**agent mode**` → `**Agent Mode**`. diff 19→20 — `issues and Pull Requests` → `**GitHub Issues** and Pull Requests`. diff 20→21 — `next edit suggestions` → `Next Edit Suggestions (NES)`.
- **Discussion #13** (Jun 2025): diff 23→24 — Three separate corrections: `coding agent` → `Coding Agent`, `issues` → `Issues`, `preview` → `` `PREVIEW` `` in the same diff.

**Frequency:** 3/13 discussions (23%). Concentrated in the more complex 2025 newsletters that reference many product features.

**Proposed rule:** Maintain a canonical product name dictionary. After assembly, scan for lowercase variants and replace with the official capitalized form. Key entries:
- `coding agent` → `Coding Agent`
- `agent mode` → `Agent Mode`
- `next edit suggestions` / `NES` → `Next Edit Suggestions (NES)`
- `issues` (when referring to the product) → `Issues`
- `pull requests` (when referring to the product) → `Pull Requests`
- `copilot spaces` → `Copilot Spaces`
- `copilot chat` → `Copilot Chat`

---

### Pattern 5: Introduction / Preamble Rewrites

**Description:** The newsletter introduction paragraph gets rewritten 2-3 times to better summarize the actual content that follows. The highlights summary drifts from the body content during editing and needs to be re-synced with what was actually included.

**Evidence:**
- **Discussion #4** (Jul 2024): diff 20→21 — Highlights rewritten from `an Industry Roundup, and Updated ADO Guidance,` to `Updated ADO + GHE Guidance, and a GenAI Industry Roundup`. diff 21→22 — Intro phrase `pull together and share current resources, announcements, and events` → `share new resources, announcements, and events`.
- **Discussion #14** (Aug 2025): diff 02→03 — Full intro paragraph added. diff 05→06 — Intro rewritten to tighten: `August brings MCP support in VS Code (GA)...` → `Highlights include GA MCP support in VS Code...`.
- **Discussion #02** (May 2024): diff 09→10 — Adds `, and events` to the intro's purpose statement.
- **Discussion #03** (Jun 2024): diff 05→06 — Highlights completely rewritten to match actual body sections, and subtitle updated.

**Frequency:** 5/13 discussions (38%). Almost every newsletter with a highlights summary rewrites it at least once.

**Proposed rule:** Generate the introduction paragraph **last**, after all content sections are finalized. Extract the actual section headings and key items to build an accurate highlights summary. Never write the intro before the body is stable.

---

### Pattern 6: Link Text and URL Refinement

**Description:** Link display text gets iteratively refined for accuracy, broken link syntax gets fixed, and URLs are swapped for more authoritative sources. Common patterns: vague labels become specific, repo links become marketplace links, and anchored text is repositioned.

**Evidence:**
- **Discussion #4** (Jul 2024): diff 12→13 — Broken link `[Visual Studio Copilot Chat is now enriched with knowledge bases on ](link)[github.com](link)` → clean `[...enriched with knowledge bases](link) from github.com`.
- **Discussion #13** (Jun 2025): diff 17→18 — `[Workflows Guide]` → `[Agentic Workflows Guide]` (more descriptive). diff 07→08 — `[Visual Studio Agent Mode]` → `[Visual Studio Release Notes]` (more accurate source).
- **Discussion #02** (May 2024): diffs 05→06 / 06→07 — `the launch [blog post]` → `the [launch blog post]` (natural reading). diff 08→09 — Repo URL → Marketplace URL for an Action.
- **Discussion #14** (Aug 2025): diff 06→07 — `[[Changelog]]` → `[[Announcement]]` (more accurate type). diff 07→08 — bare `[text](url)` → `[[text]](url)` bracket format.
- **Discussion #03** (Jun 2024): diff 10→11 — `More resources:` → `Additional resources:`.

**Frequency:** 7/13 discussions (54%). The most common type of single-line rewrite.

**Proposed rule:** After assembly: (1) validate all markdown links render correctly (no broken `](` patterns), (2) prefer Marketplace URLs over raw repo URLs for Actions, (3) use descriptive link text that names the source type (e.g., `[Changelog]`, `[Announcement]`, `[Release Notes]`), (4) move link anchors to natural reading positions.

---

### Pattern 7: Late-Breaking Content Additions

**Description:** New items are added well into the editing cycle as breaking news arrives or as the author remembers items missed in the initial draft. These are typically 1-2 line additions of high-value content.

**Evidence:**
- **Discussion #13** (Jun 2025): diff 25→26 — `Anthropic Claude Sonnet 4 and Claude Opus 4 General Availability` added (news broke same day). diff 13→14 — `Refreshed GitHub Preview Terms` item added. diff 12→13 — Entire `Microsoft Build 2025 Highlights` table added.
- **Discussion #14** (Aug 2025): diff 00→01 — Entire events/webinars section (41 lines) added in first edit. diff 03→04 — JetBrains NES item added as a late-breaking feature.
- **Discussion #15** (Dec 2025): diff 09→10 — Major structural expansion: platform updates section added with Actions custom runner images and Defender for Cloud integration. diff 12→13 — `How to Use Copilot Spaces for Faster Debugging` resource added.
- **Discussion #02** (May 2024): diff 07→08 — Two new metrics repos added. diff 02→03 — Microsoft Build webinar added to both virtual and in-person sections.

**Frequency:** 9/13 discussions (69%). Nearly every newsletter receives at least one content addition after initial publication.

**Proposed rule:** After Phase 4 assembly, hold for 24 hours before finalizing. Check GitHub Changelog, VS Code release notes, and blog for same-day/next-day announcements. Maintain a "late additions checklist" that scans source feeds one more time before publish. This is the hardest pattern to automate but could be partially addressed with a pre-publish source re-scan.

---

### Pattern 8: Wording Precision Micro-Edits

**Description:** Individual words and short phrases are swapped for slightly more precise, natural, or professional alternatives. These are the most numerous edits and the hardest to systematize. Common substitutions include: tightening qualifiers, fixing pronoun references, and removing unnecessary words.

**Evidence:**
- **Discussion #4** (Jul 2024): `and often ask` → `that often ask` (d16→17). `Those integrations` → `Those enhanced GitHub integrations` (d16→17). `for customers like this` → `for those customers` (d23→24). `simple` → `concise` (d24→25). `e.g.` → `i.e.` (d25→26). `curious how to plan` → `curious to know how to plan` (d22→23).
- **Discussion #03** (Jun 2024): `Then, you have to figure out` → `Then you can figure out` (d08→09).
- **Discussion #14** (Aug 2025): `open sourced` → `open source` (d04→05). `instruction generation and per-mode model selection` → `Generate Instructions for your workspace plus per-mode model selection` (more specific, d04→05).
- **Discussion #13** (Jun 2025): `without written customer consent` → `without customer consent` (d14→15, removing redundant "written").

**Frequency:** 10/13 discussions (77%). Present in virtually every editing session.

**Proposed rule:** This is inherently editorial and resists full automation. However, a pre-publish checklist should flag:
- `e.g.` vs `i.e.` usage (verify correct one)
- Passive constructions that could be active
- Redundant qualifiers (`written consent` when just `consent` suffices)
- Pronoun ambiguity (`this` → name the referent)

---

### Pattern 9: Event Listing Format Normalization

**Description:** Event listings get reformatted for consistency: city names are prepended, date formats are standardized, unnecessary columns are removed from tables, and chronological ordering is enforced.

**Evidence:**
- **Discussion #4** (Jul 2024): diff 19→20 — City names added before dates: `August 7-8: [GitHub is at Black Hat USA]` → `Las Vegas - August 7-8: [GitHub is at Black Hat USA]`. Colons changed to format `City - Date`.
- **Discussion #14** (Aug 2025): diff 08→09 — Event table reformatted: `Date | Time (CT) | Event | Categories` column removed the `Time (CT)` column entirely, and category labels simplified (e.g., `Developer Productivity` → `Copilot`).
- **Discussion #13** (Jun 2025): diff 11→12 — In-person events reordered chronologically (SF Jul 1 moved before Berlin Jul 9).
- **Discussion #09** (Jan 2025): diff 04→05 — `Ottowa, BC` → `Ottawa, ON` (city/province fix), `March 27` → `Mar 27` (abbreviated month).

**Frequency:** 5/13 discussions (38%). Every newsletter with an events section adjusts formatting at least once.

**Proposed rule:** Enforce a canonical event format:
- Virtual events: `| Date | Event | Categories |` (no time column)
- In-person events: `- City, ST — **Date** — [Event Name](url)`
- Sort all events chronologically
- Validate city/state/province names against a reference list
- Use 3-letter month abbreviations consistently

---

### Pattern 10: Section Heading Hierarchy Oscillation

**Description:** The author repeatedly toggles between `# Monthly Announcement / ### Sub-heading` and just `# Sub-heading` for the lead section, indicating uncertainty about the correct heading hierarchy. This pattern also appears with `#` vs `##` for sections within the newsletter body.

**Evidence:**
- **Discussion #13** (Jun 2025): diff 09→10 — `# Monthly Announcement / ### GitHub Coding Agent Launch` → `# GitHub Coding Agent Launch`. diff 10→11 — Reverted back to `# Monthly Announcement / ### GitHub Coding Agent Launch`. diff 15→16 — Changed again to `# GitHub Coding Agent Launch`.
- **Discussion #15** (Dec 2025): diff 09→10 — `# GitHub Platform Updates` section added. diff 10→11 — Same section moved and duplicated. diff 11→12 — `# GitHub Code Quality` → `## GitHub Code Quality` (heading level fix).

**Frequency:** 3/13 discussions (23%). Concentrated in the larger, more structured newsletters.

**Proposed rule:** Define and enforce a fixed heading hierarchy:
- `# [Newsletter Title]` — only once, at top
- `# [Lead Section]` — the headline announcement
- `## [Major Category]` — e.g., `## Copilot Latest Releases`, `## Copilot at Scale`
- `### [Sub-section]` — e.g., `### Latest Releases`, `### Upcoming Virtual Events`
Validate hierarchy after assembly: no `#` headings after the lead, no `###` without a parent `##`.

---

### Pattern 11: Clarifying Additions to Existing Items

**Description:** Existing bullet items get parenthetical clarifications, additional context sentences, or qualifying details added. The author enriches terse items with context that helps the reader understand why something matters.

**Evidence:**
- **Discussion #4** (Jul 2024): diff 07→08 — `Copilot Individual usage can now be [blocked at the network level]` → adds `(e.g., personal Copilot accounts that fall outside the enterprise policies)`. diff 08→09 — `upgrade to GPT-4o` expanded to include `on github.com and [Copilot Chat](link)`. diff 11→12 — adds `Copilot Business also received the model upgrade for Chat`.
- **Discussion #15** (Dec 2025): diff 06→07 — Copilot CLI item gets `**Note**: Copilot CLI is covered under the GitHub Data Protection Agreement while in preview` appended + DPA link added. diff 05→06 — Copilot Extensions item gets additional link. diff 07→08 — Preview Models item gets GPT-5.1-Codex-Max added.
- **Discussion #15** (Dec 2025): diff 04→05 — VA reference story gets `at ~$1.25 per user` added (quantitative detail).

**Frequency:** 6/13 discussions (46%). Especially prevalent in the more detailed 2025 newsletters.

**Proposed rule:** During curation (Phase 3), include at least one "so what" sentence per item explaining enterprise relevance. Include quantitative details (cost savings, time saved, % improvement) when available from source material. Flag items that are purely descriptive with no enterprise context for enrichment.

---

### Pattern 12: Sub-bullet Structure Conversion

**Description:** Block-level paragraphs under bullet items are converted to proper nested sub-bullets, or vice versa. The author adjusts the visual density by toggling between paragraph format and list format.

**Evidence:**
- **Discussion #13** (Jun 2025): diff 05→06 — Added `**June updates**:` and `**Enterprise benefits**:` as separate paragraphs. diff 06→07 — Immediately converted these to sub-bullets: `- **June updates**:` and `- **Enterprise benefits**:`.
- **Discussion #13** (Jun 2025): diff 06→07 — `> Note:` blockquote indentation adjusted from 4 spaces to 8 spaces.

**Frequency:** 2/13 discussions (15%). Appears when multi-paragraph items are created.

**Proposed rule:** Use sub-bullets (not paragraphs) for multi-point items. Format: parent bullet with short intro, then `    - **Label:** detail` for each sub-point. Limit to 3 sub-bullets per item maximum.

---

### Pattern 13: Typo and Broken Character Fixes

**Description:** Broken characters (Unicode replacement characters, extra spaces, spelling errors) are fixed in quick successive edits.

**Evidence:**
- **Discussion #3** (Jun 2024): diff 03→04 — `￼` (Unicode object replacement character U+FFFC) removed.
- **Discussion #13** (Jun 2025): diff 26→27 — `**Copilot Enterprise** s)` → `**Copilot Enterprise**)` (extra space before closing paren).
- **Discussion #9** (Jan 2025): diff 04→05 — `Ottowa` → `Ottawa`, `playlist's` → `playlists`.
- **Discussion #2** (May 2024): diff 01→02 — `San Francisco-` → `San Francisco -` (space fix).

**Frequency:** 4/13 discussions (31%).

**Proposed rule:** Run automated checks after assembly:
- No Unicode control characters (U+FFFC, U+200B, etc.)
- No double spaces
- Spell-check city names, product names against a canonical list
- No space before `)` or after `(`

---

## 3. Discussion-Specific Patterns

### Discussion #4 (Jul 2024) — ADO Migration Messaging Iteration
The Azure DevOps migration section was rewritten 4 times (diffs 16→17, 17→18, 18→19, 22→23) with each pass refining the framing from "I have many customers" (personal) to "Customers paying attention" (objective) to the final section title change from `"Better Together" story` to `What is "Better Together?"`. This shows the author iteratively de-personalizing enterprise messaging and making the narrative more consultative.

### Discussion #13 (Jun 2025) — Coding Agent Naming Flip-Flop
The title item `Agent vs Agent Mode Clarification` was renamed to `Coding Agent vs Agent Mode Clarification` (diff 24→25), then reverted to `Agent vs Agent Mode` (diff 26→27), then changed back to `Coding Agent vs Agent Mode` (diff 27→28). This 3-revision oscillation shows genuine uncertainty about the official feature name.

### Discussion #15 (Dec 2025) — Structural Reorganization
Diffs 09→10 and 10→11 show a significant structural reorganization: content was moved from a bottom `# GitHub Platform Updates` section to be interleaved higher in the newsletter alongside related Copilot content. This demonstrates a pattern of late-stage section reordering to improve narrative flow.

### Discussion #9 (Jan 2025) — Content Reordering and Item Promotion
Diffs 05→06 show a significant edit where the Copilot Metrics API item was demoted from a "Latest Releases" bullet to a "Training" resource, and a new `Copilot Content Exclusions` item was promoted into the releases slot. Demonstrates that item hierarchy within sections gets adjusted to prioritize higher-impact items.

### Discussion #14 (Aug 2025) — Event Table Simplification
Diff 08→09 completely reformatted the event table, removing the `Time (CT)` column and simplifying category labels. This suggests the initial event table format was too detailed for the audience and needed simplification for readability.

---

## 4. Recommendations for Automated Polishing Rules

### Tier 1: Zero-risk structural fixes (apply automatically)

| # | Rule | Regex / Check | Source Patterns |
|---|------|--------------|----------------|
| 1 | Space after heading hashes | `^(#{1,6})(\S)` → `$1 $2` | #1 |
| 2 | Normalize bullets to `-` | Replace `^[•*] ` with `- ` at top level | #2 |
| 3 | Remove broken Unicode chars | Strip U+FFFC, U+200B, U+FEFF | #13 |
| 4 | No double spaces | `  +` → ` ` (except indentation) | #13 |
| 5 | Fix space before `)` | `\s+\)` → `)` | #13 |
| 6 | Consistent month abbrevs | `January` → `Jan`, etc. in event dates | #9 |
| 7 | Heading hierarchy validation | No `#` after lead section; `###` must have `##` parent | #10 |

### Tier 2: Content-aware fixes (apply with review)

| # | Rule | Implementation | Source Patterns |
|---|------|---------------|----------------|
| 8 | Product name capitalization | Dictionary lookup: `coding agent` → `Coding Agent`, etc. | #4 |
| 9 | Status label format | Normalize to `` (`GA`) `` / `` (`PREVIEW`) `` | #3 |
| 10 | Link syntax validation | Verify all `[text](url)` render correctly | #6 |
| 11 | Chronological event sorting | Sort events by date ascending | #9 |
| 12 | Sub-bullet format | Convert inline paragraphs under bullets to `    - ` | #12 |

### Tier 3: Editorial guidelines (human or LLM judge)

| # | Rule | Guideline | Source Patterns |
|---|------|-----------|----------------|
| 13 | Write intro last | Generate highlights summary from finalized body | #5 |
| 14 | Pre-publish source re-scan | Check feeds for same-day announcements | #7 |
| 15 | Enterprise context check | Every item needs a "so what" for the reader | #11 |
| 16 | Wording precision review | Flag `e.g.`/`i.e.` usage, passive voice, pronoun ambiguity | #8 |
| 17 | Link text accuracy | Verify link labels match source type (Changelog vs Announcement) | #6 |

### Priority Order for Implementation

1. **Tier 1 rules 1-7** — Implement immediately in `tools/score-structural.sh` or as a post-assembly formatting pass. These are deterministic, zero-risk, and eliminate ~20% of polishing edits.
2. **Product name dictionary (rule 8)** — Highest-value Tier 2 rule. Build canonical dictionary in `reference/product-names.yaml` and apply as a find-replace pass.
3. **Status label normalization (rule 9)** — Medium effort, high consistency payoff. Regex-based.
4. **Intro-last guideline (rule 13)** — Modify Phase 4 assembly prompt to generate intro paragraph as the final step, using section headings/items as input.
5. **Pre-publish re-scan (rule 14)** — Add a 24h delay or a "final check" step that re-queries key source feeds.

---

## 5. Quantitative Impact Estimate

If these rules had been applied automatically before human polishing:

| Pattern | Estimated diffs prevented | % of total 132 |
|---------|--------------------------|----------------|
| Heading space (#1) | 4 | 3% |
| Bullet normalization (#2) | 8 | 6% |
| Label format (#3) | 6 | 5% |
| Product names (#4) | 7 | 5% |
| Link fixes (#6) | 10 | 8% |
| Typo/char fixes (#13) | 5 | 4% |
| Event formatting (#9) | 5 | 4% |
| **Tier 1 total** | **~45** | **~34%** |

The remaining ~66% of edits are content additions (can't automate), wording precision (requires editorial judgment), and structural reorganization (requires understanding of narrative flow). These are best addressed through stronger Phase 3/4 prompts (patterns #5, #7, #8, #11) rather than post-processing fixes.

---

## 6. Formatting Intelligence (from Final Published Versions)

### Bullet Anatomy Standard

Every feature bullet follows this anatomy:
```
-   **Feature Name (`STATUS`)** -- Description with enterprise context. - [Label](URL) | [Label2](URL2)
```

Components in order:
1. `-   ` (dash + 3 spaces for top-level)
2. `**Feature Name**` (bold)
3. ` (`STATUS`)` (space, backtick-wrapped label in parens)
4. ` -- ` (space-dash-dash-space for description delimiter)
5. Description sentence(s) with enterprise context
6. ` - ` (space-hyphen-space as links separator)
7. `[Label](URL) | [Label2](URL2)` pipe-separated links

### Bold Text Grammar

| Element | Bold? | Format |
|---------|-------|--------|
| Product names | Yes | **GitHub Copilot**, **VS Code**, **JetBrains** |
| Feature title (bullet start) | Yes | **Agent HQ & Enterprise AI Controls** |
| Status labels | No (backtick) | `` (`GA`) ``, `` (`PREVIEW`) `` |
| Technical standards | Yes | **MCP**, **OAuth**, **SAML**, **DPA** |
| Model names and versions | Yes | **GPT-5.1**, **Claude Opus 4.5** |
| Acronyms (first use) | Yes | **NES** (Next Edit Suggestions) |
| Generic nouns/verbs | No | enterprise, supports, enables |
| Section framing intros | Yes prefix | **Theme Name** -- Enterprise value sentence |

### Link Format Standard

- Single brackets only: `[Label](URL)` -- never `[[Label]](URL)`
- Multiple links separated by ` | ` (space-pipe-space)
- Link labels indicate source type: `[Changelog]`, `[Announcement]`, `[Release Notes]`, `[Docs]`, `[Article]`, `[Repo]`
- Prefer descriptive labels over generic ones: `[Code Review](url)` not `[Link](url)`

### Section Framing Intro Pattern

Subsections with 3+ bullets open with a bold framing sentence before the bullet list:
```markdown
### Copilot Agents Expansion

**Agentic Capabilities Everywhere** -- A massive rollout of agentic capabilities
across all IDEs transforms Copilot from a code completion tool into a proactive
partner that can plan, execute, and validate complex tasks.

-   **Plan Agent (`GA` in VS Code, `PREVIEW` elsewhere)** -- ...
```

### Events Category Taxonomy

Virtual event categories (canonical, no others):
- `Copilot` | `Copilot, Advanced` | `Copilot, New Features`
- `GHAS` | `GHAS, Security`
- `Enterprise` | `GitHub Platform`

Never use: `Developer Productivity`, `Platform` (alone), `Security` (alone).

### Status Label Accuracy Rules

- Never assume GA in one IDE because another IDE is GA
- For JetBrains/Eclipse/Xcode: default to PREVIEW unless explicitly stated GA
- Use qualified labels: `` (`GA` in VS Code, `PREVIEW` elsewhere) ``
- Add policy notes when features require admin enablement

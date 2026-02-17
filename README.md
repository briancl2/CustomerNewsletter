# CustomerNewsletter

A public, reusable system for drafting enterprise-focused Copilot newsletters.

## Start Here

- Start here (Feb 2026 launch):
  [Start here](https://briancl2.github.io/CustomerNewsletter/launch/2026-02/start-here/)
- Current newsletter:
  [February 2026 newsletter (Discussion #18)](https://github.com/briancl2/CustomerNewsletter/discussions/18)
- Last newsletter:
  [December 2025 newsletter (Discussion #15)](https://github.com/briancl2/CustomerNewsletter/discussions/15)

## Run It

### VS Code Copilot Chat

1. Open this repo in VS Code.
2. Open Copilot Chat and select the `customer_newsletter` agent.
3. Paste this prompt:

```text
i want you to generate a from-scratch brand new february newsletter using the dates Dec 5 2025 to Feb 13 2026
```

### Copilot CLI

Headless mode:

```bash
copilot --agent customer_newsletter \
  --model claude-opus-4.6 \
  --allow-all \
  --no-ask-user \
  -p "i want you to generate a from-scratch brand new february newsletter using the dates Dec 5 2025 to Feb 13 2026"
```

Interactive mode:

```bash
copilot --agent customer_newsletter --model claude-opus-4.6 -i
```

Then paste the same prompt from the VS Code section.

## Principles

- **HIGR:** treat changes like experiments (Hypothesize → Implement → Grade → Rework), not one-off edits.
- **Feed-forward learning:** when something is consistently off, fix the underlying skill/rule so future runs improve.
- **Trust disk, not self-reports:** the system proves work by writing artifacts to `workspace/` and validating them.
- **Layered scoring:** cheap checks first (structure/heuristics), then deeper rubric checks when needed.
- **Skills-first architecture:** domain rules live in `.github/skills/`; the agent stays thin and orchestrates phases.

## Architecture

At a high level, the system is a multi-phase pipeline plus a self-learning loop.

- **End-to-end pipeline:** URL manifest → content retrieval → consolidation → curator notes (optional)
  → event sources → events → content curation → assembly → polishing → validation + scoring.
- **Self-learning loop:** human corrections → learning capture → skill/reference update → regenerate
  → validate + score → future runs improve.
- **Key interfaces:**
  - Agent entrypoint: `.github/agents/customer_newsletter.agent.md`
  - Phase skills: `.github/skills/*/SKILL.md`
  - Phase prompts: `.github/prompts/*.prompt.md`
  - Fresh-cycle prep: `tools/prepare_newsletter_cycle.sh`
  - Strict validation: `tools/validate_pipeline_strict.sh`
  - Deterministic event sources: `kb/EVENT_SOURCES.yaml`, `tools/extract_event_sources.py`

More detail: [docs/architecture.md](docs/architecture.md)

## What You Should See

- Final draft written to `output/2026-02_february_newsletter.md`
- A paper trail in `workspace/` showing what was collected and curated along the way

## Docs

- Launch (Feb 2026):
  - [Start here](docs/launch/2026-02/start-here.md)
  - [Case study](docs/launch/2026-02/case-study.md)
  - [Timeline](docs/launch/2026-02/timeline.md)
- [How it works](docs/how-it-works.md)
- [Architecture](docs/architecture.md)
- [Feb 2026 system report](docs/reports/newsletter_system_report_2026-02.md)

## Repo Layout

- `.github/agents/`: the Copilot agent entrypoints
- `.github/skills/`: the phase skills (the real “how it works”)
- `.github/prompts/`: prompt files the agent uses for each phase
- `kb/`: source intelligence and source lists
- `reference/`: editorial intelligence and other long-lived guidance
- `tools/`: scoring + validation scripts
- `workspace/`: intermediate artifacts produced during a run
- `output/`: final newsletter drafts
- `archive/`: historical newsletters by year


## How It Was Done

A handful of prompts did most of the heavy lifting, then the system got tightened up through
iterative runs.

More context: [Feb 2026 launch timeline](docs/launch/2026-02/timeline.md)

### Kickoff

~~~text
Fleet deployed: i want to plan for a large project that will take multiple steps, multiple
agents, and a number of subdivided tasks. I want this plan to generate a large discovery to
start and then generate a detailed multi-stage migration plan for the Newsletter portion of
this repo

the work is to 1) extract the Newsletter portion of this repo (e.g., a) newsletter archive,
b) newsletter generation mechanisms such as prompts, agents, skills, and reference material,
and c) any other related components that will be useful in the new standalone Newsletter
repo such as skills, agents, system, update mechanisms, etc), and 2) setup the Newsletter
system in a new standalone repo with after migrating the parts from number one over.

i want to do some research to understand how the current Newsletter system relates to the
current repo, i want to understand which parts of this repo need to be either moved or
copied, and i want to create careful verification and validation mechanisms to make sure the
migration was thorough and that the new standalone newsletter repo is function and complete

everything will remain on this local laptop, so the filesystem will be fully accessible for
the entire project to cross validate

it is important to me that we also identify the overall current state of the newsletter
generation process (prompts, agents, reference material, instructions). We will move it as-
is, but we’d like to know where the process can be improved and enhanced
~~~

### Git History Mining

<details>
<summary>Open the prompt</summary>

~~~text
/fleet Extract newsletter creation benchmark data from git history for AI training.

## Objective

Mine this repo's git history to extract every newsletter creation cycle's full lifecycle —
from raw link accumulation through iterative drafting to published output. Structure the
extracted data for an AI agent to learn newsletter creation patterns, editorial judgment,
and iterative refinement behaviors.

Write everything under: Planning/newsletter_benchmark_data/

## Shared Context (all agents need this)

### Repo & Git Basics
- Working directory: /Users/briancl2/Documents/Obsidian Vault (a git repo)
- Newsletter files historically lived at: Newsletter/{YYYY}/{Month}.md, Spaces/Newsletter
Space/*.md
- Agent/prompts at: .github/agents/customer_newsletter.agent.md,
.github/prompts/agentic_newsletter_phase_*.prompt.md
- These files were DELETED on 2026-02-09 (commit 3a528dd9) during migration — but ALL
history is intact via git show/log/diff
- The commit BEFORE the deletion is the parent of 3a528dd9 — use git rev-parse 3a528dd9^ for
last state

### Published Dates (from github.com/briancl2/CustomerNewsletter/discussions)

| Cycle ID | Newsletter | Published | Discussion # | Era |
|----------|-----------|-----------|-------------|-----|
| 2024-05 | May 2024 | 2024-05-09 | #2 | pre-agentic |
| 2024-06 | June 2024 | 2024-06-18 | #3 | pre-agentic |
| 2024-07 | July 2024 | 2024-07-31 | #4 | pre-agentic |
| 2024-08 | August 2024 | 2024-08-29 | #5 | pre-agentic |
| 2024-09 | September 2024 | 2024-10-01 | #6 | pre-agentic |
| 2024-10 | October 2024 | 2024-11-01 | #7 | pre-agentic |
| 2024-12 | December 2024 | 2024-12-18 | #8 | pre-agentic |
| 2025-01 | January 2025 | 2025-01-31 | #9 | pre-agentic |
| 2025-02 | February 2025 | 2025-02-28 | #10 | pre-agentic |
| 2025-04 | April 2025 | 2025-04-07 | #11 | transition |
| 2025-05 | May 2025 | 2025-05-13 | #12 | transition |
| 2025-06 | June 2025 | 2025-06-25 | #13 | early-agentic |
| 2025-08 | August 2025 | 2025-08-29 | #14 | agentic |
| 2025-09 | September 2025 | unpublished | — | agentic-draft |
| 2025-12 | December 2025 | 2025-12-03 | #15 | agentic |
| 2026-01 | January 2026 | ~2026-01-31 | — | agentic |

### Newsletter-Related File Paths (for git log queries)
Always search across ALL of these paths:
- Newsletter/
- Spaces/Newsletter Space/
- Archive/Spaces/Newsletter Space/
- .github/agents/customer_newsletter*
- .github/prompts/agentic_newsletter*

### Key Git Commands (use these patterns)
```
# Find commits for a cycle (adjust dates per cycle)
git log --format="%h %ad %s" --date=format:"%Y-%m-%d %H:%M" --after=STARTDATE
--before=ENDDATE --diff-filter=ACDMR -- 'Newsletter/' 'Spaces/Newsletter Space/'
'.github/agents/customer_newsletter*' '.github/prompts/agentic_newsletter*'

# Extract file content at a specific commit
git show COMMIT:"path/to/file"

# Get diff between two commits for a specific file
git diff COMMIT1 COMMIT2 -- "path/to/file"

# List files changed in a commit
git show --name-status --format="" COMMIT -- 'Newsletter/' 'Spaces/Newsletter Space/'
'.github/agents/customer_newsletter*' '.github/prompts/agentic_newsletter*'

# Find when a file first appeared
git log --diff-filter=A --format="%h %ad" --date=short -- "path/to/file"
```

### Output Structure Per Cycle
Each cycle writes to: Planning/newsletter_benchmark_data/{CYCLE_ID}_{month}/
Example: Planning/newsletter_benchmark_data/2025-12_december/

Required files per cycle directory:
1. metadata.json — structured index (see schema below)
2. narrative.md — 30-80 line creation story (how, what changed, why, patterns observed)
3. starting_material/ — raw link files (Month.md content at pre-burst state)
4. snapshots/ — numbered newsletter iterations: 01_description.md, 02_description.md, etc.
5. intermediates/ — phase artifacts if they exist (URL manifests, interim files,
discoveries, events, curated sections)
6. prompts/ — agent and prompt file versions used during cycle (only for agentic-era cycles)
7. final/ — the published newsletter content
8. evolution_diffs/ — diffs between consecutive snapshots showing what changed

### metadata.json Schema
```json
{
  "cycle_id": "2025-12",
  "month": "December 2025",
  "era": "agentic",
  "published_date": "2025-12-03",
  "discussion_number": 15,
  "creation_window": {
    "first_commit": "2025-12-02T11:28",
    "last_commit": "2025-12-05T15:27",
    "duration_hours": 76,
    "link_accumulation_start": "2025-11-26"
  },
  "commit_count": 36,
  "snapshot_count": 3,
  "intermediate_count": 12,
  "prompt_iterations": 4,
  "files_touched": ["list of all files touched in cycle"],
  "commits": [
    {"hash": "abc123", "date": "2025-12-02T11:28", "message": "...", "files_changed":
    ["..."]}
  ],
  "classification": {
    "quality": "rich|medium|sparse",
    "iteration_depth": "deep|moderate|shallow",
    "pipeline_phases_visible": ["1a", "1b", "1c", "2", "3", "4"],
    "prompt_engineering_visible": true,
    "newsletter_evolution_steps": 3,
    "training_value": "high|medium|low",
    "training_value_reason": "..."
  }
}
```

### narrative.md Guidelines
Write each narrative as if briefing an AI agent that will learn from this data:
- What was the starting state (raw links, prior newsletter, context)?
- What creation steps happened in what order?
- Where did iterations occur and what drove them (quality improvements, content additions,
formatting fixes)?
- What patterns are notable (prompt refinement loops, content filtering decisions, editorial
choices)?
- What makes this cycle different from others?
- What would an autonomous agent need to replicate this cycle?

## File Write Safety
Each extraction agent writes ONLY to its assigned cycle directories. No shared files.
The VALIDATE and ANALYZE agents write ONLY to the root Planning/newsletter_benchmark_data/
directory (no cycle subdirectories).

## Wave 1: Extraction (6 agents in parallel)

### Agent EXTRACT-2024-EARLY
Cycles: 2024-05_may, 2024-06_june, 2024-07_july, 2024-08_august
Era: pre-agentic (manual curation, no agent/prompt infrastructure)
Output dirs: Planning/newsletter_benchmark_data/{2024-05_may, 2024-06_june, 2024-07_july,
2024-08_august}/
Notes:
- These are the earliest newsletters. Expected simpler commit patterns.
- No agent file or prompt files existed yet — skip prompts/ subdirectory.
- The Newsletter/{YYYY}/{Month}.md file IS the newsletter; look for iterations in
Spaces/Newsletter Space/ too.
- Link accumulation may have happened in the Month.md file itself over weeks before the
creation burst.
- For starting_material: extract Month.md content at the EARLIEST commit touching it.
- For snapshots: extract Month.md content at each subsequent commit, numbered sequentially.
- For final: extract Month.md content at the LAST commit before the next month's work
begins.
- Look for commits within 14 days before publish date for the creation burst.
- For link accumulation, search up to 30 days before publish date.

### Agent EXTRACT-2024-LATE
Cycles: 2024-09_september, 2024-10_october, 2024-12_december
Era: pre-agentic
Output dirs: Planning/newsletter_benchmark_data/{2024-09_september, 2024-10_october,
2024-12_december}/
Notes:
- Same approach as EXTRACT-2024-EARLY.
- Note: September published Oct 1, October published Nov 1, December published Dec 18.
- November 2024 was skipped — no newsletter exists for it.

### Agent EXTRACT-2025-Q1
Cycles: 2025-01_january, 2025-02_february, 2025-04_april
Era: pre-agentic to transition
Output dirs: Planning/newsletter_benchmark_data/{2025-01_january, 2025-02_february,
2025-04_april}/
Notes:
- March 2025 was skipped.
- April 2025 (published Apr 7) is the FIRST agentic-generated newsletter (april-generated.md
in archive).
- For April: check if agent/prompt files existed at that commit; if so, extract them to
prompts/.
- January and February are likely still pre-agentic manual curation.

### Agent EXTRACT-2025-MAY
Cycle: 2025-05_may (single cycle — expected 24+ commits, heavy workload)
Era: transition
Output dir: Planning/newsletter_benchmark_data/2025-05_may/
Notes:
- This is a CRITICAL cycle — 24+ commits on May 13-14 alone.
- The newsletter template and custom_instructions_newsletter were CREATED during this cycle.
- Multiple iterations of Spaces/Newsletter Space/ files visible.
- Heavy Copilot Spaces usage: look for files in Spaces/Newsletter Space/ created/modified
during this window.
- Extract ALL intermediate Spaces files — they show the drafting process.
- For prompts/: extract the initial custom_instructions_newsletter.md and any template files
created.
- Microsoft Build event content was added in multiple iterations — capture that evolution.
- Also extract Newsletter/prompts/ files that may have been created during this period.

### Agent EXTRACT-2025-MID
Cycles: 2025-06_june, 2025-08_august, 2025-09_september
Era: early-agentic to agentic
Output dirs: Planning/newsletter_benchmark_data/{2025-06_june, 2025-08_august,
2025-09_september}/
Notes:
- June (published Jun 25): early agentic pipeline usage. Look for Phase 2 content curation
prompt creation.
- August (published Aug 29): 11+ commits. New Phase 2 content curation prompt introduced
alongside newsletter content.
- September: NEVER PUBLISHED via discussions. Accumulated links from Sep 24 through Nov 26.
Mark as "draft-only" in metadata. Extract all link accumulation commits. Check if content
was folded into December 2025 newsletter.
- For Aug: look for Spaces/Newsletter Space/ intermediates (discoveries, events, draft
sections).
- For Jun: check for Spaces/Newsletter Space/ intermediates from the May-June date range.

### Agent EXTRACT-2025-LATE
Cycles: 2025-12_december, 2026-01_january
Era: agentic (mature pipeline)
Output dirs: Planning/newsletter_benchmark_data/{2025-12_december, 2026-01_january}/
Notes:
- December 2025 is the RICHEST cycle: 33+ commits on Dec 2 alone, plus Dec 3 and Dec 5.
- Full agentic pipeline visible: agent creation, Phase 1A-4, prompt refinement loops.
- Extract the agent file (.github/agents/customer_newsletter.agent.md) at MULTIPLE commit
points showing its evolution.
- Extract ALL 6 prompt files at their state during this cycle.
- Extract ALL Spaces/Newsletter Space/ intermediates: URL manifest, 5 interim files,
discoveries, events, curated sections.
- The newsletter itself evolved through 3+ versions (157→163→173 lines). Capture each
snapshot.
- 4+ iterations of Phase 1B prompt alone — capture each version in prompts/ with numbered
prefix.
- January 2026: latest newsletter. May have simpler commit history. Extract what exists.
- For January: the file is Newsletter/2026-01 Jan.md (non-standard naming). Check for
creation commits in late January 2026.

## Wave 2: Validation (1 agent, SERIAL — wait for all Wave 1 agents)

### Agent VALIDATE
Depends on: ALL Wave 1 agents completed
Output: Planning/newsletter_benchmark_data/_validation_report.md
Steps:
1. For each of the 16 cycle directories under Planning/newsletter_benchmark_data/:
   - Verify metadata.json exists and is valid JSON
   - Verify narrative.md exists and is non-empty
   - Verify final/ directory has at least 1 file
   - Verify starting_material/ has at least 1 file OR narrative.md explains why not
   - Verify snapshots count matches metadata.json snapshot_count
   - Cross-check commit_count in metadata.json against actual commits found
   - Check that era classification matches the published dates table
2. Verify no two agents wrote to the same directory
3. Produce a summary table:

| Cycle | metadata.json | narrative | snapshots | intermediates | prompts | final | commits
| quality |
4. List any MISSING cycles (gaps in coverage)
5. List any WARNINGS (low snapshot count, missing intermediates for agentic cycles, etc.)
6. Verdict: PASS (all critical checks pass) or FAIL (with specific issues)

Stop rule: Only write _validation_report.md. Do not fix issues.

## Wave 3: Analysis (1 agent, SERIAL — wait for VALIDATE)

### Agent ANALYZE
Depends on: VALIDATE completed with PASS (or PASS with warnings)
Outputs:
- Planning/newsletter_benchmark_data/_extraction_manifest.json
- Planning/newsletter_benchmark_data/_cycle_analysis.md

### _extraction_manifest.json
Master index of all cycles:
```json
{
  "extraction_date": "2026-02-10",
  "source_repo": "github/briancl2-private",
  "total_cycles": 16,
  "total_commits_extracted": N,
  "total_files_extracted": N,
  "cycles_by_era": {"pre-agentic": [...], "transition": [...], "agentic": [...]},
  "cycles_by_quality": {"rich": [...], "medium": [...], "sparse": [...]},
  "cycles": [
    {"id": "2024-05", "path": "Planning/newsletter_benchmark_data/2024-05_may/", "quality":
    "...", ...}
  ],
  "training_recommendations": {
    "best_full_cycle_examples": ["list of cycle IDs with richest beginning-middle-end
    data"],
    "best_iteration_examples": ["cycle IDs with most editorial iterations visible"],
    "best_prompt_engineering_examples": ["cycle IDs with prompt refinement loops"],
    "recommended_training_order": ["cycle IDs in order an AI should study them"]
  }
}
```

### _cycle_analysis.md
Comprehensive analysis for a human reader:
1. **Era Evolution Summary** — How did the newsletter creation process evolve from pre-
agentic to agentic?
2. **Quality Matrix** — Table of all cycles with quality/depth/training-value ratings and
one-line rationale
3. **Pattern Catalog** — Reusable patterns observed across cycles:
   - Link accumulation patterns (how raw material builds up)
   - Content filtering patterns (what gets cut and why)
   - Iteration patterns (what gets refined and how many passes)
   - Prompt engineering patterns (how prompts evolved, what worked)
   - Editorial judgment patterns (tone, structure, audience-targeting decisions)
   - Section ordering patterns (what sections appear, in what order, across months)
4. **Training Data Quality Assessment** — Which cycles have the best training signal? Which
are sparse?
5. **Recommendations for Agent Training** — Specific suggestions for how to use this data to
build an autonomous newsletter agent:
   - What behaviors can be learned from the data
   - What gaps remain (things the human did that aren't captured)
   - What additional data would help
   - Suggested training approach (fine-tuning vs few-shot vs skill extraction)

Stop rule: Write only the two output files. Read metadata.json and narrative.md from all
cycle directories.

## Orchestrator Instructions

1. Dispatch all 6 EXTRACT agents as background tasks (Wave 1). They write to completely
disjoint directories.
2. Poll promptly for completion. All 6 must complete before Wave 2.
3. Dispatch VALIDATE agent (Wave 2). Wait for completion. Read _validation_report.md.
4. If VALIDATE reports PASS or PASS-with-warnings: dispatch ANALYZE agent (Wave 3).
5. If VALIDATE reports FAIL: report failures. Do NOT dispatch ANALYZE. Stop and summarize.
6. After ANALYZE completes: read _cycle_analysis.md and summarize key findings.

Begin now by dispatching all 6 EXTRACT agents as background tasks.
~~~

</details>

### Polishing Intelligence

~~~text
i want to do some cleanup and syncronization for the actual real newsletter archive. the
"shipped" news letter is actually the body of a discussion post here:
https://github.com/briancl2/CustomerNewsletter/discussions

there may be some slight differences between each month's content in this repo and the
shipped version.

can you do a comprehensive review and syncronization of all of the past newsletters in this
repo.

i want one canonical source of newsletter archives here. the archived news letter is a first
class citizen since we will model other things off of the historical record
~~~

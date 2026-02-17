# Timeline (How the System Got Built)

This is a short, public-safe timeline of how the newsletter workflow evolved from
manual writing into a Copilot-assisted system.

## Milestones

- **May 2024:** The newsletter starts as a manual, curated monthly write-up.

- **Late 2024:** Reusable prompts enter the workflow. Faster, but still fragile.

- **2025:** Chat-based workflows help, but the process surface area keeps growing
  (more sources, more steps, more things to keep straight).

- **Feb 10, 2026:** Kickoff. The goal shifts from “write the next issue” to
  “build a system that can draft the next issue.”
  - Full kickoff prompt: see [Kickoff Prompt](#kickoff-prompt)

- **Feb 10, 2026:** Git history mining becomes a first-class input. Instead of only
  training on “finished issues,” the system also mines the incremental edits and
  intermediate artifacts so it can learn how the work actually got done.
  - Prompt excerpt: see [Git History Mining](#git-history-mining)

- **Feb 10, 2026:** Polishing intelligence gets a new data source: what actually
  shipped. The discussion post body becomes the canonical archive, so final edits are
  visible and learnable.
  - Prompt: see [Polishing Intelligence](#polishing-intelligence)

- **Feb 11, 2026:** Editorial notes get treated as durable training signals. Instead
  of re-teaching the same preferences every month, the goal becomes “capture once,
  apply forever.”
  - Prompt: see [Editorial Notes](#editorial-notes)

- **Feb 11, 2026:** A real bug forces discipline: scope and release timing have to be
  correct, and fixes have to propagate so the same miss doesn’t happen again.

Context link: [VS Code v1.108 release notes](https://code.visualstudio.com/updates/v1_108)

```text
so there is defintely something wrong with your ability to parse the dates and relase
timing

see screenshot of
https://code.visualstudio.com/updates/v1_108

this is a bug that needs to get fixed. do a RCA to understnd why you are missing this.
it was covered in detail as important to get right during that pre-flight scoping work
to know the dates in scope and the relases within that date. you missed this 3 times
now, and when i brought it up again, you said you were right to ignore it. thats really
bad

we gotta get this fixed at the source and then propagate that change out so we dont miss
it again
```

- **Feb 13, 2026:** The “one prompt” interface is real. This is the prompt that
  generated the February draft.

```text
i want you to generate a from-scratch brand new february newsletter using the dates Dec 5 2025 to Feb 13 2026
```

## Kickoff Prompt

```text
Fleet deployed: i want to plan for a large project that will take multiple steps,
multiple agents, and a number of subdivided tasks. I want this plan to generate a
large discovery to start and then generate a detailed multi-stage migration plan for
the Newsletter portion of this repo

the work is to 1) extract the Newsletter portion of this repo (e.g., a) newsletter
archive, b) newsletter generation mechanisms such as prompts, agents, skills, and
reference material, and c) any other related components that will be useful in the new
standalone Newsletter repo such as skills, agents, system, update mechanisms, etc), and
2) setup the Newsletter system in a new standalone repo with after migrating the parts
from number one over.

i want to do some research to understand how the current Newsletter system relates to
the current repo, i want to understand which parts of this repo need to be either moved
or copied, and i want to create careful verification and validation mechanisms to make
sure the migration was thorough and that the new standalone newsletter repo is function
and complete

everything will remain on this local laptop, so the filesystem will be fully accessible
for the entire project to cross validate

it is important to me that we also identify the overall current state of the newsletter
generation process (prompts, agents, reference material, instructions). We will move it
as-is, but we’d like to know where the process can be improved and enhanced
```

## Git History Mining

This is the prompt that kicked off mining the git history into benchmark/training data.

```text
/fleet Extract newsletter creation benchmark data from git history for AI training.

## Objective

Mine this repo's git history to extract every newsletter creation cycle's full lifecycle
— from raw link accumulation through iterative drafting to published output. Structure
the extracted data for an AI agent to learn newsletter creation patterns, editorial
judgment, and iterative refinement behaviors.

Write everything under: Planning/newsletter_benchmark_data/
```

## Polishing Intelligence

The shipped newsletter is the discussion post body. Treating that as canonical makes it
possible to learn from the final “last mile” edits.

Discussion index:
- [CustomerNewsletter discussions](https://github.com/briancl2/CustomerNewsletter/discussions)

```text
i want to do some cleanup and syncronization for the actual real newsletter archive.
the "shipped" news letter is actually the body of a discussion post here:
https://github.com/briancl2/CustomerNewsletter/discussions

there may be some slight differences between each month's content in this repo and the
shipped version.

can you do a comprehensive review and syncronization of all of the past newsletters in
this repo.

i want one canonical source of newsletter archives here. the archived news letter is a
first class citizen since we will model other things off of the historical record
```

## Editorial Notes

```text
ok, lets get back to the newsletter.

notes
- "This month's updates tell a single story: customers can now bring any agent, use any
  model, and work from any surface, all powered by their Copilot subscription." -> we
  need to be careful about actual factualness here. "bring any agent, use any model,
  and owrk from any surface" is not a factual claim. the truth is more like "use more
  agents, with more models, from more surfaces, all powered by one Copilot
  subscipriotn. that's one set of terms protecting your data, one payment, one platform
  to manage users,  set budgets, and govern policies" something like that. i'll let you
  workshop that
- "Third-Party Agents on Agent HQ (PREVIEW)" -> since it comes up a lot, customers ask
  if its extra cost, so just put that "covered by existing Copilot Enterprise
  subscriptions consuming the same PRU's"
- the "Announcement" title on links to the changelog should be "Changelog"
- you title blog posts as "CPO Blog" and i have no idea what CPO is??? should that just
  be "GitHub Blog" ?
- GitHub Copilot Now Supports OpenCode (GA) -> "GitHub announced an official
  partnership with OpenCode so existing GitHub Copilot subscribers can use their
  license in OpenCode, a leading CLI coding agent competitive with Claude Code and
  Codex CLI" something like that. workshop it
- add the SDK announcement to the CLI entry. its an add on
- Copilot CLI - i'd love to stack links on this to indicate the insane release veloicy.
  can you stack up like 10 direct links to release notes with major features?
- Copilot CLI is not GA. please link to the legal terms that shows that Copilot CLI is
  covered under DPA and indemnification while in preview. its in a past newsletter
- BYOK - frame this along the lines of how you can bring your github subscription more
  places, that you can also bring your own key into github.

VS Code
- Run more agents in VS Code: cloud agents, background agents, Claude Agent, parallel
  agents, enhanced subagents documentation (go find this in the vs code docs)
- you have agents tab on github.com in the VS Code section. that isnt right
- ACP support is CLI or VS code? i think this is a mistake in either the section you
  wrote or the actual update is in the wrong section
- The IDE parity should be its own section. this should have more detail. you need to
  go to the various IDE's and get more updates. this is an important section. sometimes
  the actual websites like JetBrains can be difficult to navigate. please get through
  the strange website find the release notes. also we sometimes put release notes for
  jetbrains on our changelog. please dive deeper, get more

other:
- are there any updates on GitHub Code Quality or Copilot Code Review?
- you should find all updates since the last newsletter, using the publish date. is
  your scope that large or just the last month? please be specific on what timelines
  you searched for and what you missed
- list out all of the places you looked for events
- is there a strong loop between the pre-work/initial work for an end-to-end generation
  that starts with: "what dates am i looking for? which versions are in scope vs out
  of scope, links to all those sources, etc etc. " that then genreates the intiail data
  that begins the entire process, that at the end of the process creates its own test
  cases? "are any updates from the wrong version? do i have updates for the versions i
  expect? do i have events in the right dates? etc" i feel like we can pre-generate our
  own QA which can drive a test/fix cycle as needed
```

## Patterns Worth Copying

- Start with a prompt that produces a real draft, then harden the workflow from there.
- Separate “what to include” (editorial) from “how it reads” (polish).
- When something goes wrong, fix the underlying rule so it stays fixed.

Try it:
- Repo: [`briancl2/CustomerNewsletter`](https://github.com/briancl2/CustomerNewsletter)
- Published February example: [Discussion #18](https://github.com/briancl2/CustomerNewsletter/discussions/18)

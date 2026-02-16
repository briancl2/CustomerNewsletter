# Timeline (How the System Got Built)

This is a short, public-safe timeline of how the newsletter workflow evolved from
manual writing into a Copilot-assisted system.

## Milestones

- **May 2024:** The newsletter starts as a manual, curated monthly write-up.

- **Late 2024:** Reusable prompts enter the workflow. Faster, but still fragile.

- **2025:** Chat-based workflows help, but the process surface area keeps growing
  (more sources, more steps, more things to keep straight).

- **Feb 10, 2026:** Kickoff. The goal shifts from “write the next issue” to
  “build a system that can draft the next issue.” (See the kickoff prompt in
  [`start-here.md`](./start-here.md).)

- **Feb 10, 2026:** The “scientific loop” becomes explicit: make hypotheses, test,
  measure, learn, iterate. This is what makes the system self-improving instead of
  one-off.

```text
yes! this is what i thought was being built in the first place. i want to create a
robust and thorough automation following our past principles from
#file:autonomous_loops_guide.md and other guidance in this repo to build out a very
complete, iterative, and scientifically sound, data-driven approach to learn what works.
generate hyptoheses, test, measure, learn, adjust, iterate. we can use `fleet` to
parallelize a lot of this work too. lets put soem real firepower behind this. start big
and go wide, then we will refine this into real intelligence. we will also learn where
we have true blind spots and weaknesses where we could potentially collect specific
guidance from the human user through Q&A or even a number of multiple choice prompts
```

- **Feb 11, 2026:** A real bug forces the discipline: scope and release timing have
  to be correct, and fixes have to propagate so the same miss doesn’t happen again.

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

## Patterns Worth Copying

- Start with a prompt that produces a real draft, then harden the workflow from there.
- Separate “what to include” (editorial) from “how it reads” (polish).
- When something goes wrong, fix the underlying rule so it stays fixed.

Try it:
- Repo: [`briancl2/CustomerNewsletter`](https://github.com/briancl2/CustomerNewsletter)
- Published February example: [Discussion #18](https://github.com/briancl2/CustomerNewsletter/discussions/18)

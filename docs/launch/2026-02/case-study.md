# Case Study (Public Cut)

## Executive Summary

- **Problem:** Customers (and GitHub teams) are drowning in Copilot-related updates
  scattered across release notes, changelogs, blogs, and IDE surfaces.
- **Approach:** Use shipped Copilot features to build a Copilot-assisted workflow
  that gathers updates, dedupes them, and drafts a monthly issue from one prompt.
- **Result:** The February 2026 issue was produced with a one-line prompt and then
  refined through lightweight editorial review.
- **Reusable idea:** Draft fast, then improve the system over time by turning your
  recurring edits into durable rules.
- **Try it:** Start with [`start-here.md`](./start-here.md), then run it in
  [`briancl2/CustomerNewsletter`](https://github.com/briancl2/CustomerNewsletter).

## The Story

I started writing this newsletter because Copilot changes stopped fitting into any
single “release notes” page. Updates show up across VS Code, GitHub.com, multiple
IDEs, and the CLI, and the practical question from customers is always the same:
“What changed, and what should we do next?”

For a while, the workflow was manual plus a handful of reusable prompts. That helped,
but over time it created a new problem: the prompts and the process became their own
moving target.

The shift in February 2026 was to treat this as a system-building exercise, not a
writing exercise. The goal was simple: one prompt should generate a solid draft, and
every month’s corrections should improve the next run.

Two things helped that click into place:
- **A real corpus:** finished issues (what “good” looks like) plus the messy
  intermediate edits (how “good” was reached).
- **A loop, not a one-shot:** generate, review, distill the feedback into rules,
  then re-run.

That led to two kinds of “intelligence” that live in the workflow:
- **Editorial intelligence:** selection and framing (what belongs in the issue, what
  to skip, how to prioritize).
- **Polishing intelligence:** finishing moves (tightening, formatting, link hygiene,
  labeling).

The most important habit change was this: when something is wrong, fix the underlying
rule so it stays fixed. A good monthly workflow is less about perfect first drafts and
more about a reliable loop.

One concrete example: if you find yourself repeating the same edits every month (link
labels, section ordering, over-confident phrasing, mixing GitHub.com items into IDE
sections), that’s not “polish.” That’s a rule the system is missing. Capturing it once
is how the next run starts closer to your voice.

Another example: scope bugs are fatal in a newsletter. If the system quietly uses the
wrong date window, it can feel coherent and still be wrong. Treat scope as a first-
class requirement and keep a habit of checking that the output actually reflects the
requested range.

## What’s Included / Not Included

Included:
- A runnable repo that can generate a February-style draft:
  [`briancl2/CustomerNewsletter`](https://github.com/briancl2/CustomerNewsletter)
- A published example issue to compare against:
  [Discussion #18](https://github.com/briancl2/CustomerNewsletter/discussions/18)
- A short evolution timeline: [`timeline.md`](./timeline.md)

Full technical report (long, technical):
- [Feb 2026 system report](https://briancl2.github.io/CustomerNewsletter/reports/newsletter_system_report_2026-02/)

Not included:
- Private session logs, internal-only tooling, or any customer-specific information

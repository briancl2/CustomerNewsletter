# Start Here

Copilot (and the AI dev toolchain around it) is changing fast across VS Code,
GitHub.com, IDEs, and the CLI. This repo turns that flood into a monthly newsletter
draft, plus a trail in `workspace/` showing how it got there.

Two links up front:
- Runnable repo: [`briancl2/CustomerNewsletter`](https://github.com/briancl2/CustomerNewsletter)
- Published February issue: [Discussion #18](https://github.com/briancl2/CustomerNewsletter/discussions/18)

Also in this folder:
- [Case study](./case-study.md)
- [Timeline](./timeline.md)

Full technical report (long, technical):
- [Feb 2026 system report](https://briancl2.github.io/CustomerNewsletter/reports/newsletter_system_report_2026-02/)

## VS Code Copilot Chat

1. Open the repo in VS Code.
2. Open Copilot Chat and select the `customer_newsletter` agent.
3. Paste this prompt:

```text
i want you to generate a from-scratch brand new february newsletter using the dates Dec 5 2025 to Feb 13 2026
```

If you want a cleaner, more repeatable run, follow up with:

```text
Run it as a clean cycle (no reuse) for START=2025-12-05 and END=2026-02-13.

At the end, run the repo's validators and fix what they flag.

If something's consistently off, fix the rule/skill so it stays fixed.
```

## Copilot CLI

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

## What You Should See

- Final draft written to `output/2026-02_february_newsletter.md`
- A paper trail in `workspace/` showing what was collected and curated along the way

## Changing the Date Range

You can reuse the same idea for another window. In VS Code Copilot Chat, try:

```text
Please generate a newsletter draft for START=<YYYY-MM-DD> and END=<YYYY-MM-DD>.
```

## Two Prompts That Did Most of the Work

Kickoff prompt (verbatim excerpt):

```text
Fleet deployed: i want to plan for a large project that will take multiple steps,
multiple agents, and a number of subdivided tasks. I want this plan to generate a large
discovery to start and then generate a detailed multi-stage migration plan for the
Newsletter portion of this repo
```

One-line run prompt (the one you can keep reusing):

```text
i want you to generate a from-scratch brand new february newsletter using the dates Dec 5 2025 to Feb 13 2026
```

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

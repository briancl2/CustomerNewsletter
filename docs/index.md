# CustomerNewsletter

A public, reusable system for drafting enterprise-focused Copilot newsletters.

## Start Here

If you only read one page, start here:
- [Start here (Feb 2026)](launch/2026-02/start-here.md)

Then, if you want the backstory:
- [Short case study](launch/2026-02/case-study.md)
- [Timeline](launch/2026-02/timeline.md)

Want to see a real shipped example?
- [Published February issue (Discussion #18)](https://github.com/briancl2/CustomerNewsletter/discussions/18)

## Try It

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

## Docs

- [How it works](how-it-works.md)
- [Architecture](architecture.md)
- [Feb 2026 system report](reports/newsletter_system_report_2026-02.md)

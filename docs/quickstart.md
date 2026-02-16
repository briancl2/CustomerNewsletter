# Quickstart

## Path A: VS Code Agent Mode (recommended)

1. Open the repository in VS Code.
2. Select the `customer_newsletter` agent in `.github/agents/customer_newsletter.agent.md`.
3. Confirm `config/profile.yaml` values.
4. Run:

```bash
make validate-structure
make validate-all-skills
make newsletter START=2026-01-01 END=2026-02-10
make validate-newsletter FILE=output/2026-02_february_newsletter.md
```

5. Review generated artifacts in `workspace/` and final output in `output/`.

## Path B: CLI-first

### Prerequisites

- `python3`
- `make`
- Optional but recommended: `copilot` CLI for agent-assisted loops

### Deterministic checks

```bash
make validate-structure
make validate-all-skills
make test-validator
make score-all
```

### Orchestrated generation

```bash
make newsletter START=2026-01-01 END=2026-02-10
```


If `copilot` CLI is unavailable, use deterministic checks and edit skill files manually.

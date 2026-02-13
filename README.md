# CustomerNewsletter

Open-source, skills-based system for generating enterprise-focused monthly Copilot newsletters.

This repository is the public product surface for the February 2026 release and includes:
- A reusable newsletter generation system (agents, skills, prompts, tools, scoring)
- A sample generated issue: `output/2026-02_february_newsletter.md`
- A full build report documenting the transformation to a self-learning workflow

## Quick Start

### Path A: VS Code Agent Mode (recommended)
1. Open this repository in VS Code.
2. Use the `customer_newsletter` agent from `.github/agents/customer_newsletter.agent.md`.
3. Run the pipeline gates with:

```bash
make validate-structure
make validate-all-skills
make newsletter START=2026-01-01 END=2026-02-10
make validate-newsletter FILE=output/2026-02_february_newsletter.md
```

### Path B: CLI-first
Prerequisites:
- `python3`
- `make`
- GitHub Copilot CLI (`copilot`) for agent-assisted paths

Deterministic checks (no Copilot required):

```bash
make validate-structure
make validate-all-skills
make test-validator
make score-all
```

## Documentation

- Docs site source: `docs/`
- Site config: `mkdocs.yml`
- Architecture walkthrough: `docs/architecture.md`
- System report (verbatim): `docs/reports/newsletter_system_report_2026-02.md`
- Report context note: `docs/reports/newsletter_system_report_2026-02_context.md`
- Legacy-to-modern mapping: `docs/legacy/README.md`
- Maintenance/sync model: `docs/how-we-maintain-this.md`

## Included Samples

- `output/2026-02_february_newsletter.md`
- `archive/2025/December.md`
- `archive/2024/June.md`

## System Overview

| Component | Count | Location |
|---|---:|---|
| Agents | 3 | `.github/agents/` |
| Skills | 17 | `.github/skills/` |
| Pipeline prompts | 6 phases + orchestrator | `.github/prompts/` |
| Scoring tools | 7 | `tools/score-*.sh` |
| Knowledge sources | 72 | `kb/SOURCES.yaml` |

## Legacy Artifacts

The pre-overhaul public prompts/chatmode are preserved under:
- `legacy/2026-02_pre-overhaul/`
- `legacy/README.md`

## License

MIT. See `LICENSE`.

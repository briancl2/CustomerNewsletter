# Architecture

## End-to-End Pipeline

```mermaid
flowchart LR
  A["Phase 1A URL Manifest"] --> B["Phase 1B Content Retrieval"]
  B --> C["Phase 1C Consolidation"]
  D["Phase 2 Events Extraction"] --> E["Phase 4 Assembly"]
  C --> F["Phase 3 Content Curation"]
  F --> E["Phase 4 Assembly"]
  E --> G["Validation and Scoring"]
```

## Self-Learning Propagation

```mermaid
flowchart LR
  H["Human Corrections"] --> I["Learning Capture"]
  I --> J["Skill and Reference Updates"]
  J --> K["Regeneration"]
  K --> L["Validation and Scoring"]
  L --> M["Future Runs Improve"]
```

## Interfaces and Artifacts

- Config: `config/profile.yaml`
- Agent entrypoint: `.github/agents/customer_newsletter.agent.md`
- Phase skills: `.github/skills/*/SKILL.md`
- Phase prompts: `.github/prompts/phase_*.prompt.md`
- Output sample: `output/2026-02_february_newsletter.md`

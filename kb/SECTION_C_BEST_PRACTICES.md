# Section C: Best Practices (Portable-First)

## State Header

- **AS_OF_DATE:** 2026-02-10
- **LAST_RUN_DATE:** 2026-02-10

## Portability Baseline

- Default reusable artifact location: `.agents/skills`.
- Store long-lived capability packs as `SKILL.md`-based assets and keep them tool-agnostic.
- Keep platform-specific wiring thin: adapters should reference portable assets, not duplicate them.

## 1) Prompting and Instruction Design

### Portable Recommendations

1. Write instruction stacks in layers: global standards, repo conventions, task-specific constraints.
2. Require evidence-based outputs: include source links, changed files, and validation steps.
3. Use explicit acceptance criteria and failure conditions.
4. Prefer deterministic templates for recurring tasks (for example PR review, refactor, migration).
5. Convert repeated misses into reusable skill instructions in `.agents/skills`.

### Reusable Deliverables

- `/.agents/skills/<capability>/SKILL.md`
- Prompt templates with:
  - context requirements
  - expected output format
  - validation checklist

### Platform-Specific Exception (Labeled)

> **Platform-specific exception (GitHub Copilot):** Official docs include `.github/copilot-instructions.md`, `AGENTS.md`, and `.github/instructions/*.instructions.md`. For cross-platform reuse, keep canonical instructions in `.agents/skills` and project-level adapters minimal.

## 2) Tool Use and Action Safety

### Portable Recommendations

1. Default to least privilege for tool execution and credentials.
2. Gate mutating actions with explicit checks (test pass, lint pass, policy checks).
3. Separate read-only reconnaissance from write/execute phases.
4. Require audit logs for autonomous workflows (inputs, decisions, outputs).
5. Use allowlists for network domains and external tools where possible.

### Reusable Deliverables

- Safety policy skill (`.agents/skills/safety-policy/SKILL.md`) with:
  - permission model
  - risky-command policy
  - escalation rules

### Platform-Specific Exception (Labeled)

> **Platform-specific exception (GitHub Actions agent workflows):** apply GitHub-specific permissions and safe output channels (`gh-aw` style) while keeping safety logic portable.

## 3) Evals and Regression Testing

### Portable Recommendations

1. Maintain golden task sets for core workflows.
2. Track pass/fail and quality scores over time (not only single-run outcomes).
3. Add regression tests when a miss appears; do not rely on memory alone.
4. Run pre-merge eval slices and scheduled full evals.
5. Record model/version/prompt metadata for every eval run.

### Reusable Deliverables

- `evals/golden/` test sets
- `evals/scorecards/` monthly summaries
- `evals/regression-policy.md`

### Platform-Specific Exception (Labeled)

> **Platform-specific exception:** if a vendor surface lacks native eval support, run eval harnesses externally (for example `promptfoo`, `openai/evals`) and feed results back into workflow gates.

## 4) RAG for Codebases

### Portable Recommendations

1. Index code and docs with metadata (repo, path, owner, last-modified, trust level).
2. Constrain retrieval scope by task intent and ownership boundaries.
3. Require citation output for retrieved facts used in decisions.
4. Budget context windows explicitly (critical files first, then optional references).
5. Purge or downgrade stale sources from retrieval indices.

### Reusable Deliverables

- Retrieval profile definitions (by task type)
- Citation policy template
- Source freshness policy (max staleness windows)

## 5) Orchestration Patterns (Plans, Skills, Handoffs, Memory, Guardrails)

### Portable Recommendations

1. Use plan-execute-review cycles with explicit state transitions.
2. Treat skills as modular capabilities, not monolithic prompts.
3. Record handoff packets (goal, constraints, artifacts, next checks).
4. Keep memory artifacts explicit and version-controlled when possible.
5. Add meta-monitoring for loops, stalls, and regressions in long-running agents.

### Reusable Deliverables

- orchestration contract templates
- handoff schema
- loop detection checklist

## 6) Operational Enablement (Rollout, Governance, Measurement)

### Portable Recommendations

1. Roll out by risk tier: pilot, controlled expansion, broad enablement.
2. Define ownership for prompts, skills, and policy exceptions.
3. Track ROI with outcome metrics (cycle time, escaped defects, rework).
4. Maintain incident reviews for agent failures and turn findings into policy/tests.
5. Re-certify source-of-truth maps monthly.

### Reusable Deliverables

- adoption playbook
- governance RACI
- monthly KPI dashboard template
- failure postmortem template

## Deprecated / Historical Context

- `.github/instructions/*.instructions.md` appears in current official Copilot docs, but this KB treats it as a **legacy platform-specific location** for portability governance.
- Preferred reusable pattern: `.agents/skills` with thin per-platform adapters.

## Source Pointers

- GitHub Copilot docs/custom instructions/matrix: https://docs.github.com/en/copilot
- Anthropic prompting best practices: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- Anthropic model updates: https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-6
- OpenAI eval flywheel: https://developers.openai.com/cookbook/examples/evaluation/building_resilient_prompts_using_an_evaluation_flywheel
- MCP specification: https://modelcontextprotocol.io/specification/latest
- Agent Skills specification: https://agentskills.io/specification.md

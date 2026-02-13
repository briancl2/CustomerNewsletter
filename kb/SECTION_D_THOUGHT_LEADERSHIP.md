# Section D: Thought Leadership (High-Signal)

## Curation Criteria

- Durable frameworks over tool hype.
- Concrete operational guidance (not only opinion).
- Decision utility across changing model versions.

## 1) Welcome to Peli's Agent Factory

- **Link:** https://github.github.io/gh-aw/blog/2026-01-12-welcome-to-pelis-agent-factory/
- **Tags:** `agents`, `orchestration`, `security`, `operations`
- **Why it matters:**
  - Shows large-scale practical use of many specialized repository agents.
  - Highlights guardrails, observability, and auditable workflows.
  - Demonstrates meta-agent patterns (agents that monitor other agents).
  - Frames cost/quality tradeoffs with real operational context.
- **Decisions informed:** tool selection for automation frameworks, workflow architecture, safety controls, governance model.

## 2) Turning Agent Misses into Systemic Improvements

- **Link:** https://jonmagic.com/posts/turning-agent-misses-into-systemic-improvements/
- **Tags:** `evals`, `skills`, `feedback-loop`, `quality`
- **Why it matters:**
  - Converts repeated agent misses into durable process assets (tests, skills, constraints).
  - Emphasizes reducing manual steering through better observability.
  - Gives concrete examples of workflow hardening (schema checks, visual QA, test harnesses).
- **Decisions informed:** incident-to-improvement loop design, where to invest in reusable skills, regression policy design.

## 3) OpenAI Evaluation Flywheel

- **Link:** https://developers.openai.com/cookbook/examples/evaluation/building_resilient_prompts_using_an_evaluation_flywheel
- **Tags:** `evals`, `prompting`, `measurement`
- **Why it matters:**
  - Provides a practical iteration loop for prompt/system reliability.
  - Reinforces benchmark and regression discipline over ad-hoc experimentation.
  - Useful for converting subjective quality concerns into measurable tests.
- **Decisions informed:** eval strategy, CI gating, scorecard design, failure triage prioritization.

## 4) Anthropic Prompting Best Practices

- **Link:** https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- **Tags:** `prompting`, `instruction-design`, `safety`
- **Why it matters:**
  - Strong tactical guidance for instruction clarity and decomposition.
  - Helps standardize role, context, and output constraints.
  - Supports portable prompting principles across model vendors.
- **Decisions informed:** prompt template design, instruction hierarchy policy, output contract formats.

## 5) Anthropic Model Update Pages

- **Link:** https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-6
- **Tags:** `models`, `change-management`, `risk`
- **Why it matters:**
  - Documents model behavior changes that can impact agent workflows.
  - Supports model upgrade risk planning and compatibility checks.
- **Decisions informed:** model pinning vs auto-upgrade, retest cadence, rollback criteria.

## 6) GitHub Copilot Changelog (RSS)

- **Link:** https://github.blog/changelog/label/copilot/feed/
- **Tags:** `copilot`, `release-intelligence`, `operations`
- **Why it matters:**
  - Central stream for Copilot feature announcements across surfaces.
  - Enables low-friction monthly delta detection for KB refresh.
- **Decisions informed:** monthly release monitoring strategy, communication/newsletter priorities.

## 7) GitHub Copilot Feature Matrix

- **Link:** https://docs.github.com/en/copilot/reference/copilot-feature-matrix
- **Tags:** `copilot`, `platform-comparison`, `governance`
- **Why it matters:**
  - Provides canonical feature coverage by IDE/surface.
  - Useful for entitlement and rollout planning by team/tooling stack.
- **Decisions informed:** platform support policy, migration plans, exception handling.

## 8) MCP Specification

- **Link:** https://modelcontextprotocol.io/specification/latest
- **Tags:** `mcp`, `interoperability`, `tooling`
- **Why it matters:**
  - Defines interoperable tool/context protocols across agent ecosystems.
  - Reduces lock-in risk for integrations and tool adapters.
- **Decisions informed:** integration architecture, tool investment prioritization, vendor-neutral standards strategy.

# Section B: Frameworks and Copilot-Adjacent Resources

## Scope

This section catalogs frameworks, orchestrators, evaluation harnesses, and interoperability conventions that teams commonly evaluate alongside GitHub Copilot workflows.

## Selection Rules

- Copilot-adjacent relevance required.
- Canonical repo/docs link required.
- Maturity assessed using maintenance activity, docs quality, and adoption signals.

## A) Agent Orchestration and Workflow Frameworks

### GitHub Agentic Workflows (`github/gh-aw`)

- **Definition:** GitHub-run framework to write agentic workflows in natural language markdown and execute via GitHub Actions with built-in guardrails.
- **When to use:** repository automation, recurring maintenance agents, auditable GitHub-native execution.
- **When not to use:** local-only workflows requiring no GitHub Actions dependency.
- **Maturity signals:** active maintenance, public docs, regular tagged releases.
- **Canonical links:**
  - https://github.com/github/gh-aw
  - https://github.github.io/gh-aw/
- **Copilot relationship:** complements Copilot by operationalizing recurring agent tasks around repositories.
- **Portability:** `platform-specific` (GitHub Actions execution model).

### Copilot Orchestra (`ShepAlderson/copilot-orchestra`)

- **Definition:** community multi-agent orchestration pattern for Copilot in VS Code Insiders with role-based subagents and TDD gates.
- **When to use:** teams wanting opinionated, multi-agent structured coding loops in VS Code.
- **When not to use:** environments that cannot standardize on VS Code Insiders/custom agent files.
- **Maturity signals:** documented architecture and usage flow; community-maintained.
- **Canonical links:**
  - https://github.com/ShepAlderson/copilot-orchestra
- **Copilot relationship:** direct Copilot workflow pattern using specialized agents.
- **Portability:** `platform-specific` (VS Code-centric).

### Loop Agent (`digitarald/loop-agent`)

- **Definition:** community meta-loop orchestration model that adds stall/regression detection and shared memory for multi-agent execution.
- **When to use:** advanced teams optimizing long-running multi-agent tasks with convergence checks.
- **When not to use:** small/simple tasks where orchestration overhead outweighs gains.
- **Maturity signals:** early-stage, low adoption, clear architecture docs.
- **Canonical links:**
  - https://github.com/digitarald/loop-agent
- **Copilot relationship:** conceptual orchestration patterns transferable to Copilot agent mode workflows.
- **Portability:** `portable` conceptually; implementation is tool-specific.

## B) Spec-Driven Development Frameworks

### Spec Kit (`github/spec-kit`)

- **Definition:** GitHub-maintained toolkit for spec-driven development with CLI scaffolding and agent-compatible workflows.
- **When to use:** teams that want repeatable requirements-to-implementation flow instead of ad-hoc prompting.
- **When not to use:** one-off scripts or tiny changes where formal specification overhead is unnecessary.
- **Maturity signals:** high adoption, active releases, dedicated docs site.
- **Canonical links:**
  - https://github.com/github/spec-kit
  - https://github.github.io/spec-kit/
- **Copilot relationship:** provides structured workflow templates that can be executed with Copilot-enabled IDEs/agents.
- **Portability:** `portable`.

### BMad Method (`bmad-code-org/BMAD-METHOD`)

- **Definition:** community agile AI-development framework with role-based agents and end-to-end workflow commands.
- **When to use:** teams seeking highly structured multi-role planning/delivery workflows.
- **When not to use:** minimal-process teams that prefer lightweight prompts and direct implementation.
- **Maturity signals:** high community adoption, docs portal, frequent updates.
- **Canonical links:**
  - https://github.com/bmad-code-org/BMAD-METHOD
  - http://docs.bmad-method.org
- **Copilot relationship:** can run with Copilot-compatible environments as a process framework.
- **Portability:** `portable`.

## C) Evaluation Harnesses and Benchmarks

### Promptfoo

- **Definition:** evaluation and testing framework for LLM prompts and model behavior with regression checks.
- **When to use:** prompt regression testing, model comparison, CI gates.
- **When not to use:** teams with no defined test sets/quality thresholds yet.
- **Maturity signals:** active repo, broad community use, CI-oriented docs.
- **Canonical links:**
  - https://github.com/promptfoo/promptfoo
- **Copilot relationship:** validates prompt/instruction patterns used in Copilot workflows and automations.
- **Portability:** `portable`.

### OpenAI Evals

- **Definition:** OpenAI framework and reference datasets for evaluating LLM system behavior.
- **When to use:** custom benchmark creation, longitudinal quality tracking.
- **When not to use:** if lightweight smoke tests are sufficient and dataset maintenance cost is not justified.
- **Maturity signals:** long-running repo, broad references in eval workflows.
- **Canonical links:**
  - https://github.com/openai/evals
- **Copilot relationship:** evaluation methodology is directly reusable for Copilot prompt/policy testing.
- **Portability:** `portable`.

### SWE-bench

- **Definition:** benchmark suite for evaluating coding agents on real-world software engineering tasks.
- **When to use:** comparative benchmarking of coding-agent performance.
- **When not to use:** narrow internal validation where domain-specific golden sets are more relevant.
- **Maturity signals:** recognized benchmark, active maintenance.
- **Canonical links:**
  - https://github.com/SWE-bench/SWE-bench
- **Copilot relationship:** provides external benchmark context for coding-agent capability claims.
- **Portability:** `portable`.

## D) Interoperability Protocols and Capability Packaging (within Section B/C)

### Model Context Protocol (MCP)

- **Definition:** open protocol for tool/context integration between models and external systems.
- **When to use:** connecting Copilot-adjacent workflows to external tools/data sources consistently.
- **When not to use:** closed/single-tool systems with no interoperability requirement.
- **Maturity signals:** official specification repo and docs site, growing ecosystem.
- **Canonical links:**
  - https://github.com/modelcontextprotocol/modelcontextprotocol
  - https://modelcontextprotocol.io
- **Copilot relationship:** matrix-tracked feature area; MCP expands context/tooling for Copilot agents.
- **Portability:** `portable`.

### Agent Skills Format (`agentskills.io`)

- **Definition:** open format (`SKILL.md`) for reusable agent capabilities.
- **When to use:** standardizing reusable skills across multiple agent runtimes.
- **When not to use:** tightly coupled single-vendor configs with no portability goals.
- **Maturity signals:** formal spec pages, reference repos, explicit integration guidance.
- **Canonical links:**
  - https://agentskills.io
  - https://agentskills.io/specification.md
- **Copilot relationship:** enables reusable skill assets that can complement Copilot instruction stacks.
- **Portability:** `portable`.

### AgentConfig (`agentconfig.org`)

- **Definition:** practitioner reference for aligning assistant config primitives, file locations, and integrations.
- **When to use:** cross-tool configuration design and migration planning.
- **When not to use:** as sole authoritative source for vendor behavior.
- **Maturity signals:** structured docs and tutorials; community-maintained.
- **Canonical links:**
  - https://agentconfig.org
  - https://agentconfig.org/llms.txt
- **Copilot relationship:** useful for mapping Copilot config choices into multi-agent environments.
- **Portability:** `portable`.

## E) AgentOS Disambiguation

### `genai-works-org/genai-agentos`

- **Definition:** modern "AgentOS"-named project focused on agent infrastructure patterns.
- **Use case fit:** evaluate for contemporary GenAI agent OS patterns.
- **Canonical link:** https://github.com/genai-works-org/genai-agentos
- **Portability:** `portable` (framework-level).

### `agentos-project/agentos`

- **Definition:** older project sharing the name "AgentOS," historically focused on RL/agent experimentation.
- **Use case fit:** historical/reference context, not default choice for current Copilot-adjacent orchestration.
- **Canonical link:** https://github.com/agentos-project/agentos
- **Portability:** `portable` conceptually, but lower current relevance.

## Maturity Summary (Practical)

- **High maturity:** `gh-aw`, `spec-kit`, `MCP`, `promptfoo`, `openai/evals`, `SWE-bench`.
- **Medium maturity:** `BMAD-METHOD`, `copilot-orchestra`, `agentskills.io`.
- **Low/early maturity:** `loop-agent`, select `AgentOS` variants.


# Fleet Best Practices — Copilot CLI Multi-Agent Orchestration

> Parallel sub-agent execution via `/fleet` in Copilot CLI.
> Grounded in source code analysis, session log mining (7 production sessions), and live experiments.

---

## What Fleet Is

`/fleet` activates parallel sub-agent orchestration. The main agent (orchestrator) decomposes work into todos with dependencies, dispatches sub-agents in parallel via the `task` tool, and polls for completion with `read_agent`. Sub-agents run in isolated context windows but share the filesystem.

Fleet is a prompt overlay on the existing session — not a separate runtime. The orchestrator decides how to decompose, what to parallelize, and when to serialize based on dependencies.

**Flag:** Requires `staff` or `--experimental`.

## How to Run

```bash
# Non-interactive (confirmed working)
copilot --model claude-opus-4.6 \
  -p "/fleet <task description>" \
  --allow-all --no-ask-user \
  2>&1 | tee output.txt
```

The `--model` flag controls the orchestrator. Sub-agents default to a lighter model unless you specify custom agents.

## Controlling Sub-Agent Models

Define custom agents in `.github/agents/` with `model:` in frontmatter:

```yaml
---
name: quality-writer
description: High-quality content writer
model: claude-opus-4.6
tools: ["bash", "create", "edit", "view"]
---
You are a quality-focused writer. [instructions]
```

Reference them in your fleet prompt: `Use @quality-writer for the report and @fast-worker for boilerplate`. Fleet dispatches custom agents by name and respects their model setting. Confirmed: Opus and Sonnet sub-agents run in parallel within the same fleet, each on their specified model.

## How Orchestration Works

When you invoke `/fleet`, the orchestrator:

1. **Decomposes** the task into discrete work items with dependencies
2. **Identifies** which items are independent (can run in parallel) vs dependent (must wait)
3. **Dispatches** independent items as background sub-agents simultaneously
4. **Polls** with `read_agent` — checks all agents, typically in batches
5. **Dispatches** next wave once dependencies are satisfied
6. **Verifies** outputs — reads produced files, checks completeness
7. **Synthesizes** — creates any artifacts that depend on sub-agent output

For complex tasks (4+ items with dependencies), Fleet automatically tracks work items and their dependencies internally. For simple tasks, it skips coordination overhead and dispatches directly.

### Background vs Sync Dispatch

| | background (recommended) | sync |
|---|---|---|
| How it works | Agents run in parallel; orchestrator polls with `read_agent` | Agents run one at a time; orchestrator blocks |
| Production data | B3: 203 tool calls, 9/9 completions, 0 errors | B2: 587 tool calls, 3/8 completions recorded, 1 error |
| Use when | Independent tasks with no shared state | Strictly sequential tasks with hard ordering |

**Always use background for independent work.** It's 2.9× more efficient and has better completion tracking.

## Task Decomposition

The quality of the decomposition determines everything. Each work item should:

- Produce a **distinct artifact** (a specific file at a specific path)
- Have a **clear completion condition**
- Be **independent** of other items unless explicitly dependent

Bad: "Build the documentation" (unbounded, vague)
Good: "Create docs/API.md with 3 REST endpoint sections, max 80 lines" (file, content, bound)

### Dependencies

When item B requires item A's output, declare the dependency. The orchestrator will serialize them. Items without dependencies run in parallel.

Example: 5 documentation pages can all run in parallel, but an INDEX.md that links to all 5 must wait until they're done. Tested: Fleet correctly held INDEX until all 5 pages completed.

## Sub-Agent Prompts

Sub-agents get their own context window — they cannot see the orchestrator's conversation. Their dispatch prompt must be self-contained.

**Three rules that matter most (empirically validated):**

1. **Specify the deliverable exactly** — file path, content requirements, format
2. **Set stop rules** — "max N sections", "under N lines"
3. **Pass gathered context** — anything the orchestrator already knows that the sub-agent would waste time re-discovering

### Template for complex sub-agent dispatch

```
Objective: Create the API reference documentation
Deliverable: docs/API.md
Requirements:
- 3 endpoint sections (GET /items, POST /items, DELETE /items/:id)
- Each endpoint: description, request format, response format, example
- Use markdown tables for request/response schemas
Stop rules: Maximum 80 lines. 3 endpoints only.
Context already gathered:
- Project uses REST conventions from docs/ARCHITECTURE.md
- Authentication is Bearer token (documented in CONTRIBUTING.md)
```

Only use this level of detail for complex tasks. Simple "create file X with content Y" doesn't need a template.

## File Write Safety

**Confirmed behavior: last-writer-wins, no locking, no error reported to the orchestrator.**

When two agents write to the same file, both report success. The slower writer's content silently overwrites the faster writer's.

**Prevention:** Partition files in the decomposition. Assign each agent distinct files. This is how production fleet sessions achieved zero conflicts across 94 files with 8 parallel agents.

If multiple agents must contribute to one file, have each write to a separate path, then have the orchestrator merge.

## Compaction

Background agents survive context compaction. B3 had 15 compactions during 8-agent parallel execution — all agents completed. The runtime tracks agents independently of chat history.

**Risk:** If the orchestrator's context compacts, the text containing agent IDs may be lost. Mitigation: poll agents promptly after dispatch rather than waiting.

## Orchestrator Design

Set `infer: false` on orchestrator agents to prevent them from being auto-selected as sub-agents (avoids recursive orchestration). Keep orchestrator prompts under 150 lines — extract domain logic into worker agent definitions.

Worker agents should:
- Set `infer: true` (so the orchestrator can select them)
- **Not** have `agent` in their tools list (single-level nesting — workers don't delegate)
- Have explicit scope boundaries (don't touch files outside assignment)

## Monitoring

```bash
python3 scripts/parse-session-log.py --latest                                    # Tool counts and strategy
python3 scripts/extract-tasks.py $(ls -t ~/.copilot/session-state/*/events.jsonl | head -1)  # Dispatches + completions
python3 scripts/fleet-deep-analysis.py $(ls -t ~/.copilot/session-state/*/events.jsonl | head -1)  # Conflicts + errors
```

Healthy fleet sessions: ≥90% task completion rate, 0 file conflicts, ≤5 compaction events.

## Known Limitations

1. **Last-writer-wins** on file conflicts — partition files carefully
2. **Sub-agents can't coordinate with each other** — only the orchestrator coordinates
3. **Completion signals can be lost** in sync mode — use background + `read_agent`
4. **Sub-agent model defaults to Haiku** unless you use custom agents with `model:`
5. **Long fleets risk compaction** — poll agents early, don't defer `read_agent`

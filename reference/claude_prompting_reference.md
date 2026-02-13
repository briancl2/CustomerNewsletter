---
post_title: "Claude Prompting Best Practices"
categories: ["Reference"]
tags: ["claude", "prompting", "agents", "best-practices"]
summary: "Prompting guidance optimized for Claude 4.5 when writing or improving prompts and instructions."
post_date: "2026-02-03"
---

## Claude 4.5 Prompting Best Practices

This reference codifies prompting guidance optimized for Claude Opus 4.5. It is written for AI agents to consume and apply when writing or improving prompts for custom agents, prompt files, and instructions.

## Core Principles

### Be Explicit with Instructions

Claude 4.5 follows instructions precisely and does not "go above and beyond" unless explicitly requested. Specify desired behaviors directly.

```xml
<!-- GOOD: Explicit instruction -->
<default_to_action>
Implement changes rather than only suggesting them. If the user's intent is unclear,
infer the most useful likely action and proceed, using tools to discover missing details.
</default_to_action>

<!-- BAD: Vague expectation -->
"Help the user with their code."
```

### Add Context and Motivation

Providing *why* an instruction matters helps Claude generalize correctly. Include motivation for important behaviors.

```xml
<!-- GOOD: Instruction + motivation -->
Use parallel tool calls whenever possible. This dramatically improves response latency
and reduces the number of API round-trips, which improves user experience.

<!-- BAD: Instruction without motivation -->
Use parallel tool calls.
```

### Be Vigilant with Examples

Claude 4.5 pays close attention to examples. Ensure examples:
- Model the exact behavior you want
- Avoid patterns you want to discourage
- Use placeholders `[like this]` for variable content

## Tool Usage Patterns

### Parallel Tool Calls

Claude 4.5 excels at parallel execution. Encourage parallelism for independent operations:

```xml
<use_parallel_tool_calls>
If you intend to call multiple tools and there are no dependencies between the calls,
make all independent calls in parallel. For example, when reading 3 files, run 3 tool
calls in parallel. However, if some calls depend on previous results, call them
sequentially. Never use placeholders or guess missing parameters.
</use_parallel_tool_calls>
```

### Tool Triggering

Claude 4.5 is more responsive to system prompts than previous models. Avoid aggressive capitalized language like "CRITICAL: You MUST use this tool when..." which may cause overtriggering. Use natural phrasing:

```xml
<!-- GOOD: Natural phrasing -->
Use the read_file tool when you need to see the contents of a file.

<!-- BAD: Aggressive emphasis -->
CRITICAL: You MUST ALWAYS use read_file before any discussion of file contents.
```

### Investigate Before Acting

Encourage Claude to read code before proposing changes:

```xml
<investigate_before_answering>
Always read and understand relevant files before proposing code edits. Do not speculate
about code you have not inspected. If the user references a specific file/path, open and
inspect it before explaining or proposing fixes.
</investigate_before_answering>
```

### Tool Permission Generosity

When designing agents, be generous with tool permissions rather than restrictive:

```xml
<tool_philosophy>
Include tools the agent might need, even if not used every time. Missing tools cause
failures; extra tools in the allowlist do not hurt.

Default generous: read, edit, search, web, agent, todo
Only restrict for safety reasons (e.g., no execute if shell access is dangerous)
</tool_philosophy>
```

**Don't remove tools "for minimalism"** — this causes edge case failures. An agent that "mostly outputs text" still needs `edit` when the user asks to save results.

## Subagent Orchestration

Claude 4.5 has improved native subagent orchestration capabilities. It recognizes when tasks benefit from delegation and does so proactively.

### Delegation Tools by Surface

| Surface | Delegation Tool | Notes |
|---------|-----------------|-------|
| VS Code Copilot | `runSubagent` | Use `agent` alias in tools list |
| Coding Agent | `agent` | Use `agent` alias in tools list |
| Claude Code | `Task` | **NOT supported in this repo** |

### Enable Natural Delegation

```xml
<!-- For conservative subagent usage -->
<subagent_policy>
Delegate to subagents when the task clearly benefits from a separate context window, such as:
- Research tasks requiring many file reads
- Complex analysis that would pollute the main context
- Parallel investigation of multiple topics

Do not delegate for simple file reads or straightforward edits.
</subagent_policy>
```

### Subagent Prompt Requirements

When spawning a subagent, the prompt must be self-contained:
- Include complete task description
- Specify exactly what information to return
- Define success criteria
- State whether the subagent should write code or only research

## Subagent Handoff Best Practices

These patterns are derived from empirical testing and have the highest ROI for improving orchestration quality.

### The 3 Golden Rules

| Rule | Confidence | Why It Matters |
|------|------------|----------------|
| 📋 Specify return format | 95% | Prompts saying "Return ONLY this table..." produce parseable responses. Without this, subagents return narrative dumps. |
| 🛑 Set stop rules | 90% | "Max 5 files, stop at 10 items" creates bounded execution. Without this, subagents may explore exhaustively. |
| 📦 Pass gathered context | 80% | "Context already gathered: [data]" prevents redundant research and data inconsistencies. |

### Optimized Handoff Template

```markdown
## Handoff
- **From:** <orchestrator>
- **To:** <subagent>
- **Objective:** <one sentence task>
- **Inputs:**
  - <data to pass>
  - Directory: <path>
- **Context already gathered:**
  - <fact - don't re-discover>
- **Constraints:**
  🚨 Read-only; do NOT make file changes
  Maximum <N> files
- **Required outputs:**
  Return ONLY this structure:

  | Column A | Column B |
  |----------|----------|

- **Stop rules:**
  - Stop when: <condition>
  - Return partial results if incomplete
```

### Why Each Element Matters

| Element | Purpose | Tested Impact |
|---------|---------|---------------|
| **One-sentence objective** | Focus the subagent | Prevents scope creep |
| **Context already gathered** | Skip redundant research | Avoids re-discovering known facts |
| **🚨 emoji on constraints** | Visual emphasis | Constraints reliably respected |
| **Required outputs (exact format)** | Parseable responses | Enables automated continuation |
| **Stop rules** | Bounded execution | Predictable completion |

### Handoff Anti-Patterns

| Anti-Pattern | Problem | Better Alternative |
|-------------|---------|-------------------|
| "Find everything about X" | Unbounded, unfocused | "Find the top 5 X with evidence" |
| No return format | Narrative dump | Specify exact table columns |
| No stop rules | Context exhaustion | "Max 10 files, stop at 80% confidence" |
| No context passing | Redundant research | "Context already gathered: [data]" |
| Implicit output expectation | Subagent adds unwanted extras | "Return ONLY..." |

## Validated Return Format Patterns (Empirically Tested)

These patterns were validated through 18 empirical tests in the Design 3A–3C series summarized below. Return format design has the highest ROI of any prompt engineering technique — adding column specifications preserves 30% more information at zero cost.

### Information Preservation by Format Type

| Format Type | Preservation | Evidence | Use When |
|-------------|--------------|----------|----------|
| Simple table | 60% | Design 3A (simple table, 17 tools, no context) | Never (insufficient) |
| Rich table | 90% | Design 3B (rich table, 16 tools + context) | Default for structured data |
| Narrative | 85% | Design 3C (narrative, strategic synthesis) | Summary/analysis tasks |

### DO: Rich Table Format

```markdown
## Required Outputs
Return ONLY this structure:

| Stakeholder | Company | Role | Evidence Quote | Confidence |
|-------------|---------|------|----------------|------------|

Include:
- Evidence quote for each champion signal
- Confidence level (High/Medium/Low) with reasoning
- Source file or date for each entry
```

**Result:** 90% information preservation, parseable, verifiable claims

### AVOID: Simple Table Format

```markdown
## Required Outputs
Return a table of stakeholders.

| Name | Company |
|------|---------|
```

**Result:** 60% information preservation, no context, unverifiable

### DO: Narrative with Structure

```markdown
## Required Outputs
Write 3-5 paragraphs covering:

### Primary Finding
[Main answer to the task]

### Evidence
- [Source 1]: [Quote or reference]
- [Source 2]: [Quote or reference]

### Strategic Implications
[What this means for account strategy]
```

**Result:** 85% preservation, good for synthesis tasks

### AVOID: Open-Ended Narrative

```markdown
## Required Outputs
Summarize what you find about stakeholders.
```

**Result:** Unparseable narrative dump, missing key details

### Key Columns That Preserve Nuance (Tested)

| Column Type | Impact | Why It Works |
|-------------|--------|--------------|
| Evidence Quote | +20% | Grounds claims, enables verification |
| Source File | +10% | Attribution enables follow-up |
| Confidence | +10% | Calibrates orchestrator trust |
| Last Contact | +5% | Temporal context for recency |

### DO: Request Evidence Quotes for Nuance

```markdown
| Champion | Role | Champion Strength | Evidence Quote | Confidence |
|----------|------|-------------------|----------------|------------|
| Krishna | VP AI | Strong | "CEO prioritizes AI enablement for developers" | High |
```

### AVOID: Name/Role Only

```markdown
| Champion | Role |
|----------|------|
| Krishna | VP AI |
```

**Why it fails:** No way to assess champion strength or verify claim

## Context Management

### Long-Horizon State Tracking

Claude 4.5 maintains orientation across extended sessions. Use structured formats for state:

```xml
<state_management>
- Use JSON or structured formats for tracking status (test results, task lists)
- Use freeform text for progress notes
- Use git for checkpointing across multiple sessions
- Emphasize incremental progress over completing everything at once
</state_management>
```

### Context Awareness

Claude 4.5 tracks its remaining context window. For agent harnesses that compact context:

```xml
<context_guidance>
Your context window will be compacted as it approaches its limit. Do not stop tasks
early due to token budget concerns. Be persistent and complete tasks fully. Save
progress and state before context refreshes.
</context_guidance>
```

## Mandatory Todo Usage (This Repo)

**All agents in this repository MUST use the `todo` tool for task tracking.**

This is a repo-specific policy that ensures visibility into agent progress and planning.

### Why Todo is Mandatory

1. Visibility: Todos provide clear progress tracking for complex tasks
2. Planning: Forces agents to break down work before starting
3. Completion Tracking: Prevents forgotten subtasks
4. Handoff Clarity: Orchestrators can see what subagents accomplished

### Todo Policy

```xml
<todo_policy>
Use the `todo` tool for ALL tasks, including simple ones.

Workflow:
1. On task receipt, create todo list with specific, actionable items
2. Mark ONE todo as in-progress before starting work
3. Complete the work for that specific todo
4. Mark that todo as completed IMMEDIATELY
5. Move to next todo and repeat

Never batch completions. Mark todos done as soon as they finish.
Never skip todo usage — even single-step tasks should be tracked.
</todo_policy>
```

## Communication Style

Claude 4.5 is more concise and direct:
- Provides fact-based progress reports
- More conversational, less machine-like
- May skip detailed summaries unless prompted

To request updates during work:

```xml
After completing a task involving tool use, provide a quick summary of what you've done.
```

## Avoiding Common Issues

### Overeagerness and Overengineering

Claude 4.5 may add unnecessary abstractions. Constrain this:

```xml
<minimal_scope>
Avoid over-engineering. Only make changes directly requested or clearly necessary.
Keep solutions simple and focused. Don't add features, refactor code, or make
"improvements" beyond what was asked.
</minimal_scope>
```

### Reducing Hallucinations

```xml
<grounded_answers>
Never speculate about code you have not opened. Make sure to investigate and read
relevant files before answering questions about the codebase. Give grounded,
hallucination-free answers.
</grounded_answers>
```

### File Creation

Claude 4.5 may create temporary files for iteration. To minimize:

```xml
If you create any temporary files, scripts, or helper files for iteration,
clean them up by removing them at the end of the task.
```

## Agentic Coding Guidance

### Test-Focused Solutions

Prevent focusing too heavily on passing tests:

```xml
<robust_solutions>
Write high-quality, general-purpose solutions. Do not hard-code values for specific
test cases. Implement actual logic that solves the problem generally. If tests are
incorrect, inform the user rather than working around them.
</robust_solutions>
```

### Code Exploration

Encourage thorough codebase review:

```xml
<code_exploration>
Thoroughly review the style, conventions, and abstractions of the codebase before
implementing new features. Be rigorous and persistent in searching code for key facts.
</code_exploration>
```

# Worked Examples: Reducing Repeated Agent Work

These examples show how to apply the May bundle guidance without treating this newsletter system as a universal benchmark. They use public-safe patterns: bind the task, preserve required context, validate output, and avoid claiming billing savings from workflow telemetry alone.

## Example 1: Newsletter Or Content Generation

### Situation

A team uses an AI-assisted workflow to produce a recurring technical newsletter or release digest. The draft quality is good, but the workflow repeatedly re-reads source material, performs broad searches late in the process, and needs repair passes after assembly.

### Cost-Aware Route

| Step | Pattern | Why it helps |
|---|---|---|
| Source binding | Capture accepted URLs, dates, and source classes before synthesis. | Later phases do not need to rediscover the same material. |
| Artifact reuse | Save accepted interim files and use them as the curation input. | Reduces repeated fetch/search work. |
| Compact working set | Build a smaller curation packet after source coverage is checked. | Keeps expensive synthesis focused. |
| Validation gate | Run structural, content, and link checks before publication. | Prevents a cheaper weak draft from becoming accepted output. |
| Fallback | Re-open fuller context only when readiness checks fail. | Keeps optimization reversible. |

### Validation

- Required source classes are still represented.
- Final output passes newsletter validation and link checks.
- Any token or request movement is described as workflow evidence, not billing proof.

## Example 2: Scoped Documentation Update

### Situation

A developer asks an agent to refresh documentation after a feature change. The agent spends time exploring the whole repository even though the changed files are known.

### Cost-Aware Route

1. Provide the exact files that need edits.
2. Provide the expected outcome and stopping condition.
3. Ask for a read-only check before implementation if the context is uncertain.
4. Disable or discourage broad search after the file list is confirmed.
5. Run Markdown lint, link checks, or project-specific docs validation.

### Useful Prompt Shape

```text
Update these files only: README.md, docs/how-it-works.md, and docs/architecture.md.
Goal: reflect the new release bundle navigation.
Do a brief read-only pass first, then make minimal edits.
Stop after validation and summarize changed links.
```

### Validation

- Only intended docs changed.
- Links resolve.
- The new docs match the current implementation.
- The agent did not re-run unrelated discovery or refactor unrelated files.

## Example 3: Debugging Unknown Failure

### Situation

A test fails intermittently. The team wants root cause, not a trial-and-error patch loop.

### Cost-Aware Route

| Phase | Agent instruction | Gate |
|---|---|---|
| Hypothesis | Summarize the failure and propose one testable hypothesis. | Hypothesis names a falsifiable signal. |
| Evidence | Read the failing test, recent logs, and the smallest relevant implementation surface. | No broad repository sweep unless the first hypothesis fails. |
| Patch | Make the smallest root-cause fix. | Diff is scoped to the failing behavior. |
| Validate | Run the failing test and a nearby regression set. | Tests pass or the hypothesis is revised. |
| Record | Capture the lesson if the failure mode is likely to recur. | Future runs avoid the same repair work. |

### Validation

- The fix is tied to the observed failure.
- The test that failed now passes.
- Any broader test run is proportional to risk.
- The team records whether the cause was unclear task scope, missing logs, stale context, or a real code defect.

## Example 4: Budget Block During Rollout

### Situation

A developer is blocked during UBB rollout. The team is unsure whether to raise the user budget, change model policy, or ask the developer to reduce agent use.

### Cost-Aware Route

1. Identify which budget layer blocked usage: user-level, cost-center, or enterprise.
2. Check whether the user is doing high-value work that needs a temporary override.
3. Check whether repeated attempts came from missing files, weak task boundaries, or failed validation.
4. Separate code review, CLI activity, and chat or agent usage where reporting allows.
5. Decide whether the response is an override, guidance, model policy, or workflow repair.

### Good Outcome

The user can finish valid work without weakening tests or validation, and the admin team learns whether the budget was too low, the workflow was wasteful, or the work was correctly high-usage.

## Example 5: Custom Agent Workflow

### Situation

A platform team owns a custom agent or workflow harness. They want to reduce repeated context assembly and make cost claims responsibly.

### Cost-Aware Route

- Add trace or log identifiers for phases, tools, and accepted artifacts.
- Record prompt versions and source bundle hashes.
- Keep static instructions stable where caching or reuse may help.
- Validate output quality before comparing routes.
- Track retries, repairs, and tool calls, not just prompt length.
- Use OpenTelemetry or equivalent tracing where the workflow is instrumented.

### Claim Boundary

The team can say the workflow repeated less work or needed fewer repairs when telemetry shows that. Invoice savings require billing data.

## Reuse Checklist

- Is the task bounded?
- Are required sources or files named?
- Is there a validation gate independent of the optimization?
- Is fallback available if compact context fails?
- Are metrics labeled as billing data, usage report, telemetry, experiment, or estimate?
- Is the final result accepted by the same quality bar as the baseline?

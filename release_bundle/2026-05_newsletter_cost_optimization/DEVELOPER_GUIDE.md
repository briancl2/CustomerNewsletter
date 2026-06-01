# Developer Guide: Cost-Aware Agentic Workflows

> **Bottom line:** Optimize the route, not the prompt; a shorter prompt can still cost more if it drives retries, broad search, and repairs. **For:** developers and AI workflow owners. **Read time:** about 9 minutes.

This guide is for developers reducing token and cost pressure without weakening quality. It pairs core rules with worked scenarios. For the system that produced these lessons and its before/after numbers, see [NEWSLETTER_SYSTEM_RELEASE_NOTES.md](NEWSLETTER_SYSTEM_RELEASE_NOTES.md).

## Core Rule

Optimize the route, not the prompt. A prompt can be shorter while the workflow costs more. A model can be cheaper per token and still create repair work. The useful unit is the finished workflow with quality, validation, and review intact.

## Recommended Practices

1. Measure the full workflow: inputs, outputs, requests, tools, retries, validations, and repairs.
2. Put quality gates inside the cost gate. A cheaper invalid answer is not cheaper.
3. Start by removing repeated discovery and repeated context assembly.
4. Use stable prompts, stable source bundles, and explicit acceptance criteria.
5. Preserve required source classes before reducing context.
6. Add readiness checks before using compact or no-tools routes.
7. Keep a fallback to a fuller route when readiness fails.
8. Reuse artifacts only when identity, freshness, and source scope are clear.
9. Restrict tools when reuse is the goal; otherwise the agent may reconstruct the same work.
10. Change model or reasoning only where the task is bounded and quality can be checked.
11. Treat cache and telemetry as diagnostic unless billing-grade controls exist.
12. Keep lightweight records: source links, prompts, validation reports, and known non-claims.

## Common Pitfalls

1. Telemetry alone is not invoice-grade billing evidence.
2. One task or phase is not the same as full-route savings.
3. Lower reasoning is task-specific, not globally cheaper by default.
4. Output budgets can help formatting, but they are a weak default cost strategy. In this system, an output-shape policy added millions of tokens instead of saving them.
5. Source pruning needs compensation checks for search, requests, cache, and repairs.
6. A cheaper output that misses the quality threshold is not an accepted optimization.
7. Percentages from different corpora or conditions should not be combined.
8. Routing evidence should not become model-superiority language.
9. Negative results are useful guardrails when they are recorded clearly.

## Decision Checklists

**Before changing model or reasoning:** Is the task bounded and source-defined? Is the quality gate independent of the model choice? Do you have a rollback path? Are you avoiding model-superiority language?

**Before reducing context:** Which source classes are mandatory? Does the compact artifact preserve those classes? Can the model compensate with search or tools? Is there a fallback to the fuller route? Does final validation catch missing coverage?

**Before reusing artifacts:** Is artifact identity fixed? Is freshness clear? Are tools and refetches bounded? Is output validated after reuse? Does the claim stay local to the workflow?

**Before claiming savings:** Is the result route-level, not a single step only? Did quality pass? Are corpora comparable enough for the wording? Is this estimate, telemetry, usage export, or invoice-grade evidence? What does the evidence not prove?

## Worked Examples

These examples apply the rules above without treating this newsletter system as a universal benchmark. They use general patterns: bind the task, preserve required context, validate output, and avoid claiming billing savings from workflow telemetry alone.

### Example 1: Newsletter Or Content Generation

A team produces a recurring technical newsletter. The draft quality is good, but the workflow repeatedly re-reads source material, performs broad searches late, and needs repair passes after assembly.

| Step | Pattern | Why it helps |
|---|---|---|
| Source binding | Capture accepted URLs, dates, and source classes before synthesis. | Later phases do not rediscover the same material. |
| Artifact reuse | Save accepted interim files and use them as the curation input. | Reduces repeated fetch/search work. |
| Compact working set | Build a smaller curation packet after source coverage is checked. | Keeps expensive synthesis focused. |
| Validation gate | Run structural, content, and link checks before publication. | Prevents a cheaper weak draft from becoming accepted output. |
| Fallback | Re-open fuller context only when readiness checks fail. | Keeps optimization reversible. |

**Validation:** required source classes are still represented; final output passes newsletter validation and link checks; any token or request movement is described as workflow evidence, not billing proof.

### Example 2: Scoped Documentation Update

A developer asks an agent to refresh docs after a feature change. The agent explores the whole repository even though the changed files are known.

1. Provide the exact files that need edits.
2. Provide the expected outcome and stopping condition.
3. Ask for a read-only check before implementation if the context is uncertain.
4. Disable or discourage broad search after the file list is confirmed.
5. Run Markdown lint, link checks, or project-specific docs validation.

```text
Update these files only: README.md, docs/how-it-works.md, and docs/architecture.md.
Goal: reflect the new release bundle navigation.
Do a brief read-only pass first, then make minimal edits.
Stop after validation and summarize changed links.
```

**Validation:** only intended docs changed; links resolve; new docs match the current implementation; the agent did not re-run unrelated discovery or refactor unrelated files.

### Example 3: Debugging Unknown Failure

A test fails intermittently. The team wants root cause, not a trial-and-error patch loop.

| Phase | Agent instruction | Gate |
|---|---|---|
| Hypothesis | Summarize the failure and propose one testable hypothesis. | Hypothesis names a falsifiable signal. |
| Evidence | Read the failing test, recent logs, and the smallest relevant implementation surface. | No broad repository sweep unless the first hypothesis fails. |
| Patch | Make the smallest root-cause fix. | Diff is scoped to the failing behavior. |
| Validate | Run the failing test and a nearby regression set. | Tests pass or the hypothesis is revised. |
| Record | Capture the lesson if the failure mode is likely to recur. | Future runs avoid the same repair work. |

**Validation:** the fix is tied to the observed failure; the failing test now passes; any broader test run is proportional to risk; the team records whether the cause was unclear task scope, missing logs, stale context, or a real code defect.

### Example 4: Budget Block During Rollout

A developer is blocked during UBB rollout, and the team is unsure whether to raise the user budget, change model policy, or reduce agent use.

1. Identify which budget layer blocked usage: user-level, cost-center, or enterprise.
2. Check whether the user is doing high-value work that needs a temporary override.
3. Check whether repeated attempts came from missing files, weak task boundaries, or failed validation.
4. Separate code review, CLI activity, and chat or agent usage where reporting allows.
5. Decide whether the response is an override, guidance, model policy, or workflow repair.

**Good outcome:** the user finishes valid work without weakening tests or validation, and the admin team learns whether the budget was too low, the workflow was wasteful, or the work was correctly high-usage. See the [Admin And FinOps Guide](ADMIN_FINOPS_GUIDE.md) for the triage owners.

### Example 5: Custom Agent Workflow

A platform team owns a custom agent or workflow harness and wants to reduce repeated context assembly while making cost claims responsibly.

- Add trace or log identifiers for phases, tools, and accepted artifacts.
- Record prompt versions and source bundle hashes.
- Keep static instructions stable where caching or reuse may help.
- Validate output quality before comparing routes.
- Track retries, repairs, and tool calls, not just prompt length.
- Use OpenTelemetry or equivalent tracing where the workflow is instrumented.

**Claim boundary:** the team can say the workflow repeated less work or needed fewer repairs when telemetry shows that. Invoice savings require billing data.

## Reuse Checklist

- Is the task bounded?
- Are required sources or files named?
- Is there a validation gate independent of the optimization?
- Is fallback available if compact context fails?
- Are metrics labeled as billing data, usage report, telemetry, experiment, or estimate?
- Is the final result accepted by the same quality bar as the baseline?

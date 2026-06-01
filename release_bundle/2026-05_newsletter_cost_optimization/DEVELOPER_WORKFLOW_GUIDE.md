# Developer Workflow Guide: Cost-Aware Agentic Workflows

This guide is for developers, platform engineers, and AI workflow owners who want to reduce token and cost pressure without weakening quality.

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
4. Output budgets can help formatting, but they are a weak default cost strategy.
5. Source pruning needs compensation checks for search, requests, cache, and repairs.
6. A cheaper output that misses the quality threshold is not an accepted optimization.
7. Percentages from different corpora or conditions should not be combined.
8. Routing evidence should not become model-superiority language.
9. Negative results are useful guardrails when they are recorded clearly.

## Before Changing Model Or Reasoning

- Is the task bounded and source-defined?
- Is the quality gate independent of the model choice?
- Do you have a rollback path?
- Are you avoiding model-superiority language?

## Before Reducing Context

- Which source classes are mandatory?
- Does the compact artifact preserve those classes?
- Can the model compensate with search or tools?
- Is there a fallback to the fuller route?
- Does final validation catch missing coverage?

## Before Reusing Artifacts

- Is artifact identity fixed?
- Is freshness clear?
- Are tools and refetches bounded?
- Is output validated after reuse?
- Does the claim stay local to the workflow?

## Before Claiming Savings

- Is the result route-level, not a single step only?
- Did quality pass?
- Are corpora comparable enough for the wording?
- Is this estimate, telemetry, usage export, or invoice-grade evidence?
- What does the evidence not prove?

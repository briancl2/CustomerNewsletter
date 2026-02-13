# Research Method

## State Header

- **AS_OF_DATE:** 2026-02-10
- **LAST_RUN_DATE:** 2026-02-10

## Method Overview

This KB uses a canonical-first methodology:

1. Gather first-party documentation/changelog/release sources per surface.
2. Add machine-readable feed/API endpoints wherever available.
3. Add only necessary community/practitioner sources, explicitly labeled.
4. Validate link health and capture failures.

## Search Strategies by Section

### Section A (Primary Platforms)

- Start from official Copilot docs hub and feature matrix.
- Expand by each listed surface to find:
  - docs hub
  - release/changelog pages
  - install/upgrade channels
  - feed/API endpoints
- Cross-check with Copilot changelog RSS and platform-native release notes.
- Explicitly scan changelog entries for retirement/deprecation signals (`deprecated`, `retired`, `sunset`, `closing down notice`).
- Verify cross-cutting customization sources (`custom-instructions-support`, `response-customization`, prompt-files docs) because these affect multiple surfaces.

### Section B (Frameworks)

- Begin with user-provided seed frameworks.
- Verify canonical repo/docs and current maintenance signals.
- Expand to adjacent categories:
  - orchestration frameworks
  - spec-driven frameworks
  - eval harnesses
  - protocol/spec conventions

### Section C (Best Practices)

- Prioritize vendor guidance (GitHub, Microsoft, OpenAI, Anthropic).
- Add practitioner content only when operationally concrete.
- Translate into portable-first guidance with explicit exceptions.

### Section D (Thought Leadership)

- Prefer high-signal pieces with concrete operational advice.
- Filter for durable ideas that survive model/version churn.

## Canonicality Verification Rules

A source is treated as canonical when at least one condition is true:

- Vendor-owned docs/release/changelog domain.
- Official vendor repository or marketplace listing.
- Official API/feed endpoint tied to the vendor source.

If not canonical:

- label as `Community` or `Practitioner` in `SOURCES.yaml`
- keep only if it adds concrete operational value.

## Duplicate and Naming-Collision Handling

- Deduplicate by stream identity, not by page title.
- Consolidate related URLs into one source record when they describe the same stream.
- For naming collisions (for example `AgentOS`), include explicit disambiguation records and usage notes.

## Inclusion Rules

Include a source when all are true:

1. It directly supports Copilot platform tracking or Copilot-adjacent workflow design.
2. It has clear provenance and stable URL behavior.
3. It contributes unique value not already captured.

## Exclusion Rules

Exclude when any are true:

- Pure opinion with no operational guidance.
- Duplicates existing canonical coverage.
- Dead or unverifiable link with no clear replacement.

## Practitioner-Source Classification and Downgrade Policy

- Default practitioner sources to `stability: medium` or `low`.
- Reassess each monthly run for freshness and relevance.
- Downgrade or remove if:
  - no updates over extended period
  - repeated mismatch with canonical sources
  - insufficient operational detail

## Portability Method

- All reusable guidance is authored as portable-first.
- `.agents/skills` is the default reusable asset location.
- Platform-specific patterns are documented as exceptions and not promoted as defaults.

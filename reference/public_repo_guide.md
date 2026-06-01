# Public Repo Guide

## Purpose

This repository is the public-safe mirror of the GitHub customer newsletter
generation system. It contains the reusable agents, skills, prompts, knowledge
base, validation tools, selected published newsletters, and customer-safe release
materials that can be shared without private run logs or internal evidence.

Edits should start in the private source repository and then be published through
the allowlist-based snapshot workflow.

## Public Contents

| Area | What it contains |
|---|---|
| `.github/agents/` | Newsletter-focused agent definitions. |
| `.github/prompts/` | Pipeline and phase prompts. |
| `.github/skills/` | Reusable newsletter pipeline skills. |
| `kb/` | Public source catalog, event sources, and taxonomy. |
| `reference/` | Newsletter editorial, polishing, source, and operating guidance. |
| `tools/` | Validation, scoring, publishing, and workflow scripts. |
| `tests/` | Public-safe regression fixtures and script tests. |
| `output/` | Selected final newsletters approved for publication. |
| `release_bundle/` | Customer-safe companion material and launch bundles. |

## Publication Boundary

Do publish:

- Final newsletter outputs that passed validation and human review.
- Customer-safe release bundle files that use public first-party sources.
- Pipeline skills, prompts, validation tools, tests, and knowledge-base files.
- Documentation that explains the newsletter workflow and how to run it.

Do not publish:

- `runs/` proof bundles, session logs, or debug logs.
- `workspace/` phase intermediates beyond `.gitkeep`.
- Raw internal evidence, private paths, non-public URLs, or signed-in-only source notes.
- Unsanitized planning artifacts, experiment logs, or private cost telemetry.
- Release bundle source notes unless they have been explicitly converted into a customer-safe layer.

## Publishing Workflow

Use the private source repository as the source of truth:

```bash
bash tools/publish_public_snapshot.sh --no-commit /path/to/briancl2-customer-newsletter-public
```

Then review the public checkout diff, run validation, commit on a public branch,
and open a pull request.

The allowlist lives at `tools/public_snapshot_allowlist.txt`. Target-only files
that should be removed during publication live in `tools/public_snapshot_prune.txt`.

## Review Checklist

- The public checkout has no local machine paths, private URLs, or internal-only evidence markers.
- Generated newsletters changed by the sync pass `make validate-newsletter FILE=...`.
- The public checkout passes `make test-all` before the pull request is opened.
- Release bundle links point only to public sources or customer-safe files.
- Public docs describe this newsletter generator, not unrelated source repositories.

# Copilot App Source Intelligence

> Created from the May 2026 production correction. The Copilot App release
> stream may require authenticated GitHub access even when final customer-facing
> prose must use public changelog or docs links.

## Extraction Profile

- **Primary public announcement**: GitHub Blog / Changelog entries for the
  Copilot App and its public anchors.
- **Evidence stream**: GitHub release stream when available to the operator via
  authenticated `gh api` or authenticated browser access.
- **Publication boundary**: authenticated release URLs are evidence-only unless
  publication policy explicitly changes. Final newsletter prose should use
  public-safe changelog/docs anchors.
- **Current May 2026 baseline**: authenticated review exposed 351 accessible
  releases beginning 2026-01-30, including 104 releases in the May newsletter
  window through v0.2.13.

## Extraction Strategy

1. Start from the public changelog/docs announcement and record its section
   anchors as candidate customer-facing links.
2. If an operator-provided release stream returns anonymous 404, try
   authenticated `gh api` or authenticated browser access before declaring the
   stream unavailable.
3. Inventory release tags in scope, then group release notes into named
   customer-visible capabilities.
4. Build a capability-to-link map that separates evidence release tags from
   public-safe final links.
5. Save the canonical artifacts as `workspace/copilot_app_release_inventory_START_to_END.md`
  and `workspace/newsletter_phase3_capability_map_START_to_END.json`.
6. Write final prose only after the inventory and map exist.

## Capability Clusters To Look For

| Cluster | What To Extract | Public-Safe Link Pattern |
|---|---|---|
| GitHub context | Start from issue, pull request, prompt, or previous session | Public App changelog `start from GitHub context` anchor |
| My work | Inbox, repo filters, saved tabs, badges, table view, bulk actions, search/filter pills | Public App changelog `start from GitHub context` anchor |
| Focused sessions | Branch, files, conversation, task state, worktrees, pause/resume, tray continuity | Public App changelog `work in focused sessions` anchor |
| CLI parity | Bundled/pinned CLI, imported sessions, CLI-created session filtering, policy requirements | Public App changelog `get started` anchor |
| Steering and review | Plan tab, right panel, file tree, PR/issue details, v3 diff, review-state badges | Public App changelog `steer, validate, and ship` anchor |
| Shipping loop | Review comments/checks, PR creation, merge requirements, Agent Merge readiness | Public App changelog `steer, validate, and ship` anchor |
| Validation loop | Integrated terminal, browser testing, localhost links, screenshots, browser element picker | Public App changelog `steer, validate, and ship` anchor |
| Workflows and automation | Workflow runs, templates, gallery, branch-mode workflows, cloud sessions | Public App changelog `work in focused sessions` anchor |
| Extensibility | Skills, prompts, MCP presets, canvas commands, Toolbox MCP servers | Public App changelog `work in focused sessions` anchor or docs if available |
| Model/usage controls | Model picker, UBB labels, usage affordances, billing multiplier tolerance | UBB/model policy links when no App-specific public anchor exists |
| Enterprise readiness | Business/Enterprise preview access, Copilot CLI policy, auth/security hardening | Public App changelog `get started` anchor |

## Treatment Patterns

- **New-surface expansion**: A technical-preview App launch is a product
  category, not a routine feature. Give it feature-rich treatment when release
  evidence supports detail.
- **Inline inspectability**: If release-inventory evidence is cited, link at
  least five distinct customer-visible capability clusters inline in final
  prose.
- **Evidence/public split**: Release tags can prove synthesis, but final links
  should be public-safe. Do not include anonymous-fetch failures, private tag
  URLs, authenticated-release notes, or `[truncated]` markers in customer copy.
- **No source-tail-only summaries**: A single `[Changelog]` tail link is not
  enough when the paragraph names My work, sessions, plan/diff, terminal/browser
  validation, workflows, MCP, Agent Merge, or enterprise readiness.

## Cross-References

- `workspace/2026-05_copilot_app_release_inventory.md`
- `workspace/2026-05_cli_app_capability_map.md`
- Future canonical inventory: `workspace/copilot_app_release_inventory_START_to_END.md`
- Future canonical capability map: `workspace/newsletter_phase3_capability_map_START_to_END.json`
- `workspace/2026-05_revision_root_cause_sidecar.md`
- `LEARNINGS.md` L158 and L159
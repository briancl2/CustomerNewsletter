# Copilot CLI Source Intelligence

> Refreshed on 2026-04-16 against the official GitHub Copilot CLI docs and
> releases stream. Current local applicability receipt: `GitHub Copilot CLI
> 1.0.28`

## Extraction Profile

- **Primary release stream**: [github/copilot-cli releases](https://github.com/github/copilot-cli/releases)
- **Atom feed**: `https://github.com/github/copilot-cli/releases.atom`
- **Primary docs set**:
  - [Copilot CLI overview](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/use-copilot-cli)
  - [CLI best practices](https://docs.github.com/en/copilot/how-tos/copilot-cli/cli-best-practices)
  - [CLI programmatic reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-programmatic-reference)
  - [Autopilot](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/autopilot)
  - [`/fleet`](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/fleet)
  - [Custom agents](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/create-custom-agents-for-cli)
  - [Skills](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)
  - [Hooks](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-hooks)
  - [Plugins](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-cli-plugins)
  - [Context management](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/context-management)
  - [Copilot Memory](https://docs.github.com/en/copilot/concepts/agents/copilot-memory)
  - [Remote access](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-remote-access)
  - [BYOK and local providers](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-byok-models)
- **Content model**: fast-moving GitHub Releases stream plus documentation pages
  that describe which capability families are current, supported, and broadly
  usable.
- **Current release framing**: treat the `1.0.x` train as the current surface.
  Older `0.0.x` calibration is historical only.
- **Critical rule**: the releases page is still the primary source for what
  changed; docs are the primary source for whether a capability family is
  supported and how it is expected to work.

## Extraction Strategy

1. Fetch the releases stream and collect stable releases within `DATE_RANGE`.
2. Cross-check the official docs to determine whether the release items belong
   to an active capability family or are one-off implementation details.
3. Aggregate features into one consolidated CLI narrative, never per-version
   bullets.
4. Prioritize features in these groups:
   - **Major modes**: plan mode, autopilot, review mode
   - **Agent orchestration**: `/fleet`, delegate, background agents, subagents
   - **Customization**: custom agents, skills, hooks, instructions, slash
     commands, plugins
   - **Context and memory**: repository memory, context management, chronicle,
     session behavior
   - **Connectivity and extensibility**: MCP, remote access, BYOK or local
     providers, SDK or protocol surfaces
   - **Operational quality-of-life**: permissions, diff mode, approval flow,
     tool UX
5. Skip version-by-version bugfix recaps unless they materially affect
   enterprise governance, blocked workflows, or a major feature family.

## What Survives (High Signal)

These Copilot CLI feature types consistently matter for newsletter-quality
coverage:

- **Major new modes**: plan mode, autopilot, review-oriented flows
- **Parallel or delegated execution**: `/fleet`, delegate, subagents, task
  distribution
- **Customization surface**: custom agents, skills, hooks, instructions,
  slash-command ergonomics, plugins
- **Memory and context**: repository memory, context controls, session history,
  chronicle or similar session-data surfaces
- **Integration surfaces**: MCP, remote access, BYOK or local providers,
  protocol or SDK surfaces
- **Operational controls**: approval, permissions, mode flags, repo-local
  configuration, and other workflow-shaping controls

## What Gets Cut (Low Signal)

- **Minor keybindings and UI polish** unless they materially change workflow
- **Theme and styling changes**
- **Routine bug fixes** unless security-related or tied to a major feature
- **Deep protocol internals** that do not change what operators can actually do
- **Platform-specific fixes** that are too narrow to matter to enterprise
  readers

## Treatment Patterns

- **Single consolidated bullet**: Copilot CLI should still usually appear as
  one bundled item in the broader Copilot tooling story, not as a per-release
  changelog dump.
- **High-volume does not mean short**: when a cycle has >=10 stable CLI releases
  or >=5 major capability families, write one dense February-style treatment
  with concrete command/feature names and representative inline release/docs
  links. A generic family summary is a failure.
- **Artifact contract**: high-volume CLI windows require
  `workspace/copilot_cli_release_inventory_START_to_END.md` before synthesis and
  `workspace/newsletter_phase3_capability_map_START_to_END.json` before final
  prose. Final bullets must carry at least six inline capability links; trailing
  generic source links do not satisfy the gate.
- **Capability-family framing**: describe what the CLI can now do for operators
  and teams, not just what flags were added.
- **Enterprise signal first**: prefer changes that affect governance,
  orchestration, context control, extensibility, or production workflow shape.
- **Docs plus release link pairing**: use one official doc link for behavior
  context and one releases link for current change velocity.
- **Current-host awareness**: when the repo itself relies on `copilot -p`,
  prioritize features that matter to headless or repo-driven use even if the
  broader product surface is larger.

## Capability Families For High-Volume Windows

Use these families when deciding whether the `>=5 major capability families`
trigger fires. Do not count synonyms or alternate entry points as separate
families.

| Family | Examples |
|---|---|
| Command/control modes | `--mode`, `--autopilot`, `--plan`, `/autopilot`, `/review` |
| Remote and multi-device continuity | `/remote on`, `--remote`, `/keep-alive`, mobile/web/VS Code steering |
| Session management | `--session-id`, `--resume`, `--continue`, named sessions |
| Plugin/extensibility | plugin marketplace, deterministic plugin dirs, `/skills`, custom agents |
| Integration ecosystem | MCP, ACP, SDK, OpenTelemetry, hooks |
| Observability/cost | AI Credits, token display, `/chronicle`, memory controls |
| Provider/model choice | BYOK, local providers, model picker, auto model, reasoning effort |
| Security/policy | permissions, approvals, sandboxing, secure prompt mode, RCE protection |

## Cross-Referencing

- Use the releases page as the main feature-discovery source.
- Use the docs pages above to validate whether a capability family is current
  and broadly supported.
- Cross-reference `reference/editorial-intelligence.md` when deciding whether
  a CLI change is strong enough for the newsletter.
- Cross-reference `reference/deep-research-report.md` when portability,
  instructions, skills, or prompt-surface governance are central to the story.

## Repo-Operator Notes

- The local execution surface on this machine is currently `GitHub Copilot CLI
  1.0.28`, which is the minimum baseline this repo should assume for current
  operating guidance.
- The repo's production path remains a single-shot `copilot -p` oracle plus a
  retained proof wrapper. Do not treat autopilot or `/fleet` as the live
  production path for this repo unless a later owner-side batch explicitly
  changes that contract.

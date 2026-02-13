# Current State Snapshot

## State Header

- **AS_OF_DATE:** 2026-02-10
- **LAST_RUN_DATE:** 2026-02-10

## Latest Known Surface States

| Surface | Latest known version/release | Last release/update date | Reference URL | What changed |
|---|---|---|---|---|
| GitHub.com web experiences | Copilot changelog latest item: "GPT-5.3-Codex is now generally available for GitHub Copilot" | 2026-02-09 | https://github.blog/changelog/label/copilot/feed/ | Material: model availability update announced in Copilot stream. |
| VS Code | VS Code 1.109; Copilot Chat extension 0.38.2026021002 | 2026-02-04 (VS Code), 2026-02-10 (extension) | https://code.visualstudio.com/updates/v1_109 and https://marketplace.visualstudio.com/items?itemName=GitHub.copilot-chat | Material: standalone Copilot extension deprecated; Copilot Chat is canonical extension path in VS Code 1.109 notes. |
| Visual Studio | Visual Studio 18.2.1 | 2026-01-20 | https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes | No material change noted beyond normal release progression in this run. |
| JetBrains IDEs | GitHub Copilot plugin 1.5.64-243 | 2026-02-05 | https://plugins.jetbrains.com/api/plugins/17718/updates?channel=&size=10 | Material: plugin versions ahead of matrix latest-release rows observed. |
| Xcode | GitHub Copilot for Xcode 0.47.0 | 2026-02-05 | https://github.com/github/CopilotForXcode/releases/tag/0.47.0 | Material: active release cadence continued; matrix latest-release rows lag current tag. |
| Eclipse | Marketplace "Date Updated" timestamp | 2026-01-27 | https://marketplace.eclipse.org/content/github-copilot#details | Material: official update-site URL in docs returned 404 during this run; marketplace listing still active. |
| Copilot CLI | v0.0.406 | 2026-02-07 | https://github.com/github/copilot-cli/releases/tag/v0.0.406 | Material: recent CLI release available. |
| OpenCode (officially Copilot-supported external surface) | v1.1.53 | 2026-02-05 | https://github.blog/changelog/2026-01-16-github-copilot-now-supports-opencode/ and https://github.com/anomalyco/opencode/releases/tag/v1.1.53 | Material: GitHub announced Copilot support for OpenCode; active repo is `anomalyco/opencode`; legacy `opencode-ai/opencode` archived. |
| NeoVim | `copilot.vim` tag v1.59.0 | 2026-01-09 (latest tag commit date) | https://github.com/github/copilot.vim | No material change noted beyond ongoing tag progression. |
| GitHub Mobile | Docs-based surface status | N/A | https://docs.github.com/en/copilot/how-tos/chat-with-copilot/chat-in-mobile | No material change noted in this run. |
| Windows Terminal Canary | Docs-based surface status | N/A | https://docs.github.com/en/copilot/how-tos/chat-with-copilot/chat-in-windows-terminal | No material change noted in this run. |
| Azure Data Studio | Docs-based surface status | N/A | https://learn.microsoft.com/en-us/azure-data-studio/extensions/github-copilot-extension-overview | No material change noted in this run. |

## Notable Deprecations and Migrations Affecting Guidance

1. **VS Code extension migration:** VS Code 1.109 release notes mark the standalone GitHub Copilot extension as deprecated and point to GitHub Copilot Chat as the active extension path.
2. **Legacy metrics API retirement:** GitHub announced sunset dates for legacy Copilot metrics APIs (March 2, 2026 and April 2, 2026) and recommends migration to newer usage metrics endpoints (https://github.blog/changelog/2026-01-29-closing-down-notice-of-legacy-copilot-metrics-apis/).
3. **OpenCode repository migration:** `opencode-ai/opencode` is archived; canonical active repository is `anomalyco/opencode`.
4. **Eclipse setup risk:** documented Eclipse update-site URL returned 404 on 2026-02-10; keep marketplace path as fallback and re-validate monthly.
5. **Matrix drift caveat:** feature matrix "latest releases" tables can lag marketplace/release channels.

## Notes

- This is the initial KB run snapshot for this repository, so no prior-run delta baseline exists.

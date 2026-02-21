# Phase 1B Interim: JetBrains Sources
**DATE_RANGE**: 2026-02-14 to 2026-02-21
**Reference Year**: 2026
**Generated**: 2026-02-21
**URLs Processed**: 1 (plugin updates API)

## Coverage Validation
- Earliest item date: 2026-02-17
- Latest item date: 2026-02-17
- Total items extracted: 3
- DATE_RANGE boundary verification: ✅

## Extracted Items

### [JetBrains Copilot Plugin 1.5.68: MCP allowlist enforcement] (GA)
- **Date**: 2026-02-17
- **Description**: Plugin version 1.5.68 adds enforcement of MCP server allowlists configured by organization administrators. When an organization policy restricts MCP servers, the plugin now prevents connection to unauthorized servers and displays a clear notification to the user. Previously, allowlist configuration was available but enforcement was not consistent.
- **Links**: [Plugin Version](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable/905123)
- **Relevance Score**: 8/10
- **IDE Support**: JetBrains IDEs
- **Enterprise Impact**: Critical governance feature for enterprises controlling which MCP servers developers can connect to, ensuring data does not flow to unauthorized external services.

### [JetBrains Copilot Plugin 1.5.68: improved agent session persistence] (GA)
- **Date**: 2026-02-17
- **Description**: Agent sessions in JetBrains IDEs now persist across IDE restarts, allowing developers to resume agentic work without losing context. Session state including conversation history, tool results, and pending actions is saved to the project directory.
- **Links**: [Plugin Version](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable/905123)
- **Relevance Score**: 7/10
- **IDE Support**: JetBrains IDEs
- **Enterprise Impact**: Reduces disruption from IDE restarts during long-running agentic tasks, improving developer workflow continuity.

### [JetBrains Copilot Plugin 1.5.68: Claude Opus 4.6 Fast model support] (GA)
- **Date**: 2026-02-17
- **Description**: Added support for the Claude Opus 4.6 Fast model variant in JetBrains IDEs, matching the availability across other supported IDEs. Developers can select this model from the model picker for faster interactive coding responses.
- **Links**: [Plugin Version](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable/905123)
- **Relevance Score**: 7/10
- **IDE Support**: JetBrains IDEs
- **Enterprise Impact**: Ensures model parity across IDEs, allowing teams using JetBrains IDEs to access the same fast model options available in VS Code and Visual Studio.

## Processing Notes
- One plugin version (1.5.68) released within the Feb 14-21 window
- Build variants 241 and 243 both available
- Features decomposed from single version into individual entries per extraction format requirements

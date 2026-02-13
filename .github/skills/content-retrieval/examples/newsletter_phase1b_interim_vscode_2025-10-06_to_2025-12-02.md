# VS Code Release Notes: Copilot & AI Features (2025-10-06 to 2025-12-02)

**Source**: VS Code Release Notes (v1.105, v1.106)
**Processing Date**: 2025-12-02
**Context**: Phase 1B Chunk 2 - Extraction of AI/Copilot features.

---

## VS Code v1.106 (Released 2025-11-12)

### Agent Sessions View (GA)
- **Date**: 2025-11-12
- **Description**: A centralized location for managing active chat sessions, including local sessions and background agents (Copilot coding agent, Copilot CLI, OpenAI Codex). It supports searching sessions and a consolidated view across providers.
- **Links**: [VS Code v1.106](https://code.visualstudio.com/updates/v1_106#_agent-sessions-view) | [Docs](https://code.visualstudio.com/docs/copilot/chat/chat-sessions/#_agent-sessions-view)
- **Relevance Score**: 10/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Improves visibility and management of multi-agent workflows, essential for complex development tasks involving background processes.

### Plan Agent (GA)
- **Date**: 2025-11-12
- **Description**: A built-in agent that helps break down complex tasks step-by-step before code is written. It prompts for clarifying questions and generates a detailed implementation plan for user approval before execution by Copilot.
- **Links**: [VS Code v1.106](https://code.visualstudio.com/updates/v1_106#_plan-agent) | [Docs](https://code.visualstudio.com/docs/copilot/chat/chat-planning)
- **Relevance Score**: 10/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Reduces rework and improves code quality by ensuring requirements are captured and planned upfront.

### Cloud Agents Integration (GA)
- **Date**: 2025-11-12
- **Description**: Migrated Copilot coding agent integration from GitHub Pull Request extension to Copilot Chat extension for a native experience. Enables smoother transitions between VS Code and GitHub Mission Control.
- **Links**: [VS Code v1.106](https://code.visualstudio.com/updates/v1_106#_cloud-agents) | [Docs](https://code.visualstudio.com/docs/copilot/copilot-coding-agent)
- **Relevance Score**: 9/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Streamlines the workflow between local IDE and cloud-based agentic workflows.

### CLI Agents Integration (GA)
- **Date**: 2025-11-12
- **Description**: Integration with Copilot CLI allows creating and resuming CLI agent sessions in a chat editor or integrated terminal. Supports sending messages, switching models, and attaching context.
- **Links**: [VS Code v1.106](https://code.visualstudio.com/updates/v1_106#_cli-agents) | [Docs](https://github.com/features/copilot/cli/)
- **Relevance Score**: 8/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Unifies the developer experience across GUI and CLI tools.

### Custom Agents (Renamed from Chat Modes) (GA)
- **Date**: 2025-11-12
- **Description**: "Chat modes" have been renamed to "Custom Agents". Definition files are now located in `.github/agents` with `.agents.md` suffix. Supports `target` frontmatter to optimize for VS Code or GitHub Copilot Cloud.
- **Links**: [VS Code v1.106](https://code.visualstudio.com/updates/v1_106#_chat-modes-renamed-to-custom-agents) | [Docs](https://code.visualstudio.com/docs/copilot/customization/custom-agents)
- **Relevance Score**: 9/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Standardizes agent definition for easier sharing and customization within teams.

### Inline Suggestions Open Source (GA)
- **Date**: 2025-11-12
- **Description**: Inline suggestions have been open sourced and merged into the `vscode-copilot-chat` repository. The GitHub Copilot extension and Chat extension are being consolidated into a single experience.
- **Links**: [VS Code v1.106](https://code.visualstudio.com/updates/v1_106#_inline-suggestions-are-open-source) | [Blog](https://code.visualstudio.com/blogs/2025/11/04/openSourceAIEditorSecondMilestone)
- **Relevance Score**: 8/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Transparency and consolidation of extensions simplify management and deployment.

### Reasoning / Chain of Thought Expansion (Experimental)
- **Date**: 2025-11-12
- **Description**: The `chat.agent.thinkingStyle` setting is now available for more models including GPT-5-Codex, GPT-5, GPT-5 mini, and Gemini 2.5 Pro. Added `fixedScrolling` style and support for collapsing tool calls.
- **Links**: [VS Code v1.106](https://code.visualstudio.com/updates/v1_106#_reasoning-experimental)
- **Relevance Score**: 9/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Provides visibility into model reasoning, increasing trust and debuggability of AI responses.

### Inline Chat v2 (Preview)
- **Date**: 2025-11-12
- **Description**: A modernized inline chat experience built for single prompt, single file, and code changes only. It offers a lighter UI and simplified workflow.
- **Links**: [VS Code v1.106](https://code.visualstudio.com/updates/v1_106#_inline-chat-v2-preview)
- **Relevance Score**: 8/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Improves speed and usability for quick, localized code edits.

### MCP Server Access for Organizations (GA)
- **Date**: 2025-11-12
- **Description**: Supports MCP registry configured through GitHub organization policies. Enables organizations to control which MCP servers can be installed and started via `chat.mcp.gallery.serviceUrl` and `chat.mcp.access`.
- **Links**: [VS Code v1.106](https://code.visualstudio.com/updates/v1_106#_mcp-server-access-for-your-organization) | [Docs](https://docs.github.com/en/copilot/how-tos/administer-copilot/configure-mcp-server-access)
- **Relevance Score**: 10/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Critical for governance and security of MCP servers in enterprise environments.

### Language Models Editor (Preview)
- **Date**: 2025-11-12
- **Description**: A centralized editor to view and manage all available language models for GitHub Copilot Chat. Allows filtering by provider, capability, and visibility, and adding models from installed providers.
- **Links**: [VS Code v1.106](https://code.visualstudio.com/updates/v1_106#_language-models-editor)
- **Relevance Score**: 8/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Simplifies management of diverse model options available to developers.

### Save Conversation as Prompt (GA)
- **Date**: 2025-11-12
- **Description**: New `/savePrompt` command generates a generalized prompt file based on the current chat conversation, facilitating reuse and sharing of effective prompt patterns.
- **Links**: [VS Code v1.106](https://code.visualstudio.com/updates/v1_106#_save-conversation-as-prompt) | [Docs](https://code.visualstudio.com/docs/copilot/customization/prompt-files)
- **Relevance Score**: 8/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Promotes knowledge sharing and standardization of effective prompting strategies.

### Terminal Tool Improvements (GA)
- **Date**: 2025-11-12
- **Description**: Integrated parser for better subcommand detection, experimental file write/redirection detection, and shell-specific prompts for PowerShell, bash, zsh, and fish.
- **Links**: [VS Code v1.106](https://code.visualstudio.com/updates/v1_106#_terminal-tool)
- **Relevance Score**: 7/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Increases safety and reliability of agentic terminal operations.

### Python: Copilot Hover Summaries as Docstring (GA)
- **Date**: 2025-11-12
- **Description**: Allows inserting AI-generated summaries directly into code as docstrings via the "Add as docstring" command in Copilot Hover Summaries.
- **Links**: [VS Code v1.106](https://code.visualstudio.com/updates/v1_106#_add-copilot-hover-summaries-as-docstring)
- **Relevance Score**: 7/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Accelerates documentation and improves code maintainability.

---

## VS Code v1.105 (Released 2025-10-09)

### Plan Agent (Preview/Insiders)
- **Date**: 2025-10-09
- **Description**: Introduction of the built-in plan agent to analyze tasks and generate implementation plans. (Note: Highlighted as Insiders feature in this release, seemingly GA/broadened in v1.106).
- **Links**: [VS Code v1.105](https://code.visualstudio.com/updates/v1_105#_plan-agent)
- **Relevance Score**: 9/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Early access to agentic planning capabilities.

### Handoffs for Custom Chat Modes (Insiders)
- **Date**: 2025-10-09
- **Description**: Enables guided workflows that transition between chat modes with suggested next steps and pre-filled prompts, defined in frontmatter metadata.
- **Links**: [VS Code v1.105](https://code.visualstudio.com/updates/v1_105#_handoffs) | [Docs](https://code.visualstudio.com/docs/copilot/customization/custom-chat-modes#_handoffs)
- **Relevance Score**: 8/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Orchestrates multi-step development workflows.

### Isolated Subagents (Insiders)
- **Date**: 2025-10-09
- **Description**: Allows delegating tasks to autonomous subagents (e.g., for research) that operate in their own context window without user interaction, returning results to the main session.
- **Links**: [VS Code v1.105](https://code.visualstudio.com/updates/v1_105#_isolated-subagents) | [Docs](https://code.visualstudio.com/docs/copilot/chat/chat-sessions#_subagents)
- **Relevance Score**: 9/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Optimizes context management and parallelizes task execution.

### MCP Marketplace (Preview)
- **Date**: 2025-10-09
- **Description**: Built-in MCP marketplace in the Extensions view to browse and install MCP servers from the GitHub MCP registry.
- **Links**: [VS Code v1.105](https://code.visualstudio.com/updates/v1_105#_mcp-marketplace-preview)
- **Relevance Score**: 10/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Simplifies discovery and installation of MCP servers, accelerating ecosystem adoption.

### Autostart MCP Servers (GA)
- **Date**: 2025-10-09
- **Description**: New or outdated MCP servers start automatically when a chat message is sent, with non-intrusive indicators for attention.
- **Links**: [VS Code v1.105](https://code.visualstudio.com/updates/v1_105#_autostart-mcp-servers)
- **Relevance Score**: 7/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Improves user experience by reducing manual setup steps for MCP.

### Resolve Merge Conflicts with AI (GA)
- **Date**: 2025-10-09
- **Description**: New action to resolve git merge conflicts with AI. Opens Chat view and starts an agentic flow with merge base and branch changes as context.
- **Links**: [VS Code v1.105](https://code.visualstudio.com/updates/v1_105#_resolve-merge-conflicts-with-ai)
- **Relevance Score**: 9/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Significantly reduces time and complexity in resolving merge conflicts.

### Model Availability (GPT-5-Codex, Claude Sonnet 4.5) (GA)
- **Date**: 2025-10-09
- **Description**: Added support for GPT-5-Codex (optimized for agentic coding) and Claude Sonnet 4.5 in chat.
- **Links**: [VS Code v1.105](https://code.visualstudio.com/updates/v1_105#_model-availability)
- **Relevance Score**: 10/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Access to state-of-the-art models for improved coding and reasoning.

### Chain of Thought / Thinking Tokens (Experimental)
- **Date**: 2025-10-09
- **Description**: Shows the model’s reasoning as it responds (thinking tokens) as expandable sections. Initially for GPT-5-Codex.
- **Links**: [VS Code v1.105](https://code.visualstudio.com/updates/v1_105#_chain-of-thought-experimental)
- **Relevance Score**: 9/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Enhances transparency of AI decision-making.

### Sign in with Apple Accounts (GA)
- **Date**: 2025-10-09
- **Description**: Support for signing in or setting up a GitHub Copilot account using an Apple account.
- **Links**: [VS Code v1.105](https://code.visualstudio.com/updates/v1_105#_sign-in-with-apple-accounts)
- **Relevance Score**: 6/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Broadens authentication options for users.

### Nested AGENTS.md Support (Experimental)
- **Date**: 2025-10-09
- **Description**: Support for `AGENTS.md` files in subfolders, enabling specific context and instructions for different parts of the codebase.
- **Links**: [VS Code v1.105](https://code.visualstudio.com/updates/v1_105#_support-for-nested-agentsmd-files-experimental)
- **Relevance Score**: 8/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Allows for granular, project-structure-aware agent configuration.

### Run Tests with Code Coverage (GA)
- **Date**: 2025-10-09
- **Description**: The `runTests` tool in chat now reports test code coverage to the agent, enabling it to generate and verify tests that cover the code.
- **Links**: [VS Code v1.105](https://code.visualstudio.com/updates/v1_105#_run-tests-with-code-coverage)
- **Relevance Score**: 8/10
- **IDE Support**: VS Code
- **Enterprise Impact**: Improves test quality and ensures AI-generated tests meet coverage requirements.

---

## Processing Notes
- **v1.105 (Oct 2025)**: Major focus on "Agentic" features (Plan agent, Subagents, Handoffs) coinciding with GitHub Universe. Introduction of GPT-5-Codex and Chain of Thought.
- **v1.106 (Nov 2025)**: Refinement of Agent features (Agent Sessions View, renaming Chat Modes to Custom Agents). Significant MCP updates (Org policies, Registry).
- **Overlap**: "Plan Agent" and "Reasoning" appear in both, indicating rapid iteration from Preview/Insiders to broader availability or enhancement.

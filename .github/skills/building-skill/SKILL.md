---
name: building-skill
description: "Creates complete Agent Skills from user requirements. Use when the user wants to create, build, design, or generate a new skill, or when they describe automation, workflows, or specialized AI capabilities they want to package as reusable skills. Produces SKILL.md files, scripts, references, assets, and examples following the Agent Skills specification (agentskills.io). Keywords: create skill, build skill, new skill, design skill, generate skill."
license: MIT
metadata:
  author: briancl2
  version: "1.0"
  category: system
---

# Skill Builder

Create complete, production-ready Agent Skills from natural language descriptions. This skill guides you through understanding requirements, planning structure, and generating all necessary files.

## What This Skill Produces

A complete skill package ready for distribution:
```
skill-name/
├── SKILL.md              # Core instructions + metadata
├── scripts/              # Executable automation (Python, Bash)
├── references/           # Documentation loaded into context as needed
├── assets/              # Templates, icons, boilerplate (used in output)
└── examples/            # Input/output examples for testing
```

## Workflow Overview

```mermaid
flowchart LR
    A[Gather Requirements] --> B[Plan Skill Structure]
    B --> C[Generate Core SKILL.md]
    C --> D[Create Bundled Resources]
    D --> E[Generate Test Cases]
    E --> F[Validate & Package]
```

---

## Step 1: Gather Requirements

Ask targeted questions to understand the skill's purpose. Avoid overwhelming—start with essentials:

### Required Information

1. **Primary Purpose**: "What should this skill help accomplish?"
2. **Trigger Scenarios**: "What would a user say or do that should activate this skill?"
3. **Concrete Examples**: "Give me 2-3 specific examples of how you'd use this skill."

### Contextual Questions (as needed)

- **Input/Output Format**: "What input does the skill receive? What should it produce?"
- **Degree of Freedom**: "Should the output be strictly formatted or flexible?"
- **External Dependencies**: "Does this require specific tools, APIs, or file types?"
- **Domain Knowledge**: "Is there specialized knowledge the skill needs?"

### Conclude Step 1 When

You can describe:
- 3+ concrete usage examples
- Clear trigger conditions
- Expected input/output patterns
- Any special requirements or constraints

---

## Step 2: Plan Skill Structure

Analyze each concrete example to determine what reusable resources to include.

### Decision Framework

For each example, ask:

| Question | If YES → Include |
|----------|-----------------|
| Does it require repetitive code? | `scripts/` - executable utilities |
| Does it need domain knowledge? | `references/` - documentation |
| Does it use templates/boilerplate? | `assets/` - files used in output |
| Does it benefit from examples? | `examples/` - input/output pairs |

### Resource Planning Template

```markdown
## Planned Resources for [skill-name]

### scripts/
- [ ] script_name.py - Purpose: [what it does]

### references/
- [ ] topic.md - Purpose: [what knowledge it provides]

### assets/
- [ ] template.ext - Purpose: [how it's used in output]

### examples/
- [ ] example_input.txt → example_output.txt
```

### Structure Patterns

**1. Workflow-Based** (sequential processes)
- Structure: Overview → Decision Tree → Step 1 → Step 2...
- Best for: Multi-step procedures with clear phases
- Example: Document processing, deployment pipelines

**2. Task-Based** (tool collections)
- Structure: Overview → Quick Start → Task Category 1 → Task Category 2...
- Best for: Skills with multiple independent operations
- Example: PDF tools, image editor, file utilities

**3. Reference/Guidelines** (standards or specs)
- Structure: Overview → Guidelines → Specifications → Usage...
- Best for: Brand guidelines, coding standards, documentation
- Example: Style guide, API documentation generator

**4. Capabilities-Based** (integrated systems)
- Structure: Overview → Core Capabilities → Feature 1 → Feature 2...
- Best for: Skills with interrelated features
- Example: Project management, CRM integration

---

## Step 3: Generate SKILL.md

### Frontmatter Requirements

```yaml
---
name: skill-name           # Required: lowercase, hyphens only, ≤64 chars
description: [detailed]    # Required: what + when to use, ≤1024 chars
license: MIT               # Optional: license identifier
metadata:                  # Optional: custom key-value pairs
  author: name
  version: "1.0"
  category: system         # Required: system or domain
---
```

### Description Best Practices

The description is the PRIMARY trigger mechanism. Include:

1. **What the skill does** - Clear capability statement
2. **When to use it** - Specific triggers, scenarios, file types
3. **Keywords** - Terms that might appear in user requests

**Good Example:**
```yaml
description: Creates data visualizations from CSV, JSON, or SQL query results. Use when the user asks for charts, graphs, dashboards, or wants to visualize data. Supports bar, line, pie, scatter, and heatmap chart types with customizable styling.
```

**Bad Example:**
```yaml
description: Helps with data visualization.
```

### Body Guidelines

Write instructions as if onboarding another AI agent:

- **Use imperative form**: "Generate the report" not "You should generate"
- **Be specific, not verbose**: Prefer examples over explanations
- **Reference resources with paths**: `See [schema](references/schema.md)`
- **Keep under 500 lines**: Split longer content into references

### Body Structure Template

```markdown
# [Skill Title]

[1-2 sentence overview]

## Quick Start

[Minimal steps to use the skill for the most common case]

## Core Workflow

[Main procedures with decision points]

## Reference

- [Topic 1](references/topic1.md) - When to consult
- [Topic 2](references/topic2.md) - When to consult

## Resources

List of bundled scripts/assets with brief descriptions.
```

---

## Step 4: Create Bundled Resources

### scripts/ Directory

Executable code that performs specific operations.

**Guidelines:**
- Make scripts self-contained or document dependencies clearly
- Include helpful error messages and validation
- Use Python or Bash for maximum compatibility
- Add usage documentation in script docstrings

**Script Template (Python):**
```python
#!/usr/bin/env python3
"""
[Brief description of what this script does]

Usage:
    python script_name.py <arg1> [arg2]

Example:
    python script_name.py input.txt --format json
"""

import sys

def main():
    if len(sys.argv) < 2:
        print("Usage: script_name.py <arg1> [arg2]")
        sys.exit(1)
    
    # Implementation here
    
if __name__ == "__main__":
    main()
```

### references/ Directory

Documentation loaded into context as needed. Keep individual files focused.

**Guidelines:**
- <10k words per file (recommend <5k)
- Include table of contents for files >100 lines
- Organize by domain/category when skill spans multiple areas
- Avoid duplicating content from SKILL.md

**Reference File Template:**
```markdown
# [Topic] Reference

## Overview
[Brief context for when to use this reference]

## Table of Contents
- [Section 1](#section-1)
- [Section 2](#section-2)

## Section 1
[Detailed content]

## Section 2
[Detailed content]
```

### assets/ Directory

Files used in the output Claude produces (not loaded into context).

**Common Asset Types:**
- Templates: .pptx, .docx, boilerplate directories
- Images: .png, .svg, brand assets
- Fonts: .ttf, .woff2
- Data: .csv, .json schemas

### examples/ Directory

Input/output pairs demonstrating skill usage.

**Example Structure:**
```
examples/
├── basic/
│   ├── input.txt
│   └── expected_output.txt
├── advanced/
│   ├── input.json
│   └── expected_output.json
└── edge_cases/
    ├── empty_input.txt
    └── expected_output.txt
```

---

## Step 5: Generate Test Cases

Create test cases that verify the skill works correctly.

### Test Case Template

```markdown
# Test Cases for [skill-name]

## Test 1: [Basic functionality]
**Input:** [User request or input file]
**Expected:** [What the skill should produce]
**Verification:** [How to confirm success]

## Test 2: [Edge case]
**Input:** [Edge case scenario]
**Expected:** [Correct handling]
**Verification:** [How to confirm]

## Test 3: [Error handling]
**Input:** [Invalid input]
**Expected:** [Graceful error message]
**Verification:** [Error is clear and actionable]
```

---

## Step 6: Validate & Package

### Validation Checklist

Run through before finalizing:

- [ ] **name** matches directory name exactly
- [ ] **name** is lowercase with hyphens only (no underscores)
- [ ] **description** explains both WHAT and WHEN
- [ ] **description** includes relevant keywords/triggers
- [ ] SKILL.md body is under 500 lines
- [ ] All referenced files exist at specified paths
- [ ] Scripts are executable and tested
- [ ] Examples produce expected output

### Validation Script

Use `./scripts/validate_skill.py` to check structure:

```bash
python .github/skills/building-skill/scripts/validate_skill.py path/to/skill-name
```

### Final Delivery

Provide the complete skill as:

1. **File listing** with paths
2. **Full file contents** for each file
3. **Installation instructions** (copy to `.github/skills/`)
4. **Test commands** to verify functionality

---

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|-------------|---------|----------|
| README.md in skill | Unnecessary clutter | All info goes in SKILL.md |
| "When to Use" in body | Not visible before activation | Put in description field |
| Verbose explanations | Wastes context tokens | Use examples instead |
| Deeply nested references | Hard to navigate | Max 1 level from SKILL.md |
| Duplicated content | Inconsistency risk | Single source of truth |
| Untested scripts | Runtime failures | Test before packaging |

---

## Progressive Disclosure Patterns

### Pattern 1: High-level guide with references

Keep SKILL.md lean, link to details:

```markdown
## Advanced Features

- **Form filling**: See [FORMS.md](references/forms.md) for complete guide
- **API reference**: See [API.md](references/api.md) for all methods
```

### Pattern 2: Domain-specific organization

Organize by domain when skill spans multiple areas:

```
my-skill/
├── SKILL.md (overview + navigation)
└── references/
    ├── domain1.md (loaded only when relevant)
    ├── domain2.md
    └── domain3.md
```

---

## Example: Creating a Skill

**User Request:** "I want a skill that helps me write git commit messages following conventional commits format."

### Generated Skill Structure

```
commit-message/
├── SKILL.md
├── references/
│   └── conventional-commits.md
└── examples/
    ├── basic/
    │   ├── diff.txt
    │   └── message.txt
    └── breaking-change/
        ├── diff.txt
        └── message.txt
```

### Generated SKILL.md

```markdown
---
name: commit-message
description: Generates git commit messages following Conventional Commits format. Use when committing code changes, writing commit messages, or asking for help with git commits. Analyzes diffs to determine type (feat, fix, docs, etc.) and writes clear, descriptive commit messages.
---

# Commit Message Generator

Generate commit messages from code changes.

## Quick Start

1. Analyze the staged changes or provided diff
2. Determine the commit type from change categories
3. Write a concise subject line (≤50 chars)
4. Add body with context if changes are complex

## Commit Types

| Type | When to Use |
|------|-------------|
| feat | New feature for the user |
| fix | Bug fix for the user |
| docs | Documentation only changes |
| style | Formatting, no code change |
| refactor | Code change, no feature/fix |
| test | Adding missing tests |
| chore | Build process, dependencies |

## Format

Subject: `type(scope): brief description`
Body: Explain what and why (not how)

## Reference

- [Conventional Commits Spec](references/conventional-commits.md)
```

---

## Resources

This skill includes helper scripts:

- [validate_skill.py](./scripts/validate_skill.py) - Validates skill structure and frontmatter
- [init_skill.py](./scripts/init_skill.py) - Creates new skill skeleton from template

Reference documentation:

- [design-patterns.md](references/design-patterns.md) - Workflow, output, and error handling patterns
- [specification-quick-ref.md](references/specification-quick-ref.md) - Agent Skills spec quick reference
- [examples.md](references/examples.md) - Complete skill examples at various complexity levels

Use these resources to streamline skill creation and ensure quality.

---

## Done When

- Requirements gathered with 3+ concrete usage examples
- Skill structure planned (which resources needed)
- SKILL.md generated with valid frontmatter and body
- Referenced files created (scripts/, references/, assets/, examples/)
- Validation checklist passed
- Complete skill package delivered with installation instructions

---

## Integration

### Invoked By
- Users requesting new skill creation
- `implementation-orchestrator` when building new capabilities

### Related Skills
| Skill | Relationship |
|-------|-------------|
| `auditing-skill` | Validate created skill |
| `propagating-repo-context` | Register new skill in capability map |


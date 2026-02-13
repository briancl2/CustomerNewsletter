#!/bin/bash
# local_review.sh — Review staged git changes via Copilot CLI
#
# Usage: bash .agents/skills/reviewing-code-locally/scripts/local_review.sh
#   or:  make review
#
# Reads staged diff, gathers full file context, substitutes into the review
# prompt template, and passes to copilot -p for review.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROMPT_TEMPLATE="$SKILL_DIR/references/review-prompt.md"

# Verify prompt template exists
if [ ! -f "$PROMPT_TEMPLATE" ]; then
    echo "ERROR: Review prompt template not found at $PROMPT_TEMPLATE"
    exit 1
fi

# Get staged diff, or fall back to last commit diff
DIFF=$(git diff --cached)
DIFF_SOURCE="staged changes"

if [ -z "$DIFF" ]; then
    # Nothing staged — try last commit diff instead
    DIFF=$(git diff HEAD~1)
    DIFF_SOURCE="last commit (HEAD~1)"
    if [ -z "$DIFF" ]; then
        echo "Nothing to review. Stage changes with 'git add' or have a recent commit."
        exit 1
    fi
    echo "No staged changes found. Reviewing $DIFF_SOURCE instead."
    echo ""
fi

# Gather full file context for each changed file (up to 500 lines each)
FILE_CONTEXT=""
if [ "$DIFF_SOURCE" = "staged changes" ]; then
    FILE_LIST=$(git diff --cached --name-only)
else
    FILE_LIST=$(git diff HEAD~1 --name-only)
fi
while IFS= read -r file; do
    if [ -f "$file" ]; then
        LINES=$(wc -l < "$file" | tr -d ' ')
        if [ "$LINES" -le 500 ]; then
            FILE_CONTEXT="${FILE_CONTEXT}

### ${file}

\`\`\`
$(cat "$file")
\`\`\`
"
        else
            FILE_CONTEXT="${FILE_CONTEXT}

### ${file} (${LINES} lines — skipped, exceeds 500-line limit)
"
        fi
    fi
done <<< "$FILE_LIST"

# Build the prompt by reading template and replacing placeholders
# We split the template at the placeholders and concatenate with actual content
PROMPT_BEFORE_DIFF=$(sed -n '1,/{{DIFF}}/p' "$PROMPT_TEMPLATE" | sed '$d')
PROMPT_BETWEEN=$(sed -n '/{{DIFF}}/,/{{FILE_CONTEXT}}/p' "$PROMPT_TEMPLATE" | sed '1d;$d')
PROMPT_AFTER=$(sed -n '/{{FILE_CONTEXT}}/,$p' "$PROMPT_TEMPLATE" | sed '1d')

PROMPT="${PROMPT_BEFORE_DIFF}
${DIFF}
${PROMPT_BETWEEN}
${FILE_CONTEXT}
${PROMPT_AFTER}"

# Check prompt size (macOS ARG_MAX is ~1MB)
PROMPT_SIZE=${#PROMPT}
if [ "$PROMPT_SIZE" -gt 500000 ]; then
    echo "WARNING: Prompt is ${PROMPT_SIZE} bytes (>500KB). May exceed ARG_MAX."
    echo "Consider staging fewer files or reviewing in batches."
    exit 1
fi

# Run review
FILE_COUNT=$(echo "$FILE_LIST" | grep -c . || true)
echo "Reviewing $FILE_COUNT file(s) from $DIFF_SOURCE..."
echo ""

copilot -p "$PROMPT" --no-color -s 2>&1

echo ""
echo "Review complete."

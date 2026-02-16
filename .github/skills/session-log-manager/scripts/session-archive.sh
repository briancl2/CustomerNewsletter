#!/usr/bin/env bash
# session-archive.sh — Archive sessions for a specific repo with gzip + dedup
#
# Usage:
#   bash session-archive.sh --repo <repo-name> [--output-dir <path>] [--dry-run]
#
# Archives sessions from system stores to a per-repo directory with gzip compression.
# Deduplication by session UUID — running twice produces 0 new copies.
#
# Sources:
#   1. Copilot CLI:       ~/.copilot/session-state/*/events.jsonl
#   2. VS Code Insiders:  ~/Library/Application Support/Code - Insiders/User/workspaceStorage/*/chatSessions/
#   3. VS Code Stable:    ~/Library/Application Support/Code/User/workspaceStorage/*/chatSessions/

set -uo pipefail

# --- Parse args ---
REPO_NAME=""
OUTPUT_DIR=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO_NAME="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help)
            echo "Usage: session-archive.sh --repo <repo-name> [--output-dir <path>] [--dry-run]"
            echo ""
            echo "Archives sessions for a specific repo from system stores."
            echo "Compresses with gzip. Deduplicates by session UUID."
            echo ""
            echo "Options:"
            echo "  --repo       Repository name to filter (required). Matches git_root or folder name."
            echo "  --output-dir Archive destination (default: runs/sessions/<repo>/)"
            echo "  --dry-run    Show what would be archived without copying"
            exit 0
            ;;
        *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$REPO_NAME" ]]; then
    echo "ERROR: --repo is required" >&2
    exit 1
fi

# --- Platform detection ---
if [[ "$(uname)" == "Darwin" ]]; then
    VSCODE_INSIDERS_BASE="$HOME/Library/Application Support/Code - Insiders/User/workspaceStorage"
    VSCODE_STABLE_BASE="$HOME/Library/Application Support/Code/User/workspaceStorage"
elif [[ "$(uname)" == "Linux" ]]; then
    VSCODE_INSIDERS_BASE="$HOME/.config/Code - Insiders/User/workspaceStorage"
    VSCODE_STABLE_BASE="$HOME/.config/Code/User/workspaceStorage"
else
    echo "ERROR: Unsupported platform $(uname)" >&2
    exit 1
fi

CLI_BASE="$HOME/.copilot/session-state"

# Default output dir: runs/sessions/<repo>/
if [[ -z "$OUTPUT_DIR" ]]; then
    # Find repo root (git root or cwd)
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    OUTPUT_DIR="$REPO_ROOT/runs/sessions/$REPO_NAME"
fi

# --- Init ---
archived_count=0
skipped_count=0
total_raw_bytes=0
total_compressed_bytes=0

archive_session() {
    local src_path="$1"
    local session_id="$2"
    local source_type="$3"  # "cli" or "vscode"

    local dest_name="${source_type}_${session_id}.jsonl.gz"
    local dest_path="$OUTPUT_DIR/$dest_name"

    # Dedup: skip if already archived
    if [[ -f "$dest_path" ]]; then
        skipped_count=$((skipped_count + 1))
        return
    fi

    local raw_size
    if [[ "$(uname)" == "Darwin" ]]; then
        raw_size=$(stat -f%z "$src_path" 2>/dev/null || echo 0)
    else
        raw_size=$(stat -c%s "$src_path" 2>/dev/null || echo 0)
    fi
    total_raw_bytes=$((total_raw_bytes + raw_size))

    if $DRY_RUN; then
        echo "  [DRY RUN] Would archive: $src_path → $dest_name"
        archived_count=$((archived_count + 1))
        return
    fi

    # Create output dir
    mkdir -p "$OUTPUT_DIR"

    # Compress and copy
    gzip -c "$src_path" > "$dest_path"
    
    local compressed_size
    if [[ "$(uname)" == "Darwin" ]]; then
        compressed_size=$(stat -f%z "$dest_path" 2>/dev/null || echo 0)
    else
        compressed_size=$(stat -c%s "$dest_path" 2>/dev/null || echo 0)
    fi
    total_compressed_bytes=$((total_compressed_bytes + compressed_size))

    archived_count=$((archived_count + 1))
}

# --- Scan CLI sessions ---
echo "# Session Archive: $REPO_NAME"
echo ""
echo "Scanning Copilot CLI sessions..."

if [[ -d "$CLI_BASE" ]]; then
    for session_dir in "$CLI_BASE"/*/; do
        local_events="$session_dir/events.jsonl"
        [[ -f "$local_events" ]] || continue

        # Check repo association via workspace.yaml
        ws_yaml="$session_dir/workspace.yaml"
        if [[ -f "$ws_yaml" ]]; then
            git_root=$(grep -E '^git_root:' "$ws_yaml" 2>/dev/null | head -1 | sed 's/^git_root:[[:space:]]*//' | sed 's|.*/||')
            cwd_val=$(grep -E '^cwd:' "$ws_yaml" 2>/dev/null | head -1 | sed 's/^cwd:[[:space:]]*//' | sed 's|.*/||')
            
            match=false
            if [[ "$git_root" == "$REPO_NAME" ]] || [[ "$cwd_val" == "$REPO_NAME" ]]; then
                match=true
            fi

            if $match; then
                # Extract session UUID from directory name
                session_uuid=$(basename "$session_dir")
                archive_session "$local_events" "$session_uuid" "cli"
            fi
        fi
    done
fi

# --- Scan VS Code sessions ---
scan_vscode_for_repo() {
    local base_path="$1"
    local source_label="$2"

    [[ -d "$base_path" ]] || return

    for ws_dir in "$base_path"/*/; do
        local chat_dir="$ws_dir/chatSessions"
        [[ -d "$chat_dir" ]] || continue

        # Check workspace association
        local ws_json="$ws_dir/workspace.json"
        local ws_name=""
        if [[ -f "$ws_json" ]]; then
            ws_name=$(python3 -c "
import json, sys, urllib.parse
try:
    d = json.load(open(sys.argv[1]))
    f = d.get('folder', '')
    if f:
        path = urllib.parse.unquote(f.replace('file://', ''))
        print(path.rstrip('/').split('/')[-1])
    else:
        print('')
except:
    print('')
" "$ws_json" 2>/dev/null)
        fi

        if [[ "$ws_name" == "$REPO_NAME" ]]; then
            echo "Found VS Code workspace ($source_label): $ws_name"
            for session_file in "$chat_dir"/*.jsonl "$chat_dir"/*.json; do
                [[ -f "$session_file" ]] || continue
                session_uuid=$(basename "$session_file" | sed 's/\.jsonl$//' | sed 's/\.json$//')
                archive_session "$session_file" "$session_uuid" "vscode"
            done
        fi
    done
}

echo "Scanning VS Code Insiders sessions..."
scan_vscode_for_repo "$VSCODE_INSIDERS_BASE" "Insiders"

echo "Scanning VS Code Stable sessions..."
scan_vscode_for_repo "$VSCODE_STABLE_BASE" "Stable"

# --- Report ---
echo ""
echo "## Archive Report"
echo ""
echo "| Metric | Value |"
echo "|---|---|"
echo "| Repo | $REPO_NAME |"
echo "| Output | $OUTPUT_DIR |"
echo "| New sessions archived | $archived_count |"
echo "| Skipped (already archived) | $skipped_count |"

if (( total_raw_bytes > 0 )); then
    if [[ "$(uname)" == "Darwin" ]]; then
        raw_human=$(echo "scale=1; $total_raw_bytes / 1048576" | bc)
        comp_human=$(echo "scale=1; $total_compressed_bytes / 1048576" | bc)
    else
        raw_human=$(echo "scale=1; $total_raw_bytes / 1048576" | bc)
        comp_human=$(echo "scale=1; $total_compressed_bytes / 1048576" | bc)
    fi
    echo "| Raw size | ${raw_human} MB |"
    if ! $DRY_RUN; then
        echo "| Compressed size | ${comp_human} MB |"
        if (( total_compressed_bytes > 0 )); then
            ratio=$(echo "scale=1; $total_raw_bytes / $total_compressed_bytes" | bc)
            echo "| Compression ratio | ${ratio}x |"
        fi
    fi
fi

echo ""
if $DRY_RUN; then
    echo "*Dry run — no files were copied.*"
fi

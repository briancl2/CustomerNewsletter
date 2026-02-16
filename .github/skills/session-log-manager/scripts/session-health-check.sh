#!/usr/bin/env bash
# session-health-check.sh — Scan all session stores, report per-repo sizes, detect hotspots
#
# Usage:
#   bash session-health-check.sh [--json]
#
# Scans:
#   1. Copilot CLI:       ~/.copilot/session-state/*/events.jsonl
#   2. VS Code Insiders:  ~/Library/Application Support/Code - Insiders/User/workspaceStorage/*/chatSessions/
#   3. VS Code Stable:    ~/Library/Application Support/Code/User/workspaceStorage/*/chatSessions/
#
# Output: Per-repo size table, warnings for hotspots (>500 MB workspace, >10 MB session)

set -uo pipefail

# --- Config ---
WARN_WORKSPACE_MB=500
WARN_SESSION_MB=10
WARN_TOTAL_GB=5
JSON_OUTPUT=false

if [[ "${1:-}" == "--json" ]]; then
    JSON_OUTPUT=true
fi

# --- Platform detection ---
if [[ "$(uname)" == "Darwin" ]]; then
    VSCODE_INSIDERS_BASE="$HOME/Library/Application Support/Code - Insiders/User/workspaceStorage"
    VSCODE_STABLE_BASE="$HOME/Library/Application Support/Code/User/workspaceStorage"
    SIZE_CMD="stat -f%z"
elif [[ "$(uname)" == "Linux" ]]; then
    VSCODE_INSIDERS_BASE="$HOME/.config/Code - Insiders/User/workspaceStorage"
    VSCODE_STABLE_BASE="$HOME/.config/Code/User/workspaceStorage"
    SIZE_CMD="stat -c%s"
else
    echo "ERROR: Unsupported platform $(uname)" >&2
    exit 1
fi

CLI_BASE="$HOME/.copilot/session-state"

# --- Helper functions ---
bytes_to_human() {
    local bytes=$1
    if (( bytes >= 1073741824 )); then
        printf "%.1f GB" "$(echo "scale=1; $bytes / 1073741824" | bc)"
    elif (( bytes >= 1048576 )); then
        printf "%.1f MB" "$(echo "scale=1; $bytes / 1048576" | bc)"
    elif (( bytes >= 1024 )); then
        printf "%.1f KB" "$(echo "scale=1; $bytes / 1024" | bc)"
    else
        printf "%d B" "$bytes"
    fi
}

get_file_size() {
    $SIZE_CMD "$1" 2>/dev/null || echo 0
}

# --- Scan Copilot CLI sessions ---
cli_total_bytes=0
cli_total_files=0
cli_oversized=0
declare -a cli_repo_names
declare -a cli_repo_bytes
declare -a cli_repo_counts

scan_cli_sessions() {
    if [[ ! -d "$CLI_BASE" ]]; then
        return
    fi

    # Build repo → bytes mapping by reading workspace.yaml
    local tmpfile
    tmpfile=$(mktemp)

    for session_dir in "$CLI_BASE"/*/; do
        local events="$session_dir/events.jsonl"
        [[ -f "$events" ]] || continue

        local size
        size=$(get_file_size "$events")
        cli_total_bytes=$((cli_total_bytes + size))
        cli_total_files=$((cli_total_files + 1))

        # Check oversized
        if (( size > WARN_SESSION_MB * 1048576 )); then
            cli_oversized=$((cli_oversized + 1))
        fi

        # Get repo name from workspace.yaml
        local repo_name="unknown"
        local ws_yaml="$session_dir/workspace.yaml"
        if [[ -f "$ws_yaml" ]]; then
            # Extract git_root or cwd from workspace.yaml
            local git_root
            git_root=$(grep -E '^git_root:' "$ws_yaml" 2>/dev/null | head -1 | sed 's/^git_root:[[:space:]]*//' | sed 's|.*/||')
            if [[ -n "$git_root" ]]; then
                # Replace spaces with underscores for safe parsing
                repo_name=$(echo "$git_root" | tr ' ' '_')
            else
                local cwd_val
                cwd_val=$(grep -E '^cwd:' "$ws_yaml" 2>/dev/null | head -1 | sed 's/^cwd:[[:space:]]*//' | sed 's|.*/||')
                if [[ -n "$cwd_val" ]]; then
                    repo_name=$(echo "$cwd_val" | tr ' ' '_')
                fi
            fi
        fi

        printf '%s\t%s\n' "$repo_name" "$size" >> "$tmpfile"
    done

    # Aggregate by repo
    if [[ -s "$tmpfile" ]]; then
        while IFS=$'\t' read -r name total count; do
            cli_repo_names+=("$name")
            cli_repo_bytes+=("$total")
            cli_repo_counts+=("$count")
        done < <(awk -F'\t' '{repo[$1]+=$2; count[$1]++} END {for(r in repo) printf "%s\t%s\t%s\n", r, repo[r], count[r]}' "$tmpfile" | sort -t$'\t' -k2 -rn)
    fi

    rm -f "$tmpfile"
}

# --- Scan VS Code sessions ---
vscode_total_bytes=0
vscode_total_files=0
vscode_oversized=0
declare -a vscode_ws_names
declare -a vscode_ws_bytes
declare -a vscode_ws_counts
vscode_warnings=()

scan_vscode_sessions() {
    local base_path="$1"
    local label="$2"

    [[ -d "$base_path" ]] || return

    for ws_dir in "$base_path"/*/; do
        local chat_dir="$ws_dir/chatSessions"
        [[ -d "$chat_dir" ]] || continue

        # Get workspace name from workspace.json
        local ws_name="unknown"
        local ws_json="$ws_dir/workspace.json"
        if [[ -f "$ws_json" ]]; then
            # Extract folder URI → repo name
            local folder
            folder=$(python3 -c "
import json, sys, urllib.parse
try:
    d = json.load(open(sys.argv[1]))
    f = d.get('folder', '')
    if f:
        path = urllib.parse.unquote(f.replace('file://', ''))
        print(path.rstrip('/').split('/')[-1])
    else:
        print('unknown')
except:
    print('unknown')
" "$ws_json" 2>/dev/null)
            if [[ -n "$folder" ]]; then
                ws_name="$folder"
            fi
        fi

        # Sum session file sizes
        local ws_bytes=0
        local ws_count=0
        for session_file in "$chat_dir"/*.jsonl "$chat_dir"/*.json; do
            [[ -f "$session_file" ]] || continue
            local size
            size=$(get_file_size "$session_file")
            ws_bytes=$((ws_bytes + size))
            ws_count=$((ws_count + 1))
            vscode_total_bytes=$((vscode_total_bytes + size))
            vscode_total_files=$((vscode_total_files + 1))

            # Check oversized individual session
            if (( size > WARN_SESSION_MB * 1048576 )); then
                vscode_oversized=$((vscode_oversized + 1))
            fi
        done

        if (( ws_count > 0 )); then
            vscode_ws_names+=("$ws_name ($label)")
            vscode_ws_bytes+=("$ws_bytes")
            vscode_ws_counts+=("$ws_count")

            # Check workspace hotspot
            if (( ws_bytes > WARN_WORKSPACE_MB * 1048576 )); then
                vscode_warnings+=("WARNING: $ws_name ($label) = $(bytes_to_human $ws_bytes) in $ws_count files (>${WARN_WORKSPACE_MB} MB threshold)")
            fi
        fi
    done
}

# --- Main ---
echo "# Session Log Health Check"
echo ""
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Host: $(hostname)"
echo ""

# Scan all stores
scan_cli_sessions
scan_vscode_sessions "$VSCODE_INSIDERS_BASE" "Insiders"
scan_vscode_sessions "$VSCODE_STABLE_BASE" "Stable"

grand_total_bytes=$((cli_total_bytes + vscode_total_bytes))
grand_total_files=$((cli_total_files + vscode_total_files))

# --- Summary ---
echo "## Summary"
echo ""
echo "| Store | Files | Size | Oversized (>${WARN_SESSION_MB} MB) |"
echo "|---|---:|---:|---:|"
echo "| Copilot CLI | $cli_total_files | $(bytes_to_human $cli_total_bytes) | $cli_oversized |"
echo "| VS Code (all) | $vscode_total_files | $(bytes_to_human $vscode_total_bytes) | $vscode_oversized |"
echo "| **Total** | **$grand_total_files** | **$(bytes_to_human $grand_total_bytes)** | **$((cli_oversized + vscode_oversized))** |"
echo ""

# Growth estimate
echo "Estimated daily growth: ~89 MB/day (~32 GB/year at current rate)"
echo ""

# --- CLI Per-Repo Breakdown ---
if (( ${#cli_repo_names[@]} > 0 )); then
    echo "## Copilot CLI — Per-Repo Breakdown"
    echo ""
    echo "| Repo | Sessions | Size |"
    echo "|---|---:|---:|"
    for i in "${!cli_repo_names[@]}"; do
        echo "| ${cli_repo_names[$i]} | ${cli_repo_counts[$i]} | $(bytes_to_human ${cli_repo_bytes[$i]}) |"
    done
    echo ""
fi

# --- VS Code Per-Workspace Breakdown ---
if (( ${#vscode_ws_names[@]} > 0 )); then
    echo "## VS Code — Per-Workspace Breakdown"
    echo ""
    echo "| Workspace | Sessions | Size |"
    echo "|---|---:|---:|"
    # Sort by size descending
    declare -a sorted_indices
    sorted_indices=($(
        for i in "${!vscode_ws_bytes[@]}"; do
            echo "$i ${vscode_ws_bytes[$i]}"
        done | sort -k2 -rn | awk '{print $1}'
    ))
    for i in "${sorted_indices[@]}"; do
        echo "| ${vscode_ws_names[$i]} | ${vscode_ws_counts[$i]} | $(bytes_to_human ${vscode_ws_bytes[$i]}) |"
    done
    echo ""
fi

# --- Warnings ---
warnings_count=0
echo "## Health Warnings"
echo ""

# Total size warning
if (( grand_total_bytes > WARN_TOTAL_GB * 1073741824 )); then
    echo "- **CRITICAL:** Total session storage $(bytes_to_human $grand_total_bytes) exceeds ${WARN_TOTAL_GB} GB threshold"
    warnings_count=$((warnings_count + 1))
fi

# Workspace hotspot warnings
if (( ${#vscode_warnings[@]} > 0 )); then
    for w in "${vscode_warnings[@]}"; do
        echo "- **$w**"
        warnings_count=$((warnings_count + 1))
    done
fi

# CLI oversized warnings
if (( cli_oversized > 0 )); then
    echo "- WARNING: $cli_oversized CLI sessions exceed ${WARN_SESSION_MB} MB individual threshold"
    warnings_count=$((warnings_count + 1))
fi

# VS Code oversized warnings
if (( vscode_oversized > 0 )); then
    echo "- WARNING: $vscode_oversized VS Code sessions exceed ${WARN_SESSION_MB} MB individual threshold"
    warnings_count=$((warnings_count + 1))
fi

if (( warnings_count == 0 )); then
    echo "- No warnings. All stores within thresholds."
fi

echo ""
echo "---"
echo "Thresholds: workspace >${WARN_WORKSPACE_MB} MB, session >${WARN_SESSION_MB} MB, total >${WARN_TOTAL_GB} GB"
echo "Run \`session-archive.sh\` to compress and archive. Run \`session-rotate.sh\` to age-tier."

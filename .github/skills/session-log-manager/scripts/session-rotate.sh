#!/usr/bin/env bash
# session-rotate.sh — Compress old sessions in archive, organize by age tier
#
# Usage:
#   bash session-rotate.sh [--archive-dir <path>] [--days <N>] [--dry-run]
#
# Operates ONLY on the archive directory (runs/sessions/), never on system stores.
# Compresses .jsonl files older than N days (default: 7) to .jsonl.gz
#
# Retention policy:
#   0-7 days:   Raw .jsonl (active, live access)
#   7-90 days:  .jsonl.gz (searchable via zgrep, 4-5x smaller)
#   90+ days:   Keep compressed in archive/ subfolder

set -uo pipefail

# --- Parse args ---
ARCHIVE_DIR=""
DAYS=7
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --archive-dir) ARCHIVE_DIR="$2"; shift 2 ;;
        --days) DAYS="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help)
            echo "Usage: session-rotate.sh [--archive-dir <path>] [--days <N>] [--dry-run]"
            echo ""
            echo "Compresses archived session files older than N days."
            echo "Operates only on the archive directory, never on system stores."
            echo ""
            echo "Options:"
            echo "  --archive-dir  Archive directory (default: runs/sessions/)"
            echo "  --days         Age threshold in days (default: 7)"
            echo "  --dry-run      Show what would be compressed without doing it"
            exit 0
            ;;
        *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
    esac
done

# Default archive dir
if [[ -z "$ARCHIVE_DIR" ]]; then
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    ARCHIVE_DIR="$REPO_ROOT/runs/sessions"
fi

if [[ ! -d "$ARCHIVE_DIR" ]]; then
    echo "No archive directory found at: $ARCHIVE_DIR"
    echo "Run session-archive.sh first to create the archive."
    exit 0
fi

# --- Main ---
echo "# Session Rotation"
echo ""
echo "Archive: $ARCHIVE_DIR"
echo "Threshold: $DAYS days"
echo ""

compressed_count=0
skipped_count=0
already_compressed=$(find "$ARCHIVE_DIR" -type f -name "*.jsonl.gz" 2>/dev/null | wc -l | tr -d ' ')
total_saved_bytes=0

# Find all .jsonl files (uncompressed) older than N days
while IFS= read -r -d '' file; do
    # Check file age
    if [[ "$(uname)" == "Darwin" ]]; then
        file_mtime=$(stat -f%m "$file" 2>/dev/null || echo 0)
        file_size=$(stat -f%z "$file" 2>/dev/null || echo 0)
    else
        file_mtime=$(stat -c%Y "$file" 2>/dev/null || echo 0)
        file_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
    fi

    now=$(date +%s)
    age_days=$(( (now - file_mtime) / 86400 ))

    if (( age_days < DAYS )); then
        skipped_count=$((skipped_count + 1))
        continue
    fi

    # Compress
    if $DRY_RUN; then
        echo "  [DRY RUN] Would compress: $file (${age_days}d old, $(( file_size / 1024 )) KB)"
        compressed_count=$((compressed_count + 1))
    else
        gzip "$file"
        # Calculate savings
        compressed_file="${file}.gz"
        if [[ -f "$compressed_file" ]]; then
            if [[ "$(uname)" == "Darwin" ]]; then
                new_size=$(stat -f%z "$compressed_file" 2>/dev/null || echo 0)
            else
                new_size=$(stat -c%s "$compressed_file" 2>/dev/null || echo 0)
            fi
            saved=$((file_size - new_size))
            total_saved_bytes=$((total_saved_bytes + saved))
            compressed_count=$((compressed_count + 1))
        fi
    fi
done < <(find "$ARCHIVE_DIR" -type f -name "*.jsonl" -print0 2>/dev/null)

# --- Report ---
echo ""
echo "## Rotation Report"
echo ""
echo "| Metric | Value |"
echo "|---|---|"
echo "| Files compressed | $compressed_count |"
echo "| Files skipped (recent) | $skipped_count |"
echo "| Files already compressed | $already_compressed |"

if (( total_saved_bytes > 0 )); then
    saved_mb=$(echo "scale=1; $total_saved_bytes / 1048576" | bc)
    echo "| Space saved | ${saved_mb} MB |"
fi

echo ""
if $DRY_RUN; then
    echo "*Dry run — no files were modified.*"
fi

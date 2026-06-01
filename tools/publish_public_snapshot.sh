#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(git rev-parse --show-toplevel)" && pwd -P)"
ALLOWLIST_FILE="$SOURCE_ROOT/tools/public_snapshot_allowlist.txt"
PRUNE_FILE="$SOURCE_ROOT/tools/public_snapshot_prune.txt"
TARGET_ROOT="${PUBLIC_REPO_PATH:-$HOME/Projects/CustomerNewsletter}"
COMMIT_CHANGES=0
DRY_RUN=0

validate_relative_path() {
  local rel_path="$1"
  case "$rel_path" in
    /*|../*|*/../*|*/..|..)
      echo "ERROR: unsafe relative path in snapshot config: $rel_path"
      exit 1
      ;;
  esac
}

usage() {
  cat <<'USAGE'
Usage: publish_public_snapshot.sh [--commit] [--no-commit] [--dry-run] [--target PATH] [PATH]

Copies the allowlisted public-safe snapshot from the private repo to the target
public repo, prunes known stale target-only files, scans for sensitive markers,
runs the public test suite, and leaves the result ready for PR review unless
--commit is explicitly provided.

Options:
  --commit      Commit changed files after validation.
  --no-commit   Leave changes unstaged for a PR branch review (default).
  --dry-run     Show copy/prune actions without changing files or committing.
  --target PATH Public repo target path. A positional PATH is also accepted.
  -h, --help    Show this help.
USAGE
}

TARGET_SET=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --commit)
      COMMIT_CHANGES=1
      shift
      ;;
    --no-commit)
      COMMIT_CHANGES=0
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      COMMIT_CHANGES=0
      shift
      ;;
    --target)
      shift
      if [ "$#" -eq 0 ]; then
        echo "ERROR: --target requires a path"
        exit 1
      fi
      TARGET_ROOT="$1"
      TARGET_SET=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "ERROR: unknown option: $1"
      usage
      exit 1
      ;;
    *)
      if [ "$TARGET_SET" -eq 1 ]; then
        echo "ERROR: multiple target paths provided"
        usage
        exit 1
      fi
      TARGET_ROOT="$1"
      TARGET_SET=1
      shift
      ;;
  esac
done

if [ ! -f "$ALLOWLIST_FILE" ]; then
  echo "ERROR: allowlist not found: $ALLOWLIST_FILE"
  exit 1
fi

if [ ! -d "$TARGET_ROOT/.git" ]; then
  echo "ERROR: target is not a git repo: $TARGET_ROOT"
  echo "Usage: $0 [/path/to/CustomerNewsletter]"
  exit 1
fi

TARGET_ROOT="$(cd "$TARGET_ROOT" && pwd -P)"
TARGET_GIT_ROOT="$(git -C "$TARGET_ROOT" rev-parse --show-toplevel)"
TARGET_GIT_ROOT="$(cd "$TARGET_GIT_ROOT" && pwd -P)"

if [ "$TARGET_ROOT" != "$TARGET_GIT_ROOT" ]; then
  echo "ERROR: target must be the root of a git repo: $TARGET_ROOT"
  echo "Detected git root: $TARGET_GIT_ROOT"
  exit 1
fi

case "$TARGET_ROOT" in
  "$SOURCE_ROOT"|"$SOURCE_ROOT"/*)
    echo "ERROR: target repo must not be the source repo or inside it: $TARGET_ROOT"
    exit 1
    ;;
esac

case "$SOURCE_ROOT" in
  "$TARGET_ROOT"/*)
    echo "ERROR: source repo must not be inside target repo: $SOURCE_ROOT"
    exit 1
    ;;
esac

echo "Source: $SOURCE_ROOT"
echo "Target: $TARGET_ROOT"
echo "Allowlist: $ALLOWLIST_FILE"
echo "Prune list: $PRUNE_FILE"

run_prune_list() {
  local phase="$1"
  [ -f "$PRUNE_FILE" ] || return 0

  while IFS= read -r rel_path || [ -n "$rel_path" ]; do
    case "$rel_path" in
      ""|\#*) continue ;;
    esac
    if [ "$phase" = "post-sync" ] && [ "$rel_path" = "workspace/" ]; then
      continue
    fi
    validate_relative_path "$rel_path"

    target_path="$TARGET_ROOT/$rel_path"
    if [ "$DRY_RUN" -eq 1 ]; then
      if [ -e "$target_path" ]; then
        echo "DRY PRUNE: $rel_path"
      fi
    elif [ -e "$target_path" ]; then
      rm -rf "$target_path"
      echo "PRUNE: $rel_path"
    fi
  done < "$PRUNE_FILE"
  echo "Prune phase completed: $phase"
}

run_prune_list "pre-sync"

while IFS= read -r rel_path || [ -n "$rel_path" ]; do
  case "$rel_path" in
    ""|\#*) continue ;;
  esac
  validate_relative_path "$rel_path"

  src="$SOURCE_ROOT/$rel_path"
  dst="$TARGET_ROOT/$rel_path"

  if [ -d "$src" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      if [ -d "$dst" ]; then
        rsync -ani --delete "$src/" "$dst/"
      fi
      echo "DRY SYNC dir: $rel_path"
    else
      mkdir -p "$dst"
      rsync -a --delete "$src/" "$dst/"
      echo "SYNC dir: $rel_path"
    fi
  elif [ -f "$src" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "DRY SYNC file: $rel_path"
    else
      mkdir -p "$(dirname "$dst")"
      cp -f "$src" "$dst"
      echo "SYNC file: $rel_path"
    fi
  else
    echo "WARN missing path, skipped: $rel_path"
  fi
done < "$ALLOWLIST_FILE"

run_prune_list "post-sync"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run complete; skipping scan, tests, and commit."
  exit 0
fi

echo "Running sensitive-pattern scan..."
SENSITIVE_PATTERN="(/Users/|file://|docs\.google\.com|slack\.com|sales intelligence vault|@sales-collaborator|customer account|Salesforce summaries|M365 email dumps|Revenue MCP|MEDDPICC gaps|economic buyer|renewal prep|CASE_STUDY_INTERNAL|TIMELINE_VERBATIM_UNCLIPPED|BMA_EVIDENCE_ATLAS|raw token count|provider-token accounting|private GitHub discussion)"
if ! command -v rg >/dev/null 2>&1; then
  echo "ERROR: ripgrep (rg) is required for sensitive-pattern scanning."
  exit 1
fi

set +e
rg -n -i "$SENSITIVE_PATTERN" "$TARGET_ROOT" \
  -g '!**/tools/publish_public_snapshot.sh' \
  -g '!**/tools/public_snapshot_prune.txt'
scan_status=$?
set -e

if [ "$scan_status" -eq 0 ]; then
  echo "ERROR: sensitive patterns detected in target repo."
  exit 1
elif [ "$scan_status" -ne 1 ]; then
  echo "ERROR: sensitive-pattern scan failed with exit status $scan_status."
  exit 1
fi

echo "Running full test suite in public repo..."
(
  cd "$TARGET_ROOT"
  make test-all
)

if [ "$COMMIT_CHANGES" -eq 0 ]; then
  echo "Skipping commit because --commit was not requested."
  echo "Public snapshot publish completed."
  exit 0
fi

echo "Committing snapshot in public repo (if changed)..."
(
  cd "$TARGET_ROOT"
  git add -A
  if git diff --cached --quiet; then
    echo "No changes to commit."
  else
    git commit -m "Public snapshot $(date +%F)"
    echo "Committed: Public snapshot $(date +%F)"
  fi
)

echo "Public snapshot publish completed."

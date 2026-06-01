#!/usr/bin/env bash
# Tests for prepare_newsletter_cycle.sh cycle-scoped cleanup.

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

PASS=0
FAIL=0
TMPDIR=""

cleanup() {
  if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
    rm -rf "$TMPDIR"
  fi
}
trap cleanup EXIT

assert_file_exists() {
  if [ -f "$1" ]; then
    PASS=$((PASS + 1))
  else
    echo "  FAIL: expected file to exist: $1"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_missing() {
  if [ ! -f "$1" ]; then
    PASS=$((PASS + 1))
  else
    echo "  FAIL: expected file to be missing: $1"
    FAIL=$((FAIL + 1))
  fi
}

assert_output_contains() {
  if echo "$1" | grep -q "$2"; then
    PASS=$((PASS + 1))
  else
    echo "  FAIL: output missing expected string: $2"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Prepare Newsletter Cycle Tests ==="
echo ""

TMPDIR=$(mktemp -d)
FAKE_REPO="$TMPDIR/repo"
mkdir -p "$FAKE_REPO/tools" "$FAKE_REPO/workspace"
git init -q "$FAKE_REPO"
cp tools/prepare_newsletter_cycle.sh "$FAKE_REPO/tools/prepare_newsletter_cycle.sh"

echo "current video matches" > "$FAKE_REPO/workspace/newsletter_phase4_6_video_matches_2026-04-16.md"
echo "foreign video matches" > "$FAKE_REPO/workspace/newsletter_phase4_6_video_matches_2026-03-31.md"
echo "current legacy cli inventory" > "$FAKE_REPO/workspace/2026-04_cli_release_inventory.md"
echo "current legacy app inventory" > "$FAKE_REPO/workspace/2026-04_copilot_app_release_inventory.md"
echo "current legacy capability map" > "$FAKE_REPO/workspace/2026-04_cli_app_capability_map.md"
echo "foreign legacy cli inventory" > "$FAKE_REPO/workspace/2026-03_cli_release_inventory.md"

output=$(
  cd "$FAKE_REPO" && \
  bash tools/prepare_newsletter_cycle.sh 2026-02-14 2026-04-16 --no-reuse 2>&1
)

archive_dir=$(find "$FAKE_REPO/workspace/archived/preflight" -mindepth 1 -maxdepth 1 -type d | head -n 1)

assert_file_exists "$archive_dir/newsletter_phase4_6_video_matches_2026-04-16.md"
assert_file_exists "$archive_dir/2026-04_cli_release_inventory.md"
assert_file_exists "$archive_dir/2026-04_copilot_app_release_inventory.md"
assert_file_exists "$archive_dir/2026-04_cli_app_capability_map.md"
assert_file_exists "$archive_dir/foreign_range_workspace/newsletter_phase4_6_video_matches_2026-03-31.md"
assert_file_exists "$archive_dir/foreign_range_workspace/2026-03_cli_release_inventory.md"
assert_file_missing "$FAKE_REPO/workspace/newsletter_phase4_6_video_matches_2026-04-16.md"
assert_file_missing "$FAKE_REPO/workspace/newsletter_phase4_6_video_matches_2026-03-31.md"
assert_file_missing "$FAKE_REPO/workspace/2026-04_cli_release_inventory.md"
assert_file_missing "$FAKE_REPO/workspace/2026-04_copilot_app_release_inventory.md"
assert_file_missing "$FAKE_REPO/workspace/2026-04_cli_app_capability_map.md"
assert_file_missing "$FAKE_REPO/workspace/2026-03_cli_release_inventory.md"
assert_output_contains "$output" "Quarantined 2 foreign-range workspace artifact"

echo ""
echo "==================================="
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if [ "$FAIL" -eq 0 ]; then
  echo "** ALL TESTS PASS **"
  exit 0
else
  echo "** $FAIL TEST(S) FAILED **"
  exit 1
fi

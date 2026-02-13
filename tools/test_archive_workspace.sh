#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Tests for archive_workspace.sh
# ══════════════════════════════════════════════════════════════
# Creates a temp workspace with representative files, runs the archive script,
# and asserts files moved/skipped as expected.
#
# Usage: bash tools/test_archive_workspace.sh

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
    echo "  FAIL: expected file to NOT exist: $1"
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

echo "=== archive_workspace.sh Test Suite ==="
echo ""

# ── Setup: create a temp workspace that mimics the real one ──
TMPDIR=$(mktemp -d)
FAKE_REPO="$TMPDIR/repo"
mkdir -p "$FAKE_REPO/workspace/archived"
git init -q "$FAKE_REPO"  # initialize a real git repo for git rev-parse

# Create representative files for a "2026-03" cycle
echo "url manifest content" > "$FAKE_REPO/workspace/newsletter_phase1a_url_manifest_2026-03-01_to_2026-03-31.md"
echo "discoveries content" > "$FAKE_REPO/workspace/newsletter_phase1a_discoveries_2026-03-01_to_2026-03-31.md"
echo "events content" > "$FAKE_REPO/workspace/newsletter_phase2_events_2026-03-31.md"
echo "curated content" > "$FAKE_REPO/workspace/newsletter_phase3_curated_sections_2026-03-31.md"
echo "corrections" > "$FAKE_REPO/workspace/2026-03_editorial_corrections.md"

# Also create a file from a different cycle to test isolation
echo "other cycle" > "$FAKE_REPO/workspace/newsletter_phase1a_url_manifest_2026-02-01_to_2026-02-28.md"
echo "other editorial" > "$FAKE_REPO/workspace/2026-02_editorial_review.md"

# ── Test 1: Explicit prefix archives only matching cycle ──
echo "Test 1: Explicit prefix (2026-03)"
# We need to run the script from inside the fake repo so its git rev-parse resolves to FAKE_REPO
mkdir -p "$FAKE_REPO/tools"
cp tools/archive_workspace.sh "$FAKE_REPO/tools/archive_workspace.sh"

output=$(
  cd "$FAKE_REPO" && \
  bash tools/archive_workspace.sh 2026-03 2>&1
)

# Phase files should be archived with prefix
assert_file_exists "$FAKE_REPO/workspace/archived/2026-03_newsletter_phase1a_url_manifest_2026-03-01_to_2026-03-31.md"
assert_file_exists "$FAKE_REPO/workspace/archived/2026-03_newsletter_phase1a_discoveries_2026-03-01_to_2026-03-31.md"
assert_file_exists "$FAKE_REPO/workspace/archived/2026-03_newsletter_phase2_events_2026-03-31.md"
assert_file_exists "$FAKE_REPO/workspace/archived/2026-03_newsletter_phase3_curated_sections_2026-03-31.md"

# Editorial artifacts should be archived
assert_file_exists "$FAKE_REPO/workspace/archived/2026-03_editorial_corrections.md"

# Original files should be gone
assert_file_missing "$FAKE_REPO/workspace/newsletter_phase1a_url_manifest_2026-03-01_to_2026-03-31.md"
assert_file_missing "$FAKE_REPO/workspace/2026-03_editorial_corrections.md"

# Other cycle's files should still be in workspace (not archived)
assert_file_exists "$FAKE_REPO/workspace/2026-02_editorial_review.md"

# Output should report moved count
assert_output_contains "$output" "moved"

echo "  Assertions: $((PASS)) passed so far"
echo ""

# ── Test 2: Idempotency (running again should SKIP) ──
echo "Test 2: Idempotency (re-run skips already archived)"
# Re-create one file to test the skip path
echo "recreated" > "$FAKE_REPO/workspace/newsletter_phase2_events_2026-03-31.md"
output2=$(cd "$FAKE_REPO" && bash tools/archive_workspace.sh 2026-03 2>&1)

assert_output_contains "$output2" "SKIP"

echo "  Assertions: $((PASS)) passed so far"
echo ""

# ── Test 3: Auto-detect prefix ──
echo "Test 3: Auto-detect prefix from filenames"
# Clean up and create files for auto-detection
rm -f "$FAKE_REPO/workspace/"*.md
echo "auto content" > "$FAKE_REPO/workspace/newsletter_phase1a_url_manifest_2026-04-01_to_2026-04-30.md"

output3=$(cd "$FAKE_REPO" && bash tools/archive_workspace.sh 2>&1)

assert_file_exists "$FAKE_REPO/workspace/archived/2026-04_newsletter_phase1a_url_manifest_2026-04-01_to_2026-04-30.md"
assert_file_missing "$FAKE_REPO/workspace/newsletter_phase1a_url_manifest_2026-04-01_to_2026-04-30.md"

echo "  Assertions: $((PASS)) passed so far"
echo ""

# ── Test 4: No files = error ──
echo "Test 4: No workspace files returns error"
rm -f "$FAKE_REPO/workspace/"*.md
output4=$(cd "$FAKE_REPO" && bash tools/archive_workspace.sh 2>&1 || true)

assert_output_contains "$output4" "Error"

echo ""

# ── Summary ──
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

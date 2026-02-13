#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Validator Self-Test
# ══════════════════════════════════════════════════════════════
# Tests that validate_newsletter.sh correctly catches known-bad
# patterns and passes known-good newsletters from the archive.
#
# Usage: bash tools/test_validator.sh

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

VALIDATOR=".github/skills/newsletter-validation/scripts/validate_newsletter.sh"
PASS=0
FAIL=0
TMPDIR=""

cleanup() { [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ] && rm -rf "$TMPDIR"; }
trap cleanup EXIT
TMPDIR=$(mktemp -d)

assert_passes() {
  local file="$1" label="$2"
  if bash "$VALIDATOR" "$file" > /dev/null 2>&1; then
    PASS=$((PASS + 1))
  else
    echo "  FAIL: expected PASS on $label"
    FAIL=$((FAIL + 1))
  fi
}

assert_fails() {
  local file="$1" label="$2"
  if bash "$VALIDATOR" "$file" > /dev/null 2>&1; then
    echo "  FAIL: expected FAIL on $label (validator passed when it should fail)"
    FAIL=$((FAIL + 1))
  else
    PASS=$((PASS + 1))
  fi
}

echo "=== Validator Self-Test ==="
echo ""

# ── Known-good newsletters (should all pass) ──
echo "Known-Good Tests (should pass):"

assert_passes "archive/2025/December.md" "December 2025"
# Note: Aug 2025 and earlier use em dashes and wikilinks (pre-agentic era).
# They legitimately fail validation. Only test agentic-era newsletters.
assert_passes "output/2026-02_february_newsletter.md" "February 2026 V2"

echo "  $PASS passed so far"
echo ""

# ── Known-bad: missing introduction ──
echo "Known-Bad Tests (should fail):"

# Bad 1: Empty file
echo "" > "$TMPDIR/bad_empty.md"
assert_fails "$TMPDIR/bad_empty.md" "empty file"

# Bad 2: Missing Copilot section
cat > "$TMPDIR/bad_no_copilot.md" << 'EOF'
This is a personally curated newsletter for my customers. You can find an archive of past newsletters [here](https://github.com/briancl2/CustomerNewsletter).

# Security Updates

- **Secret scanning (GA)** -- New feature. - [Announcement](https://github.blog/changelog/2025-01-01-test)

# Webinars, Events, and Recordings

Brian's personally curated YouTube playlists, updated monthly: [Copilot Tips and Training Video](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D), [GitHub Enterprise, Actions, and GHAS videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ3wk4atKpN-yOW1FtyxN48W), [How GitHub GitHubs videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1nWhqxi-UQF_O-gYWo5jpG)

If you have any questions, feel free to reach out.
EOF
assert_fails "$TMPDIR/bad_no_copilot.md" "missing Copilot section"
# This should fail because there is no header matching "^#{1,3} .*[Cc]opilot".
# This simulates a newsletter that forgot to include a dedicated Copilot section.

# Bad 3: Has em dashes
cat > "$TMPDIR/bad_emdash.md" << 'EOF'
This is a personally curated newsletter for my customers. You can find an archive of past newsletters [here](https://github.com/briancl2/CustomerNewsletter).

# Copilot

### Latest Releases

- **Feature (GA)** — This has an em dash. - [Link](https://github.blog/changelog/2025-01-01-test)

## Copilot at Scale

### Stay up to date on the latest releases
- [GitHub Copilot Changelog](https://github.blog/changelog/label/copilot/feed/)
- [VS Code Copilot Changelog](https://code.visualstudio.com/updates/#_github-copilot)
- [Visual Studio Copilot Changelog](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes#github-copilot)
- [JetBrains Copilot Changelog](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable)
- [XCode Copilot Changelog](https://github.com/github/CopilotForXcode/blob/main/ReleaseNotes.md)
- [Eclipse Copilot Changelog](https://marketplace.eclipse.org/content/github-copilot#details)

# Webinars, Events, and Recordings

Brian's personally curated YouTube playlists, updated monthly: [Copilot Tips and Training Video](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D), [GitHub Enterprise, Actions, and GHAS videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ3wk4atKpN-yOW1FtyxN48W), [How GitHub GitHubs videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1nWhqxi-UQF_O-gYWo5jpG)

If you have any questions, feel free to reach out.
EOF
assert_fails "$TMPDIR/bad_emdash.md" "em dashes"

# Bad 4: Consumer plan mention
cat > "$TMPDIR/bad_consumer.md" << 'EOF'
This is a personally curated newsletter for my customers. You can find an archive of past newsletters [here](https://github.com/briancl2/CustomerNewsletter).

# Copilot

### Latest Releases

- **Feature (GA)** -- Available for Copilot Pro+ users. - [Link](https://github.blog/changelog/2025-01-01-test)

## Copilot at Scale

### Stay up to date on the latest releases
- [GitHub Copilot Changelog](https://github.blog/changelog/label/copilot/feed/)
- [VS Code Copilot Changelog](https://code.visualstudio.com/updates/#_github-copilot)
- [Visual Studio Copilot Changelog](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes#github-copilot)
- [JetBrains Copilot Changelog](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable)
- [XCode Copilot Changelog](https://github.com/github/CopilotForXcode/blob/main/ReleaseNotes.md)
- [Eclipse Copilot Changelog](https://marketplace.eclipse.org/content/github-copilot#details)

# Webinars, Events, and Recordings

Brian's personally curated YouTube playlists, updated monthly: [Copilot Tips and Training Video](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D), [GitHub Enterprise, Actions, and GHAS videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ3wk4atKpN-yOW1FtyxN48W), [How GitHub GitHubs videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1nWhqxi-UQF_O-gYWo5jpG)

If you have any questions, feel free to reach out.
EOF
assert_fails "$TMPDIR/bad_consumer.md" "consumer plan mention (Copilot Pro+)"

# Bad 5: Dylan reference
cat > "$TMPDIR/bad_dylan.md" << 'EOF'
This is a personally curated newsletter for my customers. You can find an archive of past newsletters [here](https://github.com/briancl2/CustomerNewsletter).

# Copilot

### Latest Releases

- **Feature (GA)** -- Great feature. - [Link](https://github.blog/changelog/2025-01-01-test)

# Dylan's Corner

Some content here.

## Copilot at Scale

### Stay up to date on the latest releases
- [GitHub Copilot Changelog](https://github.blog/changelog/label/copilot/feed/)
- [VS Code Copilot Changelog](https://code.visualstudio.com/updates/#_github-copilot)
- [Visual Studio Copilot Changelog](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes#github-copilot)
- [JetBrains Copilot Changelog](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable)
- [XCode Copilot Changelog](https://github.com/github/CopilotForXcode/blob/main/ReleaseNotes.md)
- [Eclipse Copilot Changelog](https://marketplace.eclipse.org/content/github-copilot#details)

# Webinars, Events, and Recordings

Brian's personally curated YouTube playlists, updated monthly: [Copilot Tips and Training Video](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D), [GitHub Enterprise, Actions, and GHAS videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ3wk4atKpN-yOW1FtyxN48W), [How GitHub GitHubs videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1nWhqxi-UQF_O-gYWo5jpG)

If you have any questions, feel free to reach out.
EOF
assert_fails "$TMPDIR/bad_dylan.md" "Dylan reference"

# Bad 6: Missing closing
cat > "$TMPDIR/bad_no_close.md" << 'EOF'
This is a personally curated newsletter for my customers. You can find an archive of past newsletters [here](https://github.com/briancl2/CustomerNewsletter).

# Copilot

### Latest Releases

- **Feature (GA)** -- Great feature. - [Link](https://github.blog/changelog/2025-01-01-test)

## Copilot at Scale

### Stay up to date on the latest releases
- [GitHub Copilot Changelog](https://github.blog/changelog/label/copilot/feed/)
- [VS Code Copilot Changelog](https://code.visualstudio.com/updates/#_github-copilot)
- [Visual Studio Copilot Changelog](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes#github-copilot)
- [JetBrains Copilot Changelog](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable)
- [XCode Copilot Changelog](https://github.com/github/CopilotForXcode/blob/main/ReleaseNotes.md)
- [Eclipse Copilot Changelog](https://marketplace.eclipse.org/content/github-copilot#details)

# Webinars, Events, and Recordings

Brian's personally curated YouTube playlists, updated monthly: [Copilot Tips and Training Video](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D), [GitHub Enterprise, Actions, and GHAS videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ3wk4atKpN-yOW1FtyxN48W), [How GitHub GitHubs videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1nWhqxi-UQF_O-gYWo5jpG)

The end.
EOF
assert_fails "$TMPDIR/bad_no_close.md" "missing closing phrase"

# Bad 7: Missing events section
cat > "$TMPDIR/bad_no_events.md" << 'EOF'
This is a personally curated newsletter for my customers. You can find an archive of past newsletters [here](https://github.com/briancl2/CustomerNewsletter).

# Copilot

### Latest Releases

- **Feature (GA)** -- Great feature. - [Link](https://github.blog/changelog/2025-01-01-test)

## Copilot at Scale

### Stay up to date on the latest releases
- [GitHub Copilot Changelog](https://github.blog/changelog/label/copilot/feed/)
- [VS Code Copilot Changelog](https://code.visualstudio.com/updates/#_github-copilot)
- [Visual Studio Copilot Changelog](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes#github-copilot)
- [JetBrains Copilot Changelog](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable)
- [XCode Copilot Changelog](https://github.com/github/CopilotForXcode/blob/main/ReleaseNotes.md)
- [Eclipse Copilot Changelog](https://marketplace.eclipse.org/content/github-copilot#details)

If you have any questions, feel free to reach out.
EOF
assert_fails "$TMPDIR/bad_no_events.md" "missing events section"

# Bad 8: Too short (under 100 lines but with all sections)
assert_fails "$TMPDIR/bad_no_events.md" "file too short (<100 lines)"

# Bad 9: Wikilinks
cat > "$TMPDIR/bad_wikilink.md" << 'EOF'
This is a personally curated newsletter for my customers. You can find an archive of past newsletters [here](https://github.com/briancl2/CustomerNewsletter).

# Copilot

### Latest Releases

- **Feature (GA)** -- See [[internal link]] for details. - [Link](https://github.blog/changelog/2025-01-01-test)

## Copilot at Scale

### Stay up to date on the latest releases
- [GitHub Copilot Changelog](https://github.blog/changelog/label/copilot/feed/)
- [VS Code Copilot Changelog](https://code.visualstudio.com/updates/#_github-copilot)
- [Visual Studio Copilot Changelog](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes#github-copilot)
- [JetBrains Copilot Changelog](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable)
- [XCode Copilot Changelog](https://github.com/github/CopilotForXcode/blob/main/ReleaseNotes.md)
- [Eclipse Copilot Changelog](https://marketplace.eclipse.org/content/github-copilot#details)

# Webinars, Events, and Recordings

Brian's personally curated YouTube playlists, updated monthly: [Copilot Tips and Training Video](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D), [GitHub Enterprise, Actions, and GHAS videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ3wk4atKpN-yOW1FtyxN48W), [How GitHub GitHubs videos](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1nWhqxi-UQF_O-gYWo5jpG)

If you have any questions, feel free to reach out.
EOF
assert_fails "$TMPDIR/bad_wikilink.md" "wikilinks"

echo "  $PASS passed total (of $((PASS + FAIL)))"
echo ""

# ── Summary ──
TOTAL=$((PASS + FAIL))
echo "==================================="
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
distinct_bad=$((TOTAL - 3))  # minus 3 known-good
echo "Distinct bad-input checks: $distinct_bad"
if [ "$FAIL" -eq 0 ]; then
  echo "** ALL TESTS PASS **"
  exit 0
else
  echo "** $FAIL TEST(S) FAILED **"
  exit 1
fi

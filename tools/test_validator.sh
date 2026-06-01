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

cp "output/2026-02_february_newsletter.md" "$TMPDIR/good_legal_nested.md"
python3 - "$TMPDIR/good_legal_nested.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
insert = "\n## Enterprise Legal and Compliance\n\n- **Legal note** -- Customer Copyright Commitment coverage remains routed with enterprise legal readiness when it is nested below the Enterprise and Security section. - [Docs](https://docs.github.com/en/site-policy/github-terms/github-pre-release-license-terms)\n"
text = text.replace("# Enterprise and Security Updates\n", "# Enterprise and Security Updates\n" + insert, 1)
path.write_text(text, encoding="utf-8")
PY
assert_passes "$TMPDIR/good_legal_nested.md" "nested legal content under Enterprise and Security"

cp "output/2026-02_february_newsletter.md" "$TMPDIR/good_app_technical_preview.md"
python3 - "$TMPDIR/good_app_technical_preview.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
insert = "- **GitHub Copilot App (`TECHNICAL PREVIEW`)** -- The App preview gives early adopters a customer-visible path to try the new agent workspace without making release-volume claims. - [Changelog](https://github.blog/changelog/2026-05-14-github-copilot-app-is-now-available-in-technical-preview) | [Docs](https://docs.github.com/en/copilot)\n\n"
text = text.replace("## Latest Releases\n\n", "## Latest Releases\n\n" + insert, 1)
path.write_text(text, encoding="utf-8")
PY
assert_passes "$TMPDIR/good_app_technical_preview.md" "App technical preview without release inventory"

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

# Bad 10: Legal/CCC note appears before Enterprise and Security
cp "output/2026-02_february_newsletter.md" "$TMPDIR/bad_legal_venue.md"
python3 - "$TMPDIR/bad_legal_venue.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
insert = "- **Legal note** -- Customer Copyright Commitment coverage changed and Duplicate Detection is no longer required for that coverage. - [Docs](https://docs.github.com/en/site-policy/github-terms/github-pre-release-license-terms)\n\n"
text = text.replace("# Copilot\n", insert + "# Copilot\n", 1)
path.write_text(text, encoding="utf-8")
PY
assert_fails "$TMPDIR/bad_legal_venue.md" "legal/CCC content before Enterprise and Security"

# Bad 11: VS Code version inventory leaks into body prose
cp "output/2026-02_february_newsletter.md" "$TMPDIR/bad_vscode_versions.md"
python3 - "$TMPDIR/bad_vscode_versions.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
insert = "The VS Code cycle included public release signals for 1.110, 1.111, and 1.112 before the feature themes were summarized.\n\n"
text = text.replace("# Copilot\n", insert + "# Copilot\n", 1)
path.write_text(text, encoding="utf-8")
PY
assert_fails "$TMPDIR/bad_vscode_versions.md" "VS Code version sequence in body prose"

# Bad 12: App release-inventory prose is under-linked
cp "output/2026-02_february_newsletter.md" "$TMPDIR/bad_app_underlinked.md"
python3 - "$TMPDIR/bad_app_underlinked.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
insert = "- **New agent workspace (`TECHNICAL PREVIEW`)** -- I reviewed the **GitHub Copilot App** release inventory for a later cycle with **23 releases** and a broad release stream. The App now includes My work, focused sessions, plan and diff review, Agent Merge, terminal and browser validation, workflows, skills, prompts, MCP, and enterprise readiness. - [Changelog](https://github.blog/changelog/2026-05-14-github-copilot-app-is-now-available-in-technical-preview) | [Docs](https://docs.github.com/en/copilot) | [GitHub Blog](https://github.blog/) | [Release Notes](https://github.com/github/copilot-cli/releases) | [Preview Terms](https://docs.github.com/en/site-policy/github-terms/github-pre-release-license-terms)\n\n"
text = text.replace("## Latest Releases\n\n", "## Latest Releases\n\n" + insert, 1)
path.write_text(text, encoding="utf-8")
PY
assert_fails "$TMPDIR/bad_app_underlinked.md" "App release-inventory bullet under-linked"

# Bad 13: App release discovery process leaks into customer-facing prose
cp "output/2026-02_february_newsletter.md" "$TMPDIR/bad_app_process_leak.md"
python3 - "$TMPDIR/bad_app_process_leak.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
insert = "The Copilot App anonymous fetch returned 404 for github/github-app releases, but authenticated release access exposed a private tag.\n\n"
text = text.replace("# Copilot\n", insert + "# Copilot\n", 1)
path.write_text(text, encoding="utf-8")
PY
assert_fails "$TMPDIR/bad_app_process_leak.md" "App authenticated release-process leakage"

# Bad 14: High-volume CLI release prose lacks representative inline links
cp "output/2026-02_february_newsletter.md" "$TMPDIR/bad_cli_underlinked.md"
python3 - "$TMPDIR/bad_cli_underlinked.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
insert = "- **Agentic command-line platform** -- I reviewed **18 GitHub Copilot CLI releases** in scope, including **12 stable releases**. Major capabilities include plan, autopilot, remote sessions, plugins, skills, hooks, MCP, ACP, SDK, Chronicle, memory, BYOK, permissions, approvals, sandboxing, and cost visibility. - [Releases](https://github.com/github/copilot-cli/releases) | [Docs](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/use-copilot-cli) | [GitHub Blog](https://github.blog/changelog/label/copilot/) | [Release Notes](https://github.com/github/copilot-cli/releases) | [Preview Terms](https://docs.github.com/en/site-policy/github-terms/github-pre-release-license-terms) | [GitHub Previews](https://github.com/features/preview)\n\n"
text = text.replace("## Latest Releases\n\n", "## Latest Releases\n\n" + insert, 1)
path.write_text(text, encoding="utf-8")
PY
assert_fails "$TMPDIR/bad_cli_underlinked.md" "CLI high-volume release bullet under-linked"

echo "  $PASS passed total (of $((PASS + FAIL)))"
echo ""

# ── Summary ──
TOTAL=$((PASS + FAIL))
echo "==================================="
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
known_good=3
distinct_bad=$((TOTAL - known_good))
echo "Distinct bad-input checks: $distinct_bad"
if [ "$FAIL" -eq 0 ]; then
  echo "** ALL TESTS PASS **"
  exit 0
else
  echo "** $FAIL TEST(S) FAILED **"
  exit 1
fi

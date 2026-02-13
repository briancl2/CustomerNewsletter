#!/usr/bin/env python3
"""Find candidate deprecation/migration-notice lines in a newsletter markdown.

Usage:
  python3 .github/skills/deprecation-consolidation/scripts/find_deprecations.py output/YYYY-MM_month_newsletter.md

Prints matching lines with line numbers to help consolidate into a single
Enterprise & Security bullet.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


PATTERNS = [
    r"deprecat",  # deprecate, deprecated, deprecation
    r"sunset",
    r"closing down",
    r"revok",  # revoke, revoked, revocation
    r"minimum version enforcement",
    r"breaking change",
    r"migration notice",
    r"end[- ]of[- ]life|\beol\b|retir",  # retiring, retire
]


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: find_deprecations.py <newsletter_file>")
        return 2

    file_path = Path(sys.argv[1])
    if not file_path.is_file():
        print(f"Error: file not found: {file_path}")
        return 2

    text = file_path.read_text(encoding="utf-8")
    lines = text.splitlines()

    combined = re.compile("|".join(PATTERNS), re.IGNORECASE)

    matches = []
    for idx, line in enumerate(lines, start=1):
        if combined.search(line):
            matches.append((idx, line.rstrip()))

    if not matches:
        print("No deprecation/migration candidates found.")
        return 0

    print(f"Found {len(matches)} candidate line(s):")
    for idx, line in matches:
        print(f"L{idx}: {line}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

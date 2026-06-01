#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

events="$tmpdir/events.md"
sources="$tmpdir/event_sources.json"

cat > "$events" <<'MD'
# Webinars, Events, and Recordings

## Virtual Events

| Date | Event | Categories |
|------|-------|------------|
| Apr 21 | [GitHub Code Quality](https://developer.microsoft.com/en-us/reactor/events/26785) | GitHub Platform |
| May 28 | [KUWC: Making AI a Developer Team Sport](https://github.registration.goldcast.io/events/4101296b-aeb4-4676-aae7-def9b84b2027) | Copilot |

## In-Person Events

| Date | Location | Event |
|------|----------|-------|
| Jun 1 | San Francisco, CA | [GitHub Social Club San Francisco](https://github.registration.goldcast.io/events/7210a29f-5aa0-41ad-9e17-9e0329407bb8) |
| Jun 2-3 | San Francisco, CA and online | [GitHub at Microsoft Build 2026](https://github.com/resources/events/github-microsoft-build26) |
| Jun 3 | GitHub HQ, San Francisco, CA | [OpenClaw: After Hours @ GitHub](https://developer.microsoft.com/en-us/reactor/events/26780) |
| Jun 4 | GitHub HQ, San Francisco, CA | [Beyond Build: AI Developer Day](https://developer.microsoft.com/en-us/reactor/events/26781) |
MD

python3 - "$sources" <<'PY'
import json
import sys
from pathlib import Path

urls = [
    "https://github.com/resources/events/github-kuwc-part-four26",
    "https://github.com/resources/events/github-microsoft-build26",
    "https://github.com/resources/events/github-roadmap-webinar-q1",
    "https://developer.microsoft.com/en-us/reactor/events/26780",
    "https://developer.microsoft.com/en-us/reactor/events/26781",
    "https://developer.microsoft.com/en-us/reactor/events/26782",
    "https://developer.microsoft.com/en-us/reactor/events/26783",
    "https://developer.microsoft.com/en-us/reactor/events/26784",
    "https://developer.microsoft.com/en-us/reactor/events/26785",
]
payload = {
    "schema_version": 1,
    "sources": [
        {"name": "github_resources_events", "kind": "web", "fetch_ok": True},
        {"name": "reactor_series_1", "kind": "web", "fetch_ok": True},
    ],
    "candidate_urls": [{"url": url} for url in urls],
}
Path(sys.argv[1]).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

set +e
default_output="$(
  python3 tools/validate_phase2_event_quality.py \
    "$events" \
    2026-04-17 \
    2026-05-21 \
    1 \
    "$sources" \
    1 \
    "" 2>&1
)"
default_rc=$?
set -e
if [ "$default_rc" -ne 0 ]; then
  echo "ASSERTION FAILED: default helper invocation should exit cleanly and report FAIL lines"
  echo "$default_output"
  exit 1
fi
if ! grep -Fq "FAIL: Event coverage too low for 35-day range (7 < 8)" <<<"$default_output"; then
  echo "ASSERTION FAILED: default strict floor should still fail 7-of-8 event coverage"
  echo "$default_output"
  exit 1
fi

aware_output="$(
  NEWSLETTER_PHASE2_CORPUS_AWARE_EVENT_FLOOR=1 python3 tools/validate_phase2_event_quality.py \
    "$events" \
    2026-04-17 \
    2026-05-21 \
    1 \
    "$sources" \
    1 \
    ""
)"
if grep -Fq "FAIL: Event coverage too low" <<<"$aware_output"; then
  echo "ASSERTION FAILED: corpus-aware floor should accept the guarded 7-of-8 case"
  echo "$aware_output"
  exit 1
fi
if ! grep -Fq "PASS: Corpus-aware event floor accepted current-cycle event scarcity" <<<"$aware_output"; then
  echo "ASSERTION FAILED: corpus-aware floor should record the lower-floor reason"
  echo "$aware_output"
  exit 1
fi

python3 - "$sources" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["sources"][0]["fetch_ok"] = False
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

blocked_output="$(
  NEWSLETTER_PHASE2_CORPUS_AWARE_EVENT_FLOOR=1 python3 tools/validate_phase2_event_quality.py \
    "$events" \
    2026-04-17 \
    2026-05-21 \
    1 \
    "$sources" \
    1 \
    ""
)"
if ! grep -Fq "FAIL: Event coverage too low for 35-day range (7 < 8)" <<<"$blocked_output"; then
  echo "ASSERTION FAILED: corpus-aware floor must fail closed when source fetches did not all succeed"
  echo "$blocked_output"
  exit 1
fi
if ! grep -Fq "FAIL: Phase 2 event source web fetches did not all succeed" <<<"$blocked_output"; then
  echo "ASSERTION FAILED: source fetch failure should be explicit"
  echo "$blocked_output"
  exit 1
fi

echo "PASS: Phase 2 corpus-aware event floor tests"

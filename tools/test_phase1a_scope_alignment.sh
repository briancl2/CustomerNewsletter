#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/workspace"

cat > "$tmpdir/workspace/newsletter_scope_contract_2026-05-21.json" <<'JSON'
{
  "date_range": {
    "start": "2026-04-17",
    "end": "2026-05-21"
  },
  "expected_versions": {
    "vscode": [
      "1.121",
      "1.122"
    ],
    "vscode_details": {
      "1.121": {
        "actual_release_date": "2026-05-20",
        "url": "https://code.visualstudio.com/updates/v1_121"
      },
      "1.122": {
        "actual_release_date": "2026-05-21",
        "url": "https://code.visualstudio.com/updates/v1_122"
      }
    }
  }
}
JSON

cat > "$tmpdir/workspace/newsletter_phase1a_url_manifest_2026-04-17_to_2026-05-21.md" <<'MD'
# Phase 1A URL Manifest

| Version | URL |
|---------|-----|
| v1_121 | https://code.visualstudio.com/updates/v1_121 |
MD

if python3 tools/validate_phase1a_scope_alignment.py \
  2026-04-17 2026-05-21 \
  --artifact-root "$tmpdir" >"$tmpdir/missing.out" 2>&1; then
  echo "ASSERTION FAILED: missing v1_122 should fail"
  exit 1
fi
grep -q "missing scope-contract VS Code version(s): 1.122" "$tmpdir/missing.out"

cat > "$tmpdir/workspace/newsletter_scope_contract_2026-05-21.json" <<'JSON'
{
  "date_range": {
    "start": "2026-04-17",
    "end": "2026-05-21"
  },
  "expected_versions": {
    "vscode": [
      "1.12"
    ],
    "vscode_details": {
      "1.12": {
        "actual_release_date": "2026-05-21",
        "url": "https://code.visualstudio.com/updates/v1_12"
      }
    }
  }
}
JSON

cat > "$tmpdir/workspace/newsletter_phase1a_url_manifest_2026-04-17_to_2026-05-21.md" <<'MD'
# Phase 1A URL Manifest

| Version | URL |
|---------|-----|
| v1_121 | https://code.visualstudio.com/updates/v1_121 |
MD

if python3 tools/validate_phase1a_scope_alignment.py \
  2026-04-17 2026-05-21 \
  --artifact-root "$tmpdir" >"$tmpdir/substr.out" 2>&1; then
  echo "ASSERTION FAILED: v1_121 must not satisfy required v1_12"
  exit 1
fi
grep -q "missing scope-contract VS Code version(s): 1.12" "$tmpdir/substr.out"

cat > "$tmpdir/workspace/newsletter_scope_contract_2026-05-21.json" <<'JSON'
{
  "date_range": {
    "start": "2026-04-17",
    "end": "2026-05-21"
  },
  "expected_versions": {
    "vscode": [
      "1.121",
      "1.122"
    ],
    "vscode_details": {
      "1.121": {
        "actual_release_date": "2026-05-20",
        "url": "https://code.visualstudio.com/updates/v1_121"
      },
      "1.122": {
        "actual_release_date": "2026-05-21",
        "url": "https://code.visualstudio.com/updates/v1_122"
      }
    }
  }
}
JSON

cat > "$tmpdir/workspace/newsletter_phase1a_url_manifest_2026-04-17_to_2026-05-21.md" <<'MD'
# Phase 1A URL Manifest

| Version | URL |
|---------|-----|
| v1_121 | https://code.visualstudio.com/updates/v1_121 |
| v1_122 | https://code.visualstudio.com/updates/v1_122-extra |
MD

if python3 tools/validate_phase1a_scope_alignment.py \
  2026-04-17 2026-05-21 \
  --artifact-root "$tmpdir" >"$tmpdir/wrong-url.out" 2>&1; then
  echo "ASSERTION FAILED: wrong v1_122 URL should fail"
  exit 1
fi
grep -q "missing scope-contract VS Code URL(s): 1.122 -> https://code.visualstudio.com/updates/v1_122" "$tmpdir/wrong-url.out"

cat > "$tmpdir/workspace/newsletter_phase1a_url_manifest_2026-04-17_to_2026-05-21.md" <<'MD'
# Phase 1A URL Manifest

| Version | URL |
|---------|-----|
| v1_121 | https://code.visualstudio.com/updates/v1_121 |
| v1_122 | https://code.visualstudio.com/updates/v1_122 |
| v1_122 | https://code.visualstudio.com/updates/v1_122 |
MD

if python3 tools/validate_phase1a_scope_alignment.py \
  2026-04-17 2026-05-21 \
  --artifact-root "$tmpdir" >"$tmpdir/duplicate.out" 2>&1; then
  echo "ASSERTION FAILED: duplicate v1_122 should fail"
  exit 1
fi
grep -q "duplicate VS Code release version(s): 1.122" "$tmpdir/duplicate.out"

cat > "$tmpdir/workspace/newsletter_phase1a_url_manifest_2026-04-17_to_2026-05-21.md" <<'MD'
# Phase 1A URL Manifest

| Version | URL |
|---------|-----|
| v1_121 | https://code.visualstudio.com/updates/v1_121 |
| v1_122 | https://code.visualstudio.com/updates/v1_122 |
| v1_123 | https://code.visualstudio.com/updates/v1_123 |
MD

if python3 tools/validate_phase1a_scope_alignment.py \
  2026-04-17 2026-05-21 \
  --artifact-root "$tmpdir" >"$tmpdir/unexpected.out" 2>&1; then
  echo "ASSERTION FAILED: unexpected v1_123 should fail"
  exit 1
fi
grep -q "unexpected VS Code release version(s): 1.123" "$tmpdir/unexpected.out"

cat > "$tmpdir/workspace/newsletter_phase1a_url_manifest_2026-04-17_to_2026-05-21.md" <<'MD'
# Phase 1A URL Manifest

| Version | URL |
|---------|-----|
| v1_121 | https://code.visualstudio.com/updates/v1_121 |
| v1_122 | https://code.visualstudio.com/updates/v1_122 |
MD

cat > "$tmpdir/phase1a.prompt.md" <<'MD'
Rendered Phase 1A prompt
MD
touch -t 202001010000 "$tmpdir/workspace/newsletter_phase1a_url_manifest_2026-04-17_to_2026-05-21.md"
touch -t 202001010001 "$tmpdir/phase1a.prompt.md"

if python3 tools/validate_phase1a_scope_alignment.py \
  2026-04-17 2026-05-21 \
  --artifact-root "$tmpdir" \
  --prompt-file "$tmpdir/phase1a.prompt.md" >"$tmpdir/stale.out" 2>&1; then
  echo "ASSERTION FAILED: manifest older than prompt should fail"
  exit 1
fi
grep -q "possible stale manifest reuse" "$tmpdir/stale.out"

touch -t 202001010002 "$tmpdir/workspace/newsletter_phase1a_url_manifest_2026-04-17_to_2026-05-21.md"
python3 tools/validate_phase1a_scope_alignment.py \
  2026-04-17 2026-05-21 \
  --artifact-root "$tmpdir" \
  --prompt-file "$tmpdir/phase1a.prompt.md" \
  --write-receipt "$tmpdir/preflight-receipt.json" >"$tmpdir/pass.out"
grep -q "PASS: Phase 1A URL manifest covers scope-contract VS Code versions: 1.121, 1.122" "$tmpdir/pass.out"
python3 - "$tmpdir/preflight-receipt.json" <<'PY'
import json
import sys
from pathlib import Path

receipt = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert receipt["result"] == "pass"
assert receipt["scope_contract"]["sha256"]
assert receipt["phase1a_manifest"]["sha256"]
assert receipt["prompt"]["sha256"]
assert receipt["manifest_at_least_as_fresh_as_prompt"] is True
assert receipt["duplicate_versions"] == []
assert receipt["unexpected_versions"] == []
PY

render_dir="$tmpdir/render"
COPILOT_BIN=/bin/echo \
  PHASE3_STDOUT_NO_TOOLS_DISABLE_DEFAULT=1 \
  RENDER_ONLY=1 \
  RUN_DIR_OVERRIDE="$render_dir" \
  bash tools/run_newsletter_orchestrated.sh 2026-04-17 2026-05-21 >/dev/null

grep -q "expected_versions.vscode_details" "$render_dir/prompts/phase1a_manifest.prompt.md"
grep -q "validate_phase1a_scope_alignment.py" "$render_dir/prompts/phase1a_manifest.prompt.md"
grep -q -- "--prompt-file" "$render_dir/prompts/phase1a_manifest.prompt.md"

echo "PASS: Phase 1A scope-alignment tests passed"

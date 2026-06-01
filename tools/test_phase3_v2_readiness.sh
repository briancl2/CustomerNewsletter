#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

python3 -m py_compile tools/validate_phase3_v2_readiness.py

cat > "$tmpdir/source-context.md" <<'MD'
# Source Context

| Version | URL |
| --- | --- |
| 1.117 | [VS Code 1.117](https://code.visualstudio.com/updates/v1_117) |
| 1.118 | [VS Code 1.118](https://code.visualstudio.com/updates/v1_118) |
MD

cat > "$tmpdir/working-set-extra-version.md" <<'MD'
# Phase 3 Working Set

- VS Code 1.117
- VS Code 1.118
- VS Code 1.119
MD

cat > "$tmpdir/good.md" <<'MD'
# Copilot

## Latest Releases

- **Model availability and agent choice update (GA)** - GitHub gives enterprise teams platform choice across multiple provider options, including VS Code 1.117 and VS Code 1.118 readiness. [GitHub Blog](https://github.blog/changelog/example) [VS Code 1.117](https://code.visualstudio.com/updates/v1_117)
- **Enterprise rollout controls (PREVIEW)** - Admins can govern agent rollout with customer choice and policy controls. [DevBlogs](https://devblogs.microsoft.com/visualstudio/example) [VS Code 1.118](https://code.visualstudio.com/updates/v1_118)
MD

python3 tools/validate_phase3_v2_readiness.py \
  "$tmpdir/good.md" \
  --working-set "$tmpdir/working-set-extra-version.md" \
  --source-context "$tmpdir/source-context.md" \
  --require-vscode-version-coverage \
  --write-receipt "$tmpdir/good.json" >/dev/null

python3 - "$tmpdir/good.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert payload["pass"] is True
metrics = payload["metrics"]
assert metrics["model_bullets"] == 1
assert metrics["competitive_signal_groups"] >= 1
assert metrics["expected_vscode_versions"] == ["1.117", "1.118"]
assert metrics["missing_vscode_versions"] == []
PY

cat > "$tmpdir/hyphenated-choice.md" <<'MD'
# Copilot

## Latest Releases

- **Model governance update (GA)** - Enterprise teams get model controls, BYOK visibility, and platform-choice language for approved providers across VS Code 1.117 and VS Code 1.118. [GitHub Blog](https://github.blog/changelog/example) [VS Code 1.117](https://code.visualstudio.com/updates/v1_117)
- **Enterprise rollout controls (PREVIEW)** - Admins can govern agent rollout with customer-choice and provider-choice policy controls. [DevBlogs](https://devblogs.microsoft.com/visualstudio/example) [VS Code 1.118](https://code.visualstudio.com/updates/v1_118)
MD

python3 tools/validate_phase3_v2_readiness.py \
  "$tmpdir/hyphenated-choice.md" \
  --source-context "$tmpdir/source-context.md" \
  --require-vscode-version-coverage \
  --write-receipt "$tmpdir/hyphenated-choice.json" >/dev/null
python3 - "$tmpdir/hyphenated-choice.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert payload["pass"] is True
assert payload["metrics"]["competitive_signal_groups"] >= 1
PY

cat > "$tmpdir/burst169-like-multi-model.md" <<'MD'
# Copilot

## Latest Releases

- **Copilot agent orchestration expands across local, remote, and cloud surfaces (PREVIEW)** - Teams get platform-choice options for controlled agent execution. [VS Code 1.120](https://code.visualstudio.com/updates/v1_120)
- **Model availability and model controls continue to evolve across Copilot surfaces** - GitHub.com, VS Code, and Xcode all added model signals. [GitHub Blog](https://github.blog/changelog/example)
- **Cross-IDE BYOK and model governance improves regulated-industry fit (GA/PREVIEW)** - BYOK and reasoning controls support customer-choice governance. [VS Code 1.117](https://code.visualstudio.com/updates/v1_117)
- **Xcode usage-based billing and reasoning controls extend cost governance to Apple teams** - Xcode added usage-based billing and provider-choice signals. [GitHub](https://github.com/github/CopilotForXcode/blob/main/CHANGELOG.md)
MD

if python3 tools/validate_phase3_v2_readiness.py "$tmpdir/burst169-like-multi-model.md" >"$tmpdir/burst169-like.out" 2>&1; then
  echo "ASSERTION FAILED: Burst-169-like multi-model output should fail until model bullets are consolidated"
  exit 1
fi
grep -q "model availability bullets exceed floor" "$tmpdir/burst169-like.out"

cat > "$tmpdir/two-models.md" <<'MD'
# Copilot

## Latest Releases

- **GPT-5 availability (GA)** - Enterprise teams get a model update with platform choice. [GitHub Blog](https://github.blog/changelog/example)
- **GPT-4.2 model update (PREVIEW)** - Another model bullet should be compressed. [GitHub](https://github.com/example)
MD

if python3 tools/validate_phase3_v2_readiness.py "$tmpdir/two-models.md" >/dev/null 2>"$tmpdir/two-models.err"; then
  echo "ASSERTION FAILED: multiple model bullets should fail V2 readiness"
  exit 1
fi
python3 tools/validate_phase3_v2_readiness.py "$tmpdir/two-models.md" >"$tmpdir/two-models.out" 2>/dev/null || true
grep -q "model availability bullets exceed floor" "$tmpdir/two-models.out"

cat > "$tmpdir/no-competitive.md" <<'MD'
# Copilot

## Latest Releases

- **Enterprise rollout controls (GA)** - Admins can govern rollout with security controls. [GitHub Blog](https://github.blog/changelog/example) [GitHub](https://github.com/example)
MD

if python3 tools/validate_phase3_v2_readiness.py "$tmpdir/no-competitive.md" >/dev/null 2>&1; then
  echo "ASSERTION FAILED: missing competitive/platform-choice signal should fail V2 readiness"
  exit 1
fi

cat > "$tmpdir/missing-version.md" <<'MD'
# Copilot

## Latest Releases

- **Model availability and agent choice update (GA)** - Platform choice coverage mentions VS Code 1.117 only. [GitHub Blog](https://github.blog/changelog/example) [VS Code 1.117](https://code.visualstudio.com/updates/v1_117)
MD

if python3 tools/validate_phase3_v2_readiness.py \
  "$tmpdir/missing-version.md" \
  --source-context "$tmpdir/source-context.md" \
  --require-vscode-version-coverage >/dev/null 2>&1; then
  echo "ASSERTION FAILED: missing VS Code version signal should fail V2 readiness"
  exit 1
fi

cat > "$tmpdir/domain-sample.md" <<'MD'
# Copilot

- **Event and resource sources (GA)** - Official source coverage for recurring newsletter domains.
  - [Developer](https://developer.microsoft.com/en-us/events/example)
  - [DevBlogs](https://devblogs.microsoft.com/visualstudio/example)
  - [Luma](https://luma.com/example)
  - [Learn GitHub](https://learn.github.com/example)
MD

bash tools/score-v2-rubric.sh --mode production "$tmpdir/domain-sample.md" >"$tmpdir/score.out" 2>&1 || true
grep -q "Links from known valid domains (4/4, 100%)" "$tmpdir/score.out"

cat > "$tmpdir/spoofed-domain.md" <<'MD'
# Copilot

## Latest Releases

- **Model availability and agent choice update (GA)** - Platform choice coverage with a spoofed source. [Spoof](https://luma.com.evil.test/example)
MD

if python3 tools/validate_phase3_v2_readiness.py \
  "$tmpdir/spoofed-domain.md" \
  --min-valid-domain-ratio 100 >/dev/null 2>&1; then
  echo "ASSERTION FAILED: spoofed domain suffix should not pass valid-domain readiness"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import sys

sys.path.insert(0, str(Path("tools").resolve()))
from run_phase3_stdout_no_tools_artifact_reuse import source_contains_competitive_choice

assert source_contains_competitive_choice("agent choice and platform choice are present")
assert source_contains_competitive_choice("agent-provider-choice and platform-choice are present")
assert source_contains_competitive_choice("customer-choice and provider-choice are present")
assert not source_contains_competitive_choice("security controls and release notes only")
PY

rg -q -- "--require-v2-readiness" tools/run_newsletter_orchestrated.sh
rg -q -- "phase3_stdout_no_tools_v2_fallback" tools/run_newsletter_orchestrated.sh

echo "PASS: phase3 V2 readiness tests passed"

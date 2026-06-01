#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
START="2026-01-01"
END="2026-01-31"
PASS=0
FAIL=0
TMPDIR=""

cleanup() {
  [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ] && rm -rf "$TMPDIR"
}
trap cleanup EXIT
TMPDIR="$(mktemp -d)"

assert_ok() {
  local description="$1"
  shift
  if "$@"; then
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $description"
    FAIL=$((FAIL + 1))
  fi
}

assert_visual_studio_seed_score() {
  local file="$1"
  awk '
    /^### Visual Studio$/ { in_block = 1; next }
    /^### / { in_block = 0 }
    in_block && /^\- \*\*IDE parity sample \(GA\)\*\* \| score 9\/10$/ { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

assert_no_ide_parser_fallback() {
  local file="$1"
  awk '
    /^## IDE Parity Seed$/ { in_seed = 1; next }
    /^## / && in_seed { in_seed = 0 }
    in_seed && (/Could not parse IDE interim file/ || /\[MISSING_DATA\]/) { found = 1 }
    END { exit(found ? 1 : 0) }
  ' "$file"
}

assert_phase3_working_set_receipt_hash() {
  local replay_root="$1"
  python3 - "$replay_root" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
artifact = root / "workspace/newsletter_phase3_working_set_2026-04-16.md"
receipts = root / "workspace/newsletter_phase_receipts_2026-04-16.json"
payload = json.loads(receipts.read_text(encoding="utf-8"))
receipt = next(
    item
    for item in payload.get("receipts", [])
    if item.get("phase_id") == "phase3_working_set"
)
actual = hashlib.sha256(artifact.read_bytes()).hexdigest()
expected = receipt.get("artifact_sha256")
if actual != expected:
    raise SystemExit(f"phase3_working_set receipt hash drift: {actual} != {expected}")
PY
}

make_minimal_interims() {
  local workdir="$1"
  local ide_body="# Phase 1B Interim
## Extracted Items
### IDE parity sample (GA)
- **Date**: 2026-01-15
- **Description**: IDE parity remains relevant for this cycle.
- **Links**: [Example](https://example.com/ide)
- **Enterprise Impact**: Keeps the Phase 3 seed populated.
"
  printf "%s" "$ide_body" > "$workdir/workspace/newsletter_phase1b_interim_visualstudio_${START}_to_${END}.md"
  printf "%s" "$ide_body" > "$workdir/workspace/newsletter_phase1b_interim_jetbrains_${START}_to_${END}.md"
  printf "%s" "$ide_body" > "$workdir/workspace/newsletter_phase1b_interim_xcode_${START}_to_${END}.md"
}

run_build_case() {
  local fixture_name="$1"
  local expected_rc="$2"
  local benchmark_mode="${3:-}"
  local workdir="$TMPDIR/$fixture_name"
  mkdir -p "$workdir/workspace"
  cp "$ROOT/tests/fixtures/phase3_parse/${fixture_name}.md" \
    "$workdir/workspace/newsletter_phase1a_discoveries_${START}_to_${END}.md"
  make_minimal_interims "$workdir"

  local rc=0
  local stdout_file="$workdir/stdout.txt"
  local stderr_file="$workdir/stderr.txt"
  (
    cd "$workdir"
    if [ -n "$benchmark_mode" ]; then
      python3 "$ROOT/tools/build_phase3_working_set.py" "$START" "$END" --benchmark-mode "$benchmark_mode" \
        >"$stdout_file" 2>"$stderr_file"
    else
      python3 "$ROOT/tools/build_phase3_working_set.py" "$START" "$END" \
        >"$stdout_file" 2>"$stderr_file"
    fi
  ) || rc=$?

  if [ "$expected_rc" = "0" ]; then
    [ "$rc" -eq 0 ] || return 1
    [ -f "$workdir/workspace/newsletter_phase3_working_set_${END}.md" ] || return 1
    grep -q "^\*\*Parse Completeness\*\*:" "$workdir/workspace/newsletter_phase3_working_set_${END}.md" || return 1
    assert_no_ide_parser_fallback "$workdir/workspace/newsletter_phase3_working_set_${END}.md" || return 1
    assert_visual_studio_seed_score "$workdir/workspace/newsletter_phase3_working_set_${END}.md"
    return $?
  fi

  [ "$rc" -ne 0 ] || return 1
  grep -q "parse completeness below floor" "$workdir/stderr.txt"
}

echo "=== Phase 3 Contract Tests ==="
echo ""

assert_ok "inline_valid should pass" run_build_case inline_valid 0
assert_ok "heading_valid should pass" run_build_case heading_valid 0
assert_ok "mixed_valid should pass" run_build_case mixed_valid 0
assert_ok "empty_input should pass" run_build_case empty_input 0
assert_ok "malformed_star_bullets should fail closed" run_build_case malformed_star_bullets 1
assert_ok "declared_total_mismatch should fail closed" run_build_case declared_total_mismatch 1

platform_dir="$TMPDIR/platform_fold"
mkdir -p "$platform_dir/workspace"
cp "$ROOT/tests/fixtures/phase3_parse/platform_devex_valid.md" \
  "$platform_dir/workspace/newsletter_phase1a_discoveries_${START}_to_${END}.md"
make_minimal_interims "$platform_dir"
(
  cd "$platform_dir"
  python3 "$ROOT/tools/build_phase3_working_set.py" "$START" "$END" --benchmark-mode feb2026_consistency \
    >"$platform_dir/platform_stdout.txt" 2>"$platform_dir/platform_stderr.txt"
)
assert_ok "benchmark working set should omit dedicated GitHub Platform Updates bundle" \
  bash -lc "! grep -q '^### GitHub Platform Updates$' '$platform_dir/workspace/newsletter_phase3_working_set_${END}.md'"
assert_ok "benchmark working set should retain platform item under folded bundle" \
  grep -q "Platform deep links for operator workflows" "$platform_dir/workspace/newsletter_phase3_working_set_${END}.md"

april_replay="$TMPDIR/april_replay"
bash "$ROOT/tools/materialize_committed_product_fixture.sh" \
  2026-02-14 \
  2026-04-16 \
  "$april_replay"
april_working_set="$april_replay/workspace/newsletter_phase3_working_set_2026-04-16.md"
assert_ok "committed April working set should not carry IDE parser fallback control signals" \
  assert_no_ide_parser_fallback "$april_working_set"
assert_ok "committed April working set should retain Visual Studio IDE seed entries" \
  grep -q "Task delegation to Copilot coding agent" "$april_working_set"
assert_ok "committed April working set receipt hash should match materialized artifact" \
  assert_phase3_working_set_receipt_hash "$april_replay"

april_generated_replay="$TMPDIR/april_generated_replay"
bash "$ROOT/tools/materialize_committed_product_fixture.sh" \
  2026-02-14 \
  2026-04-16 \
  "$april_generated_replay"
(
  cd "$april_generated_replay"
  python3 "$ROOT/tools/build_phase3_working_set.py" 2026-02-14 2026-04-16 >/dev/null
)
april_generated_working_set="$april_generated_replay/workspace/newsletter_phase3_working_set_2026-04-16.md"
assert_ok "real April Phase 1B files should regenerate without IDE parser fallback" \
  assert_no_ide_parser_fallback "$april_generated_working_set"
assert_ok "real April Phase 1B files should regenerate Visual Studio IDE seed entries" \
  grep -q "Task delegation to Copilot coding agent" "$april_generated_working_set"
assert_ok "real April Phase 1B files should regenerate JetBrains IDE seed entries" \
  grep -q "Custom agents, sub-agents, and Plan Agent (GA)" "$april_generated_working_set"
assert_ok "real April Phase 1B files should regenerate Xcode IDE seed entries" \
  grep -q "Claude Opus 4.6 in Xcode (GA)" "$april_generated_working_set"

scaffold_standard_dir="$TMPDIR/scaffold_standard"
mkdir -p "$scaffold_standard_dir/workspace"
(
  cd "$scaffold_standard_dir"
  python3 "$ROOT/tools/init_phase3_curated_sections.py" "$START" "$END" \
    >"$scaffold_standard_dir/scaffold_standard_stdout.txt"
)
scaffold_standard="$scaffold_standard_dir/workspace/newsletter_phase3_curated_sections_${END}.md"
assert_ok "standard scaffold should include dedicated GitHub Platform Updates section" \
  grep -q "^## GitHub Platform Updates$" "$scaffold_standard"
assert_ok "standard scaffold should not contain HTML comments" \
  bash -lc "! grep -q '<!--' '$scaffold_standard'"

scaffold_benchmark_dir="$TMPDIR/scaffold_benchmark"
mkdir -p "$scaffold_benchmark_dir/workspace"
(
  cd "$scaffold_benchmark_dir"
  python3 "$ROOT/tools/init_phase3_curated_sections.py" "$START" "$END" --benchmark-mode feb2026_consistency \
    >"$scaffold_benchmark_dir/scaffold_benchmark_stdout.txt"
)
scaffold_benchmark="$scaffold_benchmark_dir/workspace/newsletter_phase3_curated_sections_${END}.md"
assert_ok "benchmark scaffold should omit dedicated GitHub Platform Updates section" \
  bash -lc "! grep -q '^## GitHub Platform Updates$' '$scaffold_benchmark'"
assert_ok "benchmark scaffold should not contain HTML comments" \
  bash -lc "! grep -q '<!--' '$scaffold_benchmark'"

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi

#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p \
  "$tmpdir/tools" \
  "$tmpdir/config/pricing" \
  "$tmpdir/workspace" \
  "$tmpdir/output" \
  "$tmpdir/run/proof/artifacts/workspace" \
  "$tmpdir/run/proof/artifacts/output" \
  "$tmpdir/run/proof/session" \
  "$tmpdir/run/proof/audit" \
  "$tmpdir/.github/agents" \
  "$tmpdir/.github/skills/newsletter-validation/scripts"

cp tools/collect_product_run_audit.py "$tmpdir/tools/"
cp tools/validate_pipeline_strict.sh "$tmpdir/tools/"
cp tools/validate_phase2_event_quality.py "$tmpdir/tools/"
cp tools/validate_phase3_curated.py "$tmpdir/tools/"
cp tools/product_run_common.py "$tmpdir/tools/"
cp tools/score-v2-rubric.sh "$tmpdir/tools/"
cp tools/materialize_committed_product_fixture.sh "$tmpdir/tools/"
cp tools/newsletter_experiment_common.py "$tmpdir/tools/"
cp tools/build_run_experiment_scorecard.py "$tmpdir/tools/"
cp tools/render_product_run_prompt.sh "$tmpdir/tools/"
cp tools/newsletter_cost_profiler.py "$tmpdir/tools/"
cp tools/newsletter_hotspot_auditor.py "$tmpdir/tools/"
cp tools/build_experiment_fixture_manifest.py "$tmpdir/tools/"
cp tools/build_scorecard_telemetry_receipt.py "$tmpdir/tools/"
cp tools/build_phase_token_telemetry_receipt.py "$tmpdir/tools/"
cp tools/prove_newsletter_stop_gates.py "$tmpdir/tools/"
cp tools/newsletter_phase_experimenter.py "$tmpdir/tools/"
cp tools/build_phase3_working_set.py "$tmpdir/tools/"
cp tools/init_phase3_curated_sections.py "$tmpdir/tools/"
cp tools/run_copilot_phase.py "$tmpdir/tools/"
cp tools/record_phase_receipt.sh "$tmpdir/tools/"
cp tools/scan_phase3_log_signatures.py "$tmpdir/tools/"
cp .github/skills/newsletter-validation/scripts/validate_newsletter.sh \
  "$tmpdir/.github/skills/newsletter-validation/scripts/"
cp .github/agents/customer_newsletter.agent.md "$tmpdir/.github/agents/"
cat > "$tmpdir/config/pricing/newsletter-model-pricing-2026-04-30.json" <<'EOF'
{
  "generated_at": "2026-04-30T16:35:00Z",
  "models": [
    {
      "provider": "openai",
      "model": "gpt-5.5",
      "aliases": [
        "copilot/gpt-5.5"
      ],
      "input_price": 5.0,
      "output_price": 30.0,
      "cache_price": {
        "read": 0.5,
        "write": 0.5
      },
      "reasoning_price": 30.0
    }
  ]
}
EOF

bash tools/materialize_committed_product_fixture.sh \
  2026-02-14 \
  2026-04-16 \
  "$tmpdir/run/proof/artifacts"

printf 'shifted live workspace state after retained fixture materialization\n' \
  > "$tmpdir/workspace/newsletter_phase1a_discoveries_2026-02-14_to_2026-04-16.md"
printf 'wrong live-cycle workspace artifact\n' \
  > "$tmpdir/workspace/newsletter_phase1a_discoveries_2026-04-17_to_2026-05-31.md"
printf '# shifted live output after retained fixture materialization\n' \
  > "$tmpdir/output/2026-04_april_newsletter.md"

python3 - "$tmpdir/run/proof/artifacts/workspace/newsletter_phase_receipts_2026-04-16.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
by_phase = {row["phase_id"]: row for row in payload["receipts"]}
by_phase["phase4_scope_results"]["receipt_order"], by_phase["phase4_editorial_review"]["receipt_order"] = (
    by_phase["phase4_editorial_review"]["receipt_order"],
    by_phase["phase4_scope_results"]["receipt_order"],
)
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

cat > "$tmpdir/run/proof/session/events.jsonl" <<'EOF'
{"type":"session.start","timestamp":"2026-04-17T02:47:56Z","data":{"sessionId":"fixture"}}
{"type":"tool.execution_start","timestamp":"2026-04-17T02:48:00Z","data":{"toolCallId":"call-view","toolName":"view"}}
{"type":"tool.execution_complete","timestamp":"2026-04-17T02:48:02Z","data":{"toolCallId":"call-view","success":true}}
{"type":"tool.execution_start","timestamp":"2026-04-17T02:48:05Z","data":{"toolCallId":"call-bash","toolName":"bash"}}
{"type":"tool.execution_complete","timestamp":"2026-04-17T02:48:09Z","data":{"toolCallId":"call-bash","success":true}}
{"type":"session.shutdown","timestamp":"2026-04-17T02:52:47Z","data":{"reason":"completed","currentModel":"gpt-5.5","totalPremiumRequests":1,"totalApiDurationMs":247992,"modelMetrics":{"gpt-5.5":{"requests":{"count":21},"usage":{"inputTokens":1489706,"outputTokens":14879,"cacheReadTokens":1386624,"cacheWriteTokens":0,"reasoningTokens":8242}}}}}
EOF

cat > "$tmpdir/run/proof/run-metadata.json" <<'EOF'
{
  "schema_version": 1,
  "start": "2026-02-14",
  "end": "2026-04-16",
  "mode": "production",
  "model": "gpt-5.5",
  "start_epoch": 1776394076,
  "started_at_utc": "2026-04-17T02:47:56Z",
  "command": "copilot --model gpt-5.5 --allow-all --deny-tool agent --no-ask-user --stream off -p @runs/product_runs/fixture/prompt.txt",
  "command_surface": "copilot_cli_single_shot",
  "experiment_id": "fixture-batch0",
  "run_class": "anchor_control",
  "fixture_pack": "production-anchor-2026-04-16",
  "prompt_sha256": "fixture",
  "prompt_source": "prompt_snapshot",
  "prompt_path": "runs/product_runs/fixture/prompt.txt",
  "prompt_renderer_command": "bash tools/render_product_run_prompt.sh 2026-02-14 2026-04-16 production",
  "artifact_root": "runs/product_runs/fixture/artifacts"
}
EOF

cat > "$tmpdir/run/proof/run-result.json" <<'EOF'
{
  "copilot_exit_code": 0,
  "audit_exit_code": 0,
  "ended_at_utc": "2026-04-17T02:52:47Z"
}
EOF

cat > "$tmpdir/run/proof/prompt.txt" <<'EOF'
Fixture product prompt
EOF

git -C "$tmpdir" init -q

(
  cd "$tmpdir"
  python3 tools/collect_product_run_audit.py \
    2026-02-14 \
    2026-04-16 \
    --mode production \
    --run-dir "$tmpdir/run/proof/audit" \
    --session-log "$tmpdir/run/proof/session/events.jsonl"
)

(
  cd "$tmpdir"
  python3 tools/build_run_experiment_scorecard.py --run-dir "$tmpdir/run/proof" >/dev/null
)

python3 - "$tmpdir/run/proof/run-scorecard.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["experiment"]["experiment_id"] != "fixture-batch0":
    raise SystemExit("experiment_id missing from scorecard")
if payload["experiment"]["run_class"] != "anchor_control":
    raise SystemExit("run_class missing from scorecard")
if payload["experiment"]["fixture_pack"] != "production-anchor-2026-04-16":
    raise SystemExit("fixture_pack missing from scorecard")
receipt_span = payload["timing"]["receipt_span_seconds"]
if not isinstance(receipt_span, int) or receipt_span <= 0:
    raise SystemExit("expected positive retained receipt span in scorecard")
if receipt_span != payload["phase_receipts"].get("receipt_span_seconds"):
    raise SystemExit("expected timing receipt span to match phase receipt span")
if not payload["phase_receipts"].get("receipt_file_sha256"):
    raise SystemExit("expected scorecard to bind the phase receipt file hash")
raw_order = payload["phase_receipts"].get("ordered_phase_ids", [])
comparable_order = payload["phase_receipts"].get("comparable_ordered_phase_ids", [])
if raw_order[-2:] != ["phase4_editorial_review", "phase4_scope_results"]:
    raise SystemExit(f"expected fixture to preserve raw swapped post-assembly order: {raw_order[-2:]}")
if comparable_order[-2:] != ["phase4_scope_results", "phase4_editorial_review"]:
    raise SystemExit(f"expected comparable order to normalize post-assembly receipts: {comparable_order[-2:]}")
normalization = payload["phase_receipts"].get("phase_order_normalization", {})
if normalization.get("applied") is not True:
    raise SystemExit("expected phase order normalization to be marked applied")
if payload["cost_estimate"]["total_usd"] is None:
    raise SystemExit("expected priced scorecard")
if payload["quality"].get("warning_taxonomy_present") is not True:
    raise SystemExit("expected warning taxonomy presence in scorecard")
if (payload["quality"].get("strict_warning_count") or 0) > 0 and not payload["quality"].get("warning_taxonomy_classes"):
    raise SystemExit("expected warning classes for non-zero strict warnings")
if "warning_taxonomy" not in payload["quality"]:
    raise SystemExit("expected warning taxonomy details in scorecard")
completeness = payload["artifact_completeness"]
if "editorial_review" in completeness.get("required_missing", []):
    raise SystemExit("editorial review must not be required-missing without production-artifacts mode")
direct_fields = payload["token_usage"].get("direct_provider_token_fields_present", [])
required_fields = ["inputTokens", "outputTokens", "cacheReadTokens", "cacheWriteTokens", "reasoningTokens"]
if direct_fields != required_fields:
    raise SystemExit(f"expected direct provider token field presence, got {direct_fields}")
if payload["token_usage"].get("missing_direct_provider_token_fields") != []:
    raise SystemExit("expected no missing direct provider token fields")
if payload["token_usage"].get("requested_models") != ["gpt-5.5"]:
    raise SystemExit("expected raw requested model list in scorecard")
model_fields = payload["token_usage"].get("model_direct_provider_token_fields", {})
model_row = model_fields.get("gpt-5.5")
if not model_row:
    raise SystemExit("expected per-model direct provider token field metadata")
if model_row.get("direct_provider_token_fields_present") != required_fields:
    raise SystemExit("expected per-model direct provider token fields to be complete")
if model_row.get("missing_direct_provider_token_fields") != []:
    raise SystemExit("expected no per-model missing direct provider token fields")
if "prompt_equality" not in payload["experiment"]:
    raise SystemExit("expected prompt equality metadata in scorecard")
equality = payload["experiment"]["prompt_equality"]
if equality.get("available") is not True:
    raise SystemExit(f"expected prompt equality to be available in fixture scorecard: {equality}")
if not equality.get("current_renderer_sha256"):
    raise SystemExit("expected current renderer hash in prompt equality metadata")
if equality.get("matches_current_renderer") is not False:
    raise SystemExit("expected fixture prompt to differ from current renderer")
PY

PYTHONPATH="$tmpdir/tools" python3 - <<'PY'
from newsletter_experiment_common import optional_artifact_names_for_audit

default_audit = {"validators": {"strict": {"cmd": ["bash", "tools/validate_pipeline_strict.sh"]}}}
strict_audit = {
    "validators": {
        "strict": {
            "cmd": ["bash", "tools/validate_pipeline_strict.sh", "--production-artifacts"]
        }
    }
}
if "editorial_review" not in optional_artifact_names_for_audit(default_audit):
    raise SystemExit("expected editorial review optional without --production-artifacts")
if "editorial_review" in optional_artifact_names_for_audit(strict_audit):
    raise SystemExit("expected editorial review required with --production-artifacts")
PY

python3 - <<'PY'
import sys
from pathlib import Path

sys.path.insert(0, str(Path("tools").resolve()))
from newsletter_experiment_common import prompt_equality_check

result = prompt_equality_check(
    {
        "prompt_sha256": "current-renderer-only",
        "prompt_source": "reconstructed_current_renderer",
    },
    {"start": "2026-02-14", "end": "2026-04-16", "mode": "production"},
)
if result["available"] is not False:
    raise SystemExit("reconstructed current renderer must not prove prompt equality")
if result["retained_prompt_sha256"] is not None:
    raise SystemExit("reconstructed current renderer must not be reported as retained prompt hash")
if not result["current_renderer_sha256"]:
    raise SystemExit("expected current renderer hash to remain visible")
PY

cat > "$tmpdir/zero-model-events.jsonl" <<'EOF'
{"type":"session.shutdown","timestamp":"2026-04-17T02:52:47Z","data":{"reason":"completed","currentModel":"gpt-5.5","modelMetrics":{"gpt-5.5":{"requests":{"count":1},"usage":{"inputTokens":10,"outputTokens":2,"cacheReadTokens":1,"cacheWriteTokens":0,"reasoningTokens":0}},"unused-model":{"requests":{"count":0},"usage":{}}}}}
EOF

PYTHONPATH="$tmpdir/tools" python3 - "$tmpdir/zero-model-events.jsonl" <<'PY'
import sys
from pathlib import Path

from newsletter_experiment_common import parse_session_metrics

metrics = parse_session_metrics(Path(sys.argv[1]))
if metrics["requested_models"] != ["gpt-5.5", "unused-model"]:
    raise SystemExit(f"expected zero-call model to stay requested: {metrics['requested_models']}")
zero_row = metrics["model_direct_provider_token_fields"].get("unused-model")
if not zero_row:
    raise SystemExit("expected zero-call model direct-field row")
if zero_row.get("request_count") != 0:
    raise SystemExit("expected zero-call model request_count to stay 0")
if zero_row.get("missing_direct_provider_token_fields") != [
    "inputTokens",
    "outputTokens",
    "cacheReadTokens",
    "cacheWriteTokens",
    "reasoningTokens",
]:
    raise SystemExit("expected zero-call model to expose missing direct fields")
PY

PYTHONPATH="$tmpdir/tools" python3 - <<'PY'
from newsletter_experiment_common import stable_scorecard_sha256

run_id = "20260501T024928Z_benchmark_proof"
payload = {
    "generated_at_utc": "2026-05-03T00:00:00Z",
    "run_id": run_id,
    "run_dir": f"/private/tmp/one/{run_id}",
    "supporting_receipts": {
        "session_log": f"/private/tmp/one/{run_id}/session/events.jsonl",
        "audit_json": f"/private/tmp/one/{run_id}/audit/RUN_AUDIT.json",
    },
}
copied = {
    **payload,
    "generated_at_utc": "2026-05-03T01:00:00Z",
    "run_dir": f"/var/folders/two/{run_id}",
    "supporting_receipts": {
        "session_log": f"/var/folders/two/{run_id}/session/events.jsonl",
        "audit_json": f"/var/folders/two/{run_id}/audit/RUN_AUDIT.json",
    },
}
if stable_scorecard_sha256(payload) != stable_scorecard_sha256(copied):
    raise SystemExit("expected stable scorecard hash to normalize copied retained-run roots")
PY

cp "$tmpdir/run/proof/run-scorecard.json" "$tmpdir/positive-scorecard.json"
hash_a="$(printf 'a%.0s' {1..64})"
jq '.token_usage.direct_provider_token_fields_present=["inputTokens"] | .token_usage.missing_direct_provider_token_fields=["outputTokens","cacheReadTokens","cacheWriteTokens","reasoningTokens"]' \
  "$tmpdir/positive-scorecard.json" > "$tmpdir/missing-field-negative-scorecard.json"
jq '.experiment.prompt_equality.current_renderer_sha256="0000000000000000000000000000000000000000000000000000000000000000" | .experiment.prompt_equality.matches_current_renderer=false | .experiment.prompt_equality.reason="Deliberately mutated current renderer hash negative control."' \
  "$tmpdir/positive-scorecard.json" > "$tmpdir/mutated-prompt-negative-scorecard.json"
jq '.experiment.prompt_equality.matches_current_renderer=true' \
  "$tmpdir/positive-scorecard.json" > "$tmpdir/inconsistent-prompt-negative-scorecard.json"
jq '.experiment.prompt_equality.available=true | .experiment.prompt_equality.retained_prompt_sha256="aaa" | .experiment.prompt_equality.current_renderer_sha256="aaa" | .experiment.prompt_equality.matches_current_renderer=true' \
  "$tmpdir/positive-scorecard.json" > "$tmpdir/malformed-prompt-hash-negative-scorecard.json"
jq --arg hash "$hash_a" '.experiment.prompt_equality.retained_prompt_sha256=$hash | .experiment.prompt_equality.current_renderer_sha256=$hash | .experiment.prompt_equality.matches_current_renderer=true' \
  "$tmpdir/positive-scorecard.json" > "$tmpdir/tampered-positive-prompt-scorecard.json"
jq '.token_usage.direct_provider_token_fields_present=["inputTokens","outputTokens","cacheReadTokens","cacheWriteTokens","reasoningTokens"] | .token_usage.missing_direct_provider_token_fields=[] | .token_usage.model_direct_provider_token_fields["claude-opus-4.6"]={"request_count":3,"direct_provider_token_fields_present":["inputTokens","outputTokens","cacheReadTokens","cacheWriteTokens"],"missing_direct_provider_token_fields":["reasoningTokens"]}' \
  "$tmpdir/positive-scorecard.json" > "$tmpdir/mixed-model-missing-field-negative-scorecard.json"
jq '.token_usage.requested_models += ["claude-sonnet-4.6"] | .token_usage.model_breakdown += [{"model":"claude-sonnet-4.6","request_count":2,"input_tokens":10,"output_tokens":5,"cache_read_tokens":0,"cache_write_tokens":0,"reasoning_tokens":1,"direct_provider_token_fields_present":["inputTokens","outputTokens","cacheReadTokens","cacheWriteTokens","reasoningTokens"],"missing_direct_provider_token_fields":[]}] | .token_usage.model_direct_provider_token_fields={"gpt-5.5": .token_usage.model_direct_provider_token_fields["gpt-5.5"]}' \
  "$tmpdir/positive-scorecard.json" > "$tmpdir/omitted-model-row-negative-scorecard.json"
jq 'del(.token_usage.model_direct_provider_token_fields)' \
  "$tmpdir/positive-scorecard.json" > "$tmpdir/missing-model-surface-negative-scorecard.json"
jq 'del(.token_usage.requested_models)' \
  "$tmpdir/positive-scorecard.json" > "$tmpdir/missing-requested-models-negative-scorecard.json"
jq '.token_usage.model_direct_provider_token_fields["gpt-5.5"]=["bad"]' \
  "$tmpdir/positive-scorecard.json" > "$tmpdir/malformed-model-row-negative-scorecard.json"
jq '.token_usage.model_direct_provider_token_fields["gpt-5.5"]={"request_count":0,"direct_provider_token_fields_present":[],"missing_direct_provider_token_fields":[]}' \
  "$tmpdir/positive-scorecard.json" > "$tmpdir/zero-count-model-row-negative-scorecard.json"
jq '.token_usage.direct_provider_token_fields_present=[{}]' \
  "$tmpdir/positive-scorecard.json" > "$tmpdir/malformed-token-list-negative-scorecard.json"
printf '{not-json' > "$tmpdir/malformed-negative-scorecard.json"
printf '{"token_usage":[],"experiment":"x"}\n' > "$tmpdir/nested-malformed-negative-scorecard.json"
(
  cd "$tmpdir"
  python3 tools/build_scorecard_telemetry_receipt.py \
    --scorecard "$tmpdir/positive-scorecard.json" \
    --negative-scorecard "$tmpdir/missing-field-negative-scorecard.json" \
    --negative-scorecard "$tmpdir/mutated-prompt-negative-scorecard.json" \
    --negative-scorecard "$tmpdir/inconsistent-prompt-negative-scorecard.json" \
    --negative-scorecard "$tmpdir/malformed-prompt-hash-negative-scorecard.json" \
    --negative-scorecard "$tmpdir/mixed-model-missing-field-negative-scorecard.json" \
    --negative-scorecard "$tmpdir/omitted-model-row-negative-scorecard.json" \
    --negative-scorecard "$tmpdir/missing-model-surface-negative-scorecard.json" \
    --negative-scorecard "$tmpdir/missing-requested-models-negative-scorecard.json" \
    --negative-scorecard "$tmpdir/malformed-model-row-negative-scorecard.json" \
    --negative-scorecard "$tmpdir/zero-count-model-row-negative-scorecard.json" \
    --negative-scorecard "$tmpdir/malformed-token-list-negative-scorecard.json" \
    --negative-scorecard "$tmpdir/malformed-negative-scorecard.json" \
    --negative-scorecard "$tmpdir/nested-malformed-negative-scorecard.json" \
    --output "$tmpdir/telemetry-receipt.json" >/dev/null
)
python3 - "$tmpdir/telemetry-receipt.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("pass") is not True:
    raise SystemExit("expected telemetry receipt with rejected negative controls to pass")
if payload.get("negative_control_count") != 13:
    raise SystemExit("expected thirteen telemetry negative controls")
if not all(row.get("rejected_as_expected") for row in payload.get("negative_controls", [])):
    raise SystemExit("expected negative controls to be rejected")
mixed = [
    row for row in payload.get("negative_controls", [])
    if row.get("scorecard_path", "").endswith("mixed-model-missing-field-negative-scorecard.json")
]
if not mixed or not mixed[0]["token_field_check"].get("model_field_errors"):
    raise SystemExit("expected mixed-model negative to fail per-model token field checks")
omitted = [
    row for row in payload.get("negative_controls", [])
    if row.get("scorecard_path", "").endswith("omitted-model-row-negative-scorecard.json")
]
if not omitted or "claude-sonnet-4.6 missing per-model direct provider token field row" not in omitted[0]["token_field_check"].get("model_field_errors", []):
    raise SystemExit("expected omitted-model negative to fail requested-model reconciliation")
inconsistent = [
    row for row in payload.get("negative_controls", [])
    if row.get("scorecard_path", "").endswith("inconsistent-prompt-negative-scorecard.json")
]
if not inconsistent or "prompt equality match boolean disagrees with retained/current hashes" not in inconsistent[0].get("shape_errors", []):
    raise SystemExit("expected inconsistent prompt equality boolean to fail")
malformed_hash = [
    row for row in payload.get("negative_controls", [])
    if row.get("scorecard_path", "").endswith("malformed-prompt-hash-negative-scorecard.json")
]
if not malformed_hash or "retained prompt hash is not a valid SHA-256" not in malformed_hash[0].get("shape_errors", []):
    raise SystemExit("expected malformed prompt hash to fail")
missing_surface = [
    row for row in payload.get("negative_controls", [])
    if row.get("scorecard_path", "").endswith("missing-model-surface-negative-scorecard.json")
]
if not missing_surface or "model direct provider token fields are missing" not in missing_surface[0]["token_field_check"].get("model_field_errors", []):
    raise SystemExit("expected missing model telemetry surface to fail")
missing_requested = [
    row for row in payload.get("negative_controls", [])
    if row.get("scorecard_path", "").endswith("missing-requested-models-negative-scorecard.json")
]
if not missing_requested or "requested_models must be a non-empty list" not in missing_requested[0].get("shape_errors", []):
    raise SystemExit("expected missing requested_models to fail")
malformed_model = [
    row for row in payload.get("negative_controls", [])
    if row.get("scorecard_path", "").endswith("malformed-model-row-negative-scorecard.json")
]
if not malformed_model or "gpt-5.5 missing per-model direct provider token field row" not in malformed_model[0]["token_field_check"].get("model_field_errors", []):
    raise SystemExit("expected malformed model row to fail without crashing")
zero_count = [
    row for row in payload.get("negative_controls", [])
    if row.get("scorecard_path", "").endswith("zero-count-model-row-negative-scorecard.json")
]
if not zero_count or "gpt-5.5 requested model row has non-positive request_count" not in zero_count[0]["token_field_check"].get("model_field_errors", []):
    raise SystemExit("expected zero-count requested model row to fail")
malformed_list = [
    row for row in payload.get("negative_controls", [])
    if row.get("scorecard_path", "").endswith("malformed-token-list-negative-scorecard.json")
]
if not malformed_list or "direct_provider_token_fields_present contains non-string value" not in malformed_list[0].get("shape_errors", []):
    raise SystemExit("expected malformed token field list to fail without crashing")
nested = [
    row for row in payload.get("negative_controls", [])
    if row.get("scorecard_path", "").endswith("nested-malformed-negative-scorecard.json")
]
if not nested or "token_usage object is missing or malformed" not in nested[0].get("shape_errors", []):
    raise SystemExit("expected nested malformed scorecard to fail without crashing")
PY

jq '.run_dir="/missing/original/proof" | .experiment.prompt_path="/missing/original/proof/prompt.txt"' \
  "$tmpdir/positive-scorecard.json" > "$tmpdir/run/proof/relocated-scorecard.json"
(
  cd "$tmpdir"
  python3 tools/build_scorecard_telemetry_receipt.py \
    --scorecard "$tmpdir/run/proof/relocated-scorecard.json" \
    --output "$tmpdir/relocated-prompt-telemetry-receipt.json" >/dev/null
)

python3 - "$tmpdir/relocated-prompt-telemetry-receipt.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("pass") is not True:
    raise SystemExit("expected relocated scorecard prompt path to resolve from scorecard run directory")
scorecard = payload["scorecards"][0]
if "retained prompt path could not be resolved" in scorecard.get("shape_errors", []):
    raise SystemExit("expected relocated prompt path to be resolved from scorecard-adjacent run copy")
PY

if (
  cd "$tmpdir"
  python3 tools/build_scorecard_telemetry_receipt.py \
    --scorecard "$tmpdir/positive-scorecard.json" \
    --negative-scorecard "$tmpdir/no-such-negative-scorecard.json" \
    --output "$tmpdir/missing-negative-telemetry-receipt.json" >/dev/null
); then
  echo "ASSERTION FAILED: expected missing negative-control scorecard path to fail"
  exit 1
fi

python3 - "$tmpdir/missing-negative-telemetry-receipt.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
negative = payload["negative_controls"][0]
if negative.get("rejected_as_expected") is not False:
    raise SystemExit("missing negative-control file must not count as rejected-as-expected")
if payload.get("negative_controls_pass") is not False:
    raise SystemExit("missing negative-control file must fail the receipt")
PY

telemetry_stdout="$(
  cd "$tmpdir"
  python3 tools/build_scorecard_telemetry_receipt.py \
    --scorecard "$tmpdir/positive-scorecard.json" \
    --output /dev/stdout
)"
TELEMETRY_STDOUT="$telemetry_stdout" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["TELEMETRY_STDOUT"])
if payload.get("pass") is not True:
    raise SystemExit("expected telemetry /dev/stdout output to be clean passing JSON")
PY

(
  cd "$tmpdir"
  python3 tools/newsletter_cost_profiler.py --run-dir "$tmpdir/run/proof" --output "$tmpdir/profiler.json" >/dev/null
)

python3 - "$tmpdir/profiler.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["run_count"] != 1:
    raise SystemExit("expected one profiled run")
if not payload["phase_estimates"]:
    raise SystemExit("expected non-empty phase estimates")
if {row.get("phase_sequence_source") for row in payload["phase_estimates"]} != {"comparable_phase_spans_seconds"}:
    raise SystemExit("expected profiler phase estimates to use comparable phase spans")
PY

(
  cd "$tmpdir"
  python3 tools/newsletter_hotspot_auditor.py --run-dir "$tmpdir/run/proof" --output "$tmpdir/hotspots.json" >/dev/null
)

python3 - "$tmpdir/hotspots.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if not payload["hottest_transitions"]:
    raise SystemExit("expected hotspot transitions when run dirs are provided directly")
if not payload["highest_output_transitions"]:
    raise SystemExit("expected output-token hotspot transitions when run dirs are provided directly")
PY

(
  cd "$tmpdir"
  python3 tools/build_experiment_fixture_manifest.py \
    --run-dir "$tmpdir/run/proof" \
    --manifest-id "fixture-manifest" \
    --output "$tmpdir/fixture-manifest.json" >/dev/null
)

python3 - "$tmpdir/fixture-manifest.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
surfaces = payload.get("surfaces", {})
if "phase4_fast_surface" not in surfaces:
    raise SystemExit("expected phase4_fast_surface in manifest")
if not surfaces["phase4_fast_surface"]:
    raise SystemExit("expected populated phase4_fast_surface")
PY

mkdir -p "$tmpdir/target/workspace"
printf 'preexisting target content\n' > \
  "$tmpdir/target/workspace/newsletter_phase3_curated_sections_2026-04-16.md"

(
  cd "$tmpdir"
  python3 tools/newsletter_phase_experimenter.py \
    materialize \
    --manifest "$tmpdir/fixture-manifest.json" \
    --surface-id phase4_fast_surface \
    --target-repo "$tmpdir/target" >/dev/null
)

if [ ! -f "$tmpdir/target/workspace/newsletter_phase3_curated_sections_2026-04-16.md" ]; then
  echo "ASSERTION FAILED: expected materialized curated surface"
  exit 1
fi

if [ ! -f "$tmpdir/target/workspace/archived/phase-experiments/proof_phase4_fast_surface/workspace/newsletter_phase3_curated_sections_2026-04-16.md" ]; then
  echo "ASSERTION FAILED: expected backup of overwritten curated surface"
  exit 1
fi

phase3_target="$tmpdir/phase3-target"
mkdir -p "$phase3_target/tools" "$tmpdir/fake-bin"
git -C "$phase3_target" init -q
cp tools/build_phase3_working_set.py "$phase3_target/tools/"
cp tools/init_phase3_curated_sections.py "$phase3_target/tools/"
cp tools/validate_phase3_curated.py "$phase3_target/tools/"
cp tools/run_copilot_phase.py "$phase3_target/tools/"
cp tools/newsletter_experiment_common.py "$phase3_target/tools/"
cp tools/record_phase_receipt.sh "$phase3_target/tools/"
cp tools/scan_phase3_log_signatures.py "$phase3_target/tools/"

bad_phase3_target="$tmpdir/phase3-bad-target"
mkdir -p "$bad_phase3_target"
git -C "$bad_phase3_target" init -q
if python3 tools/newsletter_phase_experimenter.py \
  phase3-curation \
  --manifest "$tmpdir/fixture-manifest.json" \
  --surface-id phase2_entry_surface \
  --target-repo "$bad_phase3_target" \
  --model gpt-5.5 \
  --phase-timeout-seconds 901 >/tmp/test-experiment-surfaces-bad-timeout.out 2>&1; then
  echo "ASSERTION FAILED: expected invalid Phase 3 timeout to fail"
  exit 1
fi

if [ -e "$bad_phase3_target/workspace/newsletter_phase_receipts_2026-04-16.json" ]; then
  echo "ASSERTION FAILED: invalid Phase 3 precondition should fail before materializing receipts"
  exit 1
fi

cat > "$tmpdir/fake-bin/copilot" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
target="$(ls workspace/newsletter_phase3_curated_sections_*.md | head -1)"
if [ "${COPILOT_FAKE_SIGNATURE:-}" = "bad-baseline" ]; then
  printf '%s\n' \
    "python3 tools/validate_phase3_curated.py 2026-02-14 2026-04-16 workspace/newsletter_phase3_curated_sections_2026-04-16.md --working-set workspace/newsletter_phase3_working_set_2026-04-16.md" \
    "The curated artifact is still the scaffold." \
    "FAIL: scaffold placeholder bullets remain below 24-bullet floor."
fi
cat > "$target" <<'MD'
# Phase 3: Curated Newsletter Sections
**Date Range**: fixture
**Curated**: fixture
**Sources**: Phase 3 working set
**Target Audience**: Engineering Managers, DevOps Leads, IT Leadership
**Benchmark Mode**: off
**Section Policy**: Keep GitHub Platform Updates as a dedicated section when the working set supports it.

# Copilot

## Latest Releases
- Release item 1 with enterprise context.
- Release item 2 with enterprise context.
- Release item 3 with enterprise context.
- Release item 4 with enterprise context.
- Release item 5 with enterprise context.

## IDE Parity
- Improved IDE Feature Parity
  - VS Code capability update grounded in the working set.
  - Visual Studio capability update grounded in the working set.
  - JetBrains capability update grounded in the working set.
  - Xcode capability update grounded in the working set.
  - Rollout timing differs by IDE, so validate availability per estate.

## Enterprise and Security Updates
- Enterprise item 1 with governance context.
- Enterprise item 2 with governance context.
- Enterprise item 3 with governance context.
- Enterprise item 4 with governance context.
- Enterprise item 5 with governance context.
- Enterprise item 6 with governance context.

## GitHub Platform Updates
- Platform item 1 with operator context.
- Platform item 2 with operator context.
- Platform item 3 with operator context.
- Platform item 4 with operator context.

## Resources and Best Practices
- Resource item 1 with adoption guidance.
- Resource item 2 with adoption guidance.
- Resource item 3 with adoption guidance.
- Resource item 4 with adoption guidance.
- Resource item 5 with adoption guidance.
MD
EOF
chmod +x "$tmpdir/fake-bin/copilot"

(
  cd "$tmpdir"
  PATH="$tmpdir/fake-bin:$PATH" \
  python3 tools/newsletter_phase_experimenter.py \
    phase3-curation \
    --manifest "$tmpdir/fixture-manifest.json" \
    --surface-id phase2_entry_surface \
    --target-repo "$phase3_target" \
    --model gpt-5.5 \
    --run-dir-override "$tmpdir/external-phase3-fixture" >/dev/null
)

if [ ! -s "$tmpdir/external-phase3-fixture/summary.md" ]; then
  echo "ASSERTION FAILED: expected Phase 3 experiment summary"
  exit 1
fi

if ! grep -q "Phase Return Code: 0" "$tmpdir/external-phase3-fixture/summary.md"; then
  echo "ASSERTION FAILED: expected successful Phase 3 phase return code"
  exit 1
fi

if ! grep -q "Curated Receipt Return Code: 0" "$tmpdir/external-phase3-fixture/summary.md"; then
  echo "ASSERTION FAILED: expected successful Phase 3 curated receipt return code"
  exit 1
fi

if ! grep -q "Overall Return Code: 0" "$tmpdir/external-phase3-fixture/summary.md"; then
  echo "ASSERTION FAILED: expected successful Phase 3 overall return code"
  exit 1
fi

phase3_signature_target="$tmpdir/phase3-signature-target"
mkdir -p "$phase3_signature_target/tools"
git -C "$phase3_signature_target" init -q
cp tools/build_phase3_working_set.py "$phase3_signature_target/tools/"
cp tools/init_phase3_curated_sections.py "$phase3_signature_target/tools/"
cp tools/validate_phase3_curated.py "$phase3_signature_target/tools/"
cp tools/run_copilot_phase.py "$phase3_signature_target/tools/"
cp tools/newsletter_experiment_common.py "$phase3_signature_target/tools/"
cp tools/record_phase_receipt.sh "$phase3_signature_target/tools/"
cp tools/scan_phase3_log_signatures.py "$phase3_signature_target/tools/"

if (
  cd "$tmpdir"
  PATH="$tmpdir/fake-bin:$PATH" \
  COPILOT_FAKE_SIGNATURE=bad-baseline \
  python3 tools/newsletter_phase_experimenter.py \
    phase3-curation \
    --manifest "$tmpdir/fixture-manifest.json" \
    --surface-id phase2_entry_surface \
    --target-repo "$phase3_signature_target" \
    --model gpt-5.5 \
    --run-dir-override "$tmpdir/external-phase3-signature-stop" >/tmp/test-experiment-surfaces-signature-stop.out 2>&1
); then
  echo "ASSERTION FAILED: expected Phase 3 signature scan to stop intermediate scaffold validator failure"
  exit 1
fi

if ! grep -q "Signature Scan Return Code: 65" "$tmpdir/external-phase3-signature-stop/summary.md"; then
  echo "ASSERTION FAILED: expected signature scan return code in stopped Phase 3 summary"
  exit 1
fi

if grep -q '"phase_id": "phase3_curated"' "$phase3_signature_target/workspace/newsletter_phase_receipts_2026-04-16.json"; then
  echo "ASSERTION FAILED: signature-stopped Phase 3 run should not record phase3_curated receipt"
  exit 1
fi

if ! grep -q "Do not run the validator against the scaffold" "$tmpdir/external-phase3-fixture/prompts/phase3_curation.prompt.md"; then
  echo "ASSERTION FAILED: expected Phase 3 prompt to forbid baseline scaffold validation"
  exit 1
fi

if ! grep -q "Treat the working set as read-only" "$tmpdir/external-phase3-fixture/prompts/phase3_curation.prompt.md"; then
  echo "ASSERTION FAILED: expected Phase 3 prompt to preserve working-set receipt provenance"
  exit 1
fi

python3 - "$phase3_target/workspace/newsletter_phase_receipts_2026-04-16.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["run_id"].startswith("proof_") or payload["run_id"] in {"fixture", "comparable-run", "non-comparable-run"}:
    raise SystemExit(f"expected refreshed experiment run_id, got {payload['run_id']}")
by_phase = {row["phase_id"]: row for row in payload["receipts"]}
if "phase3_working_set" not in by_phase:
    raise SystemExit("expected phase3_working_set receipt")
if "phase3_curated" not in by_phase:
    raise SystemExit("expected phase3_curated receipt")
row_run_ids = {row.get("run_id") for row in payload["receipts"] if row.get("run_id")}
if row_run_ids and row_run_ids != {payload["run_id"]}:
    raise SystemExit("expected retained receipt row run_id values to use the refreshed experiment run_id")
if "source_fixture_run_id" not in payload:
    raise SystemExit("expected copied fixture receipt provenance to retain source_fixture_run_id")
if by_phase["phase3_curated"]["receipt_order"] <= by_phase["phase3_working_set"]["receipt_order"]:
    raise SystemExit("expected phase3_curated receipt after working set")
late_phases = [
    phase_id
    for phase_id in by_phase
    if phase_id.startswith(("phase4", "phase5"))
]
if late_phases:
    raise SystemExit(f"expected phase3-curation to prune later receipts, saw {late_phases}")
phase2_orders = [
    row["receipt_order"]
    for row in payload["receipts"]
    if row["phase_id"].startswith("phase2")
]
if phase2_orders and by_phase["phase3_working_set"]["receipt_order"] <= max(phase2_orders):
    raise SystemExit("expected phase3 working-set receipt after retained phase2 receipts")
PY

cat > "$tmpdir/phase3-intermediate-failure.log" <<'EOF'
python3 tools/validate_phase3_curated.py 2026-02-14 2026-04-16 workspace/newsletter_phase3_curated_sections_2026-04-16.md --working-set workspace/newsletter_phase3_working_set_2026-04-16.md
The curated artifact is still the scaffold.
FAIL: scaffold placeholder bullets remain below 24-bullet floor.
Later final validation:
PASS: curated artifact contract satisfied (workspace/newsletter_phase3_curated_sections_2026-04-16.md, bullets=36, floor=24)
EOF
cat > "$tmpdir/phase3-concrete-failure.log" <<'EOF'
python3 tools/validate_phase3_curated.py 2026-02-14 2026-04-16 workspace/newsletter_phase3_curated_sections_2026-04-16.md --working-set workspace/newsletter_phase3_working_set_2026-04-16.md
FAIL: scaffold placeholder bullets remain below 24-bullet floor
Later final validation:
PASS: curated artifact contract satisfied (workspace/newsletter_phase3_curated_sections_2026-04-16.md, bullets=36, floor=24)
EOF
cat > "$tmpdir/phase3-failure-only.log" <<'EOF'
python3 tools/validate_phase3_curated.py 2026-02-14 2026-04-16 workspace/newsletter_phase3_curated_sections_2026-04-16.md --working-set workspace/newsletter_phase3_working_set_2026-04-16.md
FAIL: scaffold placeholder bullets remain below 24-bullet floor
EOF
cat > "$tmpdir/phase3-negated-failure.log" <<'EOF'
I won't run a validator baseline because the scaffold would fail before curation.
PASS: curated artifact contract satisfied (workspace/newsletter_phase3_curated_sections_2026-04-16.md, bullets=36, floor=24)
EOF
cat > "$tmpdir/phase3-clean.log" <<'EOF'
The model edited the curated sections directly.
PASS: curated artifact contract satisfied (workspace/newsletter_phase3_curated_sections_2026-04-16.md, bullets=36, floor=24)
EOF
cat > "$tmpdir/phase3-read-only.log" <<'EOF'
Read tools/validate_phase3_curated.py to inspect the contract.
The scaffold has placeholders, so I will edit the curated artifact before validation.
PASS: curated artifact contract satisfied (workspace/newsletter_phase3_curated_sections_2026-04-16.md, bullets=36, floor=24)
EOF
cat > "$tmpdir/phase3-prose-command.log" <<'EOF'
I will run python3 tools/validate_phase3_curated.py after editing.
The scaffold has placeholders right now, so validation passes only later.
EOF
cat > "$tmpdir/phase3-wrapped-command.log" <<'EOF'
│ python3
│ tools/validate_phase3_curated.py 2026-02-14 2026-04-16 workspace/newsletter_phase3_curated_sections_2026-04-16.md --working-set workspace/newsletter_phase3_working_set_2026-04-16.md
FAIL: scaffold placeholder bullets remain below 24-bullet floor
PASS: curated artifact contract satisfied (workspace/newsletter_phase3_curated_sections_2026-04-16.md, bullets=36, floor=24)
EOF
python3 tools/scan_phase3_log_signatures.py "$tmpdir/phase3-intermediate-failure.log" > "$tmpdir/phase3-intermediate-scan.json"
python3 - "$tmpdir/phase3-intermediate-scan.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["classification"] != "intermediate_scaffold_validator_failure_final_passed":
    raise SystemExit(payload)
if payload["has_intermediate_scaffold_validator_failure"] is not True:
    raise SystemExit("expected intermediate scaffold validator signature")
if payload["has_final_validation_pass"] is not True:
    raise SystemExit("expected final pass signal")
PY
python3 tools/scan_phase3_log_signatures.py "$tmpdir/phase3-concrete-failure.log" > "$tmpdir/phase3-concrete-scan.json"
python3 - "$tmpdir/phase3-concrete-scan.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["classification"] != "intermediate_scaffold_validator_failure_final_passed":
    raise SystemExit(payload)
if payload["has_intermediate_scaffold_validator_failure"] is not True:
    raise SystemExit("expected concrete validator failure signature")
PY
python3 tools/scan_phase3_log_signatures.py "$tmpdir/phase3-negated-failure.log" > "$tmpdir/phase3-negated-scan.json"
python3 - "$tmpdir/phase3-negated-scan.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["classification"] != "clean_final_validation_passed":
    raise SystemExit(payload)
if payload["has_intermediate_scaffold_validator_failure"]:
    raise SystemExit("negated baseline guidance should not become a stop signature")
PY
python3 tools/scan_phase3_log_signatures.py "$tmpdir/phase3-clean.log" > "$tmpdir/phase3-clean-scan.json"
python3 - "$tmpdir/phase3-clean-scan.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["classification"] != "clean_final_validation_passed":
    raise SystemExit(payload)
if payload["has_intermediate_scaffold_validator_failure"]:
    raise SystemExit("clean log should not carry intermediate scaffold validator signature")
PY
python3 tools/scan_phase3_log_signatures.py "$tmpdir/phase3-read-only.log" > "$tmpdir/phase3-read-only-scan.json"
python3 - "$tmpdir/phase3-read-only-scan.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["classification"] != "clean_final_validation_passed":
    raise SystemExit(payload)
if payload["has_intermediate_scaffold_validator_failure"]:
    raise SystemExit("reading validator source must not create execution context")
PY
python3 tools/scan_phase3_log_signatures.py "$tmpdir/phase3-prose-command.log" > "$tmpdir/phase3-prose-command-scan.json"
python3 - "$tmpdir/phase3-prose-command-scan.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["has_intermediate_scaffold_validator_failure"]:
    raise SystemExit("validator prose must not create execution context")
if payload["has_final_validation_pass"]:
    raise SystemExit("validator prose must not create final pass signal")
PY
python3 tools/scan_phase3_log_signatures.py "$tmpdir/phase3-wrapped-command.log" > "$tmpdir/phase3-wrapped-command-scan.json"
python3 - "$tmpdir/phase3-wrapped-command-scan.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["classification"] != "intermediate_scaffold_validator_failure_final_passed":
    raise SystemExit(payload)
if payload["has_intermediate_scaffold_validator_failure"] is not True:
    raise SystemExit("wrapped validator command should create execution context")
PY
python3 tools/scan_phase3_log_signatures.py "$tmpdir/phase3-failure-only.log" "$tmpdir/phase3-clean.log" > "$tmpdir/phase3-mixed-scan.json"
python3 - "$tmpdir/phase3-mixed-scan.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["classification"] != "mixed_independent_validator_signals":
    raise SystemExit(payload)
PY

if python3 tools/scan_phase3_log_signatures.py "$tmpdir/missing-phase3.log" >/tmp/test-experiment-surfaces-missing-scan.out 2>&1; then
  echo "ASSERTION FAILED: scanner should fail closed on missing log inputs"
  exit 1
fi

det_target="$tmpdir/deterministic-target"
det_path="$tmpdir/deterministic-no-copilot-path"
copilot_path="$(command -v copilot 2>/dev/null || true)"
copilot_dir=""
if [ -n "$copilot_path" ]; then
  copilot_dir="$(dirname "$copilot_path")"
fi
filtered_path=""
old_ifs="$IFS"
IFS=:
for entry in $PATH; do
  if [ -n "$copilot_dir" ] && [ "$entry" = "$copilot_dir" ]; then
    continue
  fi
  if [ -z "$filtered_path" ]; then
    filtered_path="$entry"
  else
    filtered_path="$filtered_path:$entry"
  fi
done
IFS="$old_ifs"
git clone -q . "$det_target"
cp tools/run_newsletter_phase4_fast.sh "$det_target/tools/"
cp tools/render_stage16_fast_newsletter.py "$det_target/tools/"
mkdir -p "$det_path"
for tool in bash python3 git; do
  ln -s "$(command -v "$tool")" "$det_path/$tool"
done

python3 tools/newsletter_phase_experimenter.py \
  materialize \
  --manifest config/experiment_fixture_packs/benchmark-anchor-2025-12-05_2026-02-13.json \
  --surface-id phase4_fast_surface \
  --target-repo "$det_target" >/dev/null

(
  cd "$det_target"
  PATH="$det_path:$filtered_path" \
  BENCHMARK_MODE=feb2026_consistency \
  RUN_DIR_OVERRIDE="$tmpdir/deterministic-target/runs/stage16-fast-regression" \
  bash tools/run_newsletter_phase4_fast.sh 2025-12-05 2026-02-13 >/dev/null
)

if grep -q '—' "$det_target/output/2026-02_february_newsletter.md"; then
  echo "ASSERTION FAILED: deterministic Stage 16 fast output retained em dashes"
  exit 1
fi

if grep -Eiq 'TODO|PLACEHOLDER|\[TBD\]|\[INSERT\]' "$det_target/output/2026-02_february_newsletter.md"; then
  echo "ASSERTION FAILED: deterministic Stage 16 fast output retained placeholder warning text"
  exit 1
fi

bash "$det_target/.github/skills/newsletter-validation/scripts/validate_newsletter.sh" \
  "$det_target/output/2026-02_february_newsletter.md" >/dev/null

mkdir -p "$tmpdir/runs/product_runs/incomplete-run"
cat > "$tmpdir/runs/product_runs/incomplete-run/README.txt" <<'EOF'
intentionally incomplete retained run for autodiscovery regression coverage
EOF

cp -R "$tmpdir/run/proof" "$tmpdir/runs/product_runs/complete-run"

(
  cd "$tmpdir"
  python3 tools/newsletter_hotspot_auditor.py --output "$tmpdir/hotspots-autodiscovery.json" >/dev/null
)

python3 - "$tmpdir/hotspots-autodiscovery.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if not payload["highest_cost_runs"]:
    raise SystemExit("expected autodiscovery hotspot audit to retain complete runs")
skipped = payload.get("skipped_runs", [])
if not skipped:
    raise SystemExit("expected autodiscovery hotspot audit to record skipped incomplete runs")
if not payload.get("highest_output_transitions"):
    raise SystemExit("expected autodiscovery hotspot audit to retain output-token hotspot transitions")
PY

cat > "$tmpdir/profiler-partial-estimates.json" <<'EOF'
{
  "runs": [],
  "phase_estimates": [
    {
      "run_id": "comparable-run",
      "transition": "phase1b -> phase2_event_sources",
      "duration_seconds": 10,
      "estimated_cost_usd": 1.25,
      "estimated_output_tokens": 120,
      "estimate_method": "receipt_span_proportion"
    },
    {
      "run_id": "non-comparable-run",
      "transition": "phase1b -> phase2_event_sources",
      "duration_seconds": 8,
      "estimated_cost_usd": null,
      "estimated_output_tokens": null,
      "estimate_method": "receipt_span_proportion"
    }
  ]
}
EOF

(
  cd "$tmpdir"
  python3 tools/newsletter_hotspot_auditor.py --profiler-json "$tmpdir/profiler-partial-estimates.json" --output "$tmpdir/hotspots-partial-estimates.json" >/dev/null
)

python3 - "$tmpdir/hotspots-partial-estimates.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
hot = payload["hottest_transitions"][0]
out = payload["highest_output_transitions"][0]
if hot["sample_count"] != 1 or hot["observation_count"] != 2:
    raise SystemExit("expected cost hotspot sample_count to count only comparable estimates")
if out["sample_count"] != 1 or out["observation_count"] != 2:
    raise SystemExit("expected output hotspot sample_count to count only comparable estimates")
PY

mkdir -p "$tmpdir/runs/product_runs/profiler-incomplete"
cat > "$tmpdir/runs/product_runs/profiler-incomplete/README.txt" <<'EOF'
incomplete profiler fixture
EOF

(
  cd "$tmpdir"
  python3 tools/newsletter_cost_profiler.py --runs-root "$tmpdir/runs/product_runs" --output "$tmpdir/profiler-autodiscovery.json" >/dev/null
)

python3 - "$tmpdir/profiler-autodiscovery.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["run_count"] < 1:
    raise SystemExit("expected profiler autodiscovery to retain complete runs")
if not payload.get("skipped_runs"):
    raise SystemExit("expected profiler autodiscovery to record skipped incomplete runs")
PY

cat > "$tmpdir/config/pricing/newsletter-model-pricing-override.json" <<'EOF'
{
  "generated_at": "2026-04-23T00:00:00Z",
  "models": [
    {
      "provider": "openai",
      "model": "gpt-5.5",
      "aliases": [
        "copilot/gpt-5.5"
      ],
      "input_price": 1.0,
      "output_price": 1.0,
      "cache_price": {
        "read": 0.0,
        "write": 0.0
      },
      "reasoning_price": 1.0
    }
  ]
}
EOF

(
  cd "$tmpdir"
  python3 tools/newsletter_cost_profiler.py \
    --run-dir "$tmpdir/run/proof" \
    --pricing-snapshot "$tmpdir/config/pricing/newsletter-model-pricing-override.json" \
    --output "$tmpdir/profiler-repriced.json" >/dev/null
)

python3 - "$tmpdir/profiler-repriced.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
run = payload["runs"][0]
expected = str((Path(sys.argv[1]).parent / "config/pricing/newsletter-model-pricing-override.json").resolve())
if run["cost_estimate"]["pricing_snapshot_path"] != expected:
    raise SystemExit("expected explicit pricing snapshot to reprice cached run")
PY

mkdir -p "$tmpdir/retained-runs"
cp -R runs/product_runs/20260501T024928Z_benchmark_proof "$tmpdir/retained-runs/"
cp -R runs/product_runs/20260430T115004Z_production_proof "$tmpdir/retained-runs/"

PYTHONPATH="$tmpdir/tools" python3 - <<'PY'
from prove_newsletter_stop_gates import benchmark_mode_for

try:
    benchmark_mode_for({"mode": "benchmark", "start": "2026-01-01", "end": "2026-02-01"})
except SystemExit as exc:
    if "missing benchmark_mode" not in str(exc):
        raise
else:
    raise SystemExit("expected benchmark replay to fail closed without declared benchmark_mode")
PY

(
  cd "$tmpdir"
  python3 tools/build_run_experiment_scorecard.py \
    --run-dir "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof" \
    --output "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof/run-scorecard.json" >/dev/null
  python3 tools/build_run_experiment_scorecard.py \
    --run-dir "$tmpdir/retained-runs/20260430T115004Z_production_proof" \
    --output "$tmpdir/retained-runs/20260430T115004Z_production_proof/run-scorecard.json" >/dev/null
)

cp "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof/run-scorecard.json" \
  "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof/missing-field-phase-token-negative.json"
jq '.token_usage.direct_provider_token_fields_present=["inputTokens"] | .token_usage.missing_direct_provider_token_fields=["outputTokens","cacheReadTokens","cacheWriteTokens","reasoningTokens"]' \
  "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof/run-scorecard.json" \
  > "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof/missing-field-phase-token-negative.json"
jq '.experiment.prompt_equality.current_renderer_sha256="0000000000000000000000000000000000000000000000000000000000000000" | .experiment.prompt_equality.matches_current_renderer=false | .experiment.prompt_equality.reason="Deliberately mutated current renderer hash negative control."' \
  "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof/run-scorecard.json" \
  > "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof/mutated-prompt-phase-token-negative.json"

(
  cd "$tmpdir"
  python3 tools/build_phase_token_telemetry_receipt.py \
    --run-dir "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof" \
    --scorecard "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof/run-scorecard.json" \
    --run-dir "$tmpdir/retained-runs/20260430T115004Z_production_proof" \
    --scorecard "$tmpdir/retained-runs/20260430T115004Z_production_proof/run-scorecard.json" \
    --negative-control "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof" "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof/missing-field-phase-token-negative.json" \
    --negative-control "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof" "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof/mutated-prompt-phase-token-negative.json" \
    --output "$tmpdir/phase-token-telemetry-receipt.json" >/dev/null
)

python3 - "$tmpdir/phase-token-telemetry-receipt.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("pass") is not True:
    raise SystemExit("expected fail-closed phase token telemetry receipt to pass shape/negative controls")
if payload.get("direct_phase_token_telemetry_available") is not False:
    raise SystemExit("retained runs must not qualify shutdown-only metrics as phase-boundary telemetry")
if payload.get("receipt_result") != "fail_closed_no_phase_boundary_provider_snapshots":
    raise SystemExit("expected retained aggregate-only runs to fail closed")
if payload.get("negative_controls_pass") is not True or payload.get("negative_control_count") != 2:
    raise SystemExit("expected missing-field and mutated-prompt negative controls to be rejected")
for run in payload.get("runs", []):
    if run.get("direct_model_metrics_snapshot_count") != 1:
        raise SystemExit("expected retained fixture to expose exactly one shutdown modelMetrics snapshot")
    if run.get("direct_phase_token_telemetry_available") is not False:
        raise SystemExit("expected no direct phase-local token deltas in retained fixture")
    if "fewer than two direct provider modelMetrics snapshots" not in str(run.get("qualification_reason")):
        raise SystemExit("expected missing event-shape reason for aggregate-only telemetry")
PY

if (
  cd "$tmpdir"
  python3 tools/build_phase_token_telemetry_receipt.py \
    --run-dir "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof" \
    --scorecard "$tmpdir/retained-runs/20260430T115004Z_production_proof/run-scorecard.json" \
    --output "$tmpdir/mismatched-phase-token-telemetry-receipt.json" \
    >"$tmpdir/mismatched-phase-token-telemetry-receipt.out" \
    2>"$tmpdir/mismatched-phase-token-telemetry-receipt.err"
); then
  echo "ASSERTION FAILED: expected phase-token telemetry to reject mismatched run/scorecard binding"
  exit 1
fi
if ! grep -q "Scorecard does not match run directory" "$tmpdir/mismatched-phase-token-telemetry-receipt.err"; then
  echo "ASSERTION FAILED: expected phase-token telemetry mismatch error"
  exit 1
fi

(
  cd "$tmpdir"
  python3 tools/prove_newsletter_stop_gates.py \
    --failed-run "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof" \
    --failed-scorecard "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof/run-scorecard.json" \
    --passing-run "$tmpdir/retained-runs/20260430T115004Z_production_proof" \
    --passing-scorecard "$tmpdir/retained-runs/20260430T115004Z_production_proof/run-scorecard.json" \
    --phase-token-telemetry "$tmpdir/phase-token-telemetry-receipt.json" \
    --output "$tmpdir/stop-gate-receipt.json" >/dev/null
)

python3 - "$tmpdir/stop-gate-receipt.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("pass") is not True:
    raise SystemExit("expected retained stop-gate proof to pass")
failed, passing = payload["runs"]
if payload.get("failed_run_phase1c_stopped") is not True:
    raise SystemExit("expected receipt pass to require failed-run Phase 1C stop")
if payload.get("passing_run_phase1c_continued") is not True:
    raise SystemExit("expected receipt pass to require passing-run Phase 1C continue")
if failed.get("first_stop_phase") != "phase1c_discoveries":
    raise SystemExit(f"expected failed run to stop at Phase 1C, got {failed.get('first_stop_phase')}")
if failed["phase1c_checkpoint"].get("gate") != "proposed_strict_phase1c_stop_gate":
    raise SystemExit("expected Phase 1C receipt to name the proposed strict stop gate")
phase1c_inputs = failed["phase1c_checkpoint"]["input_artifacts"]
if "phase1c_discoveries" not in phase1c_inputs:
    raise SystemExit("expected Phase 1C receipt to name the logical discoveries input")
if "legacy_filename_note" not in phase1c_inputs:
    raise SystemExit("expected Phase 1C receipt to document the legacy discoveries filename")
if passing.get("stopped"):
    raise SystemExit("expected passing run not to false-stop")
avoided = failed.get("avoided_work_lower_bound", {})
if avoided.get("token_count_lower_bound") is not None or avoided.get("cost_usd_lower_bound") is not None:
    raise SystemExit("expected token/cost lower bounds to stay null without phase-local token telemetry")
if avoided.get("phase_token_telemetry_available") is not False:
    raise SystemExit("expected stop-gate receipt to carry unavailable phase-token telemetry status")
if "fewer than two direct provider modelMetrics snapshots" not in str(avoided.get("token_cost_reason")):
    raise SystemExit("expected stop-gate token reason to cite missing phase-boundary snapshots")
if (avoided.get("phase_count_lower_bound") or 0) <= 0:
    raise SystemExit("expected positive avoided phase-count lower bound")
if avoided.get("basis") != "retained raw post-stop phase receipt chronology only":
    raise SystemExit("expected avoided-work basis to use raw retained chronology")
PY

jq '.receipt_type="wrong_phase_token_receipt_type"' \
  "$tmpdir/phase-token-telemetry-receipt.json" \
  > "$tmpdir/wrong-type-phase-token-telemetry-receipt.json"
if (
  cd "$tmpdir"
  python3 tools/prove_newsletter_stop_gates.py \
    --failed-run "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof" \
    --failed-scorecard "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof/run-scorecard.json" \
    --passing-run "$tmpdir/retained-runs/20260430T115004Z_production_proof" \
    --passing-scorecard "$tmpdir/retained-runs/20260430T115004Z_production_proof/run-scorecard.json" \
    --phase-token-telemetry "$tmpdir/wrong-type-phase-token-telemetry-receipt.json" \
    --output "$tmpdir/wrong-type-stop-gate-receipt.json" \
    >"$tmpdir/wrong-type-stop-gate-receipt.out" \
    2>"$tmpdir/wrong-type-stop-gate-receipt.err"
); then
  echo "ASSERTION FAILED: expected stop-gate replay to reject wrong phase-token receipt type"
  exit 1
fi
if ! grep -q "receipt_type" "$tmpdir/wrong-type-stop-gate-receipt.err"; then
  echo "ASSERTION FAILED: expected wrong receipt-type error"
  exit 1
fi

jq '.runs[0].scorecard_check.scorecard_file_sha256="0000000000000000000000000000000000000000000000000000000000000000"' \
  "$tmpdir/phase-token-telemetry-receipt.json" \
  > "$tmpdir/tampered-phase-token-telemetry-receipt.json"
if (
  cd "$tmpdir"
  python3 tools/prove_newsletter_stop_gates.py \
    --failed-run "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof" \
    --failed-scorecard "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof/run-scorecard.json" \
    --passing-run "$tmpdir/retained-runs/20260430T115004Z_production_proof" \
    --passing-scorecard "$tmpdir/retained-runs/20260430T115004Z_production_proof/run-scorecard.json" \
    --phase-token-telemetry "$tmpdir/tampered-phase-token-telemetry-receipt.json" \
    --output "$tmpdir/tampered-phase-token-stop-gate-receipt.json" \
    >"$tmpdir/tampered-phase-token-stop-gate-receipt.out" \
    2>"$tmpdir/tampered-phase-token-stop-gate-receipt.err"
); then
  echo "ASSERTION FAILED: expected stop-gate replay to reject tampered phase-token row hashes"
  exit 1
fi
if ! grep -q "scorecard_file_sha256" "$tmpdir/tampered-phase-token-stop-gate-receipt.err"; then
  echo "ASSERTION FAILED: expected tampered phase-token row hash error"
  exit 1
fi

jq '.run_dir="/portable/clone/runs/product_runs/20260501T024928Z_benchmark_proof"' \
  "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof/run-scorecard.json" \
  > "$tmpdir/portable-failed-scorecard.json"
jq '.run_dir="/portable/clone/runs/product_runs/20260430T115004Z_production_proof"' \
  "$tmpdir/retained-runs/20260430T115004Z_production_proof/run-scorecard.json" \
  > "$tmpdir/portable-passing-scorecard.json"
(
  cd "$tmpdir"
  python3 tools/prove_newsletter_stop_gates.py \
    --failed-run "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof" \
    --failed-scorecard "$tmpdir/portable-failed-scorecard.json" \
    --passing-run "$tmpdir/retained-runs/20260430T115004Z_production_proof" \
    --passing-scorecard "$tmpdir/portable-passing-scorecard.json" \
    --output "$tmpdir/stop-gate-portable-scorecard-receipt.json" >/dev/null
)

stop_stdout="$(
  cd "$tmpdir"
  python3 tools/prove_newsletter_stop_gates.py \
    --failed-run "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof" \
    --failed-scorecard "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof/run-scorecard.json" \
    --passing-run "$tmpdir/retained-runs/20260430T115004Z_production_proof" \
    --passing-scorecard "$tmpdir/retained-runs/20260430T115004Z_production_proof/run-scorecard.json" \
    --output /dev/stdout
)"
STOP_STDOUT="$stop_stdout" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["STOP_STDOUT"])
if payload.get("pass") is not True:
    raise SystemExit("expected stop-gate /dev/stdout output to be clean passing JSON")
PY

cp -R "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof" \
  "$tmpdir/retained-runs/20260501T024928Z_tampered_receipt_file"
(
  cd "$tmpdir"
  python3 tools/build_run_experiment_scorecard.py \
    --run-dir "$tmpdir/retained-runs/20260501T024928Z_tampered_receipt_file" \
    --output "$tmpdir/retained-runs/20260501T024928Z_tampered_receipt_file/run-scorecard.json" >/dev/null
)
python3 - "$tmpdir/retained-runs/20260501T024928Z_tampered_receipt_file/artifacts/workspace/newsletter_phase_receipts_2026-02-13.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["tampered_after_scorecard"] = True
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY
if (
  cd "$tmpdir"
  python3 tools/prove_newsletter_stop_gates.py \
    --failed-run "$tmpdir/retained-runs/20260501T024928Z_tampered_receipt_file" \
    --failed-scorecard "$tmpdir/retained-runs/20260501T024928Z_tampered_receipt_file/run-scorecard.json" \
    --passing-run "$tmpdir/retained-runs/20260430T115004Z_production_proof" \
    --passing-scorecard "$tmpdir/retained-runs/20260430T115004Z_production_proof/run-scorecard.json" \
    --output "$tmpdir/stop-gate-tampered-receipt-file.json" \
    >"$tmpdir/stop-gate-tampered-receipt-file.out" 2>"$tmpdir/stop-gate-tampered-receipt-file.err"
); then
  echo "ASSERTION FAILED: expected stop-gate proof to fail on mutated phase receipt file"
  exit 1
fi
if ! grep -q "receipt_file_sha256" "$tmpdir/stop-gate-tampered-receipt-file.err"; then
  echo "ASSERTION FAILED: expected phase receipt file hash mismatch error"
  exit 1
fi

cp -R "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof" \
  "$tmpdir/retained-runs/20260501T024928Z_uncountable_phase1b"
for path in "$tmpdir"/retained-runs/20260501T024928Z_uncountable_phase1b/artifacts/workspace/newsletter_phase1b_interim_*.md; do
  printf 'phase 1b artifact without countable headings\n' > "$path"
done
python3 - "$tmpdir/retained-runs/20260501T024928Z_uncountable_phase1b/artifacts/workspace/newsletter_phase_receipts_2026-02-13.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

receipt_path = Path(sys.argv[1])
artifact_root = receipt_path.parents[1]
payload = json.loads(receipt_path.read_text(encoding="utf-8"))
for row in payload["receipts"]:
    phase_id = row.get("phase_id", "")
    if not phase_id.startswith("phase1b_"):
        continue
    artifact = artifact_root / row["artifact_path"]
    data = artifact.read_bytes()
    row["artifact_sha256"] = hashlib.sha256(data).hexdigest()
    row["artifact_bytes"] = len(data)
    row["artifact_lines"] = artifact.read_text(encoding="utf-8").count("\n")
receipt_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY
(
  cd "$tmpdir"
  python3 tools/build_run_experiment_scorecard.py \
    --run-dir "$tmpdir/retained-runs/20260501T024928Z_uncountable_phase1b" \
    --output "$tmpdir/retained-runs/20260501T024928Z_uncountable_phase1b/run-scorecard.json" >/dev/null
)
(
  cd "$tmpdir"
  python3 tools/prove_newsletter_stop_gates.py \
    --failed-run "$tmpdir/retained-runs/20260501T024928Z_uncountable_phase1b" \
    --failed-scorecard "$tmpdir/retained-runs/20260501T024928Z_uncountable_phase1b/run-scorecard.json" \
    --passing-run "$tmpdir/retained-runs/20260430T115004Z_production_proof" \
    --passing-scorecard "$tmpdir/retained-runs/20260430T115004Z_production_proof/run-scorecard.json" \
    --output "$tmpdir/stop-gate-uncountable-phase1b-receipt.json" >/dev/null
)
python3 - "$tmpdir/stop-gate-uncountable-phase1b-receipt.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
checkpoint = payload["runs"][0]["phase1c_checkpoint"]
if checkpoint.get("continuity_ratio_unavailable_stop") is not True:
    raise SystemExit("expected uncountable Phase 1B headings to fail closed")
if checkpoint.get("ratio_stop") is not True:
    raise SystemExit("expected unavailable ratio to trigger ratio_stop")
PY

cp -R "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof" \
  "$tmpdir/retained-runs/20260501T024928Z_missing_phase1b"
(
  cd "$tmpdir"
  python3 tools/build_run_experiment_scorecard.py \
    --run-dir "$tmpdir/retained-runs/20260501T024928Z_missing_phase1b" \
    --output "$tmpdir/retained-runs/20260501T024928Z_missing_phase1b/run-scorecard.json" >/dev/null
)
find "$tmpdir/retained-runs/20260501T024928Z_missing_phase1b/artifacts/workspace" \
  -name 'newsletter_phase1b_interim_xcode_*' -delete
if (
  cd "$tmpdir"
  python3 tools/prove_newsletter_stop_gates.py \
    --failed-run "$tmpdir/retained-runs/20260501T024928Z_missing_phase1b" \
    --failed-scorecard "$tmpdir/retained-runs/20260501T024928Z_missing_phase1b/run-scorecard.json" \
    --passing-run "$tmpdir/retained-runs/20260430T115004Z_production_proof" \
    --passing-scorecard "$tmpdir/retained-runs/20260430T115004Z_production_proof/run-scorecard.json" \
    --output "$tmpdir/stop-gate-missing-input-receipt.json" \
    >"$tmpdir/stop-gate-missing-input.out" 2>"$tmpdir/stop-gate-missing-input.err"
); then
  echo "ASSERTION FAILED: expected stop-gate proof to fail closed on missing Phase 1C inputs"
  exit 1
fi

if ! grep -q "Missing required Phase 1C input" "$tmpdir/stop-gate-missing-input.err"; then
  echo "ASSERTION FAILED: expected missing Phase 1C input error"
  exit 1
fi

if (
  cd "$tmpdir"
  python3 tools/build_scorecard_telemetry_receipt.py \
    --scorecard "$tmpdir/tampered-positive-prompt-scorecard.json" \
    --output "$tmpdir/tampered-positive-prompt-receipt.json" >/dev/null
); then
  echo "ASSERTION FAILED: expected tampered positive prompt hashes to fail"
  exit 1
fi

python3 - "$tmpdir/tampered-positive-prompt-receipt.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
errors = payload["scorecards"][0].get("shape_errors", [])
if "retained prompt hash does not match experiment.prompt_sha256" not in errors:
    raise SystemExit("expected retained prompt hash to be anchored to experiment.prompt_sha256")
if "current renderer hash does not match freshly rendered prompt" not in errors:
    raise SystemExit("expected current renderer hash to be freshly recomputed for positives")
PY

jq '.phase_receipts.ordered_phase_ids=["phase1c_discoveries","phase4_scope_results"] | .phase_receipts.phase_spans_seconds={"phase1c_discoveries -> phase4_scope_results":9999}' \
  "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof/run-scorecard.json" \
  > "$tmpdir/tampered-failed-scorecard.json"
if (
  cd "$tmpdir"
  python3 tools/prove_newsletter_stop_gates.py \
    --failed-run "$tmpdir/retained-runs/20260501T024928Z_benchmark_proof" \
    --failed-scorecard "$tmpdir/tampered-failed-scorecard.json" \
    --passing-run "$tmpdir/retained-runs/20260430T115004Z_production_proof" \
    --passing-scorecard "$tmpdir/retained-runs/20260430T115004Z_production_proof/run-scorecard.json" \
    --output "$tmpdir/stop-gate-tampered-scorecard-receipt.json" \
    >"$tmpdir/stop-gate-tampered-scorecard.out" 2>"$tmpdir/stop-gate-tampered-scorecard.err"
); then
  echo "ASSERTION FAILED: expected stop-gate proof to fail closed on tampered scorecard phase receipts"
  exit 1
fi

if ! grep -q "phase_receipts.ordered_phase_ids does not match run audit" "$tmpdir/stop-gate-tampered-scorecard.err"; then
  echo "ASSERTION FAILED: expected tampered phase receipt error"
  exit 1
fi

fake_copilot="$tmpdir/fake-copilot"
cat > "$fake_copilot" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

mode="${FAKE_COPILOT_MODE:-blocked}"
if [ "${1:-}" = "--version" ]; then
  echo "GitHub Copilot CLI 9.9.9-test"
  exit 0
fi

for arg in "$@"; do
  if [ "$arg" = "--help" ] && [ "$mode" = "admitted" ]; then
    for proof_arg in "$@"; do
      if [ "$proof_arg" = "--no-cache" ]; then
        echo "Usage: copilot --model gpt-5.5 --no-cache -p PROMPT"
        exit 0
      fi
    done
  fi
done

if [ "${1:-}" = "--help" ]; then
  if [ "$mode" = "admitted" ]; then
    echo "Usage: copilot [--no-cache] [options]"
  elif [ "$mode" = "negated" ]; then
    echo "Usage: copilot [options]"
    echo "--no-cache is not supported for GitHub Copilot CLI"
  else
    echo "Usage: copilot [options]"
    echo "  --no-auto-update"
    echo "  --no-remote"
  fi
  exit 0
fi

if [ "${1:-}" = "help" ]; then
  case "${2:-}" in
    environment)
      echo "COPILOT_HOME controls CLI state only."
      ;;
    config)
      if [ "$mode" = "broken-config" ]; then
        echo "config help unavailable" >&2
        exit 9
      fi
      echo "keepAlive: off"
      ;;
    providers)
      echo "COPILOT_PROVIDER_BASE_URL changes provider routing."
      ;;
    *)
      echo "unknown help topic" >&2
      exit 1
      ;;
  esac
  exit 0
fi

echo "fake copilot should not be invoked for a blocked uncached proof run" >&2
exit 23
EOF
chmod +x "$fake_copilot"

python3 tools/admit_newsletter_no_cache_control.py \
  --copilot-bin "$fake_copilot" \
  --output "$tmpdir/no-cache-blocked-receipt.json" >/dev/null
python3 - "$tmpdir/no-cache-blocked-receipt.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("pass") is not False:
    raise SystemExit("expected no-cache admission to fail closed when no explicit flag exists")
if payload.get("admitted_mechanism") is not None:
    raise SystemExit("expected no admitted mechanism for blocked fake copilot")
if "No matched cache-control run is admitted unless pass is true." not in payload.get("non_claims", []):
    raise SystemExit("expected no-cache non-claim boundary")
PY

if python3 tools/admit_newsletter_no_cache_control.py \
  --copilot-bin "$fake_copilot" \
  --output "$tmpdir/no-cache-required-receipt.json" \
  --require-admitted >"$tmpdir/no-cache-required.out" 2>"$tmpdir/no-cache-required.err"; then
  echo "ASSERTION FAILED: expected require-admitted no-cache check to fail closed"
  exit 1
fi
if ! grep -q "No admitted Copilot CLI no-cache/uncached mechanism" "$tmpdir/no-cache-required.err"; then
  echo "ASSERTION FAILED: expected require-admitted blocker message"
  exit 1
fi

FAKE_COPILOT_MODE=negated python3 tools/admit_newsletter_no_cache_control.py \
  --copilot-bin "$fake_copilot" \
  --output "$tmpdir/no-cache-negated-receipt.json" >/dev/null
python3 - "$tmpdir/no-cache-negated-receipt.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("pass") is not False:
    raise SystemExit("expected negated --no-cache help text not to admit the mechanism")
if payload.get("candidate_validation_errors"):
    raise SystemExit("expected negated help text to be rejected before command validation")
PY

FAKE_COPILOT_MODE=broken-config python3 tools/admit_newsletter_no_cache_control.py \
  --copilot-bin "$fake_copilot" \
  --output "$tmpdir/no-cache-inspection-failed-receipt.json" >/dev/null
python3 - "$tmpdir/no-cache-inspection-failed-receipt.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("status") != "inspection_failed":
    raise SystemExit("expected failed help surface to be distinct from no supported mechanism")
if payload.get("inspection_complete") is not False:
    raise SystemExit("expected inspection_complete=false")
if not payload.get("surface_failures"):
    raise SystemExit("expected retained surface failure details")
PY

FAKE_COPILOT_MODE=admitted python3 tools/admit_newsletter_no_cache_control.py \
  --copilot-bin "$fake_copilot" \
  --output "$tmpdir/no-cache-admitted-receipt.json" \
  --args-output "$tmpdir/no-cache-admitted-args.txt" \
  --require-admitted >/dev/null
python3 - "$tmpdir/no-cache-admitted-receipt.json" "$tmpdir/no-cache-admitted-args.txt" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
args_text = Path(sys.argv[2]).read_text(encoding="utf-8").strip()
if payload.get("pass") is not True:
    raise SystemExit("expected explicit fake --no-cache flag to be admitted")
if payload.get("recommended_copilot_args") != ["--no-cache"]:
    raise SystemExit("expected --no-cache recommended args")
if payload.get("admitted_mechanism", {}).get("type") != "argv":
    raise SystemExit("expected typed argv mechanism")
if payload.get("admitted_mechanism", {}).get("validation", {}).get("pass") is not True:
    raise SystemExit("expected proof-command option parser validation")
if args_text != "--no-cache":
    raise SystemExit("expected args output to contain --no-cache")
PY

if NEWSLETTER_REQUIRE_UNCACHED_CONTROL=1 COPILOT_BIN="$fake_copilot" \
  bash tools/run_product_newsletter.sh \
    2026-02-14 \
    2026-04-16 \
    production \
    --run-dir "$tmpdir/no-cache-proof-run" \
    >"$tmpdir/no-cache-proof-run.out" 2>"$tmpdir/no-cache-proof-run.err"; then
  echo "ASSERTION FAILED: expected proof run to stop before a weak uncached control"
  exit 1
fi
if [ ! -f "$tmpdir/no-cache-proof-run/no-cache-control-receipt.json" ]; then
  echo "ASSERTION FAILED: expected blocked proof run to retain no-cache receipt"
  exit 1
fi
if [ -f "$tmpdir/no-cache-proof-run/copilot.log" ]; then
  echo "ASSERTION FAILED: expected blocked no-cache proof run to avoid invoking copilot"
  exit 1
fi
python3 - "$tmpdir/no-cache-proof-run/no-cache-control-receipt.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("status") != "blocked_no_supported_mechanism":
    raise SystemExit("expected proof-run receipt to record blocked mechanism status")
PY

mkdir -p "$tmpdir/stale-no-cache-proof-run"
printf 'stale copilot log\n' > "$tmpdir/stale-no-cache-proof-run/copilot.log"
if NEWSLETTER_REQUIRE_UNCACHED_CONTROL=1 COPILOT_BIN="$fake_copilot" \
  bash tools/run_product_newsletter.sh \
    2026-02-14 \
    2026-04-16 \
    production \
    --run-dir "$tmpdir/stale-no-cache-proof-run" \
    >"$tmpdir/stale-no-cache-proof-run.out" 2>"$tmpdir/stale-no-cache-proof-run.err"; then
  echo "ASSERTION FAILED: expected stale uncached-control run dir to fail closed"
  exit 1
fi
if ! grep -q "uncached-control run dir already contains artifacts" "$tmpdir/stale-no-cache-proof-run.err"; then
  echo "ASSERTION FAILED: expected stale uncached-control run dir error"
  exit 1
fi

echo "PASS: experiment surface tests passed"

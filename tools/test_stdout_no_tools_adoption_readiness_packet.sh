#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

python3 -m py_compile tools/build_stdout_no_tools_adoption_readiness_packet.py

python3 - "$tmpdir" <<'PY'
import json
import copy
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def base_config():
    return {
        "schema_version": 1,
        "status": "disabled_by_default",
        "tactic": "phase3_stdout_no_tools_artifact_reuse",
        "target_phase": "phase3_curation",
        "default_enabled": False,
        "production_behavior_enabled": False,
        "benchmark_evidence_floor": {
            "qualified_pair_count": 3,
            "minimum_total_direct_token_reduction_pct": 5,
            "candidate_tool_calls": 0,
            "candidate_request_count_not_higher": True,
            "direct_provider_token_fields_required": True,
            "session_binding_required": True,
            "no_refetch_binding_required": True,
            "quality_pass_required": True,
        },
        "production_admission_state": {
            "no_refetch_admission_attempted": True,
            "live_production_pair_attempted": True,
        },
        "rollback_notes": ["Use canonical Phase 3 control path if any gate fails."],
        "non_claims": [
            "This package does not enable production behavior.",
            "It is not a durable savings claim.",
            "It is not a GitHub Copilot billing claim.",
            "It is not a model recommendation.",
        ],
    }


def pair(
    pair_id,
    reduction=88.0,
    request_delta=-1,
    tool_delta=-1,
    qualifies=True,
    evidence_complete=True,
    blockers=None,
    skip_receipt=False,
    receipt_admitted=True,
):
    return {
        "pair_id": pair_id,
        "evidence_complete": evidence_complete,
        "qualifies": qualifies,
        "blockers": blockers or [],
        "receipt_path": f"planning/example/{pair_id}.json",
        "_skip_receipt": skip_receipt,
        "_receipt_admitted": receipt_admitted,
        "candidate": {"tool_calls": 0, "request_count": 1, "total_direct_tokens": 10},
        "control": {"tool_calls": 2, "request_count": 2, "total_direct_tokens": 100},
        "deltas": {
            "total_direct_token_reduction_pct": reduction,
            "request_count_candidate_minus_control": request_delta,
            "tool_calls_candidate_minus_control": tool_delta,
        },
    }


def pair_receipt(pair_payload):
    pair_id = pair_payload["pair_id"]
    admitted = pair_payload.get("_receipt_admitted", True)
    reduction = pair_payload["deltas"]["total_direct_token_reduction_pct"]
    request_delta = pair_payload["deltas"]["request_count_candidate_minus_control"]
    tool_delta = pair_payload["deltas"]["tool_calls_candidate_minus_control"]
    candidate_tool_calls = pair_payload["candidate"]["tool_calls"]
    return {
        "receipt_type": "artifact_reuse_stdout_no_tools_phase3_pair",
        "slice": {"mode": "production", "model": "gpt-5.5"},
        "selected_source_no_refetch": {
            "admission_verdict": "admit_no_refetch",
            "sidecars": {
                "phase2_selected_source_ids": {"exists": True, "sha256": "a" * 64},
                "phase2_fetch_attempt_ledger": {"exists": True, "sha256": "b" * 64},
                "phase2_no_refetch_compliance": {"exists": True, "sha256": "c" * 64},
            },
        },
        "candidate": {
            "passes": admitted,
            "metrics": {
                "phase_id": "phase3_stdout_no_tools_artifact_reuse",
                "direct_fields_complete": True,
                "session_detection_status": "bound_candidate",
                "bound_candidate_count": 1,
                "candidate_count": 1,
                "numeric_fields_complete": True,
                "tool_calls": candidate_tool_calls,
                "tool_event_count": candidate_tool_calls,
            },
            "no_refetch_sidecar_materialization": {
                "sidecars": {
                    "phase2_selected_source_ids": {"sha256": "a" * 64, "source_sha256": "a" * 64},
                    "phase2_fetch_attempt_ledger": {"sha256": "b" * 64, "source_sha256": "b" * 64},
                    "phase2_no_refetch_compliance": {"sha256": "c" * 64, "source_sha256": "c" * 64},
                }
            },
            "validation_payload": {"exit_code": 0},
            "stdout_artifact": {"exists": True},
            "materialized_artifact": {"exists": True},
            "validation_result": {"exists": True},
        },
        "control": {
            "passes": True,
            "metrics": {
                "phase_id": "phase3_curation",
                "direct_fields_complete": True,
                "session_detection_status": "bound_candidate",
                "bound_candidate_count": 1,
                "candidate_count": 1,
                "numeric_fields_complete": True,
            },
        },
        "deltas": {
            "total_direct_token_reduction_pct": reduction,
            "candidate_total_direct_tokens_at_least_5pct_lower": reduction >= 5,
            "request_count_candidate_minus_control": request_delta,
            "candidate_request_count_not_higher": request_delta <= 0,
            "tool_calls_candidate_minus_control": tool_delta,
        },
        "admission": {
            "admitted_for_single_live_phase3_pair": admitted,
            "verdict": "admit_single_pair_stdout_no_tools_evidence" if admitted else "blocked_incomplete_evidence",
            "blockers": [] if admitted else [f"{pair_id} intentionally blocked"],
        },
    }


def confirmation(**overrides):
    payload = {
        "outcome": "strong_pass_two_production_pairs_qualified",
        "attempted_pairs": 2,
        "qualified_pairs": 2,
        "aggregate_metrics": {
            "median_total_direct_token_reduction_pct": 88.0,
            "median_request_delta": -1,
            "median_tool_call_delta": -1,
        },
        "pairs": [pair("production_pair_01"), pair("production_pair_02")],
        "non_claims": [
            "This is not production enablement and does not enable production behavior.",
            "This is not a durable savings claim.",
            "This is not a GitHub Copilot billing claim.",
            "This is not a model recommendation.",
        ],
    }
    payload.update(overrides)
    return payload


def burst40_packet(**overrides):
    payload = {
        "disabled_by_default": True,
        "readiness_verdict": "ready_for_explicit_future_adoption_review",
        "required_future_approval": "Explicit operator authorization is required before any production enablement.",
        "rollback_notes": ["Disable immediately on any missing direct field."],
        "non_claims": [
            "This packet does not enable production behavior.",
            "This is not a durable savings claim.",
            "This is not a GitHub Copilot billing claim.",
            "This is not a model recommendation.",
        ],
    }
    payload.update(overrides)
    return payload


def run_case(name, config_payload, confirmation_payload, packet_payload):
    case = root / name
    confirmation_payload = copy.deepcopy(confirmation_payload)
    for pair_payload in confirmation_payload.get("pairs", []):
        if not isinstance(pair_payload, dict):
            continue
        receipt_path = case / f"{pair_payload['pair_id']}-receipt.json"
        pair_payload["receipt_path"] = str(receipt_path)
        if pair_payload.pop("_skip_receipt", False):
            continue
        write_json(receipt_path, pair_receipt(pair_payload))
        pair_payload.pop("_receipt_admitted", None)
    config_path = case / "config.json"
    confirmation_path = case / "confirmation.json"
    packet_path = case / "packet.json"
    output_path = case / "out.json"
    write_json(config_path, config_payload)
    write_json(confirmation_path, confirmation_payload)
    write_json(packet_path, packet_payload)
    result = subprocess.run(
        [
            sys.executable,
            "tools/build_stdout_no_tools_adoption_readiness_packet.py",
            "--adoption-config",
            str(config_path),
            "--production-confirmation-receipt",
            str(confirmation_path),
            "--burst40-adoption-packet",
            str(packet_path),
            "--output",
            str(output_path),
        ],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    payload = json.loads(output_path.read_text(encoding="utf-8"))
    return result, payload


ok, admitted = run_case("admitted", base_config(), confirmation(), burst40_packet())
assert ok.returncode == 0, ok.stderr
assert admitted["verdict"] == "ready_for_disabled_enablement_prep_review"
assert admitted["ready_for_production_enablement"] is False
assert admitted["requires_explicit_operator_approval_before_enablement"] is True
assert admitted["production_behavior_enabled"] is False
assert admitted["qualified_production_evidence"]["qualified_pairs"] == 2

enabled_config = base_config()
enabled_config["production_behavior_enabled"] = True
failed, blocked = run_case("enabled-config", enabled_config, confirmation(), burst40_packet())
assert failed.returncode == 2
assert "production_behavior_enabled must be false" in "\n".join(blocked["blockers"])

weak_confirmation = confirmation(qualified_pairs=1, pairs=[pair("production_pair_01")])
failed, blocked = run_case("missing-pair", base_config(), weak_confirmation, burst40_packet())
assert failed.returncode == 2
assert "at least 2 qualified pairs" in "\n".join(blocked["blockers"])

amplified = confirmation(pairs=[pair("production_pair_01"), pair("production_pair_02", request_delta=1)])
failed, blocked = run_case("request-amplification", base_config(), amplified, burst40_packet())
assert failed.returncode == 2
assert "request count must not exceed control" in "\n".join(blocked["blockers"])

no_approval = burst40_packet(required_future_approval="Future review required.")
failed, blocked = run_case("missing-approval", base_config(), confirmation(), no_approval)
assert failed.returncode == 2
assert "explicit operator authorization" in "\n".join(blocked["blockers"])

weak_non_claim = burst40_packet(non_claims=["Not production enablement."])
failed, blocked = run_case("weak-non-claim", base_config(), confirmation(), weak_non_claim)
assert failed.returncode == 2
assert "billing proof" in "\n".join(blocked["blockers"])

affirmative_billing = burst40_packet(non_claims=[
    "This is not production enablement.",
    "This is not a durable savings claim.",
    "This is GitHub Copilot billing proof.",
    "This is not a model recommendation.",
])
failed, blocked = run_case("affirmative-billing", base_config(), confirmation(), affirmative_billing)
assert failed.returncode == 2
assert "billing proof" in "\n".join(blocked["blockers"])

malformed_config = base_config()
malformed_config["benchmark_evidence_floor"]["qualified_pair_count"] = {"bad": "shape"}
failed, blocked = run_case("malformed-config", malformed_config, confirmation(), burst40_packet())
assert failed.returncode == 2
assert "qualified_pair_count must be an integer" in "\n".join(blocked["blockers"])

malformed_receipt = confirmation(aggregate_metrics=["bad"], pairs=["bad"])
failed, blocked = run_case("malformed-receipt", base_config(), malformed_receipt, burst40_packet())
assert failed.returncode == 2
blocked_text = "\n".join(blocked["blockers"])
assert "aggregate_metrics must be an object" in blocked_text
assert "production confirmation pair must be an object" in blocked_text

missing_pair_receipt = confirmation(pairs=[pair("production_pair_01"), pair("production_pair_02", skip_receipt=True)])
failed, blocked = run_case("missing-pair-receipt", base_config(), missing_pair_receipt, burst40_packet())
assert failed.returncode == 2
assert "pair receipt does not exist" in "\n".join(blocked["blockers"])

stale_pair_receipt = confirmation(
    pairs=[pair("production_pair_01"), pair("production_pair_02", receipt_admitted=False)]
)
failed, blocked = run_case("stale-pair-receipt", base_config(), stale_pair_receipt, burst40_packet())
assert failed.returncode == 2
assert "pair admission" in "\n".join(blocked["blockers"])
PY

out="$tmpdir/current-owner-packet.json"
python3 tools/build_stdout_no_tools_adoption_readiness_packet.py \
  --adoption-config config/experiment_adoption_prep/stdout_no_tools_artifact_reuse_burst39.json \
  --production-confirmation-receipt planning/stdout-no-tools-production-confirmation-burst-40-2026-05-08/production-confirmation-receipt.json \
  --burst40-adoption-packet planning/stdout-no-tools-production-confirmation-burst-40-2026-05-08/adoption-readiness-packet.json \
  --output "$out"

python3 - "$out" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert payload["verdict"] == "ready_for_disabled_enablement_prep_review"
assert payload["ready_for_production_enablement"] is False
assert payload["production_behavior_enabled"] is False
assert not payload["blockers"]
PY

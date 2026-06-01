#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

PYTHONPATH=tools python3 - "$tmpdir" "$PWD" <<'PY'
import json
import sys
from pathlib import Path
from types import SimpleNamespace

import run_copilot_phase as runner
from newsletter_experiment_common import parse_session_metrics

tmpdir = Path(sys.argv[1])
root = Path(sys.argv[2]).resolve()
prompt = tmpdir / "phase3.prompt.md"
prompt.write_text("Run only Phase 3.\n", encoding="utf-8")
rendered = tmpdir / "phase3.rendered.prompt.md"
rendered.write_text("Run only Phase 3.\n<!-- marker -->\n", encoding="utf-8")
log_path = tmpdir / "phase3.log"
log_path.write_text("OK\n", encoding="utf-8")

args = SimpleNamespace(
    agent="customer_newsletter",
    artifact_path=[
        "workspace/newsletter_phase3_working_set_2026-04-16.md",
        "workspace/newsletter_phase3_curated_sections_2026-04-16.md",
    ],
    available_tool=[],
    copilot_bin="copilot",
    cwd=str(root),
    excluded_tool=[],
    enable_reasoning_summaries=False,
    expected_response_marker=None,
    metrics_out=str(tmpdir / "phase-session-metrics.jsonl"),
    model="gpt-5.5",
    phase_id="phase3_curated",
    prompt_file=str(prompt),
    reasoning_effort=None,
    receipt_id=["phase3_working_set", "phase3_curated"],
    require_session_log=True,
    log=str(log_path),
    stdout_out=None,
    timeout=30,
    use_copilot_cwd_flag=False,
    silent=False,
    output_format=None,
    log_level=None,
    log_dir=None,
    name=None,
    session_state_base=None,
    session_out=None,
)

request_log = tmpdir / "request.events.jsonl"
request_log.write_text(
    "\n".join(
        json.dumps(row, sort_keys=True)
        for row in [
            {
                "type": "provider.request",
                "timestamp": "2026-05-19T00:00:01Z",
                "data": {
                    "requestIndex": 1,
                    "turnIndex": 1,
                    "model": "gpt-5.5",
                    "usage": {
                        "inputTokens": 100,
                        "outputTokens": 20,
                        "cacheReadTokens": 10,
                        "cacheWriteTokens": 0,
                        "reasoningTokens": 5,
                    },
                },
            },
            {
                "type": "session.shutdown",
                "timestamp": "2026-05-19T00:00:02Z",
                "data": {
                    "currentModel": "gpt-5.5",
                    "totalPremiumRequests": 1,
                    "modelMetrics": {
                        "gpt-5.5": {
                            "requests": {"count": 1},
                            "usage": {
                                "inputTokens": 100,
                                "outputTokens": 20,
                                "cacheReadTokens": 10,
                                "cacheWriteTokens": 0,
                                "reasoningTokens": 5,
                            },
                        }
                    },
                },
            },
        ]
    )
    + "\n",
    encoding="utf-8",
)
request_usage = parse_session_metrics(request_log)
request_rows = runner.build_provider_token_rows(
    request_log,
    request_usage,
    route_id="route-request",
    fallback_model="gpt-5.5",
)
if len(request_rows) != 1:
    raise SystemExit(f"expected one request row, got {len(request_rows)}")
request_row = request_rows[0]
if request_row["telemetry_scope"] != "provider_request_event":
    raise SystemExit("expected provider request telemetry scope")
if request_row["request_index"] != 1 or request_row["turn_index"] != 1:
    raise SystemExit("expected request and turn indexes to be preserved")
if request_row["direct_fields_complete"] is not True:
    raise SystemExit("expected complete direct request fields")
request_scan = runner.provider_token_event_scan(request_log)
if request_scan["status"] != "indexed_provider_request_events_available":
    raise SystemExit("expected indexed request event scan")
request_policy = runner.provider_token_evidence_policy(
    request_rows,
    {"route_id": "route-request"},
    request_scan,
)
if request_policy["status"] != "true_request_level_provider_token_rows":
    raise SystemExit("expected true request-level provider-token policy")
if request_policy["candidate_or_savings_measurement_ready"] is not False:
    raise SystemExit("Burst 139 request-level row policy must remain non-admitting")
incomplete_request_log = tmpdir / "incomplete-request.events.jsonl"
incomplete_request_log.write_text(
    json.dumps(
        {
            "type": "provider.request",
            "timestamp": "2026-05-19T00:00:01Z",
            "data": {
                "requestIndex": 1,
                "turnIndex": 1,
                "model": "gpt-5.5",
                "usage": {
                    "inputTokens": 100,
                    "outputTokens": 20,
                },
            },
        },
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)
incomplete_request_rows = runner.build_provider_token_rows(
    incomplete_request_log,
    parse_session_metrics(incomplete_request_log)
    or {
        "source": None,
        "model_breakdown": {},
        "missing_direct_provider_token_fields": [],
    },
    route_id="route-incomplete-request",
    fallback_model="gpt-5.5",
)
incomplete_request_policy = runner.provider_token_evidence_policy(
    incomplete_request_rows,
    {"route_id": "route-incomplete-request"},
    runner.provider_token_event_scan(incomplete_request_log),
)
if incomplete_request_policy["status"] != "request_level_provider_token_rows_incomplete":
    raise SystemExit("expected incomplete request rows to fail closed")
if incomplete_request_policy["candidate_or_savings_measurement_ready"] is not False:
    raise SystemExit("incomplete request rows must not admit candidate/savings measurement")
turn_only_log = tmpdir / "turn-only.events.jsonl"
turn_only_log.write_text(
    json.dumps(
        {
            "type": "provider.request",
            "timestamp": "2026-05-19T00:00:01Z",
            "data": {
                "turnIndex": 1,
                "model": "gpt-5.5",
                "usage": {
                    "inputTokens": 100,
                    "outputTokens": 20,
                    "cacheReadTokens": 0,
                    "cacheWriteTokens": 0,
                    "reasoningTokens": 1,
                },
            },
        },
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)
turn_only_scan = runner.provider_token_event_scan(turn_only_log)
if turn_only_scan["status"] != "turn_indexed_provider_token_events_only":
    raise SystemExit("expected turn-only provider event scan")
turn_only_rows = runner.build_provider_token_rows(
    turn_only_log,
    parse_session_metrics(turn_only_log)
    or {
        "source": None,
        "model_breakdown": {},
        "missing_direct_provider_token_fields": [],
    },
    route_id="route-turn-only",
    fallback_model="gpt-5.5",
)
if turn_only_rows:
    raise SystemExit("turn-only token events must not be emitted as request-level rows")

aggregate_log = tmpdir / "aggregate.events.jsonl"
aggregate_log.write_text(
    json.dumps(
        {
            "type": "session.shutdown",
            "timestamp": "2026-05-19T00:00:02Z",
            "data": {
                "currentModel": "gpt-5.5",
                "totalPremiumRequests": 2,
                "modelMetrics": {
                    "gpt-5.5": {
                        "requests": {"count": 2},
                        "usage": {
                            "inputTokens": 300,
                            "outputTokens": 40,
                            "cacheReadTokens": 25,
                            "cacheWriteTokens": 0,
                            "reasoningTokens": 7,
                        },
                    }
                },
            },
        },
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)
aggregate_usage = parse_session_metrics(aggregate_log)
aggregate_route_lock = runner.route_lock_for_phase(
    args,
    effective_prompt_path=rendered,
    token_usage=aggregate_usage,
    command_argv=["copilot", "--model", "gpt-5.5", "-p", "full prompt text"],
    returncode=0,
    session_detection={"status": "bound_candidate"},
)
aggregate_rows = runner.build_provider_token_rows(
    aggregate_log,
    aggregate_usage,
    route_id=str(aggregate_route_lock["route_id"]),
    fallback_model="gpt-5.5",
)
if aggregate_rows[0]["telemetry_scope"] != "session_shutdown_model_aggregate":
    raise SystemExit("expected aggregate fallback row")
aggregate_scan = runner.provider_token_event_scan(aggregate_log)
if aggregate_scan["status"] != "aggregate_shutdown_only":
    raise SystemExit("expected aggregate-only event scan")
aggregate_policy = runner.provider_token_evidence_policy(
    aggregate_rows,
    aggregate_route_lock,
    aggregate_scan,
)
if aggregate_policy["status"] != "equivalent_route_topology_lock_with_session_shutdown_model_aggregate":
    raise SystemExit("expected explicit aggregate-equivalent route topology policy")
if aggregate_policy["candidate_or_savings_measurement_ready"] is not False:
    raise SystemExit("aggregate-equivalent policy must not admit candidate/savings measurement")
if aggregate_rows[0]["request_index"] is not None or aggregate_rows[0]["turn_index"] is not None:
    raise SystemExit("aggregate fallback must not invent request or turn indexes")
if aggregate_route_lock["direct_fields_complete"] is not True:
    raise SystemExit("expected complete aggregate direct fields")
if aggregate_route_lock["route_command_argv"][-1] != "<prompt>":
    raise SystemExit("expected route command prompt redaction")
if len(str(aggregate_route_lock["frozen_pre_render_input_manifest_sha256"])) != 64:
    raise SystemExit("expected route lock frozen input hash")

missing_log = tmpdir / "missing.events.jsonl"
missing_log.write_text(
    json.dumps(
        {
            "type": "session.shutdown",
            "timestamp": "2026-05-19T00:00:02Z",
            "data": {
                "currentModel": "gpt-5.5",
                "totalPremiumRequests": 1,
                "modelMetrics": {
                    "gpt-5.5": {
                        "requests": {"count": 1},
                        "usage": {
                            "inputTokens": 300,
                            "outputTokens": 40,
                        },
                    }
                },
            },
        },
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)
missing_usage = parse_session_metrics(missing_log)
missing_route_lock = runner.route_lock_for_phase(
    args,
    effective_prompt_path=rendered,
    token_usage=missing_usage,
    command_argv=["copilot", "--model", "gpt-5.5", "-p", "full prompt text"],
    returncode=0,
    session_detection={"status": "bound_candidate"},
)
if missing_route_lock["direct_fields_complete"] is not False:
    raise SystemExit("expected missing direct fields to fail closed")
if missing_route_lock["quality_gate_state"] != "phase_exit_zero_direct_fields_incomplete":
    raise SystemExit("expected incomplete-direct-fields quality state")
missing_rows = runner.build_provider_token_rows(
    missing_log,
    missing_usage,
    route_id=str(missing_route_lock["route_id"]),
    fallback_model="gpt-5.5",
)
missing_policy = runner.provider_token_evidence_policy(
    missing_rows,
    missing_route_lock,
    runner.provider_token_event_scan(missing_log),
)
if missing_policy["status"] != "aggregate_provider_token_rows_incomplete":
    raise SystemExit("expected incomplete aggregate rows to fail closed")

marker = f"{runner.INVOCATION_MARKER_PREFIX} fixture-marker"
state_base = tmpdir / "session-state"
first_session = state_base / "one"
first_session.mkdir(parents=True)
(first_session / "events.jsonl").write_text(
    json.dumps(
        {
            "type": "user.message",
            "data": {
                "message": f"hello {marker}",
            },
        },
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)
prelaunch_scan = runner.build_marker_scan(state_base, marker)
if prelaunch_scan["match_count"] != 1 or prelaunch_scan["clean"] is not False:
    raise SystemExit("expected pre-launch marker scan to find prior marker")
if runner.session_logs_containing_marker(state_base, marker) != [(first_session / "events.jsonl").resolve()]:
    raise SystemExit("expected marker search to return the matching session log")

second_session = state_base / "two"
second_session.mkdir(parents=True)
(second_session / "events.jsonl").write_text(
    json.dumps(
        {
            "type": "user.message",
            "data": {
                "message": f"ambiguous {marker}",
            },
        },
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)
ambiguous_prelaunch_scan = runner.build_marker_scan(state_base, marker)
if ambiguous_prelaunch_scan["match_count"] != 2:
    raise SystemExit("expected pre-launch marker scan to retain ambiguous match count")

preexisting_gate = runner.quality_gate_state(
    0,
    {"status": "preexisting_invocation_marker"},
    aggregate_usage,
)
if preexisting_gate != "phase_prelaunch_session_log_preexisting_invocation_marker":
    raise SystemExit("expected preexisting marker to fail closed before phase execution")

stale_session_gate = runner.quality_gate_state(
    0,
    {"status": "bound_candidate_before_child_launch"},
    aggregate_usage,
)
if stale_session_gate != "phase_exit_zero_session_log_bound_candidate_before_child_launch":
    raise SystemExit("expected stale bound session to fail closed")
stale_session_orchestrator_exit_gate = runner.quality_gate_state(
    2,
    {"status": "bound_candidate_before_child_launch"},
    aggregate_usage,
)
if stale_session_orchestrator_exit_gate != "phase_exit_zero_session_log_bound_candidate_before_child_launch":
    raise SystemExit("expected stale bound session state to survive orchestrator exit code")

unavailable_rows = runner.aggregate_provider_token_rows(
    {
        "source": None,
        "primary_model": "gpt-5.5",
        "model_breakdown": {},
        "missing_direct_provider_token_fields": [
            "inputTokens",
            "outputTokens",
            "cacheReadTokens",
            "cacheWriteTokens",
            "reasoningTokens",
        ],
    },
    route_id="route-unavailable",
    fallback_model="gpt-5.5",
)
if unavailable_rows:
    raise SystemExit("provider token rows must not be fabricated without shutdown metrics")

marker_session_log = tmpdir / "marker.events.jsonl"
expected_marker = "BURST139_MARKER_OK"
marker_session_log.write_text(
    "\n".join(
        json.dumps(row, sort_keys=True)
        for row in [
            {
                "type": "assistant.message",
                "data": {
                    "content": f"{expected_marker}\n\nInspected tools/run_copilot_phase.py.",
                },
            },
            {
                "type": "session.shutdown",
                "data": {
                    "currentModel": "gpt-5.5",
                    "modelMetrics": {
                        "gpt-5.5": {
                            "requests": {"count": 1},
                            "usage": {
                                "inputTokens": 10,
                                "outputTokens": 5,
                                "cacheReadTokens": 0,
                                "cacheWriteTokens": 0,
                                "reasoningTokens": 1,
                            },
                        }
                    },
                },
            },
        ]
    )
    + "\n",
    encoding="utf-8",
)
truncated_stdout = tmpdir / "truncated.stdout"
truncated_stdout.write_text("BUR\n", encoding="utf-8")
replacement_identity = runner.response_marker_identity(
    expected_marker=expected_marker,
    stdout_path=truncated_stdout,
    session_log_path=marker_session_log,
    session_detection={"status": "bound_candidate"},
)
if replacement_identity["status"] != "bound_session_final_message_exact_marker":
    raise SystemExit("expected bound-session marker replacement proof")
if replacement_identity["stdout_prefix_only_observed"] is not True:
    raise SystemExit("expected stdout prefix-only diagnostic")
missing_identity = runner.response_marker_identity(
    expected_marker=expected_marker,
    stdout_path=truncated_stdout,
    session_log_path=marker_session_log,
    session_detection={"status": "binding_failed"},
)
if missing_identity["replacement_identity_proof_available"] is not False:
    raise SystemExit("replacement marker proof must require a bound session")
nonterminal_marker_log = tmpdir / "nonterminal-marker.events.jsonl"
nonterminal_marker_log.write_text(
    "\n".join(
        json.dumps(row, sort_keys=True)
        for row in [
            {
                "type": "assistant.message",
                "data": {"content": expected_marker},
            },
            {
                "type": "assistant.message",
                "data": {"content": "A later final response without the marker."},
            },
        ]
    )
    + "\n",
    encoding="utf-8",
)
nonterminal_identity = runner.response_marker_identity(
    expected_marker=expected_marker,
    stdout_path=truncated_stdout,
    session_log_path=nonterminal_marker_log,
    session_detection={"status": "bound_candidate"},
)
if nonterminal_identity["replacement_identity_proof_available"] is not False:
    raise SystemExit("non-terminal assistant marker must not satisfy replacement proof")
tool_request_only_log = tmpdir / "tool-request-only-marker.events.jsonl"
tool_request_only_log.write_text(
    "\n".join(
        json.dumps(row, sort_keys=True)
        for row in [
            {
                "type": "assistant.message",
                "data": {"content": expected_marker},
            },
            {
                "type": "assistant.message",
                "data": {
                    "content": "I need a tool before this is final.",
                    "toolRequests": [
                        {"name": "view", "arguments": {"path": "HANDOFF.md"}},
                    ],
                },
            },
        ]
    )
    + "\n",
    encoding="utf-8",
)
tool_request_only_identity = runner.response_marker_identity(
    expected_marker=expected_marker,
    stdout_path=truncated_stdout,
    session_log_path=tool_request_only_log,
    session_detection={"status": "bound_candidate"},
)
if tool_request_only_identity["replacement_identity_proof_available"] is not False:
    raise SystemExit("tool-request assistant message must clear prior marker proof")
metadata_marker_log = tmpdir / "metadata-marker.events.jsonl"
metadata_marker_log.write_text(
    json.dumps(
        {
            "type": "assistant.message",
            "data": {
                "content": "Visible response without the marker.",
                "toolRequests": [
                    {
                        "arguments": {"note": expected_marker},
                    }
                ],
            },
        },
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)
metadata_identity = runner.response_marker_identity(
    expected_marker=expected_marker,
    stdout_path=truncated_stdout,
    session_log_path=metadata_marker_log,
    session_detection={"status": "bound_candidate"},
)
if metadata_identity["replacement_identity_proof_available"] is not False:
    raise SystemExit("assistant metadata marker must not satisfy replacement proof")

runner.append_metrics_row(
    args,
    started_at_utc="2026-05-19T00:00:00Z",
    ended_at_utc="2026-05-19T00:00:02Z",
    start_epoch=1.0,
    end_epoch=2.0,
    returncode=0,
    session_log_path=aggregate_log,
    session_detection={"status": "bound_candidate"},
    effective_prompt_path=rendered,
    token_usage=aggregate_usage,
    command_argv=["copilot", "--model", "gpt-5.5", "-p", "full prompt text"],
    telemetry_provenance={
        "schema_version": 1,
        "invocation_id": "fixture-marker",
        "invocation_marker": marker,
        "pre_launch_marker_scan": {"match_count": 0, "clean": True},
        "post_launch_session_candidate_count": 1,
        "post_launch_bound_candidate_count": 1,
        "exactly_one_post_launch_bound_session_candidate": True,
        "child_process": {
            "pid": 12345,
            "pgid": 12345,
            "started_at_utc": "2026-05-19T00:00:00Z",
            "ended_at_utc": "2026-05-19T00:00:02Z",
            "returncode": 0,
        },
        "source_session_log_sha256": runner.sha256_file(aggregate_log),
        "copied_session_log_sha256": runner.sha256_file(aggregate_log),
        "copied_session_hash_matches_source": True,
        "stdout_stderr_log_sha256": runner.sha256_file(log_path),
        "prompt_snapshot_sha256": runner.sha256_file(rendered),
    },
)
metrics_rows = [
    json.loads(raw)
    for raw in Path(args.metrics_out).read_text(encoding="utf-8").splitlines()
    if raw.strip()
]
if len(metrics_rows) != 1:
    raise SystemExit("expected one metrics row")
metrics = metrics_rows[0]
for field in (
    "route_id",
    "route_command_argv",
    "rendered_prompt_sha256",
    "frozen_pre_render_input_manifest_sha256",
    "quality_gate_state",
    "direct_fields_complete",
    "provider_token_rows",
    "provider_token_telemetry",
    "route_topology_lock",
):
    if field not in metrics:
        raise SystemExit(f"missing metrics field: {field}")
if metrics["provider_token_telemetry"]["request_level_rows_available"] is not False:
    raise SystemExit("expected aggregate-only fixture to report no request-level rows")
if metrics["provider_token_telemetry"]["equivalent_route_topology_lock_available"] is not True:
    raise SystemExit("expected aggregate-only fixture to report route-lock fallback")
if metrics["provider_token_telemetry"]["evidence_policy"]["status"] != "equivalent_route_topology_lock_with_session_shutdown_model_aggregate":
    raise SystemExit("expected aggregate-equivalent evidence policy in metrics row")
if metrics["response_marker_identity"]["status"] != "not_requested":
    raise SystemExit("expected marker identity to be optional by default")
provenance = metrics.get("telemetry_provenance")
if not isinstance(provenance, dict):
    raise SystemExit("expected telemetry provenance block")
if provenance.get("child_process", {}).get("pid") != 12345:
    raise SystemExit("expected child process pid provenance")
if provenance.get("exactly_one_post_launch_bound_session_candidate") is not True:
    raise SystemExit("expected exactly-one post-launch session provenance")
if provenance.get("copied_session_hash_matches_source") is not True:
    raise SystemExit("expected copied session hash match provenance")

fake_state = tmpdir / "fake-session-state"
fake_copilot = tmpdir / "fake-copilot.py"
fake_copilot.write_text(
    f'''#!/usr/bin/env python3
import json
import os
import sys
import time
from pathlib import Path

args = sys.argv[1:]
model = args[args.index("--model") + 1]
agent = args[args.index("--agent") + 1] if "--agent" in args else ""
prompt = args[args.index("-p") + 1]
session_dir = Path({json.dumps(str(fake_state))}) / "fake-session"
session_dir.mkdir(parents=True, exist_ok=True)
events = session_dir / "events.jsonl"
rows = [
    {{
        "type": "session.start",
        "data": {{
            "selectedModel": model,
            "context": {{"cwd": os.getcwd(), "gitRoot": os.getcwd()}},
            "prompt": prompt,
        }},
    }},
    {{"type": "subagent.selected", "data": {{"agentName": agent}}}},
    {{"type": "tool.execution_start", "data": {{"tool": "read/readFile"}}}},
    {{
        "type": "session.shutdown",
        "data": {{
            "currentModel": model,
            "totalPremiumRequests": 2,
            "modelMetrics": {{
                model: {{
                    "requests": {{"count": 2}},
                    "usage": {{
                        "inputTokens": 500,
                        "outputTokens": 50,
                        "cacheReadTokens": 20,
                        "cacheWriteTokens": 0,
                        "reasoningTokens": 6,
                    }},
                }}
            }},
        }},
    }},
]
events.write_text("\\n".join(json.dumps(row, sort_keys=True) for row in rows) + "\\n", encoding="utf-8")
now = time.time()
os.utime(events, (now, now))
print("BURST136_FAKE_COPILOT_OK")
''',
    encoding="utf-8",
)
fake_copilot.chmod(0o755)
fake_prompt = tmpdir / "fake-run.prompt.md"
fake_marker = "BURST136_FAKE_COPILOT_OK"
fake_prompt.write_text(f"Read two fixed files and return {fake_marker}.\n", encoding="utf-8")
fake_metrics = tmpdir / "fake-run-metrics.jsonl"
fake_args = SimpleNamespace(
    agent="customer_newsletter",
    artifact_path=["tools/run_copilot_phase.py"],
    available_tool=["read/readFile"],
    copilot_bin=str(fake_copilot),
    cwd=str(root),
    excluded_tool=[],
    enable_reasoning_summaries=False,
    expected_response_marker=fake_marker,
    metrics_out=str(fake_metrics),
    model="gpt-5.5",
    phase_id="burst136_fake_no_candidate_smoke",
    prompt_file=str(fake_prompt),
    reasoning_effort=None,
    receipt_id=["burst136_fake_no_candidate_smoke"],
    require_session_log=True,
    require_direct_token_fields=True,
    log=str(tmpdir / "fake-run.log"),
    stdout_out=str(tmpdir / "fake-run.stdout"),
    timeout=30,
    use_copilot_cwd_flag=False,
    silent=False,
    output_format=None,
    log_level=None,
    log_dir=None,
    name=None,
    session_state_base=str(fake_state),
    session_out=str(tmpdir / "fake-run-events.jsonl"),
)
fake_rc = runner.run_phase(fake_args)
if fake_rc != 0:
    raise SystemExit(f"expected fake Copilot run to pass, got {fake_rc}")
fake_run_metrics = [
    json.loads(raw)
    for raw in fake_metrics.read_text(encoding="utf-8").splitlines()
    if raw.strip()
][0]
fake_provenance = fake_run_metrics["telemetry_provenance"]
if not isinstance(fake_provenance.get("child_process", {}).get("pid"), int):
    raise SystemExit("expected run_phase to record child process pid")
if fake_provenance.get("pre_launch_marker_scan", {}).get("clean") is not True:
    raise SystemExit("expected clean pre-launch marker scan")
if fake_provenance.get("exactly_one_post_launch_bound_session_candidate") is not True:
    raise SystemExit("expected one post-launch bound session candidate")
if fake_provenance.get("copied_session_hash_matches_source") is not True:
    raise SystemExit("expected copied session hash to match source")
if fake_run_metrics["request_count"] != 2 or fake_run_metrics["tool_calls"] != 1:
    raise SystemExit("expected fake run to prove non-degenerate observability fields")
if fake_run_metrics["response_marker_identity"]["status"] != "stdout_exact_marker":
    raise SystemExit("expected fake run stdout marker identity proof")

auto_stdout_metrics = tmpdir / "auto-stdout-run-metrics.jsonl"
auto_stdout_args = SimpleNamespace(**{**fake_args.__dict__})
auto_stdout_args.metrics_out = str(auto_stdout_metrics)
auto_stdout_args.log = str(tmpdir / "auto-stdout-run.log")
auto_stdout_args.stdout_out = None
auto_stdout_args.session_out = str(tmpdir / "auto-stdout-run-events.jsonl")
auto_stdout_rc = runner.run_phase(auto_stdout_args)
if auto_stdout_rc != 0:
    raise SystemExit(f"expected auto stdout fake Copilot run to pass, got {auto_stdout_rc}")
if not auto_stdout_args.stdout_out or not Path(auto_stdout_args.stdout_out).exists():
    raise SystemExit("expected expected-response-marker runs to auto-retain stdout")
auto_stdout_row = [
    json.loads(raw)
    for raw in auto_stdout_metrics.read_text(encoding="utf-8").splitlines()
    if raw.strip()
][0]
if auto_stdout_row["response_marker_identity"]["status"] != "stdout_exact_marker":
    raise SystemExit("expected auto-retained stdout marker identity proof")

stale_state = tmpdir / "stale-session-state"
stale_session = stale_state / "stale"
stale_session.mkdir(parents=True)
stale_marker = f"{runner.INVOCATION_MARKER_PREFIX} stale-marker"
(stale_session / "events.jsonl").write_text(stale_marker + "\n", encoding="utf-8")
stale_metrics = tmpdir / "stale-run-metrics.jsonl"
stale_args = SimpleNamespace(**{**fake_args.__dict__})
stale_args.session_state_base = str(stale_state)
stale_args.metrics_out = str(stale_metrics)
stale_args.log = str(tmpdir / "stale-run.log")
stale_args.stdout_out = str(tmpdir / "stale-run.stdout")
stale_args.session_out = str(tmpdir / "stale-run-events.jsonl")
Path(stale_args.stdout_out).write_text(fake_marker + "\n", encoding="utf-8")
original_uuid4 = runner.uuid.uuid4
try:
    runner.uuid.uuid4 = lambda: SimpleNamespace(hex="stale-marker")
    stale_rc = runner.run_phase(stale_args)
finally:
    runner.uuid.uuid4 = original_uuid4
if stale_rc != 2:
    raise SystemExit(f"expected preexisting marker to fail closed with 2, got {stale_rc}")
stale_row = [
    json.loads(raw)
    for raw in stale_metrics.read_text(encoding="utf-8").splitlines()
    if raw.strip()
][0]
if stale_row["session_log_detection"]["status"] != "preexisting_invocation_marker":
    raise SystemExit("expected stale marker status in metrics row")
if stale_row["telemetry_provenance"]["child_process"]["pid"] is not None:
    raise SystemExit("expected preexisting marker failure before child launch")
if stale_row["response_marker_identity"]["status"] == "stdout_exact_marker":
    raise SystemExit("pre-launch failure must not reuse stale stdout marker proof")

print("phase route-lock telemetry fixture assertions passed")
PY

#!/usr/bin/env python3
"""Shared helpers for newsletter cost-optimization experiment surfaces."""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parent.parent
OPTIONAL_ARTIFACT_NAMES = {
    "curator_processed",
    "curator_signals",
    "phase2_selected_source_ids",
    "phase2_fetch_attempt_ledger",
    "phase2_no_refetch_compliance",
    "editorial_corrections",
}
PRODUCTION_ARTIFACT_NAMES = {
    "phase45_polishing",
    "phase46_video_report",
    "editorial_review",
}
SOURCE_PRUNING_ARTIFACT_NAMES = {
    "source_pruning_context",
    "source_pruning_receipt",
}
OUTPUT_SHAPE_ARTIFACT_NAMES = {
    "output_shape_context",
    "output_shape_receipt",
}
COPILOT_TOKEN_RE = re.compile(
    r"Tokens\s+↑\s*(?P<input>[0-9.]+[kKmM]?)\s*•\s*↓\s*(?P<output>[0-9.]+[kKmM]?)\s*•\s*"
    r"(?P<cached>[0-9.]+[kKmM]?)\s+\(cached\)\s*•\s*(?P<reasoning>[0-9.]+[kKmM]?)\s+\(reasoning\)"
)
REQUESTS_RE = re.compile(r"(?P<count>\d+(?:\.\d+)?)\s+Premium requests?", re.IGNORECASE)
WARNINGS_RE = re.compile(r"Warnings:\s*`?(?P<count>\d+)`?", re.IGNORECASE)
WARNINGS_INLINE_RE = re.compile(r"(?P<count>\d+)\s+warnings?", re.IGNORECASE)
WARNING_LINE_RE = re.compile(r"^(?:[-*]\s*)?(?:WARN|WARNING):\s*(?P<message>.+)$", re.IGNORECASE)
RUBRIC_RE = re.compile(r"TOTAL:\s*(?P<score>\d+)/50")
RUBRIC_INLINE_RE = re.compile(r"(?P<score>\d+)/50")
DIRECT_PROVIDER_TOKEN_FIELDS = {
    "inputTokens": "input_tokens",
    "outputTokens": "output_tokens",
    "cacheReadTokens": "cache_read_tokens",
    "cacheWriteTokens": "cache_write_tokens",
    "reasoningTokens": "reasoning_tokens",
}


def repo_root() -> Path:
    return REPO_ROOT


def load_json(path: Path) -> Any | None:
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def load_text(path: Path) -> str | None:
    if not path.exists():
        return None
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return None


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=False) + "\n", encoding="utf-8")


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n", encoding="utf-8")


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def sha256_path(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalize_for_stable_hash(value: Any, run_id: str | None = None) -> Any:
    if isinstance(value, dict):
        return {
            key: normalize_for_stable_hash(item, run_id)
            for key, item in value.items()
            if key != "generated_at_utc"
        }
    if isinstance(value, list):
        return [normalize_for_stable_hash(item, run_id) for item in value]
    if isinstance(value, str):
        repo = str(REPO_ROOT)
        if value.startswith(repo):
            return "<repo>" + value[len(repo):]
        for marker in ("/runs/product_runs/", "/planning/", "/config/", "/data/pricing/"):
            idx = value.find(marker)
            if idx >= 0:
                return "<repo>" + value[idx:]
        if run_id and value.startswith("/"):
            marker = "/" + run_id
            idx = value.find(marker)
            if idx >= 0:
                return "<repo>/runs/product_runs/" + run_id + value[idx + len(marker):]
        if value.startswith("/"):
            return "<abs-path>/" + Path(value).name
    return value


def stable_scorecard_sha256(payload: dict[str, Any]) -> str:
    run_id = payload.get("run_id")
    normalized = normalize_for_stable_hash(payload, str(run_id) if run_id else None)
    text = json.dumps(normalized, sort_keys=True, separators=(",", ":"))
    return sha256_text(text)


def optional_artifact_names_for_audit(audit: dict[str, Any]) -> set[str]:
    optional = set(OPTIONAL_ARTIFACT_NAMES)
    optional.update(SOURCE_PRUNING_ARTIFACT_NAMES)
    optional.update(OUTPUT_SHAPE_ARTIFACT_NAMES)
    validators = audit.get("validators")
    strict = validators.get("strict") if isinstance(validators, dict) else {}
    cmd = strict.get("cmd") if isinstance(strict, dict) else []
    production_artifacts_required = (
        isinstance(cmd, list) and "--production-artifacts" in [str(part) for part in cmd]
    )
    if not production_artifacts_required:
        optional.update(PRODUCTION_ARTIFACT_NAMES)
    return optional


def current_run_artifact_path(run_dir: Path, artifact: dict[str, Any]) -> Path | None:
    logical_path = artifact.get("logical_path")
    if logical_path:
        candidate = run_dir / "artifacts" / str(logical_path)
        if candidate.exists():
            return candidate
    resolved_path = artifact.get("resolved_path")
    if resolved_path:
        candidate = Path(str(resolved_path))
        if candidate.exists():
            return candidate
    return None


def normalize_model_name(model: str | None) -> str:
    raw = str(model or "").strip().lower()
    if not raw:
        return "unknown"
    if raw.startswith("copilot/"):
        raw = raw.split("/", 1)[1]
    return raw.replace("-1m", "").replace(" ", "-")


def model_family(model: str | None) -> str:
    normalized = normalize_model_name(model)
    if normalized.startswith("gpt-"):
        return "openai"
    if normalized.startswith("claude-"):
        return "anthropic"
    return "unknown"


def discover_pricing_snapshot(explicit_path: str | None = None) -> Path | None:
    if explicit_path:
        path = Path(explicit_path).expanduser().resolve()
        return path if path.exists() else None

    local_candidates = sorted((REPO_ROOT / "config" / "pricing").glob("newsletter-model-pricing-*.json"))
    if local_candidates:
        return local_candidates[-1]

    return None


def pricing_index(snapshot: dict[str, Any]) -> dict[str, dict[str, Any]]:
    index: dict[str, dict[str, Any]] = {}
    for entry in snapshot.get("models", []):
        normalized = normalize_model_name(entry.get("model"))
        index[normalized] = entry
        for alias in entry.get("aliases", []):
            index[normalize_model_name(alias)] = entry
    return index


def human_number(raw: str) -> int:
    text = raw.strip().lower()
    multiplier = 1
    if text.endswith("k"):
        multiplier = 1_000
        text = text[:-1]
    elif text.endswith("m"):
        multiplier = 1_000_000
        text = text[:-1]
    return int(float(text) * multiplier)


def parse_copilot_log_tokens(log_path: Path) -> dict[str, Any] | None:
    text = load_text(log_path)
    if not text:
        return None
    match = None
    for line in text.splitlines():
        probe = COPILOT_TOKEN_RE.search(line)
        if probe:
            match = probe
    if not match:
        return None
    request_count = None
    for line in text.splitlines():
        probe = REQUESTS_RE.search(line)
        if probe:
            request_count = int(float(probe.group("count")))
    return {
        "source": "copilot.log",
        "input_tokens": human_number(match.group("input")),
        "output_tokens": human_number(match.group("output")),
        "cache_read_tokens": human_number(match.group("cached")),
        "cache_write_tokens": 0,
        "cached_tokens_total": human_number(match.group("cached")),
        "reasoning_tokens": human_number(match.group("reasoning")),
        "request_count": request_count,
    }


def parse_iso(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def parse_session_metrics(session_log_path: Path) -> dict[str, Any] | None:
    if not session_log_path.exists():
        return None
    shutdown_payload = None
    total_events = 0
    tool_calls = 0
    for raw_line in session_log_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw_line.strip()
        if not line:
            continue
        total_events += 1
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        if payload.get("type") == "tool.execution_start":
            tool_calls += 1
        if payload.get("type") == "session.shutdown":
            shutdown_payload = payload.get("data", {})
    if not isinstance(shutdown_payload, dict):
        return None

    model_metrics = shutdown_payload.get("modelMetrics", {})
    if not isinstance(model_metrics, dict) or not model_metrics:
        return {
            "source": "session.shutdown",
            "primary_model": shutdown_payload.get("currentModel"),
            "tool_calls": tool_calls,
            "total_events": total_events,
            "total_premium_requests": shutdown_payload.get("totalPremiumRequests"),
            "total_api_duration_ms": shutdown_payload.get("totalApiDurationMs"),
            "model_breakdown": {},
            "model_direct_provider_token_fields": {},
            "requested_models": [],
            "direct_provider_token_fields_present": [],
            "missing_direct_provider_token_fields": list(DIRECT_PROVIDER_TOKEN_FIELDS),
        }

    model_breakdown: dict[str, Any] = {}
    requested_model_field_sets: list[set[str]] = []
    requested_models: list[str] = []
    total_input = 0
    total_output = 0
    total_cache_read = 0
    total_cache_write = 0
    total_reasoning = 0
    total_requests = 0

    for raw_model, payload in model_metrics.items():
        requests = payload.get("requests", {}) if isinstance(payload, dict) else {}
        usage = payload.get("usage", {}) if isinstance(payload, dict) else {}
        if not isinstance(requests, dict):
            requests = {}
        if not isinstance(usage, dict):
            usage = {}
        request_count = int(requests.get("count", 0) or 0)
        model_fields_present = [
            field for field in DIRECT_PROVIDER_TOKEN_FIELDS if field in usage
        ]
        model_fields_missing = [
            field for field in DIRECT_PROVIDER_TOKEN_FIELDS if field not in usage
        ]
        requested_models.append(raw_model)
        if request_count > 0:
            requested_model_field_sets.append(set(model_fields_present))
        row = {
            "model": raw_model,
            "request_count": request_count,
            "input_tokens": int(usage.get("inputTokens", 0) or 0),
            "output_tokens": int(usage.get("outputTokens", 0) or 0),
            "cache_read_tokens": int(usage.get("cacheReadTokens", 0) or 0),
            "cache_write_tokens": int(usage.get("cacheWriteTokens", 0) or 0),
            "reasoning_tokens": int(usage.get("reasoningTokens", 0) or 0),
            "direct_provider_token_fields_present": model_fields_present,
            "missing_direct_provider_token_fields": model_fields_missing,
        }
        row["cached_tokens_total"] = row["cache_read_tokens"] + row["cache_write_tokens"]
        model_breakdown[raw_model] = row
        total_input += row["input_tokens"]
        total_output += row["output_tokens"]
        total_cache_read += row["cache_read_tokens"]
        total_cache_write += row["cache_write_tokens"]
        total_reasoning += row["reasoning_tokens"]
        total_requests += request_count

    run_level_present = (
        set.intersection(*requested_model_field_sets)
        if requested_model_field_sets
        else set()
    )
    primary_model = str(shutdown_payload.get("currentModel") or next(iter(model_metrics.keys())))
    return {
        "source": "session.shutdown.modelMetrics",
        "primary_model": primary_model,
        "tool_calls": tool_calls,
        "total_events": total_events,
        "total_premium_requests": int(shutdown_payload.get("totalPremiumRequests", 0) or 0),
        "total_api_duration_ms": int(shutdown_payload.get("totalApiDurationMs", 0) or 0),
        "model_breakdown": model_breakdown,
        "model_direct_provider_token_fields": {
            model: {
                "request_count": row.get("request_count", 0),
                "direct_provider_token_fields_present": row.get(
                    "direct_provider_token_fields_present", []
                ),
                "missing_direct_provider_token_fields": row.get(
                    "missing_direct_provider_token_fields", []
                ),
            }
            for model, row in model_breakdown.items()
        },
        "requested_models": requested_models,
        "input_tokens": total_input,
        "output_tokens": total_output,
        "cache_read_tokens": total_cache_read,
        "cache_write_tokens": total_cache_write,
        "cached_tokens_total": total_cache_read + total_cache_write,
        "reasoning_tokens": total_reasoning,
        "request_count": total_requests,
        "direct_provider_token_fields_present": [
            field for field in DIRECT_PROVIDER_TOKEN_FIELDS if field in run_level_present
        ],
        "missing_direct_provider_token_fields": [
            field for field in DIRECT_PROVIDER_TOKEN_FIELDS if field not in run_level_present
        ],
    }


def estimate_costs(
    token_summary: dict[str, Any],
    price_snapshot: dict[str, Any] | None,
) -> dict[str, Any]:
    if not price_snapshot:
        return {
            "pricing_snapshot_path": None,
            "method": "unpriced",
            "total_usd": None,
            "priced_models": [],
            "unpriced_models": list(token_summary.get("model_breakdown", {}).keys()),
            "model_breakdown": [],
        }
    price_index = pricing_index(price_snapshot)
    breakdown = []
    total_cost = 0.0
    priced_models: list[str] = []
    unpriced_models: list[str] = []

    model_rows = token_summary.get("model_breakdown", {})
    if not model_rows:
        primary_model = token_summary.get("primary_model")
        if primary_model:
            model_rows = {
                primary_model: {
                    "model": primary_model,
                    "request_count": token_summary.get("request_count"),
                    "input_tokens": token_summary.get("input_tokens", 0),
                    "output_tokens": token_summary.get("output_tokens", 0),
                    "cache_read_tokens": token_summary.get("cache_read_tokens", 0),
                    "cache_write_tokens": token_summary.get("cache_write_tokens", 0),
                    "reasoning_tokens": token_summary.get("reasoning_tokens", 0),
                    "cached_tokens_total": token_summary.get("cached_tokens_total", 0),
                }
            }

    for raw_model, row in model_rows.items():
        entry = price_index.get(normalize_model_name(raw_model))
        if not entry:
            unpriced_models.append(raw_model)
            breakdown.append(
                {
                    "model": raw_model,
                    "family": model_family(raw_model),
                    "estimated_cost_usd": None,
                    "pricing_available": False,
                    "input_tokens": row.get("input_tokens", 0),
                    "output_tokens": row.get("output_tokens", 0),
                    "cache_read_tokens": row.get("cache_read_tokens", 0),
                    "cache_write_tokens": row.get("cache_write_tokens", 0),
                    "reasoning_tokens": row.get("reasoning_tokens", 0),
                    "request_count": row.get("request_count", 0),
                    "direct_provider_token_fields_present": row.get(
                        "direct_provider_token_fields_present", []
                    ),
                    "missing_direct_provider_token_fields": row.get(
                        "missing_direct_provider_token_fields", []
                    ),
                }
            )
            continue

        cache_price = entry.get("cache_price", {})
        if isinstance(cache_price, dict):
            cache_read_price = float(cache_price.get("read", 0) or 0)
            cache_write_price = float(cache_price.get("write", cache_price.get("write_5m", 0)) or 0)
        else:
            cache_read_price = float(cache_price or 0)
            cache_write_price = float(cache_price or 0)
        output_price = float(entry.get("output_price", 0) or 0)
        reasoning_price = float(entry.get("reasoning_price", output_price) or output_price)

        estimated = (
            (float(row.get("input_tokens", 0) or 0) / 1_000_000) * float(entry.get("input_price", 0) or 0)
            + (float(row.get("output_tokens", 0) or 0) / 1_000_000) * output_price
            + (float(row.get("cache_read_tokens", 0) or 0) / 1_000_000) * cache_read_price
            + (float(row.get("cache_write_tokens", 0) or 0) / 1_000_000) * cache_write_price
            + (float(row.get("reasoning_tokens", 0) or 0) / 1_000_000) * reasoning_price
        )
        estimated = round(estimated, 4)
        total_cost += estimated
        priced_models.append(raw_model)
        breakdown.append(
            {
                "model": raw_model,
                "family": model_family(raw_model),
                "estimated_cost_usd": estimated,
                "pricing_available": True,
                "input_tokens": row.get("input_tokens", 0),
                "output_tokens": row.get("output_tokens", 0),
                "cache_read_tokens": row.get("cache_read_tokens", 0),
                "cache_write_tokens": row.get("cache_write_tokens", 0),
                "reasoning_tokens": row.get("reasoning_tokens", 0),
                "request_count": row.get("request_count", 0),
                "direct_provider_token_fields_present": row.get(
                    "direct_provider_token_fields_present", []
                ),
                "missing_direct_provider_token_fields": row.get(
                    "missing_direct_provider_token_fields", []
                ),
            }
        )

    return {
        "pricing_snapshot_path": str(discover_pricing_snapshot()) if price_snapshot else None,
        "method": "direct_token_estimate",
        "total_usd": round(total_cost, 4) if breakdown and priced_models else None,
        "priced_models": priced_models,
        "unpriced_models": unpriced_models,
        "model_breakdown": breakdown,
    }


def parse_warning_count(text: str | None) -> int | None:
    if not text:
        return None
    for pattern in (WARNINGS_RE, WARNINGS_INLINE_RE):
        match = pattern.search(text)
        if match:
            return int(match.group("count"))
    return None


def warning_messages(text: str | None) -> list[str]:
    if not text:
        return []
    messages: list[str] = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        match = WARNING_LINE_RE.match(line)
        if match:
            messages.append(match.group("message").strip())
    return messages


def classify_warning_message(message: str, source: str) -> str:
    normalized = message.lower()
    if "phase 1c discoveries" in normalized and "vs code version signal" in normalized:
        return "vscode-version-signal-retention"
    if "final output" in normalized and "vs code version signal" in normalized:
        return "vscode-version-output-reference"
    if "expected_versions.vscode" in normalized:
        return "vscode-version-baseline-low"
    if "no in-person events" in normalized:
        return "event-coverage-in-person-missing"
    if "github resources/goldcast" in normalized:
        return "event-coverage-github-resources-goldcast-missing"
    if "phase continuity ratio skipped" in normalized:
        return "phase-continuity-ratio-unavailable"
    if "legacy receipt ordering fallback" in normalized:
        return "receipt-order-fallback"
    return f"{source}-validator-warning"


def build_warning_taxonomy(
    strict_text: str | None,
    newsletter_text: str | None,
    strict_warning_count: int | None,
    newsletter_warning_count: int | None,
) -> dict[str, Any]:
    entries: list[dict[str, str]] = []
    classes: set[str] = set()

    for source, text, count in (
        ("strict", strict_text, strict_warning_count),
        ("newsletter", newsletter_text, newsletter_warning_count),
    ):
        messages = warning_messages(text)
        for message in messages:
            warning_class = classify_warning_message(message, source)
            classes.add(warning_class)
            entries.append(
                {
                    "source": source,
                    "class": warning_class,
                    "message": message,
                }
            )
        if count and count > 0 and not messages:
            warning_class = f"{source}-validator-warning"
            classes.add(warning_class)
            entries.append(
                {
                    "source": source,
                    "class": warning_class,
                    "message": "Validator emitted a non-zero warning count without parseable warning lines.",
                }
            )

    total_count = int(strict_warning_count or 0) + int(newsletter_warning_count or 0)
    return {
        "present": total_count == 0 or bool(entries),
        "classes": sorted(classes),
        "entries": entries,
    }


def parse_rubric_score(text: str | None) -> int | None:
    if not text:
        return None
    for pattern in (RUBRIC_RE, RUBRIC_INLINE_RE):
        match = pattern.search(text)
        if match:
            return int(match.group("score"))
    return None


def render_prompt_snapshot(
    start: str,
    end: str,
    mode: str,
    source_pruning_policy_path: str | None = None,
    output_shape_policy_path: str | None = None,
) -> dict[str, Any]:
    cmd = ["bash", "tools/render_product_run_prompt.sh", start, end, mode]
    if source_pruning_policy_path:
        cmd.extend(["--source-pruning-policy", source_pruning_policy_path])
    if output_shape_policy_path:
        cmd.extend(["--output-shape-policy", output_shape_policy_path])
    completed = subprocess.run(
        cmd,
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if completed.returncode != 0:
        return {"prompt_text": None, "prompt_sha256": None, "prompt_source": "render_failed"}
    prompt_text = completed.stdout
    return {
        "prompt_text": prompt_text,
        "prompt_sha256": sha256_text(prompt_text),
        "prompt_source": "reconstructed_current_renderer",
    }


def infer_prompt_metadata(run_dir: Path, metadata: dict[str, Any]) -> dict[str, Any]:
    prompt_path = run_dir / "prompt.txt"
    if prompt_path.exists():
        prompt_text = prompt_path.read_text(encoding="utf-8")
        return {
            "prompt_sha256": sha256_text(prompt_text),
            "prompt_source": "prompt_snapshot",
            "prompt_path": str(prompt_path),
        }
    if metadata.get("prompt_sha256"):
        return {
            "prompt_sha256": metadata.get("prompt_sha256"),
            "prompt_source": metadata.get("prompt_source", "run_metadata"),
            "prompt_path": metadata.get("prompt_path"),
        }
    if metadata.get("start") and metadata.get("end") and metadata.get("mode"):
        return render_prompt_snapshot(
            str(metadata["start"]),
            str(metadata["end"]),
            str(metadata["mode"]),
            str(metadata.get("source_pruning_policy_path") or "") or None,
            str(metadata.get("output_shape_policy_path") or "") or None,
        )
    return {"prompt_sha256": None, "prompt_source": "unavailable", "prompt_path": None}


def prompt_equality_check(prompt_meta: dict[str, Any], metadata: dict[str, Any]) -> dict[str, Any]:
    prompt_source = prompt_meta.get("prompt_source")
    retained_sha = (
        prompt_meta.get("prompt_sha256")
        if prompt_source != "reconstructed_current_renderer"
        else None
    )
    result = {
        "available": False,
        "comparison_method": "prompt_snapshot_sha256_vs_current_renderer_sha256",
        "retained_prompt_sha256": retained_sha,
        "current_renderer_sha256": None,
        "matches_current_renderer": None,
        "reason": None,
    }
    if not (metadata.get("start") and metadata.get("end") and metadata.get("mode")):
        result["reason"] = "Missing start, end, or mode metadata required to render comparison prompt."
        return result

    rendered = render_prompt_snapshot(
        str(metadata["start"]),
        str(metadata["end"]),
        str(metadata["mode"]),
        str(metadata.get("source_pruning_policy_path") or "") or None,
        str(metadata.get("output_shape_policy_path") or "") or None,
    )
    current_sha = rendered.get("prompt_sha256")
    result["current_renderer_sha256"] = current_sha
    if prompt_source == "reconstructed_current_renderer":
        result["reason"] = (
            "No retained prompt snapshot or persisted prompt hash exists; "
            "the current renderer was reconstructed and cannot prove equality."
        )
        return result
    if not retained_sha or not current_sha:
        result["reason"] = "Missing retained or rendered prompt hash."
        return result

    result["available"] = True
    result["matches_current_renderer"] = retained_sha == current_sha
    if retained_sha != current_sha:
        result["reason"] = "Retained prompt snapshot differs from the current renderer output."
    return result


def infer_fixture_pack_id(run_dir: Path, metadata: dict[str, Any]) -> str | None:
    explicit = str(metadata.get("fixture_pack") or "").strip()
    if explicit:
        return explicit
    fixture_root = REPO_ROOT / "config" / "experiment_fixture_packs"
    for path in sorted(fixture_root.glob("*.json")):
        payload = load_json(path)
        if not isinstance(payload, dict):
            continue
        if str(payload.get("run_id") or "") == run_dir.name:
            return str(payload.get("manifest_id") or "").strip() or None
    return None


def extract_model_from_command(command: str | None) -> str | None:
    if not command:
        return None
    parts = command.split()
    for idx, part in enumerate(parts[:-1]):
        if part == "--model":
            return parts[idx + 1]
    return None


def scorecard_from_run(
    run_dir: Path,
    pricing_snapshot_path: str | None = None,
) -> dict[str, Any]:
    run_dir = run_dir.resolve()
    metadata = load_json(run_dir / "run-metadata.json") or {}
    run_result = load_json(run_dir / "run-result.json") or {}
    audit = load_json(run_dir / "audit" / "RUN_AUDIT.json") or {}
    if not metadata:
        raise SystemExit(f"Missing run-metadata.json in {run_dir}")
    if not audit:
        raise SystemExit(f"Missing audit/RUN_AUDIT.json in {run_dir}")

    prompt_meta = infer_prompt_metadata(run_dir, metadata)
    session_log_path = run_dir / "session" / "events.jsonl"
    session_metrics = parse_session_metrics(session_log_path) or {}
    if not session_metrics.get("model_breakdown"):
        copilot_metrics = parse_copilot_log_tokens(run_dir / "copilot.log") or {}
        if copilot_metrics:
            merged_metrics = dict(session_metrics)
            merged_metrics.update(copilot_metrics)
            if session_metrics.get("primary_model") and not copilot_metrics.get("primary_model"):
                merged_metrics["primary_model"] = session_metrics.get("primary_model")
            if session_metrics.get("tool_calls") is not None:
                merged_metrics["tool_calls"] = session_metrics.get("tool_calls")
            if session_metrics.get("total_events") is not None:
                merged_metrics["total_events"] = session_metrics.get("total_events")
            if session_metrics.get("total_premium_requests") is not None:
                merged_metrics["total_premium_requests"] = session_metrics.get("total_premium_requests")
            if session_metrics.get("total_api_duration_ms") is not None:
                merged_metrics["total_api_duration_ms"] = session_metrics.get("total_api_duration_ms")
            if session_metrics.get("source"):
                merged_metrics["source"] = f"{session_metrics['source']}+{copilot_metrics.get('source', 'copilot.log')}"
            session_metrics = merged_metrics

    primary_model = (
        metadata.get("model")
        or session_metrics.get("primary_model")
        or extract_model_from_command(metadata.get("command"))
        or "unknown"
    )

    started_at = parse_iso(str(metadata.get("started_at_utc") or ""))
    ended_at = parse_iso(str(run_result.get("ended_at_utc") or ""))
    wall_clock_seconds = None
    if started_at and ended_at:
        wall_clock_seconds = int((ended_at - started_at).total_seconds())

    validator_results = audit.get("validators", {})
    strict_text = "\n".join(
        part for part in (
            (validator_results.get("strict") or {}).get("stdout"),
            (validator_results.get("strict") or {}).get("stderr"),
        )
        if part
    )
    newsletter_text = "\n".join(
        part for part in (
            (validator_results.get("newsletter") or {}).get("stdout"),
            (validator_results.get("newsletter") or {}).get("stderr"),
        )
        if part
    )
    rubric_text = "\n".join(
        part for part in (
            (validator_results.get("rubric") or {}).get("stdout"),
            (validator_results.get("rubric") or {}).get("stderr"),
        )
        if part
    )
    strict_warning_count = parse_warning_count(strict_text)
    newsletter_warning_count = parse_warning_count(newsletter_text)
    warning_taxonomy = build_warning_taxonomy(
        strict_text,
        newsletter_text,
        strict_warning_count,
        newsletter_warning_count,
    )

    pricing_path = discover_pricing_snapshot(pricing_snapshot_path)
    pricing_snapshot = load_json(pricing_path) if pricing_path else None
    cost = estimate_costs(session_metrics, pricing_snapshot)
    if pricing_path:
        cost["pricing_snapshot_path"] = str(pricing_path)

    artifacts = audit.get("artifacts", {})
    optional_artifact_names = optional_artifact_names_for_audit(audit)
    if metadata.get("run_class") == "source_pruning_candidate":
        optional_artifact_names.difference_update(SOURCE_PRUNING_ARTIFACT_NAMES)
    if metadata.get("run_class") == "output_shape_candidate":
        optional_artifact_names.difference_update(OUTPUT_SHAPE_ARTIFACT_NAMES)
    receipt_artifact = artifacts.get("receipts", {}) if isinstance(artifacts, dict) else {}
    receipt_file_path = None
    receipt_file_sha256 = None
    if isinstance(receipt_artifact, dict):
        candidate = current_run_artifact_path(run_dir, receipt_artifact)
        if candidate and candidate.exists():
            receipt_file_path = str(candidate)
            receipt_file_sha256 = sha256_path(candidate)
    required_present = []
    required_missing = []
    optional_present = []
    optional_missing = []
    for name, payload in artifacts.items():
        if payload.get("exists"):
            if name in optional_artifact_names:
                optional_present.append(name)
            else:
                required_present.append(name)
        else:
            if name in optional_artifact_names:
                optional_missing.append(name)
            else:
                required_missing.append(name)

    scorecard = {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "run_id": run_dir.name,
        "run_dir": str(run_dir),
        "start": metadata.get("start"),
        "end": metadata.get("end"),
        "mode": metadata.get("mode"),
        "primary_model": primary_model,
        "primary_model_family": model_family(primary_model),
        "command_surface": metadata.get("command_surface", "copilot_cli_single_shot"),
        "experiment": {
            "experiment_id": metadata.get("experiment_id"),
            "run_class": metadata.get("run_class", "ordinary_proof"),
            "fixture_pack": infer_fixture_pack_id(run_dir, metadata),
            "prompt_sha256": prompt_meta.get("prompt_sha256"),
            "prompt_source": prompt_meta.get("prompt_source"),
            "prompt_path": prompt_meta.get("prompt_path"),
            "prompt_renderer_command": metadata.get("prompt_renderer_command"),
            "prompt_equality": prompt_equality_check(prompt_meta, metadata),
            "source_pruning_policy": {
                "enabled": bool(metadata.get("source_pruning_policy_path")),
                "policy_path": metadata.get("source_pruning_policy_path"),
                "policy_sha256": metadata.get("source_pruning_policy_sha256"),
                "policy_id": (
                    Path(str(metadata.get("source_pruning_policy_path"))).stem
                    if metadata.get("source_pruning_policy_path")
                    else None
                ),
            },
            "output_shape_policy": {
                "enabled": bool(metadata.get("output_shape_policy_path")),
                "policy_path": metadata.get("output_shape_policy_path"),
                "policy_sha256": metadata.get("output_shape_policy_sha256"),
                "policy_id": (
                    Path(str(metadata.get("output_shape_policy_path"))).stem
                    if metadata.get("output_shape_policy_path")
                    else None
                ),
            },
        },
        "token_usage": {
            "source": session_metrics.get("source"),
            "primary_model": session_metrics.get("primary_model", primary_model),
            "request_count": session_metrics.get("request_count"),
            "total_premium_requests": session_metrics.get("total_premium_requests"),
            "input_tokens": session_metrics.get("input_tokens"),
            "output_tokens": session_metrics.get("output_tokens"),
            "cache_read_tokens": session_metrics.get("cache_read_tokens"),
            "cache_write_tokens": session_metrics.get("cache_write_tokens"),
            "cached_tokens_total": session_metrics.get("cached_tokens_total"),
            "reasoning_tokens": session_metrics.get("reasoning_tokens"),
            "direct_provider_token_fields_present": session_metrics.get(
                "direct_provider_token_fields_present", []
            ),
            "missing_direct_provider_token_fields": session_metrics.get(
                "missing_direct_provider_token_fields",
                list(DIRECT_PROVIDER_TOKEN_FIELDS),
            ),
            "model_direct_provider_token_fields": session_metrics.get(
                "model_direct_provider_token_fields", {}
            ),
            "requested_models": session_metrics.get("requested_models", []),
            "model_breakdown": cost.get("model_breakdown", []),
        },
        "cost_estimate": cost,
        "timing": {
            "wall_clock_seconds": wall_clock_seconds,
            "total_api_duration_ms": session_metrics.get("total_api_duration_ms"),
            "time_to_first_artifact_seconds": ((audit.get("metrics") or {}).get("time_to_first_artifact_seconds")),
            "time_to_first_receipt_seconds": ((audit.get("metrics") or {}).get("time_to_first_receipt_seconds")),
            "receipt_span_seconds": ((audit.get("metrics") or {}).get("receipt_span_seconds")),
        },
        "quality": {
            "strict_exit_code": (validator_results.get("strict") or {}).get("returncode"),
            "strict_pass": (validator_results.get("strict") or {}).get("returncode") == 0,
            "strict_warning_count": strict_warning_count,
            "newsletter_exit_code": (validator_results.get("newsletter") or {}).get("returncode"),
            "newsletter_pass": (validator_results.get("newsletter") or {}).get("returncode") == 0,
            "newsletter_warning_count": newsletter_warning_count,
            "warning_taxonomy_present": warning_taxonomy["present"],
            "warning_taxonomy_classes": warning_taxonomy["classes"],
            "warning_taxonomy": warning_taxonomy["entries"],
            "rubric_exit_code": (validator_results.get("rubric") or {}).get("returncode"),
            "rubric_score": parse_rubric_score(rubric_text),
            "rubric_pass": (
                parse_rubric_score(rubric_text) is not None and parse_rubric_score(rubric_text) >= 40
            ),
            "rubric_threshold": 40,
        },
        "artifact_completeness": {
            "required_total": len([name for name in artifacts if name not in optional_artifact_names]),
            "required_present": len(required_present),
            "required_missing": required_missing,
            "optional_total": len([name for name in artifacts if name in optional_artifact_names]),
            "optional_present": len(optional_present),
            "optional_missing": optional_missing,
        },
        "phase_receipts": {
            "present": bool((audit.get("receipts") or {}).get("present")),
            "ordered_phase_ids": (audit.get("receipts") or {}).get("ordered_phase_ids", []),
            "comparable_ordered_phase_ids": (audit.get("receipts") or {}).get(
                "comparable_ordered_phase_ids",
                (audit.get("receipts") or {}).get("ordered_phase_ids", []),
            ),
            "phase_spans_seconds": ((audit.get("metrics") or {}).get("phase_spans_seconds", {})),
            "comparable_phase_spans_seconds": (
                (audit.get("metrics") or {}).get(
                    "comparable_phase_spans_seconds",
                    ((audit.get("metrics") or {}).get("phase_spans_seconds", {})),
                )
            ),
            "receipt_span_seconds": ((audit.get("metrics") or {}).get("receipt_span_seconds")),
            "phase_order_normalization": (audit.get("receipts") or {}).get("phase_order_normalization", {}),
            "receipt_file_path": receipt_file_path,
            "receipt_file_sha256": receipt_file_sha256,
        },
        "supporting_receipts": {
            "run_metadata": str(run_dir / "run-metadata.json"),
            "run_result": str(run_dir / "run-result.json"),
            "audit_json": str(run_dir / "audit" / "RUN_AUDIT.json"),
            "session_log": str(session_log_path) if session_log_path.exists() else None,
            "copilot_log": str(run_dir / "copilot.log") if (run_dir / "copilot.log").exists() else None,
        },
    }
    return scorecard


def build_phase_estimates(scorecard: dict[str, Any]) -> list[dict[str, Any]]:
    phase_receipts = scorecard.get("phase_receipts") or {}
    spans = (
        phase_receipts.get("comparable_phase_spans_seconds")
        or phase_receipts.get("phase_spans_seconds")
        or {}
    )
    receipt_span = (scorecard.get("timing") or {}).get("receipt_span_seconds")
    total_cost = ((scorecard.get("cost_estimate") or {}).get("total_usd"))
    total_output_tokens = ((scorecard.get("token_usage") or {}).get("output_tokens"))
    rows: list[dict[str, Any]] = []
    for transition, seconds in spans.items():
        share = None
        if receipt_span and seconds is not None and receipt_span > 0:
            share = round(float(seconds) / float(receipt_span), 4)
        estimated_cost = None
        estimated_output_tokens = None
        if share is not None and total_cost is not None:
            estimated_cost = round(float(total_cost) * share, 4)
        if share is not None and total_output_tokens is not None:
            estimated_output_tokens = int(round(float(total_output_tokens) * share))
        rows.append(
            {
                "run_id": scorecard.get("run_id"),
                "transition": transition,
                "duration_seconds": seconds,
                "share_of_receipt_span": share,
                "estimated_cost_usd": estimated_cost,
                "estimated_output_tokens": estimated_output_tokens,
                "estimate_method": "receipt_span_proportion",
                "phase_sequence_source": (
                    "comparable_phase_spans_seconds"
                    if phase_receipts.get("comparable_phase_spans_seconds")
                    else "phase_spans_seconds"
                ),
            }
        )
    return rows

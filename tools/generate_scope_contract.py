#!/usr/bin/env python3
"""Generate a bounded Phase 0 scope contract for newsletter runs.

For admitted experiment fixture ranges, the helper prefers the fixture's
retained scope contract so challengers inherit the same scope precision as the
selected control. For other historical reruns, it prefers an exact archived
contract. When neither source exists, it falls back to a deterministic manifest
derived from current `kb/SOURCES.yaml`.
"""

from __future__ import annotations

import argparse
import calendar
import copy
import datetime as dt
import json
import re
from pathlib import Path
from typing import Any
from urllib import request

try:
    import yaml
except ImportError as exc:  # pragma: no cover - startup dependency guard
    raise SystemExit(
        "Missing dependency 'pyyaml'. Install repo dependencies with `pip install -r requirements.txt`."
    ) from exc

ROOT = Path(__file__).resolve().parent.parent
WORKSPACE = ROOT / "workspace"
SOURCES_PATH = ROOT / "kb" / "SOURCES.yaml"
EXPERIMENT_FIXTURE_PACK_ROOT = ROOT / "config" / "experiment_fixture_packs"
VSCODE_UPDATES_INDEX_URL = "https://code.visualstudio.com/updates"
VSCODE_UPDATE_URL_TEMPLATE = "https://code.visualstudio.com/updates/{slug}"
VSCODE_SLUG_RE = re.compile(r"/updates/(v1_[0-9]+)")
MONTH_DAY_YEAR_RE = re.compile(r"([A-Z][a-z]+ [0-9]{1,2}, 20[0-9]{2})")

STANDARD_CATEGORIES = [
    "Security & Compliance",
    "AI & Automation",
    "Platform & DevEx",
    "Enterprise Administration",
]

REQUIRED_VERSION_KEYS = [
    "vscode",
    "visual_studio",
    "jetbrains",
    "xcode",
    "copilot_cli",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate newsletter scope contract")
    parser.add_argument("start", help="Start date (YYYY-MM-DD)")
    parser.add_argument("end", help="End date (YYYY-MM-DD)")
    parser.add_argument(
        "--output",
        help="Optional output path. Defaults to workspace/newsletter_scope_contract_<END>.json",
    )
    return parser.parse_args()


def validate_date(value: str) -> dt.date:
    try:
        return dt.datetime.strptime(value, "%Y-%m-%d").date()
    except ValueError as exc:
        raise SystemExit(f"Invalid date '{value}', expected YYYY-MM-DD") from exc


def load_sources() -> dict[str, Any]:
    if not SOURCES_PATH.exists():
        raise SystemExit(f"Missing sources file: {SOURCES_PATH}")
    data = yaml.safe_load(SOURCES_PATH.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit(f"Invalid sources payload in {SOURCES_PATH}")
    return data


def iter_exact_archived_contracts(end: str) -> list[Path]:
    pattern = f"archive/**/workspace/newsletter_scope_contract_{end}.json"
    return sorted(ROOT.glob(pattern))


def load_exact_archived_contract(start: str, end: str) -> tuple[dict[str, Any] | None, Path | None]:
    for path in iter_exact_archived_contracts(end):
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError, UnicodeDecodeError):
            continue
        date_range = payload.get("date_range", {})
        if date_range.get("start") == start and date_range.get("end") == end:
            return payload, path
    return None, None


def matching_date_range(payload: dict[str, Any], start: str, end: str) -> bool:
    date_range = payload.get("date_range", {})
    return date_range.get("start") == start and date_range.get("end") == end


def load_json_object(path: Path) -> dict[str, Any] | None:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError, UnicodeDecodeError):
        return None
    return payload if isinstance(payload, dict) else None


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def load_exact_fixture_scope_contract(start: str, end: str) -> tuple[dict[str, Any] | None, Path | None, Path | None]:
    """Return the selected fixture scope contract for an admitted experiment range.

    Batch comparison runs must use the same scope-contract precision as the
    admitted control. Fixture packs retain that owner-side contract explicitly,
    so using it here preserves benchmark semantics without requiring each model
    to rediscover patch/recovery metadata by hand.
    """

    if not EXPERIMENT_FIXTURE_PACK_ROOT.exists():
        return None, None, None

    matched_manifest_paths: list[Path] = []
    fixture_errors: list[str] = []
    valid_matches: list[tuple[dict[str, Any], Path, Path]] = []
    seen_valid_match_keys: set[tuple[Path, Path]] = set()
    for manifest_path in sorted(EXPERIMENT_FIXTURE_PACK_ROOT.glob("*.json")):
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError, UnicodeDecodeError):
            continue
        if manifest.get("start") != start or manifest.get("end") != end:
            continue
        matched_manifest_paths.append(manifest_path)

        surfaces = manifest.get("surfaces", {})
        if not isinstance(surfaces, dict):
            fixture_errors.append(f"{display_path(manifest_path)} has no object-valued surfaces")
            continue
        saw_scope_contract = False
        for rows in surfaces.values():
            if not isinstance(rows, list):
                continue
            for row in rows:
                if not isinstance(row, dict) or row.get("artifact_name") != "scope_contract":
                    continue
                saw_scope_contract = True
                source_path = row.get("source_path")
                if not isinstance(source_path, str) or not source_path:
                    fixture_errors.append(f"{display_path(manifest_path)} has a scope_contract without source_path")
                    continue
                scope_path = Path(source_path)
                if not scope_path.is_absolute():
                    scope_path = ROOT / scope_path
                if not scope_path.exists():
                    fixture_errors.append(
                        f"{display_path(manifest_path)} points at missing scope contract {display_path(scope_path)}"
                    )
                    continue
                try:
                    payload = json.loads(scope_path.read_text(encoding="utf-8"))
                except (json.JSONDecodeError, OSError, UnicodeDecodeError) as exc:
                    fixture_errors.append(
                        f"{display_path(manifest_path)} points at unreadable scope contract "
                        f"{display_path(scope_path)}: {exc}"
                    )
                    continue
                date_range = payload.get("date_range", {})
                if date_range.get("start") == start and date_range.get("end") == end:
                    match_key = (manifest_path, scope_path)
                    if match_key not in seen_valid_match_keys:
                        valid_matches.append((payload, scope_path, manifest_path))
                        seen_valid_match_keys.add(match_key)
                    continue
                fixture_errors.append(
                    f"{display_path(manifest_path)} scope contract {display_path(scope_path)} "
                    f"has date range {date_range.get('start')} to {date_range.get('end')}"
                )
        if not saw_scope_contract:
            fixture_errors.append(f"{display_path(manifest_path)} has no scope_contract surface")
    if len(valid_matches) == 1:
        return valid_matches[0]
    if len(valid_matches) > 1:
        match_list = ", ".join(display_path(match[2]) for match in valid_matches)
        raise SystemExit(
            "Multiple experiment fixture scope contracts match this date range; "
            f"refusing to choose by filename order: {match_list}"
        )
    if matched_manifest_paths:
        details = "; ".join(fixture_errors) if fixture_errors else "no usable scope_contract surface found"
        raise SystemExit(
            "Matching experiment fixture manifest exists, but its retained scope contract could not be loaded: "
            + details
        )
    return None, None, None


def load_sources_index(data: dict[str, Any]) -> dict[str, dict[str, Any]]:
    sources = data.get("sources", [])
    if not isinstance(sources, list):
        raise SystemExit("SOURCES.yaml is missing a list-valued 'sources' key")

    index: dict[str, dict[str, Any]] = {}
    for item in sources:
        if not isinstance(item, dict):
            continue
        source_id = item.get("id")
        if isinstance(source_id, str) and source_id:
            index[source_id] = item
    return index


def in_range(release_date: str, start: dt.date, end: dt.date) -> bool:
    if not release_date:
        return False
    try:
        current = dt.datetime.strptime(release_date, "%Y-%m-%d").date()
    except ValueError:
        return False
    return start <= current <= end


def compact_version(version: str) -> str:
    value = version.strip()
    # JetBrains stable versions carry IDE build metadata like `-243`; the
    # scope contract tracks the plugin version itself.
    if value.endswith("-243"):
        value = value.rsplit("-", 1)[0]
    return value


def add_if_in_range(
    versions: list[str],
    version: str,
    release_date: str,
    start: dt.date,
    end: dt.date,
) -> None:
    if version and in_range(release_date, start, end):
        versions.append(compact_version(version))


def derive_vscode_versions(source: dict[str, Any], start: dt.date, end: dt.date) -> tuple[list[str], dict[str, Any]]:
    versions: list[tuple[dt.date, str, dict[str, Any]]] = []
    latest = source.get("latest_known", {}) if isinstance(source, dict) else {}

    latest_version = latest.get("version", "")
    latest_release = latest.get("release_date", "")
    latest_url = latest.get("reference_url", "")
    if latest_version and in_range(latest_release, start, end):
        versions.append(
            (
                dt.datetime.strptime(latest_release, "%Y-%m-%d").date(),
                latest_version,
                {
                    "named_month": "",
                    "actual_release_date": latest_release,
                    "url": latest_url,
                },
            )
        )

    for item in source.get("previous_versions_in_cycle", []):
        if not isinstance(item, dict):
            continue
        release_date = item.get("actual_release_date", "")
        version = item.get("version", "")
        if version and in_range(release_date, start, end):
            versions.append(
                (
                    dt.datetime.strptime(release_date, "%Y-%m-%d").date(),
                    version,
                    {
                        "named_month": item.get("named_month", ""),
                        "actual_release_date": release_date,
                        "url": item.get("reference_url", ""),
                    },
                )
            )

    versions.sort(key=lambda item: (item[0], item[1]))
    ordered = [item[1] for item in versions]
    details = {item[1]: item[2] for item in versions}
    return ordered, details


def fetch_text(url: str) -> str:
    with request.urlopen(url, timeout=20) as response:
        return response.read().decode("utf-8", errors="ignore")


def derive_vscode_versions_from_web(start: dt.date, end: dt.date) -> tuple[list[str], dict[str, Any]]:
    try:
        index_html = fetch_text(VSCODE_UPDATES_INDEX_URL)
    except Exception:
        return [], {}

    seen_slugs: set[str] = set()
    ordered_slugs: list[str] = []
    for slug in VSCODE_SLUG_RE.findall(index_html):
        if slug in seen_slugs:
            continue
        seen_slugs.add(slug)
        ordered_slugs.append(slug)

    versions: list[tuple[dt.date, str, dict[str, Any]]] = []
    for slug in ordered_slugs:
        page_url = VSCODE_UPDATE_URL_TEMPLATE.format(slug=slug)
        try:
            page_html = fetch_text(page_url)
        except Exception:
            continue

        match = MONTH_DAY_YEAR_RE.search(page_html)
        if not match:
            continue

        try:
            release_date = dt.datetime.strptime(match.group(1), "%B %d, %Y").date()
        except ValueError:
            continue
        if not (start <= release_date <= end):
            continue

        version = slug.replace("v", "").replace("_", ".")
        versions.append(
            (
                release_date,
                version,
                {
                    "named_month": "",
                    "actual_release_date": release_date.strftime("%Y-%m-%d"),
                    "url": page_url,
                },
            )
        )

    versions.sort(key=lambda item: (item[0], item[1]))
    ordered = [item[1] for item in versions]
    details = {item[1]: item[2] for item in versions}
    return ordered, details


def merge_vscode_versions(
    kb_versions: list[str],
    kb_details: dict[str, Any],
    start: dt.date,
    end: dt.date,
) -> tuple[list[str], dict[str, Any]]:
    merged: dict[str, dict[str, Any]] = {}

    for version in kb_versions:
        detail = kb_details.get(version, {}) if isinstance(kb_details, dict) else {}
        if not isinstance(detail, dict):
            detail = {}
        actual_release_date = detail.get("actual_release_date", "")
        if not actual_release_date or not in_range(actual_release_date, start, end):
            continue
        merged[version] = detail

    web_versions, web_details = derive_vscode_versions_from_web(start, end)
    for version in web_versions:
        detail = web_details.get(version, {})
        if version not in merged:
            merged[version] = detail

    ordered_items = sorted(
        merged.items(),
        key=lambda item: (
            dt.datetime.strptime(item[1]["actual_release_date"], "%Y-%m-%d").date(),
            item[0],
        ),
    )
    return [version for version, _ in ordered_items], {version: detail for version, detail in ordered_items}


def month_urls(start: dt.date, end: dt.date) -> list[str]:
    urls: list[str] = []
    cursor = dt.date(start.year, start.month, 1)
    final = dt.date(end.year, end.month, 1)
    while cursor <= final:
        urls.append(f"github.blog/changelog/{cursor:%Y/%m}/")
        if cursor.month == 12:
            cursor = dt.date(cursor.year + 1, 1, 1)
        else:
            cursor = dt.date(cursor.year, cursor.month + 1, 1)
    return urls


def load_fixture_scope_completion(
    fixture_manifest_path: Path | None,
    start: str,
    end: str,
) -> tuple[dict[str, Any] | None, Path | None]:
    if fixture_manifest_path is None:
        return None, None

    fixture_manifest = load_json_object(fixture_manifest_path)
    if fixture_manifest is None:
        raise SystemExit(f"Fixture manifest became unreadable: {display_path(fixture_manifest_path)}")

    raw_path = fixture_manifest.get("scope_completion_source_path")
    if raw_path is None:
        return None, None
    if not isinstance(raw_path, str) or not raw_path:
        raise SystemExit(
            f"{display_path(fixture_manifest_path)} has invalid scope_completion_source_path"
        )

    completion_path = Path(raw_path)
    if not completion_path.is_absolute():
        completion_path = ROOT / completion_path
    completion = load_json_object(completion_path)
    if completion is None:
        raise SystemExit(f"Scope completion source is missing or invalid: {display_path(completion_path)}")
    if not matching_date_range(completion, start, end):
        raise SystemExit(
            "Scope completion source date_range does not match fixture: "
            f"{display_path(completion_path)}"
        )
    return completion, completion_path


def add_months(value: dt.date, months: int) -> dt.date:
    month_index = value.month - 1 + months
    year = value.year + month_index // 12
    month = month_index % 12 + 1
    day = min(value.day, calendar.monthrange(year, month)[1])
    return dt.date(year, month, day)


def ensure_expected_event_date_range(manifest: dict[str, Any], end: dt.date) -> None:
    event_range = manifest.get("expected_event_date_range")
    if not isinstance(event_range, dict):
        event_range = {}

    if not event_range.get("earliest"):
        event_range["earliest"] = end.strftime("%Y-%m-%d")
    if not event_range.get("latest"):
        event_range["latest"] = add_months(end, 6).strftime("%Y-%m-%d")

    manifest["expected_event_date_range"] = event_range


def complete_missing_scope_fields(
    manifest: dict[str, Any],
    completion: dict[str, Any] | None,
    completion_path: Path | None,
) -> None:
    if completion is None or completion_path is None:
        return

    changed = False

    date_range = manifest.setdefault("date_range", {})
    completion_date_range = completion.get("date_range", {})
    if isinstance(date_range, dict) and isinstance(completion_date_range, dict):
        for key in ("previous_newsletter_end", "gap_days"):
            if key not in date_range and key in completion_date_range:
                date_range[key] = completion_date_range[key]
                changed = True

    versions = manifest.setdefault("expected_versions", {})
    completion_versions = completion.get("expected_versions", {})
    if isinstance(versions, dict) and isinstance(completion_versions, dict):
        for key in REQUIRED_VERSION_KEYS + ["vscode_details"]:
            if not versions.get(key) and completion_versions.get(key):
                versions[key] = completion_versions[key]
                changed = True

    sources = manifest.get("expected_sources")
    completion_sources = completion.get("expected_sources")
    if isinstance(sources, list) and isinstance(completion_sources, list):
        merged_sources = dedupe([*sources, *completion_sources])
        if merged_sources != sources:
            manifest["expected_sources"] = merged_sources
            changed = True

    categories = manifest.get("expected_categories")
    completion_categories = completion.get("expected_categories")
    if isinstance(categories, list) and isinstance(completion_categories, list):
        merged_categories = dedupe([*categories, *completion_categories])
        if merged_categories != categories:
            manifest["expected_categories"] = merged_categories
            changed = True

    if not manifest.get("expected_event_date_range") and completion.get("expected_event_date_range"):
        manifest["expected_event_date_range"] = completion["expected_event_date_range"]
        changed = True

    if changed:
        manifest["targeted_completion_sources"] = {
            "reason": (
                "Helper fixture output omitted required Phase 0 fields; filled from the "
                "fixture manifest's explicit scope completion source."
            ),
            "source_contract": str(completion_path.relative_to(ROOT)),
        }


def derive_fallback_manifest(start_s: str, end_s: str, start: dt.date, end: dt.date) -> dict[str, Any]:
    sources_index = load_sources_index(load_sources())

    vscode_source = sources_index.get("vscode_updates", {})
    vscode_versions, vscode_details = derive_vscode_versions(vscode_source, start, end)
    vscode_versions, vscode_details = merge_vscode_versions(vscode_versions, vscode_details, start, end)

    visual_studio_versions: list[str] = []
    add_if_in_range(
        visual_studio_versions,
        sources_index.get("visual_studio_release_notes_2026", {}).get("latest_known", {}).get("version", ""),
        sources_index.get("visual_studio_release_notes_2026", {}).get("latest_known", {}).get("release_date", ""),
        start,
        end,
    )

    jetbrains_versions: list[str] = []
    add_if_in_range(
        jetbrains_versions,
        sources_index.get("jetbrains_plugin_updates_api", {}).get("latest_known", {}).get("version", ""),
        sources_index.get("jetbrains_plugin_updates_api", {}).get("latest_known", {}).get("release_date", ""),
        start,
        end,
    )

    xcode_versions: list[str] = []
    add_if_in_range(
        xcode_versions,
        sources_index.get("xcode_copilot_repo", {}).get("latest_known", {}).get("version", ""),
        sources_index.get("xcode_copilot_repo", {}).get("latest_known", {}).get("release_date", ""),
        start,
        end,
    )

    copilot_cli_versions: list[str] = []
    add_if_in_range(
        copilot_cli_versions,
        sources_index.get("copilot_cli_releases", {}).get("latest_known", {}).get("version", ""),
        sources_index.get("copilot_cli_releases", {}).get("latest_known", {}).get("release_date", ""),
        start,
        end,
    )

    expected_sources = month_urls(start, end)
    expected_sources.append("github.blog/news-insights/company-news/")
    expected_sources.extend(
        detail["url"]
        for detail in vscode_details.values()
        if isinstance(detail, dict) and detail.get("url")
    )
    if jetbrains_versions:
        expected_sources.append("plugins.jetbrains.com/api/plugins/17718/updates")
    if xcode_versions:
        expected_sources.append("github.com/github/CopilotForXcode/releases")
    if visual_studio_versions:
        expected_sources.append("devblogs.microsoft.com/visualstudio/")
    expected_sources.append("resources.github.com/events/")

    manifest: dict[str, Any] = {
        "date_range": {
            "start": start_s,
            "end": end_s,
        },
        "expected_versions": {
            "vscode": vscode_versions,
        },
        "expected_sources": dedupe(expected_sources),
        "expected_categories": STANDARD_CATEGORIES,
        "expected_event_date_range": {
            "earliest": end_s,
            "latest": add_months(end, 6).strftime("%Y-%m-%d"),
        },
    }
    if vscode_details:
        manifest["expected_versions"]["vscode_details"] = vscode_details
    if visual_studio_versions:
        manifest["expected_versions"]["visual_studio"] = visual_studio_versions
    if jetbrains_versions:
        manifest["expected_versions"]["jetbrains"] = jetbrains_versions
    if xcode_versions:
        manifest["expected_versions"]["xcode"] = xcode_versions
    if copilot_cli_versions:
        manifest["expected_versions"]["copilot_cli"] = copilot_cli_versions

    return manifest


def dedupe(values: list[str]) -> list[str]:
    seen: set[str] = set()
    ordered: list[str] = []
    for value in values:
        if not value or value in seen:
            continue
        seen.add(value)
        ordered.append(value)
    return ordered


def main() -> int:
    args = parse_args()
    start = validate_date(args.start)
    end = validate_date(args.end)
    if end < start:
        raise SystemExit("END_DATE must be on or after START_DATE")

    WORKSPACE.mkdir(parents=True, exist_ok=True)
    out_path = Path(args.output) if args.output else WORKSPACE / f"newsletter_scope_contract_{args.end}.json"
    if not out_path.is_absolute():
        out_path = ROOT / out_path

    fixture_manifest_path: Path | None = None
    manifest, baseline_path, fixture_manifest_path = load_exact_fixture_scope_contract(args.start, args.end)
    if manifest is not None:
        if baseline_path is None:
            raise SystemExit("Exact fixture scope contract found without source metadata")
        manifest = copy.deepcopy(manifest)
        manifest["generator"] = "tools/generate_scope_contract.py"
        manifest["generation_mode"] = "experiment_fixture_scope_contract"
        if fixture_manifest_path is not None:
            manifest["fixture_manifest_path"] = str(fixture_manifest_path.relative_to(ROOT))
        manifest["fixture_scope_contract_path"] = str(baseline_path.relative_to(ROOT))
        completion_payload, completion_path = load_fixture_scope_completion(
            fixture_manifest_path,
            args.start,
            args.end,
        )
    else:
        completion_payload = None
        completion_path = None
        manifest, baseline_path = load_exact_archived_contract(args.start, args.end)
        if manifest is not None:
            if baseline_path is None:
                raise SystemExit("Exact archived contract payload found without a source path")
            manifest = copy.deepcopy(manifest)
            manifest["generator"] = "tools/generate_scope_contract.py"
            manifest["generation_mode"] = "exact_archived_contract"
            manifest["archived_contract_path"] = str(baseline_path.relative_to(ROOT))
        else:
            manifest = derive_fallback_manifest(args.start, args.end, start, end)
            manifest["generator"] = "tools/generate_scope_contract.py"
            manifest["generation_mode"] = "sources_yaml_fallback"

    complete_missing_scope_fields(manifest, completion_payload, completion_path)
    ensure_expected_event_date_range(manifest, end)
    manifest["generated_at"] = dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    try:
        display_path = str(out_path.relative_to(ROOT))
    except ValueError:
        display_path = str(out_path)
    print(f"Wrote scope contract: {display_path}")
    print(f"Generation mode: {manifest['generation_mode']}")
    if baseline_path is not None and manifest["generation_mode"] == "exact_archived_contract":
        print(f"Archived baseline: {baseline_path.relative_to(ROOT)}")
    if baseline_path is not None and manifest["generation_mode"] == "experiment_fixture_scope_contract":
        print(f"Fixture scope contract: {baseline_path.relative_to(ROOT)}")
    print(
        "VS Code versions: "
        + ", ".join(manifest.get("expected_versions", {}).get("vscode", []))
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

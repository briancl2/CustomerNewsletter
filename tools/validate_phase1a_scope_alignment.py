#!/usr/bin/env python3
"""Validate Phase 1A URL manifest coverage against the Phase 0 scope contract."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fail if Phase 1A omits VS Code versions required by the scope contract."
    )
    parser.add_argument("start", help="Cycle start date, YYYY-MM-DD")
    parser.add_argument("end", help="Cycle end date, YYYY-MM-DD")
    parser.add_argument(
        "--artifact-root",
        default=".",
        help="Repository or artifact root containing workspace/ (default: current directory).",
    )
    parser.add_argument(
        "--prompt-file",
        help="Rendered Phase 1A prompt file. When provided, the manifest must be at least as fresh as the prompt.",
    )
    parser.add_argument(
        "--write-receipt",
        help="Write a JSON provenance receipt with hashes and validation result.",
    )
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as fh:
        payload = json.load(fh)
    if not isinstance(payload, dict):
        raise SystemExit(f"Scope contract is not a JSON object: {path}")
    return payload


def contains_version_ref(text: str, version: str) -> bool:
    normalized = version.strip().removeprefix("v")
    if not normalized:
        return False
    slug = "v" + normalized.replace(".", "_")
    dotted_pattern = rf"(?<![0-9]){re.escape(normalized)}(?![0-9])"
    slug_pattern = rf"(?<![A-Za-z0-9_]){re.escape(slug)}(?![A-Za-z0-9_])"
    return bool(re.search(dotted_pattern, text, re.IGNORECASE) or re.search(slug_pattern, text, re.IGNORECASE))


def extract_urls(text: str) -> set[str]:
    return {
        match.rstrip(".,;:")
        for match in re.findall(r"https?://[^\s)<>\]\"']+", text)
    }


def extract_url_list(text: str) -> list[str]:
    return [
        match.rstrip(".,;:")
        for match in re.findall(r"https?://[^\s)<>\]\"']+", text)
    ]


def normalize_version(version: str) -> str:
    return version.strip().removeprefix("v").replace("_", ".")


def version_slug(version: str) -> str:
    return "v" + normalize_version(version).replace(".", "_")


def vscode_version_from_url(url: str) -> str | None:
    match = re.fullmatch(r"https://code\.visualstudio\.com/updates/(v[0-9]+_[0-9]+)", url)
    if not match:
        return None
    return normalize_version(match.group(1))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_receipt(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    root = Path(args.artifact_root).resolve()
    workspace = root / "workspace"
    scope = workspace / f"newsletter_scope_contract_{args.end}.json"
    manifest = workspace / f"newsletter_phase1a_url_manifest_{args.start}_to_{args.end}.md"
    prompt_file = Path(args.prompt_file).resolve() if args.prompt_file else None
    receipt_path = Path(args.write_receipt).resolve() if args.write_receipt else None
    receipt: dict[str, Any] = {
        "schema": "phase1a_scope_alignment_preflight_receipt.v1",
        "start": args.start,
        "end": args.end,
        "artifact_root": str(root),
        "scope_contract": {
            "path": str(scope),
            "exists": scope.is_file(),
            "sha256": sha256_file(scope) if scope.is_file() else "",
            "mtime_ns": scope.stat().st_mtime_ns if scope.is_file() else None,
        },
        "phase1a_manifest": {
            "path": str(manifest),
            "exists": manifest.is_file(),
            "sha256": sha256_file(manifest) if manifest.is_file() else "",
            "mtime_ns": manifest.stat().st_mtime_ns if manifest.is_file() else None,
        },
        "prompt": {
            "path": str(prompt_file) if prompt_file else "",
            "exists": prompt_file.is_file() if prompt_file else None,
            "sha256": sha256_file(prompt_file) if prompt_file and prompt_file.is_file() else "",
            "mtime_ns": prompt_file.stat().st_mtime_ns if prompt_file and prompt_file.is_file() else None,
        },
        "result": "fail",
        "failures": [],
    }

    def fail(message: str) -> int:
        receipt["failures"].append(message)
        print(f"FAIL: {message}")
        if receipt_path:
            write_receipt(receipt_path, receipt)
        return 1

    failures: list[str] = []
    if not scope.is_file():
        failures.append(f"scope contract missing: {scope}")
    if not manifest.is_file():
        failures.append(f"Phase 1A URL manifest missing: {manifest}")
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}")
        receipt["failures"].extend(failures)
        if receipt_path:
            write_receipt(receipt_path, receipt)
        return 1
    if prompt_file and not prompt_file.is_file():
        return fail(f"Phase 1A prompt file missing: {prompt_file}")

    scope_payload = load_json(scope)
    expected_versions = scope_payload.get("expected_versions", {}).get("vscode", [])
    if not isinstance(expected_versions, list):
        return fail("scope contract expected_versions.vscode is not a list")
    expected_normalized = [
        normalize_version(str(version))
        for version in expected_versions
        if str(version).strip()
    ]
    expected_set = set(expected_normalized)
    receipt["expected_versions"] = expected_normalized

    manifest_text = manifest.read_text(encoding="utf-8", errors="ignore")
    missing_versions = [
        normalize_version(str(version))
        for version in expected_versions
        if str(version).strip() and not contains_version_ref(manifest_text, str(version))
    ]
    manifest_url_list = extract_url_list(manifest_text)
    manifest_urls = set(manifest_url_list)
    vscode_urls = [
        url
        for url in manifest_url_list
        if vscode_version_from_url(url) is not None
    ]
    observed_versions = [vscode_version_from_url(url) for url in vscode_urls]
    duplicate_versions = sorted({
        version
        for version in observed_versions
        if version is not None and observed_versions.count(version) > 1
    })
    duplicate_urls = sorted({
        url
        for url in vscode_urls
        if vscode_urls.count(url) > 1
    })
    unexpected_versions = sorted({
        version
        for version in observed_versions
        if version is not None and version not in expected_set
    })
    receipt["observed_vscode_versions"] = [version for version in observed_versions if version is not None]
    receipt["observed_vscode_urls"] = vscode_urls
    receipt["duplicate_versions"] = duplicate_versions
    receipt["duplicate_urls"] = duplicate_urls
    receipt["unexpected_versions"] = unexpected_versions

    details = scope_payload.get("expected_versions", {}).get("vscode_details", {})
    if details is None:
        details = {}
    if not isinstance(details, dict):
        return fail("scope contract expected_versions.vscode_details is not an object")

    missing_urls: list[str] = []
    for version in expected_versions:
        normalized = normalize_version(str(version))
        detail = details.get(normalized) or details.get(str(version).strip())
        if not isinstance(detail, dict):
            continue
        url = str(detail.get("url") or "").strip()
        if url and url not in manifest_urls:
            missing_urls.append(f"{normalized} -> {url}")

    stale_manifest = False
    if prompt_file:
        prompt_mtime_ns = prompt_file.stat().st_mtime_ns
        manifest_mtime_ns = manifest.stat().st_mtime_ns
        stale_manifest = manifest_mtime_ns < prompt_mtime_ns
    receipt["manifest_at_least_as_fresh_as_prompt"] = not stale_manifest

    if missing_versions:
        print(f"Scope contract: {scope}")
        print(f"Phase 1A URL manifest: {manifest}")
        return fail(
            "Phase 1A URL manifest missing scope-contract VS Code version(s): "
            + ", ".join(missing_versions)
        )
    if missing_urls:
        print(f"Scope contract: {scope}")
        print(f"Phase 1A URL manifest: {manifest}")
        return fail(
            "Phase 1A URL manifest missing scope-contract VS Code URL(s): "
            + "; ".join(missing_urls)
        )
    if duplicate_versions:
        return fail(
            "Phase 1A URL manifest has duplicate VS Code release version(s): "
            + ", ".join(duplicate_versions)
        )
    if duplicate_urls:
        return fail(
            "Phase 1A URL manifest has duplicate VS Code release URL(s): "
            + ", ".join(duplicate_urls)
        )
    if unexpected_versions:
        return fail(
            "Phase 1A URL manifest has unexpected VS Code release version(s): "
            + ", ".join(unexpected_versions)
        )
    if stale_manifest:
        return fail(
            "Phase 1A URL manifest is older than rendered Phase 1A prompt; refusing possible stale manifest reuse"
        )

    receipt["result"] = "pass"
    if receipt_path:
        write_receipt(receipt_path, receipt)
    print(
        "PASS: Phase 1A URL manifest covers scope-contract VS Code versions: "
        + ", ".join(expected_normalized)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

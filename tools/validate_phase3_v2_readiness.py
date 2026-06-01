#!/usr/bin/env python3
"""Fail-closed V2-readiness checks for cost-stack Phase 3 artifacts."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from urllib.parse import urlparse

MODEL_BULLET = re.compile(
    r"^-\s+\*\*[^*]*(Model availability|model.*update|model governance|BYOK|"
    r"reasoning controls|usage-based billing|GPT-[0-9]|Gemini [0-9])",
    re.IGNORECASE,
)
MAIN_BULLET = re.compile(r"^-\s+\*\*")
LINK = re.compile(r"\[[^\]]+\]\((https?://[^)]+)\)")
VSCODE_VERSION = re.compile(r"\b1\.\d{3}\b")

COMPETITIVE_SIGNAL_GROUPS = (
    re.compile(
        r"competitive|rival|claude code|alternative|market|ecosystem|"
        r"platform[- ]choice|customer[- ]choice|provider[- ]choice|agent[- ]provider[- ]choice",
        re.IGNORECASE,
    ),
    re.compile(r"bring.*subscription|take.*subscription|anywhere|platform.*open", re.IGNORECASE),
    re.compile(r"agent.*choice|pick.*agent|choose.*agent|multiple.*provider", re.IGNORECASE),
)

VALID_DOMAIN_HOSTS = (
    "github.blog",
    "github.com",
    "docs.github.com",
    "code.visualstudio.com",
    "learn.microsoft.com",
    "developer.microsoft.com",
    "devblogs.microsoft.com",
    "plugins.jetbrains.com",
    "marketplace.eclipse.org",
    "resources.github.com",
    "www.youtube.com",
    "aitour.microsoft.com",
    "github.registration.goldcast.io",
    "luma.com",
    "learn.github.com",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", help="Curated sections artifact to check")
    parser.add_argument("--working-set", default="", help="Canonical Phase 3 working set")
    parser.add_argument("--source-context", default="", help="Optional compact source context")
    parser.add_argument("--write-receipt", default="", help="Optional JSON receipt output")
    parser.add_argument("--max-model-bullets", type=int, default=1)
    parser.add_argument("--min-competitive-signal-groups", type=int, default=1)
    parser.add_argument("--min-main-bullet-link-ratio", type=int, default=70)
    parser.add_argument("--min-link-density-times10", type=int, default=10)
    parser.add_argument("--min-valid-domain-ratio", type=int, default=75)
    parser.add_argument("--require-vscode-version-coverage", action="store_true")
    return parser.parse_args()


def read_optional(path_text: str) -> str:
    if not path_text:
        return ""
    path = Path(path_text)
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="ignore")


def extract_links(text: str) -> list[str]:
    return LINK.findall(text)


def normalize_domain(url: str) -> str:
    host = urlparse(url).netloc.lower()
    if host.startswith("www.") and host not in {"www.youtube.com"}:
        host = host[4:]
    return host


def is_valid_domain(url: str) -> bool:
    domain = normalize_domain(url)
    return any(domain == host or domain.endswith("." + host) for host in VALID_DOMAIN_HOSTS)


def main_bullet_chunks(lines: list[str]) -> list[str]:
    chunks: list[list[str]] = []
    current: list[str] = []
    for line in lines:
        if MAIN_BULLET.match(line):
            if current:
                chunks.append(current)
            current = [line]
            continue
        if current:
            current.append(line)
    if current:
        chunks.append(current)
    return ["\n".join(chunk[:11]) for chunk in chunks]


def expected_vscode_versions(*texts: str) -> list[str]:
    versions = set()
    for text in texts:
        versions.update(VSCODE_VERSION.findall(text))
    return sorted(versions, key=lambda value: tuple(int(part) for part in value.split(".")))


def build_receipt(args: argparse.Namespace, failures: list[str], metrics: dict[str, object]) -> dict[str, object]:
    return {
        "schema_version": 1,
        "artifact": "phase3-v2-readiness-receipt",
        "artifact_path": args.artifact,
        "working_set_path": args.working_set or None,
        "source_context_path": args.source_context or None,
        "pass": not failures,
        "failures": failures,
        "metrics": metrics,
        "thresholds": {
            "max_model_bullets": args.max_model_bullets,
            "min_competitive_signal_groups": args.min_competitive_signal_groups,
            "min_main_bullet_link_ratio": args.min_main_bullet_link_ratio,
            "min_link_density_times10": args.min_link_density_times10,
            "min_valid_domain_ratio": args.min_valid_domain_ratio,
            "require_vscode_version_coverage": args.require_vscode_version_coverage,
        },
        "non_claims": [
            "This is a deterministic readiness preflight, not billing proof.",
            "This does not replace final V2 scoring.",
        ],
    }


def main() -> int:
    args = parse_args()
    artifact = Path(args.artifact)
    if not artifact.exists():
        print(f"FAIL: missing artifact: {artifact}")
        return 2

    text = artifact.read_text(encoding="utf-8", errors="ignore")
    lines = text.splitlines()
    working_set_text = read_optional(args.working_set)
    source_context_text = read_optional(args.source_context)
    links = extract_links(text)
    bullet_chunks = main_bullet_chunks(lines)
    bullets_with_links = sum(1 for chunk in bullet_chunks if "https://" in chunk or "http://" in chunk)
    bullet_count = len(bullet_chunks)
    link_ratio = int((bullets_with_links * 100 / bullet_count)) if bullet_count else 0
    link_density_times10 = int((len(links) * 10 / bullet_count)) if bullet_count else 0
    valid_links = sum(1 for url in links if is_valid_domain(url))
    valid_domain_ratio = int((valid_links * 100 / len(links))) if links else 100
    model_bullets = sum(1 for line in lines if MODEL_BULLET.search(line))
    competitive_signal_groups = sum(1 for pattern in COMPETITIVE_SIGNAL_GROUPS if pattern.search(text))
    version_source_text = source_context_text if source_context_text else working_set_text
    expected_versions = expected_vscode_versions(version_source_text)
    missing_versions = [version for version in expected_versions if version not in text]

    failures: list[str] = []
    if model_bullets > args.max_model_bullets:
        failures.append(f"model availability bullets exceed floor ({model_bullets} > {args.max_model_bullets})")
    if competitive_signal_groups < args.min_competitive_signal_groups:
        failures.append(
            "competitive/platform-choice signal groups below floor "
            f"({competitive_signal_groups} < {args.min_competitive_signal_groups})"
        )
    if link_ratio < args.min_main_bullet_link_ratio:
        failures.append(
            f"main bullet source URL ratio below floor ({link_ratio}% < {args.min_main_bullet_link_ratio}%)"
        )
    if link_density_times10 < args.min_link_density_times10:
        failures.append(
            "link density below floor "
            f"({link_density_times10 / 10:.1f} < {args.min_link_density_times10 / 10:.1f})"
        )
    if valid_domain_ratio < args.min_valid_domain_ratio:
        failures.append(
            f"valid domain ratio below floor ({valid_domain_ratio}% < {args.min_valid_domain_ratio}%)"
        )
    if args.require_vscode_version_coverage and missing_versions:
        failures.append("missing VS Code version signals: " + ", ".join(missing_versions))

    metrics = {
        "main_bullet_count": bullet_count,
        "bullets_with_links": bullets_with_links,
        "main_bullet_link_ratio": link_ratio,
        "total_links": len(links),
        "link_density_times10": link_density_times10,
        "valid_links": valid_links,
        "valid_domain_ratio": valid_domain_ratio,
        "model_bullets": model_bullets,
        "competitive_signal_groups": competitive_signal_groups,
        "expected_vscode_versions": expected_versions,
        "missing_vscode_versions": missing_versions,
    }
    receipt = build_receipt(args, failures, metrics)
    if args.write_receipt:
        output = Path(args.write_receipt)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}")
        return 2
    print(
        "PASS: phase3 V2 readiness satisfied "
        f"(model_bullets={model_bullets}, competitive_groups={competitive_signal_groups}, "
        f"link_ratio={link_ratio}%, valid_domain_ratio={valid_domain_ratio}%)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

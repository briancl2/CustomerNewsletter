#!/usr/bin/env python3
"""Detect non-runtime repository mutations during retained proof runs."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

DEFAULT_ALLOWED_RUNTIME_PREFIXES = (
    "output/",
    "runs/",
    "workspace/",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        default=".",
        help="Repository root to inspect (default: current directory)",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    snapshot = sub.add_parser("snapshot", help="Write a protected-source snapshot")
    snapshot.add_argument("--output", required=True, help="Snapshot JSON path")
    snapshot.add_argument(
        "--allowed-runtime-prefix",
        action="append",
        default=[],
        help="Repo-relative prefix allowed to change during proof rows",
    )

    validate = sub.add_parser("validate", help="Validate against a prior snapshot")
    validate.add_argument("--before", required=True, help="Prior snapshot JSON path")
    validate.add_argument("--output", required=True, help="Receipt JSON path")
    return parser.parse_args()


def run_git(repo_root: Path, args: list[str]) -> list[str]:
    completed = subprocess.run(
        ["git", *args],
        cwd=repo_root,
        text=True,
        capture_output=True,
        check=False,
    )
    if completed.returncode != 0:
        raise SystemExit(completed.stderr.strip() or completed.stdout.strip())
    return [line for line in completed.stdout.splitlines() if line]


def sha256_path(path: Path) -> str | None:
    if not path.exists() or not path.is_file():
        return None
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalize_prefix(prefix: str) -> str:
    cleaned = prefix.strip().lstrip("./")
    if cleaned and not cleaned.endswith("/"):
        cleaned += "/"
    return cleaned


def allowed_prefixes(extra: list[str]) -> list[str]:
    prefixes = [*DEFAULT_ALLOWED_RUNTIME_PREFIXES, *extra]
    return sorted({normalize_prefix(prefix) for prefix in prefixes if normalize_prefix(prefix)})


def is_runtime_path(path: str, prefixes: list[str]) -> bool:
    normalized = path.lstrip("./")
    return any(normalized == prefix.rstrip("/") or normalized.startswith(prefix) for prefix in prefixes)


def file_state(repo_root: Path, rel_path: str) -> dict[str, Any]:
    path = repo_root / rel_path
    exists = path.exists() or path.is_symlink()
    state: dict[str, Any] = {
        "exists": exists,
        "sha256": sha256_path(path) if exists and path.is_file() and not path.is_symlink() else None,
        "size": path.stat().st_size if exists and path.is_file() and not path.is_symlink() else None,
        "mode": None,
        "file_type": "missing",
        "symlink_target": None,
    }
    if not exists:
        return state

    stat_result = path.lstat()
    state["mode"] = stat_result.st_mode
    if path.is_symlink():
        state["file_type"] = "symlink"
        state["symlink_target"] = str(path.readlink())
    elif path.is_file():
        state["file_type"] = "file"
    elif path.is_dir():
        state["file_type"] = "directory"
    else:
        state["file_type"] = "other"
    return {
        **state,
    }


def collect_snapshot(repo_root: Path, prefixes: list[str]) -> dict[str, Any]:
    tracked = sorted(
        path for path in run_git(repo_root, ["ls-files"]) if not is_runtime_path(path, prefixes)
    )
    untracked = sorted(
        path
        for path in run_git(repo_root, ["ls-files", "--others", "--exclude-standard"])
        if not is_runtime_path(path, prefixes)
    )
    return {
        "schema_version": 1,
        "repo_root": str(repo_root.resolve()),
        "allowed_runtime_prefixes": prefixes,
        "tracked_protected_files": {path: file_state(repo_root, path) for path in tracked},
        "untracked_protected_files": {path: file_state(repo_root, path) for path in untracked},
        "non_claims": [
            "This receipt only proves whether protected repository source changed during the proof-row window.",
            "It is not a newsletter quality, token, cost, cache, or production-adoption claim.",
        ],
    }


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def diff_states(before: dict[str, Any], after: dict[str, Any]) -> dict[str, Any]:
    before_tracked = before.get("tracked_protected_files", {})
    after_tracked = after.get("tracked_protected_files", {})
    before_untracked = before.get("untracked_protected_files", {})
    after_untracked = after.get("untracked_protected_files", {})

    tracked_paths = sorted(set(before_tracked) | set(after_tracked))
    untracked_paths = sorted(set(before_untracked) | set(after_untracked))

    changed_tracked = [
        path for path in tracked_paths if before_tracked.get(path) != after_tracked.get(path)
    ]
    added_untracked = [path for path in untracked_paths if path not in before_untracked]
    removed_untracked = [path for path in untracked_paths if path not in after_untracked]
    changed_untracked = [
        path
        for path in untracked_paths
        if path in before_untracked
        and path in after_untracked
        and before_untracked.get(path) != after_untracked.get(path)
    ]
    return {
        "changed_tracked_paths": changed_tracked,
        "added_untracked_protected_paths": added_untracked,
        "removed_untracked_protected_paths": removed_untracked,
        "changed_untracked_protected_paths": changed_untracked,
        "source_drift_detected": bool(
            changed_tracked or added_untracked or removed_untracked or changed_untracked
        ),
    }


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    if args.command == "snapshot":
        prefixes = allowed_prefixes(args.allowed_runtime_prefix)
        write_json(Path(args.output), collect_snapshot(repo_root, prefixes))
        return 0

    before_path = Path(args.before)
    before = json.loads(before_path.read_text(encoding="utf-8"))
    prefixes = [str(prefix) for prefix in before.get("allowed_runtime_prefixes", [])]
    after = collect_snapshot(repo_root, prefixes)
    diff = diff_states(before, after)
    receipt = {
        "schema_version": 1,
        "pass": not diff["source_drift_detected"],
        "result": "pass" if not diff["source_drift_detected"] else "fail_closed_source_drift",
        "before_snapshot": str(before_path.resolve()),
        "after_snapshot": after,
        **diff,
        "non_claims": [
            "A failed receipt means the proof row is invalid as an acceptance control.",
            "It does not by itself identify the semantic quality of any source edit.",
        ],
    }
    write_json(Path(args.output), receipt)
    if diff["source_drift_detected"]:
        drift_paths = sorted(
            {
                *diff["changed_tracked_paths"],
                *diff["added_untracked_protected_paths"],
                *diff["removed_untracked_protected_paths"],
                *diff["changed_untracked_protected_paths"],
            }
        )
        print(
            "ERROR: protected repository source changed during proof run: "
            + ", ".join(drift_paths),
            file=sys.stderr,
        )
        return 1
    print("PASS: proof source drift check passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

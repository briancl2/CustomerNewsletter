---
name: session-log-manager
description: "Manages AI agent session logs across Copilot CLI and VS Code stores. Health checks, per-repo archival with compression, age-based rotation, and crash forensics. Use when you need to monitor session storage growth, archive sessions per-repo, compress old sessions, investigate crashes/stalls, or detect oversized sessions. Keywords: session log, archive, rotate, compress, health check, forensics, crash RCA, disk usage, session storage."
license: MIT
metadata:
  author: briancl2
  version: "1.0"
  category: system
---

# Session Log Manager

Monitor, archive, rotate, and diagnose AI agent session logs across all stores. Deterministic shell scripts for health/archive/rotate; Python for forensics. Operates on system-wide session stores but archives per-repo.

## Quick Start

```bash
# Health check — scan all stores, report per-repo sizes, flag hotspots
bash .agents/skills/session-log-manager/scripts/session-health-check.sh

# Archive — copy & compress sessions for this repo
bash .agents/skills/session-log-manager/scripts/session-archive.sh --repo build-meta-analysis

# Rotate — compress sessions older than 7 days in the archive
bash .agents/skills/session-log-manager/scripts/session-rotate.sh

# Forensics — crash/stall RCA from session ID
python3 .agents/skills/session-log-manager/scripts/session-forensics.py <session-id-or-path>

# Image strip — remove embedded image byte-dicts, archive originals
python3 .agents/skills/session-log-manager/scripts/session-image-strip.py --dry-run --all
python3 .agents/skills/session-log-manager/scripts/session-image-strip.py --all
```

Or use Makefile targets:

```bash
make session-health
make session-archive REPO=build-meta-analysis
make session-rotate
```

## What This Skill Manages

### System Stores (Source of Truth — never modified)

| Store | Location (macOS) | Format |
|---|---|---|
| Copilot CLI | `~/.copilot/session-state/<uuid>/events.jsonl` | JSONL (event stream) |
| VS Code Insiders | `~/Library/Application Support/Code - Insiders/User/workspaceStorage/<hash>/chatSessions/*.jsonl` | JSONL (chat log) |
| VS Code Stable | `~/Library/Application Support/Code/User/workspaceStorage/<hash>/chatSessions/*.jsonl` | JSONL (chat log) |

### Archive (Repo-Local — managed by this skill)

| Location | Contents |
|---|---|
| `runs/sessions/<repo>/` | Compressed `.jsonl.gz` files, deduplicated by session UUID |

## Scripts

### `session-health-check.sh` — P0: Monitor

Scans all 3 session stores. Reports per-repo sizes. Flags hotspots.

```bash
bash .agents/skills/session-log-manager/scripts/session-health-check.sh
```

**Output:** Markdown report with:
- Summary table (files, size, oversized count per store)
- Copilot CLI per-repo breakdown (from `workspace.yaml`)
- VS Code per-workspace breakdown (from `workspace.json`)
- Health warnings (workspace >500 MB, session >10 MB, total >5 GB)

**Thresholds:**
- Workspace: >500 MB = WARNING
- Individual session: >10 MB = WARNING
- Total: >5 GB = CRITICAL

### `session-archive.sh` — P0: Archive

Archives sessions for a specific repo with gzip compression and UUID-based deduplication.

```bash
bash .agents/skills/session-log-manager/scripts/session-archive.sh --repo <name> [--output-dir <path>] [--dry-run]
```

**Behavior:**
- Scans CLI sessions via `workspace.yaml` → `git_root` match
- Scans VS Code sessions via `workspace.json` → `folder` URI match
- Compresses each session to `.jsonl.gz` (4-5x compression)
- Names: `{cli|vscode}_{uuid}.jsonl.gz`
- Deduplicates: running twice produces 0 new copies

### `session-rotate.sh` — P0: Rotate

Compresses uncompressed sessions older than N days in the archive. Never touches system stores.

```bash
bash .agents/skills/session-log-manager/scripts/session-rotate.sh [--archive-dir <path>] [--days 7] [--dry-run]
```

**Retention policy:**
- 0-7 days: Raw `.jsonl` (active, live access)
- 7+ days: Compressed `.jsonl.gz` (searchable via `zgrep`)
- Never delete: Session logs are primary behavioral evidence

### `session-forensics.py` — P1: Diagnose

Crash/stall RCA from a session ID or file path.

```bash
python3 .agents/skills/session-log-manager/scripts/session-forensics.py <session-id-or-path>
```

**Detects:**
- Context growth curve (per-line byte sizes with ASCII chart)
- Oversized attachments (images serialized as JSON dicts — L81)
- Error and Canceled events (context budget exhaustion)
- Tool call distribution
- Crash risk level (LOW / MEDIUM / HIGH / CRITICAL)

**Finds sessions by:**
- Direct file path
- UUID → searches CLI, VS Code Insiders, VS Code Stable stores

### `session-image-strip.py` — P0: Strip Images

Strips embedded image byte-dicts from VS Code session files. Images pasted into Copilot Chat
are serialized as `{"0": 137, "1": 80, ...}` — one JSON key per byte, ~2.5× inflate. This causes
V8 heap exhaustion and renderer crashes (L81, [microsoft/vscode#295334](https://github.com/microsoft/vscode/issues/295334)).

```bash
python3 .agents/skills/session-log-manager/scripts/session-image-strip.py --dry-run --all
python3 .agents/skills/session-log-manager/scripts/session-image-strip.py --all
python3 .agents/skills/session-log-manager/scripts/session-image-strip.py --workspace ea03ad
```

**Behavior:**
- Scans all JSONL session files for byte-dict patterns (PNG=137, JPEG=255, GIF=71)
- Archives each original to `~/.session-archive/images/<wsid>/` (gzipped)
- Replaces byte-dicts with `[IMAGE_STRIPPED: N bytes, stripped TIMESTAMP]`
- Preserves all conversation text, image metadata (name, path, kind)
- `--dry-run` shows what would be cleaned without modifying files

## Tiers

| Tier | Capabilities | Target Repos |
|---|---|---|
| **Good** | health check, archive (compressed), rotate | Any repo (T7, T9, T10, T11) |
| **Better** | Good + parse_session + search_sessions (from session-log-analysis skill) | Repos with analysis needs |
| **Best** | Better + forensics, monitoring, pre-commit guards | T1, B5a |

## References

- [Session Stores](references/session-stores.md) — Where logs live (macOS, Linux paths)
- [Size Budgets](references/size-budgets.md) — Thresholds, growth rates, compression ratios
- [Session Archive 2026-02-14](references/session-archive-2026-02-14.md) — Emergency cleanup: 604 files, 2.3 GB freed, restore instructions

## Examples

- [Health Check Output](examples/health-check-output.md) — Sample report
- [Forensics Report](examples/forensics-report.md) — Sample crash RCA

## Related Skills

| Skill | Relationship |
|---|---|
| `session-log-analysis` | Analysis (parse + search). Complementary — manager handles storage, analysis handles insights. |

## Done When

- `session-health-check.sh` runs without error on macOS, reports per-repo sizes
- `session-archive.sh` archives sessions for a named repo with compression and dedup
- `session-rotate.sh` compresses sessions older than threshold
- `session-forensics.py` produces crash RCA with context growth, attachment detection, error events
- All scripts exit 0 on healthy systems

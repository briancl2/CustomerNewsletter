# Strict Pipeline Contract Validation (FAIL)

- Date Range: `2026-02-14` to `2026-02-21`
- Require Fresh: `1`
- Benchmark Mode: `off`
- Phase Receipts: `workspace/newsletter_phase_receipts_2026-02-21.json`
- Fails: `1`
- Warnings: `1`

## Details

```text
PASS: Phase 1A manifest present (4207 bytes): workspace/newsletter_phase1a_url_manifest_2026-02-14_to_2026-02-21.md
PASS: Phase 1B interim (github) present (10857 bytes): workspace/newsletter_phase1b_interim_github_2026-02-14_to_2026-02-21.md
PASS: Phase 1B interim (vscode) present (5062 bytes): workspace/newsletter_phase1b_interim_vscode_2026-02-14_to_2026-02-21.md
PASS: Phase 1B interim (visualstudio) present (2026 bytes): workspace/newsletter_phase1b_interim_visualstudio_2026-02-14_to_2026-02-21.md
PASS: Phase 1B interim (jetbrains) present (2785 bytes): workspace/newsletter_phase1b_interim_jetbrains_2026-02-14_to_2026-02-21.md
PASS: Phase 1B interim (xcode) present (1945 bytes): workspace/newsletter_phase1b_interim_xcode_2026-02-14_to_2026-02-21.md
PASS: Phase 1C discoveries present (14966 bytes): workspace/newsletter_phase1a_discoveries_2026-02-14_to_2026-02-21.md
PASS: Phase 2 events present (5551 bytes): workspace/newsletter_phase2_events_2026-02-21.md
PASS: Phase 3 curated sections present (9200 bytes): workspace/newsletter_phase3_curated_sections_2026-02-21.md
PASS: Scope contract present (673 bytes): workspace/newsletter_scope_contract_2026-02-21.json
PASS: Scope results present (923 bytes): workspace/newsletter_scope_results_2026-02-21.md
PASS: Final newsletter present (16076 bytes): output/2026-02_february_newsletter.md
PASS: Phase 2 event sources present (3115 bytes): workspace/newsletter_phase2_event_sources_2026-02-21.json
PASS: No shortcut artifact: workspace/fresh_phase1a_url_manifest_2026-02-14_to_2026-02-21.md
PASS: No shortcut artifact: workspace/fresh_phase1c_discoveries_2026-02-14_to_2026-02-21.md
PASS: Phase continuity ratio acceptable: discoveries=20, phase1b_items=27, ratio=0.7407
PASS: No curator notes detected; Phase 1.5 not required for this cycle
PASS: Provenance receipts verified (13 required phases, run_id=20260221T145616Z-3829)
PASS: Scope contract fields and VS Code density checks passed
WARN: expected_versions.vscode has 1 versions; recommended >= 2 for a 8-day range.
PASS: Phase 1A includes expected VS Code version 1.110
PASS: Phase 1B VS Code interim includes expected version 1.110
PASS: Phase 1C discoveries retain expected VS Code version signal 1.110
PASS: Final output references expected VS Code version signal 1.110
PASS: Phase 1B GitHub interim includes Copilot CLI releases index URL
PASS: Phase 1B GitHub interim includes Copilot CLI release-tag URLs (2 >= 2)
PASS: Final output includes Copilot CLI releases index URL
PASS: Final output includes Copilot CLI release-tag URLs (2 >= 1)
PASS: Event coverage stats: virtual=11 in_person=8 total=19 min_required=4
PASS: Event row URL stats: unique=23 rows_with_links=23 max_reuse=1
PASS: Event source deep-link stats: github_resources=7 reactor=0
FAIL: Phase 2 event sources deep-link floor not met for Reactor (0 < 6)
PASS: Fresh marker checks completed: workspace/newsletter_run_marker_2026-02-14_to_2026-02-21.json
PASS: validate_newsletter.sh passed for final output
```

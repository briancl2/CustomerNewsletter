# Test Fixtures

Small subset of benchmark data committed for CI. The full benchmark dataset (16 cycles, 339 files) is gitignored.

## Contents

| File | Source | Used By |
|------|--------|---------|
| `dec2025_curated.md` | `benchmark/2025-12_december/intermediates/phase3_curated_sections.md` | `test_benchmark_regression.sh` |
| `aug2025_curated.md` | `benchmark/2025-08_august/intermediates/phase2_draft_sections_august_87b5cb30.md` | `test_benchmark_regression.sh` |
| `jun2025_curated.md` | `benchmark/2025-06_june/intermediates/phase_2_content_curation.md` | `test_benchmark_regression.sh` |

These are curated section outputs from 3 benchmark cycles, compared against their published gold standards in `archive/` by `tools/score-selection.sh`.

When `benchmark/` is available locally, the regression test uses the full benchmark files. In CI (where benchmark/ is gitignored), it falls back to these fixtures.

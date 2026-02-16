# Benchmark Modes

Benchmark mode configs tighten strict validation for reproducibility runs.

Use with:

```bash
bash tools/validate_pipeline_strict.sh START_DATE END_DATE --benchmark-mode <mode>
```

Where `<mode>` is either:

- a mode name in this folder (for example `feb2026_consistency`)
- or an explicit path to a JSON config file

## Config Schema (current)

```json
{
  "name": "mode_name",
  "description": "human-readable intent",
  "date_range": { "start": "YYYY-MM-DD", "end": "YYYY-MM-DD" },
  "section_contract": {
    "required_h1": ["Heading"],
    "required_h2": ["Heading"],
    "required_h1_regex": ["^Regex$"],
    "require_any": [
      {
        "id": "rule_id",
        "options": [
          { "h1": "Heading" },
          { "h1": "Heading", "h2": "Subheading" }
        ]
      }
    ],
    "min_links": 100,
    "min_words": 2500,
    "min_h1_count": 6
  }
}
```

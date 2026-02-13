# Maintenance Procedure

Monthly workflow for keeping the knowledge base current.

## Monthly Cycle (run after each newsletter)

### Step 1: Poll Feeds (~5 min)

```bash
python3 .github/skills/kb-maintenance/scripts/poll_sources.py
```

The script:
1. Reads `kb/SOURCES.yaml`
2. Validates each feed URL (https only; blocks file://, ftp://, private hosts)
3. For each source with `update_feeds.type` != "none":
   - Fetches the feed URL
   - For RSS/Atom feeds: parses XML entries (title, link, date) and reports them
   - For API feeds: reports response length (JSON parsing is manual)
4. Outputs a delta report listing discovered entries

**Note**: The `last_checked` field is read but not yet used for date filtering. Entries are listed regardless of last_checked. Manual review determines which are new.

### Step 2: Check Link Health (~10 min)

```bash
python3 .github/skills/kb-maintenance/scripts/check_link_health.py
```

The script:
1. Reads `kb/SOURCES.yaml`
2. Validates each URL scheme (https only)
3. For each source, validates:
   - `canonical_urls` (HTTP HEAD, falling back to lightweight GET if HEAD fails)
   - `latest_known.reference_url` (if present)
4. Reports: status code, redirect URL (if redirected), or error message

### Step 3: Review and Fix

- Fix broken URLs in SOURCES.yaml
- Add new sources discovered during newsletter creation
- Update `last_checked` date for polled sources
- Remove sources that are permanently dead

### Step 4: Update Snapshot

Refresh `kb/CURRENT_STATE_SNAPSHOT.md` with:
- Date of last maintenance
- Summary of changes
- Known issues or gaps

## Feed Type Details

### RSS/Atom Feeds
- Parse XML with standard library
- Look for `<item>` (RSS) or `<entry>` (Atom) elements
- Extract: title, link, pubDate/updated
- Filter by date

### API Endpoints
- JetBrains uses JSON API with pagination
- Parse JSON, extract version info and dates
- Follow pagination until dates fall before last_checked

### No Feed (Manual)
- Sources with `update_feeds.type: "none"` require manual checking
- Visit canonical_url and check for updates
- These are typically documentation pages that change infrequently

## Update Cadence Expectations

| Source Category | Expected Update Frequency |
|----------------|--------------------------|
| GitHub Blog/Changelog | Weekly (multiple entries) |
| VS Code | Monthly (one release) |
| Visual Studio | Bi-weekly (patch releases) |
| JetBrains Plugin | Weekly (2-3 releases) |
| Xcode | Monthly (1-2 releases) |
| Documentation | Varies (check monthly) |

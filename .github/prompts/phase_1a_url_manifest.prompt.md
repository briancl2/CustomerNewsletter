---
agent: customer_newsletter
---

## Phase 1A: URL Manifest - Candidate Generation & Validation

<token_budget>
**Target: 10,000-20,000 tokens total**

**Strategy**: Generate candidate URLs from known patterns, then spot-check validity
- Generate candidates: ~1,000 tokens
- Spot-check validation: 200-500 tokens per source
- Manifest output: ~2,000 tokens
</token_budget>

<approach>
**Key Insight**: We know URL architectures. Generate candidates FIRST, validate SECOND.

1. **Generate Candidate URLs** from patterns (no fetching yet)
2. **Minimal Validation**: Spot-check 1-2 URLs per source to confirm pattern
3. **Boundary Check**: Verify earliest/latest candidates span DATE_RANGE
4. **Output Manifest**: List of validated URLs for Phase 1B

**NOT Phase 1A's job**: Extracting content, reading changelogs, parsing features
</approach>

### Inputs
- **DATE_RANGE**: YYYY-MM-DD to YYYY-MM-DD
- **Reference Year**: Extracted from DATE_RANGE

### Execution Strategy

**STEP 1: Generate Candidates** (~5 min, 1,000 tokens)
For each source, generate candidate URLs using known patterns + DATE_RANGE months

**STEP 2: Spot-Check** (~10 min, 2,000-5,000 tokens)  
Fetch 1-2 URLs per source to confirm:
- URL exists (not 404)
- Contains expected date/version info
- Pattern is correct

**STEP 3: Write Manifest** (~2 min, 2,000 tokens)
Output validated candidate URLs for Phase 1B

---

## URL Pattern Reference & Candidate Generation

### 1. VS Code
**Pattern**: `https://code.visualstudio.com/updates/v1_{VERSION}`
**Candidate Generation**:
```
Start: v1_104 (Aug → Sept release)
Range: v1_105 (Sept → Oct), v1_106 (Oct → Nov), v1_107 (Nov → Dec)
```
**Spot-Check**: Fetch updates index OR v1_105 to verify Oct release date

### 2. Visual Studio
**Pattern**: `https://learn.microsoft.com/en-us/visualstudio/releases/{YEAR}/release-notes`
**Candidate Generation**:
```
VS 2022: Base URL (has Oct/Nov/Dec versions)
VS 2026: Base URL (GA Nov 24, 2025)
```
**Spot-Check**: Fetch both base URLs to confirm version lists

### 3. GitHub Changelog
**Pattern**: `https://github.blog/changelog/{YEAR}/{MM}/`
**Candidate Generation**:
```
/2025/10/ (Oct 6-31)
/2025/11/ (full month)
/2025/12/ (Dec 1-3)
```
**Spot-Check**: Sample one month URL to verify structure

### 4. GitHub Blog
**Pattern**: `https://github.blog/latest/page/{N}/`
**Candidate Generation**:
```
Page 1-5 (estimate based on ~20 posts/page, weekly cadence)
```
**Spot-Check**: Fetch page 1, estimate pagination depth

### 5. JetBrains
**Pattern**: `https://plugins.jetbrains.com/api/plugins/17718/updates?page={N}&size=8`
**Candidate Generation**:
```
Pages 1-3 (estimate ~2-3 releases/week = 16-24 versions in range)
```
**Spot-Check**: Fetch API page 1, parse JSON for date range

### 6. Copilot for Xcode
**Pattern**: `https://github.com/github/CopilotForXcode/blob/main/CHANGELOG.md`
**Candidate**: Single file
**Spot-Check**: Not needed (single URL)

---

## Phase 1A Execution

### Step 1: Generate Candidates (~2 min)
Based on DATE_RANGE, list candidate URLs for each source.

### Step 2: Spot-Check (~5-10 min, 2,000-5,000 tokens)
**Minimum validation per source**:
- VS Code: Check updates index OR one version page for date
- Visual Studio: Confirm both 2022 and 2026 have releases
- GitHub Changelog: Sample one month URL
- GitHub Blog: Check page 1 date range
- JetBrains: Fetch API page 1, check date range  
- Xcode: Confirm CHANGELOG.md exists

**Key checks**:
- URLs don't 404
- Dates align with expectations
- Boundaries span DATE_RANGE

### Step 3: Write Manifest (~2 min)
Output format:
```markdown
# Phase 1A URL Manifest
DATE_RANGE: {start} to {end}
Generated: {date}

## URLs by Source

### VS Code
- v1_105: https://... (Oct 9)
- v1_106: https://... (Nov 12)

### Visual Studio 2022
- Base URL: https://... (Oct-Nov versions)

[etc.]

## Validation
- [x] Boundaries verified
- [x] No 0-entry months
- [x] Ready for Phase 1B
```

### Success Criteria
- All candidate URLs listed
- Spot-checks pass
- Earliest ≤ start, latest ≥ end
- No month in DATE_RANGE has 0 entries
```

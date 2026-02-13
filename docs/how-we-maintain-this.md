# How We Maintain This

## Source of Truth Model

- Private working repository: `briancl2/private-source-repo`
- Public product repository: `briancl2/CustomerNewsletter`

The public repo is a sanitized, release-ready snapshot of the working system.

## What Gets Mirrored

- Agents, skills, prompts, tools, tests, docs
- Sample archive/output artifacts
- Report and process documentation

## What Does Not Get Mirrored

- Sensitive operational notes
- Environment-specific local data
- Experimental artifacts not ready for public use

## Sync Approach

Use allowlisted publish automation from the private repo:
- `tools/publish_public_snapshot.sh`
- `tools/public_snapshot_allowlist.txt`

The sync script validates, checks for denylisted terms, and stages a clean public snapshot.

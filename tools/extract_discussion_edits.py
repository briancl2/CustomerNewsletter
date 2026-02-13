#!/usr/bin/env python3
"""Extract discussion edit history from GitHub CustomerNewsletter repo.

Uses the GraphQL API to fetch all revisions of each discussion,
computes diffs between consecutive revisions, and stores as benchmark data.

Usage: python3 tools/extract_discussion_edits.py [--output-dir benchmark/polishing]
Requires: gh CLI authenticated (uses `gh auth token`)
"""

import argparse
import difflib
import json
import os
import subprocess
import sys
from pathlib import Path


def get_gh_token():
    """Get GitHub token from gh CLI."""
    result = subprocess.run(["gh", "auth", "token"], capture_output=True, text=True)
    if result.returncode != 0:
        print("Error: gh auth token failed. Run 'gh auth login' first.", file=sys.stderr)
        sys.exit(1)
    return result.stdout.strip()


def graphql_query(token, query):
    """Execute a GraphQL query against GitHub API."""
    import urllib.request
    req = urllib.request.Request(
        "https://api.github.com/graphql",
        data=json.dumps({"query": query}).encode(),
        headers={
            "Authorization": f"bearer {token}",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())


def fetch_discussions(token, owner="briancl2", repo="CustomerNewsletter"):
    """Fetch all discussions with edit counts."""
    query = f"""query {{
        repository(owner: "{owner}", name: "{repo}") {{
            discussions(first: 50, orderBy: {{field: CREATED_AT, direction: DESC}}) {{
                nodes {{
                    number
                    title
                    createdAt
                    body
                    userContentEdits(first: 1) {{
                        totalCount
                    }}
                }}
            }}
        }}
    }}"""
    data = graphql_query(token, query)
    return data["data"]["repository"]["discussions"]["nodes"]


def fetch_edits(token, owner, repo, discussion_number, page_size=50):
    """Fetch all edit revisions for a discussion (may need pagination)."""
    all_edits = []
    has_next = True
    cursor = None

    while has_next:
        after_clause = f', after: "{cursor}"' if cursor else ""
        query = f"""query {{
            repository(owner: "{owner}", name: "{repo}") {{
                discussion(number: {discussion_number}) {{
                    userContentEdits(first: {page_size}{after_clause}) {{
                        pageInfo {{
                            hasNextPage
                            endCursor
                        }}
                        nodes {{
                            editedAt
                            diff
                            editor {{
                                login
                            }}
                        }}
                    }}
                }}
            }}
        }}"""
        data = graphql_query(token, query)
        edits_data = data["data"]["repository"]["discussion"]["userContentEdits"]
        all_edits.extend(edits_data["nodes"])
        has_next = edits_data["pageInfo"]["hasNextPage"]
        cursor = edits_data["pageInfo"]["endCursor"]

    return all_edits


def compute_diff(old_text, new_text, old_label, new_label):
    """Compute unified diff between two text revisions."""
    old_lines = old_text.splitlines(keepends=True)
    new_lines = new_text.splitlines(keepends=True)
    return list(difflib.unified_diff(old_lines, new_lines,
                                      fromfile=old_label, tofile=new_label))


def classify_diff(diff_lines):
    """Classify a diff into change types."""
    additions = 0
    deletions = 0
    for line in diff_lines:
        if line.startswith("+") and not line.startswith("+++"):
            additions += 1
        elif line.startswith("-") and not line.startswith("---"):
            deletions += 1

    if additions > 0 and deletions == 0:
        return "addition"
    elif deletions > 0 and additions == 0:
        return "removal"
    elif additions > 0 and deletions > 0:
        if abs(additions - deletions) <= 2:
            return "rewrite"
        elif additions > deletions * 2:
            return "expansion"
        elif deletions > additions * 2:
            return "compression"
        else:
            return "mixed"
    return "none"


def main():
    parser = argparse.ArgumentParser(description="Extract discussion edit history")
    parser.add_argument("--output-dir", default="benchmark/polishing",
                        help="Output directory for extracted data")
    parser.add_argument("--owner", default="briancl2")
    parser.add_argument("--repo", default="CustomerNewsletter")
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    token = get_gh_token()
    print("Fetching discussions...")
    discussions = fetch_discussions(token, args.owner, args.repo)

    manifest = {
        "extracted_at": subprocess.run(["date", "-u", "+%Y-%m-%dT%H:%M:%SZ"],
                                        capture_output=True, text=True).stdout.strip(),
        "repo": f"{args.owner}/{args.repo}",
        "discussions": [],
        "total_snapshots": 0,
        "total_diffs": 0,
    }

    for disc in discussions:
        num = disc["number"]
        title = disc["title"]
        edit_count = disc["userContentEdits"]["totalCount"]

        print(f"  #{num}: {title} ({edit_count} edits)")

        disc_dir = output_dir / f"discussion_{num:02d}"
        disc_dir.mkdir(exist_ok=True)

        # Save initial body
        initial_body = disc["body"]
        (disc_dir / "initial.md").write_text(initial_body)

        disc_meta = {
            "number": num,
            "title": title,
            "created_at": disc["createdAt"],
            "edit_count": edit_count,
            "diff_count": 0,
            "snapshots": [],
            "diffs": [],
        }

        if edit_count == 0:
            disc_meta["snapshots"].append({
                "index": 0,
                "timestamp": disc["createdAt"],
                "file": "initial.md",
            })
            manifest["total_snapshots"] += 1
        else:
            # Fetch all edits (returned newest-first)
            edits = fetch_edits(token, args.owner, args.repo, num)
            # Reverse to chronological order (oldest first)
            edits.reverse()

            for i, edit in enumerate(edits):
                snapshot_file = f"revision_{i:02d}.md"
                body = edit["diff"] if edit["diff"] else initial_body
                (disc_dir / snapshot_file).write_text(body)

                disc_meta["snapshots"].append({
                    "index": i,
                    "timestamp": edit["editedAt"],
                    "editor": edit["editor"]["login"] if edit["editor"] else "unknown",
                    "file": snapshot_file,
                    "chars": len(body),
                })

            # Save final version
            if edits:
                final_body = edits[-1]["diff"] if edits[-1]["diff"] else initial_body
                (disc_dir / "final.md").write_text(final_body)

            # Compute diffs between consecutive revisions
            for i in range(1, len(edits)):
                old_body = edits[i-1]["diff"] if edits[i-1]["diff"] else initial_body
                new_body = edits[i]["diff"] if edits[i]["diff"] else initial_body

                diff_lines = compute_diff(
                    old_body, new_body,
                    f"revision_{i-1:02d} ({edits[i-1]['editedAt']})",
                    f"revision_{i:02d} ({edits[i]['editedAt']})"
                )

                diff_file = f"diff_{i-1:02d}_to_{i:02d}.diff"
                (disc_dir / diff_file).write_text("".join(diff_lines))

                change_type = classify_diff(diff_lines)
                additions = sum(1 for l in diff_lines if l.startswith("+") and not l.startswith("+++"))
                deletions = sum(1 for l in diff_lines if l.startswith("-") and not l.startswith("---"))

                disc_meta["diffs"].append({
                    "from_revision": i - 1,
                    "to_revision": i,
                    "from_timestamp": edits[i-1]["editedAt"],
                    "to_timestamp": edits[i]["editedAt"],
                    "file": diff_file,
                    "change_type": change_type,
                    "additions": additions,
                    "deletions": deletions,
                    "diff_lines": len(diff_lines),
                })

            disc_meta["diff_count"] = len(edits) - 1 if len(edits) > 1 else 0
            manifest["total_snapshots"] += len(edits)
            manifest["total_diffs"] += disc_meta["diff_count"]

        manifest["discussions"].append(disc_meta)

    # Write manifest
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n"
    )

    print(f"\nExtraction complete:")
    print(f"  Discussions: {len(manifest['discussions'])}")
    print(f"  Snapshots: {manifest['total_snapshots']}")
    print(f"  Diffs: {manifest['total_diffs']}")
    print(f"  Output: {output_dir}/")


if __name__ == "__main__":
    main()

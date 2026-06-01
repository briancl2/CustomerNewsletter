#!/usr/bin/env python3
"""
Poll RSS/Atom feeds from kb/SOURCES.yaml and report new entries.

Usage:
    python3 poll_sources.py [--dry-run]

Options:
    --dry-run    Show what would be polled without actually fetching
"""

import sys
import os
import re
import socket
import ipaddress
import xml.etree.ElementTree as ET
from datetime import datetime
from email.utils import parsedate_to_datetime
from urllib.parse import urlparse

try:
    import yaml
except ImportError:
    print("Error: PyYAML required. Install with: pip3 install pyyaml")
    sys.exit(1)

ALLOWED_SCHEMES = {"https"}

BLOCKED_HOSTNAME_PATTERNS = re.compile(
    r"^(localhost|.*\.local|.*\.internal)$", re.IGNORECASE
)


def load_sources(path="kb/SOURCES.yaml"):
    """Load and parse SOURCES.yaml."""
    if not os.path.exists(path):
        print(f"Error: {path} not found")
        sys.exit(1)
    with open(path, "r") as f:
        return yaml.safe_load(f)


def is_private_ip(hostname):
    """Check if a hostname resolves to a private/loopback/link-local address."""
    try:
        addr = ipaddress.ip_address(hostname)
        return addr.is_private or addr.is_loopback or addr.is_link_local or addr.is_reserved
    except ValueError:
        pass
    try:
        infos = socket.getaddrinfo(hostname, None, socket.AF_UNSPEC, socket.SOCK_STREAM)
        for _family, _type, _proto, _canon, sockaddr in infos:
            addr = ipaddress.ip_address(sockaddr[0])
            if addr.is_private or addr.is_loopback or addr.is_link_local or addr.is_reserved:
                return True
    except (socket.gaierror, OSError):
        pass
    return False


def validate_url(url):
    """Validate URL scheme, hostname, and block private/loopback targets."""
    parsed = urlparse(url)
    if parsed.scheme not in ALLOWED_SCHEMES:
        return False, f"blocked scheme '{parsed.scheme}' (allowed: {ALLOWED_SCHEMES})"
    if not parsed.hostname:
        return False, "missing hostname"
    if BLOCKED_HOSTNAME_PATTERNS.match(parsed.hostname):
        return False, f"blocked hostname '{parsed.hostname}' (localhost/internal)"
    if is_private_ip(parsed.hostname):
        return False, f"blocked private/loopback IP for '{parsed.hostname}'"
    return True, ""


def get_pollable_sources(data):
    """Filter to sources that have poll-able feeds."""
    pollable = []
    for source in data.get("sources", []):
        feeds = source.get("update_feeds", [])
        for feed in feeds:
            if feed.get("type", "none") != "none" and feed.get("url"):
                pollable.append({
                    "id": source.get("id"),
                    "name": source.get("name"),
                    "feed_type": feed["type"],
                    "feed_url": feed["url"],
                    "last_checked": source.get("last_checked", ""),
                })
    return pollable


def parse_date_flexible(date_str):
    """Try to parse a date string from RSS/Atom into a datetime. Returns None on failure."""
    if not date_str:
        return None
    # RFC 2822 (RSS pubDate)
    try:
        return parsedate_to_datetime(date_str)
    except (ValueError, TypeError):
        pass
    # ISO 8601 (Atom updated)
    for fmt in ("%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%d"):
        try:
            return datetime.strptime(date_str, fmt)
        except ValueError:
            continue
    return None


def parse_rss_entries(content, last_checked):
    """Parse RSS/Atom XML and return entries, filtering by last_checked when possible."""
    cutoff = None
    if last_checked:
        cutoff = parse_date_flexible(str(last_checked))
        # If last_checked is just a date string like "2026-02-10", parse it
        if cutoff is None:
            try:
                cutoff = datetime.strptime(str(last_checked), "%Y-%m-%d")
            except ValueError:
                pass

    all_entries = []
    filtered_entries = []
    try:
        root = ET.fromstring(content)
        # RSS 2.0: channel/item
        for item in root.iter("item"):
            title_el = item.find("title")
            link_el = item.find("link")
            date_el = item.find("pubDate")
            entry = {
                "title": title_el.text if title_el is not None else "(no title)",
                "link": link_el.text if link_el is not None else "",
                "date": date_el.text if date_el is not None else "",
            }
            all_entries.append(entry)
            entry_dt = parse_date_flexible(entry["date"])
            if cutoff is None or entry_dt is None or entry_dt.replace(tzinfo=None) > cutoff.replace(tzinfo=None):
                filtered_entries.append(entry)

        # Atom: entry
        ns = {"atom": "http://www.w3.org/2005/Atom"}
        for atom_entry in root.findall(".//atom:entry", ns):
            title_el = atom_entry.find("atom:title", ns)
            link_el = atom_entry.find("atom:link", ns)
            date_el = atom_entry.find("atom:updated", ns)
            entry = {
                "title": title_el.text if title_el is not None else "(no title)",
                "link": link_el.get("href", "") if link_el is not None else "",
                "date": date_el.text if date_el is not None else "",
            }
            all_entries.append(entry)
            entry_dt = parse_date_flexible(entry["date"])
            if cutoff is None or entry_dt is None or entry_dt.replace(tzinfo=None) > cutoff.replace(tzinfo=None):
                filtered_entries.append(entry)
    except ET.ParseError as e:
        all_entries.append({"title": f"(XML parse error: {e})", "link": "", "date": ""})
        return all_entries, all_entries

    return all_entries, filtered_entries


def main():
    dry_run = "--dry-run" in sys.argv

    data = load_sources()
    sources = get_pollable_sources(data)

    print("# Feed Poll Report")
    print(f"Generated: {datetime.now().isoformat()}")
    print(f"Mode: {'DRY RUN' if dry_run else 'LIVE'}")
    print(f"Pollable sources: {len(sources)}")
    print()

    total_all = 0
    total_new = 0

    for src in sources:
        print(f"## {src['name']} ({src['id']})")
        print(f"  Feed type: {src['feed_type']}")
        print(f"  Feed URL: {src['feed_url']}")
        print(f"  Last checked: {src['last_checked']}")

        # Validate URL scheme and hostname
        url_ok, url_err = validate_url(src["feed_url"])
        if not url_ok:
            print(f"  Status: BLOCKED - {url_err}")
            print()
            continue

        if dry_run:
            print("  Status: SKIPPED (dry run)")
        else:
            try:
                import urllib.request
                req = urllib.request.Request(
                    src["feed_url"],
                    headers={"User-Agent": "newsletter-kb-maintenance/1.0"}
                )
                with urllib.request.urlopen(req, timeout=15) as resp:
                    status = resp.getcode()
                    content_type = resp.headers.get("Content-Type", "unknown")
                    body = resp.read().decode("utf-8", errors="replace")
                    print(f"  Status: {status}")
                    print(f"  Content-Type: {content_type}")

                    # Parse feed entries for RSS/Atom types
                    if src["feed_type"] in ("rss", "atom"):
                        all_entries, new_entries = parse_rss_entries(body, src["last_checked"])
                        print(f"  Total entries in feed: {len(all_entries)}")
                        print(f"  New since last_checked: {len(new_entries)}")
                        for e in new_entries[:5]:  # show first 5 new
                            print(f"    - {e['title'][:80]}")
                        if len(new_entries) > 5:
                            print(f"    ... and {len(new_entries) - 5} more")
                        total_all += len(all_entries)
                        total_new += len(new_entries)
                    elif src["feed_type"] == "api":
                        print(f"  Response length: {len(body)} chars (JSON parsing not implemented)")
            except Exception as e:
                print(f"  Status: ERROR - {e}")
        print()

    print(f"Done. {len(sources)} sources {'would be' if dry_run else 'were'} polled.")
    if not dry_run:
        print(f"Total entries in feeds: {total_all}")
        print(f"New entries (since last_checked): {total_new}")


if __name__ == "__main__":
    main()

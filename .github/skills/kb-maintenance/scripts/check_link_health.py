#!/usr/bin/env python3
"""
Check link health for canonical URLs in kb/SOURCES.yaml.

Usage:
    python3 check_link_health.py [--dry-run] [--sample N]

Options:
    --dry-run      Show what would be checked without fetching
    --sample N     Only check N randomly selected sources
"""

import sys
import os
import re
import socket
import ipaddress
import random
from datetime import datetime
from urllib.parse import urlparse

try:
    import yaml
except ImportError:
    print("Error: PyYAML required. Install with: pip3 install pyyaml")
    sys.exit(1)

ALLOWED_SCHEMES = {"https"}

# Hostnames that resolve to loopback/private and should never be fetched
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
        pass  # Not a bare IP; try DNS resolution
    try:
        infos = socket.getaddrinfo(hostname, None, socket.AF_UNSPEC, socket.SOCK_STREAM)
        for _family, _type, _proto, _canon, sockaddr in infos:
            addr = ipaddress.ip_address(sockaddr[0])
            if addr.is_private or addr.is_loopback or addr.is_link_local or addr.is_reserved:
                return True
    except (socket.gaierror, OSError):
        pass  # DNS failure handled elsewhere
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


def get_urls_to_check(data):
    """Extract all URLs that should be health-checked."""
    urls = []
    for source in data.get("sources", []):
        for url in source.get("canonical_urls", []):
            urls.append({
                "id": source.get("id"),
                "name": source.get("name"),
                "url": url,
                "type": "canonical",
            })
        ref_url = source.get("latest_known", {}).get("reference_url", "")
        if ref_url:
            urls.append({
                "id": source.get("id"),
                "name": source.get("name"),
                "url": ref_url,
                "type": "reference",
            })
    return urls


def check_url(url, timeout=10):
    """Check URL health. Tries HEAD first, falls back to lightweight GET."""
    import urllib.request

    headers = {"User-Agent": "newsletter-kb-maintenance/1.0"}

    # Try HEAD first (cheapest)
    try:
        req = urllib.request.Request(url, method="HEAD", headers=headers)
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.getcode(), resp.url, None
    except Exception:
        pass  # Fall through to GET

    # HEAD failed (some servers reject it); try lightweight GET with Range
    try:
        get_headers = {**headers, "Range": "bytes=0-0"}
        req = urllib.request.Request(url, method="GET", headers=get_headers)
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.getcode(), resp.url, None
    except Exception as e:
        return None, None, str(e)


def main():
    dry_run = "--dry-run" in sys.argv
    sample_n = None
    if "--sample" in sys.argv:
        idx = sys.argv.index("--sample")
        if idx + 1 < len(sys.argv):
            try:
                sample_n = int(sys.argv[idx + 1])
            except ValueError:
                print(f"Error: --sample requires a numeric argument")
                sys.exit(1)

    data = load_sources()
    urls = get_urls_to_check(data)

    if sample_n and sample_n < len(urls):
        urls = random.sample(urls, sample_n)

    print("# Link Health Report")
    print(f"Generated: {datetime.now().isoformat()}")
    print(f"Mode: {'DRY RUN' if dry_run else 'LIVE'}")
    print(f"URLs to check: {len(urls)}")
    print()

    healthy = 0
    broken = 0
    errors = 0
    blocked = 0

    for entry in urls:
        print(f"## {entry['name']} ({entry['type']})")
        print(f"  URL: {entry['url']}")

        # Validate URL scheme before fetching
        url_ok, url_err = validate_url(entry["url"])
        if not url_ok:
            print(f"  Status: BLOCKED - {url_err}")
            blocked += 1
            print()
            continue

        if dry_run:
            print("  Status: SKIPPED (dry run)")
            print()
            continue

        status, final_url, error = check_url(entry["url"])
        if error:
            print(f"  Status: ERROR - {error}")
            errors += 1
        else:
            print(f"  Status: {status}")
            if final_url and final_url != entry["url"]:
                print(f"  Redirected to: {final_url}")
            if 200 <= status < 400:
                healthy += 1
            else:
                broken += 1
        print()

    print("## Summary")
    print(f"  Healthy: {healthy}")
    print(f"  Broken: {broken}")
    print(f"  Errors: {errors}")
    print(f"  Blocked: {blocked}")
    print(f"  Total: {len(urls)}")


if __name__ == "__main__":
    main()

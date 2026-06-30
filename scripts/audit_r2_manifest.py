#!/usr/bin/env python3
"""Audit manifest.json clip paths against live R2 worker URLs."""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets" / "signs" / "manifest.json"
BASE_URL = "https://signbridge-sign-assets.signbridge-adesso.workers.dev"


def manifest_keys(manifest: dict) -> set[str]:
    keys: set[str] = set()
    for lang in ("asl", "isl"):
        for path in set(manifest.get(lang, {}).values()):
            name = Path(path).name
            keys.add(f"{lang}/{name}")
    return keys


def check_key(key: str, timeout: float) -> tuple[str, int]:
    url = f"{BASE_URL}/{key}"
    request = urllib.request.Request(
        url,
        method="GET",
        headers={
            "User-Agent": "signbridge-r2-audit/1.0",
            "Range": "bytes=0-0",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return key, response.status
    except urllib.error.HTTPError as error:
        # 206 Partial Content is fine for range GET.
        if error.code in (200, 206):
            return key, 200
        return key, error.code
    except Exception:
        return key, 0


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workers", type=int, default=24)
    parser.add_argument("--timeout", type=float, default=15.0)
    parser.add_argument("--sample", type=int, default=0, help="Only check N keys (0 = all)")
    args = parser.parse_args()

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    keys = sorted(manifest_keys(manifest))
    if args.sample > 0:
        keys = keys[: args.sample]

    total = len(keys)
    print(f"Checking {total} manifest clip(s) against {BASE_URL}")

    missing: list[str] = []
    errors: list[tuple[str, int]] = []

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = [pool.submit(check_key, key, args.timeout) for key in keys]
        done = 0
        for future in as_completed(futures):
            key, status = future.result()
            done += 1
            if status in (200, 206):
                pass
            elif status == 404:
                missing.append(key)
            else:
                errors.append((key, status))
            if done % 500 == 0 or done == total:
                print(f"  checked {done}/{total}...")

    print()
    print(f"OK:      {total - len(missing) - len(errors)}")
    print(f"Missing: {len(missing)}")
    print(f"Errors:  {len(errors)}")

    if missing:
        print("\nMissing on R2 (first 40):")
        for key in missing[:40]:
            print(f"  {key}")
        if len(missing) > 40:
            print(f"  ... and {len(missing) - 40} more")

    if errors:
        print("\nNon-404 errors (first 20):")
        for key, status in errors[:20]:
            print(f"  {key}: {status}")

    out = ROOT / "scripts" / "data" / "r2_audit_missing.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({"missing": missing, "errors": errors}, indent=2) + "\n")
    print(f"\nWrote {out}")

    if missing or errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

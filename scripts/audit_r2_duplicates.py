#!/usr/bin/env python3
"""Audit Cloudflare R2 for duplicate objects and manifest mismatches."""

from __future__ import annotations

import json
import re
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets" / "signs" / "manifest.json"
ACCOUNT_ID = "37e94199bf2d5ceaaf638a86a3919102"
BUCKET = "signbridge-sign-videos"
WRANGLER_CONFIG = Path.home() / "Library/Preferences/.wrangler/config/default.toml"
OUT = ROOT / "scripts" / "data" / "r2_duplicate_audit.json"


def load_oauth_token() -> str:
    text = WRANGLER_CONFIG.read_text(encoding="utf-8")
    match = re.search(r'^oauth_token\s*=\s*"([^"]+)"', text, re.MULTILINE)
    if not match:
        raise SystemExit("Could not read wrangler oauth_token. Run: wrangler login")
    return match.group(1)


def list_r2_objects(token: str) -> list[dict]:
    objects: list[dict] = []
    cursor = ""
    while True:
        query = {"per_page": "1000"}
        if cursor:
            query["cursor"] = cursor
        url = (
            f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}"
            f"/r2/buckets/{BUCKET}/objects?{urllib.parse.urlencode(query)}"
        )
        request = urllib.request.Request(
            url,
            headers={"Authorization": f"Bearer {token}"},
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            payload = json.loads(response.read().decode("utf-8"))
        if not payload.get("success"):
            raise SystemExit(f"R2 list failed: {payload}")
        result = payload.get("result", [])
        objects.extend(result)
        cursor = payload.get("result_info", {}).get("cursor")
        if not cursor:
            break
        print(f"  listed {len(objects)} objects...")
    return objects


def manifest_r2_keys(manifest: dict) -> set[str]:
    keys: set[str] = set()
    for lang in ("asl", "isl"):
        for path in set(manifest.get(lang, {}).values()):
            keys.add(f"{lang}/{Path(path).name}")
    return keys


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    expected = manifest_r2_keys(manifest)
    expected.add("manifest.json")

    print(f"Listing R2 bucket: {BUCKET}")
    token = load_oauth_token()
    objects = list_r2_objects(token)

    by_key = {obj["key"]: obj for obj in objects}
    r2_keys = set(by_key)

    # Content duplicates: same size + etag
    by_fingerprint: dict[tuple[int, str], list[str]] = defaultdict(list)
    for key, obj in by_key.items():
        if key == "manifest.json" or not key.endswith(".mp4"):
            continue
        etag = (obj.get("etag") or "").strip('"')
        size = int(obj.get("size", 0))
        by_fingerprint[(size, etag)].append(key)

    content_dupes = {
        f"{size}:{etag}": sorted(keys)
        for (size, etag), keys in by_fingerprint.items()
        if etag and len(keys) > 1
    }

    # Manifest alias duplicates (same path, multiple gloss keys)
    alias_groups: dict[str, dict[str, list[str]]] = {}
    for lang in ("asl", "isl"):
        by_path: dict[str, list[str]] = defaultdict(list)
        for gloss, path in manifest.get(lang, {}).items():
            by_path[path].append(gloss)
        alias_groups[lang] = {
            path: sorted(glosses)
            for path, glosses in by_path.items()
            if len(glosses) > 1
        }

    # Same filename in both languages (separate R2 objects, not content dupes)
    asl_names = {Path(p).name for p in set(manifest["asl"].values())}
    isl_names = {Path(p).name for p in set(manifest["isl"].values())}
    shared_names = sorted(asl_names & isl_names)

    missing_on_r2 = sorted(expected - r2_keys)
    orphans_on_r2 = sorted(
        key for key in r2_keys if key != "manifest.json" and key not in expected
    )

    total_bytes = sum(int(obj.get("size", 0)) for obj in objects)
    report = {
        "bucket": BUCKET,
        "r2_object_count": len(objects),
        "r2_total_gb": round(total_bytes / (1024**3), 2),
        "manifest_expected_clips": len(expected) - 1,
        "missing_on_r2_count": len(missing_on_r2),
        "orphans_on_r2_count": len(orphans_on_r2),
        "content_duplicate_groups": len(content_dupes),
        "content_duplicate_extra_objects": sum(len(v) - 1 for v in content_dupes.values()),
        "isl_alias_path_groups": len(alias_groups.get("isl", {})),
        "shared_filename_asl_isl": len(shared_names),
        "missing_on_r2_sample": missing_on_r2[:50],
        "orphans_on_r2_sample": orphans_on_r2[:50],
        "content_duplicates_sample": dict(list(content_dupes.items())[:20]),
        "isl_alias_sample": dict(list(alias_groups.get("isl", {}).items())[:10]),
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    print()
    print(f"R2 objects:           {report['r2_object_count']}")
    print(f"R2 storage:             {report['r2_total_gb']} GB")
    print(f"Manifest clips:         {report['manifest_expected_clips']}")
    print(f"Missing on R2:          {report['missing_on_r2_count']}")
    print(f"Orphans on R2:          {report['orphans_on_r2_count']}")
    print(f"Content duplicate sets: {report['content_duplicate_groups']}")
    print(f"Extra duplicate objs:   {report['content_duplicate_extra_objects']}")
    print(f"ISL alias path groups:  {report['isl_alias_path_groups']} (not extra R2 files)")
    print(f"Shared asl/isl names:   {report['shared_filename_asl_isl']} (different videos)")
    print(f"\nWrote {OUT}")


if __name__ == "__main__":
    main()

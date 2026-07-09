#!/usr/bin/env python3
"""Download ASL/ISL signer videos from Hugging Face into assets/signs/.

Sources (Hugging Face only):
  - ISL: bridgeconn/sign-dictionary-isl  (CC BY-SA 4.0)
  - ASL: ZahidYasinMittha/American-Sign-Language-Dataset  (MIT; scraped sources)

Usage:
  pip install -r scripts/requirements-hf-signs.txt
  python3 scripts/fetch_hf_sign_library.py --language both --mvp
  python3 scripts/fetch_hf_sign_library.py --language both --curriculum
  python3 scripts/fetch_hf_sign_library.py --verify

Review dataset licenses before shipping a commercial app.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import tarfile
from datetime import datetime, timezone
from pathlib import Path

from huggingface_hub import hf_hub_download, list_repo_files

ROOT = Path(__file__).resolve().parents[1]
SIGNS_DIR = ROOT / "assets" / "signs"
MANIFEST_PATH = SIGNS_DIR / "manifest.json"
CURRICULUM_ASL_CSV = ROOT / "scripts/data/asl_master_vocabulary.csv"
CURRICULUM_ISL_CSV = ROOT / "scripts/data/isl_master_vocabulary.csv"

ISL_REPO = "bridgeconn/sign-dictionary-isl"
ASL_REPO = "ZahidYasinMittha/American-Sign-Language-Dataset"
ASL_CSV_NAME = "Aslense Dataset.csv"
MIN_CLIP_BYTES = 1024

# HF videos live under part_N/<id>-<LABEL>.mp4; CSV filenames do not match paths.
ASL_GLOSS_LABELS: dict[str, str] = {
    "hi": "HELLO",
    "thank": "THANK YOU",
    "thanks": "THANK YOU",
    "thank_you": "THANK YOU",
    "excuse_me": "EXCUSE",
    "i": "ME",
    "wake_up": "WAKE UP",
    "call": "CALL ATTENTION",
    "what": "WHAT",
    "how": "HOW",
    "want": "WANT",
    "can": "CAN",
    "cannot": "CANNOT",
    "food": "FOOD",
    "eat": "EAT",
    "drink": "DRINK",
    "doctor": "DOCTOR",
    "hospital": "HOSPITAL",
    "fever": "FEVER",
    "emergency": "EMERGENCY",
    "airport": "AIRPORT",
    "taxi": "TAXI",
    "flight": "FLIGHT",
    "menu": "MENU",
    "mug": "MUG",
    "talk": "TALK",
    "this": "THIS",
    "broken": "BROKEN",
    "quick": "QUICK",
    "night": "NIGHT",
}

MVP_GLOSSES = {
    "HELLO",
    "HI",
    "PLEASE",
    "THANK",
    "THANKS",
    "THANK-YOU",
    "SORRY",
    "EXCUSE-ME",
    "HELP",
    "I",
    "ME",
    "YOU",
    "WE",
    "MY",
    "YOUR",
    "TODAY",
    "MORNING",
    "NIGHT",
    "NOW",
    "TOMORROW",
    "YESTERDAY",
    "YES",
    "NO",
    "GOOD",
    "BAD",
    "WANT",
    "NEED",
    "CAN",
    "CANNOT",
    "KNOW",
    "UNDERSTAND",
    "TRAVEL",
    "AIRPORT",
    "TRAIN",
    "TAXI",
    "PASSPORT",
    "FLIGHT",
    "HOTEL",
    "HOME",
    "COFFEE",
    "TEA",
    "WATER",
    "FOOD",
    "EAT",
    "DRINK",
    "MUG",
    "MENU",
    "DOCTOR",
    "HOSPITAL",
    "MEDICINE",
    "PAIN",
    "FEVER",
    "EMERGENCY",
    "CALL",
    "WAIT",
    "PAY",
    "BUY",
    "CLEAN",
    "WORK",
    "SLEEP",
    "WAKE-UP",
    "HOT",
    "COLD",
    "LATE",
    "BROKEN",
    "LOST",
    "HEAVY",
    "QUICK",
    "WHERE",
    "WHY",
    "HOW",
    "WHAT",
    "WHICH",
    "TIME",
    "TALK",
    "THIS",
    "FINISH",
    "MORE",
}

DEFAULT_ALIASES = {
    "asl": {
        "hi": "hello",
        "hey": "hello",
        "thanks": "thank_you",
        "thank": "thank_you",
        "okay": "good",
        "ok": "good",
        "fine": "good",
        "cannot": "cannot",
        "can_not": "cannot",
    },
    "isl": {
        "hi": "hello",
        "thanks": "thank_you",
        "thank": "thank_you",
        "okay": "good",
        "ok": "good",
    },
}


def normalize_key(raw: str) -> str:
    cleaned = re.sub(r"\s*\(\d+\)", "", raw.strip())
    key = cleaned.upper()
    key = re.sub(r"\s+", "-", key)
    key = re.sub(r"[^A-Z0-9-]", "", key)
    return key.lower().replace("-", "_")


def expand_gloss_keys(raw: str) -> set[str]:
    keys: set[str] = set()
    base = re.sub(r"\s*\(\d+\)", "", raw.strip())
    for fragment in re.split(r"[&/,]+", base):
        fragment = fragment.strip()
        if fragment:
            keys.add(normalize_key(fragment))
    if base:
        keys.add(normalize_key(base))
    if raw.strip():
        keys.add(normalize_key(raw))
    return {key for key in keys if key}


def glosses_from_metadata(metadata: dict) -> list[str]:
    glosses = metadata.get("glosses")
    if isinstance(glosses, list):
        return [str(gloss) for gloss in glosses if str(gloss).strip()]
    if isinstance(glosses, str) and glosses.strip():
        return [glosses]

    transcript = metadata.get("transcript")
    if isinstance(transcript, dict):
        text = transcript.get("text")
        if isinstance(text, str) and text.strip():
            return [text]
    if isinstance(transcript, str) and transcript.strip():
        return [transcript]

    transcripts = metadata.get("transcripts")
    if isinstance(transcripts, list):
        return [str(gloss) for gloss in transcripts if str(gloss).strip()]
    if isinstance(transcripts, str) and transcripts.strip():
        return [transcripts]
    return []


def normalize_gloss_set(values: set[str]) -> set[str]:
    return {normalize_key(value) for value in values}


def default_manifest() -> dict:
    return {
        "version": 2,
        "generated_at": None,
        "sources": {
            "asl": {
                "repo": ASL_REPO,
                "license": "MIT (verify scraped-source rights before commercial release)",
            },
            "isl": {
                "repo": ISL_REPO,
                "license": "CC-BY-SA-4.0",
            },
        },
        "aliases": DEFAULT_ALIASES,
        "asl": {},
        "isl": {},
    }


def load_manifest() -> dict:
    if MANIFEST_PATH.exists():
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        manifest.setdefault("version", 2)
        manifest.setdefault("aliases", DEFAULT_ALIASES)
        manifest.setdefault("asl", {})
        manifest.setdefault("isl", {})
        return manifest
    return default_manifest()


def save_manifest(manifest: dict) -> None:
    manifest["version"] = 2
    manifest["generated_at"] = datetime.now(timezone.utc).isoformat()
    manifest.setdefault("aliases", DEFAULT_ALIASES)
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def asset_path(language: str, key: str) -> str:
    return f"assets/signs/{language}/{key}.mp4"


def clip_on_disk(manifest: dict, language: str, key: str) -> bool:
    path = manifest.get(language, {}).get(key)
    if not path:
        return False
    disk_path = ROOT / path
    return disk_path.exists() and disk_path.stat().st_size >= MIN_CLIP_BYTES


def should_skip_resume(
    manifest: dict,
    language: str,
    key: str,
    *,
    resume: bool,
    sync_disk: bool,
) -> bool:
    if key not in manifest.get(language, {}):
        return False
    if not resume:
        return False
    if sync_disk:
        return clip_on_disk(manifest, language, key)
    return True


def cleanup_hub_file(path: str) -> None:
    file_path = Path(path)
    if file_path.exists():
        size_mb = file_path.stat().st_size / (1024 * 1024)
        file_path.unlink(missing_ok=True)
        print(f"[cache] removed {file_path.name} ({size_mb:.1f} MB)")


def register_clip(
    manifest: dict,
    language: str,
    keys: set[str],
    source_bytes: bytes,
    *,
    canonical_key: str,
) -> bool:
    if len(source_bytes) < MIN_CLIP_BYTES:
        return False

    out_dir = SIGNS_DIR / language
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{canonical_key}.mp4"
    if not out_path.exists() or out_path.stat().st_size < MIN_CLIP_BYTES:
        out_path.write_bytes(source_bytes)

    path = asset_path(language, canonical_key)
    manifest[language][canonical_key] = path
    for key in keys:
        manifest[language][key] = path
        if key != canonical_key:
            manifest["aliases"].setdefault(language, {})[key] = canonical_key
    return True


def iter_isl_samples(shard_path: str):
    with tarfile.open(shard_path, "r:*") as archive:
        members = [member for member in archive.getmembers() if member.isfile()]
        by_stem: dict[str, dict[str, tarfile.TarInfo]] = {}
        for member in members:
            name = Path(member.name).name
            if "." not in name:
                continue
            stem, ext = name.rsplit(".", 1)
            by_stem.setdefault(stem, {})[ext.lower()] = member

        for stem, parts in by_stem.items():
            if "json" not in parts or "mp4" not in parts:
                continue
            json_member = parts["json"]
            mp4_member = parts["mp4"]
            json_bytes = archive.extractfile(json_member).read()
            mp4_bytes = archive.extractfile(mp4_member).read()
            metadata = json.loads(json_bytes.decode("utf-8"))
            gloss_texts = glosses_from_metadata(metadata)
            keys: set[str] = set()
            for gloss in gloss_texts:
                keys.update(expand_gloss_keys(str(gloss)))
            if not keys:
                continue
            canonical = sorted(keys)[0]
            yield canonical, keys, mp4_bytes, mp4_member.name


def load_curriculum_keys(csv_path: Path, gloss_column: str) -> set[str]:
    keys: set[str] = set()
    with csv_path.open(encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            for column in (gloss_column, "english"):
                value = (row.get(column) or "").strip()
                if value:
                    keys.add(normalize_key(value))
    return keys


def update_curriculum_video_flags() -> None:
    manifest = load_manifest()
    for language, csv_path, gloss_column in (
        ("asl", CURRICULUM_ASL_CSV, "asl_gloss"),
        ("isl", CURRICULUM_ISL_CSV, "isl_gloss"),
    ):
        if not csv_path.exists():
            continue
        entries = manifest.get(language, {})
        aliases = manifest.get("aliases", {}).get(language, {})
        rows: list[dict[str, str]] = []
        with csv_path.open(encoding="utf-8") as handle:
            reader = csv.DictReader(handle)
            fieldnames = list(reader.fieldnames or [])
            for row in reader:
                keys = {
                    normalize_key(row.get("english", "")),
                    normalize_key(row.get(gloss_column, "")),
                }
                keys.discard("")
                has_video = any(
                    key in entries or aliases.get(key) in entries for key in keys
                )
                row["has_local_video"] = "yes" if has_video else "no"
                rows.append(row)
        with csv_path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)
        have = sum(1 for row in rows if row["has_local_video"] == "yes")
        print(f"[curriculum] {language}: {have}/{len(rows)} with local video")


def mvp_satisfied(manifest: dict, language: str, allowed: set[str] | None) -> bool:
    if allowed is None:
        return False
    keys = set(manifest.get(language, {}))
    return allowed.issubset(keys)


def fetch_isl(
    manifest: dict,
    *,
    allowed: set[str] | None,
    limit: int | None,
    resume: bool,
    sync_disk: bool,
    stop_when_complete: bool,
) -> int:
    shard_names = sorted(
        name
        for name in list_repo_files(ISL_REPO, repo_type="dataset")
        if name.endswith(".tar")
    )
    if not shard_names:
        raise RuntimeError(f"No .tar shards found in {ISL_REPO}")

    added = 0
    for shard_name in shard_names:
        if limit is not None and added >= limit:
            break
        if stop_when_complete and allowed and mvp_satisfied(manifest, "isl", allowed):
            break
        shard_path = hf_hub_download(
            ISL_REPO,
            filename=shard_name,
            repo_type="dataset",
        )
        try:
            for _canonical, keys, mp4_bytes, member_name in iter_isl_samples(shard_path):
                if limit is not None and added >= limit:
                    break
                if allowed is not None:
                    overlap = keys & allowed
                    if not overlap:
                        continue
                    canonical = sorted(overlap)[0]
                else:
                    overlap = keys
                    canonical = sorted(keys)[0]
                if should_skip_resume(
                    manifest,
                    "isl",
                    canonical,
                    resume=resume,
                    sync_disk=sync_disk,
                ):
                    continue
                if register_clip(
                    manifest,
                    "isl",
                    overlap,
                    mp4_bytes,
                    canonical_key=canonical,
                ):
                    added += 1
                    print(f"[isl] {canonical} <- {shard_name}:{member_name}")
                if stop_when_complete and allowed and mvp_satisfied(manifest, "isl", allowed):
                    break
        finally:
            cleanup_hub_file(shard_path)
        save_manifest(manifest)
        if stop_when_complete and allowed and mvp_satisfied(manifest, "isl", allowed):
            break
    return added


def asl_label_for_key(key: str) -> str:
    if key in ASL_GLOSS_LABELS:
        return ASL_GLOSS_LABELS[key]
    return key.upper().replace("_", " ")


def build_asl_path_index() -> dict[str, list[str]]:
    suffix_pattern = re.compile(r"^part_\d+/[0-9]+-(.+)\.mp4$", re.IGNORECASE)
    by_label: dict[str, list[str]] = {}
    for name in list_repo_files(ASL_REPO, repo_type="dataset"):
        match = suffix_pattern.match(name)
        if match:
            label = match.group(1).upper()
            by_label.setdefault(label, []).append(name)
    return by_label


def fetch_asl(
    manifest: dict,
    *,
    allowed: set[str] | None,
    limit: int | None,
    resume: bool,
    sync_disk: bool,
    stop_when_complete: bool,
) -> int:
    by_label = build_asl_path_index()
    targets: list[tuple[str, str]] = []
    if allowed is not None:
        for key in sorted(allowed):
            label = asl_label_for_key(key)
            if label in by_label:
                targets.append((key, label))
    else:
        for label in sorted(by_label):
            key = normalize_key(label)
            targets.append((key, label))

    added = 0
    for key, label in targets:
        if limit is not None and added >= limit:
            break
        if stop_when_complete and allowed and mvp_satisfied(manifest, "asl", allowed):
            break
        if should_skip_resume(
            manifest,
            "asl",
            key,
            resume=resume,
            sync_disk=sync_disk,
        ):
            continue
        video_path = by_label[label][0]
        local_video = hf_hub_download(
            ASL_REPO,
            filename=video_path,
            repo_type="dataset",
        )
        try:
            mp4_bytes = Path(local_video).read_bytes()
            if register_clip(
                manifest,
                "asl",
                {key},
                mp4_bytes,
                canonical_key=key,
            ):
                added += 1
                print(f"[asl] {key} <- {video_path}")
        finally:
            cleanup_hub_file(local_video)
    save_manifest(manifest)
    return added


def verify_manifest(manifest: dict) -> int:
    missing = 0
    for language in ("asl", "isl"):
        unique_paths = set(manifest.get(language, {}).values())
        for path in sorted(unique_paths):
            disk_path = ROOT / path
            if not disk_path.exists():
                print(f"[verify] missing file: {path}")
                missing += 1
                continue
            size = disk_path.stat().st_size
            if size < MIN_CLIP_BYTES:
                print(f"[verify] tiny file ({size} B): {path}")
                missing += 1
        print(f"[verify] {language}: {len(unique_paths)} unique clips")
    return missing


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--language",
        choices=("asl", "isl", "both"),
        default="both",
    )
    parser.add_argument(
        "--mvp",
        action="store_true",
        help="Download only the shared MVP gloss list (~80 signs per language).",
    )
    parser.add_argument(
        "--curriculum",
        action="store_true",
        help="Download signs from asl/isl_master_vocabulary.csv (~597 glosses each).",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Download every available sign (ASL ~54 GB).",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Optional hard cap per language.",
    )
    parser.add_argument(
        "--no-resume",
        action="store_true",
        help="Re-download clips even when manifest entries already exist.",
    )
    parser.add_argument(
        "--sync-disk",
        action="store_true",
        help="With resume (default), re-fetch manifest entries whose local mp4 is missing.",
    )
    parser.add_argument(
        "--allow-missing-disk",
        action="store_true",
        help="Do not fail when manifest entries lack local files (R2-only workflows).",
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="Validate manifest entries and on-disk clip files.",
    )
    args = parser.parse_args()

    manifest = load_manifest()

    if args.verify:
        missing = verify_manifest(manifest)
        if missing:
            raise SystemExit(f"Verification failed: {missing} issue(s)")
        print("Verification passed.")
        return

    if args.mvp and args.all:
        parser.error("Use either --mvp or --all, not both.")
    if args.curriculum and args.all:
        parser.error("Use either --curriculum or --all, not both.")
    if args.curriculum and args.mvp:
        parser.error("Use either --curriculum or --mvp, not both.")

    use_curriculum = args.curriculum
    mvp = args.mvp or (not args.all and not use_curriculum)
    resume = not args.no_resume
    sync_disk = args.sync_disk

    asl_allowed: set[str] | None
    isl_allowed: set[str] | None
    stop_when_complete: bool
    if use_curriculum:
        if not CURRICULUM_ASL_CSV.exists() or not CURRICULUM_ISL_CSV.exists():
            parser.error("Curriculum CSV files missing under scripts/data/")
        asl_allowed = load_curriculum_keys(CURRICULUM_ASL_CSV, "asl_gloss")
        isl_allowed = load_curriculum_keys(CURRICULUM_ISL_CSV, "isl_gloss")
        stop_when_complete = True
        print(f"[curriculum] ASL targets: {len(asl_allowed)}")
        print(f"[curriculum] ISL targets: {len(isl_allowed)}")
    elif mvp:
        asl_allowed = normalize_gloss_set(MVP_GLOSSES)
        isl_allowed = normalize_gloss_set(MVP_GLOSSES)
        stop_when_complete = True
    else:
        asl_allowed = None
        isl_allowed = None
        stop_when_complete = False

    if args.language in ("isl", "both"):
        count = fetch_isl(
            manifest,
            allowed=isl_allowed,
            limit=args.limit,
            resume=resume,
            sync_disk=sync_disk,
            stop_when_complete=stop_when_complete,
        )
        print(f"ISL clips added: {count}")
    if args.language in ("asl", "both"):
        count = fetch_asl(
            manifest,
            allowed=asl_allowed,
            limit=args.limit,
            resume=resume,
            sync_disk=sync_disk,
            stop_when_complete=stop_when_complete,
        )
        print(f"ASL clips added: {count}")

    save_manifest(manifest)
    print(f"Manifest written: {MANIFEST_PATH}")
    print(
        "Totals:",
        f"asl={len(manifest['asl'])}",
        f"isl={len(manifest['isl'])}",
    )
    if use_curriculum:
        update_curriculum_video_flags()
    missing = verify_manifest(manifest)
    if missing and not args.allow_missing_disk:
        raise SystemExit(f"Post-download verification found {missing} issue(s)")
    if missing and args.allow_missing_disk:
        print(f"[verify] {missing} manifest entries still missing on disk (allowed).")


if __name__ == "__main__":
    main()

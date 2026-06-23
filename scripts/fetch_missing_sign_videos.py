#!/usr/bin/env python3
"""Fill missing curriculum sign videos from supplemental Hugging Face sources.

Sources:
  - ASL: ZahidYasinMittha (extra label variants) + Voxel51/WLASL
  - ISL: silentone0725/Indian_Sign_Language_Data.gov_Rencoded
  - ISL: Exploration-Lab/CISLR (gated — requires HF_TOKEN + dataset access)

Usage:
  export HF_TOKEN=hf_...   # never commit this token
  python3 scripts/fetch_missing_sign_videos.py
  python3 scripts/fetch_missing_sign_videos.py --language isl --cislr

Before CISLR: accept terms at https://huggingface.co/datasets/Exploration-Lab/CISLR
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import zipfile
from pathlib import Path

from huggingface_hub import hf_hub_download, list_repo_files

from fetch_hf_sign_library import (
    ASL_REPO,
    CURRICULUM_ASL_CSV,
    CURRICULUM_ISL_CSV,
    MANIFEST_PATH,
    MIN_CLIP_BYTES,
    SIGNS_DIR,
    asl_label_for_key,
    cleanup_hub_file,
    load_manifest,
    normalize_key,
    register_clip,
    save_manifest,
    update_curriculum_video_flags,
    verify_manifest,
)

WLASL_REPO = "Voxel51/WLASL"
ISL_GOV_REPO = "silentone0725/Indian_Sign_Language_Data.gov_Rencoded"
CISLR_REPO = "Exploration-Lab/CISLR"
CISLR_VIDEO_DIR = "CISLR_v1.5-a_videos"
CISLR_ZIP_PATH = f"{CISLR_VIDEO_DIR}/CISLR_v1.5-a_videos.zip"
_cislr_zip_path: Path | None = None

# Manual filename aliases in the ISL government dataset.
ISL_GOV_ALIASES: dict[str, str] = {
    "chapati": "chapati_roti",
    "wake_up": "get_up_wake_up",
    "teenager": "teenage",
    "take_care": "love_take_care_of_affection",
    "gray": "grey",
    "grey": "gray",
    "programmer": "program",
    "how_are_you": "how_you",
    "good_to_see_you": "nice_to_see_you",
    "see_you_later": "see_you_again",
    "have_a_nice_day": "nice_day",
    "have_a_good_weekend": "good_weekend",
    "thank_you": "thank_you",
    "thanks_a_lot": "thank_you",
    "no_problem": "no_worries",
    "good_luck": "luck",
    "safe_trip": "safe_travel",
    "bless_you": "bless",
    "best_friend": "bestfriend",
    "post_office": "post_office",
}


def curriculum_rows(csv_path: Path) -> list[dict[str, str]]:
    return list(csv.DictReader(csv_path.open(encoding="utf-8")))


def missing_rows(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    return [row for row in rows if row.get("has_local_video") != "yes"]


def target_keys(row: dict[str, str], gloss_column: str) -> list[str]:
    keys: list[str] = []
    for column in (gloss_column, "english"):
        value = (row.get(column) or "").strip()
        if value:
            key = normalize_key(value)
            if key not in keys:
                keys.append(key)
    return keys


def english_variants(english: str) -> list[str]:
    base = english.strip().rstrip("?").strip()
    variants = [
        base,
        base.replace(" ", "_"),
        base.replace(" ", "-"),
        base.replace("'", ""),
    ]
    seen: list[str] = []
    for variant in variants:
        cleaned = variant.strip()
        if cleaned and cleaned not in seen:
            seen.append(cleaned)
    return seen


def build_zahid_label_index() -> dict[str, str]:
    pattern = re.compile(r"^part_\d+/[0-9]+-(.+)\.mp4$", re.IGNORECASE)
    by_label: dict[str, str] = {}
    for name in list_repo_files(ASL_REPO, repo_type="dataset"):
        match = pattern.match(name)
        if match:
            label = match.group(1).upper()
            by_label.setdefault(label, name)
    return by_label


def build_wlasl_index() -> dict[str, list[str]]:
    samples_path = hf_hub_download(WLASL_REPO, "samples.json", repo_type="dataset")
    data = json.loads(Path(samples_path).read_text(encoding="utf-8"))
    by_label: dict[str, list[str]] = {}
    for sample in data.get("samples", []):
        label = (sample.get("gloss") or {}).get("label", "").strip().lower()
        filepath = sample.get("filepath")
        if label and filepath:
            by_label.setdefault(label, []).append(filepath)
    return by_label


def build_isl_gov_index() -> dict[str, str]:
    by_key: dict[str, str] = {}
    for name in list_repo_files(ISL_GOV_REPO, repo_type="dataset"):
        if not name.endswith(".mp4"):
            continue
        stem = Path(name).stem
        stem = re.sub(r"\s*-\s*English\s*$", "", stem, flags=re.IGNORECASE)
        stem = re.sub(r"\s*\(Sign_\d+\)\s*$", "", stem, flags=re.IGNORECASE)
        stem = stem.replace("_", " ").strip()
        key = normalize_key(stem)
        existing = by_key.get(key)
        if existing is None or ("(Sign_" in existing and "(Sign_" not in name):
            by_key[key] = name
    return by_key


def lookup_zahid(
    row: dict[str, str],
    by_label: dict[str, str],
) -> str | None:
    for key in target_keys(row, "asl_gloss"):
        label = asl_label_for_key(key)
        if label in by_label:
            return by_label[label]
    for variant in english_variants(row["english"]):
        label = variant.upper()
        if label in by_label:
            return by_label[label]
    return None


def lookup_wlasl(row: dict[str, str], by_label: dict[str, list[str]]) -> list[str]:
    for key in target_keys(row, "asl_gloss"):
        label = key.replace("_", " ")
        if label in by_label:
            return by_label[label]
    for variant in english_variants(row["english"]):
        label = variant.lower()
        if label in by_label:
            return by_label[label]
    return []


def lookup_isl_gov(row: dict[str, str], by_key: dict[str, str]) -> str | None:
    for key in target_keys(row, "isl_gloss"):
        if key in ISL_GOV_ALIASES:
            alias = ISL_GOV_ALIASES[key]
            if alias in by_key:
                return by_key[alias]
        if key in by_key:
            return by_key[key]
    for variant in english_variants(row["english"]):
        key = normalize_key(variant)
        if key in ISL_GOV_ALIASES:
            alias = ISL_GOV_ALIASES[key]
            if alias in by_key:
                return by_key[alias]
        if key in by_key:
            return by_key[key]
    return fuzzy_lookup_isl_gov(row, by_key)


def fuzzy_lookup_isl_gov(row: dict[str, str], by_key: dict[str, str]) -> str | None:
    english = row["english"].lower().strip().rstrip("?")
    tokens = [token for token in re.split(r"[^a-z0-9]+", english) if len(token) > 2]
    if not tokens:
        return None
    best_path: str | None = None
    best_score = 0
    for key, path in by_key.items():
        key_tokens = [token for token in key.split("_") if len(token) > 2]
        if not key_tokens:
            continue
        overlap = sum(1 for token in tokens if token in key_tokens or any(token in kt for kt in key_tokens))
        if overlap == len(tokens) and overlap > best_score:
            best_score = overlap
            best_path = path
    return best_path


def hf_token_available() -> bool:
    return bool(os.environ.get("HF_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN"))


def cislr_zip_local_path() -> Path:
    global _cislr_zip_path
    if _cislr_zip_path is None:
        local_path = hf_hub_download(CISLR_REPO, CISLR_ZIP_PATH, repo_type="dataset")
        _cislr_zip_path = Path(local_path)
    return _cislr_zip_path


def build_cislr_index() -> dict[str, str]:
    if not hf_token_available():
        print("[cislr] skip — set HF_TOKEN to access gated CISLR dataset")
        return {}

    csv_path = hf_hub_download(CISLR_REPO, "dataset.csv", repo_type="dataset")
    by_word: dict[str, str] = {}
    with Path(csv_path).open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames:
            return by_word
        fields = {name.lower(): name for name in reader.fieldnames}
        word_key = fields.get("word") or fields.get("gloss") or fields.get("label")
        uid_key = fields.get("uid") or fields.get("id")
        file_key = (
            fields.get("filename")
            or fields.get("file")
            or fields.get("video")
            or fields.get("videoname")
            or fields.get("video_name")
        )
        for row in reader:
            word = (row.get(word_key) if word_key else None) or ""
            file_name = (row.get(file_key) if file_key else None) or ""
            if not file_name and uid_key:
                uid = str(row.get(uid_key) or "").strip()
                if uid:
                    file_name = f"{uid}.mp4"
            if not word and not file_key and not uid_key:
                values = list(row.values())
                if len(values) >= 2:
                    word, file_name = values[0], values[1]
            word = str(word).strip()
            file_name = str(file_name).strip()
            if not word or not file_name:
                continue
            if not file_name.endswith(".mp4"):
                file_name = f"{file_name}.mp4"
            video_path = f"{CISLR_VIDEO_DIR}/{file_name}"
            key = normalize_key(word)
            if key not in by_word:
                by_word[key] = video_path
    print(f"[cislr] indexed {len(by_word)} words")
    return by_word


def lookup_cislr(row: dict[str, str], by_word: dict[str, str]) -> str | None:
    for key in target_keys(row, "isl_gloss"):
        if key in by_word:
            return by_word[key]
    for variant in english_variants(row["english"]):
        key = normalize_key(variant)
        if key in by_word:
            return by_word[key]
    return None


def fetch_isl_cislr_missing(manifest: dict) -> int:
    rows = missing_rows(curriculum_rows(CURRICULUM_ISL_CSV))
    if not rows:
        return 0
    cislr = build_cislr_index()
    if not cislr:
        return 0

    added = 0
    for row in rows:
        keys = target_keys(row, "isl_gloss")
        canonical = keys[0]
        if canonical in manifest["isl"]:
            continue
        remote = lookup_cislr(row, cislr)
        if remote is None:
            continue
        mp4_bytes = download_cislr_video(remote)
        if mp4_bytes is None:
            continue
        if register_clip(
            manifest,
            "isl",
            set(keys),
            mp4_bytes,
            canonical_key=canonical,
        ):
            added += 1
            print(f"[isl] {canonical} <- {CISLR_REPO}:{remote}")
        save_manifest(manifest)
    return added


def download_cislr_video(video_path: str) -> bytes | None:
    """Extract a single clip from the CISLR zip archive."""
    zip_path = cislr_zip_local_path()
    zip_member = video_path
    if not zip_member.startswith(f"{CISLR_VIDEO_DIR}/"):
        zip_member = f"{CISLR_VIDEO_DIR}/{Path(video_path).name}"
    try:
        with zipfile.ZipFile(zip_path) as archive:
            if zip_member not in archive.namelist():
                print(f"[warn] CISLR zip missing {zip_member}")
                return None
            data = archive.read(zip_member)
    except Exception as error:  # noqa: BLE001
        print(f"[warn] CISLR extract failed {zip_member} ({error})")
        return None
    if len(data) < MIN_CLIP_BYTES:
        print(f"[warn] tiny CISLR clip {zip_member} ({len(data)} B)")
        return None
    return data


def download_repo_file(repo: str, filename: str) -> bytes | None:
    try:
        local_path = hf_hub_download(repo, filename=filename, repo_type="dataset")
    except Exception as error:  # noqa: BLE001
        print(f"[warn] download failed {repo}:{filename} ({error})")
        return None
    try:
        data = Path(local_path).read_bytes()
        if len(data) < MIN_CLIP_BYTES:
            print(f"[warn] tiny clip {repo}:{filename} ({len(data)} B)")
            return None
        return data
    finally:
        cleanup_hub_file(local_path)


def fetch_asl_missing(manifest: dict) -> int:
    rows = missing_rows(curriculum_rows(CURRICULUM_ASL_CSV))
    if not rows:
        print("[asl] nothing missing")
        return 0

    zahid = build_zahid_label_index()
    wlasl = build_wlasl_index()
    added = 0

    for row in rows:
        keys = target_keys(row, "asl_gloss")
        canonical = keys[0]
        if canonical in manifest["asl"]:
            continue

        remote = lookup_zahid(row, zahid)
        repo = ASL_REPO
        candidates: list[str] = []
        if remote is not None:
            candidates = [remote]
        else:
            candidates = lookup_wlasl(row, wlasl)
            repo = WLASL_REPO
        if not candidates:
            continue

        mp4_bytes = None
        used_remote = None
        for remote in candidates:
            mp4_bytes = download_repo_file(repo, remote)
            if mp4_bytes is not None:
                used_remote = remote
                break
        if mp4_bytes is None or used_remote is None:
            continue
        if register_clip(
            manifest,
            "asl",
            set(keys),
            mp4_bytes,
            canonical_key=canonical,
        ):
            added += 1
            print(f"[asl] {canonical} <- {repo}:{used_remote}")
        save_manifest(manifest)

    return added


def fetch_isl_missing(manifest: dict, *, use_cislr: bool) -> int:
    rows = missing_rows(curriculum_rows(CURRICULUM_ISL_CSV))
    if not rows:
        print("[isl] nothing missing")
        return 0

    gov = build_isl_gov_index()
    added = 0

    for row in rows:
        keys = target_keys(row, "isl_gloss")
        canonical = keys[0]
        if canonical in manifest["isl"]:
            continue

        remote = lookup_isl_gov(row, gov)
        if remote is None:
            continue

        mp4_bytes = download_repo_file(ISL_GOV_REPO, remote)
        if mp4_bytes is None:
            continue
        if register_clip(
            manifest,
            "isl",
            set(keys),
            mp4_bytes,
            canonical_key=canonical,
        ):
            added += 1
            print(f"[isl] {canonical} <- {ISL_GOV_REPO}:{remote}")
        save_manifest(manifest)

    if use_cislr:
        added += fetch_isl_cislr_missing(manifest)
    return added


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--language",
        choices=("asl", "isl", "both"),
        default="both",
    )
    parser.add_argument(
        "--cislr",
        action="store_true",
        help="Also fetch missing ISL clips from gated CISLR (needs HF_TOKEN).",
    )
    parser.add_argument(
        "--cislr-only",
        action="store_true",
        help="Only run CISLR pass for missing ISL (skip govt dataset).",
    )
    args = parser.parse_args()

    manifest = load_manifest()
    if args.language in ("asl", "both") and not args.cislr_only:
        count = fetch_asl_missing(manifest)
        print(f"ASL supplemental clips added: {count}")
    if args.language in ("isl", "both"):
        if args.cislr_only:
            count = fetch_isl_cislr_missing(manifest)
            print(f"ISL CISLR clips added: {count}")
        else:
            count = fetch_isl_missing(manifest, use_cislr=args.cislr)
            print(f"ISL supplemental clips added: {count}")

    save_manifest(manifest)
    update_curriculum_video_flags()
    missing = verify_manifest(manifest)
    if missing:
        raise SystemExit(f"Verification found {missing} issue(s)")


if __name__ == "__main__":
    main()

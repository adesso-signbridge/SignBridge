#!/usr/bin/env python3
"""Search public web sources for missing curriculum sign videos and download matches.

Sources:
  - WLASL (GitHub JSON + YouTube via yt-dlp + ffmpeg clip)
  - Hugging Face repos with direct mp4 paths (simplyyousef ASL mirror, etc.)
  - ai4bharat/INCLUDE metadata + selective Zenodo file fetch

Usage:
  pip install -r scripts/requirements-hf-signs.txt
  # optional: brew install yt-dlp ffmpeg
  python3 scripts/fetch_web_sign_videos.py
  python3 scripts/fetch_web_sign_videos.py --language asl
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import shutil
import subprocess
import tempfile
import urllib.request
import zipfile
from pathlib import Path

from huggingface_hub import hf_hub_download, list_repo_files

from fetch_hf_sign_library import (
    CURRICULUM_ASL_CSV,
    CURRICULUM_ISL_CSV,
    MIN_CLIP_BYTES,
    cleanup_hub_file,
    load_manifest,
    normalize_key,
    register_clip,
    save_manifest,
    update_curriculum_video_flags,
    verify_manifest,
)

WLASL_JSON_URL = (
    "https://raw.githubusercontent.com/dxli94/WLASL/master/start_kit/WLASL_v0.3.json"
)
ZENODO_INCLUDE_API = "https://zenodo.org/api/records/4010759"

# Mirrors of Zahid-style ASL layout with occasional part_N/gloss.mp4 shortcuts.
ASL_HF_REPOS = [
    "simplyyousef/American-Sign-Language-Dataset",
    "ZahidYasinMittha/American-Sign-Language-Dataset",
]

INCLUDE_REPO = "ai4bharat/INCLUDE"


def target_keys(row: dict[str, str], gloss_column: str) -> list[str]:
    keys: list[str] = []
    for column in (gloss_column, "english"):
        value = (row.get(column) or "").strip()
        if value:
            key = normalize_key(value)
            if key not in keys:
                keys.append(key)
    return keys


def curriculum_rows(csv_path: Path) -> list[dict[str, str]]:
    return list(csv.DictReader(csv_path.open(encoding="utf-8")))


def missing_rows(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    return [row for row in rows if row.get("has_local_video") != "yes"]


def gloss_lookup_variants(row: dict[str, str], gloss_column: str) -> list[str]:
    variants: list[str] = []
    for column in (gloss_column, "english"):
        value = (row.get(column) or "").strip()
        if not value:
            continue
        cleaned = value.rstrip("?").strip()
        for candidate in (
            cleaned,
            cleaned.replace(" ", "_"),
            cleaned.replace(" ", "-"),
            cleaned.replace("'", ""),
        ):
            key = candidate.strip().lower()
            if key and key not in variants:
                variants.append(key)
    return variants


def load_wlasl_index() -> dict[str, list[dict]]:
    raw = urllib.request.urlopen(WLASL_JSON_URL, timeout=120).read()
    data = json.loads(raw)
    by_gloss: dict[str, list[dict]] = {}
    for entry in data:
        gloss = entry["gloss"].strip().lower()
        by_gloss.setdefault(gloss, []).extend(entry.get("instances", []))
    return by_gloss


def build_hf_shortcut_index(repo: str) -> dict[str, str]:
    """Index part_N/word.mp4 shortcuts (lowercase stem)."""
    by_key: dict[str, str] = {}
    pattern = re.compile(r"^part_\d+/(.+)\.mp4$", re.IGNORECASE)
    for name in list_repo_files(repo, repo_type="dataset"):
        match = pattern.match(name)
        if not match:
            continue
        stem = match.group(1).strip().lower()
        by_key.setdefault(stem, name)
    return by_key


def download_hf_file(repo: str, filename: str) -> bytes | None:
    try:
        local_path = hf_hub_download(repo, filename=filename, repo_type="dataset")
    except Exception as error:  # noqa: BLE001
        print(f"[warn] HF download failed {repo}:{filename} ({error})")
        return None
    try:
        data = Path(local_path).read_bytes()
        if len(data) < MIN_CLIP_BYTES:
            return None
        return data
    finally:
        cleanup_hub_file(local_path)


def convert_to_mp4(source: Path, dest: Path) -> bool:
    if shutil.which("ffmpeg") is None:
        return False
    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        str(source),
        "-c:v",
        "libx264",
        "-an",
        str(dest),
    ]
    try:
        subprocess.run(cmd, check=True, capture_output=True, timeout=120)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        print(f"[warn] ffmpeg convert failed ({error})")
        return False
    return dest.exists() and dest.stat().st_size >= MIN_CLIP_BYTES


def clip_with_ffmpeg(source: Path, dest: Path, start: float, end: float) -> bool:
    if shutil.which("ffmpeg") is None:
        return False
    duration = max(0.2, end - start)
    cmd = [
        "ffmpeg",
        "-y",
        "-ss",
        f"{start:.3f}",
        "-i",
        str(source),
        "-t",
        f"{duration:.3f}",
        "-c:v",
        "libx264",
        "-an",
        str(dest),
    ]
    try:
        subprocess.run(cmd, check=True, capture_output=True, timeout=120)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        print(f"[warn] ffmpeg clip failed ({error})")
        return False
    return dest.exists() and dest.stat().st_size >= MIN_CLIP_BYTES


def download_wlasl_clip(instance: dict, dest: Path) -> bool:
    if shutil.which("yt-dlp") is None:
        print("[wlasl] skip — install yt-dlp to download YouTube WLASL clips")
        return False

    url = instance.get("url")
    if not url:
        return False

    with tempfile.TemporaryDirectory(prefix="wlasl_") as tmp:
        tmp_dir = Path(tmp)
        raw_path = tmp_dir / "raw.%(ext)s"
        cmd = [
            "yt-dlp",
            "-f",
            "mp4/best[ext=mp4]/best",
            "-o",
            str(raw_path),
            "--no-playlist",
            "--quiet",
            url,
        ]
        try:
            subprocess.run(cmd, check=True, capture_output=True, timeout=180)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            print(f"[warn] yt-dlp failed {url} ({error})")
            return False

        downloaded = next(tmp_dir.glob("raw.*"), None)
        if downloaded is None:
            return False

        frame_start = int(instance.get("frame_start", 0))
        frame_end = int(instance.get("frame_end", 0))
        fps = int(instance.get("fps", 25) or 25)
        if frame_end > frame_start > 0:
            start = frame_start / fps
            end = frame_end / fps
            if clip_with_ffmpeg(downloaded, dest, start, end):
                return True

        # Fallback: use full download if clipping metadata is missing.
        data = downloaded.read_bytes()
        if len(data) < MIN_CLIP_BYTES:
            return False
        dest.write_bytes(data)
        return True


def fetch_wlasl_missing(manifest: dict, rows: list[dict[str, str]]) -> int:
    wlasl = load_wlasl_index()
    added = 0
    for row in rows:
        keys = target_keys(row, "asl_gloss")
        canonical = keys[0]
        if canonical in manifest["asl"]:
            continue

        instances: list[dict] = []
        for variant in gloss_lookup_variants(row, "asl_gloss"):
            instances = wlasl.get(variant.replace("_", " "), [])
            if instances:
                break

        if not instances:
            continue

        with tempfile.TemporaryDirectory(prefix="wlasl_clip_") as tmp:
            clip_path = Path(tmp) / f"{canonical}.mp4"
            for instance in instances:
                if download_wlasl_clip(instance, clip_path):
                    break
            if not clip_path.exists():
                continue
            mp4_bytes = clip_path.read_bytes()

        if register_clip(
            manifest,
            "asl",
            set(keys),
            mp4_bytes,
            canonical_key=canonical,
        ):
            added += 1
            print(f"[asl] {canonical} <- WLASL/YouTube")
            save_manifest(manifest)
    return added


def fetch_hf_shortcuts(
    manifest: dict,
    rows: list[dict[str, str]],
    *,
    language: str,
    gloss_column: str,
    repos: list[str],
) -> int:
    indexes = [(repo, build_hf_shortcut_index(repo)) for repo in repos]
    added = 0
    for row in rows:
        keys = target_keys(row, gloss_column)
        canonical = keys[0]
        if canonical in manifest[language]:
            continue

        remote: tuple[str, str] | None = None
        for variant in gloss_lookup_variants(row, gloss_column):
            for repo, index in indexes:
                path = index.get(variant)
                if path:
                    remote = (repo, path)
                    break
            if remote:
                break
        if remote is None:
            continue

        repo, filename = remote
        mp4_bytes = download_hf_file(repo, filename)
        if mp4_bytes is None:
            continue
        if register_clip(
            manifest,
            language,
            set(keys),
            mp4_bytes,
            canonical_key=canonical,
        ):
            added += 1
            print(f"[{language}] {canonical} <- {repo}:{filename}")
            save_manifest(manifest)
    return added


def include_label_key(label: str) -> str:
    cleaned = re.sub(r"^\d+\.\s*", "", label.strip().lower())
    return normalize_key(cleaned)


def build_include_index() -> dict[str, str]:
    try:
        import pyarrow.parquet as pq
    except ImportError:
        print("[include] skip — install pyarrow for INCLUDE metadata")
        return {}

    by_key: dict[str, str] = {}
    for split in ("train", "test", "val"):
        parquet_path = hf_hub_download(
            INCLUDE_REPO,
            f"data/{split}-00000-of-00001.parquet",
            repo_type="dataset",
        )
        for row in pq.read_table(parquet_path).to_pylist():
            key = include_label_key(row["label"])
            video_path = row["video_path"]
            if key and key not in by_key:
                by_key[key] = video_path
    print(f"[include] indexed {len(by_key)} labels")
    return by_key


def zenodo_include_file_map() -> dict[str, str]:
    """Map relative video_path -> Zenodo download URL."""
    raw = urllib.request.urlopen(ZENODO_INCLUDE_API, timeout=60).read()
    record = json.loads(raw)
    mapping: dict[str, str] = {}
    for entry in record.get("files", []):
        key = entry.get("key", "")
        url = (entry.get("links") or {}).get("self")
        if not key or not url:
            continue
        if key.endswith(".zip"):
            mapping[key] = url
    return mapping


def extract_include_video(zip_path: Path, member_path: str, dest: Path) -> bool:
    with zipfile.ZipFile(zip_path) as archive:
        # Zenodo zips may prefix folder names; match by suffix.
        candidates = [
            name
            for name in archive.namelist()
            if name.replace("\\", "/").endswith(member_path.replace("\\", "/"))
        ]
        if not candidates:
            return False
        data = archive.read(candidates[0])
        if len(data) < MIN_CLIP_BYTES:
            return False
        dest.write_bytes(data)
        return True


def fetch_include_missing(manifest: dict, rows: list[dict[str, str]]) -> int:
    include = build_include_index()
    if not include:
        return 0

    zenodo_files = zenodo_include_file_map()
    if not zenodo_files:
        print("[include] no Zenodo files found")
        return 0

    added = 0
    with tempfile.TemporaryDirectory(prefix="include_") as tmp:
        tmp_dir = Path(tmp)
        zip_cache: dict[str, Path] = {}

        for row in rows:
            keys = target_keys(row, "isl_gloss")
            canonical = keys[0]
            if canonical in manifest["isl"]:
                continue

            video_path: str | None = None
            for variant in gloss_lookup_variants(row, "isl_gloss"):
                key = normalize_key(variant.replace(" ", "_"))
                if key in include:
                    video_path = include[key]
                    break
            if video_path is None:
                continue

            # INCLUDE archives are category-level zips on Zenodo.
            category = video_path.split("/", 1)[0]
            zip_name = next(
                (name for name in zenodo_files if category.lower() in name.lower()),
                None,
            )
            if zip_name is None:
                print(f"[include] no zip for category {category} ({video_path})")
                continue

            if zip_name not in zip_cache:
                zip_dest = tmp_dir / zip_name
                if not zip_dest.exists():
                    print(f"[include] downloading {zip_name} ...")
                    urllib.request.urlretrieve(zenodo_files[zip_name], zip_dest)
                zip_cache[zip_name] = zip_dest

            clip_path = tmp_dir / f"{canonical}.mov"
            if not extract_include_video(zip_cache[zip_name], video_path, clip_path):
                print(f"[include] missing member {video_path} in {zip_name}")
                continue

            # Convert MOV -> MP4 when ffmpeg is available.
            mp4_path = tmp_dir / f"{canonical}.mp4"
            mp4_bytes: bytes | None = None
            if convert_to_mp4(clip_path, mp4_path):
                mp4_bytes = mp4_path.read_bytes()
            else:
                mp4_bytes = clip_path.read_bytes()

            if mp4_bytes is None or len(mp4_bytes) < MIN_CLIP_BYTES:
                continue
            if register_clip(
                manifest,
                "isl",
                set(keys),
                mp4_bytes,
                canonical_key=canonical,
            ):
                added += 1
                print(f"[isl] {canonical} <- INCLUDE:{video_path}")
                save_manifest(manifest)
    return added


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--language",
        choices=("asl", "isl", "both"),
        default="both",
    )
    parser.add_argument(
        "--skip-wlasl",
        action="store_true",
        help="Skip YouTube/WLASL downloads.",
    )
    parser.add_argument(
        "--skip-include",
        action="store_true",
        help="Skip INCLUDE/Zenodo ISL downloads.",
    )
    args = parser.parse_args()

    manifest = load_manifest()
    asl_added = isl_added = 0

    if args.language in ("asl", "both"):
        asl_rows = missing_rows(curriculum_rows(CURRICULUM_ASL_CSV))
        if not args.skip_wlasl:
            asl_added += fetch_wlasl_missing(manifest, asl_rows)
            asl_rows = missing_rows(curriculum_rows(CURRICULUM_ASL_CSV))
        asl_added += fetch_hf_shortcuts(
            manifest,
            asl_rows,
            language="asl",
            gloss_column="asl_gloss",
            repos=ASL_HF_REPOS,
        )

    if args.language in ("isl", "both"):
        isl_rows = missing_rows(curriculum_rows(CURRICULUM_ISL_CSV))
        if not args.skip_include:
            isl_added += fetch_include_missing(manifest, isl_rows)
            isl_rows = missing_rows(curriculum_rows(CURRICULUM_ISL_CSV))
        # ASL mirrors are not valid ISL signs; do not map ISL to ASL repos.

    save_manifest(manifest)
    update_curriculum_video_flags()
    verify_manifest(manifest)
    print(f"Web fetch complete: asl+={asl_added} isl+={isl_added}")


if __name__ == "__main__":
    main()

#!/usr/bin/env bash
# Bulk-upload sign videos to Cloudflare R2 in parallel (much faster than sequential wrangler).
#
# Prerequisites:
#   1. npm install
#   2. wrangler login
#
# Usage:
#   ./scripts/upload_sign_videos_r2_parallel.sh
#   PARALLEL=16 ./scripts/upload_sign_videos_r2_parallel.sh --delete-after-upload
#   ./scripts/upload_sign_videos_r2_parallel.sh --skip-existing --delete-after-upload
#   ./scripts/upload_sign_videos_r2_parallel.sh --language isl --delete-after-upload
#
# npm:
#   npm run upload:sign-videos:bulk -- --delete-after-upload

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUCKET="${BUCKET:-signbridge-sign-videos}"
PARALLEL="${PARALLEL:-4}"
DRY_RUN=0
SKIP_EXISTING=0
DELETE_AFTER_UPLOAD=0
MAX_RETRIES="${MAX_RETRIES:-5}"

LANGUAGE="both"
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --skip-existing) SKIP_EXISTING=1 ;;
    --delete-after-upload) DELETE_AFTER_UPLOAD=1 ;;
    --language)
      shift
      LANGUAGE="${1:-}"
      ;;
    --language=*) LANGUAGE="${1#*=}" ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done

case "$LANGUAGE" in
  asl|isl|both) ;;
  *)
    echo "Invalid --language: ${LANGUAGE} (use asl, isl, or both)" >&2
    exit 1
    ;;
esac

if ! command -v npx >/dev/null 2>&1; then
  echo "npx not found. Run npm install first." >&2
  exit 1
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/r2_bulk_upload.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

JOBS_FILE="${WORK_DIR}/jobs.tsv"
OK_FILE="${WORK_DIR}/ok.log"
FAIL_FILE="${WORK_DIR}/fail.log"
DEL_FILE="${WORK_DIR}/del.log"
touch "$OK_FILE" "$FAIL_FILE" "$DEL_FILE"

langs=()
case "$LANGUAGE" in
  asl) langs=(asl) ;;
  isl) langs=(isl) ;;
  both) langs=(asl isl) ;;
esac

for lang in "${langs[@]}"; do
  dir="assets/signs/${lang}"
  [[ -d "$dir" ]] || continue
  for file in "$dir"/*.mp4; do
    [[ -f "$file" ]] || continue
    printf '%s\t%s\n' "${lang}/$(basename "$file")" "$file" >>"$JOBS_FILE"
  done
done

total=0
if [[ -f "$JOBS_FILE" ]]; then
  total=$(wc -l <"$JOBS_FILE" | tr -d ' ')
fi

if (( total == 0 )); then
  echo "No local mp4 files under assets/signs/{asl,isl}."
else
  echo "Bulk uploading ${total} clip(s) to R2 bucket: ${BUCKET}"
  echo "Parallel workers: ${PARALLEL}"
  if [[ "$SKIP_EXISTING" -eq 1 ]]; then
    echo "Skipping objects that already exist in R2."
  fi
  if [[ "$DELETE_AFTER_UPLOAD" -eq 1 ]]; then
    echo "Deleting local mp4 files after successful R2 upload."
  fi

  upload_one() {
    local key="$1"
    local file="$2"

    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[dry-run] $key <= $file"
      echo ok >>"$OK_FILE"
      return 0
    fi

    if [[ ! -f "$file" ]]; then
      echo "skip (missing): $key" >&2
      return 0
    fi

    if [[ "$SKIP_EXISTING" -eq 1 ]]; then
      if npx wrangler r2 object get "${BUCKET}/${key}" --remote >/dev/null 2>&1; then
        if [[ "$DELETE_AFTER_UPLOAD" -eq 1 ]]; then
          rm -f "$file"
          echo del >>"$DEL_FILE"
        fi
        echo ok >>"$OK_FILE"
        return 0
      fi
    fi

    local attempt=1
    while (( attempt <= MAX_RETRIES )); do
      if npx wrangler r2 object put "${BUCKET}/${key}" \
        --file="$file" \
        --content-type="video/mp4" \
        --remote 2>/dev/null; then
        if [[ "$DELETE_AFTER_UPLOAD" -eq 1 ]]; then
          rm -f "$file"
          echo del >>"$DEL_FILE"
        fi
        echo ok >>"$OK_FILE"
        return 0
      fi
      sleep $((attempt * 2))
      attempt=$((attempt + 1))
    done

    echo "FAILED: ${key}" >&2
    echo fail >>"$FAIL_FILE"
    return 1
  }

  while IFS=$'\t' read -r key file; do
    while (( $(jobs -r | wc -l | tr -d ' ') >= PARALLEL )); do
      sleep 0.2
    done
    upload_one "$key" "$file" &
  done <"$JOBS_FILE"
  wait
fi

manifest="assets/signs/manifest.json"
manifest_failed=0
if [[ -f "$manifest" ]]; then
  echo "Uploading manifest.json..."
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] manifest.json <= $manifest"
  elif ! npx wrangler r2 object put "${BUCKET}/manifest.json" \
    --file="$manifest" \
    --content-type="application/json" \
    --remote >/dev/null 2>&1; then
    echo "FAILED: manifest.json" >&2
    manifest_failed=1
  fi
fi

ok=$(wc -l <"$OK_FILE" | tr -d ' ')
failed=$(wc -l <"$FAIL_FILE" | tr -d ' ')
deleted=$(wc -l <"$DEL_FILE" | tr -d ' ')

echo "Done. Processed ${ok}/${total} video(s), failed ${failed}."
if [[ "$DELETE_AFTER_UPLOAD" -eq 1 ]]; then
  echo "Deleted ${deleted} local mp4 file(s) after upload."
fi

if (( failed > 0 || manifest_failed > 0 )); then
  exit 1
fi

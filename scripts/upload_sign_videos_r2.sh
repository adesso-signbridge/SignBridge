#!/usr/bin/env bash
# Upload bundled signer videos from assets/signs/ to Cloudflare R2.
#
# Prerequisites:
#   1. npm install
#   2. wrangler login
#   3. Create bucket: wrangler r2 bucket create signbridge-sign-videos
#
# Usage:
#   ./scripts/upload_sign_videos_r2.sh
#   ./scripts/upload_sign_videos_r2.sh --dry-run
#   ./scripts/upload_sign_videos_r2.sh --skip-existing
#   ./scripts/upload_sign_videos_r2.sh --skip-existing --delete-after-upload
#   BUCKET=signbridge-sign-videos-dev ./scripts/upload_sign_videos_r2.sh

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUCKET="${BUCKET:-signbridge-sign-videos}"
DRY_RUN=0
SKIP_EXISTING=0
DELETE_AFTER_UPLOAD=0
MAX_RETRIES="${MAX_RETRIES:-5}"
SLEEP_SECS="${SLEEP_SECS:-0.2}"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --skip-existing) SKIP_EXISTING=1 ;;
    --delete-after-upload) DELETE_AFTER_UPLOAD=1 ;;
  esac
done

if ! command -v npx >/dev/null 2>&1; then
  echo "npx not found. Run npm install first." >&2
  exit 1
fi

object_exists() {
  local key="$1"
  npx wrangler r2 object get "${BUCKET}/${key}" --remote >/dev/null 2>&1
}

upload_file() {
  local file="$1"
  local key="$2"
  local content_type="$3"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] $key <= $file"
    return 0
  fi

  if [[ "$SKIP_EXISTING" -eq 1 ]] && object_exists "$key"; then
    echo "  skip (exists): $key"
    if [[ "$DELETE_AFTER_UPLOAD" -eq 1 && "$content_type" == "video/mp4" && -f "$file" ]]; then
      rm -f "$file"
      echo "  deleted local: $file"
    fi
    return 0
  fi

  local attempt=1
  while (( attempt <= MAX_RETRIES )); do
    if npx wrangler r2 object put "${BUCKET}/${key}" \
      --file="$file" \
      --content-type="$content_type" \
      --remote 2>&1; then
      sleep "$SLEEP_SECS"
      if [[ "$DELETE_AFTER_UPLOAD" -eq 1 && "$content_type" == "video/mp4" && -f "$file" ]]; then
        rm -f "$file"
        echo "  deleted local: $file"
      fi
      return 0
    fi

    echo "  retry ${attempt}/${MAX_RETRIES} for ${key} in $((attempt * 2))s..." >&2
    sleep $((attempt * 2))
    attempt=$((attempt + 1))
  done

  echo "FAILED: ${key}" >&2
  return 1
}

echo "Uploading sign videos to R2 bucket: ${BUCKET}"
if [[ "$SKIP_EXISTING" -eq 1 ]]; then
  echo "Skipping objects that already exist in R2."
fi
if [[ "$DELETE_AFTER_UPLOAD" -eq 1 ]]; then
  echo "Deleting local mp4 files after successful R2 upload."
fi

count=0
deleted=0
failed=0
for lang in asl isl; do
  dir="assets/signs/${lang}"
  if [[ ! -d "$dir" ]]; then
    continue
  fi
  for file in "$dir"/*.mp4; do
    [[ -f "$file" ]] || continue
    key="${lang}/$(basename "$file")"
    if upload_file "$file" "$key" "video/mp4"; then
      count=$((count + 1))
      if [[ ! -f "$file" ]]; then
        deleted=$((deleted + 1))
      fi
      if (( count % 50 == 0 )); then
        echo "  uploaded ${count} clips..."
      fi
    else
      failed=$((failed + 1))
    fi
  done
done

manifest="assets/signs/manifest.json"
if [[ -f "$manifest" ]]; then
  if ! upload_file "$manifest" "manifest.json" "application/json"; then
    failed=$((failed + 1))
  fi
fi

if (( failed > 0 )); then
  echo "Done with errors: ${count} uploaded, ${failed} failed. Re-run with --skip-existing." >&2
  exit 1
fi

echo "Done. Uploaded ${count} video files (+ manifest if present)."
if [[ "$DELETE_AFTER_UPLOAD" -eq 1 ]]; then
  echo "Deleted ${deleted} local mp4 file(s) after upload."
fi

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
#   BUCKET=signbridge-sign-videos-dev ./scripts/upload_sign_videos_r2.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUCKET="${BUCKET:-signbridge-sign-videos}"
DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "npx not found. Run npm install first." >&2
  exit 1
fi

upload_file() {
  local file="$1"
  local key="$2"
  local content_type="$3"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] $key <= $file"
    return 0
  fi
  npx wrangler r2 object put "${BUCKET}/${key}" \
    --file="$file" \
    --content-type="$content_type" \
    --remote
}

echo "Uploading sign videos to R2 bucket: ${BUCKET}"

count=0
for lang in asl isl; do
  dir="assets/signs/${lang}"
  if [[ ! -d "$dir" ]]; then
    continue
  fi
  for file in "$dir"/*.mp4; do
    [[ -f "$file" ]] || continue
    key="${lang}/$(basename "$file")"
    upload_file "$file" "$key" "video/mp4"
    count=$((count + 1))
    if (( count % 50 == 0 )); then
      echo "  uploaded ${count} clips..."
    fi
  done
done

manifest="assets/signs/manifest.json"
if [[ -f "$manifest" ]]; then
  upload_file "$manifest" "manifest.json" "application/json"
fi

echo "Done. Uploaded ${count} video files (+ manifest if present)."

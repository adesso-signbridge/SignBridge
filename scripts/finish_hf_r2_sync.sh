#!/usr/bin/env bash
# Wait for HF ASL download, then upload all local clips + manifest to R2.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ASL_PID="${1:-}"
if [[ -n "$ASL_PID" ]]; then
  echo "Waiting for ASL download (pid ${ASL_PID})..."
  while kill -0 "$ASL_PID" 2>/dev/null; do
    sleep 30
    count=$(find assets/signs/asl -name '*.mp4' 2>/dev/null | wc -l | tr -d ' ')
    echo "  ASL local clips: ${count}"
  done
  echo "ASL download finished."
fi

echo "Bulk uploading all local videos to R2..."
PARALLEL="${PARALLEL:-16}" npm run upload:sign-videos:bulk -- --delete-after-upload

asl=$(find assets/signs/asl -name '*.mp4' | wc -l | tr -d ' ')
isl=$(find assets/signs/isl -name '*.mp4' | wc -l | tr -d ' ')
echo "Done. Local: ASL=${asl} ISL=${isl}"

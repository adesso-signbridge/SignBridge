#!/usr/bin/env bash
# Snapshot ISL bulk-upload progress (local pending = not yet on R2).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISL_PENDING=$(find "$ROOT/assets/signs/isl" -name '*.mp4' 2>/dev/null | wc -l | tr -d ' ')
ASL_PENDING=$(find "$ROOT/assets/signs/asl" -name '*.mp4' 2>/dev/null | wc -l | tr -d ' ')
ISL_SIZE=$(du -sh "$ROOT/assets/signs/isl" 2>/dev/null | cut -f1)
TOTAL_BATCH=4513
ASL_BATCH=719
ISL_BATCH=$((TOTAL_BATCH - ASL_BATCH))
ISL_UPLOADED=$((ISL_BATCH - ISL_PENDING))
PCT=$((ISL_UPLOADED * 100 / ISL_BATCH))
DONE=$(grep -c 'Done\. Processed' /tmp/r2_upload_new.log 2>/dev/null || true)
STATUS="running"
[[ "$DONE" -gt 0 ]] && STATUS="finished"
TS=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TS] upload=$STATUS | ISL uploaded=$ISL_UPLOADED/$ISL_BATCH (${PCT}%) | ISL pending=$ISL_PENDING ($ISL_SIZE) | ASL pending=$ASL_PENDING"

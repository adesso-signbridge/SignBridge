#!/usr/bin/env bash
# Release Android builds for real devices only (arm32 + arm64).
# Drops the x86_64 emulator slice to keep AAB/APK near ~40 MB.
set -euo pipefail
cd "$(dirname "$0")/.."

PLATFORMS="android-arm,android-arm64"

echo "Building Play Store bundle..."
flutter build appbundle --release --target-platform "$PLATFORMS"

echo "Building universal phone APK..."
flutter build apk --release --target-platform "$PLATFORMS"

ls -lh build/app/outputs/bundle/release/app-release.aab
ls -lh build/app/outputs/flutter-apk/app-release.apk

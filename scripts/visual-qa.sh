#!/usr/bin/env bash
# Capture screenshots of the production DiskPrune UI on a Mac.
# Used by .github/workflows/visual-qa.yml. Does not mark Gate 4 PASS.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${DISKPRUNE_VISUAL_QA_OUT:-$ROOT/visual-qa-shots}"
APP="${DISKPRUNE_APP:-$ROOT/app/DiskPrune.app}"

mkdir -p "$OUT"
rm -rf "$OUT"
mkdir -p "$OUT"

if [[ ! -d "$APP" ]]; then
  echo "Packaging DiskPrune.app for first-launch capture…"
  bash "$ROOT/scripts/package-macos.sh"
  APP="$ROOT/app/DiskPrune.app"
fi

cd "$ROOT/app"
DISKPRUNE_VISUAL_QA=1 \
  DISKPRUNE_VISUAL_QA_OUT="$OUT" \
  DISKPRUNE_APP="$APP" \
  swift test --filter VisualQATests

echo "screenshots: $OUT"
find "$OUT" -name '*.png' | sort
count="$(find "$OUT" -name '*.png' | wc -l | tr -d ' ')"
echo "png count: $count"
if [[ "$count" -lt 20 ]]; then
  echo "expected at least 20 PNGs" >&2
  exit 1
fi

# Launch the packaged production .app and try a first-launch PNG.
# screencapture / Screen Recording often fail on GitHub-hosted runners; that is
# recorded as a limitation, not a reason to discard the hosted production views.
echo "Launching packaged DiskPrune.app…"
defaults write com.diskprune.app scanOnLaunch -bool false || true
killall DiskPrune >/dev/null 2>&1 || true
if open "$APP"; then
  sleep 5
  mkdir -p "$OUT/real-app"
  if screencapture -x "$OUT/real-app/first-launch.png" 2>/tmp/screencapture.err; then
    echo "packaged-app screenshot: $OUT/real-app/first-launch.png"
  else
    echo "screencapture failed (likely TCC). See docs/VISUAL-QA-CI.md."
    rm -f "$OUT/real-app/first-launch.png"
    echo "- Packaged DiskPrune.app launched; screencapture blocked on this runner." >> "$OUT/README.txt"
  fi
  killall DiskPrune >/dev/null 2>&1 || true
else
  echo "- Could not open packaged DiskPrune.app" >> "$OUT/README.txt"
fi


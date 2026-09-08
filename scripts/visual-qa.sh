#!/usr/bin/env bash
# Launch the packaged DiskPrune.app with the Visual QA harness enabled.
# The app writes production-UI PNGs and exits. Does not mark Gate 4 PASS.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${DISKPRUNE_VISUAL_QA_OUT:-$ROOT/visual-qa-shots}"
APP="${DISKPRUNE_APP:-$ROOT/app/DiskPrune.app}"
BIN="$APP/Contents/MacOS/DiskPrune"

rm -rf "$OUT"
mkdir -p "$OUT"

if [[ ! -x "$BIN" ]]; then
  echo "Packaging DiskPrune.app…"
  bash "$ROOT/scripts/package-macos.sh"
  APP="$ROOT/app/DiskPrune.app"
  BIN="$APP/Contents/MacOS/DiskPrune"
fi

echo "Launching $BIN (DISKPRUNE_VISUAL_QA=1)"
set +e
DISKPRUNE_VISUAL_QA=1 \
  DISKPRUNE_VISUAL_QA_OUT="$OUT" \
  "$BIN" &
pid=$!
set -e

for _ in $(seq 1 90); do
  if ! kill -0 "$pid" 2>/dev/null; then
    break
  fi
  sleep 2
done

if kill -0 "$pid" 2>/dev/null; then
  echo "visual QA harness hung; killing $pid" >&2
  kill "$pid" 2>/dev/null || true
  sleep 1
  kill -9 "$pid" 2>/dev/null || true
  exit 1
fi

set +e
wait "$pid"
status=$?
set -e
if [[ "$status" -ne 0 ]]; then
  echo "DiskPrune exited $status" >&2
  exit "$status"
fi


echo "screenshots: $OUT"
find "$OUT" -name '*.png' | sort
count="$(find "$OUT" -name '*.png' | wc -l | tr -d ' ')"
echo "png count: $count"
if [[ "$count" -lt 20 ]]; then
  echo "expected at least 20 PNGs" >&2
  cat "$OUT/README.txt" 2>/dev/null || true
  exit 1
fi

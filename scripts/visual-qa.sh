#!/usr/bin/env bash
# Launch the packaged DiskPrune.app via LaunchServices with the Visual QA harness.
# Poll until the catalog writes COMPLETE. Does not mark Gate 4 PASS.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${DISKPRUNE_VISUAL_QA_OUT:-$ROOT/visual-qa-shots}"
APP="${DISKPRUNE_APP:-$ROOT/app/DiskPrune.app}"
PLIST="$APP/Contents/Info.plist"

rm -rf "$OUT"
mkdir -p "$OUT"

if [[ ! -d "$APP" ]]; then
  echo "Packaging DiskPrune.app…"
  bash "$ROOT/scripts/package-macos.sh"
  APP="$ROOT/app/DiskPrune.app"
  PLIST="$APP/Contents/Info.plist"
fi

python3 - "$PLIST" "$OUT" <<'PY'
import plistlib, sys
path, out = sys.argv[1], sys.argv[2]
with open(path, "rb") as f:
    plist = plistlib.load(f)
plist["LSEnvironment"] = {
    "DISKPRUNE_VISUAL_QA": "1",
    "DISKPRUNE_VISUAL_QA_OUT": out,
}
with open(path, "wb") as f:
    plistlib.dump(plist, f)
print("injected LSEnvironment ->", out)
PY

codesign --force --sign - "$APP"
killall DiskPrune >/dev/null 2>&1 || true

echo "Opening $APP via LaunchServices"
open "$APP"

# Capture the live window via screencapture -l when the harness requests it.
# This is the window-server image, including NSVisualEffectView sidebar vibrancy.
# Runs in the shell so DiskPrune source does not spawn Process (guardrail).
(
  while true; do
    if [[ -f "$OUT/COMPLETE" ]]; then
      break
    fi
    if [[ -f "$OUT/CAPTURE_REQUEST" && -f "$OUT/WINDOW_ID" ]]; then
      dest="$(sed -n '1p' "$OUT/CAPTURE_REQUEST" | tr -d '\r')"
      token="$(sed -n '2p' "$OUT/CAPTURE_REQUEST" | tr -d '\r')"
      wid="$(tr -d '\n\r' < "$OUT/WINDOW_ID")"
      if [[ -n "$dest" && -n "$wid" ]]; then
        mkdir -p "$OUT/$(dirname "$dest")"
        ws="${dest%.png}.ws.png"
        if /usr/sbin/screencapture -x -l "$wid" "$OUT/$ws" 2>/dev/null; then
          echo "screencapture $wid -> $ws"
        else
          echo "screencapture failed for $wid"
        fi
      fi
      rm -f "$OUT/CAPTURE_REQUEST"
      printf '%s\n' "${token:-done}" > "$OUT/CAPTURE_DONE"
    fi
    sleep 0.15
  done
) &
WATCH_PID=$!

done_file="$OUT/DONE"
complete_file="$OUT/COMPLETE"
saw_checkpoint=0
for i in $(seq 1 150); do
  if [[ -f "$complete_file" ]]; then
    echo "catalog finished after ${i} polls"
    break
  fi
  if [[ -f "$done_file" && "$saw_checkpoint" -eq 0 ]]; then
    saw_checkpoint=1
    echo "checkpoint; waiting for COMPLETE"
  fi
  if [[ -f "$OUT/harness.log" ]]; then
    tail -n 1 "$OUT/harness.log" || true
  fi
  sleep 2
done

kill "$WATCH_PID" >/dev/null 2>&1 || true
wait "$WATCH_PID" 2>/dev/null || true

if [[ -f "$OUT/harness.log" ]]; then
  echo "---- harness.log ----"
  cat "$OUT/harness.log"
  echo "--------------------"
fi

killall DiskPrune >/dev/null 2>&1 || true
sleep 1

echo "screenshots: $OUT"
find "$OUT" -name '*.png' | sort || true
count="$(find "$OUT" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')"
echo "png count: $count"
if [[ -f "$OUT/README.txt" ]]; then
  echo "---- README.txt ----"
  cat "$OUT/README.txt"
  echo "--------------------"
fi
if [[ "$count" -lt 12 ]]; then
  echo "expected at least 12 PNGs from the production app" >&2
  exit 1
fi
echo "Gate 4 remains NOT PASS. Screenshots are supplemental evidence."

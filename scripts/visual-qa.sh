#!/usr/bin/env bash
# Launch the packaged DiskPrune.app via LaunchServices with the Visual QA harness.
# The app writes production-UI PNGs and exits. Does not mark Gate 4 PASS.
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
import json, plistlib, sys
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
open -W "$APP" || true

if [[ -f "$OUT/harness.log" ]]; then
  echo "---- harness.log ----"
  cat "$OUT/harness.log"
  echo "--------------------"
fi

echo "screenshots: $OUT"
find "$OUT" -name '*.png' | sort || true
count="$(find "$OUT" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')"
echo "png count: $count"
if [[ "$count" -lt 20 ]]; then
  echo "expected at least 20 PNGs" >&2
  cat "$OUT/README.txt" 2>/dev/null || true
  exit 1
fi

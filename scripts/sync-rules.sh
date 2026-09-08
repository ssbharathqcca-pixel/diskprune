#!/usr/bin/env bash
# Copy canonical /shared/storage-rules.json into the app bundle resource,
# injecting generated:true. Never hand-edit the destination.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/shared/storage-rules.json"
DEST="${1:-$ROOT/app/Sources/DiskPrune/Knowledge/Resources/storage-rules.json}"

if [[ ! -f "$SRC" ]]; then
  echo "missing $SRC" >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST")"
python3 - "$SRC" "$DEST" <<'PY'
import json, sys
src, dest = sys.argv[1], sys.argv[2]
with open(src) as f:
    data = json.load(f)
data["generated"] = True
data["source"] = "/shared/storage-rules.json"
with open(dest, "w") as f:
    json.dump(data, f, indent=2, sort_keys=False)
    f.write("\n")
print(f"synced {src} -> {dest}")
PY

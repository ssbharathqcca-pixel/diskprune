#!/usr/bin/env bash
# Assemble a universal (x86_64 + arm64) DiskPrune.app.
# Does NOT sign. Release signing is scripts/release-macos.sh only.
# Does NOT compile the Visual QA catalog (no -DDISKPRUNE_VISUAL_QA).
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "build-universal.sh requires macOS (need swift + lipo)." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/app"
OUT_DIR="${DISKPRUNE_OUT_DIR:-$ROOT/dist/release}"
APP="${DISKPRUNE_APP_PATH:-$OUT_DIR/DiskPrune.app}"
STAGING="$OUT_DIR/staging"
export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-14.0}"

VERSION="${DISKPRUNE_VERSION:-}"
BUILD="${DISKPRUNE_BUILD:-}"

if [[ -z "$VERSION" ]]; then
  if tag="$(git -C "$ROOT" describe --tags --exact-match 2>/dev/null)"; then
    VERSION="${tag#v}"
  else
    VERSION="0.0.0-dev"
  fi
fi
VERSION="${VERSION#v}"
if [[ -z "$BUILD" ]]; then
  sha="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo 0)"
  BUILD="${VERSION}.${GITHUB_RUN_NUMBER:-$sha}"
fi
BUILD="${BUILD#v}"

mkdir -p "$OUT_DIR" "$STAGING"
rm -rf "$APP"

echo "universal: version=${VERSION} build=${BUILD} deployment=${MACOSX_DEPLOYMENT_TARGET}"

# Refuse to compile the Visual QA catalog into a release/universal binary.
if [[ "${DISKPRUNE_ENABLE_VISUAL_QA:-0}" == "1" ]]; then
  echo "DISKPRUNE_ENABLE_VISUAL_QA=1 is not allowed in build-universal.sh" >&2
  echo "Use scripts/package-macos.sh for Visual QA." >&2
  exit 1
fi

find_product() {
  local arch="$1"
  local candidates=(
    "$APP_DIR/.build/${arch}-apple-macosx/release/DiskPrune"
    "$APP_DIR/.build/apple/Products/Release/DiskPrune"
    "$APP_DIR/.build/release/DiskPrune"
  )
  local p
  for p in "${candidates[@]}"; do
    if [[ -f "$p" ]]; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  echo "DiskPrune executable not found after --arch ${arch} build" >&2
  find "$APP_DIR/.build" -name DiskPrune -type f 2>/dev/null | head >&2 || true
  return 1
}

find_bundle() {
  local arch="$1"
  local dir
  dir="$(dirname "$(find_product "$arch")")"
  shopt -s nullglob
  local bundles=("$dir"/*.bundle)
  shopt -u nullglob
  if [[ ${#bundles[@]} -eq 0 ]]; then
    echo "SPM resource bundle missing after --arch ${arch} build in $dir" >&2
    return 1
  fi
  if [[ ${#bundles[@]} -gt 1 ]]; then
    echo "multiple resource bundles in $dir:" >&2
    printf '  %s\n' "${bundles[@]}" >&2
    return 1
  fi
  printf '%s\n' "${bundles[0]}"
}

hash_tree() {
  # Stable recursive digest of a bundle directory.
  python3 - "$1" <<'PY'
import hashlib, os, sys
root = sys.argv[1]
h = hashlib.sha256()
for dirpath, dirnames, filenames in os.walk(root):
    dirnames.sort()
    filenames.sort()
    rel = os.path.relpath(dirpath, root)
    h.update(rel.encode())
    for name in filenames:
        path = os.path.join(dirpath, name)
        h.update(name.encode())
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 16), b""):
                h.update(chunk)
print(h.hexdigest())
PY
}

cd "$APP_DIR"

echo "universal: building arm64"
swift build -c release --arch arm64 --product DiskPrune
cp "$(find_product arm64)" "$STAGING/DiskPrune.arm64"
rm -rf "$STAGING/bundle.arm64"
ARM_BUNDLE_SRC="$(find_bundle arm64)"
ARM_BUNDLE_NAME="$(basename "$ARM_BUNDLE_SRC")"
cp -R "$ARM_BUNDLE_SRC" "$STAGING/bundle.arm64"
ARM_BUNDLE_HASH="$(hash_tree "$STAGING/bundle.arm64")"

echo "universal: building x86_64"
swift build -c release --arch x86_64 --product DiskPrune
cp "$(find_product x86_64)" "$STAGING/DiskPrune.x86_64"
rm -rf "$STAGING/bundle.x86_64"
cp -R "$(find_bundle x86_64)" "$STAGING/bundle.x86_64"
X86_BUNDLE_HASH="$(hash_tree "$STAGING/bundle.x86_64")"

if [[ "$ARM_BUNDLE_HASH" != "$X86_BUNDLE_HASH" ]]; then
  echo "SPM resource bundles are not byte-identical across architectures" >&2
  echo "  arm64  $ARM_BUNDLE_HASH" >&2
  echo "  x86_64 $X86_BUNDLE_HASH" >&2
  exit 1
fi

lipo -create -output "$STAGING/DiskPrune.universal" \
  "$STAGING/DiskPrune.arm64" \
  "$STAGING/DiskPrune.x86_64"
ARCHS="$(lipo -archs "$STAGING/DiskPrune.universal")"
echo "universal: lipo -archs => $ARCHS"
if [[ "$ARCHS" != "x86_64 arm64" && "$ARCHS" != "arm64 x86_64" ]]; then
  echo "T-REL-01 FAIL: expected 'x86_64 arm64', got '$ARCHS'" >&2
  exit 1
fi

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$STAGING/DiskPrune.universal" "$APP/Contents/MacOS/DiskPrune"
chmod +x "$APP/Contents/MacOS/DiskPrune"
cp -R "$STAGING/bundle.arm64" "$APP/Contents/Resources/$ARM_BUNDLE_NAME"

if [[ -f "$APP_DIR/Sources/DiskPrune/Knowledge/Resources/storage-rules.json" ]]; then
  cp "$APP_DIR/Sources/DiskPrune/Knowledge/Resources/storage-rules.json" \
     "$APP/Contents/Resources/storage-rules.json"
fi

printf 'APPL????' > "$APP/Contents/PkgInfo"

# AppIcon.icns is optional until design supplies one. Do not invent artwork.

python3 - "$APP/Contents/Info.plist" "$VERSION" "$BUILD" <<'PY'
import plistlib, sys
path, version, build = sys.argv[1], sys.argv[2], sys.argv[3]
plist = {
    "CFBundleDevelopmentRegion": "en",
    "CFBundleDisplayName": "DiskPrune",
    "CFBundleExecutable": "DiskPrune",
    "CFBundleIdentifier": "com.diskprune.app",
    "CFBundleInfoDictionaryVersion": "6.0",
    "CFBundleName": "DiskPrune",
    "CFBundlePackageType": "APPL",
    "CFBundleShortVersionString": version,
    "CFBundleVersion": str(build),
    "LSApplicationCategoryType": "public.app-category.utilities",
    "LSMinimumSystemVersion": "14.0",
    "NSHighResolutionCapable": True,
    "NSHumanReadableCopyright": "Copyright © 2026 DiskPrune",
    "NSPrincipalClass": "NSApplication",
    "NSSupportsAutomaticGraphicsSwitching": True,
}
with open(path, "wb") as f:
    plistlib.dump(plist, f)
PY

# Hard fail if Visual QA env leaked into Info.plist.
if python3 - "$APP/Contents/Info.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], "rb") as f:
    p = plistlib.load(f)
env = p.get("LSEnvironment") or {}
if env.get("DISKPRUNE_VISUAL_QA") == "1":
    sys.exit(1)
sys.exit(0)
PY
then
  :
else
  echo "Info.plist must not enable DISKPRUNE_VISUAL_QA" >&2
  exit 1
fi

echo "packed $APP"
echo "version ${VERSION} (${BUILD})"
echo "archs ${ARCHS}"

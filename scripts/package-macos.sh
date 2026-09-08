#!/usr/bin/env bash
# Build a launchable DiskPrune.app + DMG for human Visual QA.
# Does not change product UI. Ad-hoc signed, not notarized.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/app"
BUILD_DIR="$APP_DIR/.build/release"
APP="$APP_DIR/DiskPrune.app"
DMG="$APP_DIR/DiskPrune.dmg"
VERSION="${DISKPRUNE_VERSION:-1.0.0}"
BUILD="${DISKPRUNE_BUILD:-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo qa)}"

cd "$APP_DIR"
swift build -c release --product DiskPrune

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BUILD_DIR/DiskPrune" "$APP/Contents/MacOS/DiskPrune"
chmod +x "$APP/Contents/MacOS/DiskPrune"

# SPM resource bundle (Bundle.module)
shopt -s nullglob
for bundle in "$BUILD_DIR"/*.bundle; do
  cp -R "$bundle" "$APP/Contents/Resources/"
  cp -R "$bundle" "$APP/Contents/MacOS/"
done
shopt -u nullglob

# Bundle.main fallback used by StorageKnowledge.load()
if [[ -f "$APP_DIR/Sources/DiskPrune/Knowledge/Resources/storage-rules.json" ]]; then
  cp "$APP_DIR/Sources/DiskPrune/Knowledge/Resources/storage-rules.json" \
     "$APP/Contents/Resources/storage-rules.json"
fi

printf 'APPL????' > "$APP/Contents/PkgInfo"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>DiskPrune</string>
    <key>CFBundleExecutable</key>
    <string>DiskPrune</string>
    <key>CFBundleIdentifier</key>
    <string>com.diskprune.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>DiskPrune</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD}</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 DiskPrune</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP/Contents/MacOS/DiskPrune"
codesign --force --sign - "$APP"

rm -f "$DMG"
hdiutil create -volname "DiskPrune" -srcfolder "$APP" -ov -format UDZO "$DMG"

echo "packed $APP"
echo "packed $DMG"
echo "version ${VERSION} (${BUILD})"

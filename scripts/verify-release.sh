#!/usr/bin/env bash
# 12-point Gate 5 verification against the customer DMG (PART 19.4).
# Checks 1–9 are automated and fail the script. Checks 10–12 are manual.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "verify-release.sh requires macOS" >&2
  exit 1
fi

if [[ $# -lt 1 ]]; then
  echo "usage: bash scripts/verify-release.sh DiskPrune.dmg" >&2
  exit 1
fi

DMG="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0
REPORT="${DISKPRUNE_VERIFY_REPORT:-$(dirname "$DMG")/verify-report.txt}"
NOTARY_LOG="${DISKPRUNE_NOTARY_LOG:-}"

pass() { printf 'PASS  %s\n' "$*" | tee -a "$REPORT"; }
fail() { printf 'FAIL  %s\n' "$*" | tee -a "$REPORT" >&2; FAIL=1; }
note() { printf 'NOTE  %s\n' "$*" | tee -a "$REPORT"; }
manual() { printf 'MANUAL %s\n' "$*" | tee -a "$REPORT"; }

: > "$REPORT"
echo "DiskPrune Gate 5 verification" | tee -a "$REPORT"
echo "dmg: $DMG" | tee -a "$REPORT"
echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$REPORT"
echo | tee -a "$REPORT"

if [[ ! -f "$DMG" ]]; then
  fail "1 DMG missing: $DMG"
  exit 1
fi

echo "--- 8 DMG integrity ---"
if hdiutil verify "$DMG" >/dev/null; then
  pass "8 hdiutil verify"
else
  fail "8 hdiutil verify"
fi

MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/diskprune-dmg.XXXXXX")"
ATTACH_OUT="$(hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT_DIR" "$DMG")"
cleanup_mount() {
  hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
  rmdir "$MOUNT_DIR" >/dev/null 2>&1 || true
}
trap cleanup_mount EXIT

APP="$MOUNT_DIR/DiskPrune.app"
BIN="$APP/Contents/MacOS/DiskPrune"
PLIST="$APP/Contents/Info.plist"

if [[ ! -d "$APP" ]]; then
  fail "mounted DMG has no DiskPrune.app (mount=$MOUNT_DIR)"
  echo "$ATTACH_OUT" >&2
  exit 1
fi

echo "--- 1 identity ---"
IDENT_OUT="$(codesign -dv --verbose=4 "$APP" 2>&1 || true)"
printf '%s\n' "$IDENT_OUT" >> "$REPORT"
if grep -q "Authority=Developer ID Application" <<<"$IDENT_OUT"; then
  pass "1 Developer ID Application"
else
  fail "1 codesign identity is not Developer ID Application"
fi
if grep -q "Authority=Apple Root CA" <<<"$IDENT_OUT" || grep -q "Authority=Developer ID Certification Authority" <<<"$IDENT_OUT"; then
  pass "1 Developer ID certificate chain present"
else
  note "1 intermediate/root line not parsed (see report)"
fi

echo "--- 2 nested verify ---"
if codesign --verify --deep --strict --verbose=2 "$APP" 2>>"$REPORT"; then
  pass "2 codesign --verify --deep --strict"
else
  fail "2 codesign --verify --deep --strict"
fi

echo "--- 3 hardened runtime ---"
if grep -Eq "flags=.*runtime" <<<"$IDENT_OUT"; then
  pass "3 hardened runtime"
else
  fail "3 hardened runtime flag missing"
fi

echo "--- 4 secure timestamp ---"
if grep -q "Timestamp=" <<<"$IDENT_OUT"; then
  pass "4 secure timestamp"
else
  fail "4 Timestamp= missing (ad-hoc or local clock sign)"
fi

echo "--- 5 notarization log ---"
if [[ -n "$NOTARY_LOG" && -f "$NOTARY_LOG" ]]; then
  if grep -Eqi "status: (Accepted|Accepted\.)|statusCode: 0|Accepted" "$NOTARY_LOG"; then
    pass "5 notarytool log accepted"
  else
    fail "5 notarytool log is not Accepted"
  fi
else
  note "5 notarytool log not provided (DISKPRUNE_NOTARY_LOG); staple/spctl still required"
fi

echo "--- 6 stapler ---"
if stapler validate "$DMG" >/dev/null 2>>"$REPORT"; then
  pass "6 stapler validate DMG"
else
  fail "6 stapler validate DMG"
fi
if stapler validate "$APP" >/dev/null 2>>"$REPORT"; then
  pass "6 stapler validate APP"
else
  fail "6 stapler validate APP"
fi

echo "--- 7 Gatekeeper ---"
SPCTL_OUT="$(spctl -a -vvv -t install "$APP" 2>&1 || true)"
printf '%s\n' "$SPCTL_OUT" >> "$REPORT"
if grep -q "accepted" <<<"$SPCTL_OUT" && grep -qi "Notarized Developer ID" <<<"$SPCTL_OUT"; then
  pass "7 spctl accepted, source=Notarized Developer ID"
else
  fail "7 spctl -a -vvv -t install => $SPCTL_OUT"
fi

echo "--- 9 universal slices (mounted DMG, T-REL-01) ---"
ARCHS="$(lipo -archs "$BIN")"
echo "lipo -archs => $ARCHS" | tee -a "$REPORT"
if [[ "$ARCHS" == "x86_64 arm64" || "$ARCHS" == "arm64 x86_64" ]]; then
  pass "9 lipo -archs x86_64 arm64"
else
  fail "9 lipo -archs expected x86_64 arm64, got $ARCHS"
fi

echo "--- entitlements ---"
ENT_OUT="$(codesign -d --entitlements :- "$APP" 2>/dev/null || true)"
printf '%s\n' "$ENT_OUT" >> "$REPORT"
if grep -q "get-task-allow" <<<"$ENT_OUT"; then
  fail "entitlements contain get-task-allow (debug)"
else
  pass "entitlements: no get-task-allow"
fi
if grep -q "disable-library-validation" <<<"$ENT_OUT"; then
  fail "entitlements contain disable-library-validation"
else
  pass "entitlements: no disable-library-validation"
fi
if grep -q "com.apple.security.app-sandbox" <<<"$ENT_OUT"; then
  fail "entitlements enable App Sandbox (v1 does not ship sandboxed)"
else
  pass "entitlements: no App Sandbox"
fi

echo "--- Info.plist version / Visual QA ---"
SHORT="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
BUNDLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
MINOS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PLIST")"
IDENT="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")"
echo "CFBundleShortVersionString=$SHORT" | tee -a "$REPORT"
echo "CFBundleVersion=$BUNDLE" | tee -a "$REPORT"
echo "LSMinimumSystemVersion=$MINOS" | tee -a "$REPORT"
echo "CFBundleIdentifier=$IDENT" | tee -a "$REPORT"
if [[ "$IDENT" != "com.diskprune.app" ]]; then
  fail "CFBundleIdentifier is $IDENT"
else
  pass "CFBundleIdentifier com.diskprune.app"
fi
if [[ "$MINOS" != "14.0" ]]; then
  fail "LSMinimumSystemVersion is $MINOS"
else
  pass "LSMinimumSystemVersion 14.0"
fi
if /usr/libexec/PlistBuddy -c 'Print :LSEnvironment:DISKPRUNE_VISUAL_QA' "$PLIST" >/dev/null 2>&1; then
  fail "LSEnvironment DISKPRUNE_VISUAL_QA present in release Info.plist"
else
  pass "no LSEnvironment Visual QA injection"
fi

echo "--- Visual QA catalog stripped ---"
if strings "$BIN" | grep -q "VisualQACatalog"; then
  fail "binary contains VisualQACatalog (compiled with -DDISKPRUNE_VISUAL_QA)"
else
  pass "VisualQACatalog absent from release binary"
fi
if strings "$BIN" | grep -q "VisualQAHost"; then
  fail "binary contains VisualQAHost"
else
  pass "VisualQAHost absent from release binary"
fi

echo "--- secrets / private keys not embedded ---"
if strings "$BIN" | grep -Eq 'BEGIN PRIVATE KEY|MC4CAQAwBQYDK2Vw|sk_live_|sk_test_|LICENSE_SIGNING_KEY_K|LICENSE_ENCRYPTION_KEY|whsec_|re_[A-Za-z0-9]{20,}'; then
  fail "binary strings look like private key / Stripe / Resend material"
else
  pass "no private-key / live-secret needles in binary strings"
fi

echo "--- production public k1 ---"
K1_SWIFT="$(sed -n 's/.*static let k1Base64 = "\([^"]*\)".*/\1/p' "$ROOT/app/Sources/DiskPrune/Licensing/PublicKeys.swift")"
K1_TOML="$(python3 - "$ROOT/worker/wrangler.toml" <<'PY'
from pathlib import Path
import sys, re
text = Path(sys.argv[1]).read_text()
idx = text.find("[vars]")
chunk = text[idx:]
m = re.search(r'LICENSE_SIGNING_PUB_K1\s*=\s*"([^"]+)"', chunk)
print(m.group(1) if m else "")
PY
)"
echo "PublicKeys.k1Base64=$K1_SWIFT" | tee -a "$REPORT"
echo "wrangler LICENSE_SIGNING_PUB_K1=$K1_TOML" | tee -a "$REPORT"
if [[ "$K1_SWIFT" != "$K1_TOML" || -z "$K1_SWIFT" ]]; then
  fail "PublicKeys.k1Base64 does not match wrangler.toml"
else
  pass "production k1 matches Worker public verify key"
fi
if strings "$BIN" | grep -q "$K1_SWIFT"; then
  pass "release binary embeds production k1"
else
  # CryptoKit may not store the raw base64 string if only the raw key bytes are kept.
  note "base64 k1 string not found in binary (raw 32-byte key may still be present)"
fi

echo "--- ad-hoc sign forbidden ---"
if grep -q "Signature=adhoc" <<<"$IDENT_OUT"; then
  fail "signature is ad-hoc"
else
  pass "not ad-hoc"
fi

echo "--- 10–12 manual (gate the release; cannot pass in CI) ---"
manual "10 Extracted app launches"
manual "11 Clean-Mac install: download SHA-256, double-click, drag, launch — no Terminal, no System Settings"
manual "12 Intel Mac launches"

echo | tee -a "$REPORT"
if [[ "$FAIL" -ne 0 ]]; then
  echo "Gate 5 automated checks FAILED. See $REPORT" | tee -a "$REPORT"
  exit 1
fi
echo "Checks 1–9 passed against the mounted DMG. Checks 10–12 remain MANUAL." | tee -a "$REPORT"
echo "Gate 5 is NOT PASS until 10–12 succeed on real Macs." | tee -a "$REPORT"

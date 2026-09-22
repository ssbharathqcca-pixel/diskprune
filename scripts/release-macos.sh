#!/usr/bin/env bash
# Gate 5 — universal Developer ID + hardened runtime + notarize + staple.
# Fail closed. Never falls back to ad-hoc. Never compiles Visual QA catalog.
#
#   bash scripts/release-macos.sh --prereqs   # list missing credentials (any OS)
#   bash scripts/release-macos.sh             # full release (macOS + secrets)
#   bash scripts/release-macos.sh --universal-only
#
# Secrets (env or GitHub Actions):
#   DEVELOPER_ID_CERT_P12        base64 PKCS#12 of Developer ID Application
#   DEVELOPER_ID_CERT_PASSWORD
#   APPLE_TEAM_ID
#   ASC_KEY_ID                   App Store Connect API key id
#   ASC_ISSUER_ID                App Store Connect issuer UUID
#   ASC_KEY_P8                   App Store Connect .p8 contents (PEM)
# Optional:
#   DEVELOPER_ID_IDENTITY        exact codesign identity string
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${DISKPRUNE_OUT_DIR:-$ROOT/dist/release}"
APP="$OUT_DIR/DiskPrune.app"
DMG="$OUT_DIR/DiskPrune.dmg"
ZIP="$OUT_DIR/DiskPrune.zip"
ENTITLEMENTS="$ROOT/app/Packaging/DiskPrune.entitlements"
MODE="release"

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
}

missing=()
need() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    missing+=("$name")
  fi
}

check_prereqs() {
  missing=()
  if [[ "$(uname -s)" != "Darwin" ]]; then
    missing+=("Darwin (macOS host or macos-14 GitHub runner)")
  else
    for cmd in swift lipo codesign hdiutil stapler xcrun security python3 openssl; do
      if ! command -v "$cmd" >/dev/null 2>&1; then
        missing+=("command:$cmd")
      fi
    done
    if ! xcrun --find notarytool >/dev/null 2>&1; then
      missing+=("xcrun notarytool")
    fi
  fi
  need DEVELOPER_ID_CERT_P12
  need DEVELOPER_ID_CERT_PASSWORD
  need APPLE_TEAM_ID
  need ASC_KEY_ID
  need ASC_ISSUER_ID
  need ASC_KEY_P8
  if [[ ! -f "$ENTITLEMENTS" ]]; then
    missing+=("app/Packaging/DiskPrune.entitlements")
  fi
  if [[ ${#missing[@]} -eq 0 ]]; then
    echo "prereqs: ok"
    return 0
  fi
  echo "Gate 5 prerequisites missing:" >&2
  for m in "${missing[@]}"; do
    echo "  - $m" >&2
  done
  echo >&2
  echo "Do not ad-hoc-sign and call it a release. Create GitHub Actions secrets" >&2
  echo "with those names (see docs/RELEASE.md) and re-run on a Mac / macos-14." >&2
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prereqs) MODE="prereqs"; shift ;;
    --universal-only) MODE="universal"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$MODE" == "prereqs" ]]; then
  check_prereqs
  exit $?
fi

export DISKPRUNE_OUT_DIR="$OUT_DIR"
export DISKPRUNE_APP_PATH="$APP"
unset DISKPRUNE_VISUAL_QA || true
export DISKPRUNE_ENABLE_VISUAL_QA=0

if [[ "$MODE" == "universal" ]]; then
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "release-macos.sh --universal-only requires macOS" >&2
    exit 1
  fi
  export DISKPRUNE_ALLOW_UNTAGGED="${DISKPRUNE_ALLOW_UNTAGGED:-1}"
  bash "$ROOT/scripts/build-universal.sh"
  exit 0
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "release-macos.sh: not Darwin. Refusing to invent a signed artifact." >&2
  check_prereqs || true
  exit 1
fi

if ! check_prereqs; then
  exit 1
fi

node "$ROOT/scripts/check-licensing-config.mjs"

# Version: git tag is source of truth for a real release.
if tag="$(git -C "$ROOT" describe --tags --exact-match 2>/dev/null)"; then
  export DISKPRUNE_VERSION="${DISKPRUNE_VERSION:-${tag#v}}"
else
  if [[ "${DISKPRUNE_ALLOW_UNTAGGED:-0}" != "1" ]]; then
    echo "release-macos.sh requires a git tag (vX.Y.Z) or DISKPRUNE_ALLOW_UNTAGGED=1" >&2
    exit 1
  fi
  export DISKPRUNE_VERSION="${DISKPRUNE_VERSION:-0.0.0-dev}"
fi
export DISKPRUNE_VERSION="${DISKPRUNE_VERSION#v}"
export DISKPRUNE_BUILD="${DISKPRUNE_BUILD:-${DISKPRUNE_VERSION}.${GITHUB_RUN_NUMBER:-0}}"
export DISKPRUNE_BUILD="${DISKPRUNE_BUILD#v}"

bash "$ROOT/scripts/build-universal.sh"

IDENTITY=""
KEYCHAIN_PATH=""
WORK="$(mktemp -d "${TMPDIR:-/tmp}/diskprune-sign.XXXXXX")"
P12_PATH="$WORK/developer-id.p12"
ASC_KEY_PATH="$WORK/AuthKey.p8"
NOTARY_LOG="$OUT_DIR/notarytool-log.json"
export DISKPRUNE_KEYCHAIN="$WORK/signing.keychain-db"
export DISKPRUNE_P12_PATH="$P12_PATH"
export DISKPRUNE_KEYCHAIN_PATH_FILE="$WORK/keychain-path.txt"

cleanup() {
  set +e
  if [[ -n "${KEYCHAIN_PATH:-}" ]]; then
    security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1
  fi
  if [[ -f "${DISKPRUNE_KEYCHAIN:-}" ]]; then
    security delete-keychain "$DISKPRUNE_KEYCHAIN" >/dev/null 2>&1
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

IDENTITY="$(bash "$ROOT/scripts/import-developer-id.sh")"
if [[ -f "$DISKPRUNE_KEYCHAIN_PATH_FILE" ]]; then
  KEYCHAIN_PATH="$(cat "$DISKPRUNE_KEYCHAIN_PATH_FILE")"
else
  KEYCHAIN_PATH="$DISKPRUNE_KEYCHAIN"
fi
echo "signing identity: $IDENTITY"

if [[ "$IDENTITY" == "-" || -z "$IDENTITY" ]]; then
  echo "refusing ad-hoc identity" >&2
  exit 1
fi

# Verify the SPM resource bundle is present. It contains only data files
# (JSON, plists) — no Mach-O — so codesigning it as a plugin bundle would
# fail with "bundle format unrecognized". The app-level signature covers its
# contents. --deep is prohibited for notarization; we sign code-bearing
# components individually (executable, then app).
BUNDLE=""
shopt -s nullglob
for b in "$APP/Contents/Resources"/*.bundle; do
  BUNDLE="$b"
done
shopt -u nullglob
if [[ -z "$BUNDLE" ]]; then
  echo "missing SPM resource bundle inside $APP" >&2
  exit 1
fi
echo "SPM resource bundle present: $(basename "$BUNDLE") (data-only, not signed separately)"

echo "codesign executable"
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$IDENTITY" \
  "$APP/Contents/MacOS/DiskPrune"

echo "codesign app bundle"
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$IDENTITY" \
  "$APP"

python3 - "$ASC_KEY_PATH" <<'PY'
import base64, os, pathlib, sys
text = os.environ["ASC_KEY_P8"]
path = pathlib.Path(sys.argv[1])
# Accept raw PEM or base64-encoded PEM (GitHub Secrets strips newlines from
# multi-line values; base64 encoding is the reliable storage format).
if "PRIVATE KEY" not in text:
    try:
        text = base64.b64decode(text.strip()).decode("utf-8")
    except Exception:
        pass
if "PRIVATE KEY" not in text:
    raise SystemExit("ASC_KEY_P8 must be PEM text or base64-encoded PEM")
path.write_text(text if text.endswith("\n") else text + "\n")
os.chmod(path, 0o600)
PY

# Submit to Apple Notary then wait for acceptance. Separating submit from wait
# means a transient network drop during polling cannot lose the submission id —
# we can retry wait with the same id and Apple resumes from the queue position.
# Args: <artifact> <log-base>  (writes <log-base>.submit.txt + <log-base>.txt)
# Prints submission id to stdout; all progress/diagnostic output goes to stderr.
notary_submit_and_wait() {
  local file="$1" base="$2"
  xcrun notarytool submit "$file" \
    --key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" \
    | tee "${base}.submit.txt" >&2
  local id
  id="$(awk '/^\s*id:/{print $2; exit}' "${base}.submit.txt" | tr -d '\r')"
  [[ -n "$id" ]] || { echo "notarytool: no submission id in output" >&2; exit 1; }
  echo "notarytool submission id: $id" >&2
  local attempt
  for attempt in 1 2 3; do
    if xcrun notarytool wait "$id" \
         --key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" \
         | tee -a "${base}.txt" >&2; then
      break
    fi
    [[ $attempt -lt 3 ]] || { echo "notarytool wait failed after 3 attempts" >&2; exit 1; }
    echo "notarytool wait failed (attempt $attempt/3); retrying in 30s…" >&2
    sleep 30
  done
  grep -q "status: Accepted" "${base}.txt" || {
    echo "notarization not Accepted — see ${base}.txt" >&2; exit 1
  }
  echo "$id"
}

echo "notarize app zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
notary_submit_and_wait "$ZIP" "$OUT_DIR/notarytool-app" > /dev/null
xcrun stapler staple "$APP"

echo "create and sign DMG"
rm -f "$DMG"
hdiutil create -volname "DiskPrune" -srcfolder "$APP" -ov -format UDZO "$DMG"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

echo "notarize DMG"
SUBMISSION_ID="$(notary_submit_and_wait "$DMG" "$OUT_DIR/notarytool-dmg")"

# Fetch JSON log for check 5.
if [[ -n "$SUBMISSION_ID" ]]; then
  xcrun notarytool log "$SUBMISSION_ID" \
    --key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" \
    > "$NOTARY_LOG" || true
fi

xcrun stapler staple "$DMG"

shasum -a 256 "$DMG" | tee "$DMG.sha256"

export DISKPRUNE_NOTARY_LOG="$NOTARY_LOG"
bash "$ROOT/scripts/verify-release.sh" "$DMG"

echo "release artifact: $DMG"
echo "checksum:         $DMG.sha256"
echo "Gate 5 automated checks 1–9 ran against the mounted DMG."
echo "Gate 5 is NOT PASS until checks 10–12 (launch / clean Mac / Intel) succeed."

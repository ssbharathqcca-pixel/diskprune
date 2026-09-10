#!/usr/bin/env bash
# Import Developer ID Application into an ephemeral keychain.
# Prints the identity name on stdout. Secrets stay in env / temp files.
# Always delete the keychain from the caller via cleanup.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "import-developer-id.sh requires macOS" >&2
  exit 1
fi

: "${DEVELOPER_ID_CERT_P12:?DEVELOPER_ID_CERT_P12 is required (base64 PKCS#12)}"
: "${DEVELOPER_ID_CERT_PASSWORD:?DEVELOPER_ID_CERT_PASSWORD is required}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"

KEYCHAIN_PATH="${DISKPRUNE_KEYCHAIN:-${TMPDIR:-/tmp}/diskprune-signing.keychain-db}"
KEYCHAIN_PASSWORD="${DISKPRUNE_KEYCHAIN_PASSWORD:-$(openssl rand -base64 32)}"
P12_PATH="${DISKPRUNE_P12_PATH:-$TMPDIR/diskprune-developer-id.p12}"

mkdir -p "$(dirname "$KEYCHAIN_PATH")"

python3 - "$P12_PATH" <<'PY'
import base64, os, sys
raw = os.environ["DEVELOPER_ID_CERT_P12"].strip()
path = sys.argv[1]
data = base64.b64decode(raw)
if len(data) < 64:
    raise SystemExit("DEVELOPER_ID_CERT_P12 did not decode to a PKCS#12 blob")
with open(path, "wb") as f:
    f.write(data)
PY

security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

security import "$P12_PATH" -k "$KEYCHAIN_PATH" \
  -P "$DEVELOPER_ID_CERT_PASSWORD" \
  -T /usr/bin/codesign -T /usr/bin/security >/dev/null

security set-key-partition-list \
  -S apple-tool:,apple: \
  -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null

# Put the ephemeral keychain first so codesign finds the imported identity.
EXISTING="$(security list-keychains -d user | sed 's/"//g')"
# shellcheck disable=SC2086
security list-keychains -d user -s "$KEYCHAIN_PATH" $EXISTING >/dev/null

IDENTITY="${DEVELOPER_ID_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
  IDENTITY="$(
    security find-identity -v -p codesigning "$KEYCHAIN_PATH" \
      | grep "Developer ID Application" \
      | grep "$APPLE_TEAM_ID" \
      | head -n 1 \
      | sed -E 's/.*"([^"]+)".*/\1/'
  )"
fi

if [[ -z "$IDENTITY" || "$IDENTITY" == "-" ]]; then
  echo "No Developer ID Application identity for team $APPLE_TEAM_ID" >&2
  security find-identity -v -p codesigning "$KEYCHAIN_PATH" >&2 || true
  exit 1
fi

if ! grep -q "Developer ID Application" <<<"$IDENTITY"; then
  echo "Identity is not Developer ID Application: $IDENTITY" >&2
  exit 1
fi
if ! grep -q "$APPLE_TEAM_ID" <<<"$IDENTITY"; then
  echo "Identity team does not match APPLE_TEAM_ID=$APPLE_TEAM_ID: $IDENTITY" >&2
  exit 1
fi

printf '%s\n' "$IDENTITY"
if [[ -n "${DISKPRUNE_KEYCHAIN_PATH_FILE:-}" ]]; then
  printf '%s\n' "$KEYCHAIN_PATH" > "$DISKPRUNE_KEYCHAIN_PATH_FILE"
fi

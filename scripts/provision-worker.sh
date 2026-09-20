#!/usr/bin/env bash
# Owner-run production Worker provisioner (Phase 6 / Gate 3 prep).
#
# Creates D1 `diskprune-licenses` and KV `RATE_LIMITS`, patches wrangler.toml
# binding ids, generates an Ed25519 k1 pair + AES-256 key, puts Wrangler
# secrets, applies migrations, deploys.
#
# Never writes private-key material to disk, git, or the terminal.
# Do not run with `bash -x`.
#
# Usage:
#   bash scripts/provision-worker.sh --check    # default: report only
#   bash scripts/provision-worker.sh --apply    # mutate Cloudflare + local config
#
# --apply requires `npx wrangler login` (or CLOUDFLARE_API_TOKEN + CLOUDFLARE_ACCOUNT_ID).
# STRIPE_WEBHOOK_SECRET and RESEND_API_KEY: set in the environment or paste at the prompt.
set -euo pipefail

if [[ $- == *x* ]]; then
  echo "error: refuse to run with xtrace (would leak secrets)" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKER="$ROOT/worker"
TOML="$WORKER/wrangler.toml"
PUBSWIFT="$ROOT/app/Sources/DiskPrune/Licensing/PublicKeys.swift"
BANNED_KV="c273cf8e9c864d5bbd46840db2a7f153"
MODE="check"
for arg in "$@"; do
  case "$arg" in
    --apply) MODE="apply" ;;
    --check) MODE="check" ;;
    -h|--help)
      sed -n '2,22p' "$0"
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

wrangler() {
  (cd "$WORKER" && npx wrangler "$@")
}

have_wrangler_auth() {
  local out
  out="$(wrangler whoami 2>&1)" || return 1
  if printf '%s\n' "$out" | grep -qiE 'not authenticated|not logged in|please run `wrangler login`'; then
    return 1
  fi
  return 0
}

toml_get() {
  node --input-type=module -e "
    import { readFileSync } from 'node:fs';
    const src = readFileSync(process.argv[1], 'utf8');
    const kind = process.argv[2];
    if (kind === 'd1') {
      const m = src.match(/database_id\\s*=\\s*\"([^\"]+)\"/);
      process.stdout.write(m ? m[1] : '');
    } else if (kind === 'kv') {
      const m = src.match(/binding\\s*=\\s*\"RATE_LIMITS\"\\s*\\nid\\s*=\\s*\"([^\"]+)\"/);
      process.stdout.write(m ? m[1] : '');
    } else if (kind === 'pub') {
      const vars = src.slice(src.indexOf('[vars]'));
      const m = vars.match(/LICENSE_SIGNING_PUB_K1\\s*=\\s*\"([^\"]+)\"/);
      process.stdout.write(m ? m[1] : '');
    }
  " "$TOML" "$1"
}

swift_k1() {
  node --input-type=module -e "
    import { readFileSync } from 'node:fs';
    const src = readFileSync(process.argv[1], 'utf8');
    const m = src.match(/static let k1Base64 = \"([A-Za-z0-9+/=]+)\"/);
    process.stdout.write(m ? m[1] : '');
  " "$PUBSWIFT"
}

patch_toml() {
  local key="$1" value="$2"
  node --input-type=module -e "
    import { readFileSync, writeFileSync } from 'node:fs';
    const path = process.argv[1];
    const key = process.argv[2];
    const value = process.argv[3];
    let src = readFileSync(path, 'utf8');
    if (key === 'd1') {
      src = src.replace(/database_id\\s*=\\s*\"[^\"]+\"/, 'database_id = \"' + value + '\"');
    } else if (key === 'kv') {
      src = src.replace(/(binding\\s*=\\s*\"RATE_LIMITS\"\\s*\\nid\\s*=\\s*)\"[^\"]+\"/, '\$1\"' + value + '\"');
    } else if (key === 'pub') {
      src = src.replace(/LICENSE_SIGNING_PUB_K1\\s*=\\s*\"[^\"]+\"/, 'LICENSE_SIGNING_PUB_K1 = \"' + value + '\"');
    } else {
      throw new Error('unknown patch key');
    }
    writeFileSync(path, src);
  " "$TOML" "$key" "$value"
}

patch_swift_k1() {
  local value="$1"
  node --input-type=module -e "
    import { readFileSync, writeFileSync } from 'node:fs';
    const path = process.argv[1];
    const value = process.argv[2];
    let src = readFileSync(path, 'utf8');
    const next = src.replace(/static let k1Base64 = \"[A-Za-z0-9+/=]+\"/, 'static let k1Base64 = \"' + value + '\"');
    if (next === src) throw new Error('PublicKeys.k1Base64 not patched');
    writeFileSync(path, next);
  " "$PUBSWIFT" "$value"
}

generate_keys_json() {
  node --input-type=module -e '
    const pair = await crypto.subtle.generateKey({ name: "Ed25519" }, true, ["sign", "verify"]);
    const b64 = (buf) => Buffer.from(buf).toString("base64");
    const pkcs8 = b64(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
    const pub = b64(await crypto.subtle.exportKey("raw", pair.publicKey));
    const enc = b64(crypto.getRandomValues(new Uint8Array(32)));
    process.stdout.write(JSON.stringify({ pub, pkcs8, enc }));
  '
}

put_secret() {
  local name="$1" value="$2"
  if [[ -z "$value" ]]; then
    echo "error: empty value for $name" >&2
    return 1
  fi
  printf '%s' "$value" | wrangler secret put "$name" >/dev/null
  echo "secret $name: put"
}

prompt_secret() {
  local name="$1"
  local env_val="${!name:-}"
  if [[ -n "$env_val" ]]; then
    printf '%s' "$env_val"
    return 0
  fi
  if [[ ! -t 0 ]]; then
    echo "error: $name not set and stdin is not a tty" >&2
    return 1
  fi
  printf 'Paste %s (input hidden): ' "$name" >&2
  local value
  IFS= read -r -s value
  printf '\n' >&2
  printf '%s' "$value"
}

parse_d1_id() {
  grep -Eo '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | tail -1
}

parse_kv_id() {
  grep -Eo '[0-9a-f]{32}' | tail -1
}

echo "== DiskPrune Worker provision ($MODE) =="
echo "repo: $ROOT"

node "$ROOT/scripts/check-licensing-config.mjs" || true
echo "PublicKeys.k1Base64 = $(swift_k1)"
echo "wrangler D1 id      = $(toml_get d1)"
echo "wrangler KV id      = $(toml_get kv)"

if ! have_wrangler_auth; then
  echo "wrangler: NOT AUTHENTICATED"
  echo "  npx wrangler login"
  echo "  # or export CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID"
  if [[ "$MODE" == "apply" ]]; then
    echo "error: --apply requires Wrangler authentication" >&2
    exit 1
  fi
  echo "secrets: unknown (no auth)"
  echo "Gate 3: NOT PASS — production D1/KV/secrets and a live Stripe purchase remain."
  exit 0
fi

echo "wrangler: authenticated"
secret_list="$(mktemp)"
if wrangler secret list >"$secret_list" 2>/dev/null; then
  echo "secrets present (names only):"
  sed 's/^/  /' "$secret_list"
else
  echo "secrets: list unavailable"
fi
rm -f "$secret_list"

if [[ "$MODE" != "apply" ]]; then
  echo "check complete. re-run with --apply to provision."
  exit 0
fi

echo
echo "This will:"
echo "  - create D1 diskprune-licenses and KV RATE_LIMITS if ids are placeholders"
echo "  - generate a NEW Ed25519 k1 pair and AES-256 encryption key"
echo "  - patch PublicKeys.k1Base64 and wrangler.toml [vars] LICENSE_SIGNING_PUB_K1"
echo "  - wrangler secret put LICENSE_SIGNING_KEY_K1, LICENSE_ENCRYPTION_KEY,"
echo "    STRIPE_WEBHOOK_SECRET, RESEND_API_KEY"
echo "  - apply migrations/0001_init.sql remotely and wrangler deploy"
echo "  - existing issued tokens will NOT verify after a key rotation"
echo "Private key material is never printed or written to a file."
if [[ -t 0 ]]; then
  printf "Type APPLY to continue: "
  read -r confirm
  if [[ "$confirm" != "APPLY" ]]; then
    echo "aborted"
    exit 1
  fi
fi

d1_id="$(toml_get d1)"
if [[ "$d1_id" == "REPLACE_WITH_D1_DATABASE_ID" ]]; then
  echo "creating D1 diskprune-licenses..."
  d1_out="$(wrangler d1 create diskprune-licenses 2>&1)" || {
    echo "$d1_out" >&2
    echo "error: d1 create failed" >&2
    exit 1
  }
  d1_id="$(printf '%s\n' "$d1_out" | parse_d1_id)"
  if [[ -z "$d1_id" ]]; then
    echo "$d1_out" >&2
    echo "error: could not parse D1 id" >&2
    exit 1
  fi
  patch_toml d1 "$d1_id"
  echo "D1 id: $d1_id"
else
  echo "D1 already configured: $d1_id"
fi

kv_id="$(toml_get kv)"
if [[ "$kv_id" == "REPLACE_WITH_KV_NAMESPACE_ID" ]]; then
  echo "creating KV RATE_LIMITS..."
  kv_out="$(wrangler kv namespace create RATE_LIMITS 2>&1)" || {
    echo "$kv_out" >&2
    echo "error: kv namespace create failed" >&2
    exit 1
  }
  kv_id="$(printf '%s\n' "$kv_out" | parse_kv_id)"
  if [[ -z "$kv_id" ]]; then
    echo "$kv_out" >&2
    echo "error: could not parse KV id" >&2
    exit 1
  fi
  if [[ "$kv_id" == "$BANNED_KV" ]]; then
    echo "error: refused to bind RATE_LIMITS to legacy LICENSES KV $BANNED_KV" >&2
    exit 1
  fi
  patch_toml kv "$kv_id"
  echo "KV RATE_LIMITS id: $kv_id"
else
  if [[ "$kv_id" == "$BANNED_KV" ]]; then
    echo "error: RATE_LIMITS is the banned legacy LICENSES id" >&2
    exit 1
  fi
  echo "KV already configured: $kv_id"
fi

echo "generating k1 signing pair + encryption key in memory..."
keys_json="$(generate_keys_json)"
pub="$(node -e 'process.stdout.write(JSON.parse(process.argv[1]).pub)' "$keys_json")"
pkcs8="$(node -e 'process.stdout.write(JSON.parse(process.argv[1]).pkcs8)' "$keys_json")"
enc="$(node -e 'process.stdout.write(JSON.parse(process.argv[1]).enc)' "$keys_json")"
keys_json=""
unset keys_json

if [[ ${#pub} -lt 40 ]]; then
  echo "error: generated public key looks truncated" >&2
  exit 1
fi

patch_toml pub "$pub"
patch_swift_k1 "$pub"
echo "public k1 written to PublicKeys.swift and wrangler.toml [vars]"

put_secret LICENSE_SIGNING_KEY_K1 "$pkcs8"
put_secret LICENSE_ENCRYPTION_KEY "$enc"
pkcs8=""
enc=""
unset pkcs8 enc
pub=""
unset pub

stripe_wh="$(prompt_secret STRIPE_WEBHOOK_SECRET)"
resend="$(prompt_secret RESEND_API_KEY)"
put_secret STRIPE_WEBHOOK_SECRET "$stripe_wh"
put_secret RESEND_API_KEY "$resend"
stripe_wh=""
resend=""
unset stripe_wh resend

if [[ -n "${STRIPE_PRICE_ID:-}" ]]; then
  put_secret STRIPE_PRICE_ID "$STRIPE_PRICE_ID"
fi

echo "applying D1 migrations remotely..."
wrangler d1 migrations apply diskprune-licenses --remote

echo "deploying Worker..."
if wrangler deploy; then
  echo "deploy: ok"
else
  echo "deploy: FAILED — custom domain api.diskprune.com may need to be attached in the Cloudflare dashboard." >&2
  echo "wrangler.toml and PublicKeys.swift were still updated; commit those after a successful deploy." >&2
  exit 1
fi

node "$ROOT/scripts/check-licensing-config.mjs"

echo
echo "NEXT (required, you do this):"
echo "  1. Commit worker/wrangler.toml and app/Sources/DiskPrune/Licensing/PublicKeys.swift"
echo "     (public k1 + D1/KV ids only — no secrets)."
echo "  2. Point Stripe webhook to https://api.diskprune.com/webhook"
echo "  3. Do NOT UPDATE products.stripe_price_id away from price_diskprune_personal"
echo "     unless you ALSO insert the live Stripe price as a second products row"
echo "     (same entitlements) AND/OR set Worker secret STRIPE_PRICE_ID to that id."
echo "     Stripe checkout.session.completed does not include line_items unless expanded."
echo "     The Worker falls back to the sole D1 SKU, then to price_diskprune_personal."
echo "  4. Live-purchase a license and activate in the Mac app (Gate 3)."
echo "Gate 3 is NOT PASS until that live purchase verifies."

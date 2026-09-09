const CROCKFORD = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
const KEY_BYTES = 16;
const KEY_CHARS = 20;

export const LICENSE_KEY_RE =
  /^PRUNE-[0-9A-HJKMNP-TV-Z]{5}-[0-9A-HJKMNP-TV-Z]{5}-[0-9A-HJKMNP-TV-Z]{5}-[0-9A-HJKMNP-TV-Z]{5}$/;

export function generateLicenseKey() {
  const bytes = new Uint8Array(KEY_BYTES);
  crypto.getRandomValues(bytes);
  const chars = encodeCrockford(bytes, KEY_CHARS);
  return `PRUNE-${chars.slice(0, 5)}-${chars.slice(5, 10)}-${chars.slice(10, 15)}-${chars.slice(15, 20)}`;
}

function encodeCrockford(bytes, length) {
  let bits = 0;
  let value = 0;
  let out = "";
  for (const byte of bytes) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5 && out.length < length) {
      out += CROCKFORD[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (out.length < length && bits > 0) {
    out += CROCKFORD[(value << (5 - bits)) & 31];
  }
  while (out.length < length) out += CROCKFORD[0];
  return out.slice(0, length);
}

export async function sha256Hex(text) {
  const data = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function b64urlEncode(bytes) {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function b64urlDecode(text) {
  const padded = text.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((text.length + 3) % 4);
  const bin = atob(padded);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function decodeKey(b64) {
  const padded = b64.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((b64.length + 3) % 4);
  const bin = atob(padded);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function aesKey(raw) {
  return crypto.subtle.importKey("raw", raw, { name: "AES-GCM" }, false, ["encrypt", "decrypt"]);
}

function activeEncVersion(env) {
  return env.LICENSE_ENCRYPTION_KEY_V2 ? "v2" : "v1";
}

function keyForVersion(env, version) {
  if (version === "v2") {
    if (!env.LICENSE_ENCRYPTION_KEY_V2) throw new Error("missing LICENSE_ENCRYPTION_KEY_V2");
    return decodeKey(env.LICENSE_ENCRYPTION_KEY_V2);
  }
  if (!env.LICENSE_ENCRYPTION_KEY) throw new Error("missing LICENSE_ENCRYPTION_KEY");
  return decodeKey(env.LICENSE_ENCRYPTION_KEY);
}

export async function encryptLicenseKey(plaintext, licenseId, env) {
  const version = activeEncVersion(env);
  const raw = keyForVersion(env, version);
  const key = await aesKey(raw);
  const iv = new Uint8Array(12);
  crypto.getRandomValues(iv);
  const aad = new TextEncoder().encode(licenseId);
  const ct = new Uint8Array(
    await crypto.subtle.encrypt({ name: "AES-GCM", iv, additionalData: aad }, key, new TextEncoder().encode(plaintext)),
  );
  return `${version}.${b64urlEncode(iv)}.${b64urlEncode(ct)}`;
}

export async function decryptLicenseKey(stored, licenseId, env) {
  const parts = String(stored).split(".");
  if (parts.length !== 3) throw new Error("malformed ciphertext");
  const [version, ivB64, ctB64] = parts;
  const raw = keyForVersion(env, version);
  const key = await aesKey(raw);
  const iv = b64urlDecode(ivB64);
  const ct = b64urlDecode(ctB64);
  const aad = new TextEncoder().encode(licenseId);
  const pt = await crypto.subtle.decrypt({ name: "AES-GCM", iv, additionalData: aad }, key, ct);
  const plaintext = new TextDecoder().decode(pt);
  const current = activeEncVersion(env);
  const reencrypted = version !== current ? await encryptLicenseKey(plaintext, licenseId, env) : null;
  return { plaintext, reencrypted };
}

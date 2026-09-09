const DAY = 24 * 60 * 60;
export const TOKEN_TTL_ACTIVE = 90 * DAY;
export const TOKEN_TTL_DISPUTED = 14 * DAY;

function b64urlEncode(bytes) {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function b64urlEncodeText(text) {
  return b64urlEncode(new TextEncoder().encode(text));
}

function b64urlDecode(text) {
  const padded = text.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((text.length + 3) % 4);
  const bin = atob(padded);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function decodeB64(b64) {
  const padded = b64.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((b64.length + 3) % 4);
  const bin = atob(padded);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function activeKid(env) {
  return env.LICENSE_SIGNING_KEY_K2 ? "k2" : "k1";
}

async function signingKey(env, kid) {
  const b64 = kid === "k2" ? env.LICENSE_SIGNING_KEY_K2 : env.LICENSE_SIGNING_KEY_K1;
  if (!b64) throw new Error(`missing signing key for ${kid}`);
  return crypto.subtle.importKey("pkcs8", decodeB64(b64), { name: "Ed25519" }, false, ["sign"]);
}

async function verifyKey(env, kid) {
  const b64 = kid === "k2" ? env.LICENSE_SIGNING_PUB_K2 : env.LICENSE_SIGNING_PUB_K1;
  if (!b64) throw new Error(`missing verify key for ${kid}`);
  return crypto.subtle.importKey("raw", decodeB64(b64), { name: "Ed25519" }, false, ["verify"]);
}

export async function issueToken({ keyHash, deviceId, entitlements, licenseType, maxDevices, ttlSeconds, env, now }) {
  const kid = activeKid(env);
  const iat = now ?? Math.floor(Date.now() / 1000);
  const header = JSON.stringify({ alg: "EdDSA", typ: "DPL", kid });
  const payload = JSON.stringify({
    v: 1,
    jti: crypto.randomUUID(),
    sub: keyHash,
    dev: deviceId,
    ent: entitlements,
    lt: licenseType,
    md: maxDevices,
    org: null,
    iat,
    nbf: iat,
    exp: iat + ttlSeconds,
  });
  const signingInput = `${b64urlEncodeText(header)}.${b64urlEncodeText(payload)}`;
  const key = await signingKey(env, kid);
  const sig = new Uint8Array(
    await crypto.subtle.sign("Ed25519", key, new TextEncoder().encode(signingInput)),
  );
  return {
    token: `${signingInput}.${b64urlEncode(sig)}`,
    expires_at: iat + ttlSeconds,
  };
}

export async function verifyToken(token, env, { ignoreExp = false, now } = {}) {
  if (typeof token !== "string") return { ok: false, error: "INVALID_TOKEN" };
  const parts = token.split(".");
  if (parts.length !== 3) return { ok: false, error: "INVALID_TOKEN" };
  let header;
  try {
    header = JSON.parse(new TextDecoder().decode(b64urlDecode(parts[0])));
  } catch {
    return { ok: false, error: "INVALID_TOKEN" };
  }
  if (header.typ !== "DPL" || header.alg !== "EdDSA") return { ok: false, error: "INVALID_TOKEN" };
  const kid = header.kid;
  if (kid !== "k1" && kid !== "k2") return { ok: false, error: "INVALID_TOKEN" };
  const pubB64 = kid === "k2" ? env.LICENSE_SIGNING_PUB_K2 : env.LICENSE_SIGNING_PUB_K1;
  if (!pubB64) return { ok: false, error: "INVALID_TOKEN" };
  const signingInput = `${parts[0]}.${parts[1]}`;
  const key = await verifyKey(env, kid);
  const valid = await crypto.subtle.verify(
    "Ed25519",
    key,
    b64urlDecode(parts[2]),
    new TextEncoder().encode(signingInput),
  );
  if (!valid) return { ok: false, error: "INVALID_TOKEN" };
  let payload;
  try {
    payload = JSON.parse(new TextDecoder().decode(b64urlDecode(parts[1])));
  } catch {
    return { ok: false, error: "INVALID_TOKEN" };
  }
  if (payload.v !== 1) return { ok: false, error: "INVALID_TOKEN" };
  const t = now ?? Math.floor(Date.now() / 1000);
  if (!ignoreExp && payload.exp <= t) return { ok: false, error: "INVALID_TOKEN", payload, expired: true };
  return { ok: true, header, payload };
}

export function ttlForStatus(status) {
  return status === "disputed" ? TOKEN_TTL_DISPUTED : TOKEN_TTL_ACTIVE;
}

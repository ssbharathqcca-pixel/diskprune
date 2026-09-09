import { LICENSE_KEY_RE, sha256Hex } from "./crypto.js";
import { issueToken, ttlForStatus, verifyToken } from "./tokens.js";
import {
  activeDevices,
  activeSeatCount,
  getLicenseByHash,
  getLicenseBySession,
  licensesByEmail,
  releaseDevice,
  touchDevice,
  tryClaimSeat,
  getDevice,
  getFulfillment,
} from "./db.js";
import { sendLicenseEmail } from "./email.js";
import { clientIp, limitIp, limitKey } from "./ratelimit.js";

function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...extraHeaders },
  });
}

function parseEntitlements(row) {
  try {
    const v = JSON.parse(row.entitlements_json);
    return Array.isArray(v) ? v : ["cleanup"];
  } catch {
    return ["cleanup"];
  }
}

export async function handleActivate(request, env) {
  const ip = clientIp(request);
  const ipLimit = await limitIp(env, "activate", ip, 10);
  if (!ipLimit.ok) return json({ error: "RATE_LIMIT" }, 429);
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "INVALID_REQUEST" }, 400);
  }
  const licenseKey = String(body.license_key || "").trim().toUpperCase();
  const deviceId = String(body.device_id || "").trim();
  const deviceName = body.device_name ? String(body.device_name) : null;
  if (!LICENSE_KEY_RE.test(licenseKey)) return json({ error: "INVALID_FORMAT" }, 400);
  if (!deviceId) return json({ error: "INVALID_REQUEST" }, 400);
  const keyHash = await sha256Hex(licenseKey);
  const hashLimit = await limitKey(env, "activate-key", keyHash, 20);
  if (!hashLimit.ok) return json({ error: "RATE_LIMIT" }, 429);
  const license = await getLicenseByHash(env.DB, keyHash);
  if (!license) return json({ error: "LICENSE_NOT_FOUND" }, 404);
  if (license.status === "revoked") return json({ error: "LICENSE_REVOKED" }, 403);
  if (license.status === "disputed") return json({ error: "LICENSE_DISPUTED" }, 409);

  const claimed = await tryClaimSeat(env.DB, {
    licenseId: license.id,
    deviceId,
    deviceName,
    maxDevices: Number(license.max_devices),
  });
  if (!claimed) {
    return json({ error: "SEAT_LIMIT", devices: await activeDevices(env.DB, license.id) }, 409);
  }
  const issued = await issueToken({
    keyHash: license.key_hash,
    deviceId,
    entitlements: parseEntitlements(license),
    licenseType: license.license_type,
    maxDevices: Number(license.max_devices),
    ttlSeconds: ttlForStatus(license.status),
    env,
  });
  return json({
    token: issued.token,
    expires_at: issued.expires_at,
    max_devices: Number(license.max_devices),
    entitlements: parseEntitlements(license),
  });
}

export async function handleRefresh(request, env) {
  const ip = clientIp(request);
  if (!(await limitIp(env, "refresh", ip, 60)).ok) return json({ error: "RATE_LIMIT" }, 429);
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "INVALID_REQUEST" }, 400);
  }
  const verified = await verifyToken(String(body.token || ""), env, { ignoreExp: true });
  if (!verified.ok) return json({ error: "INVALID_TOKEN" }, 401);
  const license = await getLicenseByHash(env.DB, verified.payload.sub);
  if (!license) return json({ error: "LICENSE_NOT_FOUND" }, 404);
  if (license.status === "revoked") return json({ error: "LICENSE_REVOKED" }, 403);
  const device = await getDevice(env.DB, license.id, verified.payload.dev);
  if (!device) return json({ error: "DEVICE_UNKNOWN" }, 403);
  if (device.released_at != null) return json({ error: "DEVICE_RELEASED" }, 403);
  await touchDevice(env.DB, license.id, device.device_id);
  const issued = await issueToken({
    keyHash: license.key_hash,
    deviceId: device.device_id,
    entitlements: parseEntitlements(license),
    licenseType: license.license_type,
    maxDevices: Number(license.max_devices),
    ttlSeconds: ttlForStatus(license.status),
    env,
  });
  return json({ token: issued.token, expires_at: issued.expires_at });
}

export async function handleRelease(request, env) {
  const ip = clientIp(request);
  if (!(await limitIp(env, "release", ip, 10)).ok) return json({ error: "RATE_LIMIT" }, 429);
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "INVALID_REQUEST" }, 400);
  }
  const licenseKey = String(body.license_key || "").trim().toUpperCase();
  const deviceId = String(body.device_id || "").trim();
  if (!LICENSE_KEY_RE.test(licenseKey) || !deviceId) return json({ error: "INVALID_REQUEST" }, 400);
  const license = await getLicenseByHash(env.DB, await sha256Hex(licenseKey));
  if (!license) return json({ error: "LICENSE_NOT_FOUND" }, 404);
  await releaseDevice(env.DB, license.id, deviceId);
  const used = await activeSeatCount(env.DB, license.id);
  return json({ released: true, seats_available: Math.max(0, Number(license.max_devices) - used) });
}

export async function handleResend(request, env) {
  const ip = clientIp(request);
  if (!(await limitIp(env, "resend", ip, 3)).ok) return json({ error: "RATE_LIMIT" }, 429);
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ ok: true });
  }
  const email = String(body.email || "").trim().toLowerCase();
  if (!email || !email.includes("@")) return json({ ok: true });
  if (!(await limitKey(env, "resend-email", email, 3, 86400)).ok) return json({ error: "RATE_LIMIT" }, 429);
  const rows = await licensesByEmail(env.DB, email);
  for (const row of rows) {
    if (row.status === "revoked") continue;
    try {
      await sendLicenseEmail(env, row);
    } catch {
      // still 200 — no enumeration
    }
  }
  return json({ ok: true });
}

function maskEmail(email) {
  const [local, domain] = String(email).split("@");
  if (!domain) return "•••";
  const first = local.slice(0, 1) || "•";
  return `${first}•••@${domain}`;
}

export async function handleCheckoutStatus(sessionId, env) {
  if (!sessionId) return json({ error: "NOT_FOUND" }, 404);
  const fulfillment = await getFulfillment(env.DB, sessionId);
  const license = await getLicenseBySession(env.DB, sessionId);
  if (!fulfillment && !license) return json({ error: "NOT_FOUND" }, 404);
  let payment_state = "unknown";
  let delivery_state = "unknown";
  let email_masked = null;
  if (license) {
    payment_state = "paid";
    delivery_state = license.email_state;
    email_masked = maskEmail(license.email);
  } else if (fulfillment?.state === "failed") {
    payment_state = "failed";
    delivery_state = "failed";
  } else {
    payment_state = "unpaid";
    delivery_state = "pending";
  }
  return json({ payment_state, delivery_state, email_masked });
}

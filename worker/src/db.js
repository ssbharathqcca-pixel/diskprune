export function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}

export function isUniqueError(err) {
  const msg = String(err?.message || err || "");
  return /UNIQUE constraint failed/i.test(msg) || err?.code === "SQLITE_CONSTRAINT_UNIQUE";
}

export async function recordEvent(db, stripeEventId, type) {
  try {
    await db.prepare("INSERT INTO events (stripe_event_id, type, received_at) VALUES (?, ?, ?)").bind(stripeEventId, type, nowSeconds()).run();
  } catch (err) {
    if (!isUniqueError(err)) throw err;
  }
}

export async function getProduct(db, priceId) {
  if (!priceId) return null;
  return db.prepare("SELECT * FROM products WHERE stripe_price_id = ?").bind(priceId).first();
}

/** Launch-safe: a live Payment Link payload has no line_items. If D1 has exactly one SKU, use it. */
export async function getSoleProduct(db) {
  const res = await db.prepare("SELECT * FROM products LIMIT 2").all();
  const rows = res?.results ?? [];
  return rows.length === 1 ? rows[0] : null;
}

export async function getLicenseByHash(db, keyHash) {
  return db.prepare("SELECT * FROM licenses WHERE key_hash = ?").bind(keyHash).first();
}

export async function getLicenseById(db, id) {
  return db.prepare("SELECT * FROM licenses WHERE id = ?").bind(id).first();
}

export async function getLicenseBySession(db, sessionId) {
  return db.prepare("SELECT * FROM licenses WHERE stripe_session_id = ?").bind(sessionId).first();
}

export async function getLicenseByCustomer(db, customerId) {
  if (!customerId) return null;
  return db.prepare("SELECT * FROM licenses WHERE stripe_customer_id = ? ORDER BY created_at DESC").bind(customerId).first();
}

export async function getFulfillment(db, sessionId) {
  return db.prepare("SELECT * FROM fulfillments WHERE stripe_session_id = ?").bind(sessionId).first();
}

export async function insertPendingFulfillment(db, sessionId) {
  const ts = nowSeconds();
  await db.prepare(
    "INSERT INTO fulfillments (stripe_session_id, license_id, state, created_at, updated_at) VALUES (?, NULL, 'pending', ?, ?)",
  ).bind(sessionId, ts, ts).run();
}

export async function updateFulfillment(db, sessionId, { state, licenseId }) {
  const ts = nowSeconds();
  await db.prepare(
    "UPDATE fulfillments SET state = ?, license_id = COALESCE(?, license_id), updated_at = ? WHERE stripe_session_id = ?",
  ).bind(state, licenseId ?? null, ts, sessionId).run();
}

export async function insertLicense(db, row) {
  const ts = nowSeconds();
  await db.prepare(
    `INSERT INTO licenses (
      id, key_hash, encrypted_key, email, license_type, entitlements_json, max_devices,
      org_id, status, stripe_session_id, stripe_customer_id, email_state, email_attempts,
      email_last_attempt_at, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, NULL, 'active', ?, ?, 'pending', 0, NULL, ?, ?)`,
  ).bind(
    row.id,
    row.key_hash,
    row.encrypted_key,
    row.email,
    row.license_type,
    row.entitlements_json,
    row.max_devices,
    row.stripe_session_id,
    row.stripe_customer_id ?? null,
    ts,
    ts,
  ).run();
}

export async function setLicenseStatus(db, licenseId, status) {
  await db.prepare("UPDATE licenses SET status = ?, updated_at = ? WHERE id = ?").bind(status, nowSeconds(), licenseId).run();
}

export async function setEmailState(db, licenseId, state, attempts) {
  await db.prepare(
    "UPDATE licenses SET email_state = ?, email_attempts = ?, email_last_attempt_at = ?, updated_at = ? WHERE id = ?",
  ).bind(state, attempts, nowSeconds(), nowSeconds(), licenseId).run();
}

export async function updateEncryptedKey(db, licenseId, encrypted) {
  await db.prepare("UPDATE licenses SET encrypted_key = ?, updated_at = ? WHERE id = ?").bind(encrypted, nowSeconds(), licenseId).run();
}

export async function getDevice(db, licenseId, deviceId) {
  return db.prepare("SELECT * FROM devices WHERE license_id = ? AND device_id = ?").bind(licenseId, deviceId).first();
}

export async function activeSeatCount(db, licenseId) {
  const row = await db.prepare(
    "SELECT COUNT(*) AS n FROM devices WHERE license_id = ? AND released_at IS NULL",
  ).bind(licenseId).first();
  return Number(row?.n ?? 0);
}

export async function activeDevices(db, licenseId) {
  const res = await db.prepare(
    "SELECT device_id, device_name, last_seen FROM devices WHERE license_id = ? AND released_at IS NULL",
  ).bind(licenseId).all();
  return res.results ?? [];
}

function changesOf(result) {
  return Number(result?.meta?.changes ?? 0);
}

export async function tryClaimSeat(db, { licenseId, deviceId, deviceName, maxDevices }) {
  const ts = nowSeconds();
  const existing = await getDevice(db, licenseId, deviceId);
  if (existing && existing.released_at == null) {
    await db.prepare(
      "UPDATE devices SET device_name = COALESCE(?, device_name), last_seen = ? WHERE license_id = ? AND device_id = ?",
    ).bind(deviceName ?? null, ts, licenseId, deviceId).run();
    return true;
  }

  if (existing) {
    const updated = await db.prepare(
      `UPDATE devices
          SET released_at = NULL,
              last_seen = ?,
              device_name = COALESCE(?, device_name)
        WHERE license_id = ? AND device_id = ? AND released_at IS NOT NULL
          AND (SELECT COUNT(*) FROM devices WHERE license_id = ? AND released_at IS NULL) < ?`,
    ).bind(ts, deviceName ?? null, licenseId, deviceId, licenseId, maxDevices).run();
    return changesOf(updated) > 0;
  }

  try {
    const inserted = await db.prepare(
      `INSERT INTO devices (license_id, device_id, device_name, first_seen, last_seen, released_at)
       SELECT ?, ?, ?, ?, ?, NULL
       WHERE (SELECT COUNT(*) FROM devices WHERE license_id = ? AND released_at IS NULL) < ?`,
    ).bind(licenseId, deviceId, deviceName ?? null, ts, ts, licenseId, maxDevices).run();
    return changesOf(inserted) > 0;
  } catch (err) {
    if (!isUniqueError(err)) throw err;
    const raced = await getDevice(db, licenseId, deviceId);
    if (raced && raced.released_at == null) {
      await db.prepare(
        "UPDATE devices SET device_name = COALESCE(?, device_name), last_seen = ? WHERE license_id = ? AND device_id = ?",
      ).bind(deviceName ?? null, ts, licenseId, deviceId).run();
      return true;
    }
    return false;
  }
}

export async function releaseDevice(db, licenseId, deviceId) {
  const ts = nowSeconds();
  await db.prepare(
    "UPDATE devices SET released_at = COALESCE(released_at, ?) WHERE license_id = ? AND device_id = ?",
  ).bind(ts, licenseId, deviceId).run();
}

export async function touchDevice(db, licenseId, deviceId) {
  await db.prepare(
    "UPDATE devices SET last_seen = ? WHERE license_id = ? AND device_id = ? AND released_at IS NULL",
  ).bind(nowSeconds(), licenseId, deviceId).run();
}

export async function licensesByEmail(db, email) {
  const res = await db.prepare("SELECT * FROM licenses WHERE email = ? COLLATE NOCASE").bind(email).all();
  return res.results ?? [];
}

export async function failedEmails(db) {
  const res = await db.prepare(
    "SELECT * FROM licenses WHERE email_state = 'failed' AND email_attempts < 5 AND status = 'active'",
  ).all();
  return res.results ?? [];
}

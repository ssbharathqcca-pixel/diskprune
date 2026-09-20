import Stripe from "stripe";
import {
  generateLicenseKey,
  encryptLicenseKey,
  sha256Hex,
} from "./crypto.js";
import {
  getFulfillment,
  getLicenseByCustomer,
  getLicenseBySession,
  getProduct,
  getSoleProduct,
  insertLicense,
  insertPendingFulfillment,
  isUniqueError,
  recordEvent,
  setLicenseStatus,
  updateFulfillment,
} from "./db.js";
import { sendLicenseEmail } from "./email.js";

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

const SEED_PRICE_ID = "price_diskprune_personal";

function candidatePriceIds(session, env) {
  const ids = [
    session?.line_items?.data?.[0]?.price?.id,
    session?.metadata?.stripe_price_id,
    env.STRIPE_PRICE_ID,
    SEED_PRICE_ID,
  ].filter((id) => typeof id === "string" && id.length > 0);
  return [...new Set(ids)];
}

async function resolveProduct(env, session) {
  for (const id of candidatePriceIds(session, env)) {
    const product = await getProduct(env.DB, id);
    if (product) return product;
  }
  const sole = await getSoleProduct(env.DB);
  if (sole) return sole;
  throw Object.assign(new Error("unknown product"), { status: 500 });
}

async function constructEvent(request, env) {
  const raw = await request.text();
  const signature = request.headers.get("stripe-signature");
  if (!signature || !env.STRIPE_WEBHOOK_SECRET) {
    const err = new Error("bad signature");
    err.status = 400;
    throw err;
  }
  const stripe = new Stripe(env.STRIPE_SECRET_KEY || "sk_test_dummy", { apiVersion: "2024-06-20" });
  try {
    return await stripe.webhooks.constructEventAsync(
      raw,
      signature,
      env.STRIPE_WEBHOOK_SECRET,
      undefined,
      Stripe.createSubtleCryptoProvider(),
    );
  } catch {
    const err = new Error("bad signature");
    err.status = 400;
    throw err;
  }
}

async function fulfilSession(env, session) {
  const sessionId = session.id;
  const email = session.customer_details?.email;
  if (!email) throw Object.assign(new Error("missing email"), { status: 500 });

  try {
    await insertPendingFulfillment(env.DB, sessionId);
  } catch (err) {
    if (!isUniqueError(err)) throw err;
  }

  const existing = await getFulfillment(env.DB, sessionId);
  if (existing?.state === "fulfilled" && existing.license_id) {
    return json({ received: true });
  }

  const already = await getLicenseBySession(env.DB, sessionId);
  if (already) {
    await updateFulfillment(env.DB, sessionId, { state: "fulfilled", licenseId: already.id });
    return json({ received: true });
  }

  const product = await resolveProduct(env, session);
  if (!product) throw Object.assign(new Error("unknown product"), { status: 500 });

  const licenseId = crypto.randomUUID();
  const plaintext = generateLicenseKey();
  const keyHash = await sha256Hex(plaintext);
  const encrypted = await encryptLicenseKey(plaintext, licenseId, env);
  try {
    await insertLicense(env.DB, {
      id: licenseId,
      key_hash: keyHash,
      encrypted_key: encrypted,
      email,
      license_type: product.license_type,
      entitlements_json: product.entitlements_json,
      max_devices: product.max_devices,
      stripe_session_id: sessionId,
      stripe_customer_id: session.customer || null,
    });
  } catch (err) {
    if (isUniqueError(err)) {
      const race = await getLicenseBySession(env.DB, sessionId);
      if (race) {
        await updateFulfillment(env.DB, sessionId, { state: "fulfilled", licenseId: race.id });
        return json({ received: true });
      }
    }
    throw err;
  }
  await updateFulfillment(env.DB, sessionId, { state: "fulfilled", licenseId });
  const row = await getLicenseBySession(env.DB, sessionId);
  try {
    await sendLicenseEmail(env, row);
  } catch {
    // Delivery is recoverable. Fulfilment already committed.
  }
  return json({ received: true });
}

async function markPendingUnpaid(env, session) {
  try {
    await insertPendingFulfillment(env.DB, session.id);
  } catch (err) {
    if (!isUniqueError(err)) throw err;
  }
  return json({ received: true });
}

async function revokeByCustomer(env, customerId) {
  const license = await getLicenseByCustomer(env.DB, customerId);
  if (license) await setLicenseStatus(env.DB, license.id, "revoked");
}

async function setStatusByCustomer(env, customerId, status) {
  const license = await getLicenseByCustomer(env.DB, customerId);
  if (license) await setLicenseStatus(env.DB, license.id, status);
}

export async function handleWebhook(request, env) {
  let event;
  try {
    event = await constructEvent(request, env);
  } catch {
    return json({ error: "bad signature" }, 400);
  }

  try {
    await recordEvent(env.DB, event.id, event.type);
    const obj = event.data?.object || {};
    switch (event.type) {
      case "checkout.session.completed": {
        if (obj.payment_status === "paid") return await fulfilSession(env, obj);
        if (obj.payment_status === "unpaid") return await markPendingUnpaid(env, obj);
        if (obj.payment_status === "no_payment_required") {
          return json({ error: "no_payment_required rejected" }, 400);
        }
        return json({ received: true });
      }
      case "checkout.session.async_payment_succeeded":
        return await fulfilSession(env, obj);
      case "checkout.session.async_payment_failed": {
        try {
          await insertPendingFulfillment(env.DB, obj.id);
        } catch (err) {
          if (!isUniqueError(err)) throw err;
        }
        await updateFulfillment(env.DB, obj.id, { state: "failed" });
        return json({ received: true });
      }
      case "charge.refunded":
        await revokeByCustomer(env, obj.customer);
        return json({ received: true });
      case "charge.dispute.created":
        await setStatusByCustomer(env, obj.customer, "disputed");
        return json({ received: true });
      case "charge.dispute.closed": {
        const next = obj.status === "won" ? "active" : "revoked";
        await setStatusByCustomer(env, obj.customer, next);
        return json({ received: true });
      }
      default:
        return json({ received: true });
    }
  } catch (err) {
    if (err.status === 400) return json({ error: err.message }, 400);
    return json({ error: "fulfillment_failed" }, 500);
  }
}

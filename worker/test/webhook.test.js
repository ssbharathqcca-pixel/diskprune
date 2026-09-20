import { test } from "node:test";
import assert from "node:assert/strict";
import {
  checkoutEvent,
  failingInsertLicenseD1,
  fetchWorker,
  makeEnv,
  signedWebhook,
} from "./helpers.js";

test("T-WH-01 missing or bad signature returns 400 and writes nothing", async () => {
  const env = await makeEnv();
  const unsigned = new Request("https://api.diskprune.com/webhook", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(checkoutEvent()),
  });
  const res = await fetchWorker(env, unsigned);
  assert.equal(res.status, 400);
  const bad = await fetchWorker(env, signedWebhook(checkoutEvent(), "whsec_wrong"));
  assert.equal(bad.status, 400);
  const events = env.__sqlite.prepare("SELECT COUNT(*) AS n FROM events").get();
  const licenses = env.__sqlite.prepare("SELECT COUNT(*) AS n FROM licenses").get();
  assert.equal(events.n, 0);
  assert.equal(licenses.n, 0);
});

test("T-WH-02 valid completed+paid creates exactly one license", async () => {
  const env = await makeEnv();
  const res = await fetchWorker(env, signedWebhook(checkoutEvent()));
  assert.equal(res.status, 200);
  assert.equal(env.__sqlite.prepare("SELECT COUNT(*) AS n FROM licenses").get().n, 1);
  const license = env.__sqlite.prepare("SELECT * FROM licenses").get();
  assert.equal(license.email, "ada@example.com");
  assert.equal(license.status, "active");
  assert.match(license.encrypted_key, /^v1\./);
  assert.equal(license.key_hash.length, 64);
  assert.equal(env.__emails.length, 1);
  assert.match(env.__emails[0].text, /PRUNE-/);
});

test("T-WH-03 same event twice yields one license", async () => {
  const env = await makeEnv();
  const event = checkoutEvent();
  assert.equal((await fetchWorker(env, signedWebhook(event))).status, 200);
  assert.equal((await fetchWorker(env, signedWebhook(event))).status, 200);
  assert.equal(env.__sqlite.prepare("SELECT COUNT(*) AS n FROM licenses").get().n, 1);
});

test("T-WH-04 same session different event ids yields one license", async () => {
  const env = await makeEnv();
  const a = checkoutEvent({ id: "evt_a", sessionId: "cs_same" });
  const b = checkoutEvent({ id: "evt_b", sessionId: "cs_same" });
  assert.equal((await fetchWorker(env, signedWebhook(a))).status, 200);
  assert.equal((await fetchWorker(env, signedWebhook(b))).status, 200);
  assert.equal(env.__sqlite.prepare("SELECT COUNT(*) AS n FROM licenses").get().n, 1);
});

test("T-WH-05 restart between deliveries still yields one license", async () => {
  const env = await makeEnv();
  const event = checkoutEvent({ sessionId: "cs_restart" });
  assert.equal((await fetchWorker(env, signedWebhook(event))).status, 200);
  const env2 = await makeEnv();
  env2.DB = env.DB;
  env2.__sqlite = env.__sqlite;
  env2.LICENSE_ENCRYPTION_KEY = env.LICENSE_ENCRYPTION_KEY;
  env2.LICENSE_SIGNING_KEY_K1 = env.LICENSE_SIGNING_KEY_K1;
  env2.LICENSE_SIGNING_PUB_K1 = env.LICENSE_SIGNING_PUB_K1;
  env2.fetchImpl = env.fetchImpl;
  env2.__emails = env.__emails;
  assert.equal((await fetchWorker(env2, signedWebhook({ ...event, id: "evt_retry" }))).status, 200);
  assert.equal(env.__sqlite.prepare("SELECT COUNT(*) AS n FROM licenses").get().n, 1);
});

test("T-WH-06 concurrent deliveries create exactly one license", async () => {
  const env = await makeEnv();
  const event = checkoutEvent({ sessionId: "cs_race" });
  const [a, b] = await Promise.all([
    fetchWorker(env, signedWebhook({ ...event, id: "evt_race_1" })),
    fetchWorker(env, signedWebhook({ ...event, id: "evt_race_2" })),
  ]);
  assert.equal(a.status, 200);
  assert.equal(b.status, 200);
  assert.equal(env.__sqlite.prepare("SELECT COUNT(*) AS n FROM licenses").get().n, 1);
});

test("T-WH-07 completed+unpaid issues nothing and leaves fulfillment pending", async () => {
  const env = await makeEnv();
  const res = await fetchWorker(env, signedWebhook(checkoutEvent({ payment_status: "unpaid" })));
  assert.equal(res.status, 200);
  assert.equal(env.__sqlite.prepare("SELECT COUNT(*) AS n FROM licenses").get().n, 0);
  const f = env.__sqlite.prepare("SELECT * FROM fulfillments").get();
  assert.equal(f.state, "pending");
});

test("T-WH-08 async_payment_succeeded creates a license", async () => {
  const env = await makeEnv();
  await fetchWorker(env, signedWebhook(checkoutEvent({ payment_status: "unpaid", sessionId: "cs_async" })));
  const res = await fetchWorker(
    env,
    signedWebhook(checkoutEvent({ id: "evt_async", type: "checkout.session.async_payment_succeeded", sessionId: "cs_async" })),
  );
  assert.equal(res.status, 200);
  assert.equal(env.__sqlite.prepare("SELECT COUNT(*) AS n FROM licenses").get().n, 1);
});

test("T-WH-09 async_payment_failed issues no license", async () => {
  const env = await makeEnv();
  const res = await fetchWorker(
    env,
    signedWebhook(checkoutEvent({ type: "checkout.session.async_payment_failed", sessionId: "cs_fail" })),
  );
  assert.equal(res.status, 200);
  assert.equal(env.__sqlite.prepare("SELECT COUNT(*) AS n FROM licenses").get().n, 0);
  assert.equal(env.__sqlite.prepare("SELECT state FROM fulfillments").get().state, "failed");
});

test("T-WH-10 charge.refunded revokes the license", async () => {
  const env = await makeEnv();
  await fetchWorker(env, signedWebhook(checkoutEvent({ customer: "cus_refund" })));
  const res = await fetchWorker(
    env,
    signedWebhook({
      id: "evt_refund",
      type: "charge.refunded",
      data: { object: { customer: "cus_refund" } },
    }),
  );
  assert.equal(res.status, 200);
  assert.equal(env.__sqlite.prepare("SELECT status FROM licenses").get().status, "revoked");
});

test("T-WH-11 dispute created then closed(won) returns to active", async () => {
  const env = await makeEnv();
  await fetchWorker(env, signedWebhook(checkoutEvent({ customer: "cus_disp" })));
  await fetchWorker(
    env,
    signedWebhook({
      id: "evt_d1",
      type: "charge.dispute.created",
      data: { object: { customer: "cus_disp" } },
    }),
  );
  assert.equal(env.__sqlite.prepare("SELECT status FROM licenses").get().status, "disputed");
  await fetchWorker(
    env,
    signedWebhook({
      id: "evt_d2",
      type: "charge.dispute.closed",
      data: { object: { customer: "cus_disp", status: "won" } },
    }),
  );
  assert.equal(env.__sqlite.prepare("SELECT status FROM licenses").get().status, "active");
});

test("T-DISP dispute closed(lost) revokes", async () => {
  const env = await makeEnv();
  await fetchWorker(env, signedWebhook(checkoutEvent({ customer: "cus_lost", sessionId: "cs_lost" })));
  await fetchWorker(
    env,
    signedWebhook({
      id: "evt_lost1",
      type: "charge.dispute.created",
      data: { object: { customer: "cus_lost" } },
    }),
  );
  await fetchWorker(
    env,
    signedWebhook({
      id: "evt_lost2",
      type: "charge.dispute.closed",
      data: { object: { customer: "cus_lost", status: "lost" } },
    }),
  );
  assert.equal(env.__sqlite.prepare("SELECT status FROM licenses").get().status, "revoked");
});

test("T-WH-12 D1 unavailable after a confirmed charge returns 500", async () => {
  const env = await makeEnv();
  env.DB = failingInsertLicenseD1(env.DB);
  const res = await fetchWorker(env, signedWebhook(checkoutEvent({ sessionId: "cs_down" })));
  assert.equal(res.status, 500);
});

test("T-ENC-04 plaintext key is absent from captured logs", async () => {
  const env = await makeEnv();
  const restore = env.captureLogs();
  await fetchWorker(env, signedWebhook(checkoutEvent()));
  restore();
  const plaintext = env.__emails[0].text.match(/PRUNE-[A-Z0-9-]+/)[0];
  const blob = env.__logs.join("\n");
  assert.equal(blob.includes(plaintext), false);
});

test("T-EMAIL-01 Resend 500 still creates the license and Stripe gets 200", async () => {
  const env = await makeEnv();
  env.__resendStatus = 500;
  const res = await fetchWorker(env, signedWebhook(checkoutEvent({ sessionId: "cs_mailfail" })));
  assert.equal(res.status, 200);
  const license = env.__sqlite.prepare("SELECT * FROM licenses").get();
  assert.equal(license.email_state, "failed");
  assert.ok(license.email_attempts >= 1);
});

test("GET /key-lookup is gone", async () => {
  const env = await makeEnv();
  const res = await fetchWorker(env, new Request("https://api.diskprune.com/key-lookup?session_id=cs_test_1"));
  assert.equal(res.status, 404);
});

test("T-WH-LINEITEMS live Payment Link payload (no line_items, no STRIPE_PRICE_ID) still fulfils seed SKU", async () => {
  const env = await makeEnv();
  delete env.STRIPE_PRICE_ID;
  const res = await fetchWorker(
    env,
    signedWebhook(checkoutEvent({ sessionId: "cs_plink", includeLineItems: false })),
  );
  assert.equal(res.status, 200);
  assert.equal(env.__sqlite.prepare("SELECT COUNT(*) AS n FROM licenses").get().n, 1);
});

test("T-WH-SOLE-SKU survives products.stripe_price_id UPDATE when payload has no line_items", async () => {
  const env = await makeEnv();
  delete env.STRIPE_PRICE_ID;
  env.__sqlite.prepare("UPDATE products SET stripe_price_id = 'price_live_real'").run();
  const res = await fetchWorker(
    env,
    signedWebhook(checkoutEvent({ sessionId: "cs_updated", includeLineItems: false })),
  );
  assert.equal(res.status, 200);
  assert.equal(env.__sqlite.prepare("SELECT COUNT(*) AS n FROM licenses").get().n, 1);
});

test("T-EMAIL-05 retry does not email a revoked license", async () => {
  const { retryFailedEmails } = await import("../src/email.js");
  const env = await makeEnv();
  env.__resendStatus = 500;
  await fetchWorker(env, signedWebhook(checkoutEvent({ sessionId: "cs_revmail" })));
  env.__sqlite.prepare("UPDATE licenses SET status = 'revoked', email_state = 'failed', email_attempts = 1, email_last_attempt_at = 0").run();
  env.__emails.length = 0;
  env.__resendStatus = 200;
  await retryFailedEmails(env);
  assert.equal(env.__emails.length, 0);
});

test("T-WH-METADATA uses session.metadata.stripe_price_id when line_items absent", async () => {
  const env = await makeEnv();
  delete env.STRIPE_PRICE_ID;
  env.__sqlite.prepare("UPDATE products SET stripe_price_id = 'price_from_meta'").run();
  env.__sqlite.prepare(
    "INSERT INTO products (stripe_price_id, license_type, entitlements_json, max_devices, created_at) VALUES ('price_other', 'personal', '[\"cleanup\"]', 3, 0)",
  ).run();
  const res = await fetchWorker(
    env,
    signedWebhook(
      checkoutEvent({
        sessionId: "cs_meta",
        includeLineItems: false,
        metadata: { stripe_price_id: "price_from_meta" },
      }),
    ),
  );
  assert.equal(res.status, 200);
  assert.equal(env.__sqlite.prepare("SELECT COUNT(*) AS n FROM licenses").get().n, 1);
});

test("T-WH-UNKNOWN-PRODUCT returns 500 and writes no license when SKU cannot be resolved", async () => {
  const env = await makeEnv();
  delete env.STRIPE_PRICE_ID;
  env.__sqlite.prepare("DELETE FROM products").run();
  env.__sqlite.prepare(
    "INSERT INTO products (stripe_price_id, license_type, entitlements_json, max_devices, created_at) VALUES ('price_a', 'personal', '[\"cleanup\"]', 3, 0)",
  ).run();
  env.__sqlite.prepare(
    "INSERT INTO products (stripe_price_id, license_type, entitlements_json, max_devices, created_at) VALUES ('price_b', 'personal', '[\"cleanup\"]', 3, 0)",
  ).run();
  const res = await fetchWorker(
    env,
    signedWebhook(
      checkoutEvent({
        sessionId: "cs_unk",
        includeLineItems: false,
        metadata: { stripe_price_id: "price_missing" },
      }),
    ),
  );
  assert.equal(res.status, 500);
  assert.equal(env.__sqlite.prepare("SELECT COUNT(*) AS n FROM licenses").get().n, 0);
  const body = await res.json();
  assert.equal(body.error, "fulfillment_failed");
});

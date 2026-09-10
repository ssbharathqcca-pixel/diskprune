import { test } from "node:test";
import assert from "node:assert/strict";
import { decryptLicenseKey } from "../src/crypto.js";
import { issueToken, TOKEN_TTL_ACTIVE, TOKEN_TTL_DISPUTED } from "../src/tokens.js";
import {
  checkoutEvent,
  fetchWorker,
  makeEnv,
  readJson,
  signedWebhook,
} from "./helpers.js";

async function paidLicense(env, { email = "ada@example.com", sessionId = "cs_act", customer = "cus_act" } = {}) {
  await fetchWorker(env, signedWebhook(checkoutEvent({ email, sessionId, customer })));
  const row = env.__sqlite.prepare("SELECT * FROM licenses WHERE stripe_session_id = ?").get(sessionId);
  const { plaintext } = await decryptLicenseKey(row.encrypted_key, row.id, env);
  return { row, plaintext };
}

function post(path, body, ip = "1.1.1.1") {
  return new Request(`https://api.diskprune.com${path}`, {
    method: "POST",
    headers: { "content-type": "application/json", "CF-Connecting-IP": ip },
    body: JSON.stringify(body),
  });
}

function tokenPayload(token) {
  return JSON.parse(Buffer.from(token.split(".")[1], "base64url").toString());
}

test("activate issues a token; refresh and release follow the seat rules", async () => {
  const env = await makeEnv();
  const { plaintext } = await paidLicense(env);
  const act = await fetchWorker(
    env,
    post("/v1/licenses/activate", { license_key: plaintext, device_id: "dev-a", device_name: "Ada's Mac" }),
  );
  assert.equal(act.status, 200);
  const issued = await readJson(act);
  assert.ok(issued.token.split(".").length === 3);
  assert.equal(issued.max_devices, 3);
  assert.deepEqual(issued.entitlements, ["cleanup"]);

  const refresh = await fetchWorker(env, post("/v1/licenses/refresh", { token: issued.token }));
  assert.equal(refresh.status, 200);

  const rel = await fetchWorker(env, post("/v1/licenses/release", { license_key: plaintext, device_id: "dev-a" }));
  assert.equal(rel.status, 200);
  const released = await readJson(rel);
  assert.equal(released.released, true);
  assert.equal(released.seats_available, 3);

  const blocked = await fetchWorker(env, post("/v1/licenses/refresh", { token: issued.token }));
  assert.equal(blocked.status, 403);
  assert.equal((await readJson(blocked)).error, "DEVICE_RELEASED");
});

test("T-REF-01 active license refresh is 90 days", async () => {
  const env = await makeEnv();
  const { plaintext } = await paidLicense(env, { sessionId: "cs_ref1" });
  const act = await readJson(
    await fetchWorker(env, post("/v1/licenses/activate", { license_key: plaintext, device_id: "dev-90" })),
  );
  const res = await fetchWorker(env, post("/v1/licenses/refresh", { token: act.token }));
  assert.equal(res.status, 200);
  const body = await readJson(res);
  const payload = tokenPayload(body.token);
  assert.equal(payload.exp - payload.iat, TOKEN_TTL_ACTIVE);
});

test("T-REF-02 released device cannot refresh", async () => {
  const env = await makeEnv();
  const { plaintext } = await paidLicense(env, { sessionId: "cs_rel" });
  const act = await readJson(
    await fetchWorker(env, post("/v1/licenses/activate", { license_key: plaintext, device_id: "dev-rel" })),
  );
  await fetchWorker(env, post("/v1/licenses/release", { license_key: plaintext, device_id: "dev-rel" }));
  const res = await fetchWorker(env, post("/v1/licenses/refresh", { token: act.token }));
  assert.equal(res.status, 403);
  assert.equal((await readJson(res)).error, "DEVICE_RELEASED");
});

test("T-REF-03 revoked license cannot refresh", async () => {
  const env = await makeEnv();
  const { plaintext } = await paidLicense(env, { sessionId: "cs_rev", customer: "cus_rev" });
  const act = await readJson(
    await fetchWorker(env, post("/v1/licenses/activate", { license_key: plaintext, device_id: "dev-rev" })),
  );
  await fetchWorker(
    env,
    signedWebhook({ id: "evt_rev", type: "charge.refunded", data: { object: { customer: "cus_rev" } } }),
  );
  const res = await fetchWorker(env, post("/v1/licenses/refresh", { token: act.token }));
  assert.equal(res.status, 403);
  assert.equal((await readJson(res)).error, "LICENSE_REVOKED");
});

test("T-REF-04 disputed refresh returns a 14-day token", async () => {
  const env = await makeEnv();
  const { plaintext } = await paidLicense(env, { sessionId: "cs_disp", customer: "cus_disp2" });
  const act = await readJson(
    await fetchWorker(env, post("/v1/licenses/activate", { license_key: plaintext, device_id: "dev-d" })),
  );
  await fetchWorker(
    env,
    signedWebhook({
      id: "evt_disp",
      type: "charge.dispute.created",
      data: { object: { customer: "cus_disp2" } },
    }),
  );
  const res = await fetchWorker(env, post("/v1/licenses/refresh", { token: act.token }));
  assert.equal(res.status, 200);
  const body = await readJson(res);
  const payload = tokenPayload(body.token);
  assert.equal(payload.exp - payload.iat, TOKEN_TTL_DISPUTED);
});

test("T-REF-05 expired but valid token can refresh", async () => {
  const env = await makeEnv();
  const { plaintext, row } = await paidLicense(env, { sessionId: "cs_exp" });
  await fetchWorker(env, post("/v1/licenses/activate", { license_key: plaintext, device_id: "dev-exp" }));
  const issued = await issueToken({
    keyHash: row.key_hash,
    deviceId: "dev-exp",
    entitlements: ["cleanup"],
    licenseType: "personal",
    maxDevices: 3,
    ttlSeconds: 10,
    now: Math.floor(Date.now() / 1000) - 100,
    env,
  });
  assert.ok(tokenPayload(issued.token).exp < Math.floor(Date.now() / 1000));
  const res = await fetchWorker(env, post("/v1/licenses/refresh", { token: issued.token }));
  assert.equal(res.status, 200);
});

test("T-REF-06 unknown device cannot refresh", async () => {
  const env = await makeEnv();
  const { plaintext } = await paidLicense(env, { sessionId: "cs_unk" });
  const act = await readJson(
    await fetchWorker(env, post("/v1/licenses/activate", { license_key: plaintext, device_id: "dev-known" })),
  );
  env.__sqlite.prepare("DELETE FROM devices").run();
  const res = await fetchWorker(env, post("/v1/licenses/refresh", { token: act.token }));
  assert.equal(res.status, 403);
  assert.equal((await readJson(res)).error, "DEVICE_UNKNOWN");
});

test("T-DISP disputed license blocks new activation", async () => {
  const env = await makeEnv();
  const { plaintext } = await paidLicense(env, { sessionId: "cs_dact", customer: "cus_dact" });
  await fetchWorker(
    env,
    signedWebhook({
      id: "evt_dact",
      type: "charge.dispute.created",
      data: { object: { customer: "cus_dact" } },
    }),
  );
  const res = await fetchWorker(env, post("/v1/licenses/activate", { license_key: plaintext, device_id: "dev-new" }));
  assert.equal(res.status, 409);
  assert.equal((await readJson(res)).error, "LICENSE_DISPUTED");
});

test("T-DISP revoked license cannot activate", async () => {
  const env = await makeEnv();
  const { plaintext } = await paidLicense(env, { sessionId: "cs_ract", customer: "cus_ract" });
  await fetchWorker(
    env,
    signedWebhook({ id: "evt_ract", type: "charge.refunded", data: { object: { customer: "cus_ract" } } }),
  );
  const res = await fetchWorker(env, post("/v1/licenses/activate", { license_key: plaintext, device_id: "dev-r" }));
  assert.equal(res.status, 403);
  assert.equal((await readJson(res)).error, "LICENSE_REVOKED");
});

test("T-SEAT-01 fourth device hits SEAT_LIMIT; T-SEAT-02 release then activate succeeds", async () => {
  const env = await makeEnv();
  const { plaintext } = await paidLicense(env, { sessionId: "cs_seats" });
  for (const id of ["d1", "d2", "d3"]) {
    const res = await fetchWorker(env, post("/v1/licenses/activate", { license_key: plaintext, device_id: id }));
    assert.equal(res.status, 200);
  }
  const fourth = await fetchWorker(env, post("/v1/licenses/activate", { license_key: plaintext, device_id: "d4" }));
  assert.equal(fourth.status, 409);
  const body = await readJson(fourth);
  assert.equal(body.error, "SEAT_LIMIT");
  assert.equal(body.devices.length, 3);
  await fetchWorker(env, post("/v1/licenses/release", { license_key: plaintext, device_id: "d1" }));
  const again = await fetchWorker(env, post("/v1/licenses/activate", { license_key: plaintext, device_id: "d4" }));
  assert.equal(again.status, 200);
});

test("T-EMAIL-02 resend after failure delivers the key", async () => {
  const env = await makeEnv();
  env.__resendStatus = 500;
  const { plaintext } = await paidLicense(env, { sessionId: "cs_rs", email: "resend@example.com" });
  env.__resendStatus = 200;
  env.__emails.length = 0;
  const res = await fetchWorker(env, post("/v1/licenses/resend", { email: "resend@example.com" }));
  assert.equal(res.status, 200);
  assert.equal((await readJson(res)).ok, true);
  assert.equal(env.__emails.length, 1);
  assert.ok(env.__emails[0].text.includes(plaintext));
});

test("T-EMAIL-03 unknown email still returns 200 {ok:true}", async () => {
  const env = await makeEnv();
  const res = await fetchWorker(env, post("/v1/licenses/resend", { email: "nobody@example.com" }));
  assert.equal(res.status, 200);
  assert.deepEqual(await readJson(res), { ok: true });
  assert.equal(env.__emails.length, 0);
});

test("T-EMAIL-04 fourth resend in an hour is 429", async () => {
  const env = await makeEnv();
  for (let i = 0; i < 3; i++) {
    const res = await fetchWorker(env, post("/v1/licenses/resend", { email: `n${i}@x.com` }, "9.9.9.9"));
    assert.equal(res.status, 200);
  }
  const fourth = await fetchWorker(env, post("/v1/licenses/resend", { email: "n3@x.com" }, "9.9.9.9"));
  assert.equal(fourth.status, 429);
});

test("T-CHK-01 fake checkout status reveals no key", async () => {
  const env = await makeEnv();
  const res = await fetchWorker(env, new Request("https://api.diskprune.com/v1/checkout/fake/status"));
  assert.equal(res.status, 404);
  const body = await readJson(res);
  assert.equal("license_key" in body, false);
  assert.equal("token" in body, false);
  assert.equal(JSON.stringify(body).includes("PRUNE-"), false);
});

test("T-CHK-02 paid session returns masked email and no key", async () => {
  const env = await makeEnv();
  await paidLicense(env, { sessionId: "cs_status", email: "ada@example.com" });
  const res = await fetchWorker(env, new Request("https://api.diskprune.com/v1/checkout/cs_status/status"));
  assert.equal(res.status, 200);
  const body = await readJson(res);
  assert.equal(body.payment_state, "paid");
  assert.equal(body.delivery_state, "sent");
  assert.equal(body.email_masked, "a•••@example.com");
  assert.deepEqual(Object.keys(body).sort(), ["delivery_state", "email_masked", "payment_state"]);
  assert.equal("license_key" in body, false);
  assert.equal("token" in body, false);
  assert.equal("encrypted_key" in body, false);
});

test("T-CHK-03 pending unpaid checkout is unpaid/pending with no key", async () => {
  const env = await makeEnv();
  const resPay = await fetchWorker(
    env,
    signedWebhook(checkoutEvent({ payment_status: "unpaid", sessionId: "cs_pending" })),
  );
  assert.equal(resPay.status, 200);
  const res = await fetchWorker(env, new Request("https://api.diskprune.com/v1/checkout/cs_pending/status"));
  assert.equal(res.status, 200);
  const body = await readJson(res);
  assert.equal(body.payment_state, "unpaid");
  assert.equal(body.delivery_state, "pending");
  assert.equal(body.email_masked, null);
  assert.equal("license_key" in body, false);
  assert.equal(JSON.stringify(body).includes("PRUNE-"), false);
});

test("T-CHK-04 failed fulfillment is failed with no key", async () => {
  const env = await makeEnv();
  await fetchWorker(
    env,
    signedWebhook(checkoutEvent({ type: "checkout.session.async_payment_failed", sessionId: "cs_failstat" })),
  );
  const res = await fetchWorker(env, new Request("https://api.diskprune.com/v1/checkout/cs_failstat/status"));
  assert.equal(res.status, 200);
  const body = await readJson(res);
  assert.equal(body.payment_state, "failed");
  assert.equal(body.delivery_state, "failed");
  assert.equal("license_key" in body, false);
  assert.equal(JSON.stringify(body).includes("PRUNE-"), false);
});

test("T-CHK-05 paid session status is stable on reload", async () => {
  const env = await makeEnv();
  await paidLicense(env, { sessionId: "cs_reload", email: "ada@example.com" });
  const a = await readJson(await fetchWorker(env, new Request("https://api.diskprune.com/v1/checkout/cs_reload/status")));
  const b = await readJson(await fetchWorker(env, new Request("https://api.diskprune.com/v1/checkout/cs_reload/status")));
  assert.deepEqual(a, b);
  assert.equal(a.payment_state, "paid");
  assert.equal("license_key" in a, false);
});

test("T-CHK-06 paid but email failed still reports paid and no key", async () => {
  const env = await makeEnv();
  env.__resendStatus = 500;
  await fetchWorker(env, signedWebhook(checkoutEvent({ sessionId: "cs_mailfail2", email: "ada@example.com" })));
  const res = await fetchWorker(env, new Request("https://api.diskprune.com/v1/checkout/cs_mailfail2/status"));
  const body = await readJson(res);
  assert.equal(res.status, 200);
  assert.equal(body.payment_state, "paid");
  assert.equal(body.delivery_state, "failed");
  assert.equal(body.email_masked, "a•••@example.com");
  assert.equal("license_key" in body, false);
});

test("invalid activate format is 400 before any lookup", async () => {
  const env = await makeEnv();
  const res = await fetchWorker(env, post("/v1/licenses/activate", { license_key: "nope", device_id: "d" }));
  assert.equal(res.status, 400);
  assert.equal((await readJson(res)).error, "INVALID_FORMAT");
});

test("CORS is diskprune.com only, never *", async () => {
  const env = await makeEnv();
  const res = await fetchWorker(
    env,
    new Request("https://api.diskprune.com/v1/checkout/x/status", {
      headers: { Origin: "https://evil.example" },
    }),
  );
  assert.equal(res.headers.get("Access-Control-Allow-Origin"), "https://diskprune.com");
  assert.notEqual(res.headers.get("Access-Control-Allow-Origin"), "*");
});

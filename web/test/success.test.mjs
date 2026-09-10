import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  parseSessionId,
  statusUrl,
  copyFor,
  shouldPoll,
  interpretResponse,
  payloadLeaksSecret,
  resolveCheckoutStatus,
  mountSuccessPage,
  loadingCopy,
  POLL_LIMIT,
} from "../src/lib/checkout-status.mjs";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const SUCCESS = readFileSync(join(ROOT, "src/pages/success.astro"), "utf8");
const LIB = readFileSync(join(ROOT, "src/lib/checkout-status.mjs"), "utf8");
const SITE_SUCCESS = readFileSync(
  join(ROOT, "../site/src/routes/success.tsx"),
  "utf8",
);
const SITE_STATUS = readFileSync(
  join(ROOT, "../site/src/lib/checkout-status.ts"),
  "utf8",
);
const SITE_LICENSE = readFileSync(join(ROOT, "../site/src/lib/license.ts"), "utf8");

function fakeDoc() {
  const nodes = new Map();
  for (const id of ["status-heading", "status-body", "status-loading"]) {
    nodes.set(id, { textContent: "", hidden: false, id });
  }
  return {
    getElementById: (id) => nodes.get(id) || null,
    nodes,
  };
}

function fetchSequence(responses) {
  const calls = [];
  const fetchImpl = async (url) => {
    calls.push(url);
    const next = responses.shift();
    if (!next) throw new Error("unexpected extra fetch");
    return {
      status: next.status,
      async json() {
        return next.body;
      },
    };
  };
  return { fetchImpl, calls };
}

test("T-WEB-05 missing session_id does not claim payment and reveals no key", () => {
  const copy = copyFor({ payment_state: "unknown", delivery_state: "unknown" });
  assert.equal(copy.confirmed, false);
  assert.equal(copy.body.includes("Payment received"), false);
  assert.equal(copy.body.includes("Payment confirmed"), false);
  assert.match(copy.body, /support@diskprune.com/);
  assert.equal(parseSessionId(""), null);
  assert.equal(parseSessionId("?utm=1"), null);
});

test("T-WEB-05 invalid session_id is rejected before fetch", () => {
  assert.equal(parseSessionId("?session_id=fake"), null);
  assert.equal(parseSessionId("?session_id=../etc/passwd"), null);
  assert.equal(parseSessionId("?session_id=cs_short"), null);
  assert.ok(parseSessionId("?session_id=cs_test_a1b2c3d4e5"));
});

test("pending unpaid checkout uses processing copy", () => {
  const copy = copyFor({ payment_state: "unpaid", delivery_state: "pending" });
  assert.equal(copy.kind, "unpaid");
  assert.equal(copy.confirmed, false);
  assert.match(copy.body, /payment is processing/i);
  assert.equal(copy.body.includes("Payment confirmed"), false);
  assert.equal(copy.body.includes("PRUNE-"), false);
});

test("successful fulfillment: paid + sent, masked email, no key", () => {
  const copy = copyFor({
    payment_state: "paid",
    delivery_state: "sent",
    email_masked: "a•••@example.com",
  });
  assert.equal(copy.kind, "paid-sent");
  assert.equal(copy.confirmed, true);
  assert.match(copy.body, /Payment confirmed/);
  assert.match(copy.body, /a•••@example.com/);
  assert.equal(copy.body.includes("PRUNE-"), false);
  assert.equal(copy.body.toLowerCase().includes("license key is in your email"), true);
});

test("paid but email pending polls; exhausted adds support line", () => {
  const pending = copyFor({ payment_state: "paid", delivery_state: "pending" });
  assert.equal(pending.kind, "paid-pending");
  assert.equal(shouldPoll({ payment_state: "paid", delivery_state: "pending" }), true);
  const done = copyFor({
    payment_state: "paid",
    delivery_state: "pending",
    pollExhausted: true,
  });
  assert.match(done.body, /support@diskprune.com/);
});

test("failed fulfillment does not claim success", () => {
  const copy = copyFor({ payment_state: "failed", delivery_state: "failed" });
  assert.equal(copy.confirmed, false);
  assert.equal(copy.body.includes("Payment confirmed"), false);
  assert.match(copy.body, /couldn't confirm/i);
});

test("paid but email failed still confirms payment and does not display a key", () => {
  const copy = copyFor({ payment_state: "paid", delivery_state: "failed" });
  assert.equal(copy.kind, "paid-email-failed");
  assert.equal(copy.confirmed, true);
  assert.match(copy.body, /couldn't send the license email/i);
  assert.equal(copy.body.includes("PRUNE-"), false);
});

test("interpretResponse drops leaking payloads", () => {
  assert.equal(payloadLeaksSecret({ license_key: "PRUNE-AAAAA-BBBBB-CCCCC-DDDDD" }), true);
  const view = interpretResponse(200, {
    payment_state: "paid",
    delivery_state: "sent",
    license_key: "PRUNE-AAAAA-BBBBB-CCCCC-DDDDD",
  });
  assert.equal(view.payment_state, "unknown");
  assert.equal(copyFor(view).confirmed, false);
});

test("404 / missing checkout session is unknown, no key", () => {
  const view = interpretResponse(404, { error: "NOT_FOUND" });
  assert.equal(view.payment_state, "unknown");
  const copy = copyFor(view);
  assert.equal(copy.kind, "unknown");
  assert.equal(JSON.stringify(copy).includes("PRUNE-"), false);
});

test("reload/refetch uses the same status URL and never writes a key", async () => {
  const { fetchImpl, calls } = fetchSequence([
    { status: 200, body: { payment_state: "paid", delivery_state: "sent", email_masked: "a•••@x.com" } },
    { status: 200, body: { payment_state: "paid", delivery_state: "sent", email_masked: "a•••@x.com" } },
  ]);
  const sid = "cs_test_reload1";
  const first = await resolveCheckoutStatus(sid, { fetchImpl, sleep: async () => {} });
  const second = await resolveCheckoutStatus(sid, { fetchImpl, sleep: async () => {} });
  assert.equal(first.payment_state, "paid");
  assert.equal(second.payment_state, "paid");
  assert.equal(calls[0], statusUrl(sid));
  assert.equal(calls[1], statusUrl(sid));
  assert.equal(calls[0].includes("license"), false);
  assert.equal(copyFor(first).body.includes("PRUNE-"), false);
});

test("paid+pending polls three times then stops", async () => {
  const pending = { status: 200, body: { payment_state: "paid", delivery_state: "pending", email_masked: "a•••@x.com" } };
  const { fetchImpl, calls } = fetchSequence([pending, pending, pending, pending]);
  let sleeps = 0;
  const view = await resolveCheckoutStatus("cs_test_pendingxx", {
    fetchImpl,
    sleep: async () => {
      sleeps += 1;
    },
  });
  assert.equal(calls.length, 1 + POLL_LIMIT);
  assert.equal(sleeps, POLL_LIMIT);
  assert.equal(view.pollExhausted, true);
  assert.match(copyFor(view).body, /support@diskprune.com/);
});

test("mountSuccessPage missing session never fetches", async () => {
  const doc = fakeDoc();
  let fetches = 0;
  await mountSuccessPage({
    document: doc,
    search: "",
    fetchImpl: async () => {
      fetches += 1;
      return { status: 200, json: async () => ({}) };
    },
  });
  assert.equal(fetches, 0);
  assert.equal(doc.nodes.get("status-heading").textContent, "We couldn't confirm this yet");
  assert.equal(doc.nodes.get("status-body").textContent.includes("Payment confirmed"), false);
});

test("loading copy never says generating a key", () => {
  assert.equal(loadingCopy().toLowerCase().includes("generat"), false);
  assert.equal(loadingCopy().toLowerCase().includes("license key"), false);
});

test("success.astro and site success.tsx do not fabricate keys (B-13 source)", () => {
  for (const [name, src] of [
    ["web/success.astro", SUCCESS],
    ["web/checkout-status.mjs", LIB],
    ["site/success.tsx", SITE_SUCCESS],
    ["site/license.ts", SITE_LICENSE],
    ["site/checkout-status.ts", SITE_STATUS],
  ]) {
    assert.equal(src.includes("issueLicense"), false, `${name} issueLicense`);
    assert.equal(src.includes("key-lookup"), false, `${name} key-lookup`);
    assert.equal(src.includes("Math.random"), false, `${name} Math.random`);
    assert.equal(src.includes("Generating your license"), false, `${name} generating`);
    assert.equal(src.includes("Payment received"), false, `${name} Payment received`);
    assert.equal(src.includes("id=\"license-key\""), false, `${name} license-key node`);
  }
  assert.match(LIB, /v1\/checkout\//);
  assert.match(SITE_STATUS, /v1\/checkout\//);
  assert.match(SUCCESS, /checkout-status/);
  assert.match(SITE_SUCCESS, /checkout-status/);
});

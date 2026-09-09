import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { DatabaseSync } from "node:sqlite";
import Stripe from "stripe";
import worker from "../src/index.js";

const ROOT = dirname(fileURLToPath(import.meta.url));
export const SCHEMA = readFileSync(join(ROOT, "../migrations/0001_init.sql"), "utf8");
export const WEBHOOK_SECRET = "whsec_test_diskprune";

export function wrapD1(sqlite) {
  return {
    prepare(sql) {
      const make = (binds) => ({
        bind(...args) {
          return make(args);
        },
        async first() {
          return sqlite.prepare(sql).get(...binds) ?? null;
        },
        async all() {
          return { results: sqlite.prepare(sql).all(...binds) };
        },
        async run() {
          const info = sqlite.prepare(sql).run(...binds);
          return { success: true, meta: { changes: info.changes, last_row_id: info.lastInsertRowid } };
        },
      });
      return make([]);
    },
  };
}

export function failingInsertLicenseD1(inner) {
  return {
    prepare(sql) {
      const stmt = inner.prepare(sql);
      if (!/INSERT INTO licenses/i.test(sql)) return stmt;
      return {
        bind(...args) {
          return {
            run: async () => {
              throw new Error("D1 unavailable");
            },
            first: (...a) => stmt.bind(...args).first(...a),
            all: (...a) => stmt.bind(...args).all(...a),
          };
        },
      };
    },
  };
}

export function memoryKv() {
  const map = new Map();
  return {
    async get(key) {
      return map.has(key) ? map.get(key) : null;
    },
    async put(key, value) {
      map.set(key, String(value));
    },
  };
}

function b64(bytes) {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin);
}

export async function generateSigningPair() {
  const { publicKey, privateKey } = await crypto.subtle.generateKey({ name: "Ed25519" }, true, ["sign", "verify"]);
  return {
    pkcs8: b64(new Uint8Array(await crypto.subtle.exportKey("pkcs8", privateKey))),
    pub: b64(new Uint8Array(await crypto.subtle.exportKey("raw", publicKey))),
  };
}

export function generateEncKey() {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return b64(bytes);
}

export async function makeEnv(overrides = {}) {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(SCHEMA);
  const k1 = await generateSigningPair();
  const emails = [];
  const logs = [];
  const origLog = console.log;
  const env = {
    DB: wrapD1(sqlite),
    RATE_LIMITS: memoryKv(),
    STRIPE_WEBHOOK_SECRET: WEBHOOK_SECRET,
    STRIPE_PRICE_ID: "price_diskprune_personal",
    LICENSE_ENCRYPTION_KEY: generateEncKey(),
    LICENSE_SIGNING_KEY_K1: k1.pkcs8,
    LICENSE_SIGNING_PUB_K1: k1.pub,
    RESEND_API_KEY: "re_test",
    LICENSE_FROM_EMAIL: "DiskPrune <licenses@diskprune.com>",
    CORS_ORIGIN: "https://diskprune.com",
    __sqlite: sqlite,
    __emails: emails,
    __logs: logs,
    fetchImpl: async (_url, init) => {
      emails.push(JSON.parse(init.body));
      const status = env.__resendStatus ?? 200;
      return new Response("{}", { status });
    },
    ...overrides,
  };
  env.captureLogs = () => {
    console.log = (...args) => {
      logs.push(args.map(String).join(" "));
      origLog(...args);
    };
    return () => {
      console.log = origLog;
    };
  };
  return env;
}

export function signedWebhook(event, secret = WEBHOOK_SECRET) {
  const payload = JSON.stringify(event);
  const stripe = new Stripe("sk_test_dummy");
  const header = stripe.webhooks.generateTestHeaderString({ payload, secret });
  return new Request("https://api.diskprune.com/webhook", {
    method: "POST",
    headers: { "stripe-signature": header, "content-type": "application/json" },
    body: payload,
  });
}

export async function fetchWorker(env, request) {
  return worker.fetch(request, env);
}

export function checkoutEvent({
  id = "evt_1",
  type = "checkout.session.completed",
  sessionId = "cs_test_1",
  payment_status = "paid",
  email = "ada@example.com",
  customer = "cus_1",
  priceId = "price_diskprune_personal",
} = {}) {
  return {
    id,
    type,
    data: {
      object: {
        id: sessionId,
        payment_status,
        customer,
        customer_details: { email },
        line_items: { data: [{ price: { id: priceId } }] },
      },
    },
  };
}

export async function readJson(res) {
  return res.json();
}

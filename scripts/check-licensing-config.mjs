#!/usr/bin/env node
/**
 * Phase 6 / Gate 3 prep — public-key match and secret-leak check.
 *
 * Fail closed on:
 *   - PublicKeys.k1Base64 missing, not 32 bytes, or ≠ wrangler.toml [vars] LICENSE_SIGNING_PUB_K1
 *   - PKCS#8 private-key material in app/Sources or worker/{src,wrangler.toml,migrations}
 *   - LICENSE_SIGNING_KEY_K1 assigned in wrangler [vars]
 *   - RATE_LIMITS bound to the retired LICENSES KV id
 *
 * D1/KV placeholders are reported but do not fail (owner provisioner writes real ids).
 * Pass --require-bindings to fail on placeholders (not used in CI until provisioned).
 */
import { readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const BANNED_KV = "c273cf8e9c864d5bbd46840db2a7f153";
const PLACEHOLDER_D1 = "REPLACE_WITH_D1_DATABASE_ID";
const PLACEHOLDER_KV = "REPLACE_WITH_KV_NAMESPACE_ID";
const PKCS8_NEEDLE = "MC4CAQAwBQYDK2Vw";

const requireBindings = process.argv.includes("--require-bindings");

function read(rel) {
  return readFileSync(join(ROOT, rel), "utf8");
}

function extractSwiftK1(src) {
  const m = src.match(/static let k1Base64 = "([A-Za-z0-9+/=]+)"/);
  if (!m) throw new Error("PublicKeys.k1Base64 assignment not found");
  return m[1];
}

function extractTomlPub(src) {
  const idx = src.indexOf("[vars]");
  if (idx < 0) throw new Error("wrangler.toml missing [vars]");
  const vars = src.slice(idx);
  const m = vars.match(/LICENSE_SIGNING_PUB_K1\s*=\s*"([^"]+)"/);
  if (!m) throw new Error("wrangler.toml [vars] LICENSE_SIGNING_PUB_K1 not found");
  return m[1];
}

function extractD1(src) {
  const m = src.match(/database_id\s*=\s*"([^"]+)"/);
  return m ? m[1] : null;
}

function extractKV(src) {
  const m = src.match(/binding\s*=\s*"RATE_LIMITS"\s*\nid\s*=\s*"([^"]+)"/);
  return m ? m[1] : null;
}

function varsAssignsSigningPrivate(src) {
  const idx = src.indexOf("[vars]");
  if (idx < 0) return false;
  const vars = src.slice(idx).split("\n");
  return vars.some((line) => {
    const trimmed = line.trim();
    if (trimmed.startsWith("#")) return false;
    return /^LICENSE_SIGNING_KEY_K[12]\s*=/.test(trimmed);
  });
}

function isValidPub(b64) {
  const buf = Buffer.from(b64, "base64");
  return buf.length === 32 && buf.toString("base64") === b64;
}

function walk(dir, acc = []) {
  for (const name of readdirSync(dir)) {
    if (name === "node_modules" || name === ".wrangler" || name === ".git") continue;
    const p = join(dir, name);
    const st = statSync(p);
    if (st.isDirectory()) walk(p, acc);
    else acc.push(p);
  }
  return acc;
}

const failures = [];
const notes = [];

const swiftSrc = read("app/Sources/DiskPrune/Licensing/PublicKeys.swift");
const tomlSrc = read("worker/wrangler.toml");

const k1 = extractSwiftK1(swiftSrc);
const pub = extractTomlPub(tomlSrc);
const d1 = extractD1(tomlSrc);
const kv = extractKV(tomlSrc);

if (!isValidPub(k1)) {
  failures.push(`PublicKeys.k1Base64 is not a 32-byte standard-base64 Ed25519 public key`);
}
if (!isValidPub(pub)) {
  failures.push(`wrangler.toml LICENSE_SIGNING_PUB_K1 is not a 32-byte standard-base64 Ed25519 public key`);
}
if (k1 !== pub) {
  failures.push("PublicKeys.k1Base64 does not exactly match wrangler.toml [vars] LICENSE_SIGNING_PUB_K1");
} else {
  notes.push(`public-key: MATCH (${k1.length} chars, 32 bytes)`);
}

if (varsAssignsSigningPrivate(tomlSrc)) {
  failures.push("LICENSE_SIGNING_KEY_K1/K2 must not be assigned in wrangler.toml [vars]");
}

if (!d1) failures.push("wrangler.toml missing database_id");
else if (d1 === PLACEHOLDER_D1) {
  notes.push("d1: PLACEHOLDER — run scripts/provision-worker.sh --apply");
  if (requireBindings) failures.push("D1 database_id is still the placeholder");
} else {
  notes.push(`d1: ${d1}`);
}

if (!kv) failures.push("wrangler.toml missing RATE_LIMITS id");
else if (kv === PLACEHOLDER_KV) {
  notes.push("kv RATE_LIMITS: PLACEHOLDER — run scripts/provision-worker.sh --apply");
  if (requireBindings) failures.push("RATE_LIMITS id is still the placeholder");
} else if (kv === BANNED_KV) {
  failures.push("RATE_LIMITS must not reuse legacy LICENSES KV c273cf8e9c864d5bbd46840db2a7f153");
} else {
  notes.push(`kv RATE_LIMITS: ${kv}`);
}

const scanRoots = [
  join(ROOT, "app/Sources/DiskPrune"),
  join(ROOT, "worker/src"),
  join(ROOT, "worker/migrations"),
  join(ROOT, "worker/wrangler.toml"),
];
for (const root of scanRoots) {
  const files = statSync(root).isDirectory() ? walk(root) : [root];
  for (const file of files) {
    const text = readFileSync(file, "utf8");
    if (text.includes(PKCS8_NEEDLE) || text.includes("BEGIN PRIVATE KEY")) {
      failures.push(`private-key material in ${relative(ROOT, file)}`);
    }
  }
}

for (const n of notes) console.log(n);
if (failures.length) {
  for (const f of failures) console.error(`FAIL: ${f}`);
  process.exit(1);
}
console.log("licensing-config: ok");

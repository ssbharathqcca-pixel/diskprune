import { test } from "node:test";
import assert from "node:assert/strict";
import {
  decryptLicenseKey,
  encryptLicenseKey,
  generateLicenseKey,
  LICENSE_KEY_RE,
} from "../src/crypto.js";
import { generateEncKey } from "./helpers.js";

test("T-ENC-01 encrypt then decrypt recovers plaintext", async () => {
  const env = { LICENSE_ENCRYPTION_KEY: generateEncKey() };
  const id = crypto.randomUUID();
  const key = generateLicenseKey();
  assert.match(key, LICENSE_KEY_RE);
  const stored = await encryptLicenseKey(key, id, env);
  assert.match(stored, /^v1\./);
  const out = await decryptLicenseKey(stored, id, env);
  assert.equal(out.plaintext, key);
  assert.equal(out.reencrypted, null);
});

test("T-ENC-02 decrypt with different AAD fails", async () => {
  const env = { LICENSE_ENCRYPTION_KEY: generateEncKey() };
  const stored = await encryptLicenseKey(generateLicenseKey(), crypto.randomUUID(), env);
  await assert.rejects(() => decryptLicenseKey(stored, crypto.randomUUID(), env));
});

test("T-ENC-03 one thousand encryptions use unique IVs", async () => {
  const env = { LICENSE_ENCRYPTION_KEY: generateEncKey() };
  const id = crypto.randomUUID();
  const ivs = new Set();
  for (let i = 0; i < 1000; i++) {
    const stored = await encryptLicenseKey("PRUNE-00000-00000-00000-00000", id, env);
    const iv = stored.split(".")[1];
    ivs.add(iv);
  }
  assert.equal(ivs.size, 1000);
});

test("T-ENC-05 v1 ciphertext still decrypts when v2 key is present and is re-encrypted", async () => {
  const v1 = generateEncKey();
  const v2 = generateEncKey();
  const id = crypto.randomUUID();
  const plaintext = generateLicenseKey();
  const stored = await encryptLicenseKey(plaintext, id, { LICENSE_ENCRYPTION_KEY: v1 });
  assert.match(stored, /^v1\./);
  const env = { LICENSE_ENCRYPTION_KEY: v1, LICENSE_ENCRYPTION_KEY_V2: v2 };
  const out = await decryptLicenseKey(stored, id, env);
  assert.equal(out.plaintext, plaintext);
  assert.match(out.reencrypted, /^v2\./);
  const again = await decryptLicenseKey(out.reencrypted, id, env);
  assert.equal(again.plaintext, plaintext);
});

test("generated keys never use Math.random alphabet leakage of I/L/O/U", () => {
  for (let i = 0; i < 50; i++) {
    const key = generateLicenseKey();
    assert.match(key, LICENSE_KEY_RE);
    assert.doesNotMatch(key.slice("PRUNE-".length), /[ILOU]/);
  }
});

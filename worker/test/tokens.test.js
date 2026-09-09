import { test } from "node:test";
import assert from "node:assert/strict";
import { issueToken, verifyToken, TOKEN_TTL_ACTIVE, TOKEN_TTL_DISPUTED } from "../src/tokens.js";
import { generateSigningPair } from "./helpers.js";

test("T-TOK-06 k2-signed token verifies when k2 is the active key", async () => {
  const k1 = await generateSigningPair();
  const k2 = await generateSigningPair();
  const env = {
    LICENSE_SIGNING_KEY_K1: k1.pkcs8,
    LICENSE_SIGNING_PUB_K1: k1.pub,
    LICENSE_SIGNING_KEY_K2: k2.pkcs8,
    LICENSE_SIGNING_PUB_K2: k2.pub,
  };
  const issued = await issueToken({
    keyHash: "abc",
    deviceId: "dev-1",
    entitlements: ["cleanup"],
    licenseType: "personal",
    maxDevices: 3,
    ttlSeconds: TOKEN_TTL_ACTIVE,
    env,
  });
  const header = JSON.parse(Buffer.from(issued.token.split(".")[0], "base64url").toString());
  assert.equal(header.kid, "k2");
  const verified = await verifyToken(issued.token, env);
  assert.equal(verified.ok, true);
  assert.equal(verified.payload.sub, "abc");
  assert.equal(verified.payload.dev, "dev-1");
});

test("T-TOK-07 verification uses transmitted bytes and does not re-serialize JSON", async () => {
  const k1 = await generateSigningPair();
  const env = { LICENSE_SIGNING_KEY_K1: k1.pkcs8, LICENSE_SIGNING_PUB_K1: k1.pub };
  const issued = await issueToken({
    keyHash: "hash",
    deviceId: "device",
    entitlements: ["cleanup"],
    licenseType: "personal",
    maxDevices: 3,
    ttlSeconds: 60,
    env,
  });
  const verified = await verifyToken(issued.token, env);
  assert.equal(verified.ok, true);
  const tamperedPayload = Buffer.from(JSON.stringify({ ...verified.payload, v: 1, extra: true })).toString("base64url");
  const parts = issued.token.split(".");
  const tampered = `${parts[0]}.${tamperedPayload}.${parts[2]}`;
  const bad = await verifyToken(tampered, env);
  assert.equal(bad.ok, false);
});

test("refresh accepts expired-but-valid signatures when ignoreExp is set", async () => {
  const k1 = await generateSigningPair();
  const env = { LICENSE_SIGNING_KEY_K1: k1.pkcs8, LICENSE_SIGNING_PUB_K1: k1.pub };
  const issued = await issueToken({
    keyHash: "hash",
    deviceId: "device",
    entitlements: ["cleanup"],
    licenseType: "personal",
    maxDevices: 3,
    ttlSeconds: 1,
    env,
    now: 1_000,
  });
  const expired = await verifyToken(issued.token, env, { now: 10_000 });
  assert.equal(expired.ok, false);
  const renew = await verifyToken(issued.token, env, { ignoreExp: true, now: 10_000 });
  assert.equal(renew.ok, true);
});

test("disputed TTL is 14 days, active is 90", () => {
  assert.equal(TOKEN_TTL_DISPUTED, 14 * 24 * 3600);
  assert.equal(TOKEN_TTL_ACTIVE, 90 * 24 * 3600);
});

# Implementation guide

## Layout

- `shared/storage-rules.json` — the only hand-edited rules file
- `scripts/sync-rules.sh` — copies it into the app resource with `generated: true`
- `scripts/validate-rules.mjs` — schema and handoff constraints
- `scripts/ci-guardrails.sh` — destructive-API and architecture greps
- `app/Sources/DiskPrune` — native code, one SPM executable + tests
- `worker/` — licensing backend (Phase 4). D1 + KV rate limits + Stripe-verified webhooks.
- `app/Sources/DiskPrune/Licensing/` — native client (Phase 5). Verifies DPL tokens locally. Scan/autopsy do not consult it.
- `web/` — static Astro site. Success page is status-only (`GET /v1/checkout/:id/status`).
- `site/` — current preview website (delete only after `web/` port, commit 7.7). Success page no longer fabricates keys.

## Native pipeline

`ScanEngine` streams `ScanEvent`s from probes in a fixed order (Xcode → Docker → Package managers → Caches → Logs). It holds scan-global `SeenFileIDs` for hardlink accounting. It has no filesystem-mutating API.

`PlannedItem.init?(item:userSelected:)` is the only constructor and enforces eight conditions. `CleanupPlan.init?` rejects empty plans and ancestor/descendant pairs.

`CleanupExecutor.execute(_:)` takes a `CleanupPlan` only (DEC-008). Per item: seven TOCTOU checks, then `trashItem`. Failures never abort the batch. There is no `removeItem` fallback.

## Worker (Phase 4)

`worker/src/` is the licensing Worker. Tests use Node 22 `node:sqlite` (`--experimental-sqlite`) as a D1 stand-in. The only production npm dependency is `stripe`.

```bash
cd worker
npm ci
npm test                  # all worker tests
npm run test:licensing    # T-ENC / T-TOK / T-WH
```

`wrangler.toml` D1 and KV ids are placeholders until the owner runs:

```bash
# Requires: npx wrangler login  (or CLOUDFLARE_API_TOKEN + CLOUDFLARE_ACCOUNT_ID)
# Optional env: STRIPE_WEBHOOK_SECRET  RESEND_API_KEY  STRIPE_PRICE_ID
bash scripts/provision-worker.sh --check   # report only
bash scripts/provision-worker.sh --apply   # create D1+KV, generate k1, put secrets, migrate, deploy
```

`--apply` writes the **public** k1 into `PublicKeys.k1Base64` and `[vars] LICENSE_SIGNING_PUB_K1`, and `wrangler secret put`s the private key (never committed). Commit the two public files afterwards. Do not reuse KV `c273cf8e9c864d5bbd46840db2a7f153`.

`GET /key-lookup` is gone. Checkout status never returns a key.

## Website success page (Phase 7.5 / B-13)

`web/src/pages/success.astro` reads `session_id` and calls `GET /v1/checkout/{id}/status`. It renders payment/delivery state and a masked email only. Poll paid+pending three times at 2 s, then the support line. The license key never reaches the browser.

```bash
node --test web/test/*.test.mjs
```

CI job 9 (`node scripts/check-licensing-config.mjs`) asserts the public keys match and that no PKCS#8 blob is in source.

## Native licensing (Phase 5)

`Licensing/LicenseToken.swift` verifies compact Ed25519 DPL tokens over the
transmitted bytes (never re-serialized JSON). `LicenseManager.canClean` is
true only when a stored token verifies and `ent` contains `"cleanup"`.

Activate / refresh / release talk to `https://api.diskprune.com`. Refresh is
at most once per 24 h; network failure is a silent no-op. An expired-but-valid
token is sent to `/refresh` without re-entering the key.

`PublicKeys.k1Base64` must equal `worker/wrangler.toml` `[vars] LICENSE_SIGNING_PUB_K1`.
The provisioner replaces both with a production pair. The private key never belongs
in this repository.

## Running checks

```bash
node scripts/validate-rules.mjs
bash scripts/sync-rules.sh
bash scripts/ci-guardrails.sh
node scripts/check-licensing-config.mjs
bash scripts/provision-worker.sh --check
node --test web/test/*.test.mjs
cd worker && npm test
cd app && swift test   # macOS
```

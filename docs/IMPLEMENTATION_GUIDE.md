# Implementation guide

## Layout

- `shared/storage-rules.json` — the only hand-edited rules file
- `scripts/sync-rules.sh` — copies it into the app resource with `generated: true`
- `scripts/validate-rules.mjs` — schema and handoff constraints
- `scripts/ci-guardrails.sh` — destructive-API and architecture greps
- `app/Sources/DiskPrune` — native code, one SPM executable + tests
- `worker/` — licensing backend (Phase 4). D1 + KV rate limits + Stripe-verified webhooks.
- `app/Sources/DiskPrune/Licensing/` — native client (Phase 5). Verifies DPL tokens locally. Scan/autopsy do not consult it.
- `site/` — current preview website (delete only after `web/` port, commit 7.7)

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

`wrangler.toml` has placeholder D1 and KV ids. Owner must create the database and namespace, `wrangler secret put` the keys listed in that file, and apply `migrations/0001_init.sql`. Do not commit secrets.

`GET /key-lookup` is gone. Checkout status never returns a key.

## Native licensing (Phase 5)

`Licensing/LicenseToken.swift` verifies compact Ed25519 DPL tokens over the
transmitted bytes (never re-serialized JSON). `LicenseManager.canClean` is
true only when a stored token verifies and `ent` contains `"cleanup"`.

Activate / refresh / release talk to `https://api.diskprune.com`. Refresh is
at most once per 24 h; network failure is a silent no-op. An expired-but-valid
token is sent to `/refresh` without re-entering the key.

`PublicKeys.k1Base64` must be replaced with the deployed `LICENSE_SIGNING_PUB_K1`
before a signed release. The private key never belongs in this repository.

## Running checks

```bash
node scripts/validate-rules.mjs
bash scripts/sync-rules.sh
bash scripts/ci-guardrails.sh
cd worker && npm test
cd app && swift test   # macOS
```

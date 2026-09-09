# Changelog

## Unreleased

### Native licensing (Phase 5)

- Deleted top-level `LicenseManager.swift` (B-11: `isActivated` was true if any Keychain item existed).
- Added `Licensing/{PublicKeys,LicenseToken,DeviceIdentity,KeychainStore,LicenseManager}.swift`. Cleanup entitlement is a verified Ed25519 DPL token with `ent` containing `"cleanup"`. Keychain presence grants nothing (`kSecAttrService = com.diskprune.app`, `AfterFirstUnlockThisDeviceOnly`).
- Device identity is a random UUID. No hardware identifiers.
- Activate / refresh / release match the Phase 4 Worker contract. Refresh ignores local `exp` (expired-but-valid tokens renew). Released/revoked refresh is stored as an end-reason; cleanup stays available until `exp`.
- Offline: valid token works up to 90 days; expired token disables cleanup only, with “DiskPrune needs to check your license. Connect to the internet.” Clock rollback fails open for 7 days.
- Licence settings tab wires activation, status, this-Mac release, and seat-limit device list. Scan, autopsy, and planning do not consult `LicenseManager`. `confirmMoveToTrash` requires `canClean`.
- Native tests: T-TOK-01…07, T-KC-01/02, T-DEV-01/02, T-OFF-01…05/07, activate/seat-limit/refresh end-states.

### Licensing backend (Phase 4)

- Rewrote `worker/` onto D1 + KV rate limits. Stripe webhooks use `constructEventAsync` with `SubtleCryptoProvider`. Unsigned `POST /webhook` is `400` and writes nothing (B-12).
- Removed `GET /key-lookup`. `GET /v1/checkout/:id/status` returns payment/delivery state and a masked email only.
- License keys are Crockford `PRUNE-XXXXX-XXXXX-XXXXX-XXXXX`, hashed (SHA-256) and stored as AES-256-GCM `v1.<iv>.<ct||tag>` with AAD = license id. Decrypt sites: fulfilment email, resend, retry sweep.
- Ed25519 compact DPL tokens. Activate/refresh issue 90-day tokens; disputed refresh is 14 days. Released and revoked devices cannot refresh.
- Fulfilment is idempotent on `fulfillments.stripe_session_id` (no TTL). Email delivery never rolls back a committed license. CORS is `https://diskprune.com` only.
- CI jobs 6 (worker tests) and 7 (token/crypto/idempotency). Guardrails reject `Math.random`, `/key-lookup`, and `Access-Control-Allow-Origin: *` in `worker/src`.
- Website success-page rewrite is Phase 7 (B-13). Gate 3 is not PASS until production keys and a live purchase.

### Native UI (Phase 3)

- Replaced the placeholder `ContentView` shell with the Design Guide interface: Overview (Storage Autopsy), Cleanup, Snapshots. Scan is a toolbar action. Settings is a native Settings scene.
- Cleanup goes Scan → selection → `PlannedItem` → `CleanupPlan` → dry run → TOCTOU → `CleanupExecutor` → Trash → receipt. The new UI does not call `ScannerActor.trash(urls:)`.
- Receipt copy no longer says “reclaim” for Trash-moved bytes. It now reads: “Empty Trash to permanently remove these items from your Mac.” T-TERM-01 also bans `reclaim` in ReceiptView / CleanupPlanView.
- Snapshots are inspect-only. No delete affordance and no snapshot-deletion command in the UI.
- Visual QA package: `scripts/package-macos.sh` copies the storage-rules resource into the app bundle (previous DMG packaging omitted it). Reviewer protocol is `docs/VISUAL_QA.md`.
- Visual QA capture no longer mutates `NSVisualEffectView.canDrawSubviewsIntoLayer` (that hung macos-latest with 0 PNGs). After a `CALayer.render` safety PNG, the live sidebar is recovered with `screencapture -l` from the workflow, `CGWindowListCreateImage`, or the on-screen `NSTableView` cells. The harness does not call `FileManager.removeItem`. Receipt copy is “Empty Trash to permanently remove these items from your Mac.”
- `destination` is no longer `@Published`. Same-value assigns do not republish.
- `907e103e` fixed `AutopsyModel` Int64 overflow (`classifiedBytes * w / weightTotal`). Post-scan Overview, Storage sidebar, and live Cleanup render. Gate 4 **PASS** on `2241cbe5` after human review of Visual QA run 33.


### Fixes

- `FileIdentity` no longer treats `st_blocks == 0` as "size unknown" and substitutes `st_size`. That miscounted sparse files (including the 10 GiB SPARSE01 fixture and `Docker.raw`) as fully allocated. `onDiskBytes` is always `st_blocks × 512`.
- `DirectorySizer` counts only regular files. A symlink root was being counted as `fileCount == 1` even though it was not followed (SYM01).
- Swift 5.10 compile errors that failed CI jobs 1–2: `trashItem` takes `NSURL?`; `Result` failure type must be `Error`; `volumeAvailableCapacityForImportantUsage` (`Int64?`) cannot be coalesced with `volumeAvailableCapacity` (`Int?`).

### Safety

- Removed APFS snapshot deletion (`tmutil deletelocalsnapshots`) from the native app. Snapshots are inspect-only via `SnapshotInspector.list()`.
- Cleanup now has a real plan type: `PlannedItem.init?` (eight conditions) → `CleanupPlan` → `CleanupExecutor.execute(_:)` → `trashItem` only. One failure does not abort the batch.
- Replaced `Math.random()` license-key generation in the Worker with `crypto.getRandomValues`. Signature verification landed in Phase 4 (`constructEventAsync`).

### Scanner

- Canonical `/shared/storage-rules.json` (42 rules, 10 published) with schema validation and CI drift gate.
- `FileIdentity` / `DirectorySizer` measure allocated bytes (`st_blocks × 512`) with hardlink and symlink semantics.
- Probes for Xcode, Docker (inspect-only), package managers, caches, and logs.

### Repository

- CI jobs 1–5: Swift debug build, Swift tests, guardrails, rules validation, rules drift.
- Stopped tracking `web/dist/`, `web/node_modules/`, and `worker/.wrangler/cache/wrangler-account.json`.
- Deleted `build-and-verify.sh`.

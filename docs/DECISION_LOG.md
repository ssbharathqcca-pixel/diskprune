# Decision log

Append-only. Record decisions actually made during implementation.

## DEC-001 — Cleanup uses macOS Trash

- Date: 2026-09-08
- Status: accepted (handoff)
- Decision: The only destructive filesystem call is `FileManager.trashItem`.
- Rationale: Reversibility is the real TOCTOU mitigation.
- Rejected: `removeItem` fallback when Trash fails.
- Consequences: Available capacity often does not change until the user empties Trash.

## DEC-002 — APFS snapshots are read-only in v1

- Date: 2026-09-08
- Status: accepted (handoff); snapshot *deletion* removed from the baseline in Phase 0
- Decision: No `tmutil deletelocalsnapshots`. Inspector (when added) may only `listlocalsnapshots`.
- Rationale: Deleting local snapshots is a restore-capability loss, not cache cleanup.
- Rejected: "flush purgeable space" as a product action.
- Consequences: Snapshot bytes are never part of a cleanup plan.

## DEC-003 — Docker.raw is protected

- Date: 2026-09-08
- Status: accepted (handoff); probe not yet implemented
- Decision: Docker data is inspect-only, running or stopped.
- Rationale: Deleting `Docker.raw` corrupts or destroys the user's image/volume state.
- Rejected: `.advanced` as a selectable cleanup tier in v1.

## DEC-004 — Ed25519 signed licenses

- Date: 2026-09-08
- Status: accepted (handoff); Worker signing implemented in Phase 4; app verification is Phase 5
- Decision: Compact JWS-style tokens, signed with Ed25519 on the Worker, verified with CryptoKit.
- Rationale: Offline verification without shipping the private key.
- Rejected: "presence of a Keychain item means licensed."

## DEC-005 — Random Keychain device identity

- Date: 2026-09-08
- Status: accepted (handoff); not yet implemented
- Decision: Random UUID in Keychain (`AccessibleAfterFirstUnlockThisDeviceOnly`). No hardware identifiers.
- Rejected: `IOPlatformSerialNumber`, MAC address, hardware UUID.

## DEC-006 — Storage Autopsy does not pretend to reconcile unclassified bytes

- Date: 2026-09-08
- Status: accepted (handoff); not yet implemented
- Decision: Coverage reports examined / explained / not examined. `permissionLimitedBytes` is always nil in v1.
- Rejected: Inventing an "Other" bucket that forces totals to sum to disk used.

## DEC-007 — `inout Set<FileID>` on async probe APIs is represented by a reference box

- Date: 2026-09-08
- Status: accepted (language constraint)
- Decision: Swift forbids `inout` on `async` functions. `SeenFileIDs` is a lock-protected reference type that stands in for the spec's `inout Set<FileID>`.
- Rationale: Keep sequential, deterministic global hardlink ownership without inventing a second accounting model.
- Rejected: Making DirectorySizer fully synchronous (would block cooperative cancellation).
- Consequences: Probe signatures take `SeenFileIDs` instead of `inout Set<FileID>`. Semantics are identical.

## DEC-008 — `CleanupExecutor.execute` takes only a `CleanupPlan`

- Date: 2026-09-08
- Status: accepted (stricter reading of GATE 1 vs PART 5.4)
- Decision: `func execute(_ plan: CleanupPlan) async -> CleanupReceipt`. `SpaceVerifier` is a static enum and is called internally. Progress is an optional handler stored on the actor, not a method parameter.
- Rationale: GATE 1 and the execution directive require exactly one parameter of type `CleanupPlan`. PART 5.4's extra parameters are infrastructure, not plan data.
- Rejected: `execute(plan:verifier:progress:)` as the public signature.
- Consequences: Tests set `executor.progress` (or observe the receipt) rather than passing a closure into `execute`.

## DEC-009 — New UI does not consult LicenseManager

- Date: 2026-09-08
- Status: accepted; amended Phase 5
- Decision: Scan, explain, and cleanup *planning* never read `LicenseManager`. The Licence settings tab is the activation UI. Phase 5 gates only `confirmMoveToTrash` on `canClean` (verified token).
- Rationale: T-OFF-07 / Builder Rule 8. The free tier has no code path through `LicenseManager`.
- Rejected: Treating Keychain presence as licensed (B-11). Wiring the placeholder license sheet to the new cleanup path in Phase 3.

## DEC-013 — Entitlement is a verified DPL token

- Date: 2026-09-09
- Status: accepted (Phase 5)
- Decision: `LicenseManager.canClean` is `entitlements.contains("cleanup")` after `LicenseToken.verify`. Dummy Keychain items, including the old `DiskPruneLicense` account, grant nothing. Tampered / wrong-device tokens are deleted. Expired tokens stay stored for `/refresh`. Clock rollback fails open for 7 days, then disables cleanup only.
- Rejected: `isActivated` as `SecItemCopyMatching` success.
- Consequences: Production `PublicKeys.k1` must match Worker `LICENSE_SIGNING_PUB_K1` before a signed release.


## DEC-015 — Success page is status-only (B-13)

- Date: 2026-09-10
- Status: accepted (Phase 7.5)
- Decision: `web/src/pages/success.astro` (and `site/src/routes/success.tsx` until 7.7) call `GET /v1/checkout/:id/status` and render the handoff copy table. `issueLicense()` is deleted. The Worker response may contain only `payment_state`, `delivery_state`, `email_masked`. Paid+pending polls 3× at 2 s. Missing/invalid `session_id` does not claim payment.
- Rejected: Showing the key on the success page; calling `/key-lookup`; treating a URL param as proof of payment; generating keys in `localStorage`.

## DEC-014 — Public k1 is wrangler [vars]; private k1 is a secret; D1/KV ids come from the owner provisioner

- Date: 2026-09-09
- Status: accepted (Phase 6 / Gate 3 prep)
- Decision: `LICENSE_SIGNING_PUB_K1` is public Worker configuration in `wrangler.toml` `[vars]` and must exactly equal `PublicKeys.k1Base64`. CI job 9 fails on mismatch or PKCS#8 material in source. The PKCS#8 private key is only `wrangler secret put LICENSE_SIGNING_KEY_K1`. Production D1 `diskprune-licenses` and KV `RATE_LIMITS` ids are written by `scripts/provision-worker.sh --apply` on an authenticated Wrangler session. The retired LICENSES KV `c273cf8e9c864d5bbd46840db2a7f153` is never reused as RATE_LIMITS. This builder does not generate a production keypair (the private key would transit chat/sandbox logs).
- Rationale: A public verify key in git is required for the native app and for a mechanical match check. Fabricating D1/KV ids or committing secrets is forbidden. `swift test | tee` without pipefail produced a false-green job 2 on `2afa67ba`.
- Rejected: Putting the private key in `[vars]`; generating the production pair in this sandbox; failing CI on D1/KV placeholders before the owner can provision; handoff 6.1/6.2 notarization as this Phase 6.

## DEC-010 — Receipt UI has three accounting lines

- Date: 2026-09-08
- Status: accepted (design review correction)
- Decision: Receipt displays Estimated recoverable, Moved to Trash, Storage immediately available. `volumeAvailableBefore` / `volumeAvailableAfter` are not UI rows.
- Rationale: Final design review. The Design Guide's leftover "four-line block" wording is stale.
- Rejected: A fourth accounting row.

## DEC-011 — Snapshots screen does not display a deletion command

- Date: 2026-09-08
- Status: accepted
- Decision: The Snapshots pane states that DiskPrune does not delete snapshots and links Apple's local-snapshot documentation. It does not print a snapshot-deletion command.
- Rationale: T-SNAP-03 / Builder Rule 6 forbid that API in production source. Safety architecture wins over Design Guide 13.9's Terminal snippet.
- Rejected: Showing the deletion command as user education.

## DEC-012 — Phase 4 Worker uses node:sqlite for tests

- Date: 2026-09-08
- Status: accepted
- Decision: Worker unit tests wrap Node 22 `node:sqlite` `DatabaseSync` as a D1 stand-in. Production runtime is Cloudflare D1. The only production npm dependency is `stripe`.
- Rationale: Handoff forbids extra Worker dependencies. `better-sqlite3` would need a native build.
- Rejected: Hitting a live D1 from CI; adding a test-only native SQLite binding.

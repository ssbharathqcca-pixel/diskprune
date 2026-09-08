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
- Status: accepted (handoff); not yet implemented
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
- Status: accepted
- Decision: Phase 3 UI never reads `LicenseManager.isActivated`. Scan, explain, and cleanup planning stay available. The Licence settings tab is a non-activating shell. Real tokens are Phase 5.
- Rationale: T-OFF-07 / Builder Rule 8. The existing manager treats Keychain presence as licensed (B-11).
- Rejected: Wiring the placeholder license sheet to the new cleanup path.

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

# Changelog

## Unreleased

### Fixes

- `FileIdentity` no longer treats `st_blocks == 0` as "size unknown" and substitutes `st_size`. That miscounted sparse files (including the 10 GiB SPARSE01 fixture and `Docker.raw`) as fully allocated. `onDiskBytes` is always `st_blocks × 512`.
- `DirectorySizer` counts only regular files. A symlink root was being counted as `fileCount == 1` even though it was not followed (SYM01).
- Swift 5.10 compile errors that failed CI jobs 1–2: `trashItem` takes `NSURL?`; `Result` failure type must be `Error`; `volumeAvailableCapacityForImportantUsage` (`Int64?`) cannot be coalesced with `volumeAvailableCapacity` (`Int?`).

### Safety

- Removed APFS snapshot deletion (`tmutil deletelocalsnapshots`) from the native app. Snapshots are inspect-only via `SnapshotInspector.list()`.
- Cleanup now has a real plan type: `PlannedItem.init?` (eight conditions) → `CleanupPlan` → `CleanupExecutor.execute(_:)` → `trashItem` only. One failure does not abort the batch.
- Replaced `Math.random()` license-key generation in the Worker with `crypto.getRandomValues`. Signature verification is still Phase 4.

### Scanner

- Canonical `/shared/storage-rules.json` (42 rules, 10 published) with schema validation and CI drift gate.
- `FileIdentity` / `DirectorySizer` measure allocated bytes (`st_blocks × 512`) with hardlink and symlink semantics.
- Probes for Xcode, Docker (inspect-only), package managers, caches, and logs.

### Repository

- CI jobs 1–5: Swift debug build, Swift tests, guardrails, rules validation, rules drift.
- Stopped tracking `web/dist/`, `web/node_modules/`, and `worker/.wrangler/cache/wrangler-account.json`.
- Deleted `build-and-verify.sh`.

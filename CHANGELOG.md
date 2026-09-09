# Changelog

## Unreleased

### Native UI (Phase 3)

- Replaced the placeholder `ContentView` shell with the Design Guide interface: Overview (Storage Autopsy), Cleanup, Snapshots. Scan is a toolbar action. Settings is a native Settings scene.
- Cleanup goes Scan → selection → `PlannedItem` → `CleanupPlan` → dry run → TOCTOU → `CleanupExecutor` → Trash → receipt. The new UI does not call `ScannerActor.trash(urls:)`.
- Receipt copy no longer says “reclaim” for Trash-moved bytes. It now reads: “Empty Trash to permanently remove these items from your Mac.” T-TERM-01 also bans `reclaim` in ReceiptView / CleanupPlanView.
- Snapshots are inspect-only. No delete affordance and no snapshot-deletion command in the UI.
- Visual QA package: `scripts/package-macos.sh` copies the storage-rules resource into the app bundle (previous DMG packaging omitted it). Reviewer protocol is `docs/VISUAL_QA.md`. Gate 4 remains NOT PASS.
- Visual QA capture no longer mutates `NSVisualEffectView.canDrawSubviewsIntoLayer` (that hung macos-latest with 0 PNGs). After a `CALayer.render` safety PNG, the live sidebar is recovered with `screencapture -l` from the workflow, `CGWindowListCreateImage`, or the on-screen `NSTableView` cells. The harness does not call `FileManager.removeItem`. Receipt copy is “Empty Trash to permanently remove these items from your Mac.” Gate 4 remains NOT PASS.
- `destination` is no longer `@Published`. Same-value assigns (including `List(selection:)` writeback of the current row when the Storage section appears) do not republish, which is what hung the live RootView after `ingestScan` (`1ecd789b`). Selection stays a non-optional Binding — the original `$session.destination` overload — so List cannot fight `nil`. `2f983e21` did not compile (`self` required in the class closure) and used an optional Binding. Sidebar content and Autopsy are unchanged. Gate 4 remains NOT PASS.


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

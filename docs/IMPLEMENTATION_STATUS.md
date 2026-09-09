Last verified commit: `2cea2c21` (CI jobs 1–5 GREEN; Build macOS App GREEN; Visual QA run 30 on `2cea2c21` SUCCESS with all post-scan screens captured without watchdog). Post-scan hang resolved by fixing Int64 overflow in `AutopsyModel.init`. Overview / Autopsy with data (03, 09) and live RootView (05c) now verified in CI. Gate 4 remaining items are human review / physical Mac verification. Phase 4 is not started.

An item is `[x]` only after its acceptance evidence exists.

## Gate 0 — Repository and build baseline

- [x] `.gitignore` covers `web/dist/`, `.wrangler/`, `node_modules/`
- [x] `web/dist/`, `web/node_modules/`, `worker/.wrangler/...` untracked
- [x] `build-and-verify.sh` deleted
- [x] CI jobs 1–5 added
- [x] Guardrails pass locally (`scripts/ci-guardrails.sh`) and on `0c24ff78` / `7a391077`
- [x] `swift build` / `swift test` on macOS — evidence: GitHub Actions CI run 26 on `0c24ff78` (44 tests)

## Gate 1 — Filesystem safety

- [x] `PlannedItem.init?` encodes the eight conditions
- [x] `CleanupPlan.init?` rejects empty and ancestor/descendant
- [x] Seven TOCTOU checks in `PathValidator.revalidateBeforeTrash`
- [x] `CleanupExecutor.execute(_:)` takes only `CleanupPlan`
- [x] Per-item errors; vanished item does not abort the batch
- [x] Unplanned sibling survives
- [x] No `removeItem` in `Sources/DiskPrune` (`7a391077` handshake; `e2fdb04d` had failed this)
- [x] `deletelocalsnapshots` absent from production source
- [x] New UI does not call `ScannerActor.trash(urls:)` (source grep + UIPipelineTests)
- [x] Legacy `ScannerActor.trash(urls:)` / `ContentView` / `SafetyRules` deleted after UI was CI-green (Rule 18)

## Gate 2 — Scanner and accounting

- [x] `FileIdentity.lstat` (only POSIX)
- [x] `DirectorySizer` depth cap 64, symlink non-follow, hardlink item-local dedup
- [x] `StorageCoverage` with `permissionLimitedBytes == nil` and notExamined clamp
- [x] Autopsy headlines use `StorageCoverage`, never Σ item sizes (T-HL-04 / T-COV-02)
- [ ] Real-Mac DerivedData vs `du -sk` — **NOT TESTED** (requires a Mac)

## Gate 3 — Licensing

- [ ] Worker rewrite not started
- [x] New UI does not gate on `LicenseManager.isActivated`

## Gate 4 — Native UX

- [x] Three sidebar destinations: Overview, Cleanup, Snapshots
- [x] Scan is a toolbar action
- [x] Settings is a Settings scene with TabView
- [x] Dry run precedes cleanup; "Nothing has changed yet."
- [x] Receipt three-line accounting
- [x] Protected/advanced have no checkbox
- [x] Packaging script + Visual QA protocol (`docs/VISUAL_QA.md`, `scripts/package-macos.sh`)
- [x] CI screenshot workflow of the packaged app (`docs/VISUAL-QA-CI.md`) — **supplemental, not Gate 4 PASS**
- [x] Overview / Autopsy with data (`03`, `09`) in CI — **captured on `2cea2c21`** (live RootView and hosted StorageAutopsyView rendered and captured)
- [x] Live `RootView` after `ingestScan` (sidebar Storage section + in-window chrome) — **captured on `2cea2c21`** (`05c-live-cleanup` completed without watchdog)
- [x] Sidebar `NSVisualEffectView` vibrancy in CI shots — **01/02 recovered on `30873fdd` via `screencapture -l`** (human still must review)
- [ ] Visual QA on a real Mac (light/dark/narrow) — **NOT TESTED**
- [ ] Human review of CI screenshots — **NOT TESTED**
- [ ] Canvas comparison — **NOT TESTED**
- [ ] Stranger comprehension test — **NOT TESTED**

CI Visual QA evidence on `2cea2c21` (run 30): first launch, scan progress, category, cleanup, empty cleanup, inspector (safe/protected/advanced), snapshots empty + dated, dry run, receipt, cleanup failure, settings, live cleanup with active Storage sidebar, and Overview/Autopsy with data (03, 09).

**Gate 4: NOT PASS (Pending human visual review & physical Mac testing).**

## Gate 5 — Signed universal release

- [ ] BLOCKED on Apple Developer secrets and a Mac

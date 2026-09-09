Last verified commit: `8b44f0b5` (CI jobs 1–5 GREEN; Build macOS App GREEN; Visual QA run 24 SUCCESS-with-watchdog). `8b44f0b5` dest=Cleanup before ingest: HatchSegment + idle Autopsy hosted; live hang still inside `waitForLayout` after ingest (no RootView probe). Gate 4 remains NOT PASS. Post-ingest Storage-section isolation is in flight.

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
- [ ] Overview / Autopsy with data (`03`, `09`) in CI — **NOT TESTED** (hosted idle Autopsy works; hosted autopsy-with-data and live ingest hang on `8b44f0b5`)
- [ ] Live `RootView` after `ingestScan` (sidebar Storage section + in-window chrome) — **NOT TESTED** (`8b44f0b5` hung in `waitForLayout` after dest=Cleanup ingest; HatchSegment/idle Autopsy hosted)
- [x] Sidebar `NSVisualEffectView` vibrancy in CI shots — **01/02 recovered on `30873fdd` via `screencapture -l`** (human still must review)
- [ ] Visual QA on a real Mac (light/dark/narrow) — **NOT TESTED**
- [ ] Human review of CI screenshots — **NOT TESTED**
- [ ] Canvas comparison — **NOT TESTED**
- [ ] Stranger comprehension test — **NOT TESTED**

CI Visual QA evidence on `0c24ff78` (42 PNGs, both themes): first launch, scan progress, category, cleanup, empty cleanup, inspector (safe/protected/advanced), snapshots empty + dated, dry run, receipt, cleanup failure, settings. **Not** autopsy/overview-with-data.

**Gate 4: NOT PASS.**

## Gate 5 — Signed universal release

- [ ] BLOCKED on Apple Developer secrets and a Mac

Last verified commit: pending Phase 3 push

An item is `[x]` only after its acceptance evidence exists.

## Gate 0 — Repository and build baseline

- [x] `.gitignore` covers `web/dist/`, `.wrangler/`, `node_modules/`
- [x] `web/dist/`, `web/node_modules/`, `worker/.wrangler/...` untracked
- [x] `build-and-verify.sh` deleted
- [x] CI jobs 1–5 added
- [x] Guardrails pass locally (`scripts/ci-guardrails.sh`)
- [x] `swift build` / `swift test` on macOS — evidence: GitHub Actions on `9280ee1`. Phase 3 UI will be re-evidenced on the next Actions run.

## Gate 1 — Filesystem safety

- [x] `PlannedItem.init?` encodes the eight conditions
- [x] `CleanupPlan.init?` rejects empty and ancestor/descendant
- [x] Seven TOCTOU checks in `PathValidator.revalidateBeforeTrash`
- [x] `CleanupExecutor.execute(_:)` takes only `CleanupPlan`
- [x] Per-item errors; vanished item does not abort the batch
- [x] Unplanned sibling survives
- [x] No `removeItem` in `Sources/DiskPrune`
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
- [ ] Visual QA on a real Mac (light/dark/narrow) — **NOT TESTED** in this Linux sandbox
- [ ] Canvas comparison — **NOT TESTED** (canvas unreachable)

## Gate 5 — Signed universal release

- [ ] BLOCKED on Apple Developer secrets and a Mac

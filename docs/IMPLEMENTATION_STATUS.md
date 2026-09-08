# Implementation status

Last verified commit: pending push (builder working tree)

An item is `[x]` only after its acceptance evidence exists.

## Gate 0 — Repository and build baseline

- [x] `.gitignore` covers `web/dist/`, `.wrangler/`, `node_modules/`
- [x] `web/dist/`, `web/node_modules/`, `worker/.wrangler/...` untracked
- [x] `build-and-verify.sh` deleted
- [x] CI jobs 1–5 added
- [x] Guardrails pass locally (`scripts/ci-guardrails.sh`)
- [ ] `swift build` / `swift test` on macOS — **NOT TESTED here** (Linux sandbox, no Swift toolchain). Evidence: GitHub Actions jobs 1–2.

## Gate 1 — Filesystem safety

- [x] `PlannedItem.init?` encodes the eight conditions (unit tests in `PlanningTests.swift`)
- [x] `CleanupPlan.init?` rejects empty and ancestor/descendant
- [x] Seven TOCTOU checks in `PathValidator.revalidateBeforeTrash`
- [x] `CleanupExecutor.execute(_:)` takes only `CleanupPlan`
- [x] Per-item errors; vanished item does not abort the batch (`testCLN01`)
- [x] Unplanned sibling survives (`testCLN05`)
- [x] No `removeItem` in `Sources/DiskPrune`
- [x] `deletelocalsnapshots` absent from production source
- [ ] Native tests **NOT TESTED** on this host — they will run on `macos-latest`
- [ ] Legacy `ScannerActor.trash(urls:)` still exists for the old `ContentView` (Rule 18: not deleted until UI replacement is verified)

## Gate 2 — Scanner and accounting

- [x] `FileIdentity.lstat` (only POSIX)
- [x] `DirectorySizer` depth cap 64, symlink non-follow, hardlink item-local dedup
- [x] `StorageCoverage` with `permissionLimitedBytes == nil` and notExamined clamp
- [x] Shared rules corpus, 42 rules, 10 published, validation + drift CI
- [x] Probes: Xcode, Docker (inspect-only), package managers, caches, logs
- [x] `SnapshotInspector` lists only (`listlocalsnapshots`)
- [ ] Fixture sizes / sparse / hardlink tests written; **NOT TESTED** on this host
- [ ] Real-Mac DerivedData vs `du -sk` — **NOT TESTED** (requires a Mac)

## Gate 3 — Licensing

- [ ] Worker rewrite not started (B-12 remains except `Math.random` removal)

## Gate 4 — Native UX

- [ ] New UI not started; `ContentView` placeholders remain

## Gate 5 — Signed universal release

- [ ] BLOCKED on Apple Developer secrets and a Mac

## Gate 6 — Website

- [ ] `site/` still present (delete only in commit 7.7)

## Gate 7 — Launch rehearsal

- [ ] BLOCKED on live Stripe / Resend / a real Mac

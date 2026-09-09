Last verified product commit: `2afa67ba` (Phase 5 native licensing). Phase 6 production-infra prep is in this tree. Gate 4 remains **PASS** on `2241cbe5`. Gate 3 is **not** PASS — production D1/KV ids, Wrangler secrets, a deployed k1 private key, and a live Stripe purchase are still required.

An item is `[x]` only after its acceptance evidence exists.

## Gate 0 — Repository and build baseline

- [x] `.gitignore` covers `web/dist/`, `.wrangler/`, `node_modules/`
- [x] `web/dist/`, `web/node_modules/`, `worker/.wrangler/...` untracked
- [x] `build-and-verify.sh` deleted
- [x] CI jobs 1–5 added
- [x] CI jobs 6–7 added (Worker tests; licensing token/crypto/idempotency)
- [x] CI jobs 8–9 added (native T-TOK/T-KC/T-OFF evidence; public-key match)
- [x] Guardrails pass locally (`scripts/ci-guardrails.sh`) and on `2241cbe5`
- [x] `swift build` / `swift test` on macOS — evidence: GitHub Actions CI run 42 on `2241cbe5`

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
- [ ] Real-Mac DerivedData vs `du -sk` — **NOT TESTED** (requires a Mac; not a Gate 4 blocker)

## Gate 3 — Licensing

- [x] Worker rewrite: D1 schema, AES-GCM keys, Ed25519 tokens, Stripe `constructEventAsync`, durable fulfillments PK, no `/key-lookup` (B-12)
- [x] Worker tests T-WH-01…12, T-ENC-01…05, T-TOK-06/07, T-REF-01…06, T-SEAT-01/02, T-EMAIL-01…04, T-CHK-01/02
- [x] Scan / autopsy / explanations do not consult `LicenseManager` (T-OFF-07)
- [x] Native `Licensing/*` client — B-11 fixed; T-KC-01/02, T-DEV-01/02, T-TOK-01…07, T-OFF-01…05/07
- [x] `PublicKeys.k1Base64` equals Worker `[vars] LICENSE_SIGNING_PUB_K1` (CI job 9). Value is a placeholder until `scripts/provision-worker.sh --apply`
- [x] macOS CI job 8 executes named native licensing tests (pipefail; required-name evidence)
- [ ] Live Stripe + production D1/KV ids + Wrangler secrets (owner: `bash scripts/provision-worker.sh --apply`)
- [ ] `PublicKeys.k1Base64` replaced with a public key whose private key is the deployed `LICENSE_SIGNING_KEY_K1` (owner provisioner)

**Gate 3: NOT PASS** — Worker and native client are in tree. Production D1/KV, a deployed k1 private key, and a live purchase are still required. B-13 (`site/` success page) is Phase 7.

## Gate 4 — Native UX

- [x] Three sidebar destinations: Overview, Cleanup, Snapshots
- [x] Scan is a toolbar action
- [x] Settings is a Settings scene with TabView
- [x] Dry run precedes cleanup; "Nothing has changed yet."
- [x] Receipt three-line accounting
- [x] Protected/advanced have no checkbox
- [x] Packaging script + Visual QA protocol (`docs/VISUAL_QA.md`, `scripts/package-macos.sh`)
- [x] CI screenshot workflow of the packaged app (`docs/VISUAL-QA-CI.md`)
- [x] Overview / Autopsy with data (`03`, `09`) — live `RootView`, light+dark, 1100 and 880
- [x] Live `RootView` after `ingestScan` (Storage sidebar + in-window chrome) — `05c-live-cleanup`
- [x] Sidebar `NSVisualEffectView` vibrancy — `screencapture -l` of live window
- [x] Human review of CI screenshots — this Gate 4 review of `2241cbe5`
- [ ] Visual QA on a physical Mac as a logged-in user — **NOT TESTED** (reviewer has no Mac; CI live window is the accepted substitute)
- [ ] Canvas comparison — **NOT TESTED** (artifact login); written Design Guide matched
- [ ] Stranger comprehension test — **NOT TESTED**

Reviewed artifact: [visual-qa-2241cbe5](https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34305189018/artifacts/10086420999) from [Visual QA run 33](https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34305189018). `DONE=ok`. No placeholder/prohibition glyphs. Live Storage sidebar present after scan. Receipt is three accounting lines. Protected is not red. No snapshot delete.

**Gate 4: PASS.**

## Gate 5 — Signed universal release

- [ ] BLOCKED on Apple Developer secrets and a Mac

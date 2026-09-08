# Implementation status

Last verified commit: _local until push_

This board is evidence-based. An item is `[x]` only after its acceptance
evidence exists — not merely because a file was added.

## Gate 0 — Repository and build baseline

- [x] `.gitignore` covers `web/dist/`, `.wrangler/`, `node_modules/`, `shared/*.generated.json`
- [x] `web/dist/` untracked
- [x] `web/node_modules/` untracked (additional finding: 11,005 files were committed)
- [x] `worker/.wrangler/cache/wrangler-account.json` untracked
- [x] `build-and-verify.sh` deleted
- [x] CI jobs 1–3 added
- [x] `Package.swift` has a test target
- [x] APFS snapshot deletion removed from `ScannerActor` (B-8)
- [x] `Math.random` removed from `worker/src`
- [ ] `swift build -c release` on macOS (requires GitHub `macos-latest` runner)
- [ ] `swift test` on macOS (requires GitHub `macos-latest` runner)
- [x] Guardrails script passes on this Linux builder

## Gate 1 — Filesystem safety

- [ ] CleanupPlan / PlannedItem / PathValidator
- [ ] CleanupExecutor (Trash only, per-item errors)
- [ ] Seven TOCTOU checks
- [ ] `deletelocalsnapshots` absent (source: removed in Phase 0; SnapshotInspector not yet added)

## Gate 2 — Scanner and accounting

- [ ] FileIdentity / DirectorySizer / ScanEngine
- [ ] StorageCoverage
- [ ] Hardlink and sparse-file tests

## Gate 3 — Licensing and payment

- [ ] D1 schema, webhook signature, idempotency
- [ ] Encrypted key at rest, Ed25519 tokens

## Gate 4 — Native UX

- [ ] Replacement UI; `ContentView` still present

## Gate 5 — Signed universal release

- [ ] BLOCKED on Apple Developer secrets and a Mac

## Gate 6 — Website / demo / SEO

- [ ] `site/` still present (delete only in commit 7.7 after port verified)

## Gate 7 — Launch rehearsal

- [ ] BLOCKED on live Stripe, Resend, and a real Mac

## Known environment limits (this builder)

- Linux sandbox: no Swift toolchain, no `lipo` / `codesign` / `notarytool`
- No Apple, Stripe, Cloudflare, or Resend secrets in this environment
- Swift compile and native tests are verified by GitHub Actions, not locally

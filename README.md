# DiskPrune

Native macOS storage manager. Scan free. Lifetime license **$14.99**.

DiskPrune helps you understand why a Mac is full, then moves only what you
approve to Trash. It does **not** permanently delete files, empty Trash,
delete APFS snapshots, or delete Docker disk images.

## Repository layout

| Path | What it is |
| --- | --- |
| [`app/`](app/) | Native SwiftUI Mac app (Swift 5.10, macOS 14+) |
| [`docs/`](docs/) | Architecture, safety, status, decisions |
| [`site/`](site/) | Current preview website + simulated demo (to be ported) |
| [`web/`](web/) | Astro stub — target website after the port |
| [`worker/`](worker/) | Cloudflare Worker (pre-rewrite; signature verification is Phase 4) |
| [`shared/`](shared/) | Canonical storage-rules (added in Phase 1) |

## What the native app does today

The shipping source is still the five-file baseline, with one safety change:
**APFS snapshot deletion has been removed.**

- Scan walks hardcoded Tier 1 cache paths (`SafetyRules.tier1Paths()`)
- Cleanup still uses `FileManager.trashItem` on the scanned URL list (legacy path; replaced in Phase 2 by `CleanupPlan` → `CleanupExecutor`)
- Scan is free; purge is license-gated via `api.diskprune.com`
- Sizing, Storage Autopsy, TOCTOU, and the new UI are not in this tree yet

Build on a Mac:

```bash
cd app
swift build
swift test
```

## What DiskPrune will not do (v1)

- Permanently delete (`removeItem` / `rm -rf`)
- Empty Trash
- Run `tmutil deletelocalsnapshots`
- Delete `Docker.raw` or Docker data directories
- Claim that moving files to Trash has "freed" or "reclaimed" the space

See [`docs/CLEANUP_SAFETY.md`](docs/CLEANUP_SAFETY.md) and [`docs/KNOWN_LIMITATIONS.md`](docs/KNOWN_LIMITATIONS.md).

## CI

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs a debug Swift build,
Swift tests, and destructive-operation guardrails on every push and PR.

The macOS DMG workflow is still the ad-hoc, arm64-only pipeline. Universal
Developer ID signing is Phase 6 and requires Apple secrets.

## Website

`site/` is a simulated demo. It does not scan this machine. It will be ported
to `web/` (Astro) and then deleted. Do not treat the demo as more capable than
the binary.

## License worker (current, not the target)

`worker/` currently stores keys in KV, does **not** verify Stripe signatures,
and exposes `GET /key-lookup`. That endpoint is a known defect (B-12) and will
be replaced by a status-only checkout endpoint that never returns a key.

Buy: [Stripe checkout](https://buy.stripe.com/eVqeVc8nd9wx39efNdaR200)

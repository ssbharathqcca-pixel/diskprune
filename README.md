# DiskPrune

Native macOS storage intelligence. Scan free. Lifetime license **$14.99**.

DiskPrune helps you understand why a Mac is full, then moves only what you
approve to Trash. It does **not** permanently delete files, empty Trash,
delete APFS snapshots, or delete Docker disk images.

## Repository layout

| Path | What it is |
| --- | --- |
| [`app/`](app/) | Native SwiftUI Mac app (Swift 5.10, macOS 14+) |
| [`docs/`](docs/) | Architecture, safety, Design Guide, Visual QA |
| [`site/`](site/) | Current preview website + simulated demo (to be ported) |
| [`web/`](web/) | Astro stub — target website after the port |
| [`worker/`](worker/) | Cloudflare Worker (pre-rewrite; signature verification is Phase 4) |
| [`shared/`](shared/) | Canonical storage-rules |

## Native app (Phase 3)

The running UI is Overview / Cleanup / Snapshots per [`docs/DESIGN-GUIDE.md`](docs/DESIGN-GUIDE.md). Scan is a toolbar action. Settings is a native Settings scene.

Cleanup path: `ScanEngine` → selection → `PlannedItem` → `CleanupPlan` → dry run → TOCTOU → `CleanupExecutor` → Trash → receipt (three accounting lines).

**Gate 4 (visual QA): PASS** on `2241cbe5` after human review of the CI live-window artifact ([`docs/VISUAL-QA-CI.md`](docs/VISUAL-QA-CI.md)). Phase 4 is not started.


### Visual QA build

1. Latest successful [Build macOS App](https://github.com/ssbharathqcca-pixel/diskprune/actions/workflows/build-mac.yml) on `main`
2. Download artifact `DiskPrune-<sha>`
3. Follow [`docs/VISUAL_QA.md`](docs/VISUAL_QA.md) (right-click Open; ad-hoc, not notarized)

On a Mac, locally:

```bash
cd app
swift build
swift test
# then, on macOS only:
bash ../scripts/package-macos.sh
open DiskPrune.dmg
```

## What DiskPrune will not do (v1)

- Permanently delete (`removeItem` / `rm -rf`)
- Empty Trash
- Run snapshot deletion
- Delete `Docker.raw` or Docker data directories
- Claim that moving files to Trash has "freed" or "reclaimed" the space

See [`docs/CLEANUP_SAFETY.md`](docs/CLEANUP_SAFETY.md) and [`docs/KNOWN_LIMITATIONS.md`](docs/KNOWN_LIMITATIONS.md).

## CI

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs a debug Swift build,
Swift tests, guardrails, and storage-rules checks on every push.

The macOS DMG workflow is ad-hoc signed and runner-arch. Universal Developer ID
signing is Phase 6.

## Website

`site/` is a simulated demo. It does not scan this machine. It will be ported
to `web/` (Astro) and then deleted. Do not treat the demo as more capable than
the binary.

## License worker (current, not the target)

`worker/` currently stores keys in KV, does **not** verify Stripe signatures,
and exposes `GET /key-lookup`. That endpoint is a known defect (B-12).

Buy: [Stripe checkout](https://buy.stripe.com/eVqeVc8nd9wx39efNdaR200)

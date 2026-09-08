# DiskPrune

Native macOS storage manager. Scan free. Lifetime license $19.

DiskPrune reclaims caches, Xcode DerivedData, Docker disk, and APFS local
snapshots — then moves only what you approve to Trash. It is a SwiftUI app
for macOS 14+, not a subscription cleaner.

## Repository layout

| Path | What it is |
| --- | --- |
| [`app/`](app/) | Native SwiftUI Mac app (Swift 5.10, macOS 14+) |
| [`site/`](site/) | Product website + interactive Mac-window demo |
| [`web/`](web/) | Earlier Astro marketing stub (superseded by `site/`) |
| [`worker/`](worker/) | Cloudflare Worker: Stripe webhook, license activate, key lookup |
| [`.github/workflows/build-mac.yml`](.github/workflows/build-mac.yml) | Builds, ad-hoc signs, and uploads `DiskPrune.dmg` |

## Native app

Safety engine (`SafetyRules.swift` + `ScannerActor.swift`):

- **Tier 1 (safe, pre-selected):** `~/Library/Caches`, logs, Xcode DerivedData, npm / Cargo / Gradle caches
- **Tier 2 (review required):** Containers, Application Support, Docker Desktop
- **Purge:** `FileManager.trashItem` — not `rm -rf`
- **APFS:** `tmutil deletelocalsnapshots /` after a purge
- **License:** scan is free; purge POSTs to `api.diskprune.com/v1/licenses/activate` and stores the key in Keychain

Build on a Mac:

```bash
cd app
swift build -c release
```

GitHub Actions on `macos-14` packages an ad-hoc signed `.dmg` and publishes it
on version tags. On Sequoia: System Settings → Privacy & Security → Open Anyway.

Download: [latest DiskPrune.dmg](https://github.com/ssbharathqcca-pixel/diskprune/releases/latest/download/DiskPrune.dmg)

## Product site

`site/` is the current marketing site and an in-browser demo of the Mac app.
The demo enumerates the same paths as the Swift scanner on a simulated
developer disk. It does **not** read or delete files on your machine.

```bash
cd site
npm install
npm run dev
```

- `/` landing, comparison, pricing
- `/app` full demo window
- `/blog/...` guides (System Data, DerivedData, Docker disk, purgeable space)
- `/success` license receipt (preview issues a local `PRUNE-XXXX` key)

Demo license for the browser preview: `PRUNE-DEMO-2026-LIFE`

Buy lifetime: [Stripe checkout](https://buy.stripe.com/eVqeVc8nd9wx39efNdaR200)

## License worker

`worker/` is the `diskprune-licensing` Cloudflare Worker (`api.diskprune.com`):

- `POST /webhook` — Stripe `checkout.session.completed` → `PRUNE-XXXX-XXXX-XXXX` in KV
- `POST /v1/licenses/activate` — used by the native app
- `GET /key-lookup?session_id=` — used by the success page

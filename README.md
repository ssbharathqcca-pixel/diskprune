# DiskPrune

Native macOS storage intelligence. Scan free. Lifetime license **$19**.

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
| [`worker/`](worker/) | Cloudflare Worker licensing backend (D1 + Stripe-verified webhooks) |
| [`shared/`](shared/) | Canonical storage-rules |

## Native app (Phase 3)

The running UI is Overview / Cleanup / Snapshots per [`docs/DESIGN-GUIDE.md`](docs/DESIGN-GUIDE.md). Scan is a toolbar action. Settings is a native Settings scene.

Cleanup path: `ScanEngine` → selection → `PlannedItem` → `CleanupPlan` → dry run → TOCTOU → `CleanupExecutor` → Trash → receipt (three accounting lines).

**Gate 4 (visual QA): PASS** on `2241cbe5` after human review of the CI live-window artifact ([`docs/VISUAL-QA-CI.md`](docs/VISUAL-QA-CI.md)).


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
Swift tests, guardrails, storage-rules checks, Worker tests, and licensing
tests on every push.

The macOS **Visual QA** DMG workflow is ad-hoc signed and not a release.
Universal Developer ID signing, hardened runtime, notarization, and stapling
are [`docs/RELEASE.md`](docs/RELEASE.md) (Gate 5). That pipeline **fails
closed** without Apple secrets — it never publishes an ad-hoc DMG as a GitHub
Release. Gate 5 is not PASS until checks 1–9 pass against the mounted DMG and
checks 10–12 pass on real Macs.

## Website

`web/` is the Astro site for diskprune.com. Scan free, $19 lifetime, honest
comparison and guides. `site/` is a simulated demo and is not the product.

A notarized and stapled DMG is published  — see `/download`.

## License worker

`worker/` verifies Stripe signatures (`constructEventAsync`), stores licenses
in D1 (AES-256-GCM at rest), and issues Ed25519 tokens. There is **no**
`GET /key-lookup`. Checkout status returns payment/delivery state and a masked
email only — never a key or token.

| Endpoint | Role |
| --- | --- |
| `POST /webhook` | Stripe-signed fulfilment |
| `POST /v1/licenses/activate` | Activate a device; 90-day token |
| `POST /v1/licenses/refresh` | Renew; expired-but-valid tokens accepted; released/revoked blocked |
| `POST /v1/licenses/release` | Free a seat |
| `POST /v1/licenses/resend` | Always `200 {ok:true}` (no enumeration) |
| `GET /v1/checkout/:id/status` | Status only (`payment_state`, `delivery_state`, masked email — never a key) |

The success page (`web/src/pages/success.astro`) uses that status endpoint. It does not generate or display a license key.

The native app verifies Ed25519 DPL tokens locally (`Licensing/`). Cleanup
requires a verified `cleanup` entitlement. Scanning, autopsy, and explanations
do not consult `LicenseManager`.

`PublicKeys.k1Base64` must equal `worker/wrangler.toml` `[vars] LICENSE_SIGNING_PUB_K1`
(CI job 9). The matching private key is the Wrangler secret `LICENSE_SIGNING_KEY_K1`
and is not in this repository. Production D1/KV ids are in `wrangler.toml`
(`9d1259fe`).

Do not reuse KV namespace `c273cf8e9c864d5bbd46840db2a7f153`. Do not commit secrets.

Worker tests (Node 22, `--experimental-sqlite`):

```bash
cd worker
npm ci
npm test
```

Buy: [Stripe checkout](https://buy.stripe.com/eVqeVc8nd9wx39efNdaR200)

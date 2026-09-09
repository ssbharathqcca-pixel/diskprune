# Known limitations

Honest list. Do not hide these in marketing.

## Product (v1 design)

- Moving items to Trash does **not** immediately increase available volume capacity. Files remain on disk until the user empties Trash. DiskPrune never empties Trash.
- APFS local snapshots are inspect-only. DiskPrune does not delete them.
- `Docker.raw` and Docker data directories are never cleanup targets, whether the daemon is running or stopped.
- Targeted probes are not a complete volume reconciliation. Unexamined bytes are labeled "not examined", never "other".
- Permission-limited size is **unknown** (`permissionLimitedBytes` is always nil). DiskPrune will not guess.
- APFS clones are not modelled. Two clones of one file can each report full size; removing one may free almost nothing. This is disclosed, not hidden.
- Symlinks are never cleanup candidates and are never followed for sizing.
- `.app` bundles are measured whole and never emit child cleanup targets.
- v1 emits no `.advanced` cleanup targets.

## Baseline defects still present until later phases

- Legacy `ScannerActor.trash(urls:)`, `ContentView`, and `SafetyRules` removed after the new UI was CI-green (Rule 18).
- B-11 is fixed: cleanup entitlement requires a verified DPL token. A Keychain item is not a license.
- Worker B-12 is fixed in source: Stripe `constructEventAsync`, D1 idempotent fulfillments, encrypted keys, no `GET /key-lookup`. Production D1/KV ids and Wrangler secrets are owner-held (`scripts/provision-worker.sh --apply`). This sandbox cannot authenticate to Cloudflare.
- `PublicKeys.k1Base64` currently matches `wrangler.toml [vars] LICENSE_SIGNING_PUB_K1`, but both are a placeholder whose private key is **not** deployed. The owner provisioner generates the production pair. The private key is a Wrangler secret and is not in this repository.
- Website success page in `site/` still fabricates keys (B-13). `site/` is deleted only in commit 7.7 after the Astro port is verified.
- Universal / Developer ID / notarized release (handoff Phase 6.1/6.2, Gate 5) is not started. The packaging pipeline is still ad-hoc signed, arm64-only.
- This Linux builder cannot compile Swift, sign, or notarize.

## Environment

- Native tests and `swift build` run on GitHub Actions `macos-latest`, not in this sandbox.
- Gate 5 (Developer ID + notarization) and Gate 7 (live purchase) require owner-held secrets and real Macs.

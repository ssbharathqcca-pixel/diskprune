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

- `ScannerActor.trash(urls:)` still exists as a quarantined legacy path (Rule 18). The new UI does not call it. It will be deleted after this UI is CI-green.
- `LicenseManager.isActivated` still treats any Keychain item as licensed (B-11). The new UI does not consult it.
- Worker webhook still has no Stripe signature verification (B-12). `Math.random` has been removed; the rest of the worker rewrite is Phase 4.
- `GET /key-lookup` still returns a license key (B-12). It will be removed in the worker rewrite, not papered over.
- Website success page in `site/` still fabricates keys (B-13). `site/` is deleted only in commit 7.7 after the Astro port is verified.
- Release pipeline is still ad-hoc signed, arm64-only (Phase 6).
- This Linux builder cannot compile Swift, sign, or notarize.

## Environment

- Native tests and `swift build` run on GitHub Actions `macos-latest`, not in this sandbox.
- Gate 5 (Developer ID + notarization) and Gate 7 (live purchase) require owner-held secrets and real Macs.

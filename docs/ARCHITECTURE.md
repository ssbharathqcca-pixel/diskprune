# Architecture

Canonical cleanup pipeline (handoff PART 6):

```
Scan → Understand → Select → PlannedItem.init? → CleanupPlan
  → Dry run → TOCTOU (7 checks) → trashItem → Receipt
```

UI navigation (Design Guide PART 12): Overview · Cleanup · Snapshots. Scan is a toolbar action. Settings is a `Settings` scene.

## Current tree (Phase 3)

- `App.swift` — WindowGroup + Settings scene
- `UI/` — RootView, autopsy, scan progress, candidates, dry run, receipt, snapshots, settings
- `Licensing/` — Keychain + Ed25519 token verify + activate/refresh/release. Entitlement is a verified token, never Keychain presence (B-11)
- `Scanning/`, `Cleanup/`, `Knowledge/`, `Persistence/` — unchanged safety architecture
- `ContentView.swift` / `ScannerActor.swift` / `SafetyRules.swift` — **deleted** after the new UI was CI-green (Rule 18)
- Top-level `LicenseManager.swift` — **deleted**; replaced by `Licensing/LicenseManager.swift`

## Target boundaries

| Directory | May do | Must not do |
| --- | --- | --- |
| `Scanning/` | read, stat, stream items | mutate user files; reference `CleanupExecutor` |
| `Cleanup/` | `trashItem` on a `CleanupPlan` | accept `[URL]` / `[StorageItem]` / `ScanEngine` |
| `Persistence/` | write app-owned receipts and preferences | trash or delete user content |
| `Licensing/` | Keychain + token verify + activate | treat Keychain presence as entitlement |
| `UI/` | present plan / dry run / receipt | call `trashItem` directly; call `ScannerActor.trash` |

`CleanupExecutor.execute` takes exactly one parameter: `CleanupPlan`. See DEC-008.

Shared rules live in `/shared/storage-rules.json` only. The copy under `Knowledge/Resources/` is generated.

Receipt UI shows three accounting lines: estimated recoverable, moved to Trash, storage immediately available.

## Worker production (Phase 6 / Gate 3 prep)

- D1 `diskprune-licenses` + KV `RATE_LIMITS` ids live in `worker/wrangler.toml`. Placeholders until `scripts/provision-worker.sh --apply`.
- `LICENSE_SIGNING_PUB_K1` is `[vars]` (public) and must equal `PublicKeys.k1Base64`.
- `LICENSE_SIGNING_KEY_K1`, `LICENSE_ENCRYPTION_KEY`, `STRIPE_WEBHOOK_SECRET`, `RESEND_API_KEY` are Wrangler secrets only.
- Native licensing tests: CI job 8. Public-key match: CI job 9.


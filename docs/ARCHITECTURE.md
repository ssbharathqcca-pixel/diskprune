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
- `Scanning/`, `Cleanup/`, `Knowledge/`, `Persistence/` — unchanged safety architecture
- `ContentView.swift` / `ScannerActor.swift` / `SafetyRules.swift` — **legacy, not connected to the new UI** (Rule 18)
- `LicenseManager.swift` — unused by the new UI (Phase 5)

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

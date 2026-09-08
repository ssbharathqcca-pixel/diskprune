# Architecture

Canonical cleanup pipeline (handoff PART 6):

```
Scan → Understand → Select → PlannedItem.init? → CleanupPlan
  → Dry run → TOCTOU (7 checks) → trashItem → Receipt
```

## Current tree (Phase 0)

The baseline app is still the five-file Swift executable:

- `App.swift` — `@main` WindowGroup
- `ContentView.swift` — UI shell (placeholders remain)
- `ScannerActor.swift` — enumerate + `trashItem` on a URL array (**legacy; scheduled for deletion after Gate 1**)
- `SafetyRules.swift` — hardcoded paths (**legacy**)
- `LicenseManager.swift` — Keychain presence check (**legacy**)

Phase 0 removed `flushAPFSSnapshots()` so the tree satisfies the snapshot-deletion guardrail.

## Target boundaries

| Directory | May do | Must not do |
| --- | --- | --- |
| `Scanning/` | read, stat, stream items | mutate user files; reference `CleanupExecutor` |
| `Cleanup/` | `trashItem` on a `CleanupPlan` | accept `[URL]` / `[StorageItem]` / `ScanEngine` |
| `Persistence/` | write app-owned receipts and preferences | trash or delete user content |
| `Licensing/` | Keychain + token verify + activate | treat Keychain presence as entitlement |
| `UI/` | present plan / dry run / receipt | call `trashItem` directly |

`CleanupExecutor.execute` takes exactly one parameter: `CleanupPlan`. See DEC-008.

Shared rules live in `/shared/storage-rules.json` only. The copy under `Knowledge/Resources/` is generated.

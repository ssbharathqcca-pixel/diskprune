# Visual QA in CI — supplemental evidence

**Gate 4 is not passed by this workflow.**  
A human still has to look at the screenshots (and, when possible, a real Mac). CI green here means “PNGs were produced from the production UI,” not “the UI is approved.”

Related:

- Human protocol: [`VISUAL_QA.md`](VISUAL_QA.md)
- Design authority: [`DESIGN-GUIDE.md`](DESIGN-GUIDE.md)
- Workflow: [`.github/workflows/visual-qa.yml`](../.github/workflows/visual-qa.yml)

---

## What is tested

On `macos-latest`, the workflow:

1. Builds the real `DiskPrune` product (`swift build -c release`) and packages `DiskPrune.app`.
2. Launches **that binary** with `DISKPRUNE_VISUAL_QA=1`.
3. The env-gated harness (inert in normal launches) drives the production `RootView` already on screen.
4. Writes PNGs from `NSWindow.contentView.cacheDisplay` (the app’s own view — no Screen Recording TCC).
5. Exits. Unit tests only assert `VisualQARuntime.isEnabled == false`.

XCTest cannot host AppKit on this runner (signal 5). The catalog therefore runs inside the real app process.

It does **not** click **Move to Trash**. It does **not** call `CleanupExecutor`. It does **not** bypass `CleanupPlan` / TOCTOU.


---

## What is rendered from the real app

| Shot | Captured in CI? | Source |
| --- | --- | --- |
| `01-first-launch` | yes, live window | Packaged app `contentView` |
| `02-scan-progress` | yes, live window | Production `ScanView` via live `RootView` |
| `03-overview-autopsy` | **NO — hangs runner** | StorageAutopsyView / CapacityBar |
| `04-category-detail` | yes (light; dark 1100) | Production `ResultsView` |
| `05-cleanup-candidates` | yes (light) | Production `ResultsView` + plan footer |
| `06-item-inspector` | yes | Production `ItemDetailView` |
| `07-snapshots` | yes | Production `SnapshotView` empty state |
| `07b-snapshots-list` | yes | Production `SnapshotView` with dates |
| `08-empty-no-candidates` | yes (light) | Production empty cleanup |
| `09-overview-partial` | **NO — hangs runner** | StorageAutopsyView |
| `10-inspector-protected` | yes | Production inspector, Documents rule |
| `11-inspector-advanced` | yes | Production inspector, `docker-raw` |
| `12-dry-run` | yes | Production `DryRunSheet` — not executed |
| `13-receipt` | yes | Production `ReceiptView` (three lines) |
| `14-cleanup-failure` | yes | Production `ReceiptView` failed/skipped |
| `15-settings` | yes | Production `SettingsRootView` |


Light and dark: `NSAppearance` + `.preferredColorScheme`.  
Windows: **1100×720** and **880×560** for `RootView`. Sheets use their native sizes.

---

## What uses deterministic fixtures

Anything that would otherwise require a real scan of the runner, or a real Trash move:

- Catalog `StorageItem`s (copy and safety come from `/shared/storage-rules.json`)
- `StorageCoverage` / `SnapshotSummary`
- `AppSession.phase = .scanning` (probe names and byte labels only)
- `CleanupReceipt` values for receipt / failure shots

Fixtures go through the **existing** models and the **existing** `ingestScan` test seam. They are not a parallel UI and not a parallel cleanup pipeline.

---

## What cannot be verified in CI

- Overview / Autopsy with data (`StorageAutopsyView` / `CapacityBar` hangs the GitHub-hosted runner)
- Whether a stranger understands the Overview (comprehension, not pixels)
- Canvas composition fidelity (Claude artifact login)
- True device Light/Dark as a logged-in user, vs forced `NSAppearance`
- Full Disk Access / TCC permission UI (CI cannot grant FDA)
- Reduce Motion / Reduce Transparency / VoiceOver / Dynamic Type
- Gatekeeper “right-click Open” on a customer Mac
- Liquid Glass vs macOS 14 floor on a physical display
- That `screencapture` of another process succeeded (not used; the app snapshots its own `contentView`)


- Exact window-server chrome of a user session vs `NSWindow` in XCTest

If the packaged-app shot is missing, `manifest.json` → `limitations` says so. That is **NOT TESTED**, not a PASS.

---

## How to review the screenshots

1. Open the latest **Visual QA screenshots** run:  
   https://github.com/ssbharathqcca-pixel/diskprune/actions/workflows/visual-qa.yml
2. Download artifact `visual-qa-<sha>`.
3. Read `README.txt` and `manifest.json` first (`gate4` must remain `"NOT PASS"`).
4. Walk the human checklist in [`VISUAL_QA.md`](VISUAL_QA.md) against the PNGs.
5. Hard-fail the same as on a Mac: accent-tinted sidebar, four-line receipt, snapshot delete, Protected checkbox, more than two cards, “freed/reclaimed” on the receipt.

Do not treat “workflow green” as Gate 4 PASS.

Local Mac:

```bash
bash scripts/visual-qa.sh
open visual-qa-shots
```

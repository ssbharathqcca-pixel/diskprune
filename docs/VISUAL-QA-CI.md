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
2. Compiles the production UI into the existing XCTest target.
3. Hosts **production** views (`RootView`, `DryRunSheet`, `ReceiptView`, `SettingsRootView`) in a real `NSWindow`.
4. Writes PNGs organized by theme, window size, and screen.
5. Launches the packaged `DiskPrune.app` and attempts a first-launch screenshot of that process.

It does **not** click **Move to Trash**. It does **not** call `CleanupExecutor`. It does **not** bypass `CleanupPlan` / TOCTOU.

---

## What is rendered from the real app

| Shot | Source | Data |
| --- | --- | --- |
| `real-app/first-launch.png` | Packaged `DiskPrune.app` process | Runner’s real volume header via `VolumeProbe.home()` |
| `01-first-launch` | Production `RootView` in `NSWindow` | Same idle session as a normal launch (`scanOnLaunch` off) |
| `02-scan-progress` | Production `RootView` → `ScanView` | Injected `AppSession.phase = .scanning` (no disk walk) |
| `03-overview-autopsy` | Production `RootView` → `StorageAutopsyView` | `AppSession.ingestScan` with production `StorageItem` / `StorageCoverage` |
| `04-category-detail` | Production `ResultsView` | Same session, `destination = .category(.developer)` |
| `05-cleanup-candidates` | Production `ResultsView` + `CleanupPlanView` footer | Same session, `destination = .cleanup` |
| `06-item-inspector` | Production `.inspector` + `ItemDetailView` | Safe catalog item |
| `07-snapshots` | Production `SnapshotView` | `SnapshotSummary` (inspect-only; no delete control) |
| `08-empty-no-candidates` | Production empty cleanup state | Protected/advanced only; `cleanupCandidateBytes = 0` |
| `09-overview-partial` | Production autopsy + permission copy | `permissionLimitedPaths` set |
| `10-inspector-protected` | Production inspector | Documents rule |
| `11-inspector-advanced` | Production inspector | `docker-raw` rule (sparse callout from logical vs on-disk) |
| `12-dry-run` | Production `DryRunSheet` | Plan from selected safe items — **not executed** |
| `13-receipt` | Production `ReceiptView` | Constructed `CleanupReceipt` (three accounting lines) |
| `14-cleanup-failure` | Production `ReceiptView` | Failed + skipped outcomes — **not executed** |
| `15-settings` | Production `SettingsRootView` | Licence tab is a shell; no `LicenseManager.isActivated` |

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

- Whether a stranger understands the Overview (comprehension, not pixels)
- Canvas composition fidelity (Claude artifact login)
- True device Light/Dark as a logged-in user, vs forced `NSAppearance`
- Full Disk Access / TCC permission UI (CI cannot grant FDA)
- Reduce Motion / Reduce Transparency / VoiceOver / Dynamic Type
- Gatekeeper “right-click Open” on a customer Mac
- Liquid Glass vs macOS 14 floor on a physical display
- That `CGWindowListCreateImage` of the packaged app succeeded (Screen Recording TCC often blocks it; hosted `RootView` shots are then the evidence)
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

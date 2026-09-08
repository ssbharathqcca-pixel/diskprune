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
2. Injects `LSEnvironment` (`DISKPRUNE_VISUAL_QA=1` + output path) into that app’s Info.plist and ad-hoc signs it.
3. Launches **that .app** via LaunchServices (`open DiskPrune.app`).
4. The env-gated harness (inert in normal launches) drives the production `RootView` already on screen.
5. Writes PNGs by flattening the **already-committed** `CALayer` of:
   - the live `WindowGroup` window (`RootView` states), or
   - an auxiliary on-screen `NSWindow` hosting a production child view (inspector, dry-run, receipt, settings).
6. **Does not** use `ImageRenderer` (on macOS it draws `List` / `TabView` / `Form` as a yellow prohibition placeholder).
7. **Does not** host a second `RootView` and call `displayIgnoringOpacity` (that hung the runner on List).
8. Exits. Unit tests only assert `VisualQARuntime.isEnabled == false`.

XCTest cannot host AppKit on this runner (signal 5). The catalog therefore runs inside the real app process.

It does **not** click **Move to Trash**. It does **not** call `CleanupExecutor`. It does **not** bypass `CleanupPlan` / TOCTOU.

A 200-second watchdog writes `COMPLETE` if a later shot hangs, so CI can still upload the shots already taken.


---

## What is rendered from the real app

| Shot | How CI tries to capture it | Fixture? |
| --- | --- | --- |
| `01-first-launch` | Live `RootView` window, idle | no |
| `02-scan-progress` | Live `RootView`, `phase = .scanning` | probe labels only |
| `03-overview-autopsy` | Live `RootView` after `ingestScan` (last; watchdog if hang) | coverage + items |
| `04-category-detail` | Live `RootView`, sidebar Developer | items from rules |
| `05-cleanup-candidates` | Live `RootView`, Cleanup + plan footer | items from rules |
| `06-item-inspector` | Production `ItemDetailView` in aux window | Safe item |
| `06b-inspector-in-root` | Live `RootView` with inspector column | Safe item |
| `07-snapshots` | Production `SnapshotView` empty state | empty summary |
| `07b-snapshots-list` | Live `RootView` Snapshots destination | 3 dates, inspect-only |
| `08-empty-no-candidates` | Live `RootView` Cleanup with no plannable items | protected + docker-raw |
| `09-overview-partial` | Live `RootView` with permission-limited paths (last) | partial coverage |
| `10-inspector-protected` | Production `ItemDetailView`, Documents rule | protected |
| `11-inspector-advanced` | Production `ItemDetailView`, `docker-raw` | advanced / sparse |
| `12-dry-run` | Production `DryRunSheet` — **not executed** | selected Safe items |
| `13-receipt` | Production `ReceiptView` (exactly three accounting lines) | constructed receipt |
| `14-cleanup-failure` | Production `ReceiptView` failed/skipped | constructed receipt |
| `15-settings` | Production `SettingsRootView` | none |

Light and dark: `NSApp.appearance` + `.preferredColorScheme`.  
Windows: **1100×720** and **880×560** for `RootView`. Sheets use their native sizes.

If a row is missing from `manifest.json` → `shots`, that screen is **NOT TESTED**, not a PASS. The previous hosted-RootView attempt hung on `04-category-detail`; this revision captures List states from the live window after the child-view checkpoint.

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
- Window-server chrome (traffic lights / titlebar) — shots are `contentView` layers, not `screencapture`
- That every List/autopsy state succeeded — if the runner hangs, the watchdog uploads only the checkpointed shots

If a packaged-app shot is missing, `manifest.json` → `limitations` says so. That is **NOT TESTED**, not a PASS.

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

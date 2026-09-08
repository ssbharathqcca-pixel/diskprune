# Visual QA in CI — supplemental evidence

**Gate 4 is not passed by this workflow.**  
A human still has to look at the screenshots (and, when possible, a real Mac). CI green here means “PNGs were produced from the production UI,” not “the UI is approved.”

**Sidebar (P0, capture bug):** `RootView` implements Overview / Cleanup / Snapshots in a `.sidebar` `List`. `CALayer.render` drops `NSVisualEffectView`, which is why `8696e1d8` showed a blank ~240pt column. Capture recovers the live sidebar via `screencapture -l` from the workflow, then `CGWindowListCreateImage` (`.boundsIgnoreFraming`), else the on-screen `NSTableView` cell images/labels. `cacheDisplay` of the visual-effect view hung `bcc2b49e`.

**Receipt (P0):** copy is “Empty Trash to permanently remove these items from your Mac.” T-TERM-01 and the guardrail ban `reclaim` in `ReceiptView` / `CleanupPlanView`.

**ingestScan hang (P1):** live Overview + Autopsy hatch + Storage sidebar in one update hung the runner. Fixture autopsy/category/cleanup are hosted production views; live ingest is last and switches to Cleanup first.

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
5. Writes PNGs from the live window:
   - `CALayer.render` first, written to disk immediately so a hang later cannot produce 0 PNGs.
   - If the left ~240pt sidebar column has no contrast (NSVisualEffectView is a window-server filter and does not flatten), try `CGWindowListCreateImage` of the on-screen window (real vibrancy). If Screen Recording TCC denies it, composite the live `NSTableView` cell labels at their real frames. That is capture recovery from the production sidebar, not a second UI.
   - Production child views (inspector, dry-run, receipt, settings, autopsy, category, cleanup) are hosted in an auxiliary on-screen `NSWindow` and flattened with `CALayer.render`.
6. **Does not** use `ImageRenderer` (on macOS it draws `List` / `TabView` / `Form` as a yellow prohibition placeholder).
7. **Does not** host a second `RootView` and call `displayIgnoringOpacity` (that hung the runner on List).
8. **Does not** set `canDrawSubviewsIntoLayer` on `NSVisualEffectView` (that hung run [34288655442](https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34288655442) on `bcc2b49e` with 0 PNGs).
9. Exits. Unit tests only assert `VisualQARuntime.isEnabled == false`.

XCTest cannot host AppKit on this runner (signal 5). The catalog therefore runs inside the real app process.

It does **not** click **Move to Trash**. It does **not** call `CleanupExecutor`. It does **not** bypass `CleanupPlan` / TOCTOU.

A 200-second watchdog writes `COMPLETE` if a later shot hangs, so CI can still upload the shots already taken.


---

## What is rendered from the real app

| Shot | Captured on `8696e1d8`? | How | Fixture? |
| --- | --- | --- | --- |
| `01-first-launch` | **yes** live window, light+dark, 1100 and 880 | Live `RootView` idle | no |
| `02-scan-progress` | **yes** live window, light+dark, 1100 and 880 | Live `RootView`, `phase = .scanning` | probe labels only |
| `03-overview-autopsy` | **NO** — live List/autopsy hung; watchdog collected Phase A | would be live `RootView` after `ingestScan` | coverage + items |
| `04-category-detail` | **NO** — same hang | live Developer destination | items from rules |
| `05-cleanup-candidates` | **NO** — same hang | live Cleanup + plan footer | items from rules |
| `06-item-inspector` | **yes** aux window 420×640, light+dark | Production `ItemDetailView` | Safe item |
| `07-snapshots` | **yes** empty state, light+dark, 1100 and 880 | Production `SnapshotView` | empty summary |
| `07b-snapshots-list` | **NO** — hang before dates list | live Snapshots destination | 3 dates |
| `08-empty-no-candidates` | **NO** — hang | live Cleanup, no plannable items | protected + docker-raw |
| `09-overview-partial` | **NO** — hang | live Overview + permission paths | partial coverage |
| `10-inspector-protected` | **yes** aux window, light+dark | Production `ItemDetailView` | Documents rule |
| `11-inspector-advanced` | **yes** aux window, light+dark | Production `ItemDetailView` | `docker-raw` sparse |
| `12-dry-run` | **yes** light+dark | Production `DryRunSheet` — not executed | selected Safe items |
| `13-receipt` | **yes** light+dark, three accounting lines | Production `ReceiptView` | constructed receipt |
| `14-cleanup-failure` | **yes** light+dark | Production `ReceiptView` failed/skipped | constructed receipt |
| `15-settings` | **yes** General pane, light+dark | Production `SettingsRootView` | none |

26 unique PNGs uploaded from run [34284424915](https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34284424915). Phase A (idle/scan + hosted child views) finished in ~20s. Phase B (`ingestScan` into the live `RootView`) hung; the 200s watchdog wrote `COMPLETE` so the artifact could upload.

Light and dark: `NSApp.appearance`. Windows: **1100×720** and **880×560** for live `RootView`. Missing rows are **NOT TESTED**, not a PASS.

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

- Overview / Autopsy with data, category List, Cleanup List, snapshot dates, empty-cleanup, and partial Overview — `ingestScan` into the live window hangs the GitHub-hosted runner (watchdog collects Phase A)
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

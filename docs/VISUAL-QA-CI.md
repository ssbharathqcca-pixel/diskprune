# Visual QA in CI — supplemental evidence

**Gate 4 is not passed by this workflow.**  
A human still has to look at the screenshots (and, when possible, a real Mac). CI green here means “PNGs were produced from the production UI,” not “the UI is approved.”

**Sidebar (P0, capture bug):** `RootView` implements Overview / Cleanup / Snapshots in a `.sidebar` `List`. `CALayer.render` drops `NSVisualEffectView`, which is why `8696e1d8` showed a blank ~240pt column. Capture recovers the live sidebar via `screencapture -l` from the workflow, then `CGWindowListCreateImage` (`.boundsIgnoreFraming`), else the on-screen `NSTableView` cell images/labels. `cacheDisplay` of the visual-effect view hung `bcc2b49e`. On `0c24ff78` the blank-column detector missed a uniform gray sidebar (split divider contrast), so 01/02 stayed `live-window-layer`. The detector now insets past the divider.

**Receipt (P0):** copy is “Empty Trash to permanently remove these items from your Mac.” T-TERM-01 and the guardrail ban `reclaim` in `ReceiptView` / `CleanupPlanView`.

**Post-ingest hang (P1):** `ingestScan` returns (8 items, coverage=true). The next RunLoop spin hung even with destination=Cleanup (`1ecd789b`). `8d4d1d56` stopped same-value `@Published` writeback; Visual QA then showed **exactly 7** `objectWillChange` fires and hang inside `waitForLayout` — not a publish loop. `122a0a47` omitStorage + dest=Cleanup still hung at `autopsy()` because Autopsy stayed mounted. `78b0467a` dest=Cleanup + 0.3s spin **did** unmount Autopsy; ingest then hung on `RootView n=15 dest=cleanup phase=ready coverage=true items=8` with **no further Autopsy probe**. Shape hatch is not the live hang. Remaining split: hosted autopsy-with-data vs live Storage sidebar + ResultsView. Storage sidebar and Autopsy stay in the product. Gate 4 remains NOT PASS.

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
   - Then `screencapture -l` of the live window (01/02 always; others if the left ~240pt column has no interior contrast). If Screen Recording TCC denies it, `CGWindowListCreateImage`, else composite the live `NSTableView` cell labels at their real frames. That is capture recovery from the production sidebar, not a second UI.
   - Production child views (inspector, dry-run, receipt, settings, category, cleanup, snapshots-with-dates, autopsy) are hosted in an auxiliary on-screen `NSWindow`. Most flatten with `CALayer.render`. Autopsy prefers `screencapture -l` of that aux window.
6. **Does not** use `ImageRenderer` (on macOS it draws `List` / `TabView` / `Form` as a yellow prohibition placeholder).
7. **Does not** host a second `RootView` and call `displayIgnoringOpacity` (that hung the runner on List).
8. **Does not** set `canDrawSubviewsIntoLayer` on `NSVisualEffectView` (that hung run [34288655442](https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34288655442) on `bcc2b49e` with 0 PNGs).
9. Exits. Unit tests only assert `VisualQARuntime.isEnabled == false`.

XCTest cannot host AppKit on this runner (signal 5). The catalog therefore runs inside the real app process.

It does **not** click **Move to Trash**. It does **not** call `CleanupExecutor`. It does **not** bypass `CleanupPlan` / TOCTOU.

A 200-second watchdog writes `COMPLETE` if a later shot hangs, so CI can still upload the shots already taken.

---

## Latest inspected artifacts

### `78b0467a` run 26 — [34300724103](https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34300724103)

Artifact: [visual-qa-78b0467ab73cc463267f2462ddb1529da1ae7dec](https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34300724103/artifacts/10084961008)

**Isolation result.** Shape hatch did **not** fix the live hang. dest=Cleanup + 0.3s spin unmounted Autopsy (`RootView n=14 dest=cleanup`; `StorageAutopsyView n=19 phase=idle coverage=false`). ingest complete (8 items, coverage=true, publishes=6). Last line: `RootView n=15 dest=cleanup phase=ready coverage=true items=8`. No Autopsy probe after ingest. iso-hatch laid out (blank skip). iso-autopsy-idle captured. 03/09/`05c-live-cleanup` remain **NOT TESTED**. Canvas-hatch-in-Autopsy is **not** the live hang when Autopsy is unmounted. Remaining split: hosted autopsy-with-data vs live Storage sidebar + ResultsView after ingest.

### `122a0a47` run 25 — [34299516814](https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34299516814)

Artifact: [visual-qa-122a0a47ad9f7489ca765e1518c8d10c85dbb763](https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34299516814/artifacts/10084532651)

**Isolation result.** omitStorage=true dest=Cleanup ingest still hung (~5 min watchdog). ingest complete, publishes=7, RootView stayed at probe 13, then `post-ingest-spin begin` → `StorageAutopsyView n=19 phase=ready coverage=true`. Autopsy stayed mounted (`@ObservedObject`) and `autopsy()` ran on the ingest publishes before RootView could swap to ResultsView. Isolated Canvas hatch laid out (blank PNG skip). Idle Autopsy captured. Storage-section-insert hypothesis **disproven**. Remaining candidate: Canvas `HatchSegment` as a `SegmentStack` child inside Autopsy `ScrollView` (fixture notExamined ≈ 76% of the bar). This commit replaces that Canvas with a `Shape` overlay. 03/09 remain **NOT TESTED**.

### `8b44f0b5` run 24 — [34298560795](https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34298560795)

Artifact: [visual-qa-8b44f0b547140c25b4d1b9d1bf5c1f5b0f620d9f](https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34298560795/artifacts/10084204239)

**Isolation result.** HatchSegment laid out (`iso-hatch` skipped as blank PNG). Hosted idle Autopsy captured. dest=Cleanup before ingest: 7 publishes, then hang at `waitForLayout begin` for live 05c. No further RootView probe. `DONE` = `checkpoint-before-autopsy`. Publish-loop and Autopsy-first-tree hypotheses **disproven**. Remaining candidate: live `SwiftUIOutlineListView` inserting Storage rows.

### `30873fdd` run 18 — [34292824436](https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34292824436)

Artifact: [visual-qa-30873fdd1a75df23e7029b5fa2c645bb0a179e5f](https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34292824436/artifacts/10082155083) (50 files; 8 are leftover `.ws.png`)

**01/02 recovered.** `screencapture -l` of the live window produced real sidebar chrome: Overview / Cleanup / Snapshots, Search field, Scan toolbar, traffic lights. Source `live-window-screencapture`. That is the production `RootView`, not a mock.

**03/09 still hung.** Hosted `StorageAutopsyView` died at `NSHostingView.contentView =` after `hosting constructed` (overlay `GeometryReader` was not enough). `DONE` = `checkpoint-before-autopsy`. 42 catalog PNGs + 8 `.ws.png`.

### `0c24ff78` run 17 — [34291508834](https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34291508834)

Artifact: [visual-qa-0c24ff7825a25237a6ee49f86a3a0940c68fbb4a](https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34291508834/artifacts/10081671973)  
42 PNGs. Dark 04/05/07b/08 present. 01/02 still `live-window-layer` (blank sidebar). Hung on hosted autopsy.

| Shot | On `30873fdd`? | How | Fixture? |
| --- | --- | --- | --- |
| `01-first-launch` | **yes** live window + chrome, light+dark, 1100 and 880 | Live `RootView` idle, `screencapture -l` | no |
| `02-scan-progress` | **yes** live window + chrome, light+dark, 1100 and 880 | Live `RootView`, `phase = .scanning` | probe labels only |
| `03-overview-autopsy` | **NO** — hosted view hung at contentView assignment | live `RootView` after `ingestScan` (this commit) | coverage + items |
| `04-category-detail` | **yes** light+dark, 1100 and 880 | Hosted `ResultsView` Developer | items from rules |
| `05-cleanup-candidates` | **yes** light+dark, 1100 and 880 | Hosted `ResultsView` Cleanup + Review Cleanup footer | items from rules |
| `06-item-inspector` | **yes** aux window 420×640, light+dark | Production `ItemDetailView` | Safe item |
| `07-snapshots` | **yes** empty state, light+dark, 1100 and 880 | Production `SnapshotView` | empty summary |
| `07b-snapshots-list` | **yes** light+dark, 1100 and 880 | Hosted `SnapshotView` with 3 dates + inspect-only copy | 3 dates |
| `08-empty-no-candidates` | **yes** light+dark, 1100 and 880 | Hosted Cleanup, Protected/Advanced only | protected + docker-raw |
| `09-overview-partial` | **NO** — never reached | live Overview + permission paths (this commit) | partial coverage |
| `10-inspector-protected` | **yes** aux window, light+dark | Production `ItemDetailView` | Documents rule |
| `11-inspector-advanced` | **yes** aux window, light+dark | Production `ItemDetailView` | `docker-raw` sparse |
| `12-dry-run` | **yes** light+dark | Production `DryRunSheet` — not executed | selected Safe items |
| `13-receipt` | **yes** light+dark, three accounting lines | Production `ReceiptView` | constructed receipt |
| `14-cleanup-failure` | **yes** light+dark | Production `ReceiptView` failed/skipped | constructed receipt |
| `15-settings` | **yes** General pane, light+dark | Production `SettingsRootView` (tab chrome incomplete in 520×360 pane) | none |

Inspected 04/05/07b/08 dark 1100 shots are production UI (Developer list, Cleanup checkboxes, snapshot dates, empty Protected/Advanced state). Receipt is three accounting lines + “Empty Trash to permanently remove these items from your Mac.” Missing rows are **NOT TESTED**, not a PASS.

CI jobs 1–5 on `30873fdd`: GREEN. Build macOS App: GREEN. Visual QA workflow: SUCCESS (watchdog collected shots).

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

- Overview / Autopsy with data (`03`, `09`) — **NOT TESTED.** `78b0467a` unmounted Autopsy then hung on live RootView after ingest (`dest=cleanup phase=ready coverage=true items=8`). Hosted autopsy-with-data was not reached. Catalog now dest=Cleanup omitStorage ingest first, then re-enables Storage, then hosted autopsy. Product Storage and Autopsy stay.
- Settings tab chrome in the hosted 520×360 pane
- Window-server chrome (traffic lights / titlebar) on contentView layer shots
- Canvas composition fidelity (Claude artifact login)
- True device Light/Dark as a logged-in user, vs forced `NSAppearance`
- Full Disk Access / TCC permission UI (CI cannot grant FDA)
- Reduce Motion / Reduce Transparency / VoiceOver / Dynamic Type
- Gatekeeper “right-click Open” on a customer Mac
- Liquid Glass vs macOS 14 floor on a physical display

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

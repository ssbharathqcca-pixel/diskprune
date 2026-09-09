# Visual QA in CI — supplemental evidence

**Gate 4 PASS** was recorded after human review of the `2241cbe5` artifact (see [`IMPLEMENTATION_STATUS.md`](IMPLEMENTATION_STATUS.md)).  
The harness still writes `"gate4": "NOT PASS"` into `manifest.json` so CI cannot self-certify. That field is not the verdict.

**Sidebar (P0, capture):** `RootView` implements Overview / Cleanup / Snapshots in a `.sidebar` `List`. `CALayer.render` drops `NSVisualEffectView`. Live shots recover the sidebar via `screencapture -l`.

**Receipt (P0):** three accounting lines. Copy is “Empty Trash to permanently remove these items from your Mac.” T-TERM-01 and the guardrail ban `reclaim` in `ReceiptView` / `CleanupPlanView`.

**Post-ingest hang (P1 — RESOLVED on `907e103e`):** `AutopsyModel.init` did `classifiedBytes * w / weightTotal` in `Int64`. Realistic byte values overflowed before division and trapped the process. Fix: `Int64(Double(classifiedBytes) * (Double(w) / Double(weightTotal)))`. Live `05c` / `03` / `09` now complete without watchdog.

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
5. Writes PNGs from the live window (`CALayer.render` then `screencapture -l`) and hosts production child views in an auxiliary `NSWindow`.
6. Does **not** use `ImageRenderer`. Does **not** click **Move to Trash**. Does **not** call `CleanupExecutor`. Does **not** bypass `CleanupPlan` / TOCTOU.

---

## Latest inspected artifacts

### `2241cbe5` run 33 — [34305189018](https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34305189018) — **Gate 4 review**

Artifact: [visual-qa-2241cbe5f9107cb383b008c6975bf461eddc16df](https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34305189018/artifacts/10086420999)

`DONE=ok`, `COMPLETE=ok`, 50 catalog shots, no watchdog. Capture step ~42s.

Reviewed against [`DESIGN-GUIDE.md`](DESIGN-GUIDE.md):

| Shot | Result |
| --- | --- |
| `03-overview-autopsy` live light/dark, 1100 and 880 | Production Autopsy with fixture coverage (420 GB used / 80 GB available / 80 GB explained / hatched not-examined). Two cards. Storage sidebar present. |
| `05c-live-cleanup` live 1100 light | Production `RootView` after `ingestScan`. Storage section (Developer / Caches / Logs / App data / Other classified). Cleanup selected. Protected/Advanced have no checkbox. |
| `09-overview-partial` live light/dark 1100 | Inline permission banner, “at least” prefixes, denied Mail/Messages. |
| `01` / `02` live | First launch (no Storage section) and scan progress. Real chrome. |
| `04` / `05` / `06` / `10` / `11` hosted production views | Category, cleanup list, inspector Safe/Protected/Advanced. |
| `07` / `07b` | Empty snapshots + dated list. No delete. |
| `08` | “No reclaimable data found.” Protected/Advanced only. |
| `12` dry run | “Nothing has changed yet.” Move to Trash not red. |
| `13` / `14` receipt | Exactly three accounting lines. No freed/reclaimed/recovered for trashed bytes. |
| `15` settings | General pane; Confirm before Trash locked on. Tab chrome incomplete in 520×360 hosted pane (source `TabView` still has General / Licence / Advanced). |

No yellow prohibition placeholders. No fake/QA-only duplicate UI. Isolation leftover `iso-autopsy-idle` is diagnostic, not a substitute for `03`.

### `2cea2c21` run 32 — [34304950948](https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34304950948)

First successful post-fix catalog (same product as `907e103e`). Hang gone.

### `78b0467a` run 26 — pre-fix isolation (hang still present)

Historical. Do not use for Gate 4.

---

## What uses deterministic fixtures

Catalog `StorageItem`s, `StorageCoverage`, scan-progress labels, and constructed receipts go through existing models and `ingestScan`. Not a parallel UI or cleanup pipeline.

---

## What cannot be verified in CI

- Settings tab chrome in the hosted 520×360 pane (source has `TabView`; the pane crop hides tabs)
- True device Light/Dark as a logged-in user
- Full Disk Access / TCC permission UI (CI cannot grant FDA)
- Gatekeeper “right-click Open” on a customer Mac
- Canvas artboard pixel match
- Stranger comprehension test

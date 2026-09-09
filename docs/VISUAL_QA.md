# Visual QA protocol — Phase 3

**Status:** Gate 4 **PASS** on `2241cbe5` after human review of the CI live-window artifact.  
CI `manifest.json` still writes `"gate4": "NOT PASS"` so the workflow cannot self-certify. The verdict lives in [`IMPLEMENTATION_STATUS.md`](IMPLEMENTATION_STATUS.md).

Reviewed artifact: https://github.com/ssbharathqcca-pixel/diskprune/actions/runs/34305189018/artifacts/10086420999


Authoritative documents:

- Implementation: [`DESIGN-GUIDE.md`](DESIGN-GUIDE.md)
- Composition: visual canvas (may require Claude login)  
  https://claude.ai/code/artifact/c64ba9c1-07be-4653-9199-e463c64a0a54
- Safety: [`CLEANUP_SAFETY.md`](CLEANUP_SAFETY.md)

Build under test: **`main` HEAD** (see About → version / `CFBundleVersion` = git SHA).

---

## Supplemental CI screenshots

Download artifact `visual-qa-<sha>` from  
https://github.com/ssbharathqcca-pixel/diskprune/actions/workflows/visual-qa.yml

Use them to walk this checklist when you do not have a Mac. `manifest.json` always records Gate 4 as NOT PASS.

---

## Get the Mac build


1. Open the latest successful **Build macOS App** run:  
   https://github.com/ssbharathqcca-pixel/diskprune/actions/workflows/build-mac.yml
2. Confirm the commit SHA matches `main`.
3. Download the artifact named `DiskPrune-<sha>`.
4. Unzip it. You get `DiskPrune.dmg`.

The DMG is **ad-hoc signed, arm64 or runner-arch, not notarized.** That is expected until Phase 6.

### Open on a Mac (Gatekeeper)

1. Double-click the DMG.
2. Drag DiskPrune to a writable folder (Desktop is fine). **Do not run from the DMG window if macOS refuses.**
3. Right-click DiskPrune.app → **Open** → Open.  
   System Settings → Privacy & Security may also offer “Open Anyway”.
4. Confirm **About DiskPrune** shows version `1.0.0` and the matching SHA.

Minimum OS: **macOS 14**. Floor UI must look finished without Liquid Glass.

---

## What this build will and will not do

| Will | Will not |
| --- | --- |
| Scan this Mac’s real caches / Xcode / logs | Invent demo storage numbers |
| Move **only** items you confirm, to Trash | Empty Trash |
| Show snapshots as a list | Delete snapshots or print a delete command |
| Load `/shared` storage-rules from the app bundle | Activate a licence (Phase 5) |

Cleanup (dry run → Move to Trash) **really moves files**. Prefer a throwaway account, or only tick tiny **Safe** items you can restore from Trash. First launch, scan, overview, snapshots, and settings can be reviewed without moving anything.

---

## How to produce each required screen

| # | Screen | How |
| --- | --- | --- |
| 1 | Overview / Autopsy | After a scan, sidebar **Overview** (⌘1) |
| 2 | Scan progress | Toolbar **Scan** (⌘R). Watch determinate bar and probe names. Cancel is optional. |
| 3 | Category detail | After scan, a nested **Storage** row in the sidebar |
| 4 | Cleanup candidates | Sidebar **Cleanup** (⌘2) |
| 5 | Item inspector | Select a row, ⌘⌥I, or the info button |
| 6 | Cleanup Plan | Footer on Cleanup: selection count + estimated recoverable |
| 7 | Dry Run | **Review Cleanup** on the footer. Read “Nothing has changed yet.” |
| 8 | Receipt | Confirm **Move to Trash** on a tiny Safe item, or skip if you will not move files — mark as **not exercised** |
| 9 | Snapshots | Sidebar **Snapshots** (⌘3). There must be **no** delete control |
| 10 | Settings | DiskPrune → Settings… (⌘,). Tabs: General, Licence, Advanced |
| 11 | First launch | Quit, reopen, do **not** enable Scan on launch. Empty autopsy + Scan |
| 12 | Permission / partial | If FDA is off, scan anyway. Banner must be **inline**, never a launch modal |
| 13 | Light mode | System Settings → Appearance → Light |
| 14 | Dark mode | Appearance → Dark. Cards lose the light-mode shadow |
| 15 | 880 × 560 | Window → no hamburger, no card reflow. Sidebar may hide via system toggle |
| 16 | 1100 × 720 | Default size on first open |

---

## Visual evaluation (must remain native)

For every screen above, check:

- Native macOS appearance (not a web/SaaS dashboard)
- Typography: semantic styles; **one** `.largeTitle` (capacity figure); byte figures monospaced
- Spacing on a 4pt grid (Design Guide PART 8)
- Hierarchy without extra chrome
- Sidebar: three destinations only (Overview, Cleanup, Snapshots); icons **neutral**, not accent-tinted
- Toolbar: Scan is an **action**, not a sidebar item
- Materials: glass on chrome only, never on dense lists; Reduce Transparency still readable
- **Card restraint:** at most **two** card-like containers per screen (capacity + insight on Overview; dry-run summary; receipt accounting; empty/error blocks)
- Colour: safety taxonomy (Protected is **grey**, not red); category ramp desaturated; not-examined is an **unfilled hatch**
- SF Symbols only
- Dark mode designed, not inverted
- Narrow window uses `NavigationSplitView`, not a hamburger
- Matches [`DESIGN-GUIDE.md`](DESIGN-GUIDE.md)
- Composition vs canvas (if the reviewer can open it)
- **Stranger test:** can someone who did not write this app explain why the Mac is full from Overview alone?

### Hard fails

- Protected or Advanced row shows a checkbox
- Receipt says freed / reclaimed / recovered for trashed bytes
- Receipt shows four accounting rows or `volumeAvailableBefore` / `After`
- Snapshots has a delete / swipe-to-delete / “run tmutil” control
- Launch modal for Full Disk Access
- Settings as a sidebar row
- Scan as a sidebar destination
- More than two cards on one screen
- Accent-tinted sidebar icons

---

## Report format (reviewer)

For each of the 16 items: **PASS / FAIL / NOT EXERCISED**, one sentence why.

Then:

- Greyscale / colour-independence (P7): PASS / FAIL / NOT EXERCISED
- Stranger test: PASS / FAIL
- Canvas fidelity: PASS / FAIL / CANVAS UNREACHABLE
- Gate 4 recommendation: **PASS** only if visual inspection on a Mac completed and no hard fail remains

Do not convert “looks probably fine from CI” into PASS.

---

## Still NOT TESTED (until a human finishes this protocol)

- Light / dark / 880×560 / 1100×720 on a real display
- Canvas composition fidelity
- Stranger comprehension test
- Full Disk Access / partial-scan banner on a locked-down Mac
- Dry run + receipt, if the reviewer declines to move any file
- Reduce Motion / Reduce Transparency / VoiceOver / Dynamic Type `.accessibility3`
- Gatekeeper path on a Mac that is not the Actions runner
- Universal / Developer ID / notarized build (Phase 6)

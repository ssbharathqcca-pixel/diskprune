# DISKPRUNE — DESIGN GUIDE
### Version 1.0 · Phase 3 UI/UX Implementation Authority

**Status:** Authoritative. **This document overrides all previous UI/UX guidance.**
**Companion — visual canvas:** https://claude.ai/code/artifact/c64ba9c1-07be-4653-9199-e463c64a0a54
The canvas is the *visual review authority* (24 artboards, 5 pages: Foundations · Core flow · Cleanup flow · Dark mode · States & windows). This document is the *implementation authority*. Where they disagree, this document wins on behaviour and values; the canvas wins on composition.
**Architecture constraints:** `docs/BUILDER-HANDOFF.md` PARTS 5–7 and 23. Nothing here may violate them.

> **Grok: read PART 20 (GROK IMPLEMENTATION CONTRACT) before writing a single view.** Where this document gives a rule, follow it exactly. Where it does not, ask — do not exercise subjective visual judgment.

---

## PART 0 — SOURCES AND LIMITS OF THIS DOCUMENT

Stated so no one mistakes inference for verification:

| Source | Status |
|---|---|
| Written art direction in the design brief | **Primary.** Followed throughout. |
| `docs/BUILDER-HANDOFF.md` (approved architecture) | **Primary.** Every screen cross-checked against it (PART 19). |
| macOS platform conventions | Applied from established practice plus current search-verified guidance. **`developer.apple.com` HIG pages could not be fetched in the authoring environment** — they render client-side and return only page titles. Every convention asserted here is either verifiable in Apple's own shipping apps or was confirmed by secondary sources, and is marked where it is a judgment call. |
| macOS 26 Tahoe sidebar/material behaviour | Search-verified. See PART 5.4. |
| Visual reference images | **Not received.** No images were attached to the authoring session. Direction was taken from the written brief. **If reference images exist, this guide should be re-reviewed against them.** |
| Sona UI interaction quality | **sonaui.com was blocked by the authoring environment's egress proxy.** Its published principles — purposeful animation, sensible easing, spring physics, `prefers-reduced-motion` support — were translated into PART 7. No visual language was copied, and no first-hand component review is claimed. |

---

## PART 1 — DESIGN VISION

DiskPrune is a **storage-intelligence instrument**, not a cleaner. The interface's job is to make a filesystem legible, then let the user act on that understanding — in that order, visibly.

**The one-sentence test for every screen:** *does this help the user answer "why is my Mac full?"* If not, it does not belong in v1.

**Experience order — never invert it:**

```
UNDERSTAND  →  INVESTIGATE  →  REVIEW  →  CLEAN SAFELY
```

Not `SCAN → BIG NUMBER → CLEAN EVERYTHING`. The big number is a *consequence* of understanding, never the headline.

**The two emotional beats, in order:**
1. "I finally understand what is using my Mac's storage."
2. "I trust this app enough to let it help me clean it."

Beat 2 is unreachable without beat 1. Every design decision that trades comprehension for speed-to-cleanup is wrong.

---

## PART 2 — DESIGN PRINCIPLES

**P1 — Restraint (the governing rule).**
> If removing a visual effect, gradient, shadow, border, animation, or decorative element does not reduce comprehension, hierarchy, feedback, or usability, **remove it.**

Applied literally. When in doubt, delete it and look again.

**P2 — Premium comes from structure, not surface.** Hierarchy, typography, spacing, alignment, material, interaction quality, information architecture. Never from effects. **The interface must still look premium with every semantic colour removed** — test this (PART 18).

**P3 — Minimal visual noise, not minimal information.** DiskPrune is a technical utility. It will show many rows, paths, sizes, and explanations. Do not make it artificially sparse to look minimal. Use progressive disclosure to *stage* information, never to hide useful information.

**P4 — Trust is rendered, not assumed.** The UI must show why an item appears, why it carries its safety level, what will happen, where it goes, what is reversible, what DiskPrune cannot do, and **what DiskPrune does not know**. Admitted ignorance is a feature.

**P5 — Never fake certainty.** No estimated figure presented as measured. No "not examined" region coloured as though it were understood. No implication that Trash movement frees space.

**P6 — Native by default.** Every control is a system control unless this document says otherwise. A custom control must justify its existence in a comment naming the system control it replaces and why.

**P7 — Colour is never the sole carrier of meaning.** Every state carries symbol + label + colour.

---

## PART 3 — WHAT DISKPRUNE MUST NOT LOOK LIKE

| Forbidden | Why |
|---|---|
| Web/SaaS dashboard | Tiles-everywhere, floating nav, giant coloured CTAs |
| **A collection of rounded cards** | See PART 3.1 — this is the most likely failure |
| Rainbow storage charts | Category colour must be restrained and equal-weight |
| Tinted sidebar icons | Violates macOS 26 behaviour (PART 5.4) |
| Decorative gradients, blobs, glows | P1 |
| Liquid Glass showcase | Glass is a material, not an identity |
| Hero sections, marketing copy in-app | This is a utility |
| Mobile/hamburger navigation | PART 12.4 |
| Custom-drawn versions of system controls | P6 |

### 3.1 The card rule — HARD

Cards are permitted **only** where a bounded region represents a genuinely distinct piece of information or a distinct action, and where a list, section, separator, or plain whitespace cannot express it.

**Permitted card uses in v1 — this is the complete list:**
1. The Overview capacity summary (one card, top of Overview).
2. The Overview insight statement (one card, directly below).
3. The Dry-Run summary block inside its sheet.
4. The Receipt accounting block.
5. Permission / error / empty-state blocks.

**Everything else is a list row, a grouped section, a table, or plain text on the window background.** Category breakdowns, cleanup candidates, snapshots, item details, settings — **none of these are cards.**

If a screen has more than two card-like containers visible at once, it is wrong.

---

## PART 4 — APPLE PLATFORM INTERPRETATION

| Area | Decision |
|---|---|
| Window | `NavigationSplitView` (sidebar + detail). Unified toolbar. |
| Sidebar | `List` with `.sidebar` style. Icons neutral (PART 5.4). |
| Toolbar | `.toolbar` with `ToolbarItem`. Primary action `Scan` on the trailing side. |
| Settings | **`Settings` scene + `TabView`.** Verified convention: macOS settings windows use centred tabs with icon **and** label, and the `.preference` toolbar style — **never** sidebar navigation, never a custom settings page. |
| About | Standard `NSApplication.orderFrontStandardAboutPanel`. Do not build a custom About window. |
| Destructive confirm | `.sheet` — not an alert. The dry run carries too much content for an alert. |
| Explanations | `.popover` for short "why?"; inspector column for sustained detail. |
| Lists | `List` with `.inset` style in detail panes. |
| Search | `.searchable` — filters the active pane only. |
| Progress | Determinate `ProgressView(value:)`. **Indeterminate spinners are forbidden as a primary scan indicator.** |

---

## PART 5 — COLOUR SYSTEM

> **Canvas:** artboard `Main` (Foundations) renders every value in this part — surfaces, safety taxonomy, the category ramp, and the not-examined hatch.

### 5.1 Rule of construction

**Use a system semantic colour wherever one exists.** This buys automatic light/dark, Increase Contrast, and Reduce Transparency for free. Define a literal value only where the system has no equivalent — which in v1 means the safety taxonomy and the category ramp, and nothing else.

### 5.2 Foundation — all system, no literals

| Token | SwiftUI / AppKit | Use |
|---|---|---|
| `surface.window` | `Color(nsColor: .windowBackgroundColor)` | Window background |
| `surface.content` | `Color(nsColor: .controlBackgroundColor)` | Detail pane, list backgrounds |
| `surface.raised` | `.regularMaterial` | Cards, sheets (PART 6) |
| `surface.sidebar` | `.bar` material / `.sidebar` list style | Sidebar |
| `text.primary` | `Color.primary` | Titles, values |
| `text.secondary` | `Color.secondary` | Subtitles, metadata |
| `text.tertiary` | `Color(nsColor: .tertiaryLabelColor)` | Timestamps, counts |
| `separator` | `Color(nsColor: .separatorColor)` | Dividers |
| `separator.strong` | `Color(nsColor: .gridColor)` | Table rules |
| `accent` | `Color.accentColor` | Selection, primary action, focus |
| `selection` | `Color(nsColor: .selectedContentBackgroundColor)` | Selected rows |

**No hex literal appears anywhere in this table by design.** Grok must not substitute one.

### 5.3 Safety taxonomy — the only custom semantic colours

Each state is **symbol + label + colour**. Colour alone is never sufficient (P7).

| State | SF Symbol | Colour | Label | Rationale |
|---|---|---|---|---|
| **Safe** | `checkmark.seal.fill` | `Color.green` | `Safe` | Filled = definitive |
| **Review** | `exclamationmark.circle` *(outline)* | `Color.orange` | `Review` | Outline weight lowers alarm. This asks for judgment, not fear. |
| **Advanced** | `wrench.and.screwdriver.fill` | `Color.secondary` | `Advanced` | Inspect-only in v1 |
| **Protected** | `lock.fill` | **`Color.secondary` — NOT red** | `Protected` | Protected is off-limits, not dangerous. Red here is theatrical and erodes the meaning of red. |

**Red (`Color.red`) is reserved exclusively for:** permission denied · cleanup failure · revoked licence · genuine error. **Nothing routine is ever red.** A `Protected` item rendered in red is a review failure.

### 5.4 Sidebar icons — macOS 26 behaviour

**Sidebar icons render neutral: black in light mode, white in dark mode. Never the accent colour.**

In macOS 26 the sidebar is a translucent material floating over content; accent-tinted icons clash with whatever passes beneath. Apple changed the platform default accordingly. Grok's reflex will be `.foregroundStyle(.tint)` — **do not.**

```swift
Label("Overview", systemImage: "chart.pie")
    .foregroundStyle(.primary)   // NOT .tint, NOT .accentColor
```

Selection is communicated by the row's selection background, not by icon tint.

### 5.5 Category ramp — restrained, six maximum

Storage categories need distinguishability without becoming a rainbow. Use **desaturated, approximately equal-luminance** hues so no category shouts louder than another.

| Category | Light | Dark | Notes |
|---|---|---|---|
| Developer | `#5B7C99` | `#7B9CB9` | |
| Caches | `#7A8B7F` | `#94A899` | |
| Logs | `#8B8298` | `#A69CB3` | |
| Application data | `#99835B` | `#B9A37B` | |
| Other classified | `#8A8A8E` | `#9E9EA3` | |
| **Not examined** | **no fill** | **no fill** | **See 5.6 — this is not a category** |

Maximum six segments. Beyond five real categories, aggregate the tail into *Other classified*.

### 5.6 "Not examined" — a required visual distinction

`StorageCoverage.notExaminedBytes` is **absence of knowledge, not a category.** Rendering it as a coloured segment would claim understanding DiskPrune does not have.

**Specification:** render as an **unfilled segment** — `separator`-coloured 1pt stroke, no fill, with a 45° hatch at 20% `tertiaryLabelColor`, 4pt pitch. It reads as "not measured" at a glance and is distinguishable without colour.

`permissionLimitedBytes` is **always `nil`** and **must never be drawn**. Permission-limited regions are communicated by the partial-scan banner and the denied-path list, never as an estimated area.

---

## PART 6 — MATERIALS AND LIQUID GLASS

### 6.1 The rule

**macOS 14 is the floor. The design must be complete and premium with no glass at all.** Liquid Glass is progressive enhancement on chrome only.

| Surface | macOS 14–25 (baseline) | macOS 26+ (enhancement) |
|---|---|---|
| Sidebar | `.bar` material via `.sidebar` list style | System glass (automatic with native controls) |
| Toolbar | System unified toolbar | System glass (automatic) |
| Sheets | `.regularMaterial` | System glass (automatic) |
| Overview cards | `.regularMaterial` | `.regularMaterial` — **unchanged** |
| **All data content** | **Opaque `controlBackgroundColor`** | **Opaque — never glass** |

### 6.2 Prohibitions

- **Never apply glass to dense data content.** Lists, tables, item details, receipts, category rows. Translucent backgrounds behind small text are the documented legibility failure of this material.
- **Never stack glass on glass.** Layers become muddy.
- **Never use glass as a substitute for hierarchy.**
- **Never let the design depend on glass to look finished.**

### 6.3 Implementation

Because native controls adopt glass automatically on macOS 26, the correct approach is almost always **to use the native control and add nothing.** Explicit `.glassEffect()` requires justification.

```swift
// Correct: native control, glass arrives automatically on 26+, material on 14+.
List { … }.listStyle(.sidebar)

// Only where an explicitly glassy custom chrome surface is required:
if #available(macOS 26.0, *) {
    content.glassEffect()
} else {
    content.background(.regularMaterial)
}
```

Reduce Transparency must be honoured: when `NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency` is true, every material resolves to an opaque `windowBackgroundColor` / `controlBackgroundColor`.

---

## PART 7 — TYPOGRAPHY

> **Canvas:** artboard `Main`, type-scale section.

SF Pro via **semantic text styles only** — this is what makes Dynamic Type work. Never hard-code a point size for body text.

| Role | Style | Weight | Use |
|---|---|---|---|
| Capacity figure | `.largeTitle` | `.semibold` | The one large number on Overview |
| Screen title | `.title2` | `.semibold` | Pane titles |
| Section header | `.headline` | `.semibold` | Group headers |
| Row title | `.body` | `.regular` | Item and category names |
| Row value | `.body` | `.medium` + **`.monospacedDigit()`** | All byte figures |
| Secondary | `.callout` | `.regular` | Explanations, subtitles |
| Metadata | `.caption` | `.regular` | Paths, counts, timestamps |
| Path | `.caption` | `.regular` + `.monospaced()` | Filesystem paths only |
| Badge | `.caption2` | `.medium` | Safety labels |

**Two mandatory rules:**

1. **Every byte figure uses `.monospacedDigit()`.** Values update live during a scan; proportional digits shift width and the column jitters. This is not cosmetic.
2. **The capacity figure is the only `.largeTitle` in the application.** Storage numbers must be confident, not billboard-sized. If a second `.largeTitle` appears, one of them is wrong.

Paths use `.truncationMode(.middle)` — the meaningful parts of a path are its start and end.

---

## PART 8 — SPACING, GEOMETRY, GRID

Base unit **4pt**. Every dimension is a multiple.

| Token | Value |
|---|---|
| `space.xs` / `sm` / `md` / `lg` / `xl` / `xxl` | 4 / 8 / 12 / 16 / 24 / 32 |
| `sidebar.width` | 240 (min 200, max 320) |
| `toolbar.height` | 52 (system) |
| `window.default` | 1100 × 720 |
| `window.min` | 880 × 560 |
| `content.margin` | 20 |
| `content.maxWidth` (reading columns) | 820 |
| `row.compact` | 28 |
| `row.standard` | 36 |
| `row.candidate` | 44 |
| `row.category` (title + subtitle) | 64 |
| `card.padding` | 16 |
| `section.spacing` | 24 |
| `radius.control` / `card` / `sheet` | 6 / 10 / 12 |
| `border.hairline` | 1 (`separatorColor`) |
| `icon.sidebar` / `row` / `badge` / `state` | 16 / 16 / 12 / 32 |
| `control.height` | 28 (regular), 22 (small) |
| `capacityBar.height` | 12 (Overview), 6 (inline) |
| `hitTarget.min` | 28 × 28 |

**Shadows:** one only — cards use `.shadow(color: .black.opacity(0.06), radius: 3, y: 1)` in light mode and **no shadow in dark mode** (elevation reads through surface lightness instead). No other shadow exists in the application.

---

## PART 9 — ICONOGRAPHY

**SF Symbols only.** No third-party icon sets, no custom glyphs except the app icon.

| Context | Symbol |
|---|---|
| Overview | `chart.pie` |
| Cleanup | `tray.and.arrow.down` |
| Snapshots | `clock.arrow.circlepath` |
| Scan action | `magnifyingglass` |
| Developer | `hammer` |
| Caches | `shippingbox` |
| Logs | `doc.text` |
| Application data | `app.badge` |
| Unclassified | `questionmark.folder` |
| Reveal in Finder | `folder` |
| Explain | `info.circle` |
| Trash | `trash` |
| Permission | `lock.shield` |
| Partial scan | `exclamationmark.triangle` |

Rendering: `.hierarchical` by default; `.palette` only for the safety badges. Weight `.regular`, matching adjacent text. Every icon that conveys meaning has an `accessibilityLabel`; purely decorative icons are `.accessibilityHidden(true)`.

---

## PART 10 — MOTION

| Token | Duration | Curve | Use |
|---|---|---|---|
| `motion.micro` | 0.12s | `.easeOut` | Hover, press |
| `motion.standard` | 0.25s | `.easeOut` | Pane changes, appearance |
| `motion.disclosure` | 0.35s | `.spring(response: 0.35, dampingFraction: 0.86)` | Expand/collapse |
| `motion.progress` | continuous | `.linear` | Determinate progress only |

**What animates:** disclosure expansion, selection background, pane transitions, progress fill, sheet presentation, badge count changes.

**What never animates:** byte values (they update instantly — `.monospacedDigit()` prevents jitter), the capacity bar during a scan (segments grow, they do not spring), row content, list scrolling.

**Reduced Motion** (`accessibilityReduceMotion`): every transition becomes a 0.15s opacity crossfade. No springs, no movement, no scaling. Progress bars still fill — that is information, not decoration.

**Forbidden:** bouncing, parallax, particles, attention-seeking loops, anything that animates purely to be noticed.

---

## PART 11 — COMPONENT LIBRARY

> **Canvas:** artboard `Components` renders every state below. A state absent from that artboard does not exist.

Every component below specifies anatomy, dimensions, and all states. States not listed do not exist.

### 11.1 SidebarItem
Anatomy: `[16pt symbol] [label] [spacer] [value or badge]`. Height 28. Inset 8. Radius 6.
States — default: `.primary` label, neutral icon, clear background · hover: `quaternaryLabelColor` background, 0.12s · **selected**: `selectedContentBackgroundColor`, label and icon remain neutral · focused: system focus ring · disabled: `.opacity(0.4)`.
Accessibility: `.accessibilityLabel("\(name), \(value)")`. Keyboard: ↑↓ moves, ⌘1–3 jumps.

### 11.2 CapacityBar
Anatomy: horizontal segmented bar, height 12, radius 6, segments in `StorageCoverage` order, 1pt gap.
Segments: category ramp (5.5) then **not-examined as unfilled hatch (5.6)**.
States — loading: single `quaternaryLabelColor` track · scanning: segments grow as `ScanEvent.coverage` arrives, no animation on width · complete: final · hover: segment lifts to full opacity, others to 0.6, tooltip shows category and size.
Accessibility: `.accessibilityElement(children: .ignore)` with a value string enumerating every segment including not-examined.
**Forbidden:** gradients, rounded internal segments, animated shimmer, pie or donut variants.

### 11.3 CategoryRow
Anatomy (height 64): `[16pt symbol] [title / subtitle stack] [spacer] [size, monospaced] [disclosure chevron]`.
Subtitle = `\(fileCount) items · \(producer)` where a rule supplies `producer`, else item count alone.
States — default · hover (`quaternaryLabelColor`) · selected · expanded (chevron rotates 90° over `motion.disclosure`) · partial (appends `exclamationmark.triangle` in `.orange` with tooltip "Some locations couldn't be read").

### 11.4 CandidateRow
Anatomy (height 44): `[checkbox] [title / path stack] [spacer] [SafetyBadge] [size] [info button]`.
States — unchecked (default for `review`) · **checked (default for `safe` only)** · **unselectable (`protected` / `advanced`: checkbox replaced by the safety symbol, row at `.opacity(0.7)`, not dimmed to unreadable)** · hover reveals the info button · pressed · focused.
**Invariant:** a `protected` or `advanced` row **has no checkbox at all**. It is not a disabled checkbox — the affordance does not exist.

### 11.5 SafetyBadge
Anatomy: `[12pt symbol] [label]`, 4pt gap, `.caption2 .medium`, no background fill, no pill.
**A pill or filled capsule is forbidden** — it makes the interface look like a web dashboard. Symbol + coloured text only.

### 11.6 InsightStatement
One card. Padding 16, radius 10. `.title2` statement, `.callout` supporting line. **Maximum one per screen.** This is the Autopsy's plain-English sentence.

### 11.7 ScanProgress
Anatomy: determinate `ProgressView(value:)`, current probe name `.callout`, completed probes as a checked list, `[Cancel]`.
**Forbidden:** indeterminate spinner as the primary indicator; fake progress; percentage not backed by real probe completion.

### 11.8 Others (same rigour applies)
`ToolbarScanButton` · `SearchField` (`.searchable`, filters active pane) · `ItemDetailInspector` · `DryRunSummary` · `ReceiptBlock` · `SnapshotRow` (**no delete affordance — see PART 16**) · `PermissionBanner` · `EmptyState` (32pt symbol, `.title2` title, `.callout` body, at most one action) · `ErrorState` · `LicenseStatusRow` · `DeviceRow` (with `[Release]`).

---

## PART 12 — NAVIGATION AND INFORMATION ARCHITECTURE

> **Canvas:** the sidebar is visible on every product artboard; narrow-window behaviour is artboard `NarrowWindow`.

### 12.1 Structure

```
┌ Sidebar 240pt ───────────────┬ Detail ─────────────────────────────┐
│ ⌘1  Overview                 │                                     │
│                              │                                     │
│ STORAGE      (after scan)    │                                     │
│    Developer        48.2 GB  │                                     │
│    Caches            8.1 GB  │                                     │
│    Logs              1.2 GB  │                                     │
│    Unclassified     12.1 GB  │                                     │
│                              │                                     │
│ ⌘2  Cleanup             ⑫    │                                     │
│ ⌘3  Snapshots                │                                     │
└──────────────────────────────┴─────────────────────────────────────┘
```

### 12.2 Rejected alternatives, and why

- **"Scan" as a sidebar item** — scanning is an action, not a destination. It lives in the toolbar, always reachable.
- **Separate "Overview" and "Storage Autopsy"** — they are one screen at two depths. Splitting them forces navigation in order to understand, which inverts the product promise.
- **"Settings" as a sidebar row** — the single clearest tell of a web app wearing a Mac window. Settings is a `Settings` scene on ⌘,.

### 12.3 Placement rules

| Content | Placement |
|---|---|
| Overview, Cleanup, Snapshots | Sidebar |
| Storage categories | Sidebar, nested, **after a scan only** |
| Item detail | Inspector column (⌘⌥I) — not a sheet, not a new window |
| "Why is this safe?" | Popover from the info button |
| Dry run | Sheet (modal — it precedes a destructive action) |
| Receipt | Detail pane, then reachable from Cleanup |
| Settings | `Settings` scene, ⌘, |
| About | Standard about panel |
| Permission prompt | Inline banner in the affected pane — **never a modal on launch** |

### 12.4 Narrow windows — native behaviour, not web breakpoints

macOS handles this with `NavigationSplitView` column visibility. There are no breakpoints, no hamburger, no card reflow.

| Width | Behaviour |
|---|---|
| ≥ 1000 | Sidebar + detail + inspector (if open) |
| 880–999 | Inspector closes; sidebar + detail |
| < 880 | Below minimum — not supported |
| Sidebar toggled off | Standard `sidebarToggle` toolbar item, system-provided |

**What must never happen:** hamburger menus, overlay drawers, cards reflowing into a single column, controls disappearing without a system-standard affordance. Content within the detail pane scrolls; the toolbar and sidebar stay fixed.

---

## PART 13 — SCREEN SPECIFICATIONS

> **Canvas:** every screen below has a named artboard. Where this document and the canvas differ, this document governs behaviour and values; the canvas governs composition.

### 13.1 Overview / Storage Autopsy — the product wedge

*Canvas artboard: `Overview`, `OverviewDark`, `PartialScan`, `FirstLaunch`*

**Purpose:** answer "why is my Mac full?" in ~3 seconds, then invite investigation.

```
┌─────────────────────────────────────────────────────────────┐
│ ◧  DiskPrune                                    [Scan] ⌘R   │  toolbar 52
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   Macintosh HD                                              │  .headline
│   418 GB used · 94 GB available                             │  .callout secondary
│                                                             │
│   ███████ ████ ██ ▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨            │  CapacityBar 12pt
│   ●Developer ●Caches ●Logs ▨Not examined                    │  legend .caption
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Most of your storage is developer tooling.            │  │  InsightStatement
│  │ Xcode and package caches account for 56.3 GB of the   │  │  (card 1 of 2)
│  │ 94.2 GB DiskPrune examined.                           │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│   EXAMINED                                        94.2 GB   │  section header
│     Explained                                     82.1 GB   │  rows, not cards
│     Scanned but unclassified                      12.1 GB   │
│   NOT EXAMINED                                   323.8 GB   │
│                                                             │
│   ⚠ 3 locations couldn't be read.            [Why?]         │  partial banner
│                                                             │
│   Reclaimable candidates            38.4 GB  [Review →]     │
└─────────────────────────────────────────────────────────────┘
```

**Data contract — every value maps to `StorageCoverage`:** `volumeUsedBytes`, `volumeAvailableBytes`, `examinedBytes`, `classifiedBytes`, `unclassifiedScannedBytes`, `notExaminedBytes`, `permissionLimitedPaths.count`, `cleanupCandidateBytes`. **Nothing else is displayed.**

**Required copy discipline:** "DiskPrune examined 94.2 GB of the 418 GB used." **Never** phrasing that implies the classified figure explains the whole disk.

**States** — first launch: capacity bar from volume stats (available pre-scan), everything else replaced by an EmptyState inviting a scan · scanning: bar fills live, sections stream in · complete: as drawn · partial: banner present, figures prefixed "at least" · no candidates: the reclaimable row becomes "No reclaimable data found — your storage is already lean."

**Dark mode:** card loses its shadow, gains `.regularMaterial`. Category ramp switches to the dark column. Hatch lightens to 20% white.

**Keyboard:** ⌘R scan · ⌘1 focus · ⌥⌘S sidebar · Tab through interactive elements.

### 13.2 Scan progress

*Canvas artboard: `ScanProgress`*

```
   Scanning…                                    [Cancel]
   ████████████████████░░░░░░░░░░░░  62%
   Reading Xcode caches

   ✓ User caches          8.1 GB
   ✓ Logs                 1.2 GB
   → Xcode
     Docker
     Package managers
```

Determinate only. Probe list from `ScanEvent.probeStarted`. Percentage = completed probes ÷ total probes — **honest, never synthetic**. Cancel is always enabled and responds within 500ms. On cancel: partial results are kept and clearly labelled "Scan cancelled — showing partial results."

### 13.3 Category detail

*Canvas artboard: `CategoryDetail`*

`List` of `CategoryRow`, expandable to child items. Toolbar: search, sort (size / name / date), "Select all safe". **Not cards.** Selecting a row opens the inspector.

### 13.4 Item detail (inspector)

*Canvas artboard: `ItemDetail`*

Shows only: `displayName`, `url` (monospaced, middle-truncated), `onDiskBytes`, `logicalBytes` (labelled "Logical"), `fileCount`, `newestModification`, safety badge, `explanation`, `consequence`, `howItComesBack`, `docsURL`. Sparse files (where `logicalBytes > 2 × onDiskBytes`) are labelled "Sparse file — occupies less space than its size suggests."

Unclassified items: "DiskPrune doesn't have a rule for this location" plus path and size. **No guessed explanation.**

### 13.5 Cleanup candidates

*Canvas artboard: `CleanupCandidates`, `CleanupCandidatesDark`, `NoCandidates`*

Sections by safety: Safe (pre-checked) → Review (unchecked) → Advanced (no checkbox) → Protected (no checkbox). Footer is persistent:

```
   12 items selected · 18.7 GB estimated recoverable    [Review Cleanup →]
```

**"Estimated recoverable" — never "will free".**

### 13.6 Dry run (sheet)

*Canvas artboard: `DryRun`*

```
   Review cleanup

   12 items                          18.7 GB estimated recoverable
   9 Safe                            14.2 GB
   3 Review                           4.5 GB

   Files will be moved to Trash. Nothing will be permanently deleted.
   Storage becomes available after you empty the Trash.

   Nothing has changed yet.

                                 [Cancel]  [Move to Trash]
```

"Nothing has changed yet" is **mandatory and verbatim**. `[Move to Trash]` is the default button; `[Cancel]` is Escape. Not destructive-red — this action is reversible, and red would misrepresent it.

### 13.7 Revalidation / TOCTOU

*Canvas artboard: `ReceiptPartialFailure`*

Between confirmation and trashing, items failing `PathValidator.revalidateBeforeTrash` are skipped. If any are skipped the receipt shows a "Skipped" section with a plain-English reason per `SkipReason`:

| SkipReason | Copy |
|---|---|
| `vanished` | "No longer on disk — something else removed it." |
| `becameSymlink` | "Changed to a shortcut since the scan — skipped for safety." |
| `typeChanged` | "Changed type since the scan — skipped for safety." |
| `identityChanged` | "Replaced by a different file since the scan — skipped for safety." |
| `escapedCleanupRoot` | "Moved outside the area DiskPrune scanned — skipped." |
| `appBundleAncestor` | "Inside an application bundle — DiskPrune never removes these." |
| `denyListed` | "In a protected location — DiskPrune never removes these." |
| `cancelled` | "Cancelled before this item." |

### 13.8 Receipt — the honesty screen

*Canvas artboard: `Receipt`, `ReceiptDark`, `ReceiptPartialFailure`*

```
   Cleanup complete

   Estimated recoverable                        18.7 GB
   Moved to Trash                               18.4 GB
   Storage immediately available    approximately unchanged

   Your files are still in Trash and can be restored.
   Empty Trash to permanently reclaim this space.      [Open Trash]

   ✓ Moved to Trash        11 items      18.4 GB
   ⚠ Couldn't be moved      1 item        0.3 GB   [Details]
```

**Absolute rules.** The words **"freed", "reclaimed", "recovered", "deleted", "removed"** must not appear for trashed bytes — enforced by test `T-TERM-01`. `[Open Trash]` calls `NSWorkspace.open` on the Trash and nothing else — **DiskPrune never empties Trash and has no API to do so.** When `immediateAvailableDelta` is materially non-zero, report the measured figure honestly, including negative ("decreased by 0.2 GB — another process wrote to the disk during cleanup"). "All items were skipped" is a legitimate outcome and renders as such — never as success.

### 13.9 Snapshots — read-only

*Canvas artboard: `Snapshots`, `SnapshotsDark`*

```
   Local snapshots                                   7 snapshots

   macOS keeps local Time Machine snapshots so you can restore files
   without your backup drive. They can hold tens of gigabytes, and
   macOS usually reclaims that space automatically when your disk
   fills up.

   DiskPrune does not delete snapshots.

     2026-09-08 14:22
     2026-09-07 09:15
     …

   To remove them yourself, use Terminal:
     tmutil deletelocalsnapshots /
   This permanently removes every local snapshot. You will not be able
   to restore files without your backup drive.        [Apple docs ↗]
```

**No delete button. No swipe action. No context-menu delete. No selection.** `SnapshotRow` is non-interactive.
States: none found · `readFailed` → "Couldn't read snapshots" (never an error dialog).

### 13.10 Permission required

*Canvas artboard: `PermissionRequired`*

Inline banner, **never a launch modal**:

> **Some locations couldn't be read.** macOS privacy settings may be limiting results. `[Open System Settings]` `[Continue anyway]`

The scan runs regardless. Results are marked partial. **The UI never asserts that Full Disk Access is or is not granted** — the underlying probe is a heuristic, and PART 5.6 of the Builder Handoff forbids presenting it as proof.

### 13.11 Settings — `Settings` scene, `TabView`

*Canvas artboard: `Settings`*

Verified macOS convention: centred tabs, icon **and** label each, `.preference` toolbar style. Three tabs:

| Tab | Symbol | Contents |
|---|---|---|
| General | `gearshape` | Scan on launch · appearance follows system · confirm before Trash (default on, **cannot be disabled**) |
| Licence | `key` | Status, activation field, device list with last-seen and `[Release]`, `[Buy]` |
| Advanced | `wrench.and.screwdriver` | Rules version (read-only) · receipts folder `[Reveal]` · `[Reset warnings]` |

**"Confirm before Trash" is displayed but permanently on and disabled**, with the note "DiskPrune always asks before moving files to Trash." Showing it and locking it communicates the guarantee better than hiding it.

### 13.12 Licence states

*Canvas artboard: `License`, `AboutUpdate`*

Active · offline-within-expiry (no visible difference — this is the point) · expired ("DiskPrune needs to check your licence. Connect to the internet." — **never** "invalid") · revoked · seat limit (device list + `[Release]`). **In every one of these states, scanning and every explanation remain fully available.** The free tier has no code path through `LicenseManager`.

---

## PART 14 — STATE MATRIX

| Screen | Empty | Loading | Partial | Error |
|---|---|---|---|---|
| Overview | "Scan to see what's using your storage" + `[Scan]` | Capacity bar + streaming sections | Banner + "at least" prefixes | Volume unreadable → error state |
| Category | "No items in this category" | Skeleton rows | Denied paths listed | — |
| Cleanup | "No reclaimable data found" | — | — | — |
| Receipt | "All items were skipped" | Progress + count | Mixed success/failure | All failed → honest report |
| Snapshots | "No local snapshots found" | — | — | "Couldn't read snapshots" |
| Licence | Not activated → field + `[Buy]` | Verifying | Offline | Seat limit / revoked |

**Every empty state is designed** — 32pt `.secondary` symbol, `.title2` title, `.callout` explanation, at most one action. **A blank pane is a defect.**

---

## PART 15 — ACCESSIBILITY

- **Dynamic Type:** semantic text styles only. Layout must survive `.accessibility3`; rows grow vertically, never clip.
- **Contrast:** all text ≥ 4.5:1. Honour Increase Contrast (system colours do this automatically — a reason to use them).
- **Colour independence:** every safety state is symbol + label + colour. Verify by rendering in greyscale (PART 18).
- **VoiceOver:** every row exposes name, size, safety, and selection state in one label. `CapacityBar` is a single element with a value enumerating all segments including not-examined.
- **Keyboard:** full traversal, visible focus rings, ⌘1–3 panes, ⌘R scan, ⌘F search, ⌘⌥I inspector, Space toggles selection, Escape dismisses.
- **Reduce Motion / Reduce Transparency:** PART 10 and 6.3.
- **Hit targets:** ≥ 28×28.

---

## PART 16 — MICROCOPY

**Voice:** calm, technical, clear, confident, honest. Never urgent, never celebratory, never frightening.

| Never write | Write |
|---|---|
| "Freed 18 GB!" | "Moved to Trash · 18.4 GB" |
| "Clean your Mac now" | "12.4 GB can be reviewed" |
| "Junk files" | "Generated by Xcode" |
| "Dangerous!" | "Review — this may contain data you want to keep" |
| "We couldn't scan" | "Some locations couldn't be read" |
| "Invalid licence" | "DiskPrune needs to check your licence" |

**Required phrases, verbatim:** "Nothing has changed yet." · "Files will be moved to Trash. Nothing will be permanently deleted." · "DiskPrune does not delete snapshots." · "Empty Trash to permanently reclaim this space." · "Some storage could not be classified."

No exclamation marks anywhere in the interface.

---

## PART 17 — SWIFTUI IMPLEMENTATION GUIDANCE

Maps to the approved architecture (Builder Handoff PART 5.8). **Do not restructure the architecture to suit the UI.**

```
UI/RootView.swift              NavigationSplitView + toolbar + Settings scene
UI/StorageAutopsyView.swift    13.1 — CapacityBar, InsightStatement, coverage rows
UI/ScanView.swift              13.2 — determinate progress
UI/ResultsView.swift           13.3/13.5 — List of CategoryRow / CandidateRow
UI/ItemDetailView.swift        13.4 — inspector
UI/CleanupPlanView.swift       13.5 footer
UI/DryRunSheet.swift           13.6
UI/ReceiptView.swift           13.8
UI/SnapshotView.swift          13.9 — no delete affordance
UI/LicenseView.swift           13.12
UI/StateViews.swift            EmptyState, ErrorState, PermissionBanner
UI/Components/                 CapacityBar, SafetyBadge, CategoryRow, CandidateRow
```

- `ScanEngine` is an `actor`; consume `AsyncStream<ScanEvent>` and publish to `@MainActor` state. Never block the main thread.
- Views are driven by `StorageItem` / `StorageCoverage` / `CleanupPlan` / `CleanupReceipt` **as defined** — do not add fields to satisfy a visual.
- **No third-party packages.** Foundation, SwiftUI, AppKit, CryptoKit, Darwin, Security only.
- `NSViewRepresentable` only where SwiftUI genuinely cannot express the control; each use carries a comment naming the limitation.

---

## PART 18 — VISUAL QA CHECKLIST

Run before declaring Phase 3 complete. **Any failure blocks.**

**The two decisive tests:**
1. **Greyscale test.** Render every screen with all semantic colour removed. Hierarchy must survive and every safety state must remain distinguishable. If not, the design leans on colour — fix it.
2. **Card count.** No screen shows more than two card-like containers. More means PART 3.1 was violated.

Then: does it look like a Mac app, not a web dashboard · is it excessively colourful · is Liquid Glass dominating · is typographic hierarchy clear · is spacing consistent with PART 8 · are important actions obvious · does cleanup feel trustworthy rather than aggressive · can a non-technical user understand storage · can a technical user reach depth · is dark mode designed rather than inverted · does the window work at 880×560 · are system controls used rather than reimplemented · does every visual element have a function · does the build match the visual canvas.

---

## PART 19 — DATA CROSS-CHECK

Every screen verified against the approved models. **Nothing in this guide requires data the architecture does not provide.**

| Visual | Source | OK |
|---|---|---|
| Capacity bar | `StorageCoverage` (all fields) | ✅ |
| Insight statement | `classifiedBytes`, `examinedBytes`, top categories | ✅ |
| Category rows | `StorageItem.category` + `onDiskBytes` + `fileCount` | ✅ |
| "Last built N months ago" | `newestModification` | ✅ |
| Sparse label | `logicalBytes` vs `onDiskBytes` | ✅ |
| Safety badge | `StorageItem.safety` | ✅ |
| Explanation / consequence | `StorageItem` + `StorageRule` | ✅ |
| Estimated recoverable | `CleanupPlan.estimatedRecoverableBytes` | ✅ |
| Receipt four-line block | `CleanupReceipt` | ✅ |
| Skip reasons | `ItemOutcome.skipped(reason:)` | ✅ |
| Snapshot list | `SnapshotSummary` | ✅ |
| Device list | licensing `devices` | ✅ |

**Explicitly FUTURE / NOT V1 — must not appear in the build or the canvas:** storage history or trends · growth-over-time charts · per-application footprints · duplicate detection · large-file browser · storage health score · `permissionLimitedBytes` as a number (always `nil`) · any snapshot deletion · any `Docker.raw` deletion · any Empty Trash action.

---

## PART 20 — GROK IMPLEMENTATION CONTRACT

**THIS DESIGN GUIDE OVERRIDES ALL PREVIOUS UI/UX GUIDANCE.**

The existing UI — `ContentView.swift`, its three `Text("…")` placeholders, and its hardcoded-zero dashboard — **has no visual value that must be preserved.** Implement this design. Do not cosmetically improve the placeholder.

**Grok MUST NOT:**
- invent a different visual language, or improvise where this document gives a rule
- turn the app into a web or SaaS dashboard
- introduce decorative gradients, glows, or blobs
- overuse cards — PART 3.1 lists the complete permitted set
- overuse Liquid Glass, or let any design depend on it
- tint sidebar icons with the accent colour
- introduce colours outside PART 5
- replace SF Symbols with any other icon set
- bypass native macOS conventions or reimplement system controls
- invent unsupported data or fake a capability — PART 19
- bypass `CleanupPlan`, or pass URLs to `CleanupExecutor`
- weaken any safety check, or skip TOCTOU revalidation
- add permanent deletion, snapshot deletion, `Docker.raw` deletion, or Empty Trash
- describe trashed bytes as freed, reclaimed, or recovered
- render `protected` or `advanced` items as selectable cleanup targets
- add third-party dependencies

**Grok MAY** adjust implementation details where SwiftUI or AppKit genuinely requires it — but must preserve the documented visual intent and behaviour, and must say so in the commit message.

**UI is allowed to evolve. Safety architecture is not.**

**If a requirement here is ambiguous, STOP AND REPORT.** Do not invent behaviour.

---

## PART 21 — PHASE 3 ACCEPTANCE CRITERIA

**Structure** — `NavigationSplitView` with exactly three top-level sidebar items · categories nested and appearing only after a scan · Settings is a `Settings` scene with `TabView`, not a sidebar row · About is the standard panel · Scan is a toolbar action.

**Visual** — greyscale test passes · no screen exceeds two cards · no hex colour outside PART 5.5 · every byte figure `.monospacedDigit()` · exactly one `.largeTitle` per screen · every spacing value a multiple of 4 and drawn from PART 8 · no shadow other than the single card shadow · dark mode designed, not inverted.

**Safety and honesty** — `protected`/`advanced` rows have no checkbox · dry run precedes every cleanup and reads "Nothing has changed yet." · receipt shows all four accounting lines · `T-TERM-01` passes ("freed"/"reclaimed" absent) · Snapshots has no delete affordance of any kind · `Docker.raw` never selectable · permission handled as an inline banner, never a launch modal · free tier fully functional in every licence failure state.

**Accessibility** — full keyboard traversal with visible focus · VoiceOver labels on every row and the capacity bar · Reduce Motion and Reduce Transparency honoured · layout survives `.accessibility3` · no meaning carried by colour alone.

**Windowing** — correct at 880×560 and maximised · no hamburger, overlay drawer, or card reflow at any width.

**Fidelity** — the build matches the visual canvas. Any deliberate divergence is documented in the PR body.

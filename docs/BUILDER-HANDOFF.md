# DISKPRUNE — BUILDER HANDOFF SPECIFICATION
### Version 1.0 · Implementation Edition

**Author:** Architect (Claude) · **Builder:** Grok · **Reviewer:** Repository owner (adversarial)
**Status:** Implementation contract. Supersedes Mega Plan v2 where they differ.
**Baseline verified:** HEAD `2b14a0a`, working tree clean, 2026-09-08.

> **Grok: read PART 23 (BUILDER RULES) before writing a single line.** Where this document and any prior document disagree, this document wins. Where this document is ambiguous, **stop and report** — do not invent behavior.

---

# PART 3 — REPOSITORY BASELINE

Re-inspected at HEAD `2b14a0a`. Working tree clean. No drift from Mega Plan v2 assumptions except items **B-14** and **B-15** below, which are new findings.

## 3.1 Native app — `app/` (5 files, ~250 lines)

| File | Current responsibility | Problems | Verdict | Destination |
|---|---|---|---|---|
| `Package.swift` | SPM manifest, `executableTarget`, macOS 14 | No test target; no resources | **REWRITE** | same path |
| `Sources/DiskPrune/App.swift` | `@main`, WindowGroup | Adequate | **PRESERVE** (minor edit) | same path |
| `Sources/DiskPrune/ContentView.swift` | Entire UI + scan + purge orchestration | **B-1** purge trashes the whole scan set (`:121`); **B-2** `flushAPFSSnapshots()` unconditional (`:122`); **B-3** `totalFreed = 0 // would calculate size here in reality` (`:104`); **B-4** three nav destinations are `Text(...)` placeholders (`:17-19`); **B-5** `try?` swallows all cleanup errors | **DELETE** | replaced by `UI/*.swift` |
| `Sources/DiskPrune/ScannerActor.swift` | Enumeration, trash, snapshot flush, FDA | **B-6** returns flat array of parents *and* children (`:16-25`); **B-7** `for url in urls { try trashItem }` — first throw aborts batch (`:28-32`); **B-8** `tmutil deletelocalsnapshots /` (`:37-54`); **B-9** `checkFullDiskAccess()`/`requestFullDiskAccess()` never called (`:56-66`); requests `.totalFileAllocatedSizeKey` and never reads it | **DELETE** | replaced by `Scanning/*` + `Cleanup/*` |
| `Sources/DiskPrune/SafetyRules.swift` | Hardcoded tier1/tier2 path arrays | **B-10** `tier2Paths()` is dead code — never scanned, never displayed | **DELETE** | paths become rules in `shared/storage-rules.json` |
| `Sources/DiskPrune/LicenseManager.swift` | Keychain + activation POST | **B-11** `isActivated` returns `true` if *any* Keychain item exists (`:7-16`) — never reads the value; no `kSecAttrService`; no `kSecAttrAccessible` | **DELETE** | replaced by `Licensing/*` |

## 3.2 Worker — `worker/`

| File | Problems | Verdict |
|---|---|---|
| `src/index.js` | **B-12** `POST /webhook` has **no Stripe signature verification** (`:21-45`) — one `curl` mints a license; `Math.random()` keys (`:30`) and `.substring(2,6)` can yield <4 chars; no idempotency; `GET /key-lookup?session_id=` returns a key to anyone with `CORS: *` (`:64-76`); no rate limiting; no refund/dispute handling; `active` boolean with no seats or entitlements | **REWRITE** → `src/{index,webhook,licenses,tokens,crypto,email,db}.js` |
| `wrangler.toml` | KV-only; no D1; no secrets declared | **REWRITE** |
| `.wrangler/cache/wrangler-account.json` | **B-14 (NEW)** — **tracked in a public repo despite `.wrangler/` being in `.gitignore`** (added to the ignore file *after* it was committed, so the rule does not untrack it). Exposes Cloudflare account ID `0461…4e02` and the account email. Not a credential — an account ID alone cannot authenticate — but it should not be public. | **DELETE from git** (`git rm --cached`), keep on disk |

## 3.3 Website — `site/` (TanStack Start) and `web/` (Astro)

`site/` is a **Grok/xAI app-generation scaffold**, not a marketing site. Full disposition in PART 4 and PART 16.

| Group | Files | Verdict |
|---|---|---|
| **Valuable product work** | `components/mac-app.tsx` (398), `lib/prune-store.ts` (253), `lib/blog.ts` (130), `lib/scan-data.ts` (155), `components/{disk-ring,wordmark,license-dialog,site-header,site-footer}.tsx`, `components/ui/*`, `styles.css`, `routes/index.tsx`, `routes/blog/*`, `lib/utils.ts` | **PORT to `web/`** |
| **Scaffold — no product requirement** | `lib/auth/*` (18 files), `lib/app-data/*` (11), `lib/db.ts`, `lib/multiplayer/*` (570 lines WebRTC), `scripts/grok-*`, `scripts/{preview,migrate,migration-plan,sign-out-plan,browser-smoke,brand-check,check-auth-invariant,with-app-env,write-atomic,app-env-plugin,browser-guard,preview-thumbnail}*`, `server/middleware/grok-pwa.ts`, `server/virtual-grok-og-identity.d.ts`, `lib/preview-*`, `components/preview-host-bridge.tsx`, `routeTree.gen.ts`, `router.tsx`, `vite.config.ts`, `eslint.config.mjs`, `package-lock.json` | **DELETE after port verification** |
| **Broken / false** | `routes/success.tsx` — **B-13** prints "Payment received" from a URL param and calls `issueLicense()` (client-side `Math.random()` → `localStorage`), producing a key `api.diskprune.com` has never seen and will reject; `lib/license.ts` `issueLicense()`; `lib/product.ts` `COMPARISON` — all six rows wrong or unverifiable (DissectMac listed "Subscription"/"Treemap only"; it is **$12.99 one-time** with a free tier) | **DELETE / REWRITE** |
| `web/` Astro stub | Correct architecture, no content. `web/dist/` (5 files) **B-15 (NEW)** is committed build output. | **PRESERVE `web/` as the target; `git rm -r --cached web/dist`** |

## 3.4 Other

| File | Verdict |
|---|---|
| `.github/workflows/build-mac.yml` | **REWRITE. B-16** — arm64-only (`macos-14` runners are arm64; no `lipo`) → **Intel Macs get nothing**; Info.plist lacks `CFBundleShortVersionString`/`CFBundleVersion`/`LSMinimumSystemVersion`; uses `--deep` (Apple-deprecated for distribution signing); ad-hoc signature only |
| `README.md` | **REWRITE.** Documents `/key-lookup` as "used by the success page" — the success page never calls it. Documents `tmutil deletelocalsnapshots /` as a feature. |
| `build-and-verify.sh` | **DELETE.** Superseded by CI. |
| `.gitignore` | **MODIFY.** Add `web/dist/`, `shared/*.generated.json`. |

---

# PART 4 — TARGET REPOSITORY TREE

```
/
├── .github/workflows/
│   ├── ci.yml                                          CREATE
│   └── build-mac.yml                                   REWRITE
├── shared/
│   ├── storage-rules.json                              CREATE  ← ONLY manually edited rules file
│   └── storage-rules.schema.json                       CREATE
├── scripts/
│   ├── sync-rules.sh                                   CREATE
│   └── validate-rules.mjs                              CREATE
├── app/
│   ├── Package.swift                                   REWRITE
│   ├── Sources/DiskPrune/
│   │   ├── App.swift                                   PRESERVE
│   │   ├── Models/
│   │   │   ├── FileID.swift                            CREATE
│   │   │   ├── ObjectType.swift                        CREATE
│   │   │   ├── SafetyLevel.swift                       CREATE
│   │   │   ├── Category.swift                          CREATE
│   │   │   ├── ScanState.swift                         CREATE
│   │   │   ├── StorageItem.swift                       CREATE
│   │   │   ├── StorageCoverage.swift                   CREATE
│   │   │   ├── PlannedItem.swift                       CREATE
│   │   │   ├── CleanupPlan.swift                       CREATE
│   │   │   └── CleanupReceipt.swift                    CREATE
│   │   ├── Knowledge/
│   │   │   ├── StorageKnowledge.swift                  CREATE
│   │   │   ├── StorageRule.swift                       CREATE
│   │   │   └── Resources/storage-rules.json            CREATE (generated; never hand-edited)
│   │   ├── Scanning/
│   │   │   ├── FileIdentity.swift                      CREATE
│   │   │   ├── DirectorySizer.swift                    CREATE
│   │   │   ├── ScanEngine.swift                        CREATE
│   │   │   ├── SnapshotInspector.swift                 CREATE
│   │   │   └── Probes/{Probe,Xcode,Docker,PackageManager,Cache,Log}Probe.swift  CREATE
│   │   ├── Cleanup/
│   │   │   ├── PathValidator.swift                     CREATE
│   │   │   ├── CleanupExecutor.swift                   CREATE
│   │   │   └── SpaceVerifier.swift                     CREATE
│   │   ├── Persistence/
│   │   │   ├── ReceiptStore.swift                      CREATE
│   │   │   └── PreferencesStore.swift                  CREATE
│   │   ├── Permissions/FullDiskAccess.swift            CREATE
│   │   ├── Licensing/
│   │   │   ├── LicenseToken.swift                      CREATE
│   │   │   ├── LicenseManager.swift                    CREATE
│   │   │   ├── DeviceIdentity.swift                    CREATE
│   │   │   ├── KeychainStore.swift                     CREATE
│   │   │   └── PublicKeys.swift                        CREATE
│   │   ├── UI/
│   │   │   ├── RootView.swift                          CREATE
│   │   │   ├── ScanView.swift                          CREATE
│   │   │   ├── StorageAutopsyView.swift                CREATE
│   │   │   ├── ResultsView.swift                       CREATE
│   │   │   ├── ItemDetailView.swift                    CREATE
│   │   │   ├── CleanupPlanView.swift                   CREATE
│   │   │   ├── DryRunSheet.swift                       CREATE
│   │   │   ├── ReceiptView.swift                       CREATE
│   │   │   ├── SnapshotView.swift                      CREATE
│   │   │   ├── LicenseView.swift                       CREATE
│   │   │   └── StateViews.swift                        CREATE (empty/error/partial)
│   │   ├── ContentView.swift                           DELETE
│   │   ├── ScannerActor.swift                          DELETE
│   │   ├── SafetyRules.swift                           DELETE
│   │   └── LicenseManager.swift                        DELETE (path reused under Licensing/)
│   └── Tests/DiskPruneTests/*.swift                    CREATE
├── worker/
│   ├── package.json                                    CREATE
│   ├── wrangler.toml                                   REWRITE
│   ├── migrations/0001_init.sql                        CREATE
│   ├── src/{index,webhook,licenses,tokens,crypto,email,db,ratelimit}.js  CREATE
│   ├── test/*.test.js                                  CREATE
│   ├── src/index.js                                    DELETE (replaced)
│   └── .wrangler/cache/wrangler-account.json           DELETE FROM GIT (`git rm --cached`)
├── web/                                                ← the only website
│   ├── astro.config.mjs                                REWRITE
│   ├── package.json                                    REWRITE
│   ├── tailwind.config.mjs                             PRESERVE
│   ├── src/{layouts,components,pages,content,data,lib,styles}/…   CREATE (ported)
│   ├── public/{robots.txt,favicon.svg,og.jpg}          CREATE / MOVE from site/public
│   └── dist/                                           DELETE FROM GIT
├── site/                                               DELETE ENTIRELY (after port verified)
├── build-and-verify.sh                                 DELETE
├── .gitignore                                          MODIFY
└── README.md                                           REWRITE
```

---

# PART 5 — NATIVE macOS IMPLEMENTATION SPEC

**Global:** Swift 5.10, macOS 14 deployment target. **Dependencies: Foundation, SwiftUI, AppKit, CryptoKit, Darwin, Security only. No third-party packages.** All types `Sendable` where crossing an actor boundary.

## 5.1 Models

### `FileID.swift`
```swift
struct FileID: Hashable, Sendable, Codable { let dev: UInt64; let ino: UInt64 }
```
**Responsibility.** Physical file identity for hardlink deduplication and TOCTOU revalidation.
**Source.** `lstat.st_dev`, `lstat.st_ino`. **Invariant:** constructed only by `FileIdentity`.
**Tests:** T-HL-01, T-HL-02, T-TOC-04.

### `ObjectType.swift`
```swift
enum ObjectType: String, Sendable, Codable { case directory, regularFile, symlink, other }
```
Derived from `st_mode`. `symlink` items are **never** cleanup candidates.

### `SafetyLevel.swift`
```swift
enum SafetyLevel: String, Sendable, Codable, CaseIterable {
    case safe        // regenerable by a known tool; cost of removal is time only
    case review      // probably reclaimable; may hold state the user cares about
    case advanced    // requires understanding consequences; separate screen
    case protected   // never offered. Unrepresentable in a CleanupPlan.
}
var isPreselectable: Bool { self == .safe }
var isPlannable: Bool { self == .safe || self == .review }
```
**Invariant.** `.protected` and `.advanced` return `false` from `isPlannable`. **v1 emits no `.advanced` cleanup targets at all** (Docker and snapshots are the only `.advanced` concepts and both are inspect-only).

### `Category.swift`
```swift
enum Category: String, Sendable, Codable {
    case developerBuild, packageCache, applicationCache, log, applicationSupport,
         containerData, virtualDisk, snapshot, application, userData, unknown
}
```

### `ScanState.swift`
```swift
enum ScanState: Sendable, Codable, Equatable {
    case complete
    case partial(deniedPaths: [String])   // paths that returned EACCES/EPERM
    case denied                            // root itself unreadable
}
```
**Invariant.** Any item whose subtree produced a denial is `.partial`. UI must render `.partial` sizes as "at least X", never as an exact figure.

### `StorageItem.swift`
```swift
struct StorageItem: Identifiable, Sendable, Codable {
    let id: UUID
    let url: URL                    // canonical, standardized; symlinks resolved at discovery
    let fileID: FileID              // recorded for TOCTOU revalidation
    let objectType: ObjectType
    let displayName: String         // "Xcode DerivedData — MyApp"
    let onDiskBytes: Int64          // Σ st_blocks×512, item-scope hardlink dedup   ← DISPLAYED
    let logicalBytes: Int64         // Σ st_size                                     ← detail only
    let fileCount: Int
    let newestModification: Date?
    let category: Category
    let safety: SafetyLevel
    let knowledgeID: String?        // → StorageRule.id; nil ⇒ unclassified
    let explanation: String
    let consequence: String
    let regenerable: Bool
    let cleanupRoot: URL            // approved root; item must remain a descendant
    let scanState: ScanState
    let isCleanupCandidate: Bool    // safety.isPlannable && knowledgeID != nil && objectType != .symlink
}
```
**Invariants.** Grouping is at the *meaningful unit* — one item per DerivedData project, per package-cache root — **never one item per file**. **No item may be an ancestor of another item** (asserted in tests; this is what makes B-6/B-7 structurally impossible). `url` is never inside a `.app` bundle.

### `StorageCoverage.swift` — Correction 6
```swift
struct StorageCoverage: Sendable, Codable {
    let volumeTotalBytes: Int64            // MEASURED  .volumeTotalCapacityKey
    let volumeAvailableBytes: Int64        // MEASURED  .volumeAvailableCapacityForImportantUsageKey
    let volumeUsedBytes: Int64             // MEASURED  total − available
    let classifiedBytes: Int64             // MEASURED  scan-global deduped; items with knowledgeID != nil
    let unclassifiedScannedBytes: Int64    // MEASURED  scan-global deduped; scanned, no rule matched
    let examinedBytes: Int64               // MEASURED  classified + unclassifiedScanned
    let notExaminedBytes: Int64            // DERIVED   max(0, volumeUsed − examined). Label "not examined".
    let permissionLimitedPaths: [String]   // KNOWN list
    let permissionLimitedBytes: Int64?     // UNKNOWN — ALWAYS nil in v1. Never estimated.
    let cleanupCandidateBytes: Int64       // MEASURED  scan-global deduped; isCleanupCandidate items
}
```
**Required UI copy pattern:**
> "DiskPrune examined **94.2 GB** of the **512 GB** used on this Mac, and can explain **82.1 GB** of it. **3 locations couldn't be read.**"

**Prohibited:** any phrasing implying the classified figure explains the whole disk. `permissionLimitedBytes` must never be filled with a guess — the honest answer is "unknown", and admitting it is the free tier's trust advantage.
**Tests:** T-COV-01…04.

### `PlannedItem.swift` — the safety choke point
```swift
struct PlannedItem: Sendable {
    let itemID: UUID
    let url: URL
    let fileID: FileID
    let objectType: ObjectType
    let cleanupRoot: URL
    let estimatedBytes: Int64
    let displayName: String
    let safety: SafetyLevel

    /// The ONLY way to construct a PlannedItem. Failable by design.
    init?(item: StorageItem, userSelected: Bool)
}
```
**`init?` returns `nil` unless ALL hold:**
1. `userSelected == true`
2. `item.safety.isPlannable` (rejects `.protected`, `.advanced`)
3. `item.isCleanupCandidate == true`
4. `item.objectType != .symlink`
5. `item.url` has **no `.app` path component in its full ancestry**
6. `item.url` is a strict descendant of `item.cleanupRoot`
7. `item.url` is not under any `PathValidator.denyList` entry
8. `item.url.path` is not `/`, not the home directory itself, and has depth ≥ 3

**Invariant.** No other initializer exists. No `init` from `URL`. **Unsafe states are unrepresentable, not merely unchecked.**
**Tests:** T-PLAN-01…08 (one per condition).

### `CleanupPlan.swift`
```swift
struct CleanupPlan: Sendable {
    let id: UUID
    let createdAt: Date
    let items: [PlannedItem]
    var estimatedRecoverableBytes: Int64 { /* scan-global deduped sum */ }
    var itemCount: Int { items.count }
    init?(items: [PlannedItem])   // nil if empty, or if any item is an ancestor of another
}
```
**Invariant.** An empty plan cannot exist. No plan contains both an ancestor and its descendant.

### `CleanupReceipt.swift` — Correction 1
```swift
struct CleanupReceipt: Sendable, Codable {
    let id: UUID
    let planID: UUID
    let startedAt: Date
    let finishedAt: Date
    let wasCancelled: Bool

    let estimatedRecoverableBytes: Int64   // from the plan
    let successfullyTrashedBytes: Int64    // Σ estimatedBytes of .trashed outcomes
    let volumeAvailableBefore: Int64       // MEASURED
    let volumeAvailableAfter: Int64        // MEASURED
    let immediateAvailableDelta: Int64     // after − before. MAY BE ~0 OR NEGATIVE. Report as measured.

    let outcomes: [ItemOutcome]
    let trashLocation: String?             // e.g. "~/.Trash"
    let appVersion: String
    let rulesVersion: String
}

enum ItemOutcome: Sendable, Codable {
    case trashed(itemID: UUID, path: String, bytes: Int64, resultingTrashURL: String?)
    case failed(itemID: UUID, path: String, bytes: Int64, reason: FailureReason)
    case skipped(itemID: UUID, path: String, bytes: Int64, reason: SkipReason)
}
enum FailureReason: String, Codable {
    case permissionDenied, trashUnavailable, crossVolume, fileBusy, readOnlyVolume, unknown
}
enum SkipReason: String, Codable {
    case vanished, becameSymlink, typeChanged, identityChanged, escapedCleanupRoot,
         appBundleAncestor, denyListed, cancelled
}
```

**Terminology contract — MANDATORY, enforced by test T-TERM-01 (string scan of UI sources):**

| Concept | Permitted words | **Forbidden** |
|---|---|---|
| `estimatedRecoverableBytes` | "Estimated recoverable" | "will free", "will reclaim" |
| `successfullyTrashedBytes` | "Moved to Trash" | **"freed"**, **"reclaimed"**, "deleted", "removed" |
| `immediateAvailableDelta` | "Storage immediately available" | "reclaimed" |

**Required post-cleanup UI, verbatim structure:**
```
Estimated recoverable       18.7 GB
Moved to Trash              18.4 GB
Storage immediately available   approximately unchanged
Your files are still in Trash and can be restored.
Empty Trash to permanently reclaim this space.        [Open Trash]
```
When `immediateAvailableDelta` is materially non-zero, report the measured figure honestly, including a negative one ("decreased by 0.2 GB — another process wrote to the disk during cleanup").

**DiskPrune must NEVER empty the Trash.** No API, no button, no v1 feature. `[Open Trash]` opens Finder via `NSWorkspace.shared.open` and nothing else.

**Truth metric** (PART 18 metrics, and a release gate): `successfullyTrashedBytes / estimatedRecoverableBytes`, target ≥ 0.98. **Not** `immediateAvailableDelta / estimated` — that ratio is expected to be ~0 and is not a defect.

## 5.2 Knowledge

### `StorageRule.swift` / `StorageKnowledge.swift`
**Responsibility.** Load, validate, and query the rules corpus. The only Swift code that reads `storage-rules.json`.
```swift
final class StorageKnowledge: Sendable {
    static func load() throws -> StorageKnowledge      // from bundle resource
    func rule(forPath path: String) -> StorageRule?    // longest-prefix match
    func classify(path: String) -> (SafetyLevel, Category, StorageRule?)
    var rulesVersion: String
    var publishedRuleIDs: [String]
}
```
**Matching.** Expand `~`; honor `envOverride` when the env var is set; **longest matching path prefix wins**; a `protected` rule always wins over a non-protected rule of equal or shorter prefix length.
**Default-deny.** No match ⇒ `(.review, .unknown, nil)` — **never `.safe`**. Unclassified items are therefore never pre-selected and never cleanup candidates (`isCleanupCandidate` requires `knowledgeID != nil`).
**Error behavior.** Malformed JSON ⇒ `throw`; app shows an error state and **disables cleanup entirely** (scanning still works). A single invalid rule ⇒ skip that rule, log, continue. Missing resource ⇒ `throw`.
**Concurrency.** Immutable after load; safe to share.
**Tests:** T-RULE-01…08.

## 5.3 Scanning

### `FileIdentity.swift` — the only POSIX in the codebase
```swift
enum FileIdentity {
    struct Stat: Sendable {
        let fileID: FileID; let objectType: ObjectType
        let logicalBytes: Int64      // st_size
        let onDiskBytes: Int64       // st_blocks × 512
        let linkCount: UInt64        // st_nlink
        let modified: Date?
    }
    static func lstat(_ path: String) -> Result<Stat, FileIdentityError>
}
enum FileIdentityError: Error { case notFound, permissionDenied, tooManyLinks, other(Int32) }
```
**Uses `lstat`, never `stat`** — a symlink is identified *as* a symlink and never silently traversed.
**Rationale for POSIX:** Foundation exposes no portable device/inode pair; `URLResourceValues.fileResourceIdentifier` is opaque, awkward to hash, and valid only while the file exists. `st_blocks` is the only value that correctly reflects sparse files and APFS compression.
**Error mapping.** `ENOENT`/`ENOTDIR` → `.notFound`; `EACCES`/`EPERM` → `.permissionDenied`; `ELOOP` → `.tooManyLinks`; else `.other(errno)`.
**Failure behavior.** `.notFound` → skip silently. `.permissionDenied` → record in `deniedPaths`, mark `.partial`. Others → skip and record. **Never throws out of a traversal.**
**Edge case.** `st_blocks == 0` on an exotic filesystem while `st_size > 0` → use `st_size` and flag the item's size approximate.

### `DirectorySizer.swift`
```swift
struct SizeResult: Sendable {
    let onDiskBytes: Int64; let logicalBytes: Int64; let fileCount: Int
    let newestModification: Date?; let scanState: ScanState
    let encounteredFileIDs: Set<FileID>   // hardlinked (st_nlink > 1) inodes only
}
func measure(root: URL, globalSeen: inout Set<FileID>) async -> SizeResult
```
**Algorithm.**
1. `lstat` the entry. `symlink` → count the link's own `st_blocks`, **do not follow**, do not descend.
2. `.app` bundle → measure whole, **do not descend**, emit no children.
3. If `st_nlink > 1`: dedup. Item scope — skip if already in the item's local set. Global scope — see PART 7.3.
4. Directory → count its own `st_blocks`, then recurse. **Depth cap 64.**
5. Cycle guard: a directory `FileID` already on the current path → stop.
6. `Task.isCancelled` checked at every directory boundary.
**Concurrency.** `async`, cooperatively cancellable; never blocks the main thread.
**Tests:** T-SIZE-01…07, T-SYM-01…03, T-HL-01…03, T-SPARSE-01.

### `ScanEngine.swift`
```swift
actor ScanEngine {
    init(knowledge: StorageKnowledge)
    func scan() -> AsyncStream<ScanEvent>
    func cancel()
}
enum ScanEvent: Sendable {
    case started
    case probeStarted(name: String)
    case itemsFound([StorageItem])       // streamed as each probe completes
    case snapshots(SnapshotSummary)
    case coverage(StorageCoverage)
    case finished(ScanState)
}
```
**Invariants — the most important in the app.**
- **`ScanEngine` exposes no mutating filesystem API and imports nothing from `Cleanup/`.** Enforced by CI (PART 20 job 3).
- Holds the scan-global `Set<FileID>` used for aggregate deduplication (PART 7.3).
- Results stream; the UI renders partial results while the scan continues.
**Concurrency.** `actor`. UI observes on `@MainActor`. Cancellation ≤ 500 ms.
**Failure behavior.** A probe that throws is caught; its section reports "couldn't be read"; the scan continues. **One probe failing never fails the scan.**

### `SnapshotInspector.swift` — see PART 10
### Probes — see PART 9

## 5.4 Cleanup

### `PathValidator.swift`
```swift
enum PathValidator {
    static let denyList: [String]      // §9.2 of Mega Plan v2, expanded below
    static func validateForPlanning(_ item: StorageItem) -> Bool
    static func revalidateBeforeTrash(_ planned: PlannedItem) -> Result<Void, SkipReason>  // the seven checks
}
```
**Deny list (absolute, not user-overridable):** `~/Documents` · `~/Desktop` · `~/Downloads` · `~/Pictures` · `~/Movies` · `~/Music` · `~/Library/Mobile Documents` · `~/Library/Keychains` · `~/Library/Messages` · `~/Library/Mail` · `~/Library/Photos` · `~/Library/Application Support/MobileSync` · `~/.ssh` · `~/.gnupg` · `~/.aws` · `~/.config/gcloud` · `/System` · `/Library/Apple` · `/private/var/db` · `/Applications` · **any path containing a `.app` component.**

### `CleanupExecutor.swift`
```swift
actor CleanupExecutor {
    /// The ONLY destructive entry point in the application.
    func execute(plan: CleanupPlan,
                 verifier: SpaceVerifier,
                 progress: @Sendable (Int, Int) -> Void) async -> CleanupReceipt
}
```
**Signature is the contract.** One parameter of type `CleanupPlan`. **No overload accepting `[URL]`, `[StorageItem]`, or a `ScanEngine`.** The type holds no reference to `ScanEngine` and cannot obtain one.
**The only filesystem-mutating call in the entire codebase is `FileManager.default.trashItem(at:resultingItemURL:)`.**
**Never falls back to `removeItem`.** If Trash is impossible, the item is skipped and reported. See PART 6.

### `SpaceVerifier.swift`
```swift
struct VolumeSpace: Sendable { let total: Int64; let available: Int64; let measuredAt: Date }
enum SpaceVerifier {
    static func measure(volumeContaining url: URL) -> VolumeSpace?
}
```
Uses `.volumeAvailableCapacityForImportantUsageKey` (falls back to `.volumeAvailableCapacityKey`). Called immediately before the first trash and immediately after the last. `nil` on failure → receipt records the delta as unavailable rather than zero.

## 5.5 Persistence — Correction 5

**The write boundary, stated precisely:**

> **Only `CleanupExecutor` may mutate user-managed filesystem content.**
> Application-owned persistence is permitted in `Persistence/` and `Licensing/KeychainStore` and is not a destructive operation.

| Component | Writes | Permitted |
|---|---|---|
| `CleanupExecutor` | `trashItem` on user content | **Yes — sole destructive authority** |
| `ReceiptStore` | JSON into `~/Library/Application Support/com.diskprune.app/Receipts/` | Yes (app-owned) |
| `PreferencesStore` | `UserDefaults` | Yes (app-owned) |
| `KeychainStore` | Keychain items under `com.diskprune.app` | Yes (app-owned) |
| Everything else | nothing | **No** |

CI guardrails therefore target **destructive APIs**, not all filesystem writes (PART 20 job 3). `createDirectory`, `write(to:)`, and `Data.write` are permitted in `Persistence/`.

### `ReceiptStore.swift`
```swift
enum ReceiptStore {
    static func save(_ receipt: CleanupReceipt) throws -> URL
    static func list() -> [URL]
    static func load(_ url: URL) throws -> CleanupReceipt
}
```
Filename `receipt-<ISO8601>-<uuid-prefix>.json`. Pretty-printed, stable key order. **This file is the future audit-log payload** — keep it machine-readable and versioned. A save failure never fails the cleanup; it is surfaced as a non-blocking warning.

## 5.6 Permissions

### `FullDiskAccess.swift`
```swift
enum FullDiskAccess {
    static func probeLikelyGranted() -> Bool    // heuristic ONLY — never presented as proof
    static func openSystemSettings()
}
```
**Attempt-first, never gate.** The scan runs regardless. Denied paths are collected during traversal; if any exist, a **non-blocking** banner appears: *"Some locations couldn't be read. macOS privacy settings may be limiting results."* + list + `[Open System Settings]`. Scan marked `.partial`. Re-probe on `NSApplication.didBecomeActiveNotification` and offer a rescan if the situation changed.
**Prohibited:** any copy asserting FDA is or is not granted based on `probeLikelyGranted()`. It informs the *ordering* of guidance, nothing more.

## 5.7 Licensing — see PARTS 11–13

| Type | Responsibility |
|---|---|
| `PublicKeys.swift` | `static let byKid: [String: Curve25519.Signing.PublicKey]`. **Public keys only. The private key never exists in this repository's app target.** |
| `LicenseToken.swift` | Parse + verify the compact token. Pure, no I/O, fully unit-testable. |
| `DeviceIdentity.swift` | Random UUID in Keychain (Correction: **no hardware identifiers**). |
| `KeychainStore.swift` | Typed Keychain wrapper. `kSecAttrService = "com.diskprune.app"`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. |
| `LicenseManager.swift` | `@MainActor` observable. `var entitlements: Set<String>`; `var canClean: Bool { entitlements.contains("cleanup") }`. Activation, refresh, release. **Never derives entitlement from the presence of a Keychain item.** |

## 5.8 UI

| View | Shows | Empty / error / partial state |
|---|---|---|
| `RootView` | Navigation shell | — |
| `ScanView` | Real per-probe progress with named steps | **No indeterminate spinner as the primary indicator** |
| `StorageAutopsyView` | `StorageCoverage` per PART 7.4; top contributors; one plain-English sentence | "DiskPrune didn't find significant reclaimable data" — a designed state, not a zero |
| `ResultsView` | Grouped items; checkboxes; `safe` pre-checked, `review` not; `protected` shown with explanation and **no checkbox** | Per-section empty states |
| `ItemDetailView` | Path, on-disk size, logical size, file count, last modified, explanation, consequence, how it comes back, docs link | "Unclassified — DiskPrune doesn't have a rule for this location" |
| `CleanupPlanView` | Selected items, running total, **"Nothing has changed yet"** | Cleanup button disabled when plan is empty |
| `DryRunSheet` | Count, estimated bytes, safe/review split, "Files will be moved to Trash. Nothing will be permanently deleted." `[Cancel]` `[Move to Trash]` | — |
| `ReceiptView` | The exact four-line block from §5.1 + per-item successes, failures, skips with reasons | "All items were skipped" is a legitimate outcome and must render honestly |
| `SnapshotView` | Count, dates, explanation, Apple docs link, the Terminal command with its warning | "No local snapshots found" · "Couldn't read snapshots" |
| `LicenseView` | Status, device list with last-seen, `[Release]` per device, activation field, `[Buy]` | Clear seat-exhaustion message naming the fix |

---

# PART 6 — EXACT CLEANUP CONTRACT

## 6.1 The only permitted data flow

```
ScanEngine ──▶ [StorageItem] ──▶ user selection ──▶ PlannedItem.init?(item:userSelected:)
                                                          │ (failable — 8 conditions)
                                                          ▼
                                                    CleanupPlan.init?(items:)
                                                          │ (non-empty, no ancestor/descendant pairs)
                                                          ▼
                        ┌───────── CleanupExecutor.execute(plan:verifier:progress:)
                        │                     │
                        │        per item ────┼──▶ PathValidator.revalidateBeforeTrash  (7 checks)
                        │                     │              │ pass          │ fail
                        │                     │              ▼               ▼
                        │                     │   FileManager.trashItem   .skipped(reason)
                        │                     ▼
                        └─────────────▶ CleanupReceipt ──▶ ReceiptStore.save
```

## 6.2 Structurally prohibited

| Prohibited | Enforcement |
|---|---|
| `ScanEngine → CleanupExecutor` | `Cleanup/` imports nothing from `Scanning/`. CI job 3 greps for it. |
| `[URL] → CleanupExecutor` | No such initializer or method exists. Compile error. |
| `[StorageItem] → CleanupExecutor` | No such overload. Compile error. |
| Constructing `PlannedItem` any other way | `init?` is the only initializer; the struct has no memberwise init (all stored properties `let`, explicit `private` memberwise suppression via the single `init?`). |
| Any destructive call outside `CleanupExecutor` | CI job 3. |

**Grok: if you find yourself needing to pass a URL array into the executor, the design is being violated. Stop and report.**

## 6.3 The seven TOCTOU checks — exact order

Executed by `PathValidator.revalidateBeforeTrash(_:)` **immediately before every individual `trashItem`**, not once per batch:

| # | Check | Fail → `SkipReason` |
|---|---|---|
| 1 | `FileIdentity.lstat(path)` succeeds — object still exists | `.vanished` |
| 2 | `objectType != .symlink` — the path did not become a symlink | `.becameSymlink` |
| 3 | `objectType == planned.objectType` — a directory is still a directory | `.typeChanged` |
| 4 | `fileID == planned.fileID` — same `(st_dev, st_ino)`; catches replace-with-different-object | `.identityChanged` |
| 5 | `url.resolvingSymlinksInPath().standardized` is still a strict descendant of `planned.cleanupRoot` | `.escapedCleanupRoot` |
| 6 | No `.app` component anywhere in the resolved ancestry | `.appBundleAncestor` |
| 7 | Not under any `PathValidator.denyList` entry | `.denyListed` |

**Documented limitation, to be stated in the security notes and never overclaimed:** a window remains between check 1 and `trashItem`. These checks close the realistic race, not a theoretical one. **The actual mitigation is reversibility — the item goes to Trash, not oblivion.**

## 6.4 Per-item error handling

```
for (index, item) in plan.items.enumerated() {
    if Task.isCancelled { record .skipped(.cancelled) for the remainder; break }
    switch PathValidator.revalidateBeforeTrash(item) {
    case .failure(let reason): record .skipped(reason); continue
    case .success: break
    }
    do   { try FileManager.default.trashItem(at:resultingItemURL:) ; record .trashed(...) }
    catch { record .failed(mapped(error)) }        // ← EVERY item wrapped individually
    progress(index + 1, plan.items.count)
}
```
**Invariants.**
- **`execute` never throws and never returns early on failure.** It always returns a complete receipt.
- One failure never aborts the batch. (This is the direct fix for B-7.)
- **No `removeItem` fallback under any circumstance.**

## 6.5 Batch, cancellation, and failure semantics

| Situation | Behavior |
|---|---|
| Batch ordering | Deepest paths first, so a parent is never trashed before a sibling subtree is evaluated. Plans contain no ancestor/descendant pairs anyway. |
| Cancellation mid-batch | Completed items stay trashed (correct — they are in Trash and recoverable). Remaining items → `.skipped(.cancelled)`. `receipt.wasCancelled = true`. **No rollback attempt.** |
| Trash unavailable / cross-volume | `.failed(.trashUnavailable)` or `.failed(.crossVolume)`. **Skip. Never delete instead.** |
| Permission denied | `.failed(.permissionDenied)` with UI text "Grant Full Disk Access in System Settings". |
| Item disappeared before trash | `.skipped(.vanished)` — not an error; something else removed it. |
| Item changed identity | `.skipped(.identityChanged)` — the object was replaced; refuse. |
| All items fail | Honest receipt: "0 items moved to Trash" plus every reason. **Never render as success.** |
| `SpaceVerifier` returns nil | Receipt records availability as unavailable, not `0`. |

---

# PART 7 — EXACT STORAGE ACCOUNTING CONTRACT

## 7.1 Measurement classification

| Value | Source | Class |
|---|---|---|
| `logicalBytes` | Σ `st_size` | **MEASURED** |
| `onDiskBytes` | Σ `st_blocks × 512` | **MEASURED** |
| `fileCount` | traversal count | **MEASURED** |
| `volumeTotal/Available/Used` | `URLResourceValues` | **MEASURED** |
| `classifiedBytes`, `unclassifiedScannedBytes`, `examinedBytes`, `cleanupCandidateBytes` | scan-global deduped sums | **MEASURED** |
| `notExaminedBytes` | `volumeUsed − examined` | **DERIVED** — label "not examined", never "other" |
| `permissionLimitedBytes` | — | **UNKNOWN — always `nil` in v1. Never estimated.** |
| Sizes on a `.partial` item | truncated traversal | **APPROXIMATE** — render "at least X" |
| APFS clone sharing | not modelled | **UNKNOWN — explicitly disclosed** |

## 7.2 Filesystem semantics — exact

| Case | Behavior | Accuracy |
|---|---|---|
| **Hardlinks** | Deduplicated by `FileID` at both item scope and scan-global scope when `st_nlink > 1` | Accurate |
| **Sparse files** (`Docker.raw`) | `st_blocks × 512` reflects allocated blocks, not logical length | Accurate. Detail view shows both; when `logical > 2 × onDisk`, label "sparse file" |
| **APFS compression** | `st_blocks` reflects compressed allocation | Accurate |
| **APFS clones** | **NOT deduplicated.** `st_blocks` counts shared blocks for each clone, so two clones of a 1 GB file each report 1 GB while removing one frees ~nothing | **Inaccurate by design. DISCLOSED — see 7.5.** DiskPrune does not claim clone-aware accounting. |
| **Directories** | The directory's own `st_blocks` is counted, plus its contents | Accurate |
| **Symlinks** | `lstat` only. The link's own `st_blocks` counted; **the target is never followed or counted** | Accurate |
| **Permission-denied regions** | Excluded from all totals; path recorded; item `.partial` | Honest omission |
| **`.app` bundles** | Measured whole, never descended, never a cleanup candidate | Accurate |

## 7.3 Hardlink deduplication scope — Correction 7

Two scopes, deliberately different, because they answer different questions:

| Scope | Owner | Purpose | Rule |
|---|---|---|---|
| **Item-local** | `DirectorySizer` local `Set<FileID>` | "How big is this item on its own?" | Within one item, a hardlinked inode counts once |
| **Scan-global** | `ScanEngine` global `Set<FileID>`, passed `inout` | "How much of this disk do these items account for?" | Across the whole scan, a hardlinked inode counts once — **first item to encounter it owns those bytes for aggregate purposes** |

**Consequence, which must be handled and not hidden:** `Σ item.onDiskBytes` **may exceed** `coverage.classifiedBytes` when items share hardlinked content.

**Rules:**
- **All volume-wide and category aggregates use scan-global deduplicated figures** (`StorageCoverage`, Autopsy totals, `CleanupPlan.estimatedRecoverableBytes`).
- **Per-item displays use `item.onDiskBytes`** (item-local dedup).
- **The UI must never sum per-item figures to produce a headline total.** Totals come from `StorageCoverage` and `CleanupPlan`. Enforced by test T-HL-04.
- Probes execute sequentially in a fixed, documented order so global-dedup ownership is deterministic and reproducible across runs.

## 7.4 Coverage display rules

Required Autopsy structure:
```
This Mac                     512 GB total · 418 GB used · 94 GB available
DiskPrune examined            94.2 GB
  Explained (classified)      82.1 GB
  Scanned but unclassified    12.1 GB
Not examined                 323.8 GB
3 locations couldn't be read — results may be incomplete.   [Why?]

Reclaimable candidates        38.4 GB
```
**Prohibited:** presenting `classifiedBytes` as the Mac's used space · filling `notExaminedBytes` with a guessed breakdown · omitting the permission-limited notice when denials occurred · using the word "Other" for `notExaminedBytes`.

## 7.5 Required disclosure copy

A `/support` page section and an in-app "Why don't the numbers match?" link must state, in substance:

> DiskPrune reports **space on disk** — the blocks a file actually occupies. That is why a figure can differ from Finder. It correctly accounts for compressed files, sparse files, and hard links. It does **not** currently detect APFS clones: when two files share the same underlying blocks, DiskPrune counts them separately, so removing one may free less than its listed size. Moving files to the Trash does **not** immediately increase available storage — the files are still on the disk until you empty the Trash.

## 7.6 Cleanup accounting values — Correction 1

| Value | When measured | Definition |
|---|---|---|
| `estimatedRecoverableBytes` | Plan construction | Scan-global deduped Σ of planned items' on-disk size |
| `volumeAvailableBefore` | Immediately before first trash | `SpaceVerifier.measure` |
| `successfullyTrashedBytes` | During execution | Σ `estimatedBytes` of `.trashed` outcomes |
| `volumeAvailableAfter` | Immediately after last trash | `SpaceVerifier.measure` |
| `immediateAvailableDelta` | Derived | `after − before`. **Expected ≈ 0 for same-volume Trash. May be negative.** Reported as measured. |

**UI before cleanup:** "Estimated recoverable: 18.7 GB · Files will be moved to Trash. Nothing will be permanently deleted."
**UI after cleanup:** the exact four-line block in §5.1.
**Forbidden anywhere:** "18 GB freed" as a consequence of trashing. Test T-TERM-01 fails the build on the strings `freed`, `reclaimed`, `deleted`, `removed` in `UI/` receipt-rendering code paths.

---

# PART 8 — STORAGE KNOWLEDGE RULES

## 8.1 Canonical location

**`/shared/storage-rules.json` is the only file edited by hand.** `app/Sources/DiskPrune/Knowledge/Resources/storage-rules.json` is generated and carries `"generated": true`.

## 8.2 Schema (`/shared/storage-rules.schema.json`, JSON Schema draft 2020-12)

```jsonc
{
  "schemaVersion": 1,
  "rulesVersion": "2026.09.1",           // required, semver-ish; surfaced in receipts
  "rules": [
    {
      "id": "xcode-deriveddata",          // ^[a-z0-9]+(-[a-z0-9]+)*$ · UNIQUE · also the /storage/ slug
      "paths": ["~/Library/Developer/Xcode/DerivedData"],  // ≥1; "~/" or "/" prefix only
      "envOverride": "DERIVED_DATA_PATH", // optional
      "displayName": "Xcode DerivedData",
      "category": "developerBuild",       // enum, must match Swift Category
      "safety": "safe",                   // safe | review | advanced | protected
      "regenerable": true,
      "producer": "Xcode",
      "explanation": "…",                 // required, non-empty, ≥40 chars
      "consequence": "…",                 // required, non-empty, ≥40 chars
      "howItComesBack": "…",              // required if regenerable === true
      "minMacOS": "14.0",
      "docsURL": "https://…",             // string URL or explicit null
      "lastReviewed": "2026-09-08",       // required, ISO date
      "publish": true                     // gates /storage/<id> page generation
    }
  ]
}
```
**Additional constraints, all enforced by `validate-rules.mjs` and by Swift tests:**
- `id` unique across the file.
- `explanation` and `consequence` non-empty and ≥40 characters (prevents placeholder text shipping).
- `docsURL` must be present as either a `https://` URL or an explicit `null` — the key may not be omitted.
- `safety: "protected"` rules must have `publish: false`.
- `additionalProperties: false` at every level.

## 8.3 Path precedence, default-deny, protected override

1. Expand `~`; if `envOverride` is set in the environment, that value replaces `paths[0]` for matching.
2. **Longest matching path prefix wins.**
3. **A `protected` rule wins over any non-protected rule** whose prefix is equal or shorter.
4. **No match ⇒ `(.review, .unknown, knowledgeID: nil)`.** Never `.safe`. `isCleanupCandidate` is `false` because `knowledgeID == nil`, so unclassified data can never be planned.

## 8.4 Launch corpus (~25 rules; ~10 with `publish: true`)

`safe`: xcode-deriveddata · xcode-modulecache · npm-cacache · pnpm-store · yarn-cache · cargo-registry-cache · gradle-caches · maven-repository · cocoapods-cache · spm-cache · homebrew-cache · user-caches · user-logs
`review`: xcode-archives · xcode-devicesupport · xcode-simulators · cargo-target · system-logs · containers · application-support
`advanced` (inspect-only, never a candidate): docker-raw · apfs-local-snapshots
`protected`: the full PART 5.4 deny list, one rule per entry

## 8.5 Build integration

**Native.** `scripts/sync-rules.sh` copies `shared/storage-rules.json` → `app/.../Knowledge/Resources/storage-rules.json`, injecting `"generated": true, "source": "/shared/storage-rules.json"`. `Package.swift` declares `resources: [.process("Knowledge/Resources")]`.
**Astro.** Imports `/shared/storage-rules.json` **directly** — no copy. `astro.config.mjs` allows the parent-directory import.
**CI drift gate (mandatory, PART 20 job 5).** Re-run `sync-rules.sh` into a temp path and `diff` against the committed copy. Any difference fails with: `storage-rules.json drift detected — edit /shared/storage-rules.json and run scripts/sync-rules.sh`.
**Prohibited:** a second hand-maintained rules source anywhere, including in `web/src/data/`.

---

# PART 9 — SCANNER PROBES

**Common contract.** Every probe conforms to:
```swift
protocol Probe: Sendable {
    var name: String { get }
    func discover(knowledge: StorageKnowledge, globalSeen: inout Set<FileID>) async -> [StorageItem]
}
```
**Universal rules.** A missing tool yields an **empty array and no error and no empty UI section**. A probe never throws out of `discover`. Permission denial marks the affected item `.partial` and never fails the probe. Probes run in a **fixed documented order** (Xcode → Docker → PackageManager → Cache → Log) so scan-global hardlink ownership is deterministic.

## 9.1 XcodeProbe

| Target | Discovery | Grouping | Safety | Cleanable in v1 |
|---|---|---|---|---|
| DerivedData | `~/Library/Developer/Xcode/DerivedData` (honor `DERIVED_DATA_PATH`) | **One item per project folder** (`Name-hash`). Parse the leading name for display; show `newestModification` as "last built N months ago". | `safe` | **Yes** |
| ModuleCache | `.../DerivedData/ModuleCache.noindex` | One item | `safe` | Yes |
| Archives | `~/Library/Developer/Xcode/Archives` | One item per date folder | `review` | Yes |
| iOS DeviceSupport | `~/Library/Developer/Xcode/iOS DeviceSupport` | **One item per OS version** | `review` | Yes |
| Simulators | `~/Library/Developer/CoreSimulator/Devices` | One item per device UDID; read `device.plist` for runtime and name; flag runtimes absent from `~/Library/Developer/CoreSimulator/Profiles/Runtimes` as "unavailable" | `review` | Yes — but surface `xcrun simctl delete unavailable` as the **recommended** route |

**Failure behavior.** No Xcode → empty. Unparseable `device.plist` → include the item with a generic name; never guess.
**Tests:** T-XC-01…05.

## 9.2 DockerProbe — inspect-only

**Discovery (probe all; never one hardcoded path):**
```
~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw
~/Library/Containers/com.docker.docker/Data/vms/0/Docker.raw
~/.docker/desktop/vms/0/data/Docker.raw
~/Library/Containers/com.docker.docker/Data/                 (directory total, fallback)
~/.colima/                                                    (Colima)
~/.orbstack/                                                  (OrbStack)
```
**Daemon detection.** Socket presence at `/var/run/docker.sock` **or** `~/.docker/run/docker.sock`, plus a running-process check. Result is **informational only** — it does not change cleanability.

**Behavior — absolute:**
- `safety: .advanced`, `isCleanupCandidate: false`, **whether the daemon is running or stopped.**
- **`Docker.raw` and every Docker data directory are NEVER cleanup targets in v1.**
- The detail view reports the size, explains that the file is sparse and does not shrink when containers are removed, and shows the Docker-native commands with what each affects:
  `docker system prune -a` · `docker builder prune` · `docker volume prune` — each with a one-line consequence and a link to Docker's docs.
- Show both logical and on-disk size and label it a sparse file.
- If the layout is unrecognised: report what was found and say the layout is unfamiliar. **Never guess.**

**Rationale for Grok:** deleting `Docker.raw` while the daemon runs corrupts state; deleting it while stopped destroys every image, container, and volume. Neither is an outcome a user expects from "clean up caches". DiskPrune does not own Docker's storage lifecycle.
**Tests:** T-DOCK-01…05.

## 9.3 PackageManagerProbe

| Manager | Path (env override) | Grouping | Safety | v1 |
|---|---|---|---|---|
| npm | `~/.npm/_cacache` (`npm_config_cache`) | one | safe | Yes |
| pnpm | `~/Library/pnpm/store`, `~/.pnpm-store` (`PNPM_HOME`) | one | safe | Yes |
| Yarn | `~/Library/Caches/Yarn`, `~/.yarn/berry/cache` | one per location | safe | Yes |
| Cargo registry | `~/.cargo/registry/cache` (`CARGO_HOME`) | one | safe | Yes |
| Cargo target | discovered `target/` dirs — **not scanned in v1** | — | — | **No** (risk of deleting an active build tree) |
| Gradle | `~/.gradle/caches` (`GRADLE_USER_HOME`) | one | safe | Yes |
| Maven | `~/.m2/repository` (`MAVEN_OPTS` ignored; honor `~/.m2/settings.xml` only if trivially parseable, else default) | one | safe | Yes |
| CocoaPods | `~/Library/Caches/CocoaPods` | one | safe | Yes |
| SPM | `~/Library/Caches/org.swift.swiftpm` | one | safe | Yes |
| Homebrew | `~/Library/Caches/Homebrew` (`HOMEBREW_CACHE`) | one | safe | Yes — surface `brew cleanup` as the alternative |

**Tests:** T-PKG-01…04 (env overrides honored; absent tools yield nothing).

## 9.4 CacheProbe / LogProbe

`~/Library/Caches` → **one item per top-level subdirectory**, classified individually against the rules (a subdirectory matching a `protected` rule is excluded). `~/Library/Logs` → one item. `/Library/Logs` → one item, `review`, and **expected to fail at trash time without elevation** — mark it clearly and let the receipt report the failure honestly rather than pre-filtering it silently.
**Tests:** T-CACHE-01…03.

---

# PART 10 — SNAPSHOT CONTRACT

**Snapshots are READ-ONLY. There is no deletion API anywhere in the product.**

```swift
struct SnapshotSummary: Sendable { let count: Int; let dates: [Date]; let readFailed: Bool }
enum SnapshotInspector {
    static func list() async -> SnapshotSummary     // the ONLY function in this type
}
```

| Aspect | Specification |
|---|---|
| Command | **`/usr/bin/tmutil listlocalsnapshots /` and nothing else.** The single allow-listed `Process` invocation in the app. |
| Timeout | **5 seconds.** On timeout: terminate the process, return `readFailed: true`. |
| Parsing | Lines matching `com.apple.TimeMachine.<yyyy-MM-dd-HHmmss>(.local)?`. Unparseable lines ignored. |
| Failure | Non-zero exit, empty output, or garbage → `readFailed: true` → UI shows "Couldn't read snapshots". **Never an error dialog.** |
| Zero snapshots | Designed empty state: "No local snapshots found." |
| UI | Count, dates, explanation that macOS keeps them for local restore and normally reclaims the space automatically under pressure; link to Apple's documentation; the Terminal command shown **as text the user may choose to run**, with an explicit statement of what is lost. |
| **Prohibited everywhere** | `tmutil deletelocalsnapshots` in any production source · any "flush", "purge snapshots", or "free purgeable space" action · snapshot bytes in any cleanup total · marketing copy implying DiskPrune deletes snapshots |

**Consistency requirement.** Native app, demo, website copy, README, tests, and CI guardrails must all agree. Test T-SNAP-03 greps the entire repository (excluding this specification and `/support` explanatory prose) for `deletelocalsnapshots` and fails on any hit in source.

---

# PART 11 — LICENSING IMPLEMENTATION SPEC

## 11.1 D1 schema — `worker/migrations/0001_init.sql`

```sql
CREATE TABLE products (
  stripe_price_id   TEXT PRIMARY KEY,
  license_type      TEXT NOT NULL,
  entitlements_json TEXT NOT NULL,          -- '["cleanup"]'
  max_devices       INTEGER NOT NULL,       -- CONFIG, not a constant
  created_at        INTEGER NOT NULL
);

CREATE TABLE licenses (
  id                    TEXT PRIMARY KEY,               -- uuid; used as AES-GCM AAD
  key_hash              TEXT NOT NULL UNIQUE,           -- SHA-256 hex of the plaintext key
  encrypted_key         TEXT NOT NULL,                  -- 'v1.<b64url iv>.<b64url ct||tag>'  ← Correction 2
  email                 TEXT NOT NULL,
  license_type          TEXT NOT NULL,
  entitlements_json     TEXT NOT NULL,
  max_devices           INTEGER NOT NULL,
  org_id                TEXT,                           -- reserved; always NULL in v1
  status                TEXT NOT NULL,                  -- 'active' | 'disputed' | 'revoked'
  stripe_session_id     TEXT NOT NULL UNIQUE,
  stripe_customer_id    TEXT,
  email_state           TEXT NOT NULL,                  -- 'pending' | 'sent' | 'failed'
  email_attempts        INTEGER NOT NULL DEFAULT 0,
  email_last_attempt_at INTEGER,
  created_at            INTEGER NOT NULL,
  updated_at            INTEGER NOT NULL
);
CREATE INDEX idx_licenses_email  ON licenses(email);
CREATE INDEX idx_licenses_status ON licenses(status);
CREATE INDEX idx_licenses_email_state ON licenses(email_state);

CREATE TABLE fulfillments (                              -- PERMANENT. No TTL, ever.
  stripe_session_id TEXT PRIMARY KEY,                    -- ← the idempotency guarantee
  license_id        TEXT,
  state             TEXT NOT NULL,                       -- 'pending' | 'fulfilled' | 'failed'
  created_at        INTEGER NOT NULL,
  updated_at        INTEGER NOT NULL
);

CREATE TABLE events (                                    -- PERMANENT audit trail
  stripe_event_id TEXT PRIMARY KEY,
  type            TEXT NOT NULL,
  received_at     INTEGER NOT NULL
);

CREATE TABLE devices (
  license_id  TEXT NOT NULL,
  device_id   TEXT NOT NULL,                             -- random UUID from the client
  device_name TEXT,
  first_seen  INTEGER NOT NULL,
  last_seen   INTEGER NOT NULL,
  released_at INTEGER,                                   -- NULL ⇒ occupies a seat
  PRIMARY KEY (license_id, device_id)
);
CREATE INDEX idx_devices_active ON devices(license_id) WHERE released_at IS NULL;
```

## 11.2 License key format and encryption at rest — Correction 2

**Generation.** `crypto.getRandomValues(new Uint8Array(16))` → Crockford base32 (alphabet `0123456789ABCDEFGHJKMNPQRSTVWXYZ`, excluding I/L/O/U) → `PRUNE-XXXXX-XXXXX-XXXXX-XXXXX` (20 chars ≈ 100 bits). **`Math.random()` is prohibited.**

**Encryption.** AES-256-GCM via WebCrypto.

| Aspect | Specification |
|---|---|
| Key | `LICENSE_ENCRYPTION_KEY` — 32 raw bytes, base64, **Wrangler secret only**. Never in the repo, never in `wrangler.toml`. |
| IV / nonce | **Fresh 12 random bytes per encryption**, from `crypto.getRandomValues`. Never reused. |
| AAD | `licenses.id` (the row UUID) — binds ciphertext to its row and defeats cut-and-paste between rows. |
| Ciphertext representation | `v1.<base64url(iv)>.<base64url(ciphertext ‖ tag)>` stored in `licenses.encrypted_key`. The `v1.` prefix is the rotation handle. |
| Encryption boundary | `worker/src/crypto.js` — `encryptLicenseKey(plaintext, licenseId, env)` / `decryptLicenseKey(stored, licenseId, env)`. **No other module calls WebCrypto for this purpose.** |
| Decrypt call sites — exhaustive | (1) initial email send, (2) `/v1/licenses/resend`, (3) the email retry sweep. **Three sites. No fourth.** |
| Plaintext lifetime in memory | Generation → hash → encrypt → store → email → **drop the reference.** Never assigned to a variable that outlives the request handler. |
| Rotation | Introduce `LICENSE_ENCRYPTION_KEY_V2`; write `v2.`, read both; re-encrypt lazily on each successful decrypt; a one-shot script sweeps the remainder; remove `v1` once `SELECT COUNT(*) WHERE encrypted_key LIKE 'v1.%'` is zero. |

**The plaintext license key must NEVER appear in:** logs (Worker or otherwise) · URLs or query strings · any browser-reachable response · analytics · Stripe metadata or description fields · a plaintext D1 column · error messages or stack traces · Resend metadata (body only).
**Permitted in logs:** the first 8 characters of `key_hash`, for correlation.
**Tests:** T-ENC-01…05.

## 11.3 Lifecycle states and the dispute lifecycle — Correction 4

```
                 charge.refunded ──────────────────────────▶ revoked
active ──── charge.dispute.created ─▶ disputed ─── closed(lost) ─▶ revoked
                                          └──────── closed(won) ─▶ active
```

| Status | New activation | Refresh | Existing token |
|---|---|---|---|
| `active` | Allowed | Allowed → **90-day** token | Valid to `exp` |
| `disputed` | **Blocked** — `409 LICENSE_DISPUTED` | **Allowed → 14-day token** | Remains valid to `exp` |
| `revoked` | Blocked — `403 LICENSE_REVOKED` | **Blocked** — `403 LICENSE_REVOKED` | Remains valid to `exp`, then cleanup disables |

**Why refresh is permitted while disputed, with a shortened token:** a dispute can be won, and a legitimate customer must not be locked out over an unresolved bank enquiry. The shortened 14-day token means the eventual resolution — either direction — reaches them quickly. **Do not revoke on `charge.dispute.created`.**
**Tests:** T-DISP-01…05.

## 11.4 Activation — transaction semantics

```
POST /v1/licenses/activate   { license_key, device_id, device_name? }
```
1. Validate key format by regex **before any database read**. Invalid → `400 INVALID_FORMAT`.
2. `SELECT * FROM licenses WHERE key_hash = ?`. Absent → `404 LICENSE_NOT_FOUND`.
3. `status == 'revoked'` → `403 LICENSE_REVOKED`. `status == 'disputed'` → `409 LICENSE_DISPUTED`.
4. **Single D1 transaction:**
   - Existing row for `(license_id, device_id)` with `released_at IS NULL` → update `last_seen`.
   - Existing row with `released_at IS NOT NULL` → **re-activate** (set `released_at = NULL`) **only if** the active seat count is below `max_devices`; else `409 SEAT_LIMIT`.
   - No row → count `WHERE released_at IS NULL`; `< max_devices` → insert; else `409 SEAT_LIMIT` with the device list (`device_name`, `last_seen`) so the app can offer a release.
5. Issue a token (PART 12).

## 11.5 Refresh — Correction 3

```
POST /v1/licenses/refresh   { token }
```
**Exact ordered chain. Every step is mandatory.**
1. Verify token signature and `kid`. Invalid → `401 INVALID_TOKEN`.
2. Resolve `license` from `sub` (key hash) and `device` from `dev`. Absent → `404`.
3. `licenses.status == 'revoked'` → **`403 LICENSE_REVOKED`**.
4. Device row exists for `(license_id, dev)` → else **`403 DEVICE_UNKNOWN`**.
5. **`devices.released_at IS NULL` → else `403 DEVICE_RELEASED`.**
6. Update `last_seen`.
7. Issue a new token: 90 days if `active`, **14 days if `disputed`**.

**An expired-but-cryptographically-valid token is still accepted for refresh** (steps 1–5 do not check `exp`), so a customer who was offline past expiry can renew rather than being locked out. A **released** or **revoked** license can never refresh, expired or not.
**Tests:** T-REF-01…06.

## 11.6 Release

```
POST /v1/licenses/release   { license_key, device_id }
```
Sets `released_at = now()`. Idempotent. Frees the seat immediately. The released device's **existing token remains locally valid until `exp`** (the offline model has no revocation channel), but **can never be refreshed** (§11.5 step 5). This is stated plainly in the License screen so the behavior is not surprising.

## 11.7 Rate limits and CORS

| Endpoint | Limit |
|---|---|
| `POST /webhook` | none (Stripe-signed) |
| `POST /v1/licenses/activate` | 10/hour per IP **and** 20/hour per `key_hash` |
| `POST /v1/licenses/refresh` | 60/hour per IP |
| `POST /v1/licenses/release` | 10/hour per IP |
| `POST /v1/licenses/resend` | **3/hour per IP and 3/day per email** |
| `GET /v1/checkout/:id/status` | 30/hour per IP |

Implementation: KV counters with a 1-hour TTL — approximate limiting is acceptable and appropriate here.
**CORS:** `Access-Control-Allow-Origin: https://diskprune.com` only. **Never `*`.** The native app is not a browser and is unaffected.

## 11.8 API contracts

| Endpoint | Request | Success | Errors |
|---|---|---|---|
| `POST /webhook` | Stripe raw body + `stripe-signature` | `200 {received:true}` | `400` bad signature; `500` DB failure **so Stripe retries** |
| `POST /v1/licenses/activate` | `{license_key, device_id, device_name?}` | `200 {token, expires_at, max_devices, entitlements}` | `400`,`403`,`404`,`409`,`429` |
| `POST /v1/licenses/refresh` | `{token}` | `200 {token, expires_at}` | `401`,`403`,`404`,`429` |
| `POST /v1/licenses/release` | `{license_key, device_id}` | `200 {released:true, seats_available}` | `400`,`404`,`429` |
| `POST /v1/licenses/resend` | `{email}` | **always `200 {ok:true}`** (no enumeration) | `429` |
| `GET /v1/checkout/:session_id/status` | — | `200 {payment_state, delivery_state, email_masked}` | `404`,`429` |

**`GET /v1/checkout/:session_id/status` returns no key, no token, and nothing that retrieves either.** `email_masked` is `a•••@example.com`.

---

# PART 12 — CRYPTOGRAPHIC TOKEN SPEC

## 12.1 Format

Compact JWS-style: `base64url(header) + "." + base64url(payload) + "." + base64url(signature)`

```jsonc
// header
{"alg":"EdDSA","typ":"DPL","kid":"k1"}

// payload
{"v":1,
 "jti":"<uuid>",
 "sub":"<sha256 hex of the license key>",   // never the key itself
 "dev":"<device_id uuid>",
 "ent":["cleanup"],
 "lt":"personal",
 "md":3,                                     // max_devices — from the products row
 "org":null,
 "iat":1757308800,
 "nbf":1757308800,
 "exp":1765084800}
```

## 12.2 Canonical serialization — solved, not hand-waved

**The signing input is the exact ASCII byte sequence `b64url(header) ‖ "." ‖ b64url(payload)` as transmitted.** The verifier signs and verifies **those bytes**; it never re-serializes the JSON. This removes JSON key ordering, whitespace, and number formatting as concerns entirely. **JSON is parsed only after the signature validates.**

Base64url is unpadded (RFC 7515 §2): standard base64 with `+`→`-`, `/`→`_`, `=` stripped.

## 12.3 Signing (Worker) and verification (app)

**Worker — `worker/src/tokens.js`:**
```js
crypto.subtle.importKey("pkcs8", pkcs8Bytes, {name:"Ed25519"}, false, ["sign"])
crypto.subtle.sign("Ed25519", key, new TextEncoder().encode(signingInput))
```
Private key: `LICENSE_SIGNING_KEY_K1` — base64 PKCS#8, **Wrangler secret only**.

**App — `Licensing/LicenseToken.swift`:**
```swift
Curve25519.Signing.PublicKey(rawRepresentation: Data)      // CryptoKit, macOS 10.15+ ✓
publicKey.isValidSignature(sigBytes, for: signingInputBytes)
```

**The private key never exists in the app target, the app bundle, or this repository. `PublicKeys.swift` contains public keys only.**

## 12.4 Verification order (app) — fail closed on every branch

1. Exactly three `.`-separated segments → else invalid.
2. Decode header. `typ == "DPL"`, `alg == "EdDSA"` → else invalid.
3. `kid` present in `PublicKeys.byKid` → else **`.unknownKid`** (see 12.6).
4. `isValidSignature` over the raw signing input → else invalid.
5. Parse payload JSON (**only now**).
6. `v == 1` → else `.unsupportedVersion`.
7. `dev == DeviceIdentity.current` → else **`.deviceMismatch`**.
8. `nbf ≤ now < exp` (±24 h skew allowance on `nbf`) → else `.expired` / `.notYetValid`.
9. `ent` contains `"cleanup"` → else no cleanup entitlement.

**Every failure grants nothing. In every case the free tier is unaffected** — scanning, autopsy, and explanations never consult a token.

## 12.5 Key rotation

`PublicKeys.byKid` is a **map**, shipping with `k1`. To rotate: add `k2` to the map in an app release → wait for adoption → switch the Worker to sign with `k2`. The app accepts any known `kid`. A `kid` is removed only after every token signed with it has expired (≥90 days after the switch).

## 12.6 Unknown `kid`, tampering, device mismatch

| Condition | Behavior |
|---|---|
| **Unknown `kid`** | Do **not** hard-fail. Treat as "needs online refresh": keep cleanup enabled **only if** a previously verified token is still within `exp`; otherwise disable cleanup and prompt to reconnect. This makes a rotation mistake recoverable rather than a mass lockout. |
| **Tampered signature** | Hard reject. Delete the stored token. Prompt for reactivation. |
| **Device mismatch** | Hard reject (the token was copied from another Mac). Prompt for activation on this Mac. |

**Tests:** T-TOK-01…10.

---

# PART 13 — OFFLINE LICENSING SPEC

**One mechanism: token expiry. There is no separate grace counter.**

| Scenario | Behavior |
|---|---|
| **Online — activate** | POST activate → token → Keychain. `lastOnlineVerification = now`. |
| **Online — refresh** | On launch, and at most once per 24 h. Success → new token. Network failure → silent no-op; the existing token remains authoritative. |
| **Offline — valid token** | Full cleanup entitlement until `exp`. **Up to 90 days offline with no degradation.** |
| **Expired token** | **Cleanup disabled. Scanning, autopsy, explanations, snapshot inspection, and receipts remain fully available — forever.** Message: *"DiskPrune needs to check your license. Connect to the internet."* — **never** "your license is invalid." |
| **Reconnect after expiry** | The expired-but-cryptographically-valid token is presented to `/refresh`, which does not check `exp` (§11.5). If the license and device remain authorized, a new token is issued and cleanup returns with no re-entry of the key. |
| **Clock rollback** | Persist `maxSeenTime` in the Keychain. If `now < maxSeenTime − 24 h`: **fail open** — the app keeps working — show *"Your Mac's clock appears to be incorrect"*, and set `requiresOnlineCheckBy = maxSeenTime + 7 days`. If that passes with no successful online check, disable cleanup (free tier unaffected). **Never brick a paying customer over a clock.** |
| **Clock forward past `exp`** | Ordinary expiry. |
| **Released device** | Existing token valid to `exp`; **refresh returns `403 DEVICE_RELEASED`**; cleanup disables at expiry with a message naming reactivation. |
| **Revoked license** | Existing token valid to `exp`; **refresh returns `403 LICENSE_REVOKED`**; cleanup disables at expiry. Worst-case revocation reach is 90 days — acceptable at $14.99, where revocation is a backstop, not a control. |
| **Disputed license** | Refresh succeeds with a **14-day** token, so the resolution reaches the customer quickly in either direction. No user-visible dispute messaging in the app. |

**Absolute rule:** *no customer ever loses free scanning because licensing failed, expired, was revoked, was disputed, or could not be reached.* The free tier has **no** code path that consults `LicenseManager`. Enforced by test T-OFF-07.

---

# PART 14 — STRIPE WEBHOOK SPEC

## 14.1 Signature verification

```js
const raw = await request.text();               // RAW body — never JSON.parse first
const event = await stripe.webhooks.constructEventAsync(
  raw, request.headers.get("stripe-signature"),
  env.STRIPE_WEBHOOK_SECRET, undefined, Stripe.createSubtleCryptoProvider()
);
```
**`constructEventAsync` is mandatory.** The synchronous `constructEvent` throws `SubtleCryptoProvider cannot be used in a synchronous context` on Workers — it does not verify. Verification failure → `400`, nothing processed.

## 14.2 Payment state rules — exhaustive

| Event | `payment_status` | Action |
|---|---|---|
| `checkout.session.completed` | `paid` | **Fulfil.** |
| `checkout.session.completed` | `unpaid` | `fulfillments.state = 'pending'`. **Issue nothing.** |
| `checkout.session.completed` | `no_payment_required` | **Reject and alert.** No $0 SKU exists. |
| `checkout.session.async_payment_succeeded` | — | **Fulfil**, idempotently via the same session-ID constraint. |
| `checkout.session.async_payment_failed` | — | `state = 'failed'`. Issue nothing. |
| `charge.refunded` | — | `licenses.status = 'revoked'`. |
| `charge.dispute.created` | — | `status = 'disputed'` (§11.3). **Do not revoke.** |
| `charge.dispute.closed` | `status: won` | `status = 'active'`. |
| `charge.dispute.closed` | `status: lost` | `status = 'revoked'`. |
| any other | — | Record in `events`, return `200`, ignore. |

## 14.3 Durable idempotency and concurrency

**Fulfilment is one D1 transaction whose first statement is:**
```sql
INSERT INTO fulfillments (stripe_session_id, state, created_at, updated_at)
VALUES (?, 'pending', ?, ?);
```
A `UNIQUE`/PK constraint violation means the session is already being fulfilled or is fulfilled → **return `200`, issue nothing.**

- **`fulfillments` has no TTL, ever.** A webhook replayed on day 30 cannot mint a second license.
- **Concurrency:** two simultaneous deliveries both attempt the insert; SQLite serializes them; exactly one succeeds. **No lock, no read-then-write, no race.** Survives Worker restarts because the constraint lives in the database.
- `events.stripe_event_id` is recorded permanently for audit.

## 14.4 Failure responses

| Condition | Response | Rationale |
|---|---|---|
| Bad signature | `400` | Stripe will not retry a 400; nothing was processed |
| Duplicate session | `200` | Already fulfilled |
| D1 unavailable **after** a confirmed charge | **`500`** | **Stripe retries.** Never `200` on an unfulfilled payment. Log the session ID loudly. |
| Email send failure | **`200`** | Fulfilment succeeded; delivery is a separate, recoverable concern |
| Unknown event type | `200` | Recorded and ignored |

## 14.5 The four guarantees

1. A successfully charged payment **eventually produces exactly one license**.
2. A duplicate or replayed webhook **never produces another license**.
3. A delayed payment **never produces a license before confirmation**.
4. A failed payment **never produces a license**.

**Tests:** T-WH-01…12.

---

# PART 15 — LICENSE EMAIL SPEC

**Provider: Resend.** One HTTPS POST from the Worker. No account system, no ESP dashboard dependency, no template engine.

## 15.1 Flow

```
license row COMMITTED (email_state='pending')
   ↓
decrypt key (crypto.js)  →  POST https://api.resend.com/emails
   ↓ success                                    ↓ failure
email_state='sent'                    email_state='failed', attempts++
                                      (retry sweep + self-serve resend)
```
**Fulfilment never depends on delivery.** The license row is committed **before** the send is attempted. A send failure never rolls back fulfilment and never returns non-200 to Stripe.

## 15.2 Email content

Subject: `Your DiskPrune license key`. Plain text plus a minimal HTML part. Contains: the license key, activation instructions (DiskPrune → License → paste), the download link, the support address, and the refund policy link. **No tracking pixels, no link wrapping** — a receipt email should not be surveilled.

## 15.3 Retry, resend, protection

| Concern | Specification |
|---|---|
| Retry | A Cron Trigger sweep every 6 h re-attempts `email_state = 'failed' AND email_attempts < 5`, exponential spacing. |
| Self-serve resend | `POST /v1/licenses/resend {email}` → decrypt and send if a license exists. **Always returns `200 {ok:true}`** regardless — no account enumeration. |
| Rate limit | 3/hour per IP **and** 3/day per email address. |
| Support recovery | The same code path, invoked manually. **Correction 2 is what makes this possible** — without `encrypted_key` the plaintext is unrecoverable after a delivery failure and the customer is stranded. |
| **Logging** | **Never log the plaintext key.** Log `license_id` and the first 8 chars of `key_hash` only. The key appears in the Resend request **body** and nowhere else — not in metadata, tags, or headers. |

**Tests:** T-EMAIL-01…06.

---

# PART 16 — WEBSITE IMPLEMENTATION SPEC

Static Astro in `web/`. **Port first, verify, then delete `site/`.**

## 16.1 Migration map — nothing valuable is lost

| From `site/` | To `web/` | Notes |
|---|---|---|
| `components/mac-app.tsx` (398) | `src/components/MacDemo.tsx` — island, `client:visible` | Keep per-category selection, tier badges, progress, window chrome. Apply PART 17 changes. |
| `lib/prune-store.ts` (253) | `src/lib/demo-store.ts` | Apply PART 17 state machine. |
| `lib/scan-data.ts` (155) | `src/data/demo-scan.ts` | **Regenerate from `/shared/storage-rules.json`** so demo and app agree by construction. |
| `lib/blog.ts` (130) | `src/content/guides/*.md` | Port the prose into content collections. Real technical writing — preserve it. |
| `components/{disk-ring,wordmark,license-dialog,site-header,site-footer}.tsx`, `components/ui/*` | `src/components/` | Drop unused Radix primitives. |
| `styles.css` | `src/styles/global.css` | Port design tokens wholesale. |
| `routes/index.tsx` | `src/pages/index.astro` | Port layout and responsive behavior; **rewrite every claim.** |
| Pricing section | `src/pages/pricing.astro` | Stripe stays an external boundary. |
| `routes/blog/*` | `src/pages/guides/*` | Content collections. |
| `routes/success.tsx` | `src/pages/success.astro` | **Rewrite** — status only. |
| `lib/product.ts` `COMPARISON` | `src/data/comparison.ts` | **Delete all six rows; rewrite from verified sources.** |
| `lib/utils.ts` | `src/lib/utils.ts` | Port `cn`, `formatBytes`. |
| `public/{favicon.svg,og.jpg}` | `web/public/` | Move. |

## 16.2 Deleted — no product requirement

Better Auth (`lib/auth/*`, 18 files) · PGlite · Kysely · `lib/db.ts` · `lib/app-data/*` (11 files) · `lib/multiplayer/*` (570 lines WebRTC) · `scripts/grok-*` · `server/middleware/grok-pwa.ts` · `lib/preview-*` · `components/preview-host-bridge.tsx` · `routeTree.gen.ts` · `router.tsx` · **`issueLicense()` and all client-side key generation** · all DB migrations · `/__grok/manifest.webmanifest` and `apple-touch-icon` links.

**The website is marketing, content, and demo infrastructure. Not a SaaS product.** No auth, no database, no server runtime, no PWA glue.

## 16.3 Success page — status only

```
read session_id → GET /v1/checkout/{id}/status → render by state
```
| State | Copy |
|---|---|
| `paid` + `sent` | "Payment confirmed. Your license key is in your email — we sent it to a•••@example.com." |
| `paid` + `pending` | "Payment confirmed. Your key is being generated — check your email in a minute." Poll 3× at 2 s, then show the support line. |
| `unpaid` (async) | "Your payment is processing. Some payment methods take a few days. We'll email your key as soon as it clears." |
| `failed` / unknown | "We couldn't confirm this yet. Email support@diskprune.com and we'll sort it out." |

**Absolute prohibitions.** The license key never reaches the browser. No client-side key generation. **The words "Payment received" never appear without a Stripe-confirmed `paid` status.** No claim token in a URL.

## 16.4 Deployment

Static output to a CDN host. **Add a deployment configuration — none exists in the repository today.** `web/dist/` removed from version control and added to `.gitignore`.

---

# PART 17 — DEMO CONTRACT

**Governing rule: the demo must never be more capable than the shipped binary.**

## 17.1 Required changes to the ported store

1. **`flushSnapshots` deleted entirely.** Snapshots are inspect-only in the demo, exactly as in the app.
2. **Snapshot bytes removed from every cleanup total.**
3. **A dry-run/confirm step inserted before purge**, mirroring the app.
4. **"Live scan demo" → "Interactive demo (simulated)"** everywhere.
5. **Persistent disclosure visible at every breakpoint** — *"Demo data — not a live scan of this Mac."* The current notice sits inside `hidden md:flex` at 11 px and vanishes on mobile. It must be in the window chrome, not the sidebar.
6. **No fake "freed" number.** The demo uses the PART 5.1 terminology contract: "Moved to Trash", "still recoverable", "empty Trash to reclaim".

## 17.2 Demo state machine — exact

```
idle ──startScan──▶ scanning ──(complete)──▶ results
                        │                       │ toggleItem / selectAll / clearAll
                        └──cancel──▶ idle       ▼
                                            planReady ──review──▶ dryRun
                                                 ▲                   │ cancel → planReady
                                                 │                   │ confirm (licensed?)
                                                 │                   ├─ no  → licensePrompt → planReady
                                                 │                   └─ yes → trashing
                                                 │                             ▼
                                                 └────── reset ───────────── receipt
```
**Invariants.** `results → trashing` is impossible (must pass through `planReady` **and** `dryRun`). `dryRun` always states **"Nothing has changed yet."** `licensePrompt` never auto-proceeds to `trashing` on activation — it returns to `planReady` and the user confirms again. (The current `prune-store.ts:224-227` calls `confirmPurge()` immediately on activation; that is removed.) The demo license `PRUNE-DEMO-2026-LIFE` is labelled demo-only and can never be presented as a purchase outcome.

---

# PART 18 — SEO IMPLEMENTATION

## 18.1 Page inventory

| URL | Title | Description | Canonical |
|---|---|---|---|
| `/` | DiskPrune — Understand what's filling your Mac | Free scan explains what's using your storage… | self |
| `/pricing` | DiskPrune Pricing — $14.99 lifetime | One-time. No subscription. Free scanning forever. | self |
| `/download` | Download DiskPrune for macOS | Signed and notarized. macOS 14 and later. Apple Silicon and Intel. | self |
| `/guides/<slug>` | `<frontmatter.title>` | `<frontmatter.description>` | self |
| `/storage/<id>` | `<rule.displayName> — what it is and whether it's safe to remove` | derived from `rule.explanation` | self |
| `/compare/<competitor>` | DiskPrune vs `<Name>` — an honest comparison | verified `<date>` | self |
| `/privacy`, `/support`, `/refunds` | — | — | self |

## 18.2 Structured data

| Page | Type | Notes |
|---|---|---|
| `/`, `/pricing` | `SoftwareApplication` | `name`, `operatingSystem: "macOS 14.0"`, `applicationCategory: "UtilitiesApplication"`, `offers` (price, currency), `url`. **No `aggregateRating`, no `review`** — Google restricts self-serving review markup and we have no reviews. |
| `/guides/*`, `/storage/*` | `Article` | Real `datePublished` / `dateModified` from frontmatter and `rule.lastReviewed`. |
| all nested | `BreadcrumbList` | — |
| site-wide | `WebSite`, `Organization` | — |

## 18.3 Guide frontmatter (required)

```yaml
title: string
description: string          # 120–158 chars
publishedAt: date
updatedAt: date
macOSTested: string          # "26.6.2 (Tahoe)"
architectureTested: string   # "Apple Silicon" | "Intel" | "both"
relatedRules: [string]       # storage-rules ids → cross-links
```
**No `macOSTested` value without a real test on a real Mac. Never invent a test result.**

## 18.4 `/storage/*` generation

`getStaticPaths()` filters `rules.filter(r => r.publish === true)`. **~10 pages at launch, not ~25.** A rule earns `publish: true` only when it has first-hand testing behind it, a real consequence to describe, and search intent worth serving. **Page-per-rule is exactly the scaled-thin-content pattern to avoid.**

## 18.5 Also required

`robots.txt` referencing the sitemap · `@astrojs/sitemap` · Open Graph and Twitter/X cards with a real image · semantic HTML · descriptive alt text · internal links from every guide to `/download` and to its `relatedRules` pages · consistent trailing-slash policy · no accidental `noindex` · **no fake ratings, no fake reviews, no claims of market leadership.**

---

# PART 19 — RELEASE ENGINEERING

## 19.1 Build commands — exact

```bash
cd app
swift build -c release --arch arm64
swift build -c release --arch x86_64
lipo -create -output DiskPrune.universal \
  .build/arm64-apple-macosx/release/DiskPrune \
  .build/x86_64-apple-macosx/release/DiskPrune
lipo -archs DiskPrune.universal   # MUST print: x86_64 arm64
```

**Resource handling.** SPM emits `DiskPrune_DiskPrune.bundle` per architecture. The build **asserts the two bundles are byte-identical** (`shasum -a 256` comparison) and copies one. **A mismatch fails the build** rather than picking arbitrarily.

## 19.2 Bundle assembly and Info.plist

```
DiskPrune.app/Contents/
├── Info.plist
├── MacOS/DiskPrune                    ← the universal binary
└── Resources/{DiskPrune_DiskPrune.bundle, AppIcon.icns}
```

| Key | Value | Source |
|---|---|---|
| `CFBundleIdentifier` | `com.diskprune.app` | fixed |
| `CFBundleExecutable` | `DiskPrune` | fixed |
| `CFBundleName` | `DiskPrune` | fixed |
| `CFBundlePackageType` | `APPL` | fixed |
| `CFBundleShortVersionString` | e.g. `1.0.0` | **git tag with `v` stripped** |
| `CFBundleVersion` | e.g. `1.0.0.42` | short version + `github.run_number` |
| `LSMinimumSystemVersion` | `14.0` | fixed |
| `NSHumanReadableCopyright` | `© 2026 …` | fixed |
| `LSApplicationCategoryType` | `public.app-category.utilities` | fixed |
| `NSHighResolutionCapable` | `true` | fixed |

**Version source of truth is the git tag.** A non-tag build uses `0.0.0-dev`.

## 19.3 Signing, notarization, stapling

```bash
# nested code first, then the bundle — NOT --deep
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: <NAME> (<TEAMID>)" \
  DiskPrune.app/Contents/Resources/DiskPrune_DiskPrune.bundle
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: <NAME> (<TEAMID>)" DiskPrune.app

hdiutil create -volname DiskPrune -srcfolder DiskPrune.app -ov -format UDZO DiskPrune.dmg
codesign --force --timestamp --sign "Developer ID Application: …" DiskPrune.dmg

xcrun notarytool submit DiskPrune.dmg \
  --key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" --wait
xcrun stapler staple DiskPrune.dmg
shasum -a 256 DiskPrune.dmg > DiskPrune.dmg.sha256
```
**`--deep` is prohibited** — Apple deprecates it for signing distribution bundles. Sign nested code explicitly, inside-out.

**Secrets:** `DEVELOPER_ID_CERT_P12` (base64), `DEVELOPER_ID_CERT_PASSWORD`, `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`. Imported into a temporary keychain, **deleted in an `always()` step**. **Missing secrets fail the build** — the pipeline never silently produces an ad-hoc artifact that looks signed.

## 19.4 The 12-point verification — against what the customer downloads

Mount the built DMG and run every check against the `.app` **extracted from the mounted image**:

| # | Check | Command / method |
|---|---|---|
| 1 | Code signature identity | `codesign -dv --verbose=4` → "Developer ID Application" |
| 2 | Nested code and resources valid | `codesign --verify --deep --strict --verbose=2` |
| 3 | Hardened runtime | flags include `runtime` |
| 4 | Secure timestamp | `codesign -dvv` shows `Timestamp=` |
| 5 | Notarization accepted | `notarytool log` clean |
| 6 | Stapled | `stapler validate` on **both** `.app` and `.dmg` |
| 7 | Gatekeeper assessment | `spctl -a -vvv -t install` → "accepted, source=Notarized Developer ID" |
| 8 | DMG integrity | `hdiutil verify` |
| 9 | **Universal** | `lipo -archs` on the executable **inside the mounted DMG** → `x86_64 arm64` |
| 10 | Extracted app launches | manual |
| 11 | Clean-Mac install and launch, **no Gatekeeper detour** | manual |
| 12 | Intel smoke test | manual |

Checks 10–12 are manual and **gate the release**. Check 9 is the acceptance criterion for universal support — **a build log claiming it is not acceptable evidence.**

## 19.5 Clean-Mac acceptance test

On a Mac that has never run DiskPrune: download the DMG from the GitHub release URL in Safari → verify the SHA-256 → double-click → drag to Applications → launch. **Pass = the app opens with no Terminal command and no visit to System Settings.**

---

# PART 20 — CI

`.github/workflows/ci.yml` on push and PR. **Jobs 1–9 are mandatory and block merge.**

| # | Job | Runner | Mandatory | Fails when |
|---|---|---|---|---|
| 1 | Swift build (debug) | macos-latest | **Yes** | compile error |
| 2 | Swift unit tests | macos-latest | **Yes** | any test fails |
| 3 | **Destructive-operation guardrails** | ubuntu | **Yes** | see below |
| 4 | Storage-rule schema validation | ubuntu | **Yes** | schema violation |
| 5 | Storage-rule drift check | ubuntu | **Yes** | `shared/` ≠ generated copy |
| 6 | Worker tests | ubuntu | **Yes** | any test fails |
| 7 | Licensing tests (token, crypto, idempotency) | ubuntu | **Yes** | any test fails |
| 8 | Website build | ubuntu | **Yes** | build fails, or any DB/auth import is present |
| 9 | SEO validation | ubuntu | **Yes** | missing title/description/canonical; sitemap URL not 200; invalid structured data |
| 10 | Universal artifact build | macos-latest | on `main` and tags | `lipo -archs` lacks a slice |
| 11 | Signing + notarization | macos-latest | on tags | any of the 12 checks fails; **or secrets are absent** |

## 20.1 Job 3 — guardrails, and why they are not theater

**The structural argument comes first.** `CleanupExecutor` is the sole destructive authority; it accepts one parameter of type `CleanupPlan`; `PlannedItem.init?` is failable and enforces eight conditions; the only mutating call is `trashItem`. **These operations are unnecessary because the architecture provides no situation that requires them.** The greps are a **regression alarm on that architecture**, not the mechanism.

| Pattern | Scope | Rationale |
|---|---|---|
| `removeItem`, `removeItemAt` | all of `Sources/DiskPrune/` | permanent deletion |
| `unlink(`, `rmdir(`, `remove(` | all | POSIX deletion |
| `rm -rf`, `rm -r` | all | shell deletion |
| `Process(`, `NSTask` | all **except** `Scanning/SnapshotInspector.swift` | arbitrary execution |
| `tmutil`, `deletelocalsnapshots` | all **except** `SnapshotInspector.swift` (which may contain `listlocalsnapshots` only) | snapshot destruction |
| `import Cleanup` inside `Scanning/`; `import Scanning` inside `Cleanup/` | — | enforces the one-way data flow |
| `Math.random` | `worker/src/` | insecure randomness |
| `freed`, `reclaimed` | `UI/ReceiptView.swift`, `UI/CleanupPlanView.swift` | **terminology contract (Correction 1)** |

**Explicitly NOT flagged:** `createDirectory`, `write(to:)`, `Data.write`, `JSONEncoder` output in `Persistence/`. These are app-owned writes and are permitted (Correction 5).

---

# PART 21 — TEST MATRIX

Format: **ID · Setup · Action · Expected.** Destructive tests use isolated `FileManager.temporaryDirectory` fixtures. **No automated test touches a real home directory.** Manual tests are marked **[M]**.

## Scanner and sizing
| ID | Setup | Action | Expected |
|---|---|---|---|
| T-SIZE-01 | Fixture: 3 files of 1 MB, 2 MB, 4 MB | measure | `onDiskBytes` within 1 block of 7 MB |
| T-SIZE-02 | 70-level nested dirs | measure | terminates at depth 64; no crash |
| T-SIZE-03 | Directory removed mid-walk | measure | completes; no throw |
| T-SIZE-04 | 5 000 small files | measure | `fileCount == 5000` |
| T-SIZE-05 | Empty directory | measure | 0 bytes, 0 files, `.complete` |
| T-SIZE-06 | Nested `.app` bundle | measure | bundle counted whole; **no child item emitted** |
| T-SIZE-07 | `st_blocks == 0`, `st_size > 0` | measure | falls back to `st_size`; flagged approximate |
| T-SPARSE-01 | Sparse file: logical 10 GB, allocated 100 MB | measure | `onDisk ≈ 100 MB`, `logical == 10 GB`, sparse flag set |

## Permissions
| ID | Setup | Action | Expected |
|---|---|---|---|
| T-PERM-01 | Subdirectory `chmod 000` | scan | item `.partial`, path in `deniedPaths`, scan completes |
| T-PERM-02 | Root unreadable | scan | `.denied`; **other probes still run** |
| T-PERM-03 | Denials present | render | banner shown; totals rendered as "at least" |
| T-PERM-04 | FDA probe returns false | scan | scan **still runs**; no assertion about FDA state in copy |

## Symlinks, hardlinks, grouping
| ID | Setup | Action | Expected |
|---|---|---|---|
| T-SYM-01 | Symlink → outside the root | measure | target not counted; link's own blocks counted |
| T-SYM-02 | Symlink loop | measure | terminates |
| T-SYM-03 | Symlink → a large directory | measure | not descended |
| T-HL-01 | 2 hardlinks to one 1 GB file, same item | measure | counted once |
| T-HL-02 | Hardlinks across two items | scan | `coverage.classifiedBytes` counts once; **each item reports its own size** |
| T-HL-03 | `st_nlink == 1` | measure | not added to the dedup set (perf) |
| T-HL-04 | Items sharing hardlinks | render Autopsy | headline uses `StorageCoverage`, **never Σ item sizes** |
| T-GRP-01 | DerivedData with 3 projects | scan | 3 items; **no item is an ancestor of another** |

## `.app`, planning, TOCTOU
| ID | Setup | Action | Expected |
|---|---|---|---|
| T-APP-01 | Cache containing a `.app` | scan | no child item inside the bundle |
| T-APP-02 | `StorageItem` with a `.app` ancestor | `PlannedItem.init?` | **`nil`** |
| T-PLAN-01…08 | one per §5.1 condition | `PlannedItem.init?` | **`nil`** in every case |
| T-PLAN-09 | zero items | `CleanupPlan.init?` | **`nil`** |
| T-PLAN-10 | ancestor + descendant | `CleanupPlan.init?` | **`nil`** |
| T-TOC-01 | Item deleted after planning | execute | `.skipped(.vanished)`; batch continues |
| T-TOC-02 | Item replaced by a symlink | execute | `.skipped(.becameSymlink)` |
| T-TOC-03 | Directory replaced by a file | execute | `.skipped(.typeChanged)` |
| T-TOC-04 | Same path, different inode | execute | `.skipped(.identityChanged)` |
| T-TOC-05 | Path made to escape `cleanupRoot` | execute | `.skipped(.escapedCleanupRoot)` |
| T-TOC-06 | Path moved under a `.app` | execute | `.skipped(.appBundleAncestor)` |
| T-TOC-07 | Path matches the deny list | execute | `.skipped(.denyListed)` |

## Cleanup, Trash, receipt, accounting
| ID | Setup | Action | Expected |
|---|---|---|---|
| T-CLN-01 | 10 items, item 3 permission-denied | execute | **9 trashed, 1 `.failed`, batch completed** |
| T-CLN-02 | Empty plan | — | cannot be constructed (T-PLAN-09) |
| T-CLN-03 | 10 items, cancel after 5 | execute | 5 trashed, 5 `.skipped(.cancelled)`, `wasCancelled == true` |
| T-CLN-04 | Trash unavailable | execute | `.failed(.trashUnavailable)`; **no `removeItem` call** (spy-verified) |
| T-CLN-05 | Fixture with unplanned siblings | execute | **siblings survive untouched** |
| T-CLN-06 | All items fail | execute | receipt honest; **not rendered as success** |
| T-RCP-01 | Any receipt | encode/decode | round-trips |
| T-RCP-02 | Some items fail | receipt | `successfullyTrashedBytes` excludes them |
| T-RCP-03 | `SpaceVerifier` returns nil | receipt | delta recorded unavailable, **not 0** |
| **T-TERM-01** | UI sources | string scan | **`freed` / `reclaimed` absent from receipt and plan rendering** |
| T-COV-01 | Mixed classified/unclassified | scan | `examined == classified + unclassifiedScanned` |
| T-COV-02 | Any scan | render | headline never implies classified == disk used |
| T-COV-03 | Denials present | coverage | `permissionLimitedBytes == nil`; **never estimated** |
| T-COV-04 | `examined > volumeUsed` (clone artifact) | coverage | `notExamined` clamps to 0; no negative rendered |

## Snapshots and Docker
| ID | Setup | Action | Expected |
|---|---|---|---|
| T-SNAP-01 | Real `tmutil` output | parse | correct count and dates |
| T-SNAP-02 | Empty / garbage output | parse | `readFailed` or count 0; no crash |
| **T-SNAP-03** | whole repo | grep | **`deletelocalsnapshots` absent from all source** |
| T-SNAP-04 | Full cleanup run **[M]** | before/after | `tmutil listlocalsnapshots /` **unchanged** |
| T-SNAP-05 | `tmutil` hangs | list | returns within 5 s, `readFailed: true` |
| T-DOCK-01 | Docker absent | probe | empty; no error; no empty section |
| T-DOCK-02 | Docker installed, running | probe | item present, `.advanced`, `isCleanupCandidate == false` |
| T-DOCK-03 | Docker installed, **stopped** | probe | **still not a cleanup candidate** |
| T-DOCK-04 | Colima layout | probe | discovered |
| T-DOCK-05 | Unknown layout | probe | reports what was found; no guess |

## Licensing, tokens, offline
| ID | Setup | Action | Expected |
|---|---|---|---|
| T-TOK-01…04 | valid / bit-flipped / unknown-kid / wrong-device tokens | verify | valid; reject; `.unknownKid`; `.deviceMismatch` |
| T-TOK-05 | Expired token | verify | `.expired` |
| T-TOK-06 | `k2`-signed token, two-key map | verify | valid |
| T-TOK-07 | Payload with reordered JSON keys | verify | **valid** — bytes are signed, not re-serialized |
| T-KC-01 | Manual `security add-generic-password` | launch | **cleanup NOT enabled** |
| T-KC-02 | Keychain entry deleted | launch | new device UUID; second seat consumed |
| T-DEV-01 | Fresh install | activate | one device row |
| T-DEV-02 | Second launch | launch | same UUID; no new row |
| T-REF-01 | Active license | refresh | 90-day token |
| **T-REF-02** | **Device released** | refresh | **`403 DEVICE_RELEASED`** |
| T-REF-03 | Revoked license | refresh | `403 LICENSE_REVOKED` |
| T-REF-04 | **Disputed** license | refresh | **`200`, 14-day token** |
| T-REF-05 | Expired but valid signature | refresh | **`200`** — renewal succeeds |
| T-REF-06 | Unknown device | refresh | `403 DEVICE_UNKNOWN` |
| T-SEAT-01 | 3 seats used | activate 4th | `409 SEAT_LIMIT` + device list |
| T-SEAT-02 | Release then activate | activate | succeeds |
| T-OFF-01 | Valid token, no network | launch | cleanup available |
| T-OFF-02 | Expired token, no network | launch | cleanup off; **scan available** |
| T-OFF-03 | Clock back 30 days | launch | **fails open** + warning + `requiresOnlineCheckBy` set |
| T-OFF-04 | `requiresOnlineCheckBy` passed, still offline | launch | cleanup off; **scan available** |
| T-OFF-05 | Reconnect after expiry | refresh | new token; cleanup returns without re-entering the key |
| **T-OFF-07** | any license failure state | scan | **free tier fully functional in every case** |

## Stripe and email
| ID | Setup | Action | Expected |
|---|---|---|---|
| T-WH-01 | No / bad signature | POST | `400`; **no DB write** |
| T-WH-02 | Valid `completed` + `paid` | POST | exactly one license |
| T-WH-03 | Same event twice | POST ×2 | **one** license |
| T-WH-04 | Same session, different event ids | POST ×2 | **one** license |
| T-WH-05 | Simulated restart between deliveries | POST ×2 | **one** license (durability) |
| T-WH-06 | Two concurrent deliveries | POST ‖ POST | **exactly one**; the loser returns `200` |
| T-WH-07 | `completed` + `unpaid` | POST | **no license**; `state='pending'` |
| T-WH-08 | `async_payment_succeeded` | POST | license created |
| T-WH-09 | `async_payment_failed` | POST | **no license**; `state='failed'` |
| T-WH-10 | `charge.refunded` | POST | `status='revoked'` |
| T-WH-11 | `dispute.created` then `closed(won)` | POST ×2 | `disputed` → `active` |
| T-WH-12 | D1 unavailable after charge | POST | **`500`** so Stripe retries |
| T-ENC-01 | Round-trip | encrypt→decrypt | plaintext recovered |
| T-ENC-02 | Wrong AAD (different `licenses.id`) | decrypt | **fails** |
| T-ENC-03 | 1 000 encryptions | inspect | **all IVs unique** |
| T-ENC-04 | Worker log capture across all paths | scan | **plaintext key never present** |
| T-ENC-05 | `v1` ciphertext, `v2` key present | decrypt | still decrypts; lazy re-encrypt |
| T-EMAIL-01 | Resend returns 500 | fulfil | license **still created**; `email_state='failed'`; Stripe gets `200` |
| T-EMAIL-02 | Resend after failure | POST resend | key delivered (proves Correction 2 works) |
| T-EMAIL-03 | Unknown email | POST resend | **`200 {ok:true}`** — no enumeration |
| T-EMAIL-04 | 4th resend in an hour | POST | `429` |
| T-CHK-01 | `/v1/checkout/fake/status` | GET | no key, no payment claim |
| T-CHK-02 | Paid session | GET | state + masked email; **no key** |

## Release and website
| ID | Action | Expected |
|---|---|---|
| T-REL-01 | `lipo -archs` on the `.app` **inside the mounted DMG** | `x86_64 arm64` |
| T-REL-02 | `spctl -a -vvv -t install` | "accepted, source=Notarized Developer ID" |
| T-REL-03 | `stapler validate` on `.app` and `.dmg` | both pass |
| T-REL-04 **[M]** | Clean Mac: download → verify SHA → open | launches, **no System Settings detour** |
| T-REL-05 **[M]** | Intel Mac | launches |
| T-WEB-01 | `npm run build` | static output; **no DB step** |
| T-WEB-02 | grep routes | **no auth / db / multiplayer imports** |
| T-WEB-03 | Demo at 375 px | **disclosure visible** |
| T-WEB-04 | Demo state machine | `results → trashing` **impossible** |
| T-WEB-05 | grep site sources | **`issueLicense` absent** |
| T-SEO-01 | every page | title, description, canonical present |
| T-SEO-02 | sitemap | every URL returns 200 |
| T-SEO-03 | structured data | validates; **no `aggregateRating`** |
| T-SEO-04 | `/storage/*` | count == rules with `publish: true` |

---

# PART 22 — IMPLEMENTATION ORDER

**Two ordering laws, non-negotiable:**
1. **No destructive cleanup code exists before `CleanupPlan` / `PlannedItem` / `PathValidator` and their tests are merged and green.**
2. **No licensing code exists before webhook verification, D1 storage, and idempotency are merged and green.**

### Phase 0 — Baseline (Gate 0)
| C | Files | Functional after | Tests |
|---|---|---|---|
| 0.1 | `.gitignore`; `git rm --cached web/dist worker/.wrangler/...` | Repo clean; **account ID untracked** | — |
| 0.2 | `.github/workflows/ci.yml` (jobs 1–3), `Package.swift` (test target) | CI runs, guardrails active | job 3 green on the current tree |

### Phase 1 — Knowledge and scanning (Gate 2 groundwork)
| C | Files | Functional after | Tests |
|---|---|---|---|
| 1.1 | `shared/storage-rules.{json,schema.json}`, `scripts/{sync-rules.sh,validate-rules.mjs}`, CI jobs 4–5 | Rules validated; drift gated | schema tests |
| 1.2 | `Models/{FileID,ObjectType,SafetyLevel,Category,ScanState}.swift` | — | compile |
| 1.3 | `Scanning/FileIdentity.swift` | lstat wrapper | T-HL-03, error mapping |
| 1.4 | `Scanning/DirectorySizer.swift` | Real sizing | T-SIZE-*, T-SYM-*, T-HL-01, T-SPARSE-01 |
| 1.5 | `Knowledge/{StorageRule,StorageKnowledge}.swift` + generated resource | Classification | T-RULE-* |
| 1.6 | `Models/{StorageItem,StorageCoverage}.swift`, `Scanning/ScanEngine.swift`, `Probes/{Probe,Cache,Log}Probe.swift` | **Real scan with real bytes — B-3 fixed** | T-GRP-01, T-COV-*, T-HL-02/04 |
| 1.7 | `Permissions/FullDiskAccess.swift` | Partial-scan honesty — B-9 fixed | T-PERM-* |
| 1.8 | `Scanning/SnapshotInspector.swift` | Read-only snapshots — **B-8 removed** | T-SNAP-01/02/03/05 |

> **GATE 1 — filesystem safety.** No destructive code exists yet. `deletelocalsnapshots` absent from the repo. Job 3 green.

### Phase 2 — Cleanup (the only destructive phase)
| C | Files | Functional after | Tests |
|---|---|---|---|
| 2.1 | `Cleanup/PathValidator.swift`, `Models/{PlannedItem,CleanupPlan}.swift` | **Safety model exists before any executor** | T-PLAN-01…10, T-APP-02 |
| 2.2 | `Models/CleanupReceipt.swift`, `Persistence/ReceiptStore.swift` | Receipt model | T-RCP-01 |
| 2.3 | `Cleanup/SpaceVerifier.swift` | Volume measurement | T-RCP-03 |
| 2.4 | `Cleanup/CleanupExecutor.swift` | **Cleanup — B-1, B-5, B-7 fixed** | T-CLN-*, T-TOC-01…07 |

> **GATE 2 — scanner and accounting correctness.** See PART 25.

### Phase 3 — Probes and UI
| C | Files | Functional after | Tests |
|---|---|---|---|
| 3.1 | Rules corpus expanded to ~25 | Full classification | schema |
| 3.2 | `Probes/XcodeProbe.swift` | Per-project Xcode | T-XC-* |
| 3.3 | `Probes/DockerProbe.swift` | Docker inspect-only | T-DOCK-* |
| 3.4 | `Probes/PackageManagerProbe.swift` | 9 managers | T-PKG-* |
| 3.5 | `UI/{RootView,ScanView,StorageAutopsyView,StateViews}.swift` | Autopsy | T-COV-02 |
| 3.6 | `UI/{ResultsView,ItemDetailView,CleanupPlanView}.swift` | Selection — **B-4 fixed** | — |
| 3.7 | `UI/{DryRunSheet,ReceiptView,SnapshotView}.swift`; delete `ContentView/ScannerActor/SafetyRules` | **Full loop** | **T-TERM-01** |

### Phase 4 — Licensing backend
| C | Files | Functional after | Tests |
|---|---|---|---|
| 4.1 | `worker/{package.json,wrangler.toml,migrations/0001_init.sql,src/db.js}` | D1 schema | migration applies |
| 4.2 | `worker/src/crypto.js` | Key gen + AES-GCM | T-ENC-* |
| 4.3 | `worker/src/tokens.js` | Ed25519 signing | T-TOK-06/07 |
| 4.4 | `worker/src/webhook.js`, `src/index.js` | **Verification + idempotency — B-12 fixed** | T-WH-01…12 |
| 4.5 | `worker/src/email.js` | Delivery + resend | T-EMAIL-* |
| 4.6 | `worker/src/{licenses,ratelimit}.js` | activate/refresh/release | T-REF-*, T-SEAT-*, T-CHK-* |

### Phase 5 — Licensing client
| C | Files | Functional after | Tests |
|---|---|---|---|
| 5.1 | `Licensing/{KeychainStore,DeviceIdentity}.swift` | Random device UUID | T-DEV-*, T-KC-02 |
| 5.2 | `Licensing/{PublicKeys,LicenseToken}.swift` | Local verification | T-TOK-01…07 |
| 5.3 | `Licensing/LicenseManager.swift`, `UI/LicenseView.swift`; delete old `LicenseManager.swift` | **Real gating — B-11 fixed** | T-KC-01, T-OFF-* |

> **GATE 3 — licensing and payment correctness.**

### Phase 6 — Release
| C | Files | Functional after | Tests |
|---|---|---|---|
| 6.1 | `build-mac.yml` — universal + Info.plist | **Intel supported — B-16 fixed** | T-REL-01 |
| 6.2 | `build-mac.yml` — signing, notarization, stapling, 12-point verification | **Notarized DMG** | T-REL-02…05 |

> **GATE 4 — native UX.** > **GATE 5 — signed universal release.**

### Phase 7 — Website
| C | Files | Functional after | Tests |
|---|---|---|---|
| 7.1 | `web/` scaffold, tokens, layouts, deploy config | Site builds | T-WEB-01 |
| 7.2 | `MacDemo.tsx` + `demo-store.ts` + `demo-scan.ts` | Demo ported | T-WEB-03/04 |
| 7.3 | Guides → content collections | Content | — |
| 7.4 | Landing, pricing, download, privacy, support, refunds | **Claims rewritten — B-6/B-7 site side fixed** | — |
| 7.5 | `success.astro` | **Status-only — B-13 fixed** | T-WEB-05, T-CHK-01 |
| 7.6 | SEO + `/storage/*` + comparison; CI jobs 8–9 | SEO live | T-SEO-* |
| 7.7 | **Delete `site/`** (only after 7.1–7.6 verified) | One website | full suite |
| 7.8 | `README.md` rewrite | Docs match reality | — |

> **GATE 6 — website, demo, SEO.** > **GATE 7 — launch rehearsal.**

---

# PART 23 — BUILDER RULES

**Grok: these are absolute. Violating any one invalidates the work.**

1. **Do not invent architecture.** If this document does not specify it, ask.
2. **Do not silently change product scope.** PART 4 and the DO-NOT-BUILD list are a contract.
3. **Do not add dependencies.** Foundation, SwiftUI, AppKit, CryptoKit, Darwin, Security on native; `stripe` only on the Worker; Astro + React on the site. Anything else requires written justification and approval.
4. **Do not weaken a safety check to make a test pass.** If a test fails because a safeguard blocks it, **the test is wrong.** Report it.
5. **Never replace Trash with permanent deletion.** No `removeItem` fallback in any error path.
6. **Never implement snapshot deletion.** No API, no button, no flag, no "advanced" escape hatch.
7. **Never implement `Docker.raw` deletion.** Running or stopped.
8. **Never generate a fake license or payment flow.** No client-side key generation. No "Payment received" without Stripe confirmation.
9. **Never use `Math.random()` for anything security-sensitive.** `crypto.getRandomValues` on the Worker; `SystemRandomNumberGenerator` / `UUID()` on native.
10. **Never log a secret.** No plaintext license keys, signing keys, or encryption keys in any log, error, or trace.
11. **Never bypass `CleanupPlan`.** If you need to pass URLs into the executor, the design is being violated — stop and report.
12. **Never bypass TOCTOU validation.** All seven checks, before every individual trash, every time.
13. **Never create a second storage-rules source.** `/shared/storage-rules.json` is the only hand-edited copy.
14. **Never make the demo more capable than the binary.**
15. **Never add SaaS infrastructure** — no auth, database, accounts, or server runtime on the website.
16. **If a requirement is ambiguous, STOP AND REPORT.** Do not invent behavior. An unanswered question costs minutes; a wrong guess in a file-deleting utility costs a customer's data.
17. **Every commit leaves the repository buildable and testable** wherever practical.
18. **Never delete existing functionality before its replacement is verified.** `site/` is deleted in commit 7.7 — not before.

---

# PART 24 — FILE-BY-FILE CHECKLIST

### Repository hygiene
- [ ] MODIFY `.gitignore` — add `web/dist/`
- [ ] DELETE FROM GIT `web/dist/**` (`git rm -r --cached`)
- [ ] DELETE FROM GIT `worker/.wrangler/cache/wrangler-account.json` (`git rm --cached`) — **exposes Cloudflare account ID + email**
- [ ] DELETE `build-and-verify.sh`
- [ ] REWRITE `README.md`

### Shared and scripts
- [ ] CREATE `shared/storage-rules.json`
- [ ] CREATE `shared/storage-rules.schema.json`
- [ ] CREATE `scripts/sync-rules.sh`
- [ ] CREATE `scripts/validate-rules.mjs`

### Native — models
- [ ] CREATE `app/Sources/DiskPrune/Models/FileID.swift`
- [ ] CREATE `.../Models/ObjectType.swift`
- [ ] CREATE `.../Models/SafetyLevel.swift`
- [ ] CREATE `.../Models/Category.swift`
- [ ] CREATE `.../Models/ScanState.swift`
- [ ] CREATE `.../Models/StorageItem.swift`
- [ ] CREATE `.../Models/StorageCoverage.swift`
- [ ] CREATE `.../Models/PlannedItem.swift`
- [ ] CREATE `.../Models/CleanupPlan.swift`
- [ ] CREATE `.../Models/CleanupReceipt.swift`

### Native — knowledge, scanning, cleanup, persistence, permissions
- [ ] CREATE `.../Knowledge/StorageRule.swift`
- [ ] CREATE `.../Knowledge/StorageKnowledge.swift`
- [ ] CREATE `.../Knowledge/Resources/storage-rules.json` *(generated — never hand-edit)*
- [ ] CREATE `.../Scanning/FileIdentity.swift`
- [ ] CREATE `.../Scanning/DirectorySizer.swift`
- [ ] CREATE `.../Scanning/ScanEngine.swift`
- [ ] CREATE `.../Scanning/SnapshotInspector.swift`
- [ ] CREATE `.../Scanning/Probes/Probe.swift`
- [ ] CREATE `.../Scanning/Probes/XcodeProbe.swift`
- [ ] CREATE `.../Scanning/Probes/DockerProbe.swift`
- [ ] CREATE `.../Scanning/Probes/PackageManagerProbe.swift`
- [ ] CREATE `.../Scanning/Probes/CacheProbe.swift`
- [ ] CREATE `.../Scanning/Probes/LogProbe.swift`
- [ ] CREATE `.../Cleanup/PathValidator.swift`
- [ ] CREATE `.../Cleanup/CleanupExecutor.swift`
- [ ] CREATE `.../Cleanup/SpaceVerifier.swift`
- [ ] CREATE `.../Persistence/ReceiptStore.swift`
- [ ] CREATE `.../Persistence/PreferencesStore.swift`
- [ ] CREATE `.../Permissions/FullDiskAccess.swift`

### Native — licensing and UI
- [ ] CREATE `.../Licensing/PublicKeys.swift`
- [ ] CREATE `.../Licensing/LicenseToken.swift`
- [ ] CREATE `.../Licensing/DeviceIdentity.swift`
- [ ] CREATE `.../Licensing/KeychainStore.swift`
- [ ] CREATE `.../Licensing/LicenseManager.swift`
- [ ] CREATE `.../UI/RootView.swift`
- [ ] CREATE `.../UI/ScanView.swift`
- [ ] CREATE `.../UI/StorageAutopsyView.swift`
- [ ] CREATE `.../UI/ResultsView.swift`
- [ ] CREATE `.../UI/ItemDetailView.swift`
- [ ] CREATE `.../UI/CleanupPlanView.swift`
- [ ] CREATE `.../UI/DryRunSheet.swift`
- [ ] CREATE `.../UI/ReceiptView.swift`
- [ ] CREATE `.../UI/SnapshotView.swift`
- [ ] CREATE `.../UI/LicenseView.swift`
- [ ] CREATE `.../UI/StateViews.swift`

### Native — removals, manifest, tests
- [ ] PRESERVE `app/Sources/DiskPrune/App.swift`
- [ ] REWRITE `app/Package.swift` (resources + test target)
- [ ] DELETE `app/Sources/DiskPrune/ContentView.swift`
- [ ] DELETE `app/Sources/DiskPrune/ScannerActor.swift`
- [ ] DELETE `app/Sources/DiskPrune/SafetyRules.swift`
- [ ] DELETE `app/Sources/DiskPrune/LicenseManager.swift` *(old top-level file)*
- [ ] CREATE `app/Tests/DiskPruneTests/` — one file per PART 21 group

### Worker
- [ ] CREATE `worker/package.json`
- [ ] REWRITE `worker/wrangler.toml` (D1 binding, secrets, cron)
- [ ] CREATE `worker/migrations/0001_init.sql`
- [ ] CREATE `worker/src/{index,webhook,licenses,tokens,crypto,email,db,ratelimit}.js`
- [ ] CREATE `worker/test/*.test.js`
- [ ] DELETE `worker/src/index.js` *(old monolith, replaced)*

### Website
- [ ] REWRITE `web/{astro.config.mjs,package.json}`
- [ ] PRESERVE `web/tailwind.config.mjs`
- [ ] CREATE `web/src/layouts/{Base,Guide}.astro`
- [ ] CREATE `web/src/components/MacDemo.tsx` *(ported from `site/src/components/mac-app.tsx`)*
- [ ] CREATE `web/src/components/{DiskRing,Wordmark,SiteHeader,SiteFooter}.tsx` + `ui/`
- [ ] CREATE `web/src/lib/{demo-store,utils}.ts`
- [ ] CREATE `web/src/data/{demo-scan,comparison}.ts`
- [ ] CREATE `web/src/content/guides/*.md` *(ported from `site/src/lib/blog.ts`)*
- [ ] CREATE `web/src/pages/{index,pricing,download,success,privacy,support,refunds}.astro`
- [ ] CREATE `web/src/pages/guides/[...slug].astro`
- [ ] CREATE `web/src/pages/storage/[id].astro`
- [ ] CREATE `web/src/pages/compare/[competitor].astro`
- [ ] CREATE `web/src/styles/global.css` *(ported from `site/src/styles.css`)*
- [ ] CREATE `web/public/robots.txt`
- [ ] MOVE `site/public/{favicon.svg,og.jpg}` → `web/public/`
- [ ] CREATE deployment configuration *(none exists today)*
- [ ] DELETE `site/` **entirely — commit 7.7, only after the port is verified**

### CI
- [ ] CREATE `.github/workflows/ci.yml` (jobs 1–9)
- [ ] REWRITE `.github/workflows/build-mac.yml` (universal, Developer ID, notarize, staple, 12-point verify, SHA-256)

---

# PART 25 — FINAL ACCEPTANCE GATES

Each gate is objective pass/fail. **A gate does not pass partially.**

### GATE 0 — Repository and build baseline
`swift build -c release` succeeds · `swift test` runs · CI jobs 1–3 green · `web/dist/` and `worker/.wrangler/cache/wrangler-account.json` untracked · guardrail greps pass on the current tree.

### GATE 1 — Filesystem safety
`grep -rn "deletelocalsnapshots\|removeItem\|rm -rf" app/Sources/DiskPrune/` → **empty** · `CleanupExecutor.execute` has exactly one parameter, of type `CleanupPlan` · `PlannedItem.init?` returns `nil` for all eight conditions (T-PLAN-01…08) · `CleanupPlan.init?` rejects empty and ancestor/descendant (T-PLAN-09/10) · all seven TOCTOU checks fail independently (T-TOC-01…07) · a 10-item batch with one failure completes 9 (T-CLN-01) · unplanned siblings survive (T-CLN-05) · no `removeItem` invoked when Trash fails (T-CLN-04, spy-verified) · `Cleanup/` imports nothing from `Scanning/`.

### GATE 2 — Scanner and accounting correctness
Fixture sizes within 1 block (T-SIZE-01) · **on a real Mac [M], DerivedData size within 2% of `du -sk`** · hardlinks counted once at both scopes (T-HL-01/02) · headline totals never sum per-item figures (T-HL-04) · sparse file reports allocated ≪ logical (T-SPARSE-01) · symlinks never followed (T-SYM-01…03) · no item is an ancestor of another (T-GRP-01) · `.app` emits no children (T-APP-01) · denied subtree → `.partial`, scan completes (T-PERM-01) · `permissionLimitedBytes == nil` (T-COV-03) · **dashboard never displays "Zero bytes" after a successful scan** · **T-TERM-01 green: "freed"/"reclaimed" absent from receipt rendering** · **[M] full cleanup leaves `tmutil listlocalsnapshots /` unchanged** (T-SNAP-04).

### GATE 3 — Licensing and payment correctness
`curl -X POST .../webhook -d '{"type":"checkout.session.completed"}'` → **`400`, no DB write** · replayed event → one license, including across a simulated restart (T-WH-03/05) · concurrent deliveries → exactly one (T-WH-06) · `completed`+`unpaid` → no license (T-WH-07) · `async_payment_succeeded` → license (T-WH-08) · refund → revoked (T-WH-10) · dispute → `disputed`, **not revoked**; won → `active` (T-WH-11) · **released device cannot refresh (T-REF-02)** · revoked cannot refresh (T-REF-03) · disputed refreshes with a 14-day token (T-REF-04) · expired-but-valid refreshes (T-REF-05) · `security add-generic-password` grants nothing (T-KC-01) · tampered token rejected (T-TOK-02) · **encrypted key round-trips and resend works after a simulated email failure (T-ENC-01, T-EMAIL-02)** · **plaintext key absent from all logs (T-ENC-04)** · `/v1/checkout/fake/status` reveals nothing (T-CHK-01) · **free tier functional under every license failure state (T-OFF-07)**.

### GATE 4 — Native product UX
Every item shows explanation and consequence · `safe` pre-checked, `review` not, `protected` uncheckable · dry run precedes every cleanup and states "Nothing has changed yet" · receipt renders the exact four-line block · empty, error, and partial states designed for every screen · scan works and is honest without FDA · Autopsy distinguishes examined / explained / not examined / permission-limited · **[M] a stranger can explain, in their own words, why their Mac is full after reading the Autopsy.**

### GATE 5 — Universal signed notarized release
All 12 PART 19.4 checks pass **against the `.app` extracted from the mounted DMG** · `lipo -archs` → `x86_64 arm64` · `spctl` → "accepted, source=Notarized Developer ID" · **[M] clean Mac: download, verify SHA-256, double-click, drag, launch — no Terminal, no System Settings** · **[M] Intel Mac launches** · versions consistent between tag, Info.plist, and the release page · SHA-256 published.

### GATE 6 — Website, demo, SEO
`npm run build` → static output, no DB step (T-WEB-01) · no auth/db/multiplayer imports (T-WEB-02) · `issueLicense` absent (T-WEB-05) · demo disclosure visible at 375 px (T-WEB-03) · `results → trashing` impossible (T-WEB-04) · every page has title, description, canonical (T-SEO-01) · every sitemap URL 200 (T-SEO-02) · structured data valid, **no `aggregateRating`** (T-SEO-03) · `/storage/*` count == `publish: true` count (T-SEO-04) · **every competitor claim sourced, dated, linked, and naming something they do better** · **every product claim true of the shipped binary** · "notarized" appears only because GATE 5 passed · `site/` deleted.

### GATE 7 — Launch rehearsal (all manual)
Real purchase with a real card → key arrives **by email** → activates the real app → cleanup runs → receipt is honest → refund in Stripe → license revoked at next refresh · a second Mac activates (seat 2) · release seat 2 → **refresh from that Mac returns `403 DEVICE_RELEASED`** · resend endpoint delivers the key after a simulated failure · `/success?session_id=fake` claims no payment and reveals no key · support email answered by a human · **the owner has personally run a full scan and cleanup on their own primary Mac and would do it again.**

---

# PART 26 — CONTRADICTION AUDIT

Performed against this document and Mega Plan v2. All resolved.

| Area | Contradiction found | Resolution |
|---|---|---|
| **Trash vs freed** | v2 called the post-cleanup measurement "verified reclaim", implying trashing frees space | **Correction 1 applied throughout.** Four distinct values (§5.1, §7.6); terminology contract; T-TERM-01 enforces it; truth metric changed to `successfullyTrashedBytes / estimatedRecoverableBytes` |
| **Truth metric** | v2's `verifiedReclaim / estimated` would read ~0 for same-volume Trash and flag a false defect | Metric redefined (§5.1); `immediateAvailableDelta` reported separately and honestly |
| **Encrypted recovery** | v2 stored only `key_hash` while promising resend and retry — impossible | **Correction 2.** `encrypted_key` (AES-256-GCM, per-row IV, row-id AAD, versioned prefix); three enumerated decrypt sites; T-EMAIL-02 proves recovery |
| **Device release** | v2's release set `released_at` but refresh did not check it | **Correction 3.** §11.5 step 5 → `403 DEVICE_RELEASED`; T-REF-02 |
| **Dispute** | v2 revoked on `dispute.created`, punishing a customer who may win | **Correction 4.** `active/disputed/revoked` lifecycle; refresh permitted while disputed with a 14-day token; T-WH-11, T-REF-04 |
| **Write boundary** | v2 said "`Cleanup/` is the only directory permitted to write" while receipts are also written | **Correction 5.** Boundary restated as *user-managed filesystem content*; `Persistence/` permitted; guardrails target destructive APIs only (§20.1) |
| **Coverage** | v2's Autopsy could imply classified bytes explained the whole disk | **Correction 6.** `StorageCoverage` with measured/derived/unknown classes; required copy pattern; T-COV-02/03 |
| **Hardlink scope** | v2's per-item `Set<FileID>` double-counts across items in aggregates | **Correction 7.** Two explicit scopes (§7.3); aggregates use scan-global; UI never sums per-item; T-HL-02/04 |
| **APFS clones** | Risk of implying clone-aware accounting | Explicitly **not** claimed; disclosed in §7.5 and on `/support`; `notExaminedBytes` clamps at 0 (T-COV-04) |
| **Scanner vs cleanup** | Risk of a convenience path from scan results to deletion | Type-level separation (§6.1/6.2); import guardrail; no `[URL]` overload exists |
| **`.app` semantics** | "measure whole" vs "protected" read as conflicting | Measurement ≠ candidacy (§5.1, §6.3 check 6, §9); T-APP-01/02 |
| **Protected paths** | Deny list scattered across documents | Single source: `PathValidator.denyList` (§5.4) + `protected` rules (§8.4); both enforced |
| **TOCTOU** | v2 implied a race-free guarantee | Limitation stated plainly (§6.3); reversibility named as the real mitigation |
| **Snapshots** | Risk of an "advanced" escape hatch reappearing | No delete API exists; `SnapshotInspector` has one function; T-SNAP-03 greps the repo; PART 23 rule 6 |
| **Docker** | v2 classified `Docker.raw` `.advanced` — a selectable tier | Never a cleanup candidate, running or stopped (§9.2); T-DOCK-02/03; `.advanced` emits no v1 targets at all (§5.1) |
| **Full Disk Access** | Heuristic probe risked being presented as proof | `probeLikelyGranted()` informs ordering only; attempt-first; T-PERM-04 |
| **D1 transactions** | KV eventual consistency vs idempotency claim | D1 PK constraint; concurrency proof in §14.3; T-WH-05/06 |
| **Activation vs refresh** | Two similar flows risked divergent checks | Both specified as ordered chains (§11.4, §11.5) with distinct error codes |
| **Token expiry** | v2 had a 30-day grace *and* a 90-day token | One mechanism: expiry (§13). Grace removed |
| **Offline** | Risk of the free tier being gated by license state | Free tier has **no** code path consulting `LicenseManager`; T-OFF-07 |
| **Revoked/disputed** | Behavior on existing tokens undefined | Full matrix in §11.3 and §13 |
| **Stripe states** | `completed` treated as paid | `payment_status` rules + async lifecycle (§14.2); T-WH-07/08/09 |
| **Browser exposure** | v2 reintroduced `session_id` as a retrieval credential | **No key or claim token ever crosses the browser** (§16.3); status endpoint returns state + masked email only; T-CHK-01/02 |
| **Shared rules** | SPM cannot reference resources outside the target | `/shared` canonical + generated copy + CI drift gate (§8.5); "no second source" is Builder Rule 13 |
| **Demo vs native** | Demo had selection the app lacked, and flushed snapshots | Demo state machine (§17.2) mirrors the app; snapshots inspect-only; auto-purge-on-activation removed |
| **Website vs binary** | Site claimed a Tier-2 review flow and approval-gated cleanup that did not exist | Claims rewritten in 7.4; GATE 6 requires every claim be true of the shipped binary |
| **Universal build** | Log-based evidence is insufficient | `lipo -archs` on the `.app` inside the mounted DMG (§19.4 #9, T-REL-01) |
| **Signing** | `--deep` is Apple-deprecated for distribution | Explicit inside-out signing (§19.3); `--deep` used only in `--verify` |
| **Notarization** | Site could claim "notarized" before it was true | GATE 6 requires GATE 5 first |
| **CI safety checks** | Guardrails would flag legitimate `Persistence/` writes | Scoped to destructive APIs; exclusions listed (§20.1) |
| **Enterprise scope** | v2's ">2,000 users" was an arbitrary rule | Demand-led; only the six data-model foundations are built |

**No unresolved contradictions remain.**

---

## Verified external facts (re-verify before publishing any competitor claim)

DaisyDisk $9.99 lifetime / 5 Macs · DissectMac free + $12.99 one-time Pro · GrandPerspective free / $2.99 · CleanMyMac ~$34.95/yr · macOS 26 Tahoe 26.6.2 (Aug 2026), last Intel-supporting release · Sequoia removed the Ctrl-click Gatekeeper bypass · `macos-14` GitHub runners are arm64-only · Stripe `constructEventAsync` + `createSubtleCryptoProvider` required on Workers · Stripe dispute fee $15 + $15 counter fee · Apple Developer Program $99/yr, `xcrun notarytool` the only supported CLI · CryptoKit `Curve25519.Signing` available macOS 10.15+.

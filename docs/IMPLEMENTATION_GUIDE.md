# Implementation guide

## Layout

- `shared/storage-rules.json` — the only hand-edited rules file
- `scripts/sync-rules.sh` — copies it into the app resource with `generated: true`
- `scripts/validate-rules.mjs` — schema and handoff constraints
- `scripts/ci-guardrails.sh` — destructive-API and architecture greps
- `app/Sources/DiskPrune` — native code, one SPM executable + tests
- `worker/` — licensing (Phase 4 rewrite still pending)
- `site/` — current preview website (delete only after `web/` port, commit 7.7)

## Native pipeline

`ScanEngine` streams `ScanEvent`s from probes in a fixed order (Xcode → Docker → Package managers → Caches → Logs). It holds scan-global `SeenFileIDs` for hardlink accounting. It has no filesystem-mutating API.

`PlannedItem.init?(item:userSelected:)` is the only constructor and enforces eight conditions. `CleanupPlan.init?` rejects empty plans and ancestor/descendant pairs.

`CleanupExecutor.execute(_:)` takes a `CleanupPlan` only (DEC-008). Per item: seven TOCTOU checks, then `trashItem`. Failures never abort the batch. There is no `removeItem` fallback.

## Running checks

```bash
node scripts/validate-rules.mjs
bash scripts/sync-rules.sh
bash scripts/ci-guardrails.sh
cd app && swift test   # macOS
```

# Cleanup safety

## Non-negotiable

1. The only destructive call is `FileManager.trashItem`. There is no `removeItem` fallback.
2. DiskPrune never empties Trash.
3. DiskPrune never deletes APFS local snapshots.
4. DiskPrune never deletes `Docker.raw` or Docker data directories.
5. A cleanup plan cannot contain both an ancestor and a descendant.
6. Symlinks are never cleanup candidates.
7. Paths containing a `.app` component are never cleanup candidates.
8. Every `trashItem` is preceded by the seven TOCTOU checks in `PathValidator.revalidateBeforeTrash`.

## Terminology (Correction 1)

| Value | Say | Never say |
| --- | --- | --- |
| Plan estimate | Estimated recoverable | will free / will reclaim |
| Successful `trashItem` | Moved to Trash | freed / reclaimed / deleted / removed |
| Volume delta | Storage immediately available | reclaimed |

Moving to Trash does **not** immediately increase available capacity on the same volume. Receipts must report the measured delta, including zero and negative.

## Current code vs target

The new UI calls only `CleanupExecutor.execute(_ plan: CleanupPlan)`. Legacy `ScannerActor.trash(urls:)` has been deleted (Rule 18).


# Storage accounting

DiskPrune reports **space on disk** (`st_blocks × 512`), not Finder's logical size.

| Value | Source | Class |
| --- | --- | --- |
| `logicalBytes` | Σ `st_size` | measured |
| `onDiskBytes` | Σ `st_blocks × 512` | measured |
| Volume total / available / used | `URLResourceValues` | measured |
| `classifiedBytes` | scan-global hardlink-deduped sum of items with a rule | measured |
| `unclassifiedScannedBytes` | scanned, no rule | measured |
| `examinedBytes` | classified + unclassified | measured |
| `notExaminedBytes` | max(0, volumeUsed − examined) | derived — labeled "not examined" |
| `permissionLimitedBytes` | — | **always nil in v1** |

## Hardlinks

Two scopes:

- **Item-local:** a hardlinked inode counts once inside one item's `onDiskBytes`.
- **Scan-global:** the same inode counts once in `StorageCoverage`. The first item to encounter it owns those bytes for aggregates.

`Σ item.onDiskBytes` may exceed `coverage.classifiedBytes`. Headline totals come from `StorageCoverage`, never from summing the table.

## Sparse files, compression, clones

- Sparse (`Docker.raw`): `onDiskBytes` is allocated blocks; detail view also shows logical size.
- APFS compression: `st_blocks` already reflects compressed allocation.
- APFS clones: **not modelled**. Two clones can each report full size; removing one may free almost nothing.

## Cleanup numbers

Moving to Trash does not free space. Receipts report:

1. Estimated recoverable
2. Moved to Trash
3. Storage immediately available (measured delta, may be ~0 or negative)

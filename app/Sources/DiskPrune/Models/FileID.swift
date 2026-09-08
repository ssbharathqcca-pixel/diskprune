import Foundation

/// Physical file identity for hardlink deduplication and TOCTOU revalidation.
/// Constructed only by `FileIdentity` from `lstat.st_dev` / `lstat.st_ino`.
struct FileID: Hashable, Sendable, Codable {
    let dev: UInt64
    let ino: UInt64
}

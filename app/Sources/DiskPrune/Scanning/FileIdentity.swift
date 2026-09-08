import Darwin
import Foundation

enum FileIdentityError: Error, Equatable {
    case notFound
    case permissionDenied
    case tooManyLinks
    case other(Int32)
}

enum FileIdentity {
    struct Stat: Sendable {
        let fileID: FileID
        let objectType: ObjectType
        let logicalBytes: Int64
        let onDiskBytes: Int64
        let linkCount: UInt64
        let modified: Date?
        let sizeApproximate: Bool
    }

    /// The only POSIX entry in the codebase. Uses `lstat`, never `stat`.
    static func lstat(_ path: String) -> Result<Stat, FileIdentityError> {
        var st = Darwin.stat()
        let rc = Darwin.lstat(path, &st)
        if rc != 0 {
            switch errno {
            case ENOENT, ENOTDIR:
                return .failure(.notFound)
            case EACCES, EPERM:
                return .failure(.permissionDenied)
            case ELOOP:
                return .failure(.tooManyLinks)
            default:
                return .failure(.other(errno))
            }
        }

        let mode = Int32(st.st_mode)
        let objectType: ObjectType
        switch mode & Int32(S_IFMT) {
        case Int32(S_IFDIR):
            objectType = .directory
        case Int32(S_IFREG):
            objectType = .regularFile
        case Int32(S_IFLNK):
            objectType = .symlink
        default:
            objectType = .other
        }

        let logical = Int64(st.st_size)
        // Always st_blocks × 512. A sparse file (ftruncate / Docker.raw) reports
        // st_blocks == 0 with st_size > 0; that is a valid measurement, not a
        // reason to fall back to logical size.
        let onDisk = Int64(st.st_blocks) * 512

        let modified: Date?
        let ts = st.st_mtimespec
        if ts.tv_sec > 0 {
            modified = Date(timeIntervalSince1970: TimeInterval(ts.tv_sec) + TimeInterval(ts.tv_nsec) / 1_000_000_000)
        } else {
            modified = nil
        }

        let fileID = FileID(dev: UInt64(truncatingIfNeeded: st.st_dev), ino: UInt64(st.st_ino))
        return .success(
            Stat(
                fileID: fileID,
                objectType: objectType,
                logicalBytes: logical,
                onDiskBytes: onDisk,
                linkCount: UInt64(st.st_nlink),
                modified: modified,
                sizeApproximate: false
            )
        )
    }
}

/// Lock-protected set standing in for the spec's `inout Set<FileID>` (DEC-007).
final class SeenFileIDs: @unchecked Sendable {
    private let lock = NSLock()
    private var ids = Set<FileID>()

    @discardableResult
    func insert(_ id: FileID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return ids.insert(id).inserted
    }

    func contains(_ id: FileID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return ids.contains(id)
    }

    var snapshot: Set<FileID> {
        lock.lock()
        defer { lock.unlock() }
        return ids
    }
}

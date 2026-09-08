import Foundation

struct SizeResult: Sendable {
    let onDiskBytes: Int64
    let logicalBytes: Int64
    let fileCount: Int
    let newestModification: Date?
    let scanState: ScanState
    let encounteredFileIDs: Set<FileID>
    let globallyNewOnDiskBytes: Int64
    let sizeApproximate: Bool
    let deniedPaths: [String]
}

enum DirectorySizer {
    static let depthCap = 64

    static func measure(root: URL, globalSeen: SeenFileIDs) async -> SizeResult {
        var itemLocal = Set<FileID>()
        var encountered = Set<FileID>()
        var denied: [String] = []
        var onDisk: Int64 = 0
        var logical: Int64 = 0
        var files = 0
        var newest: Date?
        var globallyNew: Int64 = 0
        var approximate = false
        var pathStack = Set<FileID>()

        func walk(_ url: URL, depth: Int) {
            if Task.isCancelled { return }
            if depth > depthCap { return }

            let path = url.path
            switch FileIdentity.lstat(path) {
            case .failure(.notFound):
                return
            case .failure(.permissionDenied):
                denied.append(path)
                return
            case .failure:
                return
            case .success(let st):
                if pathStack.contains(st.fileID) {
                    return
                }

                if st.linkCount > 1 {
                    encountered.insert(st.fileID)
                    if !itemLocal.insert(st.fileID).inserted {
                        return
                    }
                }

                let newToGlobal: Bool
                if st.linkCount > 1 {
                    newToGlobal = globalSeen.insert(st.fileID)
                } else {
                    newToGlobal = true
                }

                if st.sizeApproximate { approximate = true }
                onDisk += st.onDiskBytes
                logical += st.logicalBytes
                if newToGlobal { globallyNew += st.onDiskBytes }
                if st.objectType != .directory { files += 1 }
                if let m = st.modified {
                    if newest == nil || m > newest! { newest = m }
                }

                switch st.objectType {
                case .symlink, .other, .regularFile:
                    return
                case .directory:
                    pathStack.insert(st.fileID)
                    defer { pathStack.remove(st.fileID) }

                    let isAppBundle = url.pathExtension == "app"
                    guard let children = try? FileManager.default.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: nil,
                        options: [.skipsPackageDescendants]
                    ) else {
                        denied.append(path)
                        return
                    }
                    for child in children {
                        if Task.isCancelled { return }
                        if isAppBundle {
                            walk(child, depth: depth + 1)
                        } else if child.pathExtension == "app" {
                            walk(child, depth: depth + 1)
                        } else {
                            walk(child, depth: depth + 1)
                        }
                    }
                }
            }
        }

        switch FileIdentity.lstat(root.path) {
        case .failure(.permissionDenied):
            return SizeResult(
                onDiskBytes: 0,
                logicalBytes: 0,
                fileCount: 0,
                newestModification: nil,
                scanState: .denied,
                encounteredFileIDs: [],
                globallyNewOnDiskBytes: 0,
                sizeApproximate: false,
                deniedPaths: [root.path]
            )
        case .failure:
            return SizeResult(
                onDiskBytes: 0,
                logicalBytes: 0,
                fileCount: 0,
                newestModification: nil,
                scanState: .complete,
                encounteredFileIDs: [],
                globallyNewOnDiskBytes: 0,
                sizeApproximate: false,
                deniedPaths: []
            )
        case .success:
            walk(root, depth: 0)
        }

        let state: ScanState
        if denied.contains(root.path) && onDisk == 0 && files == 0 {
            state = .denied
        } else if denied.isEmpty {
            state = .complete
        } else {
            state = .partial(deniedPaths: denied)
        }

        return SizeResult(
            onDiskBytes: onDisk,
            logicalBytes: logical,
            fileCount: files,
            newestModification: newest,
            scanState: state,
            encounteredFileIDs: encountered,
            globallyNewOnDiskBytes: globallyNew,
            sizeApproximate: approximate,
            deniedPaths: denied
        )
    }
}

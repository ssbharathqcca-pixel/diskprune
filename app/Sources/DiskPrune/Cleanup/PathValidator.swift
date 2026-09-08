import Foundation

enum PathValidator {
    static var denyList: [String] {
        let home = NSHomeDirectory()
        return [
            "\(home)/Documents",
            "\(home)/Desktop",
            "\(home)/Downloads",
            "\(home)/Pictures",
            "\(home)/Movies",
            "\(home)/Music",
            "\(home)/Library/Mobile Documents",
            "\(home)/Library/Keychains",
            "\(home)/Library/Messages",
            "\(home)/Library/Mail",
            "\(home)/Library/Photos",
            "\(home)/Library/Application Support/MobileSync",
            "\(home)/.ssh",
            "\(home)/.gnupg",
            "\(home)/.aws",
            "\(home)/.config/gcloud",
            "/System",
            "/Library/Apple",
            "/private/var/db",
            "/Applications",
        ]
    }

    static func isDenied(_ path: String) -> Bool {
        let standardized = (path as NSString).standardizingPath
        if hasAppComponent(standardized) { return true }
        for entry in denyList {
            let e = (entry as NSString).standardizingPath
            if standardized == e || standardized.hasPrefix(e + "/") {
                return true
            }
        }
        return false
    }

    static func hasAppComponent(_ path: String) -> Bool {
        URL(fileURLWithPath: path).pathComponents.contains { $0.hasSuffix(".app") }
    }

    static func isStrictDescendant(_ url: URL, of root: URL) -> Bool {
        let child = url.resolvingSymlinksInPath().standardized.path
        let parent = root.resolvingSymlinksInPath().standardized.path
        if child == parent { return true }
        return child.hasPrefix(parent.hasSuffix("/") ? parent : parent + "/")
    }

    static func pathDepth(_ path: String) -> Int {
        URL(fileURLWithPath: path).standardized.pathComponents.filter { $0 != "/" }.count
    }

    static func validateForPlanning(_ item: StorageItem) -> Bool {
        PlannedItem(item: item, userSelected: true) != nil
    }

    static func revalidateBeforeTrash(_ planned: PlannedItem) -> Result<Void, SkipReason> {
        switch FileIdentity.lstat(planned.url.path) {
        case .failure(.notFound):
            return .failure(.vanished)
        case .failure:
            return .failure(.vanished)
        case .success(let st):
            if st.objectType == .symlink {
                return .failure(.becameSymlink)
            }
            if st.objectType != planned.objectType {
                return .failure(.typeChanged)
            }
            if st.fileID != planned.fileID {
                return .failure(.identityChanged)
            }
        }
        let resolved = planned.url.resolvingSymlinksInPath().standardized
        if !isStrictDescendant(resolved, of: planned.cleanupRoot) {
            return .failure(.escapedCleanupRoot)
        }
        if hasAppComponent(resolved.path) {
            return .failure(.appBundleAncestor)
        }
        if isDenied(resolved.path) {
            return .failure(.denyListed)
        }
        return .success(())
    }
}

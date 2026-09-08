import Foundation

struct XcodeProbe: Probe {
    let name = "Xcode"

    func discover(knowledge: StorageKnowledge, globalSeen: SeenFileIDs) async -> [StorageItem] {
        var items: [StorageItem] = []

        let derivedDefault = ProbeSupport.expand("~/Library/Developer/Xcode/DerivedData")
        let derivedPath = ProcessInfo.processInfo.environment["DERIVED_DATA_PATH"].flatMap { $0.isEmpty ? nil : $0 } ?? derivedDefault
        let derivedRoot = URL(fileURLWithPath: derivedPath)
        if ProbeSupport.exists(derivedRoot.path) {
            if let children = try? FileManager.default.contentsOfDirectory(
                at: derivedRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            ) {
                for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                    if child.lastPathComponent == "ModuleCache.noindex" { continue }
                    var isDir: ObjCBool = false
                    FileManager.default.fileExists(atPath: child.path, isDirectory: &isDir)
                    guard isDir.boolValue else { continue }
                    let projectName = child.lastPathComponent.split(separator: "-").first.map(String.init) ?? child.lastPathComponent
                    if let item = await ProbeSupport.item(
                        at: child,
                        knowledge: knowledge,
                        globalSeen: globalSeen,
                        displayName: "Xcode DerivedData — \(projectName)",
                        cleanupRoot: derivedRoot
                    ) {
                        items.append(item)
                    }
                }
            }
            let moduleCache = derivedRoot.appendingPathComponent("ModuleCache.noindex")
            if ProbeSupport.exists(moduleCache.path),
               let item = await ProbeSupport.item(at: moduleCache, knowledge: knowledge, globalSeen: globalSeen) {
                items.append(item)
            }
        }

        let archives = URL(fileURLWithPath: ProbeSupport.expand("~/Library/Developer/Xcode/Archives"))
        if ProbeSupport.exists(archives.path),
           let dates = try? FileManager.default.contentsOfDirectory(at: archives, includingPropertiesForKeys: nil) {
            for folder in dates.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir)
                guard isDir.boolValue else { continue }
                if let item = await ProbeSupport.item(
                    at: folder,
                    knowledge: knowledge,
                    globalSeen: globalSeen,
                    displayName: "Xcode Archive — \(folder.lastPathComponent)",
                    cleanupRoot: archives
                ) {
                    items.append(item)
                }
            }
        }

        let deviceSupport = URL(fileURLWithPath: ProbeSupport.expand("~/Library/Developer/Xcode/iOS DeviceSupport"))
        if ProbeSupport.exists(deviceSupport.path),
           let versions = try? FileManager.default.contentsOfDirectory(at: deviceSupport, includingPropertiesForKeys: nil) {
            for version in versions.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: version.path, isDirectory: &isDir)
                guard isDir.boolValue else { continue }
                if let item = await ProbeSupport.item(
                    at: version,
                    knowledge: knowledge,
                    globalSeen: globalSeen,
                    displayName: "iOS DeviceSupport — \(version.lastPathComponent)",
                    cleanupRoot: deviceSupport
                ) {
                    items.append(item)
                }
            }
        }

        let simRoot = URL(fileURLWithPath: ProbeSupport.expand("~/Library/Developer/CoreSimulator/Devices"))
        let runtimeRoot = URL(fileURLWithPath: ProbeSupport.expand("~/Library/Developer/CoreSimulator/Profiles/Runtimes"))
        if ProbeSupport.exists(simRoot.path),
           let devices = try? FileManager.default.contentsOfDirectory(at: simRoot, includingPropertiesForKeys: nil) {
            for device in devices {
                let plist = device.appendingPathComponent("device.plist")
                var display = "Simulator \(device.lastPathComponent)"
                if let data = try? Data(contentsOf: plist),
                   let obj = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                    let name = obj["name"] as? String
                    let runtime = obj["runtime"] as? String
                    if let name {
                        display = name
                        if let runtime { display += " — \(runtime)" }
                    }
                }
                if let item = await ProbeSupport.item(
                    at: device,
                    knowledge: knowledge,
                    globalSeen: globalSeen,
                    displayName: display,
                    cleanupRoot: simRoot
                ) {
                    items.append(item)
                }
                _ = runtimeRoot
            }
        }

        return items
    }
}

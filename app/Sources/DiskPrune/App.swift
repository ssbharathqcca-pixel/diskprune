import AppKit
import SwiftUI

@main
struct DiskPruneApp: App {
    var body: some Scene {
        WindowGroup {
            Group {
                if let knowledge = try? StorageKnowledge.load() {
                    if VisualQARuntime.isEnabled {
                        VisualQARuntime.root(knowledge: knowledge)
                    } else {
                        RootView(session: AppSession(knowledge: knowledge))
                    }
                } else {
                    KnowledgeLoadErrorView()
                }
            }
        }
        .defaultSize(width: Geometry.windowDefault.width, height: Geometry.windowDefault.height)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About DiskPrune") {
                    NSApp.orderFrontStandardAboutPanel(options: [:])
                }
            }
            CommandGroup(after: .newItem) {
                Button("Scan") {
                    NotificationCenter.default.post(name: .diskPruneScan, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsRootView(knowledge: try? StorageKnowledge.load())
        }
    }
}

extension Notification.Name {
    static let diskPruneScan = Notification.Name("com.diskprune.app.scan")
}

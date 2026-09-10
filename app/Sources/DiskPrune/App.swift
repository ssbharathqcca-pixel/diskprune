import AppKit
import SwiftUI

@main
struct DiskPruneApp: App {
    init() {
#if DISKPRUNE_VISUAL_QA
        if VisualQARuntime.isEnabled {
            PreferencesStore.scanOnLaunch = false
        } else {
            LicenseManager.shared.start()
        }
        VisualQARuntime.trace("DiskPruneApp.init enabled=\(VisualQARuntime.isEnabled)")
#else
        LicenseManager.shared.start()
#endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let knowledge = try? StorageKnowledge.load() {
#if DISKPRUNE_VISUAL_QA
                    if VisualQARuntime.isEnabled {
                        VisualQARuntime.root(knowledge: knowledge)
                    } else {
                        RootView(session: AppSession(knowledge: knowledge))
                    }
#else
                    RootView(session: AppSession(knowledge: knowledge))
#endif
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

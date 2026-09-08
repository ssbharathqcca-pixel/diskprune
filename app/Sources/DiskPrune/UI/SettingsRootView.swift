import AppKit
import SwiftUI

struct SettingsRootView: View {
    var knowledge: StorageKnowledge?

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            LicenseView()
                .tabItem { Label("Licence", systemImage: "key") }
            AdvancedSettingsView(knowledge: knowledge)
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 520, height: 360)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("scanOnLaunch") private var scanOnLaunch = false

    var body: some View {
        Form {
            Toggle("Scan on launch", isOn: $scanOnLaunch)
            LabeledContent("Appearance", value: "Follows system")
            Toggle("Confirm before Trash", isOn: .constant(true))
                .disabled(true)
            Text("DiskPrune always asks before moving files to Trash.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: scanOnLaunch) { value in
            PreferencesStore.scanOnLaunch = value
        }
        .onAppear {
            scanOnLaunch = PreferencesStore.scanOnLaunch
        }
    }
}

struct AdvancedSettingsView: View {
    var knowledge: StorageKnowledge?

    var body: some View {
        Form {
            LabeledContent("Rules version", value: knowledge?.rulesVersion ?? "unavailable")
            Button("Reveal receipts folder") {
                let dir = ReceiptStore.directory
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                NSWorkspace.shared.open(dir)
            }
            Button("Reset warnings") {
                PreferencesStore.resetWarnings()
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

import AppKit
import SwiftUI

/// Settings Licence tab. Entitlement is a verified token, never Keychain presence.
struct LicenseView: View {
    @ObservedObject var manager: LicenseManager
    @State private var licenseKey = ""

    private let buyURL = URL(string: "https://buy.stripe.com/eVqeVc8nd9wx39efNdaR200")

    init(manager: LicenseManager) {
        self.manager = manager
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Status", value: manager.statusLabel)
                if let warning = manager.clockWarning {
                    Text(warning)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if manager.status == .expired || manager.status == .needsOnlineCheck {
                    Text("DiskPrune needs to check your license. Connect to the internet.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Check license") {
                        Task { await manager.refresh() }
                    }
                    .disabled(manager.busy)
                }
                if manager.status == .releasedExpired {
                    Text("This Mac was released. Activate it again in Settings → Licence.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if let message = manager.lastUserMessage, !message.isEmpty {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text("Scanning, explanations, and cleanup planning remain available.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section {
                TextField("Licence key", text: $licenseKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(manager.busy || manager.status == .active)
                Button("Activate") {
                    Task { await manager.activate(licenseKey: licenseKey) }
                }
                .disabled(manager.busy || manager.status == .active || licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let buyURL {
                    Button("Buy") {
                        NSWorkspace.shared.open(buyURL)
                    }
                }
            }
            Section("Devices") {
                if manager.hasStoredToken || !manager.seatLimitDevices.isEmpty {
                    LabeledContent(ProcessInfo.processInfo.hostName, value: "This Mac")
                    if manager.hasStoredToken {
                        Button("Release this Mac") {
                            Task { await manager.release() }
                        }
                        .disabled(manager.busy)
                    }
                    ForEach(manager.seatLimitDevices) { device in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.deviceName ?? device.deviceId)
                                if let seen = device.lastSeen {
                                    Text(seen.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Release") {
                                Task { await manager.release(deviceId: device.deviceId) }
                            }
                            .disabled(manager.busy)
                        }
                    }
                } else {
                    Text("Device management appears after licence activation.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480)
        .padding()
    }
}

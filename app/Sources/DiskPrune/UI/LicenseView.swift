import AppKit
import SwiftUI

/// Settings Licence tab shell. Does not derive entitlement from Keychain presence.
/// Real token verification is Phase 5. Scanning and explanations stay available.
struct LicenseView: View {
    private let buyURL = URL(string: "https://buy.stripe.com/eVqeVc8nd9wx39efNdaR200")

    var body: some View {
        Form {
            Section {
                LabeledContent("Status", value: "Not activated")
                Text("Scanning, explanations, and cleanup planning remain available. Paid activation is not wired in this build.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section {
                if let buyURL {
                    Button("Buy") {
                        NSWorkspace.shared.open(buyURL)
                    }
                }
            }
            Section("Devices") {
                Text("Device management appears after licence activation.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480)
        .padding()
    }
}

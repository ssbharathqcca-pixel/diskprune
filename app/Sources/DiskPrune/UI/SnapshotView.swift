import SwiftUI

struct SnapshotView: View {
    let summary: SnapshotSummary?

    var body: some View {
        Group {
            if let summary, summary.readFailed {
                EmptyStateView(
                    symbol: "clock.arrow.circlepath",
                    title: "Couldn't read snapshots",
                    detail: "DiskPrune couldn't list local Time Machine snapshots. This is inspect-only — nothing was changed."
                )
            } else if let summary, summary.count == 0 {
                EmptyStateView(
                    symbol: "clock.arrow.circlepath",
                    title: "No local snapshots found",
                    detail: "macOS has no local Time Machine snapshots on this volume right now."
                )
            } else if let summary {
                snapshotList(summary)
            } else {
                EmptyStateView(
                    symbol: "clock.arrow.circlepath",
                    title: "No local snapshots found",
                    detail: "Scan to list local Time Machine snapshots. DiskPrune does not delete snapshots."
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Snapshots")
    }

    private func snapshotList(_ summary: SnapshotSummary) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Space.md) {
                    Text("macOS keeps local Time Machine snapshots so you can restore files without your backup drive. They can hold tens of gigabytes, and macOS usually returns that space automatically when your disk fills up.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("DiskPrune does not delete snapshots.")
                        .font(.callout.weight(.medium))
                    Link("About local snapshots (Apple)", destination: URL(string: "https://support.apple.com/en-us/102154")!)
                        .font(.callout)
                }
                .padding(.vertical, Space.sm)
            } header: {
                Text("Local snapshots · \(summary.count)")
            }

            Section("Dates") {
                ForEach(Array(summary.dates.enumerated()), id: \.offset) { _, date in
                    Text(UIFormat.snapshotDate(date))
                        .font(.body.monospacedDigit())
                        .textSelection(.enabled)
                }
            }
        }
        .listStyle(.inset)
        .environment(\.defaultMinListRowHeight, Geometry.rowStandard)
    }
}

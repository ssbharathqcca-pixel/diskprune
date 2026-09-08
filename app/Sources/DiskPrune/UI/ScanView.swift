import SwiftUI

struct ScanView: View {
    @ObservedObject var session: AppSession

    private var completedCount: Int { session.completedProbes.count }
    private var totalCount: Int { AppSession.probeOrder.count }
    private var progress: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Geometry.sectionSpacing) {
            HStack {
                Text("Scanning…")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Cancel") { session.cancelScan() }
                    .keyboardShortcut(.cancelAction)
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .accessibilityLabel("Scan progress")
                .accessibilityValue("\(Int(progress * 100)) percent")

            Text(statusLine)
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Space.sm) {
                ForEach(AppSession.probeOrder, id: \.self) { name in
                    probeRow(name)
                }
            }
        }
        .padding(Geometry.contentMargin)
        .frame(maxWidth: Geometry.contentMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var statusLine: String {
        if let active = session.activeProbe {
            return "Reading \(active)"
        }
        return "Finishing…"
    }

    private func probeRow(_ name: String) -> some View {
        let done = session.completedProbes.contains(name)
        let current = session.activeProbe == name
        let bytes = session.probeBytes[name]
        return HStack(spacing: Space.sm) {
            Image(systemName: done ? "checkmark" : (current ? "arrow.right" : "minus"))
                .foregroundStyle(done ? Color.secondary : (current ? Color.primary : Color(nsColor: .tertiaryLabelColor)))
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(name)
                .font(.body)
                .foregroundStyle(done || current ? .primary : .secondary)
            Spacer()
            if let bytes, done {
                Text(UIFormat.bytes(bytes))
                    .font(.body.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(done ? "\(name) complete" : (current ? "\(name) in progress" : name))
    }
}

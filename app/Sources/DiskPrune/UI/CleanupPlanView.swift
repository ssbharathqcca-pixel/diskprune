import SwiftUI

struct CleanupPlanView: View {
    @ObservedObject var session: AppSession

    var body: some View {
        HStack(spacing: Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(session.selectedCount) items selected · \(UIFormat.bytes(session.estimatedRecoverable)) estimated recoverable")
                    .font(.callout.monospacedDigit())
                Text("Nothing has changed yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Review Cleanup") {
                session.presentDryRun()
            }
            .disabled(session.currentPlan == nil || session.phase == .executing)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, Geometry.contentMargin)
        .padding(.vertical, Space.md)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            Divider()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.selectedCount) items selected, \(UIFormat.bytes(session.estimatedRecoverable)) estimated recoverable. Nothing has changed yet.")
    }
}

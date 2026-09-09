import SwiftUI

struct DryRunSheet: View {
    @ObservedObject var session: AppSession

    private var plan: CleanupPlan? { session.currentPlan }

    private var safeCount: Int {
        session.items.filter { session.isSelected($0) && $0.safety == .safe }.count
    }

    private var reviewCount: Int {
        session.items.filter { session.isSelected($0) && $0.safety == .review }.count
    }

    private var safeBytes: Int64 {
        session.items.filter { session.isSelected($0) && $0.safety == .safe }.reduce(0) { $0 + $1.onDiskBytes }
    }

    private var reviewBytes: Int64 {
        session.items.filter { session.isSelected($0) && $0.safety == .review }.reduce(0) { $0 + $1.onDiskBytes }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Geometry.sectionSpacing) {
            Text("Review cleanup")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: Space.sm) {
                summaryRow("\(plan?.itemCount ?? 0) items", UIFormat.bytes(plan?.estimatedRecoverableBytes ?? 0) + " estimated recoverable")
                summaryRow("\(safeCount) Safe", UIFormat.bytes(safeBytes))
                summaryRow("\(reviewCount) Review", UIFormat.bytes(reviewBytes))
            }
            .padding(Geometry.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Geometry.radiusCard, style: .continuous))

            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Files will be moved to Trash. Nothing will be permanently deleted.")
                    .font(.callout)
                Text("Storage becomes available after you empty the Trash.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Nothing has changed yet.")
                    .font(.callout.weight(.medium))
            }

            if !session.canClean {
                Text(session.cleanupBlockedMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel") { session.showDryRun = false }
                    .keyboardShortcut(.cancelAction)
                Button("Move to Trash") { session.confirmMoveToTrash() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(plan == nil || !session.canClean)
            }
        }
        .padding(Geometry.sectionSpacing)
        .frame(minWidth: 440, minHeight: 280)
    }

    private func summaryRow(_ left: String, _ right: String) -> some View {
        HStack {
            Text(left)
                .font(.body)
            Spacer()
            Text(right)
                .font(.body.monospacedDigit())
        }
    }
}

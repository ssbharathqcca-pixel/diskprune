import AppKit
import SwiftUI

struct ReceiptView: View {
    let receipt: CleanupReceipt
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Geometry.sectionSpacing) {
            Text(title)
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: Space.sm) {
                line("Estimated recoverable", UIFormat.bytes(receipt.estimatedRecoverableBytes))
                line("Moved to Trash", UIFormat.bytes(receipt.successfullyTrashedBytes))
                line("Storage immediately available", immediatelyAvailable)
            }
            .padding(Geometry.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Geometry.radiusCard, style: .continuous))

            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Your files are still in Trash and can be restored.")
                    .font(.callout)
                HStack {
                    Text("Empty Trash to permanently reclaim this space.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Trash", action: openTrash)
                }
            }

            outcomeSection

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Geometry.sectionSpacing)
        .frame(minWidth: 480, minHeight: 360)
    }

    private var title: String {
        if trashedCount == 0 && failedCount == 0 {
            return "All items were skipped"
        }
        if trashedCount == 0 && skippedCount == 0 {
            return "Cleanup did not finish"
        }
        return "Cleanup complete"
    }

    private var immediatelyAvailable: String {
        guard let delta = receipt.immediateAvailableDelta else {
            return "not measured"
        }
        if abs(delta) < 1_000_000 {
            return "approximately unchanged"
        }
        if delta > 0 {
            return UIFormat.bytes(delta)
        }
        return "decreased by \(UIFormat.bytes(-delta)) — another process wrote to the disk during cleanup"
    }

    private var trashedCount: Int {
        receipt.outcomes.filter { if case .trashed = $0 { return true }; return false }.count
    }

    private var failedCount: Int {
        receipt.outcomes.filter { if case .failed = $0 { return true }; return false }.count
    }

    private var skippedCount: Int {
        receipt.outcomes.filter { if case .skipped = $0 { return true }; return false }.count
    }

    private var outcomeSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            if trashedCount > 0 {
                outcomeRow(symbol: "checkmark", tint: .secondary, title: "Moved to Trash", count: trashedCount, bytes: receipt.successfullyTrashedBytes)
            }
            if failedCount > 0 {
                DisclosureGroup {
                    ForEach(failedLines, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                } label: {
                    outcomeRow(symbol: "exclamationmark.triangle", tint: .red, title: "Couldn't be moved", count: failedCount, bytes: failedBytes)
                }
            }
            if skippedCount > 0 {
                DisclosureGroup {
                    ForEach(skippedLines, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                } label: {
                    outcomeRow(symbol: "minus.circle", tint: .orange, title: "Skipped", count: skippedCount, bytes: skippedBytes)
                }
            }
        }
    }

    private func outcomeRow(symbol: String, tint: Color, title: String, count: Int, bytes: Int64) -> some View {
        HStack {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
            Spacer()
            Text("\(count) items")
                .foregroundStyle(.secondary)
            Text(UIFormat.bytes(bytes))
                .font(.body.monospacedDigit())
        }
        .font(.body)
    }

    private var failedBytes: Int64 {
        receipt.outcomes.reduce(0) { sum, o in
            if case .failed(_, _, let bytes, _) = o { return sum + bytes }
            return sum
        }
    }

    private var skippedBytes: Int64 {
        receipt.outcomes.reduce(0) { sum, o in
            if case .skipped(_, _, let bytes, _) = o { return sum + bytes }
            return sum
        }
    }

    private var failedLines: [String] {
        receipt.outcomes.compactMap { outcome in
            if case .failed(_, let path, _, let reason) = outcome {
                return "\(path) — \(reason.plainEnglish)"
            }
            return nil
        }
    }

    private var skippedLines: [String] {
        receipt.outcomes.compactMap { outcome in
            if case .skipped(_, let path, _, let reason) = outcome {
                return "\(path) — \(reason.plainEnglish)"
            }
            return nil
        }
    }

    private func line(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.body.weight(.medium).monospacedDigit())
        }
        .font(.body)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }

    private func openTrash() {
        let trash = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash")
        NSWorkspace.shared.open(trash)
    }
}

extension SkipReason {
    var plainEnglish: String {
        switch self {
        case .vanished: return "No longer on disk — something else took it."
        case .becameSymlink: return "Changed to a shortcut since the scan — skipped for safety."
        case .typeChanged: return "Changed type since the scan — skipped for safety."
        case .identityChanged: return "Replaced by a different file since the scan — skipped for safety."
        case .escapedCleanupRoot: return "Moved outside the area DiskPrune scanned — skipped."
        case .appBundleAncestor: return "Inside an application bundle — DiskPrune never removes these."
        case .denyListed: return "In a protected location — DiskPrune never removes these."
        case .cancelled: return "Cancelled before this item."
        }
    }
}

extension FailureReason {
    var plainEnglish: String {
        switch self {
        case .permissionDenied: return "Permission denied."
        case .trashUnavailable: return "Trash was unavailable."
        case .crossVolume: return "Couldn't move across volumes."
        case .fileBusy: return "The file was busy."
        case .readOnlyVolume: return "The volume is read-only."
        case .unknown: return "Couldn't be moved."
        }
    }
}

import SwiftUI

struct CategoryRow: View {
    let bucket: CategoryBucket
    let bytes: Int64
    let fileCount: Int
    let producer: String?
    var partial: Bool = false
    var expanded: Bool = false

    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: bucket.symbol)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: Geometry.iconRow, height: Geometry.iconRow)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Space.sm) {
                    Text(bucket.title)
                        .font(.body)
                    if partial {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .help("Some locations couldn't be read")
                            .accessibilityLabel("Some locations couldn't be read")
                    }
                }
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(UIFormat.bytes(bytes))
                .font(.body.weight(.medium).monospacedDigit())
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(expanded ? 90 : 0))
        }
        .frame(minHeight: Geometry.rowCategory)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bucket.title), \(UIFormat.bytes(bytes)), \(subtitle)")
    }

    private var subtitle: String {
        let count = "\(fileCount) items"
        if let producer, !producer.isEmpty {
            return "\(count) · \(producer)"
        }
        return count
    }
}

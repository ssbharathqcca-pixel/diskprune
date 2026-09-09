import SwiftUI

struct CapacitySegment: Equatable {
    enum Kind: Equatable {
        case category(CategoryBucket)
        case notExamined
    }
    let kind: Kind
    let bytes: Int64
}

struct CapacityBar: View {
    let segments: [CapacitySegment]
    let total: Int64
    let height: CGFloat
    var loading: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered: Int?

    var body: some View {
        Group {
            if loading || total <= 0 || segments.isEmpty {
                Capsule()
                    .fill(Color(nsColor: .quaternaryLabelColor))
            } else {
                // Layout, not GeometryReader: a GR inside StorageAutopsyView's
                // ScrollView hung macos-latest at NSHostingView.contentView
                // assignment (30873fdd). Segment widths stay proportional.
                SegmentStack(weights: segments.map { CGFloat(max($0.bytes, 0)) }, spacing: 1) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        segmentView(segment)
                            .opacity(hovered == nil || hovered == index ? 1 : 0.6)
                            .onHover { inside in
                                hovered = inside ? index : (hovered == index ? nil : hovered)
                            }
                            .help(tooltip(segment))
                    }
                }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Geometry.radiusControl, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Storage capacity")
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder
    private func segmentView(_ segment: CapacitySegment) -> some View {
        switch segment.kind {
        case .category(let bucket):
            RoundedRectangle(cornerRadius: 0)
                .fill(bucket.fill(colorScheme))
        case .notExamined:
            HatchSegment()
        }
    }

    private func tooltip(_ segment: CapacitySegment) -> String {
        switch segment.kind {
        case .category(let bucket):
            return "\(bucket.title) · \(UIFormat.bytes(segment.bytes))"
        case .notExamined:
            return "Not examined · \(UIFormat.bytes(segment.bytes))"
        }
    }

    private var accessibilityValue: String {
        if loading { return "Waiting for scan" }
        let parts = segments.map { segment -> String in
            switch segment.kind {
            case .category(let bucket):
                return "\(bucket.title) \(UIFormat.bytes(segment.bytes))"
            case .notExamined:
                return "Not examined \(UIFormat.bytes(segment.bytes))"
            }
        }
        return parts.joined(separator: ", ")
    }
}

/// Proportional HStack that only ever places at the parent's finite proposal.
private struct SegmentStack: Layout {
    var weights: [CGFloat]
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = Self.finite(proposal.width)
        let height = Self.finite(proposal.height) ?? 12
        return CGSize(width: width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let n = subviews.count
        guard n > 0, bounds.width.isFinite, bounds.width > 0, bounds.height.isFinite else { return }
        let gaps = spacing * CGFloat(max(n - 1, 0))
        let usable = max(bounds.width - gaps, 0)
        var sum: CGFloat = 0
        for i in 0..<n {
            sum += i < weights.count ? max(weights[i], 0) : 0
        }
        if sum <= 0 { sum = CGFloat(n) }
        var x = bounds.minX
        for i in 0..<n {
            let weight = i < weights.count ? max(weights[i], 0) : 0
            let w = min(max(usable * weight / sum, 2), usable)
            subviews[i].place(
                at: CGPoint(x: x, y: bounds.minY),
                proposal: ProposedViewSize(width: w, height: bounds.height)
            )
            x += w + spacing
        }
    }

    private static func finite(_ value: CGFloat?) -> CGFloat? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return min(value, 4096)
    }
}

/// Unfilled hatch: separator 1pt stroke, 45° hatch at 20% tertiaryLabel, 4pt pitch (PART 5.6).
struct HatchSegment: View {
    var body: some View {
        Canvas { context, size in
            guard size.width.isFinite, size.height.isFinite,
                  size.width > 0, size.height > 0 else { return }
            let width = min(size.width, 4096)
            let height = min(size.height, 4096)
            let hatch = Color(nsColor: .tertiaryLabelColor).opacity(0.2)
            var x: CGFloat = -height
            var steps = 0
            while x < width + height && steps < 3_000 {
                var path = Path()
                path.move(to: CGPoint(x: x, y: height))
                path.addLine(to: CGPoint(x: x + height, y: 0))
                context.stroke(path, with: .color(hatch), lineWidth: 1)
                x += 4
                steps += 1
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            Rectangle()
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}

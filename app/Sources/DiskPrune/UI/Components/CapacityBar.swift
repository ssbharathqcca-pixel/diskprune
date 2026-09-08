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
        GeometryReader { geo in
            HStack(spacing: 1) {
                if loading || total <= 0 || segments.isEmpty {
                    Capsule()
                        .fill(Color(nsColor: .quaternaryLabelColor))
                } else {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        segmentView(segment, width: width(for: segment, in: geo.size.width))
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
        .clipShape(RoundedRectangle(cornerRadius: Geometry.radiusControl, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Storage capacity")
        .accessibilityValue(accessibilityValue)
    }

    private func width(for segment: CapacitySegment, in totalWidth: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        let gaps = CGFloat(max(segments.count - 1, 0))
        let usable = max(totalWidth - gaps, 0)
        return max(usable * CGFloat(segment.bytes) / CGFloat(total), 2)
    }

    @ViewBuilder
    private func segmentView(_ segment: CapacitySegment, width: CGFloat) -> some View {
        switch segment.kind {
        case .category(let bucket):
            RoundedRectangle(cornerRadius: 0)
                .fill(bucket.fill(colorScheme))
                .frame(width: width)
        case .notExamined:
            HatchSegment()
                .frame(width: width)
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

/// Unfilled hatch: separator 1pt stroke, 45° hatch at 20% tertiaryLabel, 4pt pitch (PART 5.6).
struct HatchSegment: View {
    var body: some View {
        Canvas { context, size in
            let hatch = Color(nsColor: .tertiaryLabelColor).opacity(0.2)
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                context.stroke(path, with: .color(hatch), lineWidth: 1)
                x += 4
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            Rectangle()
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}

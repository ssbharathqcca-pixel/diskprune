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
        // Overlay GeometryReader on a height-capped clear view so the reader
        // never inherits an unbounded ScrollView proposal. A top-level
        // GeometryReader inside StorageAutopsyView's ScrollView reported
        // non-finite width on macos-latest, then HatchSegment.frame(width:)
        // hung hosted 03/09 (0c24ff78). Appearance is unchanged when the
        // parent proposes a normal width.
        Color.clear
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .overlay {
                GeometryReader { geo in
                    let barWidth = Self.finiteWidth(geo.size.width)
                    HStack(spacing: 1) {
                        if loading || total <= 0 || segments.isEmpty || barWidth <= 0 {
                            Capsule()
                                .fill(Color(nsColor: .quaternaryLabelColor))
                        } else {
                            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                                segmentView(segment, width: width(for: segment, in: barWidth))
                                    .opacity(hovered == nil || hovered == index ? 1 : 0.6)
                                    .onHover { inside in
                                        hovered = inside ? index : (hovered == index ? nil : hovered)
                                    }
                                    .help(tooltip(segment))
                            }
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

    private static func finiteWidth(_ value: CGFloat) -> CGFloat {
        guard value.isFinite, value > 0 else { return 0 }
        return min(value, 4096)
    }

    private func width(for segment: CapacitySegment, in totalWidth: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        let safeWidth = Self.finiteWidth(totalWidth)
        guard safeWidth > 0 else { return 2 }
        let gaps = CGFloat(max(segments.count - 1, 0))
        let usable = max(safeWidth - gaps, 0)
        let raw = usable * CGFloat(segment.bytes) / CGFloat(total)
        guard raw.isFinite else { return 2 }
        return min(max(raw, 2), safeWidth)
    }

    @ViewBuilder
    private func segmentView(_ segment: CapacitySegment, width: CGFloat) -> some View {
        let w = Self.finiteWidth(width)
        switch segment.kind {
        case .category(let bucket):
            RoundedRectangle(cornerRadius: 0)
                .fill(bucket.fill(colorScheme))
                .frame(width: w > 0 ? w : 2, height: height)
        case .notExamined:
            HatchSegment()
                .frame(width: w > 0 ? w : 2, height: height)
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

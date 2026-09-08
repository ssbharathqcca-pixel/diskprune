import SwiftUI

/// Symbol + coloured label. A pill or filled capsule is forbidden (PART 11.5).
struct SafetyBadge: View {
    let level: SafetyLevel

    var body: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: level.symbolName)
                .font(.caption2.weight(.medium))
                .symbolRenderingMode(.palette)
                .foregroundStyle(level.tint, level.tint)
                .frame(width: Geometry.iconBadge, height: Geometry.iconBadge)
            Text(level.label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(level.tint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(level.label)
    }
}

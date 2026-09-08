import SwiftUI

struct CandidateRow: View {
    let item: StorageItem
    let selected: Bool
    let selectable: Bool
    var onToggle: (Bool) -> Void
    var onInfo: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: Space.md) {
            if selectable {
                Toggle("", isOn: Binding(
                    get: { selected },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .accessibilityLabel("Select \(item.displayName)")
            } else {
                Image(systemName: item.safety.symbolName)
                    .foregroundStyle(item.safety.tint)
                    .frame(width: 18, height: 18)
                    .accessibilityLabel(item.safety.label)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.body)
                    .lineLimit(1)
                Text(item.url.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: Space.md)

            SafetyBadge(level: item.safety)

            Text(UIFormat.bytes(item.onDiskBytes))
                .font(.body.weight(.medium).monospacedDigit())

            Button(action: onInfo) {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
            .opacity(hovering ? 1 : 0.35)
            .accessibilityLabel("Explain \(item.displayName)")
            .help("Why is this here?")
        }
        .frame(minHeight: Geometry.rowCandidate)
        .padding(.vertical, Space.xs)
        .opacity(selectable ? 1 : 0.7)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(selectable ? [] : .isStaticText)
    }

    private var accessibilityText: String {
        let state = selectable ? (selected ? "selected" : "not selected") : item.safety.label
        return "\(item.displayName), \(UIFormat.bytes(item.onDiskBytes)), \(item.safety.label), \(state)"
    }
}

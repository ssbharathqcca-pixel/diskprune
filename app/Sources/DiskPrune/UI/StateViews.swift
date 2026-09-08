import AppKit
import SwiftUI

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let detail: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Space.md) {
            Image(systemName: symbol)
                .font(.system(size: Geometry.iconState))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: 420)
        .padding(Geometry.cardPadding)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Geometry.radiusCard, style: .continuous))
        .modifier(CardShadow())
        .padding(Geometry.contentMargin)
    }
}

struct ErrorStateView: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: Geometry.iconState))
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.weight(.semibold))
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 420)
        .padding(Geometry.cardPadding)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Geometry.radiusCard, style: .continuous))
        .padding(Geometry.contentMargin)
    }
}

struct PermissionBanner: View {
    let paths: [String]
    var onOpenSettings: () -> Void = { FullDiskAccess.openSystemSettings() }
    var onContinue: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .top, spacing: Space.sm) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text("Some locations couldn't be read. macOS privacy settings may be limiting results.")
                    .font(.callout)
            }
            if !paths.isEmpty {
                Text(paths.prefix(8).joined(separator: "\n"))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .truncationMode(.middle)
            }
            HStack(spacing: Space.md) {
                Button("Open System Settings", action: onOpenSettings)
                if let onContinue {
                    Button("Continue anyway", action: onContinue)
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(Geometry.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Geometry.radiusCard, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct KnowledgeLoadErrorView: View {
    var body: some View {
        ErrorStateView(
            title: "Couldn't load storage rules",
            detail: "DiskPrune needs its storage-rules resource to classify locations. Reinstall the app if this continues."
        )
        .frame(minWidth: Geometry.windowMin.width, minHeight: Geometry.windowMin.height)
    }
}

struct CardShadow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if colorScheme == .dark || reduceTransparency {
            content
        } else {
            content.shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        }
    }
}

struct ReduceTransparencyBackground<S: Shape>: ViewModifier {
    var shape: S
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .windowBackgroundColor), in: shape)
        } else {
            content
        }
    }
}

import AppKit
import SwiftUI

struct ItemDetailView: View {
    let item: StorageItem
    let knowledge: StorageKnowledge

    private var rule: StorageRule? {
        item.knowledgeID.flatMap { knowledge.rule(id: $0) }
    }

    private var isSparse: Bool {
        item.logicalBytes > item.onDiskBytes * 2 && item.onDiskBytes >= 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Geometry.sectionSpacing) {
                Text(item.displayName)
                    .font(.title2.weight(.semibold))
                    .textSelection(.enabled)

                SafetyBadge(level: item.safety)

                labeled("Path", item.url.path, path: true)
                labeled("On disk", UIFormat.bytes(item.onDiskBytes), mono: true)
                labeled("Logical", UIFormat.bytes(item.logicalBytes), mono: true)
                labeled("Files", "\(item.fileCount)", mono: true)
                labeled("Last modified", UIFormat.date(item.newestModification))

                if isSparse {
                    Text("Sparse file — occupies less space than its size suggests.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Divider()

                if item.knowledgeID == nil {
                    Text("DiskPrune doesn't have a rule for this location")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    block(title: "Why it's here", body: item.explanation)
                    block(title: "What happens if you move it", body: item.consequence)
                    if let how = rule?.howItComesBack, !how.isEmpty {
                        block(title: "How it comes back", body: how)
                    }
                    if let docs = rule?.docsURL {
                        Link("Documentation", destination: docs)
                    }
                }

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                .buttonStyle(.link)
            }
            .padding(Geometry.contentMargin)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .navigationTitle("Inspector")
    }

    private func labeled(_ title: String, _ value: String, path: Bool = false, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(path ? .caption.monospaced() : (mono ? .body.monospacedDigit() : .body))
                .textSelection(.enabled)
                .lineLimit(path ? 3 : 2)
                .truncationMode(path ? .middle : .tail)
        }
    }

    private func block(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title)
                .font(.headline.weight(.semibold))
            Text(body)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

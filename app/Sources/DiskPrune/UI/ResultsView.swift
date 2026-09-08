import SwiftUI

enum ResultsFilter: Equatable {
    case cleanup
    case bucket(CategoryBucket)
}

struct ResultsView: View {
    @ObservedObject var session: AppSession
    var filter: ResultsFilter
    @State private var sort: Sort = .size

    enum Sort: String, CaseIterable {
        case size, name, date
    }

    var body: some View {
        VStack(spacing: 0) {
            if visibleItems.isEmpty {
                empty
            } else if filter == .cleanup {
                cleanupList
            } else {
                categoryList
            }
            if filter == .cleanup {
                CleanupPlanView(session: session)
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("Sort", selection: $sort) {
                    Text("Size").tag(Sort.size)
                    Text("Name").tag(Sort.name)
                    Text("Date").tag(Sort.date)
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Sort")
            }
            if filter == .cleanup {
                ToolbarItem(placement: .automatic) {
                    Button("Select all safe") { session.selectAllSafe() }
                }
            }
        }
    }

    private var title: String {
        switch filter {
        case .cleanup: return "Cleanup"
        case .bucket(let bucket): return bucket.title
        }
    }

    private var visibleItems: [StorageItem] {
        var items = session.items
        switch filter {
        case .cleanup:
            break
        case .bucket(let bucket):
            items = items.filter { CategoryBucket.bucket(for: $0.category) == bucket }
        }
        let query = session.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            items = items.filter {
                $0.displayName.localizedCaseInsensitiveContains(query)
                    || $0.url.path.localizedCaseInsensitiveContains(query)
            }
        }
        switch sort {
        case .size: items.sort { $0.onDiskBytes > $1.onDiskBytes }
        case .name: items.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .date: items.sort { ($0.newestModification ?? .distantPast) > ($1.newestModification ?? .distantPast) }
        }
        return items
    }

    private var empty: some View {
        Group {
            if filter == .cleanup {
                EmptyStateView(
                    symbol: "tray",
                    title: "No reclaimable data found",
                    detail: "DiskPrune didn't find significant reclaimable data."
                )
            } else {
                EmptyStateView(
                    symbol: "folder",
                    title: "No items in this category",
                    detail: "Nothing in this category matched the current scan."
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cleanupList: some View {
        let grouped = Dictionary(grouping: visibleItems, by: \.safety)
        return List {
            section(.safe, items: grouped[.safe] ?? [])
            section(.review, items: grouped[.review] ?? [])
            section(.advanced, items: grouped[.advanced] ?? [])
            section(.protected, items: grouped[.protected] ?? [])
        }
        .listStyle(.inset)
    }

    private var categoryList: some View {
        List(visibleItems, id: \.id) { item in
            CandidateRow(
                item: item,
                selected: session.isSelected(item),
                selectable: session.canSelect(item),
                onToggle: { session.setSelected(item, $0) },
                onInfo: { session.openInspector(item) }
            )
            .contentShape(Rectangle())
            .onTapGesture { session.openInspector(item) }
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private func section(_ level: SafetyLevel, items: [StorageItem]) -> some View {
        if items.isEmpty {
            Section(level.label) {
                Text("No \(level.label.lowercased()) items")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else {
            Section(level.label) {
                ForEach(items, id: \.id) { item in
                    CandidateRow(
                        item: item,
                        selected: session.isSelected(item),
                        selectable: session.canSelect(item),
                        onToggle: { session.setSelected(item, $0) },
                        onInfo: { session.openInspector(item) }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { session.openInspector(item) }
                }
            }
        }
    }
}

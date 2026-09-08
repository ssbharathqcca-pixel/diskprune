import AppKit
import SwiftUI

struct RootView: View {
    @StateObject var session: AppSession

    init(session: AppSession) {
        _session = StateObject(wrappedValue: session)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: Geometry.sidebarMin, ideal: Geometry.sidebarWidth, max: Geometry.sidebarMax)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationSplitViewStyle(.balanced)
        .inspector(isPresented: $session.inspectorOpen) {
            if let item = session.selectedDetail {
                ItemDetailView(item: item, knowledge: session.knowledge)
            }
        }
        .searchable(text: $session.searchText, prompt: "Filter")
        .toolbar { toolbar }
        .sheet(isPresented: $session.showDryRun) {
            DryRunSheet(session: session)
        }
        .sheet(isPresented: $session.showReceipt) {
            if let receipt = session.receipt {
                ReceiptView(receipt: receipt)
            }
        }
        .onAppear {
            if PreferencesStore.scanOnLaunch, session.phase == .idle {
                session.startScan()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .diskPruneScan)) { _ in
            if session.phase != .scanning && session.phase != .executing {
                session.startScan()
            }
        }
        .frame(minWidth: Geometry.windowMin.width, minHeight: Geometry.windowMin.height)
    }

    private var sidebar: some View {
        List(selection: $session.destination) {
            Label("Overview", systemImage: "chart.pie")
                .foregroundStyle(.primary)
                .tag(SidebarDestination.overview)
                .keyboardShortcut("1", modifiers: .command)
                .accessibilityLabel(overviewA11y)

            if session.phase == .ready || session.phase == .executing, let coverage = session.coverage {
                Section("Storage") {
                    ForEach(sidebarCategories(coverage), id: \.0) { bucket, bytes in
                        HStack {
                            Label(bucket.title, systemImage: bucket.symbol)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(UIFormat.bytes(bytes))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .tag(SidebarDestination.category(bucket))
                        .accessibilityLabel("\(bucket.title), \(UIFormat.bytes(bytes))")
                    }
                }
            }

            Label {
                HStack {
                    Text("Cleanup")
                    Spacer()
                    if session.selectedCount > 0 {
                        Text("\(session.selectedCount)")
                            .font(.caption2.monospacedDigit())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color(nsColor: .tertiaryLabelColor).opacity(0.25), in: Capsule())
                            .accessibilityHidden(true)
                    }
                }
            } icon: {
                Image(systemName: "tray.and.arrow.down")
            }
            .foregroundStyle(.primary)
            .tag(SidebarDestination.cleanup)
            .keyboardShortcut("2", modifiers: .command)
            .accessibilityLabel("Cleanup, \(session.selectedCount) selected")

            Label("Snapshots", systemImage: "clock.arrow.circlepath")
                .foregroundStyle(.primary)
                .tag(SidebarDestination.snapshots)
                .keyboardShortcut("3", modifiers: .command)
        }
        .listStyle(.sidebar)
        .navigationTitle("DiskPrune")
    }

    @ViewBuilder
    private var detail: some View {
        switch session.phase {
        case .scanning:
            ScanView(session: session)
        case .executing:
            executingView
        case .failed(let message):
            ErrorStateView(title: "Scan failed", detail: message)
        default:
            switch session.destination {
            case .overview:
                StorageAutopsyView(session: session)
            case .category(let bucket):
                ResultsView(session: session, filter: .bucket(bucket))
            case .cleanup:
                ResultsView(session: session, filter: .cleanup)
            case .snapshots:
                SnapshotView(summary: session.snapshots)
            }
        }
    }

    private var executingView: some View {
        VStack(spacing: Space.md) {
            Text("Moving to Trash")
                .font(.title2.weight(.semibold))
            ProgressView(value: session.executeTotal == 0 ? 0 : Double(session.executeDone) / Double(session.executeTotal))
                .progressViewStyle(.linear)
                .frame(maxWidth: 360)
            Text("\(session.executeDone) of \(session.executeTotal)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(Geometry.contentMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Moving to Trash, \(session.executeDone) of \(session.executeTotal)")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                session.inspectorOpen.toggle()
            } label: {
                Image(systemName: "sidebar.trailing")
            }
            .help("Inspector")
            .keyboardShortcut("i", modifiers: [.command, .option])
            .accessibilityLabel("Toggle inspector")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                session.startScan()
            } label: {
                Label("Scan", systemImage: "magnifyingglass")
            }
            .disabled(session.phase == .scanning || session.phase == .executing)
            .keyboardShortcut("r", modifiers: .command)
            .accessibilityLabel("Scan")
        }
    }

    private func sidebarCategories(_ coverage: StorageCoverage) -> [(CategoryBucket, Int64)] {
        AutopsyModel(coverage: coverage, items: session.items, volumeName: session.volumeName, cancelled: session.scanCancelled)
            .categoryShares
            .filter { $0.1 > 0 }
    }

    private var overviewA11y: String {
        if let coverage = session.coverage {
            return "Overview, \(UIFormat.bytes(coverage.volumeUsedBytes)) used"
        }
        return "Overview"
    }
}

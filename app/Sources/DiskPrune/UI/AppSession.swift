import Foundation
import SwiftUI

enum SidebarDestination: Hashable, Identifiable {
    case overview
    case category(CategoryBucket)
    case cleanup
    case snapshots

    var id: String {
        switch self {
        case .overview: return "overview"
        case .category(let bucket): return "category-\(bucket.rawValue)"
        case .cleanup: return "cleanup"
        case .snapshots: return "snapshots"
        }
    }
}

/// Owns the native UI pipeline. The only mutation it triggers is
/// `CleanupExecutor.execute(_ plan: CleanupPlan)`.
@MainActor
final class AppSession: ObservableObject {
    enum Phase: Equatable {
        case idle
        case scanning
        case ready
        case executing
        case failed(String)
    }

    static let probeOrder = ["Xcode", "Docker", "Package managers", "Caches", "Logs"]

    let knowledge: StorageKnowledge

    @Published var phase: Phase = .idle
    @Published var destination: SidebarDestination = .overview
    @Published var activeProbe: String?
    @Published var completedProbes: [String] = []
    @Published var probeBytes: [String: Int64] = [:]
    @Published var items: [StorageItem] = []
    @Published var coverage: StorageCoverage?
    @Published var snapshots: SnapshotSummary?
    @Published var selectedIDs: Set<UUID> = []
    @Published var receipt: CleanupReceipt?
    @Published var scanState: ScanState = .complete
    @Published var scanCancelled = false
    @Published var executeDone = 0
    @Published var executeTotal = 0
    @Published var showDryRun = false
    @Published var showReceipt = false
    @Published var inspectorOpen = false
    @Published var selectedDetail: StorageItem?
    @Published var searchText = ""
    @Published var volumeName = "Macintosh HD"
    @Published var preScanTotal: Int64 = 0
    @Published var preScanAvailable: Int64 = 0
    @Published var preScanUsed: Int64 = 0

    private var scanTask: Task<Void, Never>?
    private var executeTask: Task<Void, Never>?
    private var engine: ScanEngine?

    init(knowledge: StorageKnowledge) {
        self.knowledge = knowledge
        if let volume = VolumeProbe.home() {
            volumeName = volume.name
            preScanTotal = volume.total
            preScanAvailable = volume.available
            preScanUsed = volume.used
        }
    }

    var currentPlan: CleanupPlan? {
        let planned = items.compactMap { PlannedItem(item: $0, userSelected: selectedIDs.contains($0.id)) }
        return CleanupPlan(items: planned)
    }

    var selectedCount: Int { selectedIDs.count }

    var estimatedRecoverable: Int64 {
        currentPlan?.estimatedRecoverableBytes ?? 0
    }

    var permissionPaths: [String] {
        if case .partial(let paths) = scanState { return paths }
        return coverage?.permissionLimitedPaths ?? []
    }

    func canSelect(_ item: StorageItem) -> Bool {
        item.isCleanupCandidate
    }

    func isSelected(_ item: StorageItem) -> Bool {
        selectedIDs.contains(item.id)
    }

    func setSelected(_ item: StorageItem, _ on: Bool) {
        guard canSelect(item) else { return }
        if on {
            selectedIDs.insert(item.id)
        } else {
            selectedIDs.remove(item.id)
        }
    }

    func selectAllSafe() {
        for item in items where item.safety == .safe && item.isCleanupCandidate {
            selectedIDs.insert(item.id)
        }
    }

    func openInspector(_ item: StorageItem) {
        selectedDetail = item
        inspectorOpen = true
    }

    func startScan() {
        scanTask?.cancel()
        executeTask?.cancel()
        engine = ScanEngine(knowledge: knowledge)
        phase = .scanning
        destination = .overview
        activeProbe = nil
        completedProbes = []
        probeBytes = [:]
        items = []
        selectedIDs = []
        coverage = nil
        snapshots = nil
        receipt = nil
        selectedDetail = nil
        inspectorOpen = false
        showDryRun = false
        showReceipt = false
        scanCancelled = false
        scanState = .complete

        let engine = self.engine!
        scanTask = Task { [weak self] in
            guard let self else { return }
            let stream = await engine.scan()
            for await event in stream {
                if Task.isCancelled { break }
                self.handle(event)
            }
        }
    }

    func cancelScan() {
        scanCancelled = true
        scanTask?.cancel()
        Task { await engine?.cancel() }
        if let activeProbe {
            completedProbes.append(activeProbe)
            self.activeProbe = nil
        }
        phase = items.isEmpty && coverage == nil ? .idle : .ready
    }

    /// Test seam: apply a finished scan without touching the disk.
    func ingestScan(items: [StorageItem], coverage: StorageCoverage, snapshots: SnapshotSummary? = nil) {
        self.items = items
        self.coverage = coverage
        self.snapshots = snapshots
        selectedIDs = Set(items.filter { $0.safety.isPreselectable && $0.isCleanupCandidate }.map(\.id))
        phase = .ready
        scanState = coverage.permissionLimitedPaths.isEmpty ? .complete : .partial(deniedPaths: coverage.permissionLimitedPaths)
    }

    func presentDryRun() {
        guard currentPlan != nil else { return }
        showDryRun = true
    }

    func confirmMoveToTrash() {
        guard let plan = currentPlan else { return }
        showDryRun = false
        phase = .executing
        executeDone = 0
        executeTotal = plan.itemCount

        executeTask = Task { [weak self] in
            guard let self else { return }
            let executor = CleanupExecutor()
            await executor.setProgress { done, total in
                Task { @MainActor [weak self] in
                    self?.executeDone = done
                    self?.executeTotal = total
                }
            }
            let receipt = await executor.execute(plan)
            self.apply(receipt: receipt)
        }
    }

    private func apply(receipt: CleanupReceipt) {
        self.receipt = receipt
        let trashed = Set(receipt.outcomes.compactMap { outcome -> UUID? in
            if case .trashed(let id, _, _, _) = outcome { return id }
            return nil
        })
        items.removeAll { trashed.contains($0.id) }
        selectedIDs.subtract(trashed)
        phase = .ready
        destination = .cleanup
        showReceipt = true
    }

    private func handle(_ event: ScanEvent) {
        switch event {
        case .started:
            break
        case .probeStarted(let name):
            if let activeProbe {
                completedProbes.append(activeProbe)
            }
            activeProbe = name
        case .itemsFound(let found):
            items.append(contentsOf: found)
            let added = found.reduce(Int64(0)) { $0 + $1.onDiskBytes }
            if let activeProbe {
                probeBytes[activeProbe, default: 0] += added
            }
            for item in found where item.safety.isPreselectable && item.isCleanupCandidate {
                selectedIDs.insert(item.id)
            }
        case .snapshots(let summary):
            snapshots = summary
        case .coverage(let cov):
            coverage = cov
        case .finished(let state):
            scanState = state
            if let activeProbe {
                completedProbes.append(activeProbe)
            }
            activeProbe = nil
            phase = .ready
            PreferencesStore.setLastScanAt(Date())
        }
    }
}

extension CleanupExecutor {
    func setProgress(_ handler: (@Sendable (Int, Int) -> Void)?) {
        progress = handler
    }
}

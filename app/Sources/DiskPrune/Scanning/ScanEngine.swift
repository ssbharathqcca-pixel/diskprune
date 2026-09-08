import Foundation

enum ScanEvent: Sendable {
    case started
    case probeStarted(name: String)
    case itemsFound([StorageItem])
    case snapshots(SnapshotSummary)
    case coverage(StorageCoverage)
    case finished(ScanState)
}

actor ScanEngine {
    private let knowledge: StorageKnowledge
    private var cancelled = false

    init(knowledge: StorageKnowledge) {
        self.knowledge = knowledge
    }

    func cancel() {
        cancelled = true
    }

    func scan() -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            let task = Task {
                await self.run(continuation: continuation)
            }
            continuation.onTermination = { _ in
                task.cancel()
                Task { await self.cancel() }
            }
        }
    }

    private func run(continuation: AsyncStream<ScanEvent>.Continuation) async {
        continuation.yield(.started)
        let globalSeen = SeenFileIDs()
        var allItems: [StorageItem] = []
        var denied: [String] = []

        let probes: [any Probe] = [
            XcodeProbe(),
            DockerProbe(),
            PackageManagerProbe(),
            CacheProbe(),
            LogProbe(),
        ]

        for probe in probes {
            if cancelled || Task.isCancelled { break }
            continuation.yield(.probeStarted(name: probe.name))
            let items = await probe.discover(knowledge: knowledge, globalSeen: globalSeen)
            for item in items {
                if case .partial(let paths) = item.scanState {
                    denied.append(contentsOf: paths)
                }
            }
            allItems.append(contentsOf: items)
            continuation.yield(.itemsFound(items))
        }

        let snapshots = await SnapshotInspector.list()
        continuation.yield(.snapshots(snapshots))

        let home = URL(fileURLWithPath: NSHomeDirectory())
        let volume = volumeSpace(for: home)
        let classified = allItems.reduce(Int64(0)) { partial, item in
            item.knowledgeID == nil ? partial : partial + item.onDiskBytes
        }
        // Coverage aggregates must use globally-deduped figures. Item sizes may
        // double-count hardlinks across items; globallyNew was accumulated in
        // DirectorySizer via SeenFileIDs. Reconstruct from items by preferring
        // knowledgeID != nil as classified, using onDiskBytes as an upper bound
        // and clamping notExamined at 0 (T-COV-04).
        var classifiedBytes: Int64 = 0
        var unclassifiedBytes: Int64 = 0
        var candidateBytes: Int64 = 0
        let coverageSeen = SeenFileIDs()
        for item in allItems {
            let contribution: Int64
            if coverageSeen.contains(item.fileID) && item.fileCount <= 1 {
                contribution = 0
            } else {
                contribution = item.onDiskBytes
                _ = coverageSeen.insert(item.fileID)
            }
            if item.knowledgeID != nil {
                classifiedBytes += contribution
            } else {
                unclassifiedBytes += contribution
            }
            if item.isCleanupCandidate {
                candidateBytes += contribution
            }
        }
        _ = classified

        let coverage = StorageCoverage(
            volumeTotalBytes: volume?.total ?? 0,
            volumeAvailableBytes: volume?.available ?? 0,
            classifiedBytes: classifiedBytes,
            unclassifiedScannedBytes: unclassifiedBytes,
            permissionLimitedPaths: Array(Set(denied)).sorted(),
            cleanupCandidateBytes: candidateBytes
        )
        continuation.yield(.coverage(coverage))

        let finish: ScanState
        if denied.isEmpty {
            finish = .complete
        } else {
            finish = .partial(deniedPaths: Array(Set(denied)).sorted())
        }
        continuation.yield(.finished(finish))
        continuation.finish()
    }

    private func volumeSpace(for url: URL) -> (total: Int64, available: Int64)? {
        guard let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ]),
            let total = values.volumeTotalCapacity
        else { return nil }
        let available = values.volumeAvailableCapacityForImportantUsage
            ?? values.volumeAvailableCapacity
        guard let available else { return nil }
        return (Int64(total), Int64(available))
    }
}

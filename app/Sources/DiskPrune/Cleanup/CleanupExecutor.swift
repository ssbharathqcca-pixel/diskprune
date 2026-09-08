import Foundation

actor CleanupExecutor {
    var progress: (@Sendable (Int, Int) -> Void)?

    /// The ONLY destructive entry point. Exactly one parameter: CleanupPlan.
    func execute(_ plan: CleanupPlan) async -> CleanupReceipt {
        let started = Date()
        let firstURL = plan.items[0].url
        let before = SpaceVerifier.measure(volumeContaining: firstURL)
        var outcomes: [ItemOutcome] = []
        var wasCancelled = false
        var trashLocation: String?

        for (index, item) in plan.items.enumerated() {
            if Task.isCancelled {
                wasCancelled = true
                for rest in plan.items[index...] {
                    outcomes.append(
                        .skipped(itemID: rest.itemID, path: rest.url.path, bytes: rest.estimatedBytes, reason: .cancelled)
                    )
                }
                break
            }

            switch PathValidator.revalidateBeforeTrash(item) {
            case .failure(let reason):
                outcomes.append(
                    .skipped(itemID: item.itemID, path: item.url.path, bytes: item.estimatedBytes, reason: reason)
                )
            case .success:
                do {
                    var resulting: NSURL?
                    try FileManager.default.trashItem(at: item.url, resultingItemURL: &resulting)
                    let resultingURL = resulting as URL?
                    if trashLocation == nil {
                        trashLocation = resultingURL?.deletingLastPathComponent().path ?? "~/.Trash"
                    }
                    outcomes.append(
                        .trashed(
                            itemID: item.itemID,
                            path: item.url.path,
                            bytes: item.estimatedBytes,
                            resultingTrashURL: resultingURL?.path
                        )
                    )
                } catch {
                    outcomes.append(
                        .failed(
                            itemID: item.itemID,
                            path: item.url.path,
                            bytes: item.estimatedBytes,
                            reason: Self.mapFailure(error)
                        )
                    )
                }
            }
            progress?(index + 1, plan.items.count)
        }

        let after = SpaceVerifier.measure(volumeContaining: firstURL)
        let delta: Int64?
        if let b = before?.available, let a = after?.available {
            delta = a - b
        } else {
            delta = nil
        }
        let trashedBytes: Int64 = outcomes.reduce(0) { sum, outcome in
            if case .trashed(_, _, let bytes, _) = outcome { return sum + bytes }
            return sum
        }

        let receipt = CleanupReceipt(
            id: UUID(),
            planID: plan.id,
            startedAt: started,
            finishedAt: Date(),
            wasCancelled: wasCancelled,
            estimatedRecoverableBytes: plan.estimatedRecoverableBytes,
            successfullyTrashedBytes: trashedBytes,
            volumeAvailableBefore: before?.available,
            volumeAvailableAfter: after?.available,
            immediateAvailableDelta: delta,
            outcomes: outcomes,
            trashLocation: trashLocation,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0-dev",
            rulesVersion: ""
        )
        _ = try? ReceiptStore.save(receipt)
        return receipt
    }

    static func mapFailure(_ error: Error) -> FailureReason {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain {
            switch ns.code {
            case NSFileWriteNoPermissionError, NSFileReadNoPermissionError, 257, 513:
                return .permissionDenied
            case NSFileWriteVolumeReadOnlyError:
                return .readOnlyVolume
            case NSFileLockingError:
                return .fileBusy
            default:
                break
            }
        }
        let message = ns.localizedDescription.lowercased()
        if message.contains("trash") { return .trashUnavailable }
        if message.contains("volume") { return .crossVolume }
        return .unknown
    }
}

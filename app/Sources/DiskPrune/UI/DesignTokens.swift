import AppKit
import SwiftUI

/// Spacing, type, colour, and motion from Design Guide PARTS 5–10.
/// Hex literals appear only in `CategoryBucket` (PART 5.5). Everything else is a system colour.
enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Geometry {
    static let sidebarWidth: CGFloat = 240
    static let sidebarMin: CGFloat = 200
    static let sidebarMax: CGFloat = 320
    static let windowDefault = CGSize(width: 1100, height: 720)
    static let windowMin = CGSize(width: 880, height: 560)
    static let contentMargin: CGFloat = 20
    static let contentMaxWidth: CGFloat = 820
    static let rowCompact: CGFloat = 28
    static let rowStandard: CGFloat = 36
    static let rowCandidate: CGFloat = 44
    static let rowCategory: CGFloat = 64
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let radiusControl: CGFloat = 6
    static let radiusCard: CGFloat = 10
    static let radiusSheet: CGFloat = 12
    static let iconSidebar: CGFloat = 16
    static let iconRow: CGFloat = 16
    static let iconBadge: CGFloat = 12
    static let iconState: CGFloat = 32
    static let controlHeight: CGFloat = 28
    static let capacityBarHeight: CGFloat = 12
    static let capacityBarInline: CGFloat = 6
    static let hitMin: CGFloat = 28
}

enum Motion {
    static let micro: Double = 0.12
    static let standard: Double = 0.25
    static let disclosure: Double = 0.35
    static let reduced: Double = 0.15
}

enum UIFormat {
    static func bytes(_ value: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: value)
    }

    static func date(_ value: Date?) -> String {
        guard let value else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: value)
    }

    static func snapshotDate(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: value)
    }
}

enum VolumeProbe {
    static func home() -> (name: String, total: Int64, available: Int64, used: Int64)? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ]),
            let totalInt = values.volumeTotalCapacity
        else { return nil }
        let available: Int64
        if let important = values.volumeAvailableCapacityForImportantUsage {
            available = important
        } else if let fallback = values.volumeAvailableCapacity {
            available = Int64(fallback)
        } else {
            return nil
        }
        let total = Int64(totalInt)
        return (values.volumeName ?? "Macintosh HD", total, available, max(0, total - available))
    }
}

/// Visual buckets for the capacity bar (PART 5.5). Not a second accounting model —
/// headlines still come from `StorageCoverage`. These split `classifiedBytes` only.
enum CategoryBucket: String, CaseIterable, Identifiable, Hashable {
    case developer
    case caches
    case logs
    case applicationData
    case otherClassified

    var id: String { rawValue }

    var title: String {
        switch self {
        case .developer: return "Developer"
        case .caches: return "Caches"
        case .logs: return "Logs"
        case .applicationData: return "Application data"
        case .otherClassified: return "Other classified"
        }
    }

    var symbol: String {
        switch self {
        case .developer: return "hammer"
        case .caches: return "shippingbox"
        case .logs: return "doc.text"
        case .applicationData: return "app.badge"
        case .otherClassified: return "questionmark.folder"
        }
    }

    func fill(_ scheme: ColorScheme) -> Color {
        let hex: String
        switch (self, scheme) {
        case (.developer, .dark): hex = "7B9CB9"
        case (.developer, _): hex = "5B7C99"
        case (.caches, .dark): hex = "94A899"
        case (.caches, _): hex = "7A8B7F"
        case (.logs, .dark): hex = "A69CB3"
        case (.logs, _): hex = "8B8298"
        case (.applicationData, .dark): hex = "B9A37B"
        case (.applicationData, _): hex = "99835B"
        case (.otherClassified, .dark): hex = "9E9EA3"
        case (.otherClassified, _): hex = "8A8A8E"
        }
        return Color(hex: hex)
    }

    static func bucket(for category: Category) -> CategoryBucket {
        switch category {
        case .developerBuild, .packageCache: return .developer
        case .applicationCache: return .caches
        case .log: return .logs
        case .applicationSupport, .containerData, .application: return .applicationData
        case .virtualDisk, .snapshot, .userData, .unknown: return .otherClassified
        }
    }
}

extension Color {
    /// PART 5.5 category ramp only. Do not use for surfaces or text.
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

extension SafetyLevel {
    var symbolName: String {
        switch self {
        case .safe: return "checkmark.seal.fill"
        case .review: return "exclamationmark.circle"
        case .advanced: return "wrench.and.screwdriver.fill"
        case .protected: return "lock.fill"
        }
    }

    var label: String {
        switch self {
        case .safe: return "Safe"
        case .review: return "Review"
        case .advanced: return "Advanced"
        case .protected: return "Protected"
        }
    }

    /// Red is reserved for errors. Protected and Advanced are secondary grey.
    var tint: Color {
        switch self {
        case .safe: return .green
        case .review: return .orange
        case .advanced, .protected: return .secondary
        }
    }
}

struct CategoryShare: Equatable {
    let bucket: CategoryBucket
    let bytes: Int64
}

struct AutopsyModel: Equatable {
    let volumeName: String
    let volumeTotalBytes: Int64
    let volumeUsedBytes: Int64
    let volumeAvailableBytes: Int64
    let examinedBytes: Int64
    let classifiedBytes: Int64
    let unclassifiedScannedBytes: Int64
    let notExaminedBytes: Int64
    let cleanupCandidateBytes: Int64
    let permissionPathCount: Int
    let isPartial: Bool
    let emptyCandidates: Bool
    let statement: String
    let supporting: String
    let categoryShares: [CategoryShare]

    /// Headlines come only from `StorageCoverage`. Category shares are a split of
    /// `classifiedBytes` using item weights — they are never summed as a headline.
    init(coverage: StorageCoverage, items: [StorageItem], volumeName: String, cancelled: Bool) {
        self.volumeName = volumeName
        volumeTotalBytes = coverage.volumeTotalBytes
        volumeUsedBytes = coverage.volumeUsedBytes
        volumeAvailableBytes = coverage.volumeAvailableBytes
        examinedBytes = coverage.examinedBytes
        classifiedBytes = coverage.classifiedBytes
        unclassifiedScannedBytes = coverage.unclassifiedScannedBytes
        notExaminedBytes = coverage.notExaminedBytes
        cleanupCandidateBytes = coverage.cleanupCandidateBytes
        permissionPathCount = coverage.permissionLimitedPaths.count
        isPartial = !coverage.permissionLimitedPaths.isEmpty || cancelled
        emptyCandidates = coverage.cleanupCandidateBytes == 0

        var weights: [CategoryBucket: Int64] = [:]
        for item in items where item.knowledgeID != nil {
            let bucket = CategoryBucket.bucket(for: item.category)
            weights[bucket, default: 0] += item.onDiskBytes
        }
        let weightTotal = weights.values.reduce(Int64(0), +)
        var shares: [CategoryShare] = []
        if weightTotal > 0, classifiedBytes > 0 {
            for bucket in CategoryBucket.allCases {
                let w = weights[bucket] ?? 0
                guard w > 0 else { continue }
                let shareBytes = Int64(Double(classifiedBytes) * (Double(w) / Double(weightTotal)))
                shares.append(CategoryShare(bucket: bucket, bytes: shareBytes))
            }
        }
        if unclassifiedScannedBytes > 0 {
            if let idx = shares.firstIndex(where: { $0.bucket == .otherClassified }) {
                shares[idx] = CategoryShare(bucket: .otherClassified, bytes: shares[idx].bytes + unclassifiedScannedBytes)
            } else {
                shares.append(CategoryShare(bucket: .otherClassified, bytes: unclassifiedScannedBytes))
            }
        }
        categoryShares = shares

        let top = shares.max(by: { $0.bytes < $1.bytes })
        if classifiedBytes == 0 && examinedBytes == 0 {
            statement = "Scan to see what's using your storage"
            supporting = "DiskPrune examines known caches, build products, and logs. It does not claim to explain the whole disk."
        } else if let top, classifiedBytes > 0 {
            statement = "Most of the storage DiskPrune could explain is \(top.bucket.title.lowercased())."
            supporting = "\(top.bucket.title) accounts for \(UIFormat.bytes(top.bytes)) of the \(UIFormat.bytes(examinedBytes)) DiskPrune examined."
        } else {
            statement = "Some storage could not be classified."
            supporting = "DiskPrune examined \(UIFormat.bytes(examinedBytes)) of the \(UIFormat.bytes(volumeUsedBytes)) used."
        }
    }
}

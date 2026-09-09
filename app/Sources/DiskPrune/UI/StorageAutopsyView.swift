import SwiftUI

struct StorageAutopsyView: View {
    @ObservedObject var session: AppSession
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let _ = VisualQARuntime.probe(
            "StorageAutopsyView",
            extra: "phase=\(String(describing: session.phase)) coverage=\(session.coverage != nil)"
        )
        return Group {
            if session.phase == .idle && session.coverage == nil {
                firstLaunch
            } else if let coverage = session.coverage {
                autopsy(coverage)
            } else if session.phase == .ready && session.items.isEmpty {
                EmptyStateView(
                    symbol: "internaldrive",
                    title: "Scan to see what's using your storage",
                    detail: "DiskPrune examines known caches, build products, and logs. It does not claim to explain the whole disk.",
                    actionTitle: "Scan",
                    action: { session.startScan() }
                )
            } else {
                firstLaunch
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Do not reuse the idle ScrollView identity for autopsy-with-data.
        // ingestScan publishes into an already-mounted Autopsy (`122a0a47`).
        .id(session.coverage == nil ? "autopsy-idle" : "autopsy-ready")
    }

    private var firstLaunch: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Geometry.sectionSpacing) {
                volumeHeader(used: session.preScanUsed, available: session.preScanAvailable)
                CapacityBar(
                    segments: [],
                    total: session.preScanTotal,
                    height: Geometry.capacityBarHeight,
                    loading: true
                )
                EmptyStateView(
                    symbol: "chart.pie",
                    title: "Scan to see what's using your storage",
                    detail: "DiskPrune will examine known caches, build products, and logs, then show what it can explain — and what it cannot.",
                    actionTitle: "Scan",
                    action: { session.startScan() }
                )
            }
            .padding(Geometry.contentMargin)
            .frame(maxWidth: Geometry.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func autopsy(_ coverage: StorageCoverage) -> some View {
        let model = AutopsyModel(
            coverage: coverage,
            items: session.items,
            volumeName: session.volumeName,
            cancelled: session.scanCancelled
        )
        let prefix = model.isPartial ? "at least " : ""
        let _ = VisualQARuntime.probe(
            "autopsy-ready",
            extra: "notExamined=\(model.notExaminedBytes) shares=\(model.categoryShares.count)"
        )
        return ScrollView {
            VStack(alignment: .leading, spacing: Geometry.sectionSpacing) {
                volumeHeader(used: model.volumeUsedBytes, available: model.volumeAvailableBytes)

                CapacityBar(
                    segments: barSegments(model),
                    total: max(model.volumeUsedBytes, 1),
                    height: Geometry.capacityBarHeight
                )
                legend(model)

                insight(model)

                if session.scanCancelled {
                    Text("Scan cancelled — showing partial results.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                coverageRows(model, prefix: prefix)

                if model.permissionPathCount > 0 {
                    PermissionBanner(paths: session.permissionPaths)
                }

                candidatesRow(model)
            }
            .padding(Geometry.contentMargin)
            .frame(maxWidth: Geometry.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func volumeHeader(used: Int64, available: Int64) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(session.volumeName)
                .font(.headline.weight(.semibold))
            Text("\(UIFormat.bytes(used)) used · \(UIFormat.bytes(available)) available")
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func legend(_ model: AutopsyModel) -> some View {
        HStack(spacing: Space.lg) {
            ForEach(model.categoryShares, id: \.bucket) { share in
                HStack(spacing: Space.xs) {
                    Circle()
                        .fill(share.bucket.fill(colorScheme))
                        .frame(width: 8, height: 8)
                    Text(share.bucket.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if model.notExaminedBytes > 0 {
                HStack(spacing: Space.xs) {
                    HatchSegment()
                        .frame(width: 12, height: 8)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    Text("Not examined")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func insight(_ model: AutopsyModel) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(model.statement)
                .font(.title2.weight(.semibold))
            Text(model.supporting)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(Geometry.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Geometry.radiusCard, style: .continuous))
        .modifier(CardShadow())
    }

    private func coverageRows(_ model: AutopsyModel, prefix: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            row("Examined", value: prefix + UIFormat.bytes(model.examinedBytes), header: true)
            row("Explained", value: prefix + UIFormat.bytes(model.classifiedBytes), indent: true)
            row("Scanned but unclassified", value: prefix + UIFormat.bytes(model.unclassifiedScannedBytes), indent: true)
            Divider().padding(.vertical, Space.sm)
            row("Not examined", value: UIFormat.bytes(model.notExaminedBytes), header: true)
        }
    }

    private func row(_ title: String, value: String, header: Bool = false, indent: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(header ? .headline.weight(.semibold) : .body)
                .padding(.leading, indent ? Space.lg : 0)
            Spacer()
            Text(value)
                .font(.body.weight(.medium).monospacedDigit())
        }
        .padding(.vertical, Space.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }

    private func candidatesRow(_ model: AutopsyModel) -> some View {
        HStack {
            if model.emptyCandidates {
                Text("No reclaimable data found — your storage is already lean.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                Text("Reclaimable candidates")
                    .font(.body)
                Spacer()
                Text(UIFormat.bytes(model.cleanupCandidateBytes))
                    .font(.body.weight(.medium).monospacedDigit())
                Button("Review") {
                    session.destination = .cleanup
                }
            }
        }
        .padding(.top, Space.sm)
    }

    private func barSegments(_ model: AutopsyModel) -> [CapacitySegment] {
        var segments = model.categoryShares.map { CapacitySegment(kind: .category($0.bucket), bytes: $0.bytes) }
        if model.notExaminedBytes > 0 {
            segments.append(CapacitySegment(kind: .notExamined, bytes: model.notExaminedBytes))
        }
        return segments
    }
}

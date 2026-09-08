import Foundation

struct SnapshotSummary: Sendable {
    let count: Int
    let dates: [Date]
    let readFailed: Bool
}

enum SnapshotInspector {
    /// The ONLY function in this type. Read-only. Never deletes snapshots.
    static func list() async -> SnapshotSummary {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: runProcess())
            }
        }
    }

    static func parse(_ output: String) -> [Date] {
        let regex = try? NSRegularExpression(
            pattern: #"com\.apple\.TimeMachine\.(\d{4}-\d{2}-\d{2}-\d{6})(?:\.local)?"#
        )
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        var dates: [Date] = []
        regex?.enumerateMatches(in: output, range: range) { match, _, _ in
            guard let match, match.numberOfRanges >= 2,
                  let r = Range(match.range(at: 1), in: output) else { return }
            if let date = formatter.date(from: String(output[r])) {
                dates.append(date)
            }
        }
        return dates
    }

    private static func runProcess() -> SnapshotSummary {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = ["listlocalsnapshots", "/"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return SnapshotSummary(count: 0, dates: [], readFailed: true)
        }

        let deadline = Date().addingTimeInterval(5)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            return SnapshotSummary(count: 0, dates: [], readFailed: true)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if process.terminationStatus != 0 && output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return SnapshotSummary(count: 0, dates: [], readFailed: true)
        }
        let dates = parse(output)
        return SnapshotSummary(count: dates.count, dates: dates, readFailed: false)
    }
}

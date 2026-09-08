import Foundation

enum ScanState: Sendable, Codable, Equatable {
    case complete
    case partial(deniedPaths: [String])
    case denied
}

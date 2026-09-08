import Foundation

enum SafetyLevel: String, Sendable, Codable, CaseIterable {
    case safe
    case review
    case advanced
    case protected

    var isPreselectable: Bool { self == .safe }
    var isPlannable: Bool { self == .safe || self == .review }
}

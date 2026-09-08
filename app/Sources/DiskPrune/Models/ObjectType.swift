import Foundation

enum ObjectType: String, Sendable, Codable {
    case directory
    case regularFile
    case symlink
    case other
}

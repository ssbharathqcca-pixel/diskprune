import Foundation

enum Category: String, Sendable, Codable {
    case developerBuild
    case packageCache
    case applicationCache
    case log
    case applicationSupport
    case containerData
    case virtualDisk
    case snapshot
    case application
    case userData
    case unknown
}

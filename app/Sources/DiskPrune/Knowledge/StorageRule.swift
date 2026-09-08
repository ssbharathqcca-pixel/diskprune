import Foundation

struct StorageRule: Sendable, Equatable {
    let id: String
    let paths: [String]
    let envOverride: String?
    let displayName: String
    let category: Category
    let safety: SafetyLevel
    let regenerable: Bool
    let producer: String
    let explanation: String
    let consequence: String
    let howItComesBack: String?
    let minMacOS: String
    let docsURL: URL?
    let lastReviewed: String
    let publish: Bool
}

extension StorageRule: Codable {
    enum CodingKeys: String, CodingKey {
        case id, paths, envOverride, displayName, category, safety, regenerable
        case producer, explanation, consequence, howItComesBack, minMacOS
        case docsURL, lastReviewed, publish
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        paths = try c.decode([String].self, forKey: .paths)
        envOverride = try c.decodeIfPresent(String.self, forKey: .envOverride)
        displayName = try c.decode(String.self, forKey: .displayName)
        category = try c.decode(Category.self, forKey: .category)
        safety = try c.decode(SafetyLevel.self, forKey: .safety)
        regenerable = try c.decode(Bool.self, forKey: .regenerable)
        producer = try c.decode(String.self, forKey: .producer)
        explanation = try c.decode(String.self, forKey: .explanation)
        consequence = try c.decode(String.self, forKey: .consequence)
        howItComesBack = try c.decodeIfPresent(String.self, forKey: .howItComesBack)
        minMacOS = try c.decode(String.self, forKey: .minMacOS)
        if try c.decodeNil(forKey: .docsURL) {
            docsURL = nil
        } else if let raw = try c.decodeIfPresent(String.self, forKey: .docsURL) {
            docsURL = URL(string: raw)
        } else {
            docsURL = nil
        }
        lastReviewed = try c.decode(String.self, forKey: .lastReviewed)
        publish = try c.decode(Bool.self, forKey: .publish)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(paths, forKey: .paths)
        try c.encodeIfPresent(envOverride, forKey: .envOverride)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(category, forKey: .category)
        try c.encode(safety, forKey: .safety)
        try c.encode(regenerable, forKey: .regenerable)
        try c.encode(producer, forKey: .producer)
        try c.encode(explanation, forKey: .explanation)
        try c.encode(consequence, forKey: .consequence)
        try c.encodeIfPresent(howItComesBack, forKey: .howItComesBack)
        try c.encode(minMacOS, forKey: .minMacOS)
        if let docsURL {
            try c.encode(docsURL.absoluteString, forKey: .docsURL)
        } else {
            try c.encodeNil(forKey: .docsURL)
        }
        try c.encode(lastReviewed, forKey: .lastReviewed)
        try c.encode(publish, forKey: .publish)
    }
}

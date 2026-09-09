import CryptoKit
import Foundation

enum LicenseToken {
    struct Claims: Equatable {
        var kid: String
        var jti: String
        var sub: String
        var deviceId: String
        var entitlements: [String]
        var licenseType: String
        var maxDevices: Int
        var org: String?
        var iat: Int64
        var nbf: Int64
        var exp: Int64
        var compact: String

        var hasCleanup: Bool { entitlements.contains("cleanup") }
        var expiresAt: Date { Date(timeIntervalSince1970: TimeInterval(exp)) }
    }

    enum Failure: Equatable, Error {
        case malformed
        case invalidHeader
        case unknownKid
        case invalidSignature
        case unsupportedVersion
        case deviceMismatch
        case expired
        case notYetValid
    }

    /// Fail closed. JSON is parsed only after the signature validates over the
    /// transmitted ASCII bytes `b64url(header).b64url(payload)`.
    static func verify(
        _ compact: String,
        deviceId: String,
        now: Date = Date(),
        keys: [String: Curve25519.Signing.PublicKey] = PublicKeys.byKid,
        nbfSkew: TimeInterval = 24 * 3600
    ) -> Result<Claims, Failure> {
        let parts = compact.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3 else { return .failure(.malformed) }

        guard let headerData = Base64URL.decode(parts[0]),
              let header = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any]
        else { return .failure(.malformed) }

        guard let typ = header["typ"] as? String, typ == "DPL",
              let alg = header["alg"] as? String, alg == "EdDSA",
              let kid = header["kid"] as? String
        else { return .failure(.invalidHeader) }

        guard let publicKey = keys[kid] else { return .failure(.unknownKid) }

        let signingInput = Data((parts[0] + "." + parts[1]).utf8)
        guard let signature = Base64URL.decode(parts[2]),
              publicKey.isValidSignature(signature, for: signingInput)
        else { return .failure(.invalidSignature) }

        guard let payloadData = Base64URL.decode(parts[1]),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        else { return .failure(.malformed) }

        guard jsonInt64(payload["v"]) == 1 else { return .failure(.unsupportedVersion) }

        let dev = payload["dev"] as? String ?? ""
        guard dev == deviceId else { return .failure(.deviceMismatch) }

        let nbf = jsonInt64(payload["nbf"]) ?? 0
        let exp = jsonInt64(payload["exp"]) ?? 0
        let t = Int64(now.timeIntervalSince1970)
        if t + Int64(nbfSkew) < nbf { return .failure(.notYetValid) }
        if t >= exp { return .failure(.expired) }

        let entitlements = payload["ent"] as? [String] ?? []
        let org: String?
        if payload["org"] is NSNull || payload["org"] == nil {
            org = nil
        } else {
            org = payload["org"] as? String
        }

        return .success(
            Claims(
                kid: kid,
                jti: payload["jti"] as? String ?? "",
                sub: payload["sub"] as? String ?? "",
                deviceId: dev,
                entitlements: entitlements,
                licenseType: payload["lt"] as? String ?? "",
                maxDevices: Int(jsonInt64(payload["md"]) ?? 0),
                org: org,
                iat: jsonInt64(payload["iat"]) ?? 0,
                nbf: nbf,
                exp: exp,
                compact: compact
            )
        )
    }
}

enum Base64URL {
    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func encode(_ string: String) -> String {
        encode(Data(string.utf8))
    }

    static func decode(_ string: String) -> Data? {
        var s = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let pad = (4 - s.count % 4) % 4
        if pad > 0 { s += String(repeating: "=", count: pad) }
        return Data(base64Encoded: s)
    }
}

func jsonInt64(_ any: Any?) -> Int64? {
    if let n = any as? Int64 { return n }
    if let n = any as? Int { return Int64(n) }
    if let n = any as? NSNumber { return n.int64Value }
    if let d = any as? Double { return Int64(d) }
    return nil
}

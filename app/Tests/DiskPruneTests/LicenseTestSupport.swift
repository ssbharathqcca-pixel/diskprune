import CryptoKit
import Foundation
@testable import DiskPrune

final class TestClock {
    var date: Date
    init(_ date: Date) { self.date = date }
}

enum MockNetworkError: Error { case offline }

final class MockLicenseAPI: LicenseTalking {
    var error: Error? = MockNetworkError.offline
    var activateStatus = 404
    var activateJSON: [String: Any] = ["error": "LICENSE_NOT_FOUND"]
    var refreshStatus = 401
    var refreshJSON: [String: Any] = ["error": "INVALID_TOKEN"]
    var releaseStatus = 200
    var releaseJSON: [String: Any] = ["released": true, "seats_available": 3]
    var activateBodies: [[String: Any]] = []
    var refreshBodies: [[String: Any]] = []
    var releaseBodies: [[String: Any]] = []
    var refreshCalls = 0

    func post(path: String, body: [String: Any]) async throws -> (status: Int, json: [String: Any]) {
        if let error { throw error }
        if path.contains("activate") {
            activateBodies.append(body)
            return (activateStatus, activateJSON)
        }
        if path.contains("refresh") {
            refreshCalls += 1
            refreshBodies.append(body)
            return (refreshStatus, refreshJSON)
        }
        if path.contains("release") {
            releaseBodies.append(body)
            return (releaseStatus, releaseJSON)
        }
        return (404, [:])
    }
}

enum TestTokens {
    struct Pair {
        var privateKey: Curve25519.Signing.PrivateKey
        var publicKey: Curve25519.Signing.PublicKey { privateKey.publicKey }
        var kid: String
        var keys: [String: Curve25519.Signing.PublicKey] { [kid: publicKey] }
    }

    static func pair(kid: String = "k1") -> Pair {
        Pair(privateKey: Curve25519.Signing.PrivateKey(), kid: kid)
    }

    static func payload(
        deviceId: String,
        sub: String = "deadbeef",
        jti: String = "jti-1",
        ent: [String] = ["cleanup"],
        lt: String = "personal",
        md: Int = 3,
        iat: Int64,
        nbf: Int64? = nil,
        exp: Int64,
        version: Int = 1,
        reversed: Bool = false
    ) -> String {
        let nbfValue = nbf ?? iat
        let entJSON = "[" + ent.map { "\"\($0)\"" }.joined(separator: ",") + "]"
        if reversed {
            return "{\"exp\":\(exp),\"nbf\":\(nbfValue),\"iat\":\(iat),\"org\":null,\"md\":\(md),\"lt\":\"\(lt)\",\"ent\":\(entJSON),\"dev\":\"\(deviceId)\",\"sub\":\"\(sub)\",\"jti\":\"\(jti)\",\"v\":\(version)}"
        }
        return "{\"v\":\(version),\"jti\":\"\(jti)\",\"sub\":\"\(sub)\",\"dev\":\"\(deviceId)\",\"ent\":\(entJSON),\"lt\":\"\(lt)\",\"md\":\(md),\"org\":null,\"iat\":\(iat),\"nbf\":\(nbfValue),\"exp\":\(exp)}"
    }

    static func issue(
        privateKey: Curve25519.Signing.PrivateKey,
        kid: String = "k1",
        deviceId: String,
        now: Date,
        ttl: TimeInterval,
        reversed: Bool = false,
        ent: [String] = ["cleanup"],
        version: Int = 1
    ) -> String {
        let iat = Int64(now.timeIntervalSince1970)
        let exp = iat + Int64(ttl)
        return issue(
            privateKey: privateKey,
            kid: kid,
            payload: payload(deviceId: deviceId, ent: ent, iat: iat, exp: exp, version: version, reversed: reversed)
        )
    }

    static func issue(privateKey: Curve25519.Signing.PrivateKey, kid: String = "k1", payload: String) -> String {
        let header = "{\"alg\":\"EdDSA\",\"typ\":\"DPL\",\"kid\":\"\(kid)\"}"
        let signingInput = Base64URL.encode(header) + "." + Base64URL.encode(payload)
        let signature = Data(try! privateKey.signature(for: Data(signingInput.utf8)))
        return signingInput + "." + Base64URL.encode(signature)
    }

    static func bitFlip(_ token: String) -> String {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, var sig = Base64URL.decode(parts[2]), !sig.isEmpty else { return token }
        sig[0] ^= 0xFF
        return parts[0] + "." + parts[1] + "." + Base64URL.encode(sig)
    }
}

enum LicenseFixtures {
    static let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    static let day: TimeInterval = 24 * 3600

    @MainActor
    static func manager(
        tokenTTL: TimeInterval? = 90 * day,
        expired: Bool = false,
        now: Date = t0,
        pair: TestTokens.Pair = TestTokens.pair(),
        api: MockLicenseAPI = MockLicenseAPI(),
        lastOnline: Date? = nil
    ) -> (LicenseManager, TestClock, KeychainStore, TestTokens.Pair, MockLicenseAPI) {
        let store = KeychainStore.memory()
        let device = DeviceIdentity.current(store: store)
        let clock = TestClock(now)
        if let tokenTTL {
            let ttl = expired ? -10 * day : tokenTTL
            let iat = expired ? now.addingTimeInterval(-20 * day) : now
            let token = TestTokens.issue(privateKey: pair.privateKey, kid: pair.kid, deviceId: device, now: iat, ttl: ttl)
            store.set(.token, string: token)
        }
        if let lastOnline {
            store.set(.lastOnline, date: lastOnline)
        }
        let manager = LicenseManager(store: store, api: api, clock: { clock.date }, keys: pair.keys)
        return (manager, clock, store, pair, api)
    }
}
